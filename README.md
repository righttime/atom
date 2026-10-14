# ATOM v0.1

**Install once. Work anywhere. Adapt to every project.**

설치 한 번, 어디서나 사용, 프로젝트에 맞게 동작.

ATOM은 기존 AI coding CLI에서 사용하는 가벼운 Markdown agent 모음입니다. 사람이 제품 방향을 정하고 agent가 허용된 구현·검증·독립 검토를 수행합니다. 별도 runtime, 서버, 데이터베이스, plugin, `atom init`, 프로젝트 `.atom/` 설정은 없습니다.

## 지원

- OpenCode **2.0.19**, Claude Code **2.1.259** 검증 대상. 다른 버전·Codex 호환성은 아직 주장하지 않습니다. 실제 실행 결과와 제한은 아래 검증 기록을 참고하세요.
- POSIX shell 기반 설치기. macOS에서 검증; Windows native shell은 지원하지 않습니다.
- 선택한 CLI(`opencode` 또는 `claude`)와 기본 shell 도구, `sha256sum` 또는 `shasum`이 필요합니다. 설치기에 Python/Node/npm 의존성은 없습니다.
- **Model-agnostic:** 모든 agent는 `model`을 생략합니다. 모델·provider·variant 선택은 host CLI와 사용자만 관리합니다. OpenCode child는 기본 상속을, Claude child는 사용자의 subagent 모델 설정을 포함한 native 선택 규칙을 따릅니다. ATOM은 호출 모델을 지정하거나 모델 설정·fallback을 변경하지 않습니다. ATOM 자체의 오류 후 모델 전환도 없습니다.

## 설치

저장소 checkout에서:

```sh
./atom install --ai opencode --dry-run
./atom install --ai opencode
./atom status
```

`atom`을 어느 디렉터리에서나 실행하려면 checkout의 절대 경로를 shell의 `PATH`에 추가하세요. 배포 파일 `agents/`가 필요하므로 checkout을 유지합니다.

```sh
export PATH="/absolute/path/to/atom:$PATH"
atom install --ai opencode
```

모든 설치 작업은 **전역이 기본이자 유일한 범위**입니다. `--global`과 프로젝트별 설치는 지원하지 않습니다. 대상은 `opencode debug paths config`로 발견한 디렉터리의 `agents/`입니다. OpenCode가 인식하는 `XDG_CONFIG_HOME`, `OPENCODE_CONFIG_DIR` override를 그대로 따릅니다.

새 agent가 보이지 않으면 OpenCode를 다시 열거나 native `opencode reload`를 사용하세요. 설치기가 service를 자동 재시작하거나 현재 session을 변경하지는 않습니다.

### Claude Code 전역 설치

```sh
./atom install --ai claude --dry-run
./atom install --ai claude
./atom status --ai claude
./atom update --ai claude
./atom uninstall --ai claude
```

기본 대상은 `~/.claude/agents/`입니다. shell에 `CLAUDE_CONFIG_DIR`을 지정했다면 그 디렉터리의 `agents/`를 사용합니다. 안전을 위해 절대 경로를 사용하세요. 설정 파일 안에만 있는 `env.CLAUDE_CONFIG_DIR`은 설치기가 해석하지 않으므로 동일한 경로를 shell에 명시하세요. 프로젝트별 초기화·`.claude/agents/` 복사·plugin 설치는 필요 없습니다.

```sh
CLAUDE_CONFIG_DIR=/absolute/path/to/claude-config ./atom install --ai claude
```

CLI별 source는 OpenCode `agents/atom-*.md`, Claude `agents/claude/atom-*.md`입니다. 기존 사용자 설정, `CLAUDE.md`, Skills, plugin과 다른 Agent 파일은 수정하지 않습니다. 처음 `agents/` 디렉터리가 만들어진 실행 중 세션은 다시 열어야 할 수 있습니다. 프로젝트/managed/CLI 정의의 동명 Agent는 전역 정의보다 우선할 수 있으며 ATOM은 이를 덮어쓰지 않습니다.

## 사용

어느 프로젝트에서든 `opencode`를 열고 agent 목록에서 선택합니다. 기본 TUI 단축키는 `Ctrl+X` 다음 `A`, 순환은 `Shift+Tab`입니다. 사용자 keybind 설정에 따라 다를 수 있습니다.

