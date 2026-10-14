#!/bin/sh
# Static routing metadata contract, not proof of native delegation.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
for role in planner designer developer reviewer qa; do
  description=$(sed -n 's/^description: //p' "$ROOT/agents/claude/atom-$role.md")
  case "$description" in
    *'Use for '*'; not for '*'Simple questions and ordinary conversation do not need this agent.'*) ;;
    *) echo "Missing intent/exclusion/simple-question boundary: $role" >&2; exit 1 ;;
  esac
  printf 'PASS %s routing description contract (static only)\n' "$role"
done
