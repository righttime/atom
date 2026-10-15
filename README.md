# ATOM v0.2

**Install once. Work anywhere. Adapt to every project.**

설치 한 번, 어디서나 사용, 프로젝트에 맞게 동작.

ATOM은 기존 AI coding CLI에서 사용하는 가벼운 Markdown agent 모음입니다. 사람이 제품 방향을 정하고 agent가 허용된 구현·검증·독립 검토를 수행합니다. 별도 runtime, 서버, 데이터베이스, plugin, `atom init`, 프로젝트 `.atom/` 설정은 없습니다.

**Humans describe the goal. ATOM selects the right expertise.**

## 지원

- OpenCode V2 대상(기존 2.0.19 검증 기록은 아래 참고). Codex·Claude Code에는 설치 adapter를 추가하지 않습니다. 역할 본문을 제공한 정책 실험과 native 설치·위임 검증은 구분합니다.
- POSIX shell 기반 설치기. macOS에서 검증; Windows native shell은 지원하지 않습니다.
- `opencode`와 기본 shell 도구, `sha256sum` 또는 `shasum`이 필요합니다. Python/Node/npm 의존성은 없습니다.
- **Model-agnostic:** 모든 agent는 `model`을 생략합니다. 모델·provider·variant 선택은 OpenCode와 사용자만 관리하며, child agent는 OpenCode의 기본 상속을 따릅니다. ATOM은 모델을 선택·변경하거나 오류 시 자동 전환하지 않습니다.

## 설치

저장소 checkout에서:

```sh
./atom install --ai opencode --dry-run
./atom install --ai opencode
./atom status
```

`atom`을 어느 디렉터리에서나 실행하려면 checkout의 절대 경로를 shell의 `PATH`에 추가하세요. 배포 파일 `agents/`, `skills/`가 필요하므로 checkout을 유지합니다.

```sh
export PATH="/absolute/path/to/atom:$PATH"
atom install --ai opencode
```

모든 설치 작업은 **전역이 기본이자 유일한 범위**입니다. `--global`과 프로젝트별 설치는 지원하지 않습니다. 대상은 `opencode debug paths config`로 발견한 디렉터리의 `agents/`와 `skills/atom-routing.md`입니다. OpenCode가 인식하는 `XDG_CONFIG_HOME`, `OPENCODE_CONFIG_DIR` override를 그대로 따릅니다. 기존 전역 `AGENTS.md`나 Build 설정을 수정하지 않습니다.

새 agent가 보이지 않으면 OpenCode를 다시 열거나 native `opencode reload`를 사용하세요. 설치기가 service를 자동 재시작하거나 현재 session을 변경하지는 않습니다.

## 사용

일반 Build 세션에서 자연어로 목표를 설명하세요. Native `atom-routing` Skill과 Agent description이 전문가 선택을 유도합니다. 별도 Router Agent는 없습니다. Skill 발견은 자동 실행을 보장하지 않으며, 선택은 현재 모델과 host permission에 의존하는 prompt 기반 동작입니다.

| 자연어 요청 | 위임 대상 |
| --- | --- |
| 이 기능이 가능한지, 구현 전에 접근 방법을 검토해 줘 | Planner |
| 기존 설정 화면을 분석하고 UX 개선 방향을 제안해 줘 | Designer |
| 좋아, 그 설계대로 구현해 줘 | Developer → 독립 Reviewer |
| 현재 변경 사항을 독립적으로 검토해 줘 | Reviewer |
| 최종 검증하고 PR 초안을 준비해 줘. 생성은 하지 마 | QA |

코드 설명·함수 이름 추천·작은 예제에는 위임이나 무거운 계획을 요구하지 않습니다. 사용자가 명시한 Agent 선택은 존중합니다. 기존 직접 선택도 유지됩니다: agent 목록, `Ctrl+X` 다음 `A`, `Shift+Tab`(사용자 keybind에 따라 다름).

| Agent | 역할 | Mode |
| --- | --- | --- |
| `atom-planner` | 자연어 의도에 맞춘 Explore / Design / Plan / Deep Dive | `all` |
| `atom-designer` | 신규 UI/UX 설계, 기존 흐름·접근성·일관성 검토 | `all` |
| `atom-developer` | 요청된 구현부터 PR까지 책임, 검증·독립 검토·수정·Insight | `all` |
| `atom-reviewer` | 요약을 믿지 않고 실제 staged/unstaged diff·새 파일·요구사항 검토 | `all` |
| `atom-qa` | 요청된 최종 검증부터 PR까지 책임, 범위 내 수정 전달·재검증 | `all` |