| Agent | 역할 | OpenCode Mode |
| --- | --- | --- |
| `atom-planner` | 자연어 의도에 맞춘 Explore / Design / Plan / Deep Dive | `primary` |
| `atom-designer` | 신규 UI/UX 설계, 기존 흐름·접근성·일관성 검토 | `primary` |
| `atom-developer` | 승인된 구현, 위험도에 맞는 검증, 독립 검토 반복, Insight | `primary` |
| `atom-reviewer` | 요약을 믿지 않고 실제 staged/unstaged diff·새 파일·요구사항 검토 | `all` |
| `atom-qa` | 요청된 최종 검증과 명시적으로 요청된 PR 작업 | `primary` |

```sh
opencode run --agent atom-planner "이 아이디어의 가능성만 간단히 검토해 줘"
opencode run --agent atom-developer "승인된 계획을 구현하고 검토해 줘"
opencode run --agent atom-reviewer "현재 변경을 요구사항과 대조해 검토해 줘"
```

고정 workflow는 없습니다. 프로젝트의 stack·구조·컨벤션·`AGENTS.md`·skills·테스트·권한은 OpenCode의 native context를 사용합니다. Superpowers는 선택 사항이며 기존 skills를 설치·복제·덮어쓰지 않습니다. 이미 승인된 작업에 불필요한 재승인·commit·문서 생성 절차를 추가하지 않습니다.

### Claude Code 사용과 차이

어느 프로젝트에서든 native 세션 Agent로 실행합니다:

```sh
claude --agent atom-planner "이 아이디어의 가능성만 간단히 검토해 줘"
claude --agent atom-designer "현재 로그인 흐름의 접근성을 검토해 줘"
claude --agent atom-developer "승인된 계획을 구현하고 검토해 줘"
claude --agent atom-reviewer "현재 변경을 요구사항과 대조해 검토해 줘"
claude --agent atom-qa "현재 변경의 최종 테스트를 수행해 줘"
```

| 항목 | OpenCode | Claude Code |
| --- | --- | --- |
| 정의 | `description`, `mode`, `steps`, `permissions` | `name`, `description`, `tools`/`disallowedTools`, `maxTurns` |
| Developer 실행 | primary Agent | `claude --agent atom-developer`로 주 세션 실행 권장 |
| 독립 검토 | native `subagent` | native `Agent`, `subagent_type: "atom-reviewer"` |
| 검토 대기 | foreground 호출 | foreground 가능 시 사용; host가 비동기 실행하면 실제 completion을 기다림 |
| 프로젝트 적응 | native context·`AGENTS.md` | native context·`CLAUDE.md` 및 관련 `AGENTS.md`, 기존 native Skill |
| 모델 | host 기본 상속 | host 모델 선택 및 사용자 subagent 설정 존중 |

Claude Developer도 별도 context의 Reviewer 결과를 받은 다음 수정·재검토합니다. 검토 중인 파일을 결과 도착 전에 수정하지 않습니다. **실패·불완전 호출을 포함한 최대 3회 검토**는 양쪽에서 같은 prompt 계약입니다. Claude interactive fork mode에서는 background 실행이므로 “항상 foreground”를 보장하지 않습니다. Developer를 subagent로 위임한 경우 native nesting 한도나 권한 때문에 Reviewer 호출이 불가능할 수 있습니다. 이때 설정을 변경하거나 self-review를 독립 검토로 간주하지 않고 `INCOMPLETE`와 주 세션 실행 방법을 안내합니다. 새로운 실행 엔진이나 orchestration은 없습니다.

Claude Code 2.1.259의 `claude agents`는 실행 세션 관리 명령이지 설치된 정의 목록이 아닙니다. `/agents` 또는 native 세션 init의 Agent 목록으로 발견 여부를 확인하세요. ATOM `status`는 파일 소유권·상태 검사이며 host가 실제 Agent를 실행했다는 증거는 아닙니다.

Developer는 foreground Reviewer 결과를 받은 뒤 blocking finding을 수정하고 필요한 검증·재검토를 수행합니다. **같은 작업 묶음당 최초 검토를 포함해 최대 3회 호출**하며 실패·불완전한 호출도 횟수에 포함합니다. 한도에 도달하면 미해결 문제를 보고하고 성공을 주장하지 않습니다.

ATOM Insight는 대화 안의 간결한 Markdown입니다. 완료 보고서를 길게 만드는 대신 **변경된 동작과 중요한 설계 판단을 빠르게 이해**하도록 돕습니다. 설명 깊이는 변경 줄 수가 아니라 이해하기 어려운 이유로 선택합니다.

