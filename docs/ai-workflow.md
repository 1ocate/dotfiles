# AI 협업과 로컬 GitHub 인증

프로젝트 분석 → 실행 환경 판별·Windows 사용 환경 승인 확인 → 적용 범위 결정 → 수정 → 검증 → 커밋·제출 순서로 진행합니다.
시작할 때 [README](../README.md), [평가와 방향](environment-direction.md), [AI 지침](../AGENTS.md)과 최신 `main`을 확인합니다.

## 변경 제출 기준

| 변경 | 제출 방식 |
| --- | --- |
| 동작을 바꾸지 않는 README·분석·평가·계획 문서와 오탈자·링크 | `docs/` 작업 브랜치와 PR |
| 설정·코드·스크립트·플러그인·lockfile·설치 방식 | 작업 브랜치와 PR |
| AI 지침·인증·권한·배포 절차 | 문서만 바꾸더라도 PR |
| 문서와 동작 변경이 함께 있는 경우 | 전체를 PR로 제출 |

특정 작업에 대해 사용자가 명시한 제출 방식이 우선합니다. PR merge는 사용자가 결정합니다.
각 호스트의 체크아웃은 실제 설정 원본이자 Git 작업 디렉터리입니다. 일상적인 설정 변경은 이 원본에서 기록하고, 실험적인 변경이나 적용 전 검증에는 별도 worktree를 사용합니다. 환경 판별·승인·격리 기준은 [공통 설정 가드레일](setup-guardrails.md)을 따릅니다.

## 자율 진행과 병렬 분담

기본 흐름은 **요청 → 자율 분석·필요한 작업의 병렬 수행 → 검증·독립 검토 → 커밋·push·PR → 사용자 리뷰**입니다. 일반적인 구현 선택과 다음 단계마다 확인을 요청하지 않습니다. 진행 상황은 공유하며, 요구사항이나 적용 범위를 크게 바꾸는 정보가 부족할 때만 질문합니다. 실제 설치·설정 연결·merge·배포에 대한 명시적 요청과 도구의 권한 승인 절차는 그대로 유지합니다.

| 역할 | 책임과 투입 기준 |
| --- | --- |
| 총괄·공통 구현 | 요청 해석, 공통 원본 수정, 파일 담당 지정, 결과 통합, 검증과 Git·PR 처리 |
| [macos_reviewer](../.codex/agents/macos_reviewer.toml) | OS 차이가 큰 변경의 macOS 셸·tmux·클립보드·Hammerspoon 흐름 검토 |
| [windows_reviewer](../.codex/agents/windows_reviewer.toml) | WSL 없는 네이티브 PowerShell의 경로·셸·연결·클립보드·IME와 환경 격리 검토 |
| [independent_reviewer](../.codex/agents/independent_reviewer.toml) | 최종 diff의 누락·회귀·키 충돌·기존 설정 보존·검증 근거 검토 |

작은 공통 수정은 구현과 리뷰만으로 처리하고, OS 차이가 큰 변경에 두 OS 검토 역할을 추가합니다. 세 검토 역할은 기본 읽기 전용입니다. 구현을 병렬 분담할 때는 총괄이 기본 worker에 수정 가능한 파일을 지정합니다. 같은 파일은 동시에 수정하지 않으며 Git 기록과 제출은 총괄이 담당합니다. 모델과 추론 수준은 고정하지 않고 부모 세션을 따릅니다.

