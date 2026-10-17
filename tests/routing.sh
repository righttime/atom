#!/bin/sh
# Opt-in real Build routing probes. No routing instruction is put in the fixture.
# ATOM_TEST_MODEL affects these new test sessions only; never fallback or --auto.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
command -v jq >/dev/null 2>&1 || { echo 'jq is required' >&2; exit 1; }
command -v node >/dev/null 2>&1 || { echo 'Node is required only for the disposable JS fixture' >&2; exit 1; }
TMP=$(mktemp -d "${TMPDIR:-/tmp}/atom-routing-test.XXXXXX")
TMP=$(CDPATH= cd -- "$TMP" && pwd -P)
export XDG_CONFIG_HOME="$TMP/config"
export OPENCODE_CONFIG_DIR="$XDG_CONFIG_HOME/opencode"
mkdir -p "$TMP/project" "$OPENCODE_CONFIG_DIR"
printf 'Native routing evidence: %s\n' "$TMP"
opencode --version
sh "$ROOT/atom" install
cd "$TMP/project"
git init -q -b atom-routing-test
cat > AGENTS.md <<'EOF'
# Disposable settings project
This is an approved, small vanilla JS settings feature. Use existing files and
Node's built-in assertions; no dependencies, reports, config changes, or servers.
Storage contract: saveSettings(storage, value) writes JSON to the "settings" key
and returns value. Verification: node test.cjs. UI entry: settings.html + ui.js.
Only settings.js, settings.html, ui.js and test.cjs are task-owned.
Preserve unrelated user-notes.txt exactly. Inspect actual working state.
No commits, push, PR creation, external services, model or permission changes.
Use reversible local defaults; do not wait for routine implementation approval.
EOF
cat > settings.js <<'EOF'
function saveSettings(storage, value) { return value; }
module.exports = { saveSettings };
EOF
cat > settings.html <<'EOF'
<!doctype html><html lang="en"><title>Settings</title>
<main><h1>Settings</h1><input id="displayName" placeholder="Name"></main></html>
EOF
cat > ui.js <<'EOF'
// Wire the existing displayName input to the settings storage when implemented.
EOF
cat > test.cjs <<'EOF'
const assert = require('node:assert/strict');
const { saveSettings } = require('./settings.js');
const values = new Map();
const storage = { setItem: (key, value) => values.set(key, value) };
assert.deepEqual(saveSettings(storage, { displayName: 'Ada' }), { displayName: 'Ada' });
assert.deepEqual(JSON.parse(values.get('settings')), { displayName: 'Ada' });
console.log('PASS settings persistence');
EOF
printf 'Pre-existing unrelated user work.\n' > user-notes.txt
cp user-notes.txt "$TMP/user-notes.before"
git add AGENTS.md settings.js settings.html ui.js test.cjs
snapshot() { git diff HEAD 2>/dev/null || git diff --cached; git diff; cksum settings.js settings.html ui.js test.cjs AGENTS.md user-notes.txt; }
session_id() { jq -rs '[.[] | select(.sessionID != null)][0].sessionID // empty' "$1"; }
api() { opencode api --standalone get "$1" > "$2"; }
run_build() {
  name=$1; prompt=$2; continuation=${3:-}
  set -- opencode run --standalone --agent build --format json
  if [ -n "$continuation" ]; then set -- "$@" --session "$continuation"
  elif [ -n "${ATOM_TEST_MODEL:-}" ]; then set -- "$@" --model "$ATOM_TEST_MODEL"; fi
  if "$@" "$prompt" > "$TMP/$name.jsonl" 2> "$TMP/$name.stderr"; then :
  else
    if grep -q 'provider\.' "$TMP/$name.jsonl"; then
      echo "BLOCKED $name: model/provider error; no fallback. Remaining model probes NOT TESTED."
      cat "$TMP/$name.jsonl"; exit 2
    fi
    echo "BLOCKED/FAIL $name: inspect $TMP/$name.jsonl and .stderr"; exit 1
  fi
  parent=$(session_id "$TMP/$name.jsonl")
  [ -n "$parent" ]
  api "/api/session/$parent/message?limit=100" "$TMP/$name.messages.json"
  api "/api/session?parentID=$parent&limit=100" "$TMP/$name.children.json"
  # Real child messages, not just role-like parent text, are retained for audit.
  for child in $(jq -r '.data[].id' "$TMP/$name.children.json"); do
    api "/api/session/$child/message?limit=100" "$TMP/$child.messages.json"
    api "/api/session?parentID=$child&limit=100" "$TMP/$child.children.json"
    for grandchild in $(jq -r '.data[].id' "$TMP/$child.children.json"); do
      api "/api/session/$grandchild/message?limit=100" "$TMP/$grandchild.messages.json"
    done
  done
  cmp user-notes.txt "$TMP/user-notes.before"
}
expect_child() {
  name=$1; role=$2
  jq -e --arg role "$role" 'any(.data[]; .agent == $role)' "$TMP/$name.children.json" >/dev/null || {
    echo "FAIL $name: no actual $role child; skill discovery is not routing"; return 1;
  }
  # Require a completed native delegation call AND a child's completed response.
  jq -e --arg role "$role" 'any(.data[] | .content[]?; .type == "tool" and .name == "subagent" and .state.status == "completed" and .state.input.agent == $role)' "$TMP/$name.messages.json" >/dev/null
  child=$(jq -r --arg role "$role" '.data[] | select(.agent == $role) | .id' "$TMP/$name.children.json" | head -n 1)
  jq -e 'any(.data[]; .type == "assistant" and .finish == "stop" and .error == null)' "$TMP/$child.messages.json" >/dev/null
  printf 'PASS %s delegation guard: %s → %s (%s); semantics require log audit\n' "$name" "$parent" "$role" "$child"
}
expect_review() {
  name=$1
  set -- "$TMP/$name.children.json"
  for child in $(jq -r '.data[].id' "$TMP/$name.children.json"); do
    set -- "$@" "$TMP/$child.children.json"
  done
  jq -s '[.[].data[] | select(.agent == "atom-reviewer")] | unique_by(.id)' "$@" > "$TMP/$name.reviews.json"
  count=$(jq length "$TMP/$name.reviews.json")
  [ "$count" -ge 1 ] && [ "$count" -le 3 ] || { echo "FAIL $name: expected 1–3 real Reviewer sessions, got $count"; return 1; }
  last=$(jq -r 'sort_by(.time.created) | last.id' "$TMP/$name.reviews.json")
  jq -e '[.data[] | select(.type == "assistant")] | sort_by(.time.created) | reverse | map([.content[]? | select(.type == "text") | .text] | join("\n")) | map(select(length > 0)) | .[0] | test("^\\s*[#*` ]*PASS(?:\\s|[*`]|$)")' "$TMP/$last.messages.json" >/dev/null
  echo "PASS $name real Reviewer final-verdict guard ($count sessions); failed attempts/order require audit"
}

