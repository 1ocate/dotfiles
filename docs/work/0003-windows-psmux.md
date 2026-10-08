# 0003: Windows PowerShell에 psmux 적용

- 상태: 리뷰 대기 (사용자 PowerShell tmux 동작 확인 완료, PR 병합 준비)
- 요청·배경: 호환성 확인 후 사용자가 PowerShell 로컬 적용과 변경 파일을 모은 PR 제출을 요청했다. Neovim 연동을 우선한다.
- 시작일: 2026-10-06
- 기준: main `38d1473`, `feat/windows-psmux`; fetch 후 origin/main 일치, 기존 사용자 변경 없음
- 실행 환경: windows-powershell. 저장된 승인과 Neovim junction/WezTerm loader 확인
- 범위: Windows psmux 설치·설정·PowerShell 함수·WezTerm 시작, Neovim 이동 검증과 PR
- 비대상: macOS/WSL tmux 변경, 플러그인 업데이트, 다른 health 경고, 재부팅 복원
- 관련 ADR: [ADR 0003](../adr/0003-windows-psmux.md)
- 관련 PR: [PR #10](https://github.com/1ocate/dotfiles/pull/10), [작업 브랜치](https://github.com/1ocate/dotfiles/tree/feat/windows-psmux)

## 분석과 미확인 사항

navigator는 TMUX를 감지하고 tmux -S를 호출한다. 선행 portable v3.3.8 검사에서 내부/외부 이동·zoom·두 세션 8개 검사가 통과했다. pane PATH에 tmux.exe가 없으면 실패했다. 이전 보고 원본은 Git 제외 `.local/psmux-compatibility.md`이며 아래 통합 검증과 구분한다.

기존 tmux.conf의 Unix 명령을 그대로 사용할 수 없어 Windows 전용 pane_current_command 감지와 clipboard 동작을 연결했다. Neovim navigator의 기존 키맵·zoom 동작과 WezTerm 키맵은 유지하고 Windows psmux 전경 상태 helper만 연결했다. GitHub wrapper에서 토큰 부재로 열린 PR 조회가 불가능했다. 기존 기록의 다음 번호 0003을 사용하며 제출 전에 충돌을 확인해야 한다.

## 계획과 완료 조건

1. Windows 전용 설정·opt-in 설치 진입점·원본 profile loader·launcher 구현. 승인·경로·도구 점검과 재실행 보존.
2. 현재 장비에 적용하고 새 셸의 실행 경로·프로젝트 세션 확인.
3. 별도 이름의 서버에서 입력 전달·Neovim 이동·zoom·두 세션·공백/한글 경로를 검증하고 사용자 세션과 lockfile을 보존한다.
4. OS 격리 검사·독립 리뷰 후 diff 검토·커밋·SSH push·PR 제출. 인증 불가 시 PR 본문과 브랜치 준비. merge는 사용자에게 맡긴다.

물리 키·GUI detach/attach와 IME 검증은 이번 자동 검사로 대체하지 않는다. 클라이언트의 root binding 명령을 control CLI로 전달하여 ConPTY의 Neovim TUI 동작을 검사했다. 이후 후속 검사에서 실제 attached-client Esc/K/L을 추가했으며 물리 WezTerm 키 이벤트 검증은 남긴다.

## 진행 로그

| 시각 | 수행 내용·결과 | 다음 일 |
| --- | --- | --- |
| 2026-10-06 KST (시각 미기록) | 최신 main·원본·저장된 승인·선행 검사 확인. 사용자 변경 없음. GitHub token 부재 | 구현·적용·통합 검증 |
| 2026-10-06 KST (시각 미기록) | v3.3.8 공식 x64 ZIP의 SHA256 확인 후 사용자 프로그램 경로에 설치. 두 프로필에 원본 loader, PATH와 호스트 opt-in 연결 | 새 셸·Neovim 검사 |
| 2026-10-06 KST (시각 미기록) | Windows 리뷰의 PATH 우선순위·PS5.1 UTF-8·빈 PATH 문제 수정. macOS 정적 리뷰에서 기존 흐름 회귀 없음 | 통합 검증 |
| 2026-10-06 KST (시각 미기록) | LSP와 같은 자식 프로세스가 pane_current_command를 pwsh로 가리는 문제 재현. Windows Neovim OSC 133 표시와 셸 prompt 초기화 추가. prompt 오류 상태 보존까지 5.1/7 검사 | 자식 프로세스·종료 검증 통과 |
| 2026-10-06 KST (시각 미기록) | 초기 TUI 검사에서 한 TCP 연결에 명령을 여러 번 보내는 테스트가 실패. psmux의 클라이언트 root 명령 전달 경로와 직접 send-key를 구분하여 검사 수정 | 수정된 통합 검사 통과 |
| 2026-10-06 KST (시각 미기록) | 기본 navigator 및 오프라인 현재 LazyVim 설정에서 이동 검사 통과. 독립 리뷰에 따라 detach 후 PowerShell 유지, 테스트 서버 종료 확인 보완 | 제출·GUI 후속 확인 |

## 변경 결과

- `scripts/setup-psmux.ps1`: pinned portable 준비, 승인·입력 점검, 프로필 백업·loader, PATH 백업, opt-in/Disable. 기존 다른 psmux 버전과 홈 tmux.conf를 덮어쓰지 않는다.
- `scripts/setup-windows.ps1 -WithPsmux`: 명시적 선택 기능으로 Plan/Check/설치 연결. 기본 설치 동작은 유지한다.
- `tmux/psmux.conf`: Windows 전경 프로그램 감지, Ctrl+h/j/k/l 전달/이동, Ctrl+Space prefix, split·copy mode·Windows clipboard.
- `powershell/psmux.ps1`: pinned tmux.exe PATH, 기존 명령을 보존하는 mux/t alias, 전체 이름의 함수와 경로 해시 기반 프로젝트 세션.
- `.wezterm.lua`와 launcher: 같은 호스트의 승인·opt-in에서만 시작, 도구 부재/오류와 detach 후 PowerShell 제공.

## 검증 결과

대상은 main `38d1473` 이후 본 작업 diff. 실제 환경은 Windows 네이티브 PowerShell 5.1/7.6.6, Neovim 0.12.5, psmux 3.3.8이다.

| 종류·명령 | 결과·한계 |
| --- | --- |
| 실제 `setup-psmux.ps1`, `-SkipInstall` 재실행 | 설치·프로필·PATH 연결 성공; 두 프로필·feature state·user PATH의 재실행 전후 해시/값 유지 |
| 실제 `setup-windows.ps1 -Check -WithPsmux`, WezTerm `show-keys` | 사전 점검 및 실제 WezTerm 설정 읽기 통과. GUI 키 입력은 아님 |
| 실제 `tests/psmux-runtime.ps1` (5.1과 7) | 승인·schema·호스트·환경·활성화 격리, 사용자 mux/t 보존, pinned PATH, 한글/공백 및 같은 이름의 프로젝트 세션 식별 검사 통과 |
| 실제 `tests/windows-psmux.py` | 현재 options/navigator 로드; 8개 내부/외부 매핑·zoom·두 세션 검사 통과. LSP와 같은 자식이 있어도 Neovim 감지 유지, 종료 후 셸 감지 복귀. live ConPTY Neovim의 root 명령 전달·셸 복귀·한글/공백 split 경로 통과. 서버 PID 종료 확인, 사용자 lockfile 유지 |
| 실제 `tests/windows-psmux.py --full-config` | 현재 LazyVim 원본과 설치된 플러그인으로 같은 시나리오 통과. 다운로드·Mason/parser 자동 설치와 Lua bytecode cache를 검사에서 차단. 전체 설정 모드에서는 lazy.load로 navigator를 로드하고 config/키맵을 직접 다시 적용하지 않는다. 일반 캐시 경로/GUI 전체 기능을 검증했다고 주장하지 않음 |
| 실제 mux 함수 별도 smoke (5.1과 7) | 임시 data 경로의 dotfiles 이름 서버에서 두 세션 생성·각 세션을 명시적으로 대상으로 한 reload binding 원본 경로 확인. 비TTY attach 버전 출력은 GUI attach 성공 근거로 사용하지 않음 |
| 모의 `tests/check_environment.py` | macOS/Linux/WSL 설정의 origin/main 비교 및 Windows opt-in/부재/잘못된 marker 검사 통과 |
| 실제 Python unittest discover | 14개 검사 성공, POSIX ACL 검사 1개는 Windows에서 skip |
| 모의 `tests/psmux-foreground.lua` | OSC 실행·정지·재개·종료 및 비대상 OS/승인/서버의 미실행 검사 통과 |
| 문법·정적 | PowerShell AST, Lua loadfile, git diff --check, macOS/windows/독립 reviewer 검토. 지적된 사항 수정 |

## 남은 일

- [PR #10](https://github.com/1ocate/dotfiles/pull/10)에서 변경과 미검증 범위를 검토하고 병합을 결정한다.
- 사용자가 PowerShell tmux 동작 확인 완료를 보고했다. 개별 시나리오 목록은 제공되지 않았으므로 fzf 선택 UI, copy mode 한글 clipboard, 기존 Alt/Esc·IME의 개별 검증 완료를 추가로 주장하지 않는다.
- 깨끗한 새 장비의 전체 설치, macOS/WSL/Linux 실기기는 미검증이다. 이 PR을 새 장비 설치 재현성 완료로 표시하지 않는다.
- merge는 요청되지 않았으며 수행하지 않는다. 로컬 구성요소의 설치/자동검사 결과는 `.local/setup-state.json`에 별도로 보존한다.

## 제출 상태

- 2026-10-06 10:22 +09:00 (KST): 구현 커밋 `c39073f`를 SSH로 `feat/windows-psmux`에 push했다. Git 작성자 값은 저장소의 기존 .gitconfig에서 이번 커밋 프로세스에만 전달했다.
- repo-scoped wrapper의 draft PR 생성은 해당 체크아웃의 `.local/gh-token` 부재로 실행되지 않았다. 본문은 Git 제외 `.local/pr-windows-psmux.md`에 준비했다. 토큰 준비 후 열린 PR과 번호 충돌 확인·PR 제출·역링크 기록이 남는다.
- 위 인증 대기 시점에는 작업 상태를 완료/리뷰 대기로 표시하지 않았다. 이후 아래 PR 제출 결과에 따라 리뷰 대기로 갱신했다.

- 2026-10-06 10:26 +09:00 (KST): 사용자 안내에 따라 토큰 파일 존재만 확인했다. GitHub CLI 2.102.0을 winget CurrentUser 범위로 준비하고 repo-scoped wrapper로 열린 PR을 확인한 뒤 [draft PR #10](https://github.com/1ocate/dotfiles/pull/10)을 제출했다. GUI/IME 미검증 때문에 draft를 유지하며 merge하지 않았다.

## Ctrl+H 입력 경로 후속 수정

### 좌우 pane 이동 재요청

- 2026-10-06 KST: 사용자는 prefix 없는 Ctrl+h/l로 좌우 분할 pane 이동을 요청했다. 기준 `fc7e559`, 실행 환경 windows-powershell, origin/main `38d1473`이다. 사용자 `nvim/lazy-lock.json` 변경과 Neovim junction을 보존한다.
- 분석·계획: 기존 C-h/C-BSpace 별칭은 표준 ConPTY의 modifier 없는 Backspace 해석을 해결하지 못한다. 실제 attached client에 명시적 Ctrl+h CSI-u 입력을 보내 좌우 Neovim/셸 이동과 일반 Backspace 보존을 확인한다. 성공하면 승인·활성화된 Windows psmux 시작 경로에만 WezTerm 입력 변환을 추가한다. prefix 창 이동, Unix 설정과 설치·실사용 서버 적용은 범위 밖이다. ADR 0003의 제안에 입력 담당 계층과 변경 이유를 보완하고 기존 draft PR #10을 갱신한다.

### Ctrl+K·분할 후 Esc 후속 분석

- 2026-10-06 KST: 사용자가 위아래 분할의 Ctrl+K 실패와 Neovim에서 literal `^L` 입력·Esc 실패를 보고했다. 실행 환경은 windows-powershell, 기준은 `75cf568`이다. 기존 staged Ctrl+H 수정 및 사용자 lockfile 변경을 보존한다. 최신 main은 fetch로 확인한다.
- 계획: 기존 attached ConPTY 검사에 실제 단일 Esc와 위아래 pane의 raw Ctrl+J/K를 추가하여 재현한다. Neovim 모드를 테스트 helper로 강제 복원하면 Esc 오류를 숨기므로 해당 구간은 실제 입력을 사용한다. 원인을 확인한 뒤 Windows 입력 경로만 수정하고 기본/전체 설정 검증을 수행한다. 기존 ADR 0003에 따른 버그 수정이며 새 결정은 아직 없다.

- 2026-10-06 KST: 사용자가 Ctrl+H 실패를 보고했다. 기준 커밋은 75cf568이고 최신 origin/main은 38d1473이다. Windows PowerShell 체크아웃에 기존 사용자 변경은 없었다.
- 분석: 격리된 psmux 3.3.8 서버에 실제 ConPTY 클라이언트를 붙여 passthrough flags 0xE 진단에서 raw 0x08을 보내면 Backspace+CONTROL 이벤트가 되고 C-h root binding은 실행되지 않는다. 임시 C-BSpace binding에서는 왼쪽 pane 이동이 통과했다. 0x7f 일반 Backspace는 modifier 없이 입력되어 이동하지 않았다.
- 계획: Windows 전용 psmux 설정의 root와 prefix에 C-BSpace 별칭을 추가한다. WezTerm 공통 키맵과 Neovim 키맵은 보존한다. 실제 클라이언트 입력으로 Neovim 내부/외부 이동과 일반 Backspace를 검증하고 현재 세션에 설정을 reload한 뒤 같은 PR #10을 갱신한다. Ctrl+Backspace도 동일 이벤트이므로 이동으로 처리되는 제약을 문서화한다.
- 결과: C-BSpace root/prefix 별칭과 사용 제약을 추가했다. 호스트의 기존 PowerShell 승인·psmux 활성화를 확인한 뒤 현재 dotfiles/main 세션에 source-file로 reload하고 두 binding 등록을 확인했다. 프로세스나 세션은 재시작하지 않았다.
- 검증 보완: 기존 live 검사에서 root 명령을 CLI로 실행하던 방식을 실제 attached client의 ConPTY 키 입력 검사로 교체했다. 기본 ConPTY 플래그 0을 사용하며 테스트 전용 C# helper는 설치된 .NET Framework 컴파일러로 임시 경로에 만든다. 당시 Ctrl+H/Ctrl+L/일반 Backspace raw 검사를 시도했다. 후속 표준 flags 0 실행에서는 raw Ctrl+H가 modifier 없는 Backspace여서 탐색 검사가 실패했으며, 이 시도는 통과 근거로 사용하지 않는다. 최종 검사는 Ctrl+H/J CLI 전달과 Ctrl+K/L·Backspace·Esc의 실제 attached-client 입력을 구분한다. 물리 WezTerm·IME·단일 Esc의 입력 처리는 검증 완료로 주장하지 않는다.
- 테스트 준비 수정: 전체 LazyVim에서 dashboard 버퍼가 검사 버퍼를 대체해 삽입 준비가 실패했다. Backspace 검사는 별도의 이름 있는 편집 버퍼를 준비해 수행하도록 분리했다. 키 매핑이나 실제 설정을 덮어쓰지 않는다.

- 후속 재현: 실제 attached ConPTY 클라이언트에서 삽입 모드에 Ctrl+L 네 번 후 단일/두 Escape를 보내면 줄에 0x0c 네 개가 들어가고 mode=i가 유지됐다. Ctrl+\ Ctrl+N은 정상 복귀했다. 위아래 Ctrl+K는 일반 모드에서 통과했다. Ctrl+J의 LF는 Enter로 디코딩되며 별도로 기록한다.
- 수정 계획: Windows dotfiles psmux의 foreground marker에 삽입 모드를 구분하고, 해당 모드에서만 Esc 및 탐색 키를 Neovim 표준 Ctrl+\ Ctrl+N으로 일반 모드 복귀시킨 뒤 전달한다. 일반 모드·셸·fzf·Neovim 터미널 모드의 Esc와 일반 Backspace는 보존한다. 기존 ADR 0003의 Windows 입력 어댑터 제안에 구체적 처리를 보완한다.

- 검증 정정: 최초 Ctrl+H 분석은 passthrough flags 0xE 진단의 결과였다. 표준 ConPTY flags 0에서는 raw 0x08이 modifier 없는 Backspace이고 raw LF는 Enter로 해석됐다. 모드 준비에는 CLI를 사용하되 실제 검사 키 Esc/K/L은 attached-client 입력으로 전달하며, H/J CLI 검사를 raw/물리 키 검증으로 주장하지 않는다.

- 2026-10-06T14:37+09:00 (KST): 최종 windows-powershell 미커밋 diff에서 `py -3 -u tests/windows-psmux.py` 및 `--full-config` 모두 통과했다. 실제 attached-client Esc/K/L, 삽입 모드 위 이동·반복 오른쪽 이동의 문자 보존, 삽입→터미널 전환 marker/원래 Esc 보존, 일반 Backspace, 격리 서버 종료와 사용자 lockfile 보존을 확인했다. H/J는 CLI 검증이며 물리 키 성공으로 표시하지 않는다.
- 검증 보완 과정에서 Neovim 터미널 정리를 native 키로 처리하던 fixture가 실패했다. 입력 검증 이후의 종료를 테스트 Lua `qa!`로 분리했다. 실제 Esc 복귀·이동 검사는 강제 모드 변경이나 fixture 종료로 통과시키지 않는다.
- `nvim --headless -u NONE -i NONE -l tests/psmux-foreground.lua`, `py -3 -B tests/check_environment.py`, `git diff --check` 통과. 지연 로드/재개 시 현재 모드 감지와 OS·승인·socket 격리를 확인했다. Windows/독립 읽기 전용 리뷰 지적을 반영했다. macOS/WSL/Linux 실기기, WezTerm 물리 키/IME는 미검증이다.
- 원본만 수정했으며 이번 후속 작업에서 사용자 서버 reload·설치·프로필 적용·Neovim 재시작은 수행하지 않았다. 반영하려면 저장 후 Neovim을 다시 실행하고 psmux prefix+r로 원본 설정을 다시 읽는다. 관련 수정은 기존 draft PR #10에 제출하며 merge하지 않는다.

- 2026-10-06T14:38+09:00 (KST): 수정 커밋 `1026d48`을 SSH로 같은 작업 브랜치에 push하고 [draft PR #10](https://github.com/1ocate/dotfiles/pull/10)의 한국어 제목·본문을 갱신했다. GitHub에서 OPEN/draft와 head 일치를 확인했다. 사용자 lockfile만 미커밋 변경으로 남겼으며 merge·실사용 재로드는 수행하지 않았다.

- 2026-10-06 KST: CSI-u와 F13은 표준 ConPTY에서 도달하지 않아 제외했다. Alt+h 형식은 실제 attached client의 Neovim 내부 왼쪽 이동·셸에서 Neovim pane 복귀를 통과했다. WezTerm opt-in 분기에서 Ctrl+h를 해당 형식으로, Ctrl+l을 raw 0x0c로 전달하도록 명시했다. psmux M-h root/prefix 별칭으로 기존 탐색과 prefix window 동작을 보존하며 Alt+h 예약·PowerShell fallback의 입력 차이를 ADR과 사용 지침에 적었다.
- 추가 삽입 모드 왼쪽 검사에서 수평 split-window -b가 실제로 오른쪽 pane을 만드는 fixture 문제를 발견했다. 새 pane을 swap-pane으로 왼쪽에 배치하고 좌표를 확인한 뒤 입력을 검증하도록 수정했다. 최초 실패를 입력 성공 근거로 사용하지 않는다. sandbox에서는 기존 headless 외부 이동도 실패하여 격리 ConPTY 검증을 승인된 실행으로 수행했다.

- 2026-10-06T15:46+09:00 (KST): 최종 windows-powershell 미커밋 diff에서 `py -3 -u tests/windows-psmux.py`와 `--full-config` 모두 통과했다. 실제 attached-client Alt+h 형식의 Ctrl+h로 내부 왼쪽 이동·외부 pane 복귀·삽입 모드 왼쪽 이동과 문자 보존을 확인했으며 raw Ctrl+l 오른쪽 이동·Backspace·Esc·격리 서버 종료·사용자 lockfile 보존도 통과했다. `py -3 -B tests/check_environment.py`, Lua loadfile, 실제 WezTerm show-keys의 h/l 전달, `git diff --check` 통과. 독립 읽기 전용 리뷰의 Alt+h 예약·다른 탭 영향을 반영했다. 물리 WezTerm 키/IME 및 macOS/WSL/Linux 실기기는 미검증이다. 사용자 서버 reload·설치·설정 연결은 수행하지 않았으며 사용 지침에 재로드 방법을 적었다. 기존 draft PR #10으로 제출한다.

## 사용자 동작 확인과 병합 준비

- 2026-10-06T15:59+09:00 (KST): 사용자가 “powershell 환경에서 tmux 동작확인 완료. 커밋 후 pr merge준비”를 요청했다. 실행 환경은 windows-powershell, 기준 HEAD는 `05711b1`, fetch한 origin/main은 `38d1473`이다. PR #10의 원격 head가 로컬 HEAD와 일치하며 충돌 없음(`MERGEABLE`/`CLEAN`), 등록된 CI check와 승인 리뷰는 없다.
- 분석·계획: 후속 입력 수정은 이미 커밋·push되어 있다. 이번에는 사용자 실제 동작 확인을 같은 기록에 추가하고 문서 diff·링크를 검증한 뒤 명시적 파일 stage, 커밋·SSH push, 한국어 PR 본문 갱신과 draft 해제를 수행한다. 새 설계 결정은 없고 ADR 0003은 병합 전 제안 상태를 유지한다. 플러그인 일괄 업데이트인 기존 사용자 `nvim/lazy-lock.json` 변경은 보존·제외한다.
- 검증 범위: 사용자 보고를 Windows PowerShell tmux의 실제 사용 확인 근거로 기록하며 자동 검사를 재실행한 것으로 쓰지 않는다. 개별 키·GUI·clipboard·IME 시나리오와 재로드 방식은 보고에 명시되지 않았다. 앞선 자동 검사 근거를 유지하고 macOS/WSL/Linux 실기기 및 깨끗한 새 장비 전체 설치는 미검증으로 남긴다. 실제 merge·자동 merge·설치·설정 적용은 이번 요청 범위에 포함하지 않는다.

- 2026-10-06T16:01+09:00 (KST): 작업 기록 링크·diff 검토와 git diff --check 및 staged diff 검사를 통과했다. 검증 확인 기록을 5e82223으로 커밋·SSH push하고 PR #10의 한국어 본문을 갱신했다. draft 해제 후 GitHub에서 isDraft=false, MERGEABLE/CLEAN과 원격 head 일치를 확인했다. 등록된 CI check는 없다. 사용자 lockfile 변경만 보존했으며 실제 merge·자동 merge·환경 적용은 수행하지 않았다. 다음 단계는 사용자의 최종 PR 리뷰와 병합 결정이다.

### 프로젝트 선택 F 단축키 후속 계획

2026-10-08 KST: 사용자가 기존 tmux의 `Ctrl+Space` → `Shift+F` 프로젝트 선택을 Windows에도 연결하도록 요청했다. 실행 환경은 windows-powershell, 최신 main은 `66a85b7`, 현재 원본 기준은 `870706c`다. 사용자 lockfile·폰트를 보존하고 직전 Esc 적용 원본을 유지하기 위해 `fix/psmux-project-key`를 PR #14 브랜치 위에서 작업하며 후속 PR의 base를 `fix/windows-terminal-esc`로 지정한다. 기존 ADR 0003의 PowerShell 프로젝트 함수와 키 입력 책임을 재사용하므로 새 구조 결정은 없다.

분석: Unix 설정은 `bind-key -r F new-window t`를 제공하지만 psmux에는 F 호출이 없다. Windows의 `t`는 프로필에서 등록되어 있으므로 새 PowerShell 7 창이 프로필을 읽고 `t`를 실행하도록 연결한다. 현재 pane 경로를 유지하고 검색 경로는 기존 `.local/project-paths.txt`를 사용한다. 기존 사용자 t가 있으면 기존 정책대로 그 명령을 보존한다.

계획: 대문자 F만 바인딩 → 별도 namespace 서버에서 설정 로드·F 매핑·실제 새 창의 프로젝트 선택기 시작 확인 → 기존 runtime 격리 검사 → 현재 dotfiles 서버에 F 바인딩만 적용하고 조회 검증 → 로컬 결과·문서 갱신 → diff·커밋·push·draft PR. 다른 키·셸 프로필·설치·OS·사용자 세션은 변경하지 않는다. 물리 prefix 입력과 fzf 선택·취소·프로젝트 전환은 자동 검증과 구분한다.

### 프로젝트 선택 F 구현·적용 검증

2026-10-08 KST, windows-powershell, 후속 미커밋 diff:

- 원본: `tmux/psmux.conf`에 prefix 대문자 F → 현재 pane 경로의 새 창 → `pwsh -NoLogo -NoExit -Command t`를 추가했다. 프로필·기존 사용자 t·프로젝트 검색 목록을 재사용하며 macOS/WSL/Linux의 Unix 원본은 수정하지 않았다. 새 셸은 선택 취소·명령 종료 후 남도록 한다.
- 실제 격리 검증: 고유 namespace 서버에서 원본 설정 로드 성공, `list-keys`의 prefix F 확인. 동일한 `new-window` 명령으로 한글·공백 경로에서 프로필이 로드된 PowerShell을 실행한 뒤 `list-panes`의 foreground가 fzf임을 확인했다. 취소 입력 C-c를 전송했고 검증 namespace만 종료했다. 사용자 세션은 생성·종료하지 않았다. 물리 키 dispatcher 경로를 검증한 것으로 쓰지 않는다.
- 기존 검사: PowerShell 7에서 `tests/psmux-runtime.ps1` 통과. 승인·호스트·OS 격리, 사용자 mux/t 보존, 고정 PATH, 공백·한글 경로 및 프로젝트 세션 이름, prompt 내용·오류 상태 보존을 확인했다. `git diff --check` 통과.
- 실제 적용: 현재 호스트의 환경 승인·psmux 활성화 상태 Ready와 기존 dotfiles 서버를 확인하고 `bind-key -r F new-window -c '#{pane_current_path}' 'pwsh -NoLogo -NoExit -Command t'`만 적용했다. `list-keys`로 매핑을 다시 확인했고 이전 F 및 결과는 `.local/psmux-project-key-before.txt`, `.local/psmux-project-key.json`에 기록했다. 이전 호스트 setup-state·다른 키·프로필·자동시작은 변경하지 않았다.
- 미검증: 실제 Ctrl+Space → Shift+F 물리 입력, 사용자 fzf 선택·취소 UI와 선택 후 세션 이동은 GUI 미검증이다. 다른 OS 실기기·새 장비 설치도 미검증으로 남긴다. 직전 Esc 적용 원본을 유지하기 위해 후속 PR은 #14 브랜치 기반이며 해당 PR 병합 후 base를 main으로 변경한다.

2026-10-08 KST: 독립 읽기 전용 리뷰에서 정적 blocker는 없었으나 live CLI와 설정 파서의 인수 차이를 추가 검증하도록 권고했다. 실제 격리 attached-client에 prefix+F를 입력하니 초기 CLI 바인딩은 따옴표를 잃어 새 PowerShell만 열고 t는 실행하지 않았다. 매핑 조회만으로 완료를 주장하지 않고 실패를 수정했다.

- 검증 서버에 `bind-key -r F new-window -c "'#{pane_current_path}'" "'pwsh -NoLogo -NoExit -Command t'"`로 명령 전체의 따옴표를 보존하여 적용한 뒤 실제 attached-client dispatcher에서 fzf foreground를 확인했다. 자동 입력 도구의 NUL 제약 때문에 검증 서버만 prefix를 Ctrl+B로 바꾸어 Ctrl+B → F를 전송했다. 사용자 서버의 Ctrl+Space와 물리 키 검증은 여전히 미검증이다. 한글·공백 현재 경로도 유지되었다. 검증 서버만 종료했다.
- 성공한 동일 CLI 형태로 현재 dotfiles 서버의 F를 다시 적용하고 명령 전체가 따옴표로 보존된 list-keys 출력과 로컬 결과 기록을 확인했다. 원본 설정 파일은 이미 명령 전체를 따옴표로 지정하므로 별도 코드 수정은 필요하지 않았다. 이후 prefix → r로 원본을 읽어도 같은 명령이 유지된다.

2026-10-08 KST: 검증한 변경을 `e5fb126`으로 커밋·SSH push하고 #14 브랜치 기반 [draft PR #15](https://github.com/1ocate/dotfiles/pull/15)를 제출했다. 사용자 lockfile·폰트는 포함하지 않았고 merge는 수행하지 않았다.
