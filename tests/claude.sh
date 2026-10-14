#!/bin/sh
# Opt-in native Claude integration. Requires an existing authenticated environment.
# No --model, fallback, permission bypass, user settings writes or project ATOM init.
set -eu
command -v claude >/dev/null 2>&1
command -v jq >/dev/null 2>&1 || { echo 'Integration evidence requires jq (installer does not).' >&2; exit 1; }
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
USER_CONFIG=${CLAUDE_CONFIG_DIR:-${HOME:?}/.claude}
TMP=$(mktemp -d "${TMPDIR:-/tmp}/atom-claude-test.XXXXXX")
TMP=$(CDPATH= cd -- "$TMP" && pwd -P)
export CLAUDE_CONFIG_DIR="$TMP/config"
mkdir -p "$CLAUDE_CONFIG_DIR" "$TMP/project-a" "$TMP/project-b"
printf 'Native Claude logs/fixtures: %s\n' "$TMP"
claude --version

# Preserve the tester's model-related choices in the isolated config without
# copying credentials, permissions, hooks, plugins or unrelated user settings.
# Authentication/provider environment inherited from the caller stays untouched.
if [ -f "$USER_CONFIG/settings.json" ]; then
  jq '{model, modelSettings, effortLevel,
    env: ((.env // {}) | with_entries(select(.key | test("^(ANTHROPIC_(MODEL|DEFAULT_.*_MODEL)|CLAUDE_CODE_(SUBAGENT_MODEL(_FORCE)?|EFFORT_LEVEL))$"))))}
    | with_entries(select(.value != null))' "$USER_CONFIG/settings.json" > "$CLAUDE_CONFIG_DIR/settings.json"
else
  printf '{}\n' > "$CLAUDE_CONFIG_DIR/settings.json"
fi
cp "$CLAUDE_CONFIG_DIR/settings.json" "$TMP/settings.before"
mkdir -p "$CLAUDE_CONFIG_DIR/agents" "$CLAUDE_CONFIG_DIR/skills/private"
printf '%s\n' '---' 'name: private-user-agent' 'description: Existing user agent; not part of ATOM.' '---' 'Do not modify files.' > "$CLAUDE_CONFIG_DIR/agents/private.md"
printf 'existing private skill\n' > "$CLAUDE_CONFIG_DIR/skills/private/SKILL.md"
printf 'user instructions\n' > "$CLAUDE_CONFIG_DIR/CLAUDE.md"
(cd "$CLAUDE_CONFIG_DIR" && cksum settings.json agents/private.md skills/private/SKILL.md CLAUDE.md) > "$TMP/user.before"
sh "$ROOT/atom" install --ai claude
sh "$ROOT/atom" status --ai claude > "$TMP/status.txt"
[ "$(grep -c '^Installed atom-' "$TMP/status.txt")" -eq 5 ]
sh "$ROOT/atom" update --ai claude

run_agent() {
  agent=$1; log=$2; prompt=$3
  if claude -p --agent "$agent" --max-turns 60 --output-format stream-json --verbose \
    --forward-subagent-text --no-session-persistence "$prompt" > "$log"; then :
  else echo "Claude invocation failed; evidence: $log" >&2; return 1; fi
  jq -se 'any(.[]; .type == "result" and .is_error == false and .subtype == "success")' "$log" >/dev/null
  if jq -se 'any(.[]; .type == "result" and ((.permission_denials // []) | length) > 0)
    or any(.[]; .type == "user" and any(.message.content[]?; .type == "tool_result" and .is_error == true and ((.content | tostring) | test("permission|haven.t granted"; "i"))))' "$log" >/dev/null; then
    echo "Host permission blocked this integration run; no bypass attempted by the harness. Evidence: $log" >&2
    return 1
  fi
  jq -se 'any(.[]; .type == "assistant" and any(.message.content[]?; .type == "text" and (.text | length > 0)))' "$log" >/dev/null
}

cd "$TMP/project-a"
run_agent atom-planner "$TMP/planner.jsonl" 'Disposable read-only smoke test. No tools or files. State your ATOM role and give one brief feasibility criterion for lightweight global agents.'
run_agent atom-designer "$TMP/designer.jsonl" 'Disposable read-only smoke test. No tools or files. State your ATOM role and give three accessibility criteria for a login form.'
run_agent atom-qa "$TMP/qa.jsonl" 'Disposable role smoke test, not a request to run tests or create a PR. No tools or files. State your ATOM QA role in one sentence.'

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
cat > CLAUDE.md <<'EOF'
# Disposable shell fixture
sum(a,b) must return the integer sum, including negatives and zero.
Verify with: sh test_sum.sh. Only sum.sh is editable.
Preserve test_sum.sh, CLAUDE.md and user-notes.txt exactly.
No dependencies, docs, stage, commit, push, model/config changes or external services.
EOF
printf 'Pre-existing user work. Preserve these exact bytes.\n' > user-notes.txt
cksum test_sum.sh CLAUDE.md user-notes.txt > "$TMP/fixture.before"
git init -q -b atom-test
[ "$(git branch --show-current)" = atom-test ] && [ -z "$(git remote)" ]
git add sum.sh test_sum.sh CLAUDE.md
if sh test_sum.sh; then echo 'Expected draft failure' >&2; exit 1; fi
run_agent atom-reviewer "$TMP/reviewer.jsonl" 'Independently inspect the actual staged/unstaged draft, source and CLAUDE.md. Author claims sum.sh implements integer addition; verify that untrusted claim. No test execution, file changes or delegation. Return PASS/CHANGES_REQUIRED/INCOMPLETE with finding IDs.'
jq -se '[.[] | select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text] | last | test("^\\s*[#*` ]*CHANGES_REQUIRED(?:\\s|[*`]|$)")' "$TMP/reviewer.jsonl" >/dev/null
run_agent atom-developer "$TMP/developer.jsonl" 'Approved REVIEW-FIRST disposable task. Review counter starts at 0/3. Before ANY edit or test execution, use the native Agent tool with subagent_type atom-reviewer to inspect the current draft in this working directory. This is an explicit review-first exception. Reviewer must independently read actual staged/unstaged diff, source/tests and CLAUDE.md, not run tests or edit, and return PASS/CHANGES_REQUIRED/INCOMPLETE plus stable IDs. Wait for its actual result; fix blocking findings in sum.sh, run sh test_sum.sh, then request a separate native Reviewer re-review with prior IDs and observed checks in the SAME maximum-three-call budget. Do not impersonate a Reviewer or launch a nested CLI. The staged draft is authorized, user-notes.txt is unrelated work. Preserve test_sum.sh and CLAUDE.md. Do not stage, commit, push, create docs, change settings/model/permissions or access external services. If blocked, report incomplete rather than bypassing permissions. Return concise ATOM Insight with actual review count/verdict.'
sh test_sum.sh
cksum test_sum.sh CLAUDE.md user-notes.txt > "$TMP/fixture.after"
cmp "$TMP/fixture.before" "$TMP/fixture.after"
jq -s -f "$ROOT/tests/claude-evidence.jq" "$TMP/developer.jsonl" > "$TMP/review-evidence.json"
cat "$TMP/review-evidence.json"

# Init records establish host discovery, not merely five files on disk.
for log in planner designer qa reviewer developer; do
  jq -se 'any(.[]; .type == "system" and .subtype == "init"
    and ([.agents[]? | select(test("^atom-(planner|designer|developer|reviewer|qa)$"))] | unique | length) == 5)' "$TMP/$log.jsonl" >/dev/null
done
cmp "$TMP/settings.before" "$CLAUDE_CONFIG_DIR/settings.json"
(cd "$CLAUDE_CONFIG_DIR" && cksum settings.json agents/private.md skills/private/SKILL.md CLAUDE.md) > "$TMP/user.after"
cmp "$TMP/user.before" "$TMP/user.after"
sh "$ROOT/atom" uninstall --ai claude
[ ! -e "$CLAUDE_CONFIG_DIR/.atom-manifest" ]
for role in planner designer developer reviewer qa; do [ ! -e "$CLAUDE_CONFIG_DIR/agents/atom-$role.md" ]; done
(cd "$CLAUDE_CONFIG_DIR" && cksum settings.json agents/private.md skills/private/SKILL.md CLAUDE.md) > "$TMP/user.after"
cmp "$TMP/user.before" "$TMP/user.after"
printf 'PASS five native agents across two projects, review/fix/re-review, preserved fixtures/settings and uninstall. Evidence: %s\n' "$TMP"