- 사소한 변경: 몇 줄의 Markdown만 제공합니다.
- 동작/API 변경: 근거가 있는 Before/After와 대표 입력·출력.
- 계층 간 흐름: 짧은 데이터 흐름 설명, 필요한 경우 작은 Mermaid와 텍스트 대안.
- 알고리즘·상태 전이: 중요한 규칙과 입력 하나의 단계 추적.
- 실제 소스에서 확인한 사실, 실행한 검증 결과, 실행하지 않은 개념 예시를 구분합니다. Reviewer `PASS`는 해당 범위의 코드 검토이지 독립 runtime 테스트나 무결함 보장이 아닙니다.

Insight 초안이 제공되면 Reviewer가 **기존 코드 검토 호출 안에서** 핵심 설명도 소스와 대조합니다. 별도 Insight Reviewer 호출이나 필수 초안 파일은 없습니다. 기본적으로 영구 결과물을 만들지 않고, 필요한 설계 결정만 기존 유지 문서에 보존합니다. Git 범위로 설명을 재생성할 수 있지만 당시 테스트 결과·화면·기록하지 않은 의도는 이력만으로 복원하지 않습니다. 전용 Insight Agent/Skill/DB/Runtime은 없습니다.

Developer는 명시적으로 승인된 **비기본 작업 브랜치**에서 본인 변경만 stage하고 의미 있는 commit과 검증·검토된 변경의 일반 push를 수행할 수 있습니다. Git mutation 전 현재 브랜치가 main/master 및 실제 remote-default가 아님을 확인합니다. 명시적인 no-commit/no-push 요청과 host 권한은 우선합니다. 기본 브랜치 직접 push, force push, 파괴적인 Git 작업은 기본 금지입니다. 일반 개발은 현재 디렉터리에서 진행하며 worktree는 실제 병렬·격리 필요가 있을 때만 사용자와 협의합니다.

## 업데이트·제거

먼저 checkout을 원하는 배포 버전으로 업데이트한 뒤 실행하세요. `atom update`는 현재 로컬 배포를 적용하며 인터넷 다운로드·self-update·npm 설치를 하지 않습니다.

```sh
atom update --ai opencode --dry-run
atom update --ai opencode
atom status
atom uninstall --ai opencode --dry-run
atom uninstall --ai opencode
```

- 전역 config의 `.atom-manifest`에 설치 버전과 파일별 SHA-256을 기록합니다. OpenCode는 기존 `ATOM1`, Claude는 `ATOM1-CLAUDE` 형식을 사용합니다. 같은 config 경로에서 다른 CLI의 manifest를 발견하면 status를 포함해 중단하여 소유권 혼용을 막습니다. 별도 config 경로를 사용하세요.
- Install은 모든 source와 대상 충돌을 먼저 확인합니다. 충돌이 있으면 복사 전에 중단합니다.
- Update는 소유권과 checksum이 확인된 파일만 교체하고 누락 파일을 복구합니다. 변경·미소유·unsafe 파일은 보존하고 skipped로 보고합니다.
- Uninstall은 변경되지 않은 소유 파일만 제거합니다. 수정된 파일과 그 ownership 기록은 남깁니다. 어느 CLI의 config 디렉터리도 전체 삭제하지 않습니다.
- 기존 수동 복사본은 내용이 같아도 자동 인수하지 않습니다. 소유권이 불명확한 파일은 사용자가 확인한 뒤 **agent 검색 경로 밖에 백업 이동**하고 다시 설치하세요. `--force`는 없습니다.
- Status는 경로, 배포/설치 버전, 설치·누락·수정·충돌 파일을 표시합니다. Dry-run은 파일·디렉터리·manifest·lock을 생성하거나 변경하지 않습니다.
- 처리되지 않은 충돌이나 실행 실패는 nonzero exit입니다. Update/uninstall은 안전한 항목을 처리하면서 충돌 항목을 보존할 수 있습니다.

## 안전 경계와 제한

기존 agents, skills, `AGENTS.md`/`CLAUDE.md`, model/provider 설정, 전역 permissions, 다른 CLI 설정은 수정하지 않습니다. OpenCode Agent permission에는 권한을 넓히는 `allow` 규칙이 없습니다. Claude는 advisory profiles의 Write/Edit/NotebookEdit 및 필요한 Agent 제한을 정의하며 `permissionMode`를 지정하지 않습니다. 도구 목록은 host permission 승인을 대신하지 않습니다.

