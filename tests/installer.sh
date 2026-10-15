#!/bin/sh
# Filesystem contract tests. Uses a fake OpenCode path probe, never the real config.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/atom-installer-test.XXXXXX")
TMP=$(CDPATH= cd -- "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
mkdir -p "$TMP/bin" "$TMP/distribution/agents" "$TMP/distribution/skills"
cat > "$TMP/bin/opencode" <<'EOF'
#!/bin/sh
if [ "$*" = 'debug paths config' ]; then
  printf '%s\n' "$TEST_CONFIG"
else
  exit 2
fi
EOF
chmod +x "$TMP/bin/opencode"
export PATH="$TMP/bin:$PATH"
cp "$ROOT/atom" "$TMP/distribution/atom"
cp "$ROOT"/agents/atom-*.md "$TMP/distribution/agents/"
[ ! -f "$ROOT/skills/atom-routing.md" ] || cp "$ROOT/skills/atom-routing.md" "$TMP/distribution/skills/"
CLI="$TMP/distribution/atom"
export TEST_CONFIG="$TMP/config with spaces"
passed=0
pass() { passed=$((passed + 1)); printf 'PASS %s\n' "$1"; }
run() { sh "$CLI" "$@" > "$TMP/output" 2>&1; }
fails() { if run "$@"; then cat "$TMP/output"; echo 'Expected failure' >&2; exit 1; fi; }
contains() { grep -q "$1" "$TMP/output" || { cat "$TMP/output"; exit 1; }; }
snapshot() {
  if [ -d "$TEST_CONFIG" ]; then
    (cd "$TEST_CONFIG" && find . -type f -exec cksum {} \; | LC_ALL=C sort)
  fi
}

run install --ai opencode --dry-run
[ ! -e "$TEST_CONFIG" ]
contains 'Would install'
pass 'clean dry-run creates nothing'

run install --ai opencode
for name in planner designer developer reviewer qa; do
  cmp "$TMP/distribution/agents/atom-$name.md" "$TEST_CONFIG/agents/atom-$name.md"
done
[ -f "$TEST_CONFIG/.atom-manifest" ]
pass 'clean installation of all five agents'
[ -f "$TEST_CONFIG/skills/atom-routing.md" ] || { echo 'Missing installed native routing skill' >&2; exit 1; }
cmp "$TMP/distribution/skills/atom-routing.md" "$TEST_CONFIG/skills/atom-routing.md"
grep -q '^atom-routing.md ' "$TEST_CONFIG/.atom-manifest"
for name in planner designer developer reviewer qa; do
  grep -q '^mode: all$' "$TEST_CONFIG/agents/atom-$name.md"
done
pass 'routing skill is owned and all five agents support direct and child selection'

snapshot > "$TMP/before"
run install --ai opencode
snapshot > "$TMP/after"
cmp "$TMP/before" "$TMP/after"
contains 'Unchanged'
pass 'repeated installation is idempotent'

mkdir -p "$TEST_CONFIG/skills/private"
printf 'user agent\n' > "$TEST_CONFIG/agents/user.md"
printf 'private skill\n' > "$TEST_CONFIG/skills/private/SKILL.md"
printf '{"permissions": [], "model": "unchanged"}\n' > "$TEST_CONFIG/opencode.json"
printf 'user instructions\n' > "$TEST_CONFIG/AGENTS.md"
cp "$TEST_CONFIG/opencode.json" "$TMP/user-config"
cp "$TEST_CONFIG/AGENTS.md" "$TMP/user-instructions"

printf '\nDistribution update\n' >> "$TMP/distribution/agents/atom-planner.md"
printf '\nInsight protocol update\n' >> "$TMP/distribution/agents/atom-developer.md"
printf '\nInsight routing update\n' >> "$TMP/distribution/skills/atom-routing.md"
snapshot > "$TMP/before"
run update --ai opencode --dry-run
snapshot > "$TMP/after"
cmp "$TMP/before" "$TMP/after"
contains 'Would update'
pass 'update dry-run is read-only'
run update --ai opencode
cmp "$TMP/distribution/agents/atom-planner.md" "$TEST_CONFIG/agents/atom-planner.md"
cmp "$TMP/distribution/agents/atom-developer.md" "$TEST_CONFIG/agents/atom-developer.md"
cmp "$TMP/distribution/skills/atom-routing.md" "$TEST_CONFIG/skills/atom-routing.md"
contains 'Updated'
pass 'update from current distribution includes owned Insight protocol and routing'

printf '\nUser customization\n' >> "$TEST_CONFIG/agents/atom-reviewer.md"
cp "$TEST_CONFIG/agents/atom-reviewer.md" "$TMP/custom-reviewer"
printf '\nNext distribution\n' >> "$TMP/distribution/agents/atom-reviewer.md"
fails update --ai opencode
contains 'Skipped'
cmp "$TMP/custom-reviewer" "$TEST_CONFIG/agents/atom-reviewer.md"
pass 'update preserves user modifications'
run status
contains 'Modified.*atom-reviewer'
contains 'Distribution version: 0.2.0'
contains 'Installation version: 0.2.0'
pass 'status identifies modified owned files and version'

rm "$TEST_CONFIG/agents/atom-developer.md"
run status
contains 'Missing.*atom-developer'
fails update --ai opencode
cmp "$TMP/distribution/agents/atom-developer.md" "$TEST_CONFIG/agents/atom-developer.md"
pass 'partial installation recovery restores missing owned agent'

snapshot > "$TMP/before"
fails uninstall --ai opencode --dry-run
snapshot > "$TMP/after"
cmp "$TMP/before" "$TMP/after"
contains 'Would remove'
pass 'uninstall dry-run preserves every file'
fails uninstall --ai opencode
[ ! -e "$TEST_CONFIG/agents/atom-planner.md" ]
[ ! -e "$TEST_CONFIG/agents/atom-developer.md" ]
[ ! -e "$TEST_CONFIG/skills/atom-routing.md" ]
cmp "$TMP/custom-reviewer" "$TEST_CONFIG/agents/atom-reviewer.md"
cmp "$TMP/user-config" "$TEST_CONFIG/opencode.json"
cmp "$TMP/user-instructions" "$TEST_CONFIG/AGENTS.md"
[ "$(cat "$TEST_CONFIG/agents/user.md")" = 'user agent' ]
[ "$(cat "$TEST_CONFIG/skills/private/SKILL.md")" = 'private skill' ]
pass 'uninstall removes only unchanged owned files; preserves unrelated data'

export TEST_CONFIG="$TMP/conflict"
mkdir -p "$TEST_CONFIG/agents"
cp "$TMP/distribution/agents/atom-planner.md" "$TEST_CONFIG/agents/atom-planner.md"
snapshot > "$TMP/before"
fails install --ai opencode
snapshot > "$TMP/after"
cmp "$TMP/before" "$TMP/after"
[ ! -e "$TEST_CONFIG/agents/atom-qa.md" ]
contains 'conflict'
pass 'identical pre-existing unowned file is not adopted; no partial install'
run uninstall --ai opencode
[ -f "$TEST_CONFIG/agents/atom-planner.md" ]
pass 'uninstall without ownership preserves pre-existing files'

export TEST_CONFIG="$TMP/missing-source"
mv "$TMP/distribution/agents/atom-qa.md" "$TMP/qa.backup"
fails install --ai opencode
[ ! -e "$TEST_CONFIG" ]
contains 'source'
mv "$TMP/qa.backup" "$TMP/distribution/agents/atom-qa.md"
pass 'missing source rejects installation before writes'

export TEST_CONFIG="$TMP/source-symlink"
mv "$TMP/distribution/agents/atom-qa.md" "$TMP/qa.backup"
ln -s "$TMP/qa.backup" "$TMP/distribution/agents/atom-qa.md"
fails install --ai opencode
[ ! -e "$TEST_CONFIG" ]
rm "$TMP/distribution/agents/atom-qa.md"
mv "$TMP/qa.backup" "$TMP/distribution/agents/atom-qa.md"
pass 'source file symlink is rejected before writes'
mv "$TMP/distribution/agents" "$TMP/source-agents"
ln -s "$TMP/source-agents" "$TMP/distribution/agents"
fails install --ai opencode
[ ! -e "$TEST_CONFIG" ]
rm "$TMP/distribution/agents"
mv "$TMP/source-agents" "$TMP/distribution/agents"
pass 'source directory symlink is rejected before writes'

export TEST_CONFIG="$TMP/hash-failure"
cat > "$TMP/bin/sha256sum" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "$TMP/bin/sha256sum"
fails install --ai opencode
[ ! -e "$TEST_CONFIG/.atom-manifest" ]
[ ! -e "$TEST_CONFIG/agents/atom-planner.md" ]
rm "$TMP/bin/sha256sum"
pass 'checksum failure aborts without an invalid manifest or installation'

export TEST_CONFIG="$TMP/alternate/location"
run install --ai opencode
[ -f "$TEST_CONFIG/agents/atom-qa.md" ]
pass 'uses non-default CLI-discovered configuration directory'
run uninstall --ai opencode
[ ! -e "$TEST_CONFIG/.atom-manifest" ]
run uninstall --ai opencode
pass 'clean and repeated uninstall'

export TEST_CONFIG="$TMP/symlink-config"
mkdir -p "$TMP/outside"
ln -s "$TMP/outside" "$TEST_CONFIG"
fails install --ai opencode
[ ! -e "$TMP/outside/agents" ]
pass 'configuration symlink is rejected'
export TEST_CONFIG="$TMP/symlink-parent/config"
ln -s "$TMP/outside" "$TMP/symlink-parent"
fails install --ai opencode
[ ! -e "$TMP/outside/config" ]
pass 'symlink ancestor is rejected'
export TEST_CONFIG="$TMP/symlink-agents"
mkdir -p "$TEST_CONFIG"
ln -s "$TMP/outside" "$TEST_CONFIG/agents"
fails install --ai opencode
[ ! -e "$TMP/outside/atom-planner.md" ]
pass 'agent-directory symlink is rejected'
export TEST_CONFIG="$TMP/symlink-file"
mkdir -p "$TEST_CONFIG/agents"
ln -s "$TMP/nonexistent" "$TEST_CONFIG/agents/atom-planner.md"
fails install --ai opencode
[ -L "$TEST_CONFIG/agents/atom-planner.md" ]
pass 'dangling agent symlink is preserved'

export TEST_CONFIG="$TMP/owned-symlink"
run install --ai opencode
cp "$TEST_CONFIG/agents/atom-qa.md" "$TMP/outside/qa.md"
rm "$TEST_CONFIG/agents/atom-qa.md"
ln -s "$TMP/outside/qa.md" "$TEST_CONFIG/agents/atom-qa.md"
fails update --ai opencode
fails uninstall --ai opencode
[ -L "$TEST_CONFIG/agents/atom-qa.md" ]
cmp "$TMP/distribution/agents/atom-qa.md" "$TMP/outside/qa.md"
pass 'owned path replaced by symlink is preserved on update and uninstall'

export TEST_CONFIG="$TMP/bad-manifest"
mkdir -p "$TEST_CONFIG"
printf 'unrecognized ownership\n' > "$TEST_CONFIG/.atom-manifest"
fails install --ai opencode
fails uninstall --ai opencode
[ "$(cat "$TEST_CONFIG/.atom-manifest")" = 'unrecognized ownership' ]
pass 'malformed ownership is preserved and rejected'
rm "$TEST_CONFIG/.atom-manifest"
ln -s "$TMP/nonexistent" "$TEST_CONFIG/.atom-manifest"
fails install --ai opencode
[ -L "$TEST_CONFIG/.atom-manifest" ]
pass 'manifest symlink is rejected'

export TEST_CONFIG="$TMP/rollback"
cat > "$TMP/bin/mv" <<'EOF'
#!/bin/sh
for arg do
  case "$arg" in
    */agents/atom-reviewer.md) exit 1 ;;
  esac