```sh
opencode run --agent atom-planner "이 아이디어의 가능성만 간단히 검토해 줘"
opencode run --agent atom-developer "승인된 계획을 구현하고 검토해 줘"
opencode run --agent atom-developer "이 수정을 구현하고 테스트·검토 후 PR까지 생성해 줘"
opencode run --agent atom-qa "현재 변경을 최종 검증하고 필요한 수정 처리 후 PR까지 생성해 줘"
opencode run --agent atom-reviewer "현재 변경을 요구사항과 대조해 검토해 줘"
```

고정 workflow는 없습니다. 프로젝트의 stack·구조·컨벤션·`AGENTS.md`·skills·테스트·권한은 OpenCode의 native context를 사용합니다. Superpowers는 선택 사항이며 기존 skills를 설치·복제·덮어쓰지 않습니다. 이미 승인된 작업에 불필요한 재승인·commit·문서 생성 절차를 추가하지 않습니다.

Developer는 foreground Reviewer 결과를 받은 뒤 blocking finding을 수정하고 필요한 검증·재검토를 수행합니다. **같은 작업 묶음당 최초 검토를 포함해 최대 3회 호출**하며 실패·불완전한 호출도 횟수에 포함합니다. 한도에 도달하면 미해결 문제를 보고하고 성공을 주장하지 않습니다.

Build는 사용자 목표·승인 요구사항·acceptance criteria·이전 결정·제외 범위·사용자 변경·검증 및 미해결 문제를 child 호출 메시지로 전달하고, 결과를 같은 대화에 반영합니다. Child가 전체 부모 대화를 자동 상속한다고 가정하지 않습니다. 영구 Context 파일은 만들지 않습니다.

Developer child가 **구조적 depth limit** 때문에 Reviewer를 중첩 호출할 수 없으면 실제 수정·검증 근거와 남은 검토 예산을 부모에 반환합니다. 부모 Build가 sibling Reviewer를 호출하고, 필요한 수정은 기존 Developer child를 재개해 처리합니다. 실패한 중첩 시도도 3회에 포함합니다. 이는 권한 거부의 대체 경로가 아닙니다. denied/pending 권한이면 부모·다른 도구로 재시도하지 않고 차단을 보고합니다.

ATOM Insight는 대화 안의 간결한 Markdown입니다. 완료 보고서를 길게 만드는 대신 **변경된 동작과 중요한 설계 판단을 빠르게 이해**하도록 돕습니다. 설명 깊이는 변경 줄 수가 아니라 이해하기 어려운 이유로 선택합니다.

- 사소한 변경: 몇 줄의 Markdown만 제공합니다.
- 동작/API 변경: 근거가 있는 Before/After와 대표 입력·출력.
- 계층 간 흐름: 짧은 데이터 흐름 설명, 필요한 경우 작은 Mermaid와 텍스트 대안.
- 알고리즘·상태 전이: 중요한 규칙과 입력 하나의 단계 추적.
- 실제 소스에서 확인한 사실, 실행한 검증 결과, 실행하지 않은 개념 예시를 구분합니다. Reviewer `PASS`는 해당 범위의 코드 검토이지 독립 runtime 테스트나 무결함 보장이 아닙니다.

Insight 초안이 제공되면 Reviewer가 **기존 코드 검토 호출 안에서** 핵심 설명도 소스와 대조합니다. 별도 Insight Reviewer 호출이나 필수 초안 파일은 없습니다. 기본적으로 영구 결과물을 만들지 않고, 필요한 설계 결정만 기존 유지 문서에 보존합니다. Git 범위로 설명을 재생성할 수 있지만 당시 테스트 결과·화면·기록하지 않은 의도는 이력만으로 복원하지 않습니다. 전용 Insight Agent/Skill/DB/Runtime은 없습니다.

### PR 책임과 승인