# v2.0.29 private-server catalog endpoints can return an empty list without an
# active runner. Actual skill/subagent tool records below are stronger evidence
# than a pre-run registry assertion (or the mere existence of installed files).

# A/B/F are independent and read-only. Names are not mentioned in user prompts.
snapshot > "$TMP/readonly.before"
run_build A '새로운 설정 기능을 만들려고 해. 구현 전에 가능한 접근 방법을 검토해 줘.'
expect_child A atom-planner
snapshot > "$TMP/readonly.after"; cmp "$TMP/readonly.before" "$TMP/readonly.after"
run_build B '설정 화면의 사용성을 개선하고 싶어. 기존 UI를 분석하고 개선 방향을 제안해 줘.'
expect_child B atom-designer
jq -e 'all(.data[]; .agent != "atom-advisor")' "$TMP/B.children.json" >/dev/null
snapshot > "$TMP/readonly.after"; cmp "$TMP/readonly.before" "$TMP/readonly.after"
run_build F '이 함수 이름 좀 추천해 줘. function f(settings) { return JSON.stringify(settings); }'
jq -e '.data | length == 0' "$TMP/F.children.json" >/dev/null
jq -e '[.data[] | .content[]? | select(.type == "tool" and (.name == "subagent" or .name == "skill"))] | length == 0' "$TMP/F.messages.json" >/dev/null
snapshot > "$TMP/readonly.after"; cmp "$TMP/readonly.before" "$TMP/readonly.after"
echo 'PASS F selective execution guard: no subagent or skill calls'