Prompt는 sandbox가 아닙니다. Shell·테스트·MCP는 외부 영향을 줄 수 있고 child agent는 자신의 권한을 사용합니다. Agent는 우회하지 않도록 지시되지만 실제 보안 경계는 host permission/policy입니다. 파괴적 작업·배포·범위 밖 변경·아직 승인되지 않은 외부 mutation은 별도 명시적 승인과 host 권한이 필요합니다. QA의 PR 생성도 자동 실행하지 않습니다.

Reviewer는 실제 diff·소스·테스트 코드를 읽기 중심 shell 명령으로 조사할 수 있습니다. 테스트 실행·빌드·패키지 설치는 Developer 책임이며, 명령별 보안 시스템이나 shell 전체 차단을 추가하지 않습니다.

설치기는 symlink config/상위 경로/agent 디렉터리를 거부하고 symlink 파일을 보존합니다. `.atom-lock`으로 동시 ATOM mutation을 막고, 일반 오류·종료 signal에는 변경 파일을 rollback합니다. 이 잠금은 다른 편집기나 악의적인 동시 filesystem 변경을 막지 않습니다. `SIGKILL`·전원 손실에는 rollback을 보장하지 않으며 stale lock/잔여 staging 파일을 남길 수 있습니다. 해당 작업이 종료됐는지 확인하고 백업과 ownership을 점검한 뒤 복구하세요. Ownership을 잃은 파일은 자동 삭제·인수하지 않습니다.

3회 검토 제한은 prompt 계약입니다. OpenCode `steps`와 Claude subagent `maxTurns`는 추가 실행 상한이지 Reviewer 호출 수 제한 엔진이 아닙니다. 특정 모델의 준수, 버그 없는 결과, 30–60분 무중단 실행을 보장하지 않습니다. 권한 차단·모델 오류·미해결 finding은 정직하게 보고합니다.

## 검증

```sh
sh -n atom
sh -n tests/installer.sh
sh -n tests/opencode.sh
sh -n tests/claude-installer.sh
sh -n tests/claude.sh
sh -n tests/claude-evidence.sh
sh tests/installer.sh
ATOM_TEST_AI=claude sh tests/installer.sh
sh tests/claude-installer.sh
# jq가 이미 설치된 환경에서만 실행 (설치기는 jq 불필요)
sh tests/claude-evidence.sh
```

Filesystem suite는 가짜 CLI와 격리된 임시 config만 사용합니다. 실제 사용자 config에는 접근하지 않습니다. 두 CLI에 같은 31개 안전성 사례를 적용하고, Claude 전용 suite로 HOME/override·설정/모델/Skills 보존·cross-CLI manifest 충돌·정적 정의를 검사합니다. Evidence parser suite는 합성 로그로 부모 주장, 다른 child, tool stdout, 모델 override, 호출 수 초과를 거부하는지 검사하며 실제 Agent 실행 검증은 아닙니다.

### Claude Code 실제 실행 (opt-in)

```sh
sh tests/claude.sh
```

기존에 인증된 Claude 환경과 `jq`가 필요합니다. 임시 `CLAUDE_CONFIG_DIR`에 전역 설치하고 두 프로젝트에서 5개 Agent를 호출합니다. 사용자 settings에서 **모델 관련 선택만** 임시 config에 반영하고 원본을 변경하지 않습니다. 인증/provider는 호출자의 환경을 사용하며 credentials·hooks·permissions·plugins는 복사하지 않습니다. 인증이 settings에만 있는 환경은 해당 인증을 프로세스 환경으로 제공해야 합니다. 인증 실패 시 자동 로그인·모델 변경·권한 우회 없이 실패합니다.

`--model`/fallback/permission bypass 없이 실행하며 native init 목록으로 5개 발견을 확인합니다. `--forward-subagent-text`로 child assistant 응답을 Agent 호출 ID와 연결하고 **실제 완료 → 성공한 Edit/Write → `sh test_sum.sh` 성공 → 다음 Reviewer 호출**의 이벤트 순서와 2–3회 호출을 검사합니다. 비동기 실행 시작 acknowledgment는 완료가 아니므로 `task_notification`의 `completed`를 요구합니다. 중간 판정 누락·검토 중 편집·최종 PASS 후 편집도 거부합니다. 이 parser는 fixture의 native Edit/Write 경로용이며 Bash-only 수정이나 근거가 없는/다른 로그 형식은 통과시키지 않습니다. 부모 주장·테스트 stdout은 Reviewer verdict로 인정하지 않습니다. 호출 모델 인자 부재와 config 바이트 보존을 검사하고 관측된 모델 이름을 로그로 남깁니다. 사용자가 child 모델을 별도로 설정한 경우 부모와 같은 모델을 강제하지 않습니다.

