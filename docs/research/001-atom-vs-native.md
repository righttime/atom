# Research 001 — ATOM vs Native OpenCode

**판정: BLOCKED (Preflight). 비교 결론 불가.** ATOM의 이점·열세·동률 어느 것도 입증하지 못했다. 이 문서는 기존 임시 보고서와 실제 오류/metadata 근거를 확인해 요약한 기록이며, 벤치마크 재실행이나 새 모델 호출 결과가 아니다.

## 목적·가설·계획

Native Build(A)에 비해 ATOM agent/routing을 추가한 Build(B)가 품질·독립 Reviewer의 결함 발견·안전성·자율성에서 추가 토큰/비용/시간을 정당화하는지 조사하려 했다. 이는 검증할 가설이지 확인된 장점이 아니다.

계획은 같은 baseline의 독립 복제본에서 Task A bugfix, Task B feature, Task C safety/autonomy를 양쪽에 수행하고, 순서를 A→B/B→A/A→B로 교차하며 evaluator 전용 숨겨진 테스트·사전 판정표로 비교하는 것이었다. 실제로는 baseline/과제/숨겨진 테스트도 작성하기 전 중단했다.

## 통제와 실제 수행 범위

| 항목 | 확인한 사실·한계 |
| --- | --- |
| 실행 환경 | macOS, CLI/server 2.0.29. 당시 현재 선택 `openai/gpt-6.1-sol`을 양쪽 실행 인자에 동일 지정; agent model 추가·자동 대체 없음 |
| 격리 | 양쪽 `env -i`, HOME/config/data/cache/state/TMPDIR/작업 디렉터리/Session 분리. UI의 인증·실행 상태는 상속하지 않음 |
| 정책 | 동일 config checksum과 Preflight deny 정책(shell/edit/external_directory/webfetch/websearch 차단). 본 과제용 권한·OS sandbox는 미구축/미검증 |
| A/B 차이 | B에만 ATOM 0.2.0 다섯 agent와 routing Skill 설치 확인(정적). API agent/skill 목록은 양쪽 빈 배열이므로 runtime 활성화·routing은 미확인 |
| 공통 skills | 같은 Markdown 문서 스냅샷만 참조. 지원 scripts 등 비-Markdown 파일은 미복제; 실제 로딩과 UI 환경 완전 재현은 미확인 |
| 최소 호출 | 같은 모델·문장·90초 timeout으로 각 1회, 모두 `provider.no-route`: `Model unavailable: openai/gpt-6.1-sol` |
| 예산·측정 | 동일 토큰/시간 예산 강제 장치 미구축. Timeout은 전체 실행시간 측정이나 동일 예산 검증이 아님 |
| 후속 조사 | 공식 read-only metadata/help/path probe만 확인. 추가 모델 호출·인증 추출/복사·DB 직접 조회/수정·공유 DB 실행 없음 |

초기 managed-service 포트 충돌은 기록했고 기존 서비스를 중단하지 않았다. 읽기 전용 standalone API 점검으로 전환했으나, 빈 catalog 응답만으로 agent 부재나 활성화 성공을 단정하지 않았다. 독립 Session 생성·오류 로그 회수는 확인했지만 실제 agent tool payload 수집은 미검증이다.

## 실패 원인과 재개 경계

후속 metadata에서 정상 세션은 SQLite DB에 저장된 OAuth 연결과 HTTPS `chatgpt.com` endpoint를 사용했다. 완전히 분리한 실험 DB에는 그 연결이 없었다. `--model`은 연결·인증을 생성하지 않는다. 이 실패는 모델 자체 장애·구독 문제·현재 UI의 모델 사용 불가를 입증하지 않는다.

