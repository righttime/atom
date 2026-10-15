#!/bin/sh
# Static prompt contract regression, NOT modeled behavior or host enforcement.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
has() { grep -Fq -- "$2" "$ROOT/$1" || { printf 'FAIL static contract: %s: %s\n' "$1" "$2" >&2; exit 1; }; }
has agents/atom-developer.md 'implementation request also authorizes a meaningful scoped local commit'
printf 'PASS static A: implementation -> reviewed local commit only\n'
has agents/atom-developer.md 'ordinary push to a **non-default work branch**, and PR creation'
has skills/atom-routing.md '| Implement through PR creation | `atom-developer` |'
printf 'PASS static B: implementation + PR -> Developer owns publish\n'
has agents/atom-qa.md 'Verification alone authorizes checks and results only: no commit, push, or PR creation'
has agents/atom-qa.md 'Do not automatically delegate fixes'
printf 'PASS static C: verification only -> checks/report only\n'
has agents/atom-qa.md 'When no blockers remain, complete the authorized scoped commit'
has skills/atom-routing.md '| Verify through PR creation | `atom-qa` |'
printf 'PASS static D: verification + PR -> QA owns publish, not implicit fixes\n'
for file in agents/atom-developer.md agents/atom-qa.md skills/atom-routing.md; do
  has "$file" 'PR preparation or a PR draft is not publication approval'
done
printf 'PASS static E: PR preparation/draft -> no publish\n'
for file in agents/atom-developer.md agents/atom-qa.md; do
  has "$file" 'Do not modify Jira unless Jira integration is explicitly requested'
  has "$file" 'no-commit/no-push/local-only'
  has "$file" 'force'
done
has skills/atom-routing.md 'including "do not touch Jira"'
printf 'PASS static F: Jira exclusions and explicit delivery limits survive routing\n'
has agents/atom-developer.md '## Default completion report'
has agents/atom-developer.md 'Generate Insight only when the user explicitly asks'
has agents/atom-developer.md 'A request to implement the Insight feature is not a request to generate a presentation'
has skills/atom-routing.md '| Explicitly present or visually explain an implementation/change | `atom-developer` |'
has agents/atom-developer.md 'relevant Git history/diff'
has agents/atom-developer.md '**source-confirmed facts**'
has agents/atom-developer.md '**actual test/measurement results**'
has agents/atom-developer.md '**conceptual examples not executed**'
has agents/atom-developer.md 'comparison graphs only from actual measurements'
has agents/atom-developer.md 'outside the repository'
has agents/atom-developer.md 'actual absolute HTML path'
has agents/atom-developer.md 'explicitly say when it was not performed or was blocked'
has agents/atom-developer.md 'presentation-only request does not authorize'
printf 'PASS static on-demand Insight trigger, evidence, temporary artifact and delivery contract (not runtime behavior)\n'
for file in "$ROOT"/agents/*.md; do
  if sed -n '1,/^$/p' "$file" | grep -Eq '^(model:|[[:space:]]*allow:)'; then
    echo 'FAIL unexpected model/permission expansion' >&2; exit 1
  fi
done
printf 'PASS static model/permission guard; no runtime behavior established\n'