done
exec /bin/mv "$@"
EOF
chmod +x "$TMP/bin/mv"
fails install --ai opencode
for name in planner designer developer reviewer qa; do
  [ ! -e "$TEST_CONFIG/agents/atom-$name.md" ]
done
[ ! -e "$TEST_CONFIG/.atom-manifest" ]
rm "$TMP/bin/mv"
run install --ai opencode
pass 'failed write rolls back owned changes; retry recovers'

cp "$TEST_CONFIG/agents/atom-planner.md" "$TMP/original-planner"
cp "$TEST_CONFIG/.atom-manifest" "$TMP/original-manifest"
printf '\nRollback update candidate\n' >> "$TMP/distribution/agents/atom-planner.md"
cat > "$TMP/bin/mv" <<'EOF'
#!/bin/sh
for arg do
  case "$arg" in */agents/atom-reviewer.md) exit 1 ;; esac
done
exec /bin/mv "$@"
EOF
chmod +x "$TMP/bin/mv"
printf '\nAnother update\n' >> "$TMP/distribution/agents/atom-reviewer.md"
fails update --ai opencode
cmp "$TMP/original-planner" "$TEST_CONFIG/agents/atom-planner.md"
cmp "$TMP/original-manifest" "$TEST_CONFIG/.atom-manifest"
rm "$TMP/bin/mv"
pass 'failed update restores original files and ownership'