통합 실행은 비용·시간이 들고 권한 정책에 따라 차단될 수 있습니다. 허용된 기존 host 권한만 사용하며 script가 권한을 완화하지 않습니다. 격리 fixture의 `CLAUDE.md`는 일반 프로젝트 지침이지 ATOM 초기화 파일이 아닙니다. 임시 로그는 실패를 포함해 보존됩니다. 실제 사용자 인증/provider·managed 정책은 완전히 격리되지 않으며, 모든 사용자 Skills와의 행동 호환성을 테스트했다는 뜻은 아닙니다.

실제 OpenCode 통합 실험은 비용·시간이 들 수 있으므로 별도 opt-in입니다. 아래 `MODEL`에는 사용자가 사용할 수 있는 모델 ID를 지정합니다. 이 지정은 테스트 실행에만 적용되며 배포 agent나 사용자 설정에는 저장하지 않습니다. 생략하면 OpenCode 기본 선택을 사용하고, 모델 오류 시 테스트가 실패할 뿐 자동 전환하지 않습니다.

```sh
ATOM_TEST_MODEL='PROVIDER/MODEL' sh tests/opencode.sh
```

통합 suite는 JSON 근거 검사용 `jq`가 필요합니다(설치기에는 필요 없음). 임시 XDG 전역 config에 설치하고 서로 다른 두 프로젝트에서 다섯 agent를 실제 호출합니다. Child의 최종 assistant verdict 순서에서 `CHANGES_REQUIRED → PASS`를 확인하고 모델 상속, 사용자 파일 보존, Primary 전환 시 model 유지, 제거를 검사합니다. 상세 근거는 출력된 임시 경로의 로그로 확인할 수 있습니다. Git fixture는 commit 없이 staged draft를 사용하며 ATOM-specific 프로젝트 설정을 만들지 않습니다. 로그는 확인할 수 있도록 보존합니다.

Insight 평가에는 기존 수정 사례의 간결한 최종 설명, 같은 기존 Reviewer 호출에 전달한 거짓 설명·검증 주장, 세 번째 프로젝트의 할인 계산 단계 설명을 사용합니다. 출력된 임시 경로의 `insight-evaluation.md`에 작은 의미 평가 기준과 이해 확인 질문을 남깁니다. 길이·불필요한 시각화·fixture 보존 guardrail은 자동 검사하지만 **설명 정확성·유용성은 소스/실행 근거와 대조해 평가**합니다. Guardrail 통과만으로 의미 평가 PASS를 주장하지 않습니다. 테스트 로그·평가 자료는 임시 실험 근거이며 설치 패키지나 프로젝트 문서로 배포하지 않습니다.

### 기존 검증 기록

아래 실제 Agent 통합 결과는 기존 실험 기록입니다. 현재 Insight 평가가 추가된 suite의 재실행 성공을 뜻하지 않습니다.

- macOS / OpenCode 2.0.19: filesystem 모의 테스트 **31개 통과**, shell syntax 검사 통과.
- 실제 임시 XDG config: 다섯 agent 설치·호출·제거, 두 프로젝트에서 초기화 없이 사용 확인.
- 실제 native child **2회**: `CHANGES_REQUIRED → Developer 수정·테스트 → PASS`. Child의 최종 assistant 응답을 검사했으며 테스트 stdout을 verdict로 간주하지 않았습니다. 기존 사용자 파일은 보존됐습니다.
- Reviewer는 실제 diff·소스·테스트를 읽기 중심으로 조사했고 runtime 테스트는 Developer가 수행했습니다.
- Designer → QA 전환 시 model/provider/variant 유지, Reviewer child의 native 모델 상속 확인. 테스트에만 단일 model을 지정했으며 배포 설정에는 반영하지 않았습니다.

### 현재 배포본 재검증 (2026-10-14)

