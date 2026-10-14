#!/bin/sh
# Claude-specific path and cross-host ownership tests. No real user config.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/atom-claude-installer.XXXXXX")
TMP=$(CDPATH= cd -- "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
mkdir -p "$TMP/bin" "$TMP/home"
printf '#!/bin/sh\nexit 2\n' > "$TMP/bin/claude"
cat > "$TMP/bin/opencode" <<'EOF'
#!/bin/sh
[ "$*" = 'debug paths config' ] || exit 2
printf '%s\n' "$TEST_CONFIG"
EOF
chmod +x "$TMP/bin/claude" "$TMP/bin/opencode"
export PATH="$TMP/bin:$PATH" HOME="$TMP/home"
unset CLAUDE_CONFIG_DIR
passed=0
pass() { passed=$((passed + 1)); printf 'PASS %s\n' "$1"; }
run() { sh "$ROOT/atom" "$@" > "$TMP/output" 2>&1 || { cat "$TMP/output"; return 1; }; }
fails() { if sh "$ROOT/atom" "$@" > "$TMP/output" 2>&1; then cat "$TMP/output"; exit 1; fi; }
snapshot() { (cd "$TEST_CONFIG" && find . -type f -exec cksum {} \; | LC_ALL=C sort); }

run install --ai claude --dry-run
[ ! -e "$HOME/.claude" ]
run install --ai claude
for role in planner designer developer reviewer qa; do
  cmp "$ROOT/agents/claude/atom-$role.md" "$HOME/.claude/agents/atom-$role.md"
done
pass 'Claude default HOME installs five native definitions without a path probe'
run status --ai claude
[ "$(grep -c '^Installed atom-' "$TMP/output")" -eq 5 ]
run uninstall --ai claude
[ ! -e "$HOME/.claude/.atom-manifest" ]
pass 'Claude default status and uninstall'

export TEST_CONFIG="$TMP/opencode-default"
run install
cmp "$ROOT/agents/atom-developer.md" "$TEST_CONFIG/agents/atom-developer.md"
run status
[ "$(grep -c '^Installed atom-' "$TMP/output")" -eq 5 ]
run uninstall
[ ! -e "$TEST_CONFIG/.atom-manifest" ]
pass 'CLI without --ai still installs, reports and removes OpenCode definitions'

export CLAUDE_CONFIG_DIR="$TMP/override with spaces" TEST_CONFIG="$TMP/override with spaces"
mkdir -p "$TEST_CONFIG/agents" "$TEST_CONFIG/skills/superpowers"
printf '{"model":"user-choice","permissions":{"deny":["Bash(git push *)"]}}\n' > "$TEST_CONFIG/settings.json"
printf 'user instructions\n' > "$TEST_CONFIG/CLAUDE.md"
printf 'private agent\n' > "$TEST_CONFIG/agents/private.md"
printf 'existing skill\n' > "$TEST_CONFIG/skills/superpowers/SKILL.md"
snapshot > "$TMP/user.before"
run install --ai claude
run update --ai claude
run uninstall --ai claude
snapshot > "$TMP/user.after"
cmp "$TMP/user.before" "$TMP/user.after"
pass 'Claude override preserves settings/model, instructions, agents and existing Skills'

run install --ai opencode
snapshot > "$TMP/before"
for action in install update status uninstall; do fails "$action" --ai claude; done
snapshot > "$TMP/after"
cmp "$TMP/before" "$TMP/after"
pass 'Claude cannot adopt, update or remove an OpenCode manifest in a shared config'
run uninstall --ai opencode
run install --ai claude
snapshot > "$TMP/before"
for action in install update status uninstall; do fails "$action" --ai opencode; done
snapshot > "$TMP/after"
cmp "$TMP/before" "$TMP/after"
pass 'OpenCode cannot adopt, update or remove a Claude manifest in a shared config'

export CLAUDE_CONFIG_DIR=relative/path
fails install --ai claude
export CLAUDE_CONFIG_DIR=/
fails install --ai claude
export CLAUDE_CONFIG_DIR="$TMP/noncanonical/../config"
fails install --ai claude
export CLAUDE_CONFIG_DIR="$TMP/multiline
path"
fails install --ai claude
pass 'Claude rejects relative, root, noncanonical and multiline config paths'

# Schema/policy assertions complement, but do not replace, native CLI validation.
for role in planner designer developer reviewer qa; do
  file="$ROOT/agents/claude/atom-$role.md"
  [ "$(head -n 1 "$file")" = '---' ]
  grep -q "^name: atom-$role$" "$file"
  grep -q '^description: ' "$file"
  if grep -Eq '^(model|mode|steps|permissions|permissionMode|skills|isolation):' "$file"; then exit 1; fi
  if grep -Eq 'OpenCode|`subagent`|background: false|--fallback-model' "$file"; then exit 1; fi
done
grep -q 'subagent_type: "atom-reviewer"' "$ROOT/agents/claude/atom-developer.md"
grep -q 'three Reviewer calls total' "$ROOT/agents/claude/atom-developer.md"
grep -q '^disallowedTools: .*Agent' "$ROOT/agents/claude/atom-reviewer.md"
pass 'Claude schema, native review contract and no model/permission/Skill overrides (static)'
printf '\n%s Claude-specific tests passed.\n' "$passed"