run_build D '현재 변경된 코드에 결함이 있는지 독립적으로 검토해 줘.'
expect_child D atom-reviewer
snapshot > "$TMP/readonly.after"; cmp "$TMP/readonly.before" "$TMP/readonly.after"

# C must implement persistence and obtain an actual independent review.
run_build C '설정값을 저장하는 기능을 구현해 줘.'
expect_child C atom-developer
expect_review C
jq -e 'all(.data[]; .agent != "atom-advisor")' "$TMP/C.children.json" >/dev/null
node test.cjs > "$TMP/C.test.txt"
git diff > "$TMP/C.diff"

# G uses the SAME Build session over two user turns; its decision must appear in
# the Developer call, not just in a test or persistent context file.
run_build G1 '설정값은 자동 저장해야 하고, 저장 버튼은 만들지 마. 기존 입력란의 input 이벤트에서 저장하는 설계 방향만 간단히 정리해 줘. 아직 구현하지 마.'
g_session=$parent
run_build G2 '좋아, 그 설계대로 구현해 줘.' "$g_session"
expect_child G2 atom-developer
expect_review G2
jq -e 'any(.data[] | .content[]?; .type == "tool" and .name == "subagent" and .state.input.agent == "atom-developer" and (.state.input.prompt | test("자동|autosave|auto.save|automatic"; "i")) and (.state.input.prompt | test("저장 버튼|save button|save-button"; "i")))' "$TMP/G2.messages.json" >/dev/null
if grep -Eiq '<button|type=["\x27]?submit' settings.html; then echo 'FAIL G: unexpected save/submit button'; exit 1; fi
node test.cjs > "$TMP/G.test.txt"
git diff > "$TMP/G.diff"

snapshot > "$TMP/qa.before"
run_build E '현재 구현의 최종 검증을 수행하고 PR을 준비해 줘. 실제 PR 생성은 하지 마. 파일 수정과 Commit/Push도 하지 마.'
expect_child E atom-qa
snapshot > "$TMP/qa.after"; cmp "$TMP/qa.before" "$TMP/qa.after"

# Explicit skeptical intent, not an agent/skill name. Advice must not modify work
# or replace the actual Reviewer already required above. Semantic quality needs audit.
snapshot > "$TMP/advisor.before"
run_build H '다른 관점에서 놓친 전제와 엉뚱하지만 현실적인 대안을 찾아 줘. 이 프로젝트의 기존 데이터나 처리결과 재활용으로 더 간단해질 여지가 없다면 없다고 해도 돼. 현재 작업은 취소하지 말고 읽기 전용으로 자문만 해 줘. 사실과 가설, 실행하지 않은 저비용 실험을 구분해 줘.'
expect_child H atom-advisor
snapshot > "$TMP/advisor.after"; cmp "$TMP/advisor.before" "$TMP/advisor.after"
[ -z "$(git remote)" ]
! git rev-parse --verify HEAD >/dev/null 2>&1
sh "$ROOT/atom" uninstall
echo 'PASS routing fixture guards. NOT a semantic/context/review-order PASS.'
echo 'Audit parent/child tools, actual input handoffs, UI event behavior, Reviewer verdicts and shared call counts, unnecessary questions, explicit role respect, and final diffs in the displayed evidence directory.'