cat > "$TMP/bin/rm" <<'EOF'
#!/bin/sh
if [ "$*" = "$TEST_CONFIG/agents/atom-reviewer.md" ]; then exit 1; fi
exec /bin/rm "$@"
EOF
chmod +x "$TMP/bin/rm"
fails uninstall --ai opencode
cmp "$TMP/original-planner" "$TEST_CONFIG/agents/atom-planner.md"
cmp "$TMP/original-manifest" "$TEST_CONFIG/.atom-manifest"
rm "$TMP/bin/rm"
pass 'failed uninstall restores original files and ownership'

# Inject restoration failure into a disposable copy of the installer. Production
# has no testing hooks; the copy replaces only its rollback command, not behavior.
sed 's@/bin/mv -f@restore-fail -f@g' "$CLI" > "$TMP/rollback-cli"
cp "$TMP/rollback-cli" "$CLI"
cat > "$TMP/bin/restore-fail" <<'EOF'
#!/bin/sh
exit 1
EOF
cat > "$TMP/bin/mv" <<'EOF'
#!/bin/sh
for arg do
  case "$arg" in */agents/atom-reviewer.md) exit 1 ;; esac
done
exec /bin/mv "$@"
EOF
chmod +x "$TMP/bin/mv" "$TMP/bin/restore-fail"
fails update --ai opencode
backup=$(find "$TEST_CONFIG" -name old-atom-planner.md -type f)
[ -n "$backup" ]
cmp "$TMP/original-planner" "$backup"
contains 'backup'
cp "$ROOT/atom" "$CLI"
rm "$TMP/bin/mv" "$TMP/bin/restore-fail"
pass 'failed rollback preserves original backup and staging directory'

