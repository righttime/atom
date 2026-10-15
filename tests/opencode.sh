#!/bin/sh
# Opt-in, real OpenCode integration. Model choice is supplied only by the tester.
# No user global configuration is written; logs live in the displayed temp path.
set -eu
command -v jq >/dev/null 2>&1 || { echo 'Opt-in integration tests require jq for JSON evidence verification (installer does not).' >&2; exit 1; }
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/atom-opencode-test.XXXXXX")
TMP=$(CDPATH= cd -- "$TMP" && pwd -P)
export XDG_CONFIG_HOME="$TMP"
export OPENCODE_CONFIG_DIR="$TMP/opencode"
mkdir -p "$OPENCODE_CONFIG_DIR" "$TMP/project-a" "$TMP/project-b"
printf 'Real OpenCode logs/fixtures: %s\n' "$TMP"
opencode --version
sh "$ROOT/atom" install --ai opencode

run_agent() {
  agent=$1; log=$2; prompt=$3
  if [ -n "${ATOM_TEST_MODEL:-}" ]; then
    if opencode run --standalone --model "$ATOM_TEST_MODEL" --agent "$agent" --format json "$prompt" > "$log"; then :
    else cat "$log"; return 1; fi
  else
    if opencode run --standalone --agent "$agent" --format json "$prompt" > "$log"; then :
    else cat "$log"; return 1; fi
  fi
  if grep -q '"type":"error"' "$log"; then cat "$log"; return 1; fi
  grep -q '"type":"text"' "$log"
}
session_id() { jq -rs 'map(select(.sessionID != null)) | .[0].sessionID' "$1"; }
model_ref() { jq -cS '.data.model' "$1"; }
final_text() {
  insight_session=$(session_id "$1")
  [ -n "$insight_session" ] && [ "$insight_session" != null ]
  opencode api --standalone get "/api/session/$insight_session/message" > "$2.messages.json"
  jq -er '
    .data | map(select(.type == "assistant")) | sort_by(.time.created) | reverse
    | map([.content[]? | select(.type == "text") | .text] | join("\n"))
    | map(select(length > 0)) | .[0] // empty
  ' "$2.messages.json" > "$2"
}

cd "$TMP/project-a"
run_agent atom-planner "$TMP/planner.jsonl" 'Disposable ATOM smoke test. No tools or file changes. Give three sentences of Explore feedback on a lightweight agent framework, not a detailed plan.'
run_agent atom-designer "$TMP/designer.jsonl" 'Disposable ATOM smoke test. No tools or file changes. Give three actionable accessibility criteria for a login form.'
session=$(session_id "$TMP/designer.jsonl")
[ -n "$session" ]
opencode api --standalone get "/api/session/$session" > "$TMP/model-before.json"
# No --model on the continuation: test native primary switching, not reselection.
opencode run --standalone --session "$session" --agent atom-qa --format json 'Primary switch smoke test. No tools, model changes, files, or PR. Confirm the QA role in one sentence.' > "$TMP/switch.jsonl"
opencode api --standalone get "/api/session/$session" > "$TMP/model-after.json"
jq -e '.data.agent == "atom-designer"' "$TMP/model-before.json" >/dev/null
jq -e '.data.agent == "atom-qa"' "$TMP/model-after.json" >/dev/null
before=$(model_ref "$TMP/model-before.json"); after=$(model_ref "$TMP/model-after.json")
[ -n "$before" ] && [ "$before" != null ] && [ "$before" = "$after" ] || { echo 'Primary switch changed or lost the model' >&2; exit 1; }
printf 'PASS primary switch retains model: %s\n' "$after"