- **Developer에게 구현부터 PR까지 요청:** Developer가 구현 → 테스트 → 독립 Reviewer → 수정·재검토 → Commit → 일반 Push → PR 생성을 책임집니다. QA는 필수 단계가 아닙니다.
- **QA에게 최종 검증부터 PR까지 요청:** QA가 검증·후속 수정 전달·재검증·독립 검토 근거 확인·Commit·Push·PR을 책임집니다. 도움을 받아도 최초 책임자는 유지하며 사용자에게 일상적인 primary 전환을 요구하지 않습니다.
- QA의 구현 결함은 기본적으로 Developer에게 재현·범위·baseline·사용자 변경·검증 결과·남은 검토 횟수·전달 한계와 함께 foreground 위임합니다. `atom-developer`의 `all` mode는 이 bounded helper 실행을 위한 것입니다. QA 직접 편집은 사용자가 명시적으로 승인한 작은 수정이고 프로젝트 역할 규칙과 host 권한이 허용할 때만 가능합니다. 포괄적인 `edit deny`는 제거하지만 무제한 구현 권한을 부여하지 않습니다.
- QA/Developer 간 전달에도 **동일 묶음 전체 최대 3회** Reviewer 예산을 공유합니다. 최종 변경을 커버하는 실제 독립 `PASS`와 필요한 검사 통과 없이 publish하지 않습니다. Reviewer는 소유권을 넘겨받거나 runtime 검증을 대신하지 않습니다.
- 명시적인 **PR 생성 요청은 해당 범위의 Commit·비기본 작업 브랜치 일반 Push·PR 생성을 승인**합니다. 단계별·브랜치명별 대화 재승인을 요구하지 않습니다. 단순 테스트·PR 요약·PR review 요청에는 이 승인이 없습니다. `local-only`, `no-commit`, `no-push` 등 명시적 제한과 host permission은 우선합니다.
- Commit/Push 전 main/master·실제 remote-default가 아닌 작업 브랜치인지와 포함할 변경을 확인하고, 필요하면 기존 작업을 보존하며 작업 브랜치를 만듭니다. 외부 변경 전 repository·remote·push ref·PR base를 확인합니다. 기본 브랜치 직접 Push(`HEAD:main` 포함), Force Push, 이력 재작성·파괴적 명령·무관한 변경은 PR 요청만으로 승인되지 않습니다. **Merge는 사용자의 별도 명시적 결정**이 필요하며 auto-merge도 켜지 않습니다.
- Jira 연동이 명시적으로 요청되지 않은 작업은 Jira를 변경하지 않습니다. GitHub helper 등은 기존 host/프로젝트 지침에 따라 사용하되 책임과 권한을 넘기거나 넓히지 않습니다. 실제 성공 응답의 URL만 생성된 PR로 보고합니다.

일반 개발은 현재 디렉터리에서 진행하며 worktree는 실제 병렬·격리 필요가 있을 때만 사용자와 협의합니다. 별도 Router/Orchestrator는 없고 작은 native routing Skill 하나만 배포합니다. 기존 TDD·검증·review Skill을 호환되는 범위에서 재사용하며, 승인된 작업에 Skill이 불필요한 Human Gate를 추가하지 않도록 합니다.

OpenCode는 native `subagent`와 agent mode/permission을 사용합니다. Codex·Claude Code에서는 해당 host가 실제 제공하는 독립 agent/session 기능을 사용하며 OpenCode frontmatter·tool을 그대로 지원한다고 가정하지 않습니다. 독립 실행이나 위임이 없으면 구체적인 handoff/blocker를 보고하고 가능한 검증만 계속합니다. 자신을 독립 Reviewer로 간주하거나 host denial을 다른 CLI/도구로 우회하지 않습니다.

## 업데이트·제거

먼저 checkout을 원하는 배포 버전으로 업데이트한 뒤 실행하세요. `atom update`는 현재 로컬 배포를 적용하며 인터넷 다운로드·self-update·npm 설치를 하지 않습니다.

```sh
atom update --ai opencode --dry-run
atom update --ai opencode
atom status
atom uninstall --ai opencode --dry-run
atom uninstall --ai opencode
```

