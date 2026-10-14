# 프로젝트 작업 지침

## GitHub 계정

- 이 저장소는 **`righttime/atom`**이며 GitHub 작업에는 **`righttime` 계정**을 사용합니다. `hk-neo` 등 다른 계정으로 대신 실행하지 않습니다.
- Git remote의 `github.com-mine`은 Git용 SSH alias입니다. Push 성공이 `gh` API도 같은 계정이라는 뜻은 아닙니다.
- `GH_TOKEN`/`GITHUB_TOKEN`은 저장된 `gh` 계정보다 우선할 수 있습니다. GitHub 명령 전에 실제 API 계정이 `righttime`인지 확인합니다.
- 다른 프로젝트에 영향을 주는 전역 `gh auth switch`, 환경 변수, 인증 설정 변경은 하지 않습니다. 아래처럼 프로젝트 명령의 subshell에서만 저장된 `righttime` 인증을 사용합니다.

```sh
(
  set +x
  GH_TOKEN=$(env -u GH_TOKEN -u GITHUB_TOKEN \
    gh auth token --hostname github.com --user righttime) || exit 1
  [ -n "$GH_TOKEN" ] || exit 1
  export GH_TOKEN
  unset GITHUB_TOKEN
  [ "$(gh api user --jq .login)" = righttime ] || exit 1

  # 이 subshell 안에서 gh 명령을 실행합니다. 대상 저장소를 명시합니다.
  gh repo view righttime/atom
)
```

- 토큰은 출력하거나 파일·로그·커밋에 저장하지 않습니다. 인증이 없거나 실제 계정이 다르면 중단하고 보고합니다. 다른 계정으로 자동 전환하거나 host 권한을 우회하지 않습니다.
- PR의 저장소는 `righttime/atom`이고 기본 base는 실제 remote-default인 `main`입니다. 생성 전 실제 base/head와 포함 변경을 확인합니다. Push는 비기본 작업 브랜치를 명시하며 기본 브랜치에 직접 Push하지 않습니다.
- PR 생성 승인은 Merge·auto-merge 승인이 아닙니다. Jira 연동 요청이 없으면 Jira를 변경하지 않습니다.

## 검증

- 배포물은 `agents/`의 Markdown과 POSIX shell 설치기 `atom`입니다. 새 runtime이나 프로젝트 초기화 절차를 추가하지 않습니다.
- Shell 변경은 `sh -n atom`, `sh -n tests/installer.sh`, `sh -n tests/opencode.sh`, `sh -n tests/ownership.sh`와 관련 테스트로 검증합니다. 설치기 회귀 검증은 `sh tests/installer.sh`입니다.
- 실제 모델 호출 테스트는 opt-in입니다. 사용자가 선택한 모델을 `ATOM_TEST_MODEL`로 명시하며 현재 UI 세션의 모델 상속을 가정하거나 실패 후 임의 모델로 전환하지 않습니다. 실행 범위와 비용은 `README.md`의 검증 절차를 따릅니다.