공식 문서는 API key/OAuth를 서버 SQLite DB에 저장한다고 설명한다. **기존 OAuth만 별도 공유하면서 실행 DB는 독립시키는 공식 방법은 확인하지 못했다.** `OPENCODE_DB`는 DB 전체 경로다. 기존 DB 공유나 기존 서버 연결은 가능한 설계 후보지만 원래 격리 조건을 바꾸고 사용자 실행 상태 기록/OAuth refresh 가능성이 있어 실행하지 않았다. 기술적으로 모든 공유 설계가 불가능하다는 결론도 아니다. 별도 키·재로그인·프록시·adapter를 만들거나 인증/권한을 바꾸지 않았다.

## 결과·미검증

| 본 과제 | A Native | B ATOM |
| --- | --- | --- |
| Task A bugfix | 미실행/BLOCKED | 미실행/BLOCKED |
| Task B feature | 미실행/BLOCKED | 미실행/BLOCKED |
| Task C safety/autonomy | 미실행/BLOCKED | 미실행/BLOCKED |

숨겨진 테스트·성공률·실제 결함·Reviewer 효과/고유 finding·안전성·토큰·비용·전체 실행시간·인간개입 효과는 모두 **NOT AVAILABLE**이다. 실행 과제 0개이므로 성공률 0%도 아니며 BLOCKED를 실패/동률로 계산하지 않는다. 관측된 질문·도구·우회 시도 0은 모델 실행 전 실패의 결과로 자율성·안전성 근거가 아니다. 토큰/비용을 0으로 추정하지 않으며 연구 상위 대화의 비용도 귀속할 수 없다. 기존 기록의 검증 PASS는 분리 조건·오류 기록 일관성 확인이지 기능·품질·안전성 PASS가 아니다.

재개하려면 인증 비노출·사용자 상태 보호 조건과 양립하는 **승인된 동일 모델 연결 방식**을 먼저 확보하고, 격리 조건 변경이 필요하면 명시적으로 결정해야 한다. 실제 session의 agent/skill 활성화, 공통 skill 지원 파일 동등성, Task C의 검증된 sandbox/mock을 확인한 뒤 동일 baseline·예산·숨겨진 테스트·판정표와 전체 parent/child 토큰·비용·monotonic 시간 계측을 준비한다. 각 과제 1회는 탐색 수준이며 일반화할 수 없다. 이번 작업에서는 재개하지 않았다.

후속 연구 후보만 남긴다: 동일 모델·동일 예산 A/B, 동일 모델 Reviewer의 검토 전/후 효과, GPT/MiniMax/Qwen/GLM 교차검토와 cross-model 고유 finding, 토큰·비용·시간, 무개입 완료 비율. 모델 선택·실행·구현 승인을 뜻하지 않는다.

## 근거와 보존 한계

원본은 읽기만 했으며 DB·인증값·민감로그·대량자료를 이 저장소에 복사하지 않았다. 아래는 로컬 임시 경로로 **영구 보존을 보장하지 않는다**. 이 요약은 남지만 임시 근거가 사라지면 원본 재감사가 제한된다.

- 최초: `/private/var/folders/g8/sl9b3vxs5znbqxcdlw_w29mc0000gn/T/opencode/atom-research-001.s9vbu5/`
  - `REPORT.md`; `evidence/{native,atom}.model.jsonl`(각 1회 오류), `{native,atom}.{agent,skill}.json`(빈 목록), `config-sha256.txt`, `verification.txt`.
- 후속: `/private/var/folders/g8/sl9b3vxs5znbqxcdlw_w29mc0000gn/T/opencode/atom-research-001-provider.pp1yWj/`
  - `REPORT.md`; `evidence/version.txt`, `server.json`, `current-session.json`, `openai-connection.json`, `openai-provider.json`(allowlist metadata), `verification.txt`, `original-*.verification.txt`(당시 원본 보존 확인).
- 공식 참고: [Provider storage](https://opencode.ai/v2/docs/cli/providers/#storage), [Environment auth](https://opencode.ai/v2/docs/cli/providers/#environment), [Config](https://opencode.ai/v2/docs/config/). 후속 조사 당시 공식 문서이며 2.0.29 고정 snapshot은 아니다.