- 전역 config의 `.atom-manifest`에 설치 버전과 파일별 SHA-256을 기록합니다.
- Install은 모든 source와 대상 충돌을 먼저 확인합니다. 충돌이 있으면 복사 전에 중단합니다.
- Update는 소유권과 checksum이 확인된 파일만 교체하고 누락 파일을 복구합니다. 변경·미소유·unsafe 파일은 보존하고 skipped로 보고합니다.
- Uninstall은 변경되지 않은 소유 파일만 제거합니다. 수정된 파일과 그 ownership 기록은 남깁니다. OpenCode config 디렉터리 전체를 삭제하지 않습니다.
- 기존 수동 복사본은 내용이 같아도 자동 인수하지 않습니다. 소유권이 불명확한 파일은 사용자가 확인한 뒤 **agent 검색 경로 밖에 백업 이동**하고 다시 설치하세요. `--force`는 없습니다.
- Status는 경로, 배포/설치 버전, 설치·누락·수정·충돌 파일을 표시합니다. Dry-run은 파일·디렉터리·manifest·lock을 생성하거나 변경하지 않습니다.
- 처리되지 않은 충돌이나 실행 실패는 nonzero exit입니다. Update/uninstall은 안전한 항목을 처리하면서 충돌 항목을 보존할 수 있습니다.

## 안전 경계와 제한

기존 사용자 agents, skills, `AGENTS.md`, model/provider 설정, 전역 permissions, 다른 CLI 설정은 수정하지 않습니다. ATOM이 소유한 다섯 Agent와 routing Skill만 checksum 정책에 따라 관리합니다. Agent permission에는 권한을 넓히는 `allow` 규칙이 없으며 advisory profiles의 `edit` denial 등 필요한 제한만 추가합니다.

Prompt는 sandbox가 아닙니다. Shell·테스트·MCP는 외부 영향을 줄 수 있고 child agent는 자신의 권한을 사용합니다. Agent는 우회하지 않도록 지시되지만 실제 보안 경계는 host permission/policy입니다. 파괴적 작업·배포·범위 밖 변경·아직 승인되지 않은 외부 mutation은 별도 명시적 승인과 host 권한이 필요합니다. 명시적인 PR 생성 요청은 위 범위의 승인이지 host permission 우회가 아닙니다.

Reviewer는 실제 diff·소스·테스트 코드를 읽기 중심 shell 명령으로 조사할 수 있습니다. 테스트 실행·빌드는 Developer/QA 책임이며, 명령별 보안 시스템이나 shell 전체 차단을 추가하지 않습니다.

설치기는 symlink config/상위 경로/agent 디렉터리를 거부하고 symlink 파일을 보존합니다. `.atom-lock`으로 동시 ATOM mutation을 막고, 일반 오류·종료 signal에는 변경 파일을 rollback합니다. 이 잠금은 다른 편집기나 악의적인 동시 filesystem 변경을 막지 않습니다. `SIGKILL`·전원 손실에는 rollback을 보장하지 않으며 stale lock/잔여 staging 파일을 남길 수 있습니다. 해당 작업이 종료됐는지 확인하고 백업과 ownership을 점검한 뒤 복구하세요. Ownership을 잃은 파일은 자동 삭제·인수하지 않습니다.

3회 검토 제한은 prompt 계약이고 `steps`는 추가 model-step 상한입니다. 특정 모델의 준수, 버그 없는 결과, 30–60분 무중단 실행을 보장하지 않습니다. 권한 차단·모델 오류·미해결 finding은 정직하게 보고합니다.

## 검증

```sh
sh -n atom
sh -n tests/installer.sh
sh -n tests/opencode.sh
sh -n tests/ownership.sh
sh -n tests/routing.sh
sh tests/installer.sh
```

Filesystem suite는 가짜 OpenCode path probe와 격리된 임시 config만 사용합니다. 실제 사용자 config에는 접근하지 않습니다. Clean/repeated install, update, uninstall, dry-run, 충돌·수정 보존, 누락 복구, source/checksum 오류, 경로 override, symlink, rollback, lock, 다른 agent·skill·설정 보존을 검증합니다.

`routing.sh`는 별도 임시 config에 배포본을 설치하고 일반 Build에서 Agent/Skill 이름 없는 자연어 요청을 실행합니다. Node는 격리된 vanilla JS 설정 fixture의 검증에만 필요하며 ATOM 설치 의존성이 아닙니다. A/B/D 읽기 전용, C 구현, E 검증·PR 준비(no-publish), F 단순 질문, G 같은 세션의 이전 결정 전달을 조사합니다. 실제 child/session/tool 로그와 diff를 보존합니다. 자동 guard와 별도로 **호출 메시지의 이전 결정·수정 주체·테스트 실행·독립 검토 순서·불필요한 승인 질문**을 로그에서 확인해야 합니다. 단순 child 존재나 저장 버튼 부재만으로 의미 검증 PASS를 선언하지 않습니다. 모델 오류 시 fallback 없이 중단하며 이후 모델 실험은 미실행으로 남깁니다.

