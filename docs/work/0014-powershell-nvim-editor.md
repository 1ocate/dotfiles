# 0014: PowerShell의 Kubernetes·기본 편집기를 Neovim으로 설정

- 상태: 진행 중
- 요청: k9s edit가 메모장 대신 Neovim을 열도록 로컬에 적용하고 PR을 제출한다.
- 기준: main bb7871d, feat/powershell-nvim-editor.
- 환경·범위: windows-powershell, Windows PowerShell 5.1·PowerShell 7의 기존 powershell/aliases.ps1 원본 로더. macOS/WSL/Linux는 미변경.
- 분석: 두 프로필에 원본 로더가 이미 있고 nvim이 PATH에서 발견된다. 현재 EDITOR/KUBE_EDITOR는 비어 있다. 별칭은 외부 프로그램이 읽는 환경변수를 대신하지 않는다. k9s 공식 안내는 EDITOR/KUBE_EDITOR를 사용한다.
- 결정: ADR 0002·0010의 기존 원본 로더·native Windows 범위를 유지하는 작은 확장이므로 새 ADR은 없다.
- 계획: nvim 존재 시 비어 있는 EDITOR/KUBE_EDITOR에만 nvim 기본값 → 기존 별칭·명시적 환경값 보존 검사 → 실제 root 원본 백업·반영 → 신규 자식 셸/무설정 nvim 실행 확인 → PR.
- 적용: 프로필·User/Machine 환경변수 레지스트리·패키지 설치는 변경하지 않는다. 현재 실행 중인 k9s/부모 셸에는 소급 반영되지 않아 새 탭 또는 loader 재실행 후 k9s를 다시 시작한다.
- 완료 기준: PS5.1/7 기본값·명시값·미설치·비Windows·재로딩 검사, 기존 별칭 검사, diff/link 검증, 원본 반영 및 PR 제출. 실제 클러스터 edit는 실행하지 않는다.
- 참고: https://k9scli.io/topics/install/

2026-10-22 KST 구현·검증: PS7/PS5.1 tests/powershell-editor.ps1에서 기본값·독립적인 기존값 보호·재실행·nvim 부재·비Windows 제외를 확인했다. PS7 tests/powershell-aliases.ps1에서 기존 loader/인코딩/백업/별칭 인자 전달 회귀 검사도 통과했다. root aliases 원본이 HEAD와 같은 것을 검사하고 .local에 백업한 뒤 반영했다. 양쪽 PowerShell의 NoProfile 자식에서 root 원본을 읽고 실제 nvim --headless -u NONE -i NONE 프로세스까지 EDITOR/KUBE_EDITOR가 전달됨을 확인했다. 기존 프로필·User/Machine 환경·클러스터는 변경하지 않았다. 실제 k9s edit UI는 사용자 확인 범위다.

실제 Neovim 상속 검사에서 초기 inline Lua 인자는 PS5.1 따옴표 처리 때문에 assertion 오류를 냈지만 nvim 종료값 0으로 보고됐다. Lua 파일과 명시적인 cquit 오류 종료를 사용하는 검사로 고쳐 양쪽 셸에서 오류 없이 재통과했다. 독립 정적 리뷰에서도 자동 loader·기존 값 보존·환경 격리의 차단 문제는 없었다.
