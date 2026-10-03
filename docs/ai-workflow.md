# AI 협업과 로컬 GitHub 인증

프로젝트 분석 → 계획 → 분리된 작업 환경에서 수정 → 검증 → 커밋·제출 순서로 진행합니다.
시작할 때 [README](../README.md), [평가와 방향](environment-direction.md), [AI 지침](../AGENTS.md)과 최신 `main`을 확인합니다.

## 변경 제출 기준

| 변경 | 제출 방식 |
| --- | --- |
| 동작을 바꾸지 않는 README·분석·평가·계획 문서와 오탈자·링크 | 검증 후 `main` 직접 커밋·push |
| 설정·코드·스크립트·플러그인·lockfile·설치 방식 | 작업 브랜치와 PR |
| AI 지침·인증·권한·배포 절차 | 문서만 바꾸더라도 PR |
| 문서와 동작 변경이 함께 있는 경우 | 전체를 PR로 제출 |

특정 작업에 대해 사용자가 명시한 제출 방식이 우선합니다. PR merge는 사용자가 결정합니다.
실제로 사용하는 설정에 연결된 체크아웃을 바로 수정하지 않고 별도 worktree에서 작업합니다.

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
