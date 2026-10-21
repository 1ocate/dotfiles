# 0013: PowerShell Ctrl+R 히스토리 fzf 검색

- 상태: 리뷰 대기
- PR: https://github.com/1ocate/dotfiles/pull/24
- 요청: Ctrl+R로 과거 명령을 검색하고 선택한 명령을 입력줄에 넣는다.
- 기준: 최신 main 2a92162 (PR #22 병합 확인), feat/powershell-fzf-history. main 대상으로 독립 PR을 제출한다.
- 환경·범위: windows-powershell, 기존 tab-completion 원본 로더에 연결. 다른 OS·프로필·패키지 설치는 변경하지 않는다.
- 결정: ADR 0002의 원본 로더·선택 의존성 구조를 유지하므로 새 ADR은 없다.
- 분석: PSReadLine 기본 Ctrl+R은 대화형 역방향 검색이다. 기존 SSH fzf 경로와 키가 분리되어 있으며 명령 실행 대신 Replace만 사용한다.
- 계획: 저장 파일과 현재 PSReadLine 히스토리를 최신순 중복 제거 → 입력줄을 초기 query로 fzf → 선택 시 입력 교체. 취소는 그대로, 의존성/선택 실패는 기본 ReverseSearchHistory. 여러 줄 명령은 원문을 유지하고 검색에는 한 줄 요약과 ID를 사용한다.
- 검증 계획: 가상 히스토리의 역순·중복·여러 줄·빈 파일, 가상 fzf의 query·취소·실패·옵션 복원, 실제 fzf의 선택, PS5.1/7 문법·기존 SSH 검사. 개인 명령 기록을 출력하거나 실행하지 않는다.
- 미확인: Windows Terminal의 실제 Ctrl+R GUI 조작. macOS/WSL/Linux는 미변경·실기기 미검증.

2026-10-21 KST 검증: PS7 및 Windows PowerShell 5.1에서 tests/history-fzf.ps1 통과. 가상 파일의 여러 줄·한글·역순·중복 제거·빈/없는 파일, 가상 fzf의 query·취소/오류·원문 복원·전역 옵션/인코딩/종료코드 복원, 실제 fzf의 한글 선택을 검사했다. 초기 PS5.1 검사는 구버전 PSReadLine에 없는 Chord 조회와 기본 ASCII 파이프 때문에 실패해 테스트를 호환 조회와 런타임과 같은 UTF-8로 고친 뒤 재통과했다. 기존 tests/ssh-fzf.ps1도 PS7에서 통과했다. 개인 히스토리를 읽거나 명령을 실행하지 않았다.

독립 정적 리뷰에서 loader 누락·키 충돌·자동 실행·취소/실패 경로의 차단 문제는 없었다. 최신 main에서 SSH PR #22 병합을 확인했다. 현재 체크아웃의 기존 Tab 원본이 기준과 같음을 검사한 뒤 새 runtime과 loader 추가를 반영했다. 프로필 편집·도구 설치는 하지 않았다. 새 PowerShell에서 실제 Ctrl+R GUI 확인과 PR 리뷰가 남았다.

2026-10-21 KST 사용자 GUI 피드백: fzf에서 입력해도 검색되지 않았다. 설치된 fzf 0.74.4에 가상 git/kubectl 행으로 --with-nth=2.. 및 --nth=2.. 조합을 전달하면 git 검색이 exit 1로 실패하고 --nth를 제거하면 exit 0으로 매칭됨을 재현했다. 표시 변환 후 다시 필드를 제한해 명령이 검색 범위에서 빠진 것이 원인이다. --nth를 제거해 표시된 명령 전체를 검색한다. 이전 실제 fzf 검사가 runtime 옵션 조합을 사용하지 않은 누락을 수정해 selector가 실제 전달한 전체 인자를 그대로 실행하는 회귀 검사로 보강했다. 로컬 원본에도 동일하게 수정했다.

수정 검증: PS7 및 PS5.1의 tests/history-fzf.ps1이 실제 runtime 전체 인자와 --filter를 사용해 한글 매칭까지 재통과했다. git diff --check도 통과했다. 실제 대화형 GUI 재확인은 사용자 확인이 남았다.
