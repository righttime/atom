---
name: ATOM Native Routing
description: Use for substantive software work to select the right ATOM expert from natural language, including feasibility or approach exploration, UI/UX analysis, implementing an approved change, independent code review, and final verification or PR preparation. Also use for follow-ups such as "now implement that design". Not for simple explanations, naming suggestions, or small examples. No need for the user to name an agent.
---

# ATOM native routing

Humans describe the goal. ATOM selects the right expertise. Use only the host's native agents, current session, and delegation messages. No router agent, runtime, persistent context file, model selection, configuration changes, or required project initialization.

## Select the smallest sufficient action

- Respect explicit agent selection and the user's scope. A directly selected ATOM expert handles its own role; do not route it back to itself or start a routing cycle.
- Answer simple explanations, function naming, small examples, and trivial questions directly. Do not load more workflow skills, plan, or delegate just to answer them.
- For substantive work in Build, call the matching existing expert with the native `subagent` tool in foreground and wait for its result. Do not merely announce a role or answer as if that expert ran. Use semantic intent, not a requirement for exact keywords:

| Intent | Agent ID | Boundary |
| --- | --- | --- |
| Feasibility, alternatives, requirements, approach before implementation | `atom-planner` | Read-only; brief exploration unless a detailed plan is requested |
| UI/UX, screen usability, accessibility, existing interface analysis | `atom-designer` | Inspect relevant project UI; recommendations, not implementation |
| Implement, fix, or continue an approved design | `atom-developer` | Implementation, relevant checks, independent Reviewer loop |
| Independent review of actual current changes | `atom-reviewer` | Read-only review, not a rewrite or runtime test campaign |
| Final verification, release readiness, PR preparation | `atom-qa` | Risk-based checks and PR draft; publishing only if explicitly authorized |

Choose by the requested deliverable: "implement this UI improvement" is Developer; "analyze its UX" is Designer. Do not run all five roles for one request. QA is not mandatory after Developer. Ask only when an ambiguity genuinely blocks correct authorized work. Do not repeat brainstorming, design approval, or planning for already approved requirements.

## Carry context in the call

Before delegating, assemble the relevant facts from this conversation and inspected project state. Pass a compact message, not just the last user sentence:

- User goal and requested deliverable; approved requirements and acceptance criteria.
- Important earlier decisions and their source, including negative constraints such as automatic saving and **no save button**. Never invent missing approval or decisions.
- Exclusions and delivery limits, especially no-commit/no-push/no-PR; current working directory and relevant paths.
- Known baseline, existing staged/unstaged/untracked user work, owned paths/hunks. If not inspected, say unknown and ask the expert to inspect before editing.
- Actual verification results, unresolved findings, previous expert conclusions as claims to verify, and shared Reviewer calls already used out of three.

Children start with fresh context; do not assume they receive the whole parent conversation. Use returned findings to continue this same user conversation. Keep earlier decisions unless the user changes them. Resume the same Developer child with `sessionID` for bounded follow-up fixes when available, carrying any new constraints explicitly. No permanent handoff file is required.

## Preserve review and permissions

Developer owns implement → checks → independent Reviewer → valid blocking fixes → recheck/re-review. A Reviewer must actually execute in a separate session, inspect the final batch, and return `PASS`, `CHANGES_REQUIRED`, or `INCOMPLETE`. Wait before editing reviewed files. Share **at most three Reviewer calls total per meaningful batch**, including failed/incomplete attempts, across all helpers and the parent; never reset the budget on a handoff. Pass the requirements, baseline/user work, actual diff/new paths, checks, previous finding IDs, and call number in every review request.

If native nesting is unavailable solely because of the host's structural depth limit, the Developer returns the implementation/check evidence, remaining review budget, and a review-pending handoff. The parent may call a sibling `atom-reviewer` in foreground, then resume Developer for valid fixes and repeat within that same budget. This is native coordination in the existing conversation, not independent self-review. Do not declare success until the final content has a real independent PASS and required checks pass.

This depth-limit handoff is **not** permission fallback: a denied or pending action, denied agent, or denied review must not be retried through the parent, another agent/tool, shell, MCP, changed configuration, or `--auto`. Report the exact blocker and continue only independent permitted work. A missing expert or model error is not successful routing; never select/change models or providers or silently substitute a role. No push, PR creation, merge, external mutation, or secret access is authorized by routing itself. Honor host and project instructions over generic skill ceremonies.

Report actual agent IDs, results, review status/call count, and remaining blockers concisely. Distinguish successful delegation, successful context transfer, runtime checks, and untested behavior; agent-like prose or skill discovery alone proves none of these.