export TEST_CONFIG="$TMP/locked"
mkdir -p "$TEST_CONFIG/.atom-lock"
fails install --ai opencode
[ -d "$TEST_CONFIG/.atom-lock" ]
[ ! -e "$TEST_CONFIG/agents/atom-planner.md" ]
pass 'concurrent or stale lock is not removed'

export TEST_CONFIG="$TMP/legacy-upgrade"
run install
# A v0.1 manifest owns only the five agents. Update must add the new skill.
grep -v '^atom-routing.md ' "$TEST_CONFIG/.atom-manifest" | sed '1s/0.2.0/0.1.0/' > "$TMP/legacy-manifest"
mv "$TMP/legacy-manifest" "$TEST_CONFIG/.atom-manifest"
rm "$TEST_CONFIG/skills/atom-routing.md"
run update
cmp "$TMP/distribution/skills/atom-routing.md" "$TEST_CONFIG/skills/atom-routing.md"
pass 'legacy five-agent manifest upgrades with owned routing skill'
printf '\nDistribution routing update\n' >> "$TMP/distribution/skills/atom-routing.md"
run update
cmp "$TMP/distribution/skills/atom-routing.md" "$TEST_CONFIG/skills/atom-routing.md"
pass 'routing skill update replaces only the unchanged owned version'
printf '\nUser routing customization\n' >> "$TEST_CONFIG/skills/atom-routing.md"
cp "$TEST_CONFIG/skills/atom-routing.md" "$TMP/custom-routing"
fails update
fails uninstall
cmp "$TMP/custom-routing" "$TEST_CONFIG/skills/atom-routing.md"
grep -q '^atom-routing.md ' "$TEST_CONFIG/.atom-manifest"
pass 'modified routing skill and ownership survive update and uninstall'

export TEST_CONFIG="$TMP/skill-conflict"
mkdir -p "$TEST_CONFIG/skills"
printf 'User skill\n' > "$TEST_CONFIG/skills/atom-routing.md"
snapshot > "$TMP/before"
fails install
snapshot > "$TMP/after"
cmp "$TMP/before" "$TMP/after"
pass 'unowned routing skill aborts installation before agent writes'

export TEST_CONFIG="$TMP/skill-symlink"
mkdir -p "$TEST_CONFIG"
ln -s "$TMP/outside" "$TEST_CONFIG/skills"
fails install
[ ! -e "$TEST_CONFIG/agents" ]
[ ! -e "$TMP/outside/atom-routing.md" ]
pass 'skill-directory symlink rejects installation before writes'

export TEST_CONFIG="$TMP/skill-rollback"
cat > "$TMP/bin/mv" <<'EOF'
#!/bin/sh
for arg do
  case "$arg" in */skills/atom-routing.md) exit 1 ;; esac
done
exec /bin/mv "$@"
EOF
chmod +x "$TMP/bin/mv"
fails install
for name in planner designer developer reviewer qa; do
  [ ! -e "$TEST_CONFIG/agents/atom-$name.md" ]
done
[ ! -e "$TEST_CONFIG/skills/atom-routing.md" ]
[ ! -e "$TEST_CONFIG/.atom-manifest" ]
rm "$TMP/bin/mv"
pass 'routing skill write failure rolls back all five agent writes'

fails install --ai codex
fails install --global
fails update --unknown
pass 'unsupported platforms and flags fail safely'
printf '\n%s filesystem tests passed.\n' "$passed"
