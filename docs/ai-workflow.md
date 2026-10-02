# AI 협업과 로컬 GitHub 인증

AI는 `AGENTS.md`를 읽고 기존 사용자 변경을 보존하며 작업 브랜치에서 수정합니다.
검증 후 변경 파일만 커밋하고 push하여 PR을 만듭니다. merge는 사용자가 결정합니다.

## 로컬 준비

1. GitHub CLI (`gh`), Python 3, Git을 설치합니다.
2. 저장소 루트에 `.local` 디렉터리를 만들고 `.local/gh-token` 파일에 토큰 한 개를 저장합니다. 따옴표나 `export` 문은 넣지 않습니다. 토큰은 채팅이나 명령행 인수로 전달하지 말고 로컬 편집기로 입력합니다.
3. macOS/Linux에서는 `chmod 700 .local`, `chmod 600 .local/gh-token`으로 권한을 제한합니다. Windows에서는 파일 보안 속성에서 본인만 읽을 수 있도록 ACL을 제한합니다.
4. `python3 scripts/gh-local.py api user --jq .login`으로 확인합니다. Windows에서는 `python3` 대신 `py -3`을 사용합니다.

`.local/`은 Git에서 제외합니다. wrapper는 토큰을 gh 자식 프로세스의 `GH_TOKEN`에만 전달하고, gh 설정은 `.local/gh`에 둡니다. 전역 gh 로그인 정보와 `GH_DEBUG`는 사용하지 않습니다. `auth`와 `extension` 명령은 차단합니다. 임의의 `gh api` 요청 권한까지 제한하는 보안 경계는 아니므로 AI 작업 범위는 `AGENTS.md`를 따릅니다.

토큰은 `1ocate/dotfiles` 프로젝트 전용으로 발급하세요. fine-grained PAT의 Repository access에서 Only select repositories를 선택하고 `dotfiles`만 지정합니다. wrapper의 기본 대상도 `1ocate/dotfiles`로 설정합니다. 실제 접근 제한은 GitHub에서 설정한 토큰 권한으로 적용됩니다. fine-grained PAT로 PR을 만들려면 해당 저장소의 Pull requests 읽기/쓰기 권한이 필요합니다. 만료 후에는 로컬 파일만 교체합니다.
Git remote는 현재 SSH 방식입니다. `git push`에는 별도의 SSH 인증이 필요하며 wrapper의 토큰은 Git push에 사용되지 않습니다.

## PR 예시

```sh
git switch -c feat/example
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
