#!/bin/sh
# Static prompt contracts + mock transcript guards, NOT model/native routing evidence.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
has() { grep -Fq -- "$2" "$ROOT/$1" || { echo "FAIL contract: $1: $2" >&2; exit 1; }; }
A=agents/atom-advisor.md
R=skills/atom-routing.md
has "$A" 'The Skeptic'
has "$A" 'Question everything, including the question itself.'
has "$A" 'Challenge assumptions, not momentum.'
has "$A" 'mode: all'
has "$A" 'action: edit'
has "$A" 'action: subagent'
has "$A" 'Evidence / Hypothesis'
has "$A" 'Cheap Test'
has "$A" 'at most three'
has "$A" 'Do not manufacture alternatives'
has "$A" 'Do not modify source'
has "$A" 'Never replace Planner, Developer, Reviewer, or QA'
has "$A" 'model/provider'
has "$A" 'past processing results'
has "$A" 'derive intermediate information'
has "$A" 'not executed'
has "$A" 'product direction or approval-scope changes belong to the user'
has "$A" 'Do not delegate further'
has "$A" 'read-only inspection'
has "$R" 'simple bugs, clear UI changes, routine cleanup'
has "$R" 'ordinary feature or verification plan execution'
has "$R" 'repeated failure of the same approach'
has "$R" 'high-cost research or retraining'
has "$R" '다른 관점'
has "$R" 'does not automatically interrupt'
has "$R" 'parent Build'
has "$R" 'No random scheduler'
has "$R" 'sufficiently validated decision'
has "$R" 'not one failed test'
has "$R" 'consultation costs exceed likely benefit'
has "$R" 'defer prior conclusions until independent hypotheses'
has "$R" 'Never hide safety requirements'
has "$R" 'mandatory independent `atom-reviewer`'
has "$R" 'actual host'
has "$R" 'Claude Code'
for role in planner designer developer qa reviewer; do
  has "agents/atom-$role.md" 'Build'
done
has agents/atom-developer.md 'Delegate review to `atom-reviewer`'
printf 'PASS Advisor static contracts (not runtime routing)\n'

# Handwritten traces exercise the acceptance oracle, not an invented production router.
# A/B no optional call; C/D may call; E explicit call; F work continues;
# G unsupported idea rejected; H real Reviewer required; I direct selection retained.
valid_trace() {
  case "$1:$2" in
    A:skip|B:skip|C:skip|C:advisor|D:skip|D:advisor|E:advisor|F:continue|G:reject|H:reviewer|I:direct) return 0 ;;
    *) return 1 ;;
  esac
}
for row in A:skip B:skip C:advisor D:advisor E:advisor F:continue G:reject H:reviewer I:direct; do
  valid_trace "${row%%:*}" "${row#*:}"
done
for row in A:advisor B:advisor E:skip F:stop G:fabricate H:advisor I:reroute; do
  if valid_trace "${row%%:*}" "${row#*:}"; then echo 'FAIL mock accepted invalid trace' >&2; exit 1; fi
done
valid_trace C skip; valid_trace D skip
printf 'PASS mock A-I positive/negative trace oracle; J covered by installer.sh\n'
printf 'NOT RUN: actual model calls, routing, latency or token measurement\n'
