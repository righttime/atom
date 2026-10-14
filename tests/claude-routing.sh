#!/bin/sh
# Opt-in default-session experiment: no --agent, model override, permission
# grant, or ATOM names in user prompts. Optional rule goes ONLY in temp config.
# Preflight mode never attempts edits/tests: useful when execution is blocked.
set -eu
command -v claude >/dev/null 2>&1
command -v jq >/dev/null 2>&1
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
USER_CONFIG=${CLAUDE_CONFIG_DIR:-${HOME:?}/.claude}
TMP=$(mktemp -d "${TMPDIR:-/tmp}/atom-claude-routing.XXXXXX")
TMP=$(CDPATH= cd -- "$TMP" && pwd -P)
export CLAUDE_CONFIG_DIR="$TMP/config"
mkdir -p "$CLAUDE_CONFIG_DIR" "$TMP/project"
printf 'Routing evidence: %s\n' "$TMP"
claude --version
# Preserve user model choices only. Auth/provider must already be supplied in
# the caller environment; never copy credentials, hooks or permission grants.
if [ -f "$USER_CONFIG/settings.json" ]; then
  jq '{model, modelSettings, effortLevel,
    env: ((.env // {}) | with_entries(select(.key | test("^(ANTHROPIC_(MODEL|DEFAULT_.*_MODEL)|CLAUDE_CODE_(SUBAGENT_MODEL(_FORCE)?|EFFORT_LEVEL))$"))))}
    | with_entries(select(.value != null))' "$USER_CONFIG/settings.json" > "$CLAUDE_CONFIG_DIR/settings.json"
else
  printf '{}\n' > "$CLAUDE_CONFIG_DIR/settings.json"
fi
cp "$CLAUDE_CONFIG_DIR/settings.json" "$TMP/settings.before"
if [ -n "${ATOM_TEST_ROUTING_RULE:-}" ]; then
  mkdir -p "$CLAUDE_CONFIG_DIR/rules"
  cp "$ATOM_TEST_ROUTING_RULE" "$CLAUDE_CONFIG_DIR/rules/atom-routing.md"
fi
sh "$ROOT/atom" install --ai claude
cd "$TMP/project"
cat > sum.sh <<'EOF'
#!/bin/sh
sum() { printf '%s\n' "$(($1 - $2))"; }
EOF
cat > test_sum.sh <<'EOF'
#!/bin/sh
set -eu
. ./sum.sh
[ "$(sum 2 3)" = 5 ]
[ "$(sum -2 3)" = 1 ]
[ "$(sum 0 0)" = 0 ]
echo 'PASS: three sum cases'
EOF
cat > CLAUDE.md <<'EOF'
# Disposable expense calculator fixture
sum(a,b) must return integer addition, including negatives and zero.
Test command: sh test_sum.sh. Only sum.sh may be edited.
Do not create UI files, plans, documentation or dependencies.
Do not stage, commit, push, create a PR, access external services or alter settings.
Preserve test_sum.sh and CLAUDE.md. Do not bypass a denied/pending permission.
EOF
cksum test_sum.sh CLAUDE.md > "$TMP/fixture.before"
git init -q -b atom-routing-fixture
test "$(git branch --show-current)" = atom-routing-fixture
test -z "$(git remote)"
git add sum.sh test_sum.sh CLAUDE.md
git diff --cached --binary > "$TMP/staged.before"
git ls-files --others --exclude-standard > "$TMP/untracked.before"
SESSION=$(uuidgen | tr '[:upper:]' '[:lower:]')
first=1
turn() {
  label=$1; prompt=$2
  printf '%s\n' "$prompt" > "$TMP/$label.prompt.txt"
  if [ "$first" = 1 ]; then set -- --session-id "$SESSION"; first=0
  else set -- --resume "$SESSION"; fi
  if claude -p "$@" --max-turns 24 --output-format stream-json --verbose \
    --forward-subagent-text "$prompt" > "$TMP/$label.jsonl"; then :
  else echo "Invocation failed: $label; inspect $TMP" >&2; return 1; fi
  jq -se 'any(.[]; .type == "result" and .is_error == false and .subtype == "success")' "$TMP/$label.jsonl" >/dev/null
  if jq -se 'any(.[]; .type == "system" and .subtype == "permission_denied")
    or any(.[]; .type == "result" and ((.permission_denials // []) | length) > 0)' "$TMP/$label.jsonl" >/dev/null; then
    echo "BLOCKED by host permission: $label; no bypass/retry. Evidence: $TMP" >&2
    return 1
  fi
  jq -c 'select(.type == "assistant") | .parent_tool_use_id as $parent
    | .message.content[]? | select(.type == "tool_use" and (.name == "Agent" or .name == "Task"))
    | {id, parent: $parent, subagent_type: .input.subagent_type, modelArgument: (.input | has("model"))}' "$TMP/$label.jsonl"
}
turn simple 'What is 2 + 2? Answer briefly; no tools are needed.'
turn plan '이 작은 비용 합계 도구가 가능한지 검토하고 구현 접근법을 제안해 줘. 아직 코드를 바꾸지 마. 제품 결정 하나는 꼭 유지해 줘: 숫자가 아닌 입력은 stdout 없이 종료 코드 17로 거부한다. 의존성은 추가하지 않는다.'
turn design '앞서 정한 요구사항을 유지하면서 입력 화면의 UX를 검토해 줘. 오류 상태와 합계 안내를 중심으로 구현 가능한 수용 기준만 제안하고 코드는 바꾸지 마.'
turn review '지금 변경된 코드에 문제가 있는지 독립적으로 검토해 줘. 실제 소스와 diff를 읽고 결함과 근거를 알려 줘. 테스트 실행이나 수정은 하지 마.'
if [ "${ATOM_TEST_ROUTING_PREFLIGHT:-0}" = 1 ]; then
  turn qa '최종 검증과 PR 준비의 체크리스트를 만들어 줘. 이번에는 테스트 실행, 수정, 실제 PR 생성, commit, push는 하지 마. 실제 소스를 읽고 알려진 결함과 아직 검증하지 못한 항목을 구분해 줘.'
  turn develop '좋아, 이 버그 수정 작업을 맡아 줘. 앞서 정한 제품 요구사항을 유지해 줘. 이번 단계는 구현 전 독립적인 결함 검토까지만 진행하고 그 실제 결과를 받은 다음 중단해 줘. 파일 수정이나 테스트 실행은 하지 마. 검토는 실제 분리된 컨텍스트에서 수행하고, 권한이 막히면 우회하지 말고 미완료로 보고해 줘.'
else
  turn qa '최종 검증하고 PR 준비해 줘. 실제 PR 생성, commit, push는 하지 말고, 검증 실패가 있으면 실패와 차단 사유를 그대로 알려 줘.'
  turn develop '좋아, 이제 앞서 정한 제품 요구사항을 유지하면서 이 버그를 수정해 줘. 코드 변경 전에 독립적인 결함 검토를 먼저 받고, 피드백을 반영한 뒤 테스트와 독립적인 재검토까지 진행해 줘. 검토 결과가 도착하기 전에는 수정하지 마. 단순 역할 흉내가 아니라 실제 분리된 검토를 사용하고, 권한이 막히면 우회하지 말고 미완료로 보고해 줘.'
fi

cmp "$TMP/settings.before" "$CLAUDE_CONFIG_DIR/settings.json"
cksum test_sum.sh CLAUDE.md | cmp "$TMP/fixture.before" -
for label in simple plan design review qa develop; do
  jq -se --arg session "$SESSION" 'any(.[]; .type == "system" and .subtype == "init" and .session_id == $session)' "$TMP/$label.jsonl" >/dev/null
done
jq -se 'all(.[]; if .type == "assistant" then
  all(.message.content[]?; if .type == "tool_use" and (.name == "Agent" or .name == "Task")
    then ((.input.subagent_type // "") | startswith("atom-") | not) else true end)
  else true end)' "$TMP/simple.jsonl" >/dev/null
for pair in plan:planner design:designer review:reviewer qa:qa develop:developer; do
  label=${pair%%:*}; role=${pair#*:}
  if jq -se --arg role "atom-$role" 'any(.[]; .type == "assistant" and .parent_tool_use_id == null
    and any(.message.content[]?; .type == "tool_use" and (.name == "Agent" or .name == "Task") and .input.subagent_type == $role and (.input | has("model") | not)))' "$TMP/$label.jsonl" >/dev/null; then :
  else echo "FAIL actual automatic delegation: $label (role-like text is not evidence); $TMP" >&2; exit 1; fi
done
# Normalize only the Developer child context for the existing strict loop
# parser. Keep actual Reviewer IDs/text/completions, never parent summaries.
jq -s '
  [.[] | select(.type == "assistant" and .parent_tool_use_id == null)
    | .message.content[]? | select(.type == "tool_use" and (.name == "Agent" or .name == "Task") and .input.subagent_type == "atom-developer") | .id]
  | if length != 1 then error("Expected one native Developer invocation") else .[0] end' "$TMP/develop.jsonl" > "$TMP/developer-id.json"
jq -se --slurpfile id "$TMP/developer-id.json" '
  [.[] | select(.type == "assistant") | .parent_tool_use_id as $parent
    | .message.content[]? | select(.type == "tool_use" and (.name == "Agent" or .name == "Task") and .input.subagent_type == "atom-reviewer")
    | {id: .id, parent: $parent}]
  | length >= 1 and length <= 3 and all(.[]; .parent == $id[0])' "$TMP/develop.jsonl" >/dev/null
jq -c --slurpfile id "$TMP/developer-id.json" '
  if .parent_tool_use_id == $id[0] then .parent_tool_use_id = null
    | if .type == "assistant" then .message.content |= map(if .type == "tool_use" and .name == "Task" then .name = "Agent" else . end) else . end
  else . end' "$TMP/develop.jsonl" > "$TMP/nested-normalized.jsonl"
if [ "${ATOM_TEST_ROUTING_PREFLIGHT:-0}" != 1 ]; then
  jq -s -f "$ROOT/tests/claude-evidence.jq" "$TMP/nested-normalized.jsonl" > "$TMP/nested-review-evidence.json"
fi
if [ "${ATOM_TEST_ROUTING_PREFLIGHT:-0}" = 1 ]; then
  git diff --exit-code
  git diff --cached --binary | cmp "$TMP/staged.before" -
  git ls-files --others --exclude-standard | cmp "$TMP/untracked.before" -
  printf 'Read-only routing and nested invocation assertions passed; inspect decisions/actual completion in %s. Repair/re-review was NOT exercised.\n' "$TMP"
  exit 0
fi
sh test_sum.sh
# Decision appears only in the early user prompt, not the project instructions.
set +e
sh -c '. ./sum.sh; sum bad 2' > "$TMP/invalid.stdout" 2> "$TMP/invalid.stderr"
code=$?
set -e
test "$code" -eq 17 && test ! -s "$TMP/invalid.stdout"
printf 'Fixture assertions passed; inspect actual delegation, nested completion and decision handoff in %s (not an automatic routing PASS).\n' "$TMP"