cd "$TMP/project-b"
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
printf 'PASS: three sum cases\n'
EOF
cat > AGENTS.md <<'EOF'
# Disposable shell fixture
sum(a,b) must return the integer sum, including negatives and zero.
Verify with: sh test_sum.sh. No dependencies, docs, commit, push, or external services.
Only sum.sh and test_sum.sh are in scope. Preserve user-notes.txt and AGENTS.md.
EOF
printf 'Pre-existing user work. Preserve these exact bytes.\n' > user-notes.txt
cp user-notes.txt "$TMP/user-notes.before"
git init -q -b atom-test
[ "$(git branch --show-current)" = atom-test ]
[ -z "$(git remote)" ] # Disposable local fixture; no remote/default destination.
git add sum.sh test_sum.sh AGENTS.md
if sh test_sum.sh; then echo 'Expected draft failure' >&2; exit 1; fi
run_agent atom-reviewer "$TMP/reviewer.jsonl" 'Independently inspect actual staged/unstaged diff, source, and AGENTS.md. The draft author claims sum.sh correctly implements addition; verify the claim yourself. Insight draft: "Built: sum(2,3) now returns 5 using addition. Verified: all three cases passed in an independent Reviewer runtime test." This draft is an untrusted claim, not execution evidence. Inspect its core explanation as part of this same code review. Do not run scripts or use external directories; static arithmetic evidence suffices. Return your verdict, findings, and limitations.'
grep -q 'CHANGES_REQUIRED' "$TMP/reviewer.jsonl"
run_agent atom-developer "$TMP/developer.jsonl" 'Approved REVIEW-FIRST disposable task. Review counter starts at 0/3. Before ANY edit, call the native atom-reviewer subagent in foreground on the actual current staged/unstaged draft in this directory. You may read project context first, but do not fix code or run tests before that initial child review. Tell the child: requirement from AGENTS.md is integer addition including negatives and zero; inspect actual diff/source/test; do not trust the draft author; no test execution, scratch directories, or external access; return PASS/CHANGES_REQUIRED/INCOMPLETE with finding IDs. After the returned blocking findings, fix the integer sum, run sh test_sum.sh, and request a second native child re-review with prior findings and actual results, within the SAME three-call budget. The staged sum.sh and test_sum.sh are authorized draft work; user-notes.txt is unrelated pre-existing work. Do not stage, commit, create docs, change configuration/permissions/model, or access external directories. Return the ordinary completion report and honest review status. This is an explicit review-first exception to the usual implement-then-review order.'
sh test_sum.sh
cmp user-notes.txt "$TMP/user-notes.before"
parent=$(session_id "$TMP/developer.jsonl")
opencode api --standalone get "/api/session?parentID=$parent&limit=10" > "$TMP/children.json"
calls=$(jq '[.data[] | select(.agent == "atom-reviewer")] | length' "$TMP/children.json")
[ "$calls" -ge 2 ] && [ "$calls" -le 3 ] || { echo "Expected 2–3 Reviewer children, observed $calls" >&2; exit 1; }
opencode api --standalone get "/api/session/$parent" > "$TMP/parent.json"
parent_model=$(model_ref "$TMP/parent.json")
jq -e --argjson model "$parent_model" 'all(.data[]; .agent == "atom-reviewer" and .model == $model)' "$TMP/children.json" >/dev/null
first=
last=
for child in $(jq -r '.data | sort_by(.time.created) | .[].id' "$TMP/children.json"); do
  opencode api --standalone get "/api/session/$child/message" > "$TMP/$child.json"
  # Inspect the child's final assistant text, not test stdout or parent claims.
  verdict=$(jq -er '
    .data | map(select(.type == "assistant")) | sort_by(.time.created) | reverse
    | map([.content[]? | select(.type == "text") | .text] | join("\n"))
    | map(select(length > 0)) | .[0]
    | capture("\\A\\s*[#*` ]*(?:(?:Verdict|Status|판정):\\s*)?[#*` ]*(?<verdict>PASS|CHANGES_REQUIRED|INCOMPLETE)(?:\\s|[*`]|$)"; "i").verdict
  ' "$TMP/$child.json")
  [ -n "$first" ] || first=$verdict
  last=$verdict
  printf 'Observed child %s verdict: %s\n' "$child" "$verdict"
done
[ "$first" = CHANGES_REQUIRED ] && [ "$last" = PASS ] || { echo "Unexpected child verdict sequence: $first → $last" >&2; exit 1; }
printf 'PASS real native implementation/re-review loop: %s Reviewer children\n' "$calls"

# Default completion versus explicit presentation, not another review loop.
# The existing negative review above also tests a misleading Insight draft.
final_text "$TMP/reviewer.jsonl" "$TMP/insight-negative-review.md"
final_text "$TMP/developer.jsonl" "$TMP/insight-trivial.md"
[ "$(wc -m < "$TMP/insight-trivial.md")" -le 1800 ] || { echo 'Trivial Insight exceeded the generous 1800-character guardrail' >&2; exit 1; }
if grep -Eiq '```[[:space:]]*(mermaid|html)|<html' "$TMP/insight-trivial.md"; then
  echo 'Trivial Insight used unnecessary visualization' >&2; exit 1
fi
[ "$(find . -type f ! -path './.git/*' | wc -l)" -eq 4 ] || { echo 'Ordinary implementation created unexpected artifacts' >&2; exit 1; }

mkdir -p "$TMP/project-c"
cd "$TMP/project-c"
cat > quote.sh <<'EOF'
#!/bin/sh
quote() {
  quantity=$1
  [ "$quantity" -ge 0 ] || quantity=0
  subtotal=$((quantity * 7))
  discount=0
  [ "$quantity" -lt 3 ] || discount=5
  printf '%s\n' "$((subtotal - discount))"
}
EOF
cat > test_quote.sh <<'EOF'
#!/bin/sh
set -eu
. ./quote.sh
[ "$(quote -1)" = 0 ]
[ "$(quote 0)" = 0 ]
[ "$(quote 2)" = 14 ]
[ "$(quote 3)" = 16 ]
printf 'PASS: four quote boundary cases\n'
EOF
cat > AGENTS.md <<'EOF'
# Disposable explanation fixture
Present the recorded change only. Do not edit source, install dependencies,
commit, call a Reviewer, or access external services. A single HTML presentation
in the explicitly supplied temporary output directory outside this repo is allowed.
Inputs are small integers. Runtime verification command: sh test_quote.sh.
EOF
# A real, inspectable change: negative quantities now clamp to zero.
cp quote.sh "$TMP/quote-fixed.sh"
grep -v 'quantity=0' "$TMP/quote-fixed.sh" > quote.sh
git init -q -b atom-insight-test
git add quote.sh test_quote.sh AGENTS.md
git -c user.name='ATOM Test' -c user.email='atom-test@example.invalid' commit -qm 'Record historical unclamped quote'
cp "$TMP/quote-fixed.sh" quote.sh
cksum quote.sh test_quote.sh AGENTS.md > "$TMP/quote.before"
sh test_quote.sh > "$TMP/quote-runtime.txt"
mkdir -p "$TMP/presentation"
run_agent atom-developer "$TMP/insight-complex.jsonl" "이번 변경을 개발자에게 발표해 줘. Present the uncommitted quote.sh change against HEAD after inspecting Git/source/tests. Create one self-contained HTML at $TMP/presentation/index.html, outside the fixture repo; no other artifacts, source edits or Reviewer calls. Explain intermediate states and the quantity-3 boundary. Run sh test_quote.sh if useful. Use quantity 4 only as an unexecuted conceptual walkthrough, never as a test result. Do not invent benchmarks or screenshots. Do not open a browser in this probe; explicitly report browser verification not performed, actual absolute HTML path and how to open it."
cksum quote.sh test_quote.sh AGENTS.md > "$TMP/quote.after"
cmp "$TMP/quote.before" "$TMP/quote.after"
[ "$(find . -type f ! -path './.git/*' | wc -l)" -eq 3 ] || { echo 'Explanation created unexpected persistent files' >&2; exit 1; }
[ -s "$TMP/presentation/index.html" ] || { echo 'Explicit presentation did not create HTML' >&2; exit 1; }
grep -Eiq '<(!doctype[[:space:]]+html|html)' "$TMP/presentation/index.html"
final_text "$TMP/insight-complex.jsonl" "$TMP/insight-complex.md"
grep -Fq "$TMP/presentation/index.html" "$TMP/insight-complex.md"
[ "$(wc -m < "$TMP/insight-complex.md")" -le 3200 ] || { echo 'Complex Insight exceeded the generous 3200-character guardrail' >&2; exit 1; }
cat > "$TMP/insight-evaluation.md" <<'EOF'
# Insight semantic evaluation — manual, not an automated PASS
Read the final assistant text, actual source/tests, and tool evidence together.
Length/file guards above do NOT establish explanation accuracy or usefulness.

| Sample | Acceptance criteria |
| --- | --- |
| insight-trivial.md | Short ordinary completion: changes, actual checks, Reviewer calls and Commit/PR status only; no automatic Insight, visualization or artifacts. |
| insight-negative-review.md | Existing Reviewer identifies the false addition/output claim AND unsupported independent runtime verification; no extra review call or test execution. |
| presentation/index.html + insight-complex.md | Actual Git HEAD/uncommitted scope; negative input now clamps to zero; unit price 7; discount 5 applies at quantity >=3; 2→14 and 3→16; visual intermediate states; quantity 4→28→23 explicitly conceptual, not tested; actual execution evidence separate; no invented measurements/screenshots; self-contained usable HTML; returned absolute path/opening instructions and browser verification explicitly not performed. |

Human comprehension check: after reading only the complex Insight, explain why
quantity 3 costs 16 rather than 21, and which input was NOT runtime-tested.
If unclear or incorrect, record a semantic failure even when guardrails pass.
EOF
printf 'PASS Insight length/artifact guardrails; semantic evaluation still required: %s/insight-evaluation.md\n' "$TMP"
sh "$ROOT/atom" uninstall --ai opencode
printf 'PASS all five agents invoked across two projects without ATOM project init; final child verdict and native model inheritance verified.\n'