실제 OpenCode 통합 실험은 비용·시간이 들 수 있으므로 별도 opt-in입니다. 아래 `MODEL`에는 사용자가 사용할 수 있는 모델 ID를 지정합니다. 이 지정은 테스트 실행에만 적용되며 배포 agent나 사용자 설정에는 저장하지 않습니다. 새 CLI 세션이 현재 UI 대화의 모델을 상속한다고 가정하지 말고 재현 가능한 실험에는 모델을 명시하세요. 생략하면 OpenCode 기본 선택을 사용하고, 모델 오류 시 테스트가 실패할 뿐 자동 전환하지 않습니다.

```sh
ATOM_TEST_MODEL='PROVIDER/MODEL' sh tests/opencode.sh
ATOM_TEST_MODEL='PROVIDER/MODEL' sh tests/ownership.sh
ATOM_TEST_MODEL='PROVIDER/MODEL' sh tests/routing.sh
# 별도 선택적 source-prompt 정책 실험 (각 CLI 기본 모델 사용):
ATOM_TEST_HOST=codex sh tests/ownership.sh
ATOM_TEST_HOST=claude sh tests/ownership.sh
```

통합 suite는 JSON 근거 검사용 `jq`가 필요합니다(설치기에는 필요 없음). 임시 XDG 전역 config에 설치하고 서로 다른 두 프로젝트에서 다섯 agent를 실제 호출합니다. Child의 최종 assistant verdict 순서에서 `CHANGES_REQUIRED → PASS`를 확인하고 모델 상속, 사용자 파일 보존, Primary 전환 시 model 유지, 제거를 검사합니다. 상세 근거는 출력된 임시 경로의 로그로 확인할 수 있습니다. Git fixture는 commit 없이 staged draft를 사용하며 ATOM-specific 프로젝트 설정을 만들지 않습니다. 로그는 확인할 수 있도록 보존합니다.

`ownership.sh`는 Developer/QA의 승인·소유권 정책 응답을 검사하고, OpenCode에서는 별도 로컬 Git fixture의 계산 결과·사용자 메모 보존·범위 내 Commit·Developer child 존재·Reviewer 최종 verdict를 자동 확인합니다. **수정 주체·agent의 실제 검사 실행·최종 변경의 검토 순서는 자동 판정하지 않습니다.** 생성된 `ownership-evaluation.md`에 따라 parent/child tool 기록과 최종 diff를 대조하기 전에는 native 역할 전달 성공을 주장하지 않습니다. remote를 설정하지 않고 실제 Push/PR/Merge/Jira 변경은 하지 않습니다. 정책 JSON 응답은 자체 진술이지 원격 동작의 실행 근거가 아닙니다. Codex/Claude 선택은 역할 본문을 명시적으로 전달하는 **정책 전용 실험**이며 native 설치·위임·Commit 검증은 생략합니다. 모델 오류/host 차단은 실패로 남기고 자동 fallback이나 `--auto`는 사용하지 않습니다. Prompt 계약이 모든 모델에서 보장된다는 뜻은 아닙니다.

Insight 평가에는 기존 수정 사례의 간결한 최종 설명, 같은 기존 Reviewer 호출에 전달한 거짓 설명·검증 주장, 세 번째 프로젝트의 할인 계산 단계 설명을 사용합니다. 출력된 임시 경로의 `insight-evaluation.md`에 작은 의미 평가 기준과 이해 확인 질문을 남깁니다. 길이·불필요한 시각화·fixture 보존 guardrail은 자동 검사하지만 **설명 정확성·유용성은 소스/실행 근거와 대조해 평가**합니다. Guardrail 통과만으로 의미 평가 PASS를 주장하지 않습니다. 테스트 로그·평가 자료는 임시 실험 근거이며 설치 패키지나 프로젝트 문서로 배포하지 않습니다.

### 기존 검증 기록

아래 실제 Agent 통합 결과는 기존 실험 기록입니다. 현재 Insight 평가가 추가된 suite의 재실행 성공을 뜻하지 않습니다.