- `atom`, `tests/installer.sh`, `tests/opencode.sh`의 shell syntax 검사 통과; filesystem suite **31개 통과**.
- 현재 통합 suite는 첫 Planner 호출에서 OpenCode 기본 모델의 `provider.invalid-request` (`The requested model is not supported`, HTTP 400)로 중단됐습니다. 모델·provider 설정은 변경하지 않았습니다.
- 따라서 새 Insight 평가 사례의 실제 Agent 출력·의미 평가는 아직 미검증이며, 기존 통합 기록과 구분합니다. 사용자가 OpenCode에서 사용 가능한 모델을 선택한 환경에서 opt-in suite 재검증이 필요합니다.

미검증: 다른 OS/OpenCode 버전·model/provider, 실제 원격 commit/push/PR/배포, 3회 한도 소진·context compaction·30–60분 장기 작업, 모든 외부 skill workflow와의 행동 호환성. Superpowers/기존 skills 설치 파일은 변경하지 않으며 개별 지침 충돌은 host/user 정책에 따릅니다.

### Claude 지원 확장 검증 (2026-10-14)

- Shell syntax 및 filesystem 검증: OpenCode **31개**, Claude 공통 **31개**, Claude 전용 **8개** 통과. Evidence parser **17개** 통과는 합성 로그 검증이며 native loop 성공 기록이 아닙니다.
- Claude Code **2.1.259**에서 임시 전역 설치·status·update 및 두 프로젝트의 native init 목록에서 **Agent 5개 발견**을 확인했습니다. Planner/Designer/QA/Reviewer 실제 응답과 Developer 실제 실행을 관측했습니다. 사용자 모델 설정을 반영한 환경에서 실행했고 ATOM 모델 인자·설정 변경은 없습니다.
- Developer가 native Agent로 독립 Reviewer를 **1회** 호출했습니다. Child가 staged diff·소스·테스트·프로젝트 지침을 읽고 실제 덧셈 오류에 `CHANGES_REQUIRED`를 반환했습니다. Child 응답은 parent Agent 호출 ID로 확인했습니다.
- **수정·재검토는 미검증:** host가 fixture Edit를 미승인으로 차단했습니다. 모델은 지침과 달리 Write/추가 Edit 재시도도 했고 모두 차단됐습니다. 120초 제한으로 종료됐으며 full native suite는 PASS하지 않았습니다. 권한 완화·다른 도구 우회·모델 교체로 통과시키지 않았습니다. 이후 prompt에 Edit/Write 간 재시도 금지를 더 명시했지만 그 추가 문구의 실제 준수는 미검증입니다. Prompt만으로 모든 모델의 안전 지침 준수를 보장할 수 없습니다.
- 실패 후 별도 허용된 확인에서 fixture·임시 모델 settings·기존 사용자 Agent/Skill/지침의 바이트 보존과 전역 uninstall을 확인했습니다. 실제 사용자 전역 설치가 아니라 격리 config 검증입니다.
- OpenCode native suite도 기본 모델의 HTTP 400 (`The requested model is not supported`)로 첫 Planner 호출에서 중단됐습니다. 기존 filesystem 회귀는 통과했고 기존 OpenCode Agent 정의·통합 스크립트는 변경하지 않았습니다.
- Native validator는 `agents/claude`를 plugin 디렉터리로 해석해 실패했고 `agents/` 이름의 임시 디렉터리에서는 검사 항목 없이 성공했습니다. 이 출력은 Agent schema 검증 근거로 사용하지 않았습니다. 실제 host 발견/실행과 정적 검사를 구분합니다.

따라서 지원 코드와 설치 안전성은 검증됐지만 **완전한 Claude 수정·재검토 실행, interactive 비동기 대기, nesting 한도/3회 소진, 실제 Git commit/push 자율 동작과 모든 Skills 행동 호환성은 미검증**입니다. 이미 허용된 host 권한과 사용 가능한 사용자 모델의 환경에서 opt-in 통합 검증이 필요합니다. ATOM은 테스트를 위해 그 권한·모델을 바꾸지 않습니다.

공식 V2 참고: [Agents](https://opencode.ai/v2/docs/agents), [Permissions](https://opencode.ai/v2/docs/permissions), [Skills](https://opencode.ai/v2/docs/skills), [Keybinds](https://opencode.ai/v2/docs/cli/keybinds).

Claude 공식 참고: [Subagents](https://code.claude.com/docs/en/sub-agents), [CLI reference](https://code.claude.com/docs/en/cli-reference), [Environment variables](https://code.claude.com/docs/en/env-vars), [Skills](https://code.claude.com/docs/en/skills). 최신 문서의 모든 기능이 2.1.259에서 제공된다고 가정하지 않습니다.