검토 역할이 해당 OS의 실기기를 제공하는 것은 아닙니다. 실제 실행·정적 검토·모의 검사를 구분하고, 미검증 환경과 남은 문제를 PR에 기록합니다. WSL은 기존 동작 유지 관점에서 필요한 경우 검토하며 네이티브 Linux 실기기 검증은 초기 완료 조건으로 삼지 않습니다. 상태 재개는 [장비별 진행 기록](setup-guardrails.md#장비별-적용-진행-기록과-작업-재개)을 따릅니다.

## Codex 실행

병합된 변경을 실제 작업 체크아웃에 반영한 뒤 저장소 루트에서 실행합니다. 기존 로컬 변경은 보존하며 충돌을 처리하고, 새 세션에서 프로젝트 지침과 에이전트 정의를 읽게 합니다.

```powershell
codex --approve-for-me
```

macOS에서도 같은 명령을 사용합니다. 이 옵션은 작업 디렉터리 쓰기 sandbox에서 실행 승인 요청을 자동 검토합니다. 모든 명령을 무조건 승인하거나 환경 선택에 동의하는 옵션이 아닙니다. 현재 세션의 권한은 이 문서 수정으로 바뀌지 않습니다. 전역 권한 설정을 자동 변경하지 않습니다.

프로젝트 [.codex/config.toml](../.codex/config.toml)은 에이전트를 활성화하고 하위 에이전트 동시 실행 상한을 3개로 둡니다(총괄 제외). 실행 환경의 더 낮은 한도는 그대로 적용되며, 매 작업마다 상한까지 띄우라는 의미는 아닙니다. 프로젝트 설정을 읽으려면 Codex에서 해당 체크아웃이 신뢰된 프로젝트여야 합니다. 기존 CLI에서 옵션을 지원하지 않으면 `codex --help`로 확인하고 조직에서 허용한 업데이트 경로를 사용합니다.

Windows의 Codex CLI `0.160.0`에서 `--approve-for-me` 옵션을 확인했습니다. 설정 형식과 프로젝트 에이전트 정의는 [OpenAI 공식 문서](https://learn.chatgpt.com/docs/agent-configuration/subagents)를 기준으로 작성했습니다. 다른 버전과 macOS의 실제 에이전트 실행은 별도 확인 대상입니다.

## 로컬 준비

1. GitHub CLI (`gh`), Python 3, Git을 설치합니다.
2. 저장소 루트에 `.local` 디렉터리를 만들고 `.local/gh-token` 파일에 토큰 한 개를 저장합니다. 따옴표나 `export` 문은 넣지 않습니다. 토큰은 채팅이나 명령행 인수로 전달하지 말고 로컬 편집기로 입력합니다.
3. macOS/Linux에서는 `chmod 700 .local`, `chmod 600 .local/gh-token`으로 권한을 제한합니다. Windows에서는 파일 보안 속성에서 본인만 읽을 수 있도록 ACL을 제한합니다.
4. 저장소 루트에서 `python3 scripts/gh-local.py api user --jq .login`과 `python3 scripts/gh-local.py repo view --json nameWithOwner --jq .nameWithOwner`로 인증과 대상 저장소를 확인합니다. Windows에서는 `python3` 대신 `py -3`을 사용합니다.

토큰 경로는 명령을 실행하는 디렉터리가 아니라 스크립트가 위치한 체크아웃을 기준으로 정해집니다. 별도 worktree에는 토큰 파일이 자동으로 공유되지 않습니다. 기존 토큰 설정이 있는 체크아웃의 wrapper를 `--head`를 지정해 PR 생성에 사용할 수 있으며, 새 worktree에 토큰을 자동 복제하지 않습니다.

스크립트는 Python 표준 라이브러리만 사용하며 추가 패키지는 필요하지 않습니다. 현재 macOS에서 인증과 PR 생성은 확인했습니다. Windows 실기기 실행과 ACL 검사는 미검증이며, Windows 파일 권한은 사용자가 설정해야 합니다.

`.local/`은 Git에서 제외합니다. wrapper는 토큰을 gh 자식 프로세스의 `GH_TOKEN`에만 전달하고, gh 설정은 `.local/gh`에 둡니다. 전역 gh 로그인 정보와 `GH_DEBUG`는 사용하지 않습니다. `auth`와 `extension` 명령은 차단합니다. 임의의 `gh api` 요청 권한까지 제한하는 보안 경계는 아니므로 AI 작업 범위는 `AGENTS.md`를 따릅니다.

토큰은 `1ocate/dotfiles` 프로젝트 전용으로 발급하세요. fine-grained PAT의 Repository access에서 Only select repositories를 선택하고 `dotfiles`만 지정합니다. wrapper의 기본 대상도 `1ocate/dotfiles`로 설정합니다. 실제 접근 제한은 GitHub에서 설정한 토큰 권한으로 적용됩니다. fine-grained PAT로 PR을 만들려면 해당 저장소의 Pull requests 읽기/쓰기 권한이 필요합니다. 만료 후에는 로컬 파일만 교체합니다.
Git remote는 현재 SSH 방식입니다. `git push`에는 별도의 SSH 인증이 필요하며 wrapper의 토큰은 Git push에 사용되지 않습니다.

## PR 예시

```sh
# 실제 설정과 연결되지 않은 별도 작업 디렉터리에서 진행
# 시작 전 최신 원격 main과 기존 사용자 변경을 확인
git switch -c feat/example origin/main
# 수정 및 검증 후 실제 변경 파일을 명시
git add path/to/changed-file
git diff --cached --check
git diff --cached
git commit -m "변경: 구체적인 결과"
git push -u origin feat/example
python3 scripts/gh-local.py pr create --draft --base main --head feat/example --title "구체적인 변경 결과" --body-file .local/pr-body.md
```

PR 본문에는 문제, 변경 결과, 검증 결과와 검증하지 못한 환경을 기록합니다.
`AGENTS.md`는 작업 규칙입니다. 강제 적용이 필요하면 GitHub의 branch protection/ruleset에서 PR 필수 및 직접 push 제한을 별도로 설정해야 합니다. 이 변경은 서버 설정을 수정하지 않습니다.

인증 옵션은 [GitHub CLI 환경 변수 문서](https://cli.github.com/manual/gh_help_environment), PR 옵션은 [PR 생성 문서](https://cli.github.com/manual/gh_pr_create)를 참고하세요.


## 인증 도구 검증

```sh
python3 -B -m unittest discover -s tests -v
```

Windows에서는 `py -3 -B -m unittest discover -s tests -v`를 사용합니다.
검사는 임시 디렉터리와 가짜 토큰을 사용하며 실제 토큰이나 네트워크에 접근하지 않습니다. 누락·빈 토큰·잘못된 인코딩, POSIX 권한·심볼릭 링크, 차단 명령, gh 누락, 프로젝트별 환경 전달과 종료 코드를 확인합니다. 이 검사는 Windows의 실제 gh 실행이나 ACL 검증을 대신하지 않습니다.