- macOS / OpenCode 2.0.19: filesystem 모의 테스트 **31개 통과**, shell syntax 검사 통과.
- 실제 임시 XDG config: 다섯 agent 설치·호출·제거, 두 프로젝트에서 초기화 없이 사용 확인.
- 실제 native child **2회**: `CHANGES_REQUIRED → Developer 수정·테스트 → PASS`. Child의 최종 assistant 응답을 검사했으며 테스트 stdout을 verdict로 간주하지 않았습니다. 기존 사용자 파일은 보존됐습니다.
- Reviewer는 실제 diff·소스·테스트를 읽기 중심으로 조사했고 runtime 테스트는 Developer가 수행했습니다.
- Designer → QA 전환 시 model/provider/variant 유지, Reviewer child의 native 모델 상속 확인. 테스트에만 단일 model을 지정했으며 배포 설정에는 반영하지 않았습니다.

### v0.1 배포본 재검증 (2026-10-14)

- Filesystem suite **31개 통과**. 소유권 변경은 Agent 본문과 README, opt-in 테스트에 한정하며 설치기·기존 Skill은 변경하지 않습니다.
- 최초 모델 미지정 호출은 `github-copilot/gemini-4-argon`을 선택해 `provider.invalid-request` (`The requested model is not supported`, HTTP 400)로 실패했습니다. 새 CLI 테스트 세션의 기본 선택은 현재 UI 대화의 선택 모델과 달랐습니다. 모델 목록 등록은 해당 계정에서의 실제 호출 성공을 보장하지 않습니다.
- 현재 대화와 같은 `openai/gpt-6.1-sol`을 테스트 인자로만 명시한 `ATOM_TEST_MODEL=openai/gpt-6.1-sol sh tests/opencode.sh`는 통과했습니다. 다섯 agent 호출, primary 모델 유지, native Reviewer **2회**의 `CHANGES_REQUIRED → 수정·테스트 → PASS`, child 모델 상속과 설치·제거를 확인했습니다. Insight 출력은 소스·실행 근거와 대조해 작은 설명·거짓 설명 지적·할인 경계/개념 예시 구분도 확인했습니다. 사용자 전역 모델·provider·권한 설정은 변경하지 않았습니다.
- `ATOM_TEST_MODEL=openai/gpt-6.1-sol sh tests/ownership.sh`도 통과했습니다. 실제 응답으로 발견된 OpenCode JSON 출력의 문자열 인코딩 불일치(`jq -rs` → `jq -s`)를 수정했습니다. 별도 QA 세션이 parent/child tool 기록·최종 diff·commit을 대조해 두 역할의 실제 수정 주체·수정 후 테스트·독립 검토 후 범위 내 로컬 Commit과 소유권 유지를 확인했습니다. QA 사례에서는 Developer helper의 Reviewer 호출이 depth limit으로 실패했으며, 실패를 포함한 **2/3회** 예산 안에서 QA parent가 Reviewer `PASS`를 확보했습니다. Developer 사례는 **1/3회**였습니다. Fixture는 remote를 설정하지 않았고 실제 Push·PR·Merge·Jira 변경은 하지 않았습니다.
- Codex 0.160.1 역할 본문 정책 실험: 기존 QA는 독립 검토 필요·승인된 작은 직접 수정 항목에서 기대와 다르게 응답해 실패했고, 변경 후 Developer/QA는 각 13개 정책 판단을 통과했습니다. 이는 실제 CLI 출력에 대한 정책 회귀 근거이며 native 위임이나 원격 publish의 실행 증거는 아닙니다.
- Claude Code 2.1.259도 변경 후 Developer/QA 각 13개 정책 판단을 통과했습니다. OpenCode와 마찬가지로 모델·provider·권한을 바꾸지 않았으며 Codex/Claude 실험은 독립적인 플랫폼 정책 실험이지 차단된 OpenCode 작업의 우회가 아닙니다.

미검증: 다른 OS/OpenCode 버전·model/provider, 실제 원격 commit/push/PR/배포, 3회 한도 소진·context compaction·30–60분 장기 작업, 모든 외부 skill workflow와의 행동 호환성. Superpowers/기존 skills 설치 파일은 변경하지 않으며 개별 지침 충돌은 host/user 정책에 따릅니다.

공식 V2 참고: [Agents](https://opencode.ai/v2/docs/agents), [Permissions](https://opencode.ai/v2/docs/permissions), [Skills](https://opencode.ai/v2/docs/skills), [Keybinds](https://opencode.ai/v2/docs/cli/keybinds).
