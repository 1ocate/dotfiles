# 0003: Windows PowerShell에 psmux 적용

- 상태: 리뷰 대기 (기본 namespace 구현·자동 검증 완료, Codex 재시작·GUI 확인 및 Windows Terminal 연결 승인 대기)
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

### tmux 호환 명령과 기본 namespace 전환 검증 계획

2026-10-08 KST: 사용자가 namespace가 기존 tmux와 구별하기 위한 것인지, tmux 명령으로 사용할 때도 문제가 발생하는지 검증을 요청했다. 실행 환경은 windows-powershell, 기준 HEAD·최신 origin/main은 `1f1bf3d`다. 열린 프로젝트 F 작업 PR #15의 namespace 전환 실패 분석을 참고하되 병합하거나 적용하지 않는다. 현재 체크아웃은 main으로 변경되어 있어 이번 검증을 최신 main 기반 `fix/psmux-session-validation`에서 진행한다. 기존 사용자 lockfile·폰트는 보존한다.

분석: 현재 Windows PATH의 tmux.exe와 psmux.exe는 모두 설치된 psmux 3.3.8 디렉터리에 있다. 파일 해시는 서로 다르므로 같은 바이너리라고 단정하지 않고 실행 결과로 호환성과 서버 공유를 확인한다. 기존 Unix `scripts/t`는 기본 namespace를 사용하고 D는 해당 함수에 설정 저장소 경로를 넘기는 키다. `-L dotfiles`는 설정 저장소 경로를 의미하지 않는다.

계획: 각 검증 프로세스에 고유한 절대 PSMUX_DATA_DIR을 지정하고 실제 사용자 데이터와 분리한다. psmux/tmux 명령 × 기본/named namespace의 네 조건에서 생성·목록·한글/공백 작업 경로·실제 attached-client 왕복 전환을 비교한다. 반대쪽 실행 파일에서도 생성한 세션 조회가 되는지 확인하고 존재하지 않는 대상의 오류와 기존 세션 보존도 검사한다. 검증용 세션은 이름을 지정해 종료하며 bare kill-server를 사용하지 않는다. 재현 가능한 검사를 저장하고 결과·제약을 같은 기록에 추가한 뒤 검증 PR을 제출한다. 설치·원본 런타임·namespace 정책·기존 세션은 바꾸지 않으므로 새 ADR은 필요하지 않다. 현재 t 함수의 -L 제거와 GUI 키·다른 OS는 이번 검증 범위 밖이다.

2026-10-08 KST 추가 요청·검증 결과: 사용자가 다른 psmux와의 분리가 필수인지 확인을 요청했다. psmux 자체에는 필수 조건이 아니다. 설치된 psmux.exe와 tmux.exe 모두 `-V`에서 psmux 3.3.8/66cf613을 보고하며, 같은 PSMUX_DATA_DIR과 namespace의 세션을 양쪽 실행 파일에서 조회·조작할 수 있었다. 두 실행 파일의 해시는 다르므로 파일 동일성은 주장하지 않는다. 이는 현재 Windows tmux가 Unix tmux와 별개의 엔진이 아니라 psmux 호환 진입점임을 보여준다. `-L dotfiles`는 다른 psmux 사용과의 선택적 분리이며 Unix tmux와 구별하기 위한 필수 장치가 아니다.

- 실제 native 검증: `tests/windows-psmux-sessions.py`는 기존 ConPTY helper를 재사용하고 네 조건마다 고유 PSMUX_DATA_DIR을 만들었다. 각 실행 파일에서 기본 namespace와 named namespace로 두 세션을 생성하고 반대쪽 명령에서도 조회했다. 한글·공백 작업 경로를 확인하고 실제 클라이언트를 source에 붙여 전환을 실행했다.
- 기본 namespace: psmux와 tmux 모두 `switch-client -t =project` 성공과 실제 클라이언트 이동을 확인했다. 각 조건에서 추가 3회 왕복 전환을 수행하고 존재하지 않는 대상의 실패·현재 연결 및 두 세션 보존도 확인했다.
- named namespace: psmux와 tmux 모두 대상이 있어도 `can't find session: project`, exit 1이었다. 클라이언트는 source에 남았고 세션은 보존되었다. 반대쪽 실행 파일과 일반 이름·전체 namespace 접두사 이름을 사용해도 실패했다. named 조건의 실패를 버그 재현 성공으로 기록하며 기능 통과로 표현하지 않는다.
- 초기 검증 도구의 정리 판정은 list-sessions가 세션이 없어도 exit 0인 것을 반영하지 못해 중단됐다. 출력이 비었는지 기다리도록 수정한 뒤 네 조건 전체를 재실행해 통과했다. 각 조건의 생성한 두 이름만 kill-session으로 정리하고 모든 helper 종료와 세션 목록 비움을 확인했다. bare kill-server·사용자 세션 종료는 실행하지 않았다. 사용자 lockfile은 byte 비교로 보존을 확인했다.
- 현재 설정의 의존성: powershell/psmux.ps1의 타 namespace 진입 차단·prompt marker, nvim/lua/config/psmux.lua의 foreground marker가 dotfiles namespace에 묶여 있다. 런타임에서 -L만 제거하면 안전하지 않다. 기본 namespace 전환은 후속 설계·어댑터 변경·기존 세션 보존 계획이 필요하며 이번 검증에서 적용하지 않았다. 기본 namespace를 다른 psmux 사용과 공유하면 세션 이름과 설정 책임을 공유한다는 비용이 있다. 서로 다른 사용자/호스트/WSL tmux와 분리를 위해 이 label이 반드시 필요한 것은 아니다.
- 범위·한계: Windows 네이티브 pinned 3.3.8의 실제 attached-client 세션 비교와 정적 어댑터 분석이다. 현재 t/fzf/F/D 전체 흐름, 기존 사용자 namespace에서의 전환, 실제 WezTerm·Windows Terminal 물리 키·IME, Neovim 통합, 다른 OS 실기기·새 장비 설치를 검증한 것으로 확대하지 않는다. namespace 정책·의존성·프로필·자동 시작을 변경하지 않았으며 포크가 필수라는 앞선 제안을 기본 namespace 대안 검증 결과로 보완한다.

2026-10-08 KST 최종 검토: 독립 읽기 전용 리뷰에서 실제 list-clients 이동을 확인하는 비교 방식과 범위 표기에 blocker가 없었다. 정리 명령 timeout에도 helper 종료를 수행하고 통신 오류를 빈 세션 목록으로 오인하지 않도록 권고를 반영했다. 버전 확인도 임시 registry를 사용한다. 기존 설정·세션은 그대로 두고 검증 코드와 기록만 제출한다. 이번 작업의 상태는 리뷰 대기이며 PR 제출 후 링크를 추가한다.

2026-10-08 KST: 최종 보강 후 네 조건의 실제 ConPTY 검사·Python 문법·git diff --check를 통과했다. 검증 코드와 기록을 `3cbe19c`으로 커밋·SSH push하고 [검증 PR #16](https://github.com/1ocate/dotfiles/pull/16)을 제출했다. 상태는 리뷰 대기다. PR #15와 #16 모두 merge하지 않았고 런타임·사용자 설정·기존 세션·lockfile·폰트를 변경하지 않았다.

### 기본 namespace 전환안 사전 검토

2026-10-08 KST: 사용자는 기존 tmux 세션 이전·보존보다 named namespace를 제거해 사용할 수 있게 하는 것이 목표라고 설명한 뒤, 해당 방안으로 문제가 해결되는지 사전 검토를 요청했다. 기준은 `7004caf`, 실행 환경은 windows-powershell이며 사용자 lockfile·폰트 변경만 존재했다. 이번 단계는 계획 검토로 실행 중인 사용자 세션 종료·런타임 변경·적용은 수행하지 않는다. 검증 PR #16의 실제 기본 namespace 전환 성공은 앞선 실행 근거이며 이번 읽기 전용 검토에서 재실행한 것으로 쓰지 않는다.

분석·검토 기준: 네 matrix 결과가 전환 오류 해소를 뒷받침하는지, -L 제거 외에 PowerShell 진입 차단·prompt/Neovim foreground 감지·설정 로드·자동 시작·기본 세션 재사용을 함께 변경해야 하는지 확인한다. 구현 승인은 앞선 요청에 있지만 이번 요청의 검토 단계에서는 코드나 실제 환경을 바꾸지 않는다. 기본 namespace로 동작을 변경할 때는 후속 ADR에서 기존 ADR 0003의 named 서버 선택을 명시적으로 보완해야 한다.

검토 결과: 기본 namespace 사용은 pinned 3.3.8의 named 전환 결함을 피하는 타당한 방법이다. 현재 wrapper의 -L dotfiles 전체와 /dotfiles, 진입 조건을 함께 바꾸지 않으면 기본 pane에서 t가 계속 차단된다. prompt 초기화와 Neovim 모드 marker도 namespace 이름 대신 승인된 Windows·psmux 전용 감지로 전환해야 한다. 로컬 공식 소스 pane.rs의 set_tmux_env는 기본 pane에 /tmp/psmux-{server_pid}/default,{port},0 형식 TMUX와 실제 세션명 PSMUX_SESSION을 제공한다. 명령 이름만으로 Unix tmux와 구분하지 않는다.

WezTerm은 기존 launcher를 통해 같은 Invoke-DotfilesMux를 호출하므로 함수의 변경으로 시작 경로도 기본 namespace로 바뀐다. 저장소의 -f tmux/psmux.conf는 계속 지정해야 한다. 기존 기본 main이 있다면 has-session에 -f를 붙이는 것만으로 그 서버의 설정이 다시 로드되지 않으므로 생성 전에 기존 기본 세션 상태와 설정 책임을 확인해야 한다. Windows Terminal 저장소 원본은 일반 pwsh이며 별도 자동 시작이 있다면 해당 로컬 호출 경로도 확인해야 한다. F/D는 현재 main의 psmux.conf에 없으므로 namespace 변경만으로 키 연결까지 구현됐다고 할 수 없다.

완료 조건: 실제 저장소 wrapper의 mux 시작과 t 경로 지정·fzf 선택/취소, F/D를 제공할 경우 실제 키 dispatcher와 선택 후 세션 이동, Neovim 내부/외부 pane 이동·삽입 모드/Esc·prompt reset을 기본 namespace에서 검증한다. 기존 named 세션을 종료하는 것 자체는 -L 선택을 변경하지 않는다. 앞선 최소 설정 session matrix만으로 전체 통합 완료를 선언하지 않는다. macOS/WSL/Linux와 물리 GUI/IME는 실행 근거 없이 완료로 기록하지 않는다.

2026-10-08 KST: Windows 읽기 전용 리뷰에서도 전환 방향이 타당함을 확인했다. 필수 보완은 PowerShell·Neovim psmux 감지 변경, 기존 기본 세션의 config 책임 확인, 필요 시 F/D 연결과 전체 흐름 검증이다. launcher·설치 연결·클립보드·IME는 직접 변경할 필요가 없다는 검토를 반영했다. 리뷰는 정적이며 이번 검토로 실제 적용 완료를 선언하지 않는다. 검토 기록을 기존 PR #16에 추가하며 runtime 수정은 후속 구현 단계로 남긴다.

### 초기 namespace 결정·입력 회귀·원본 연결 재검토

2026-10-08 KST: 사용자가 초기 namespace 결정부터 확인하고 h split 이동·Neovim insert Esc 문제 해결에 필요한지 재검토하며, 실제 설정이 저장소 원본에 링크되어 변경이 Git에 남아야 한다고 요청했다. 기준 `1ef95ac`, windows-powershell, 최신 main `1f1bf3d`를 fetch했다. 사용자 lockfile·폰트는 보존한다. 이번 검토는 역사·실제 링크의 읽기 전용 점검과 필요 시 임시 데이터 경로의 실험에 한정하고 사용자 세션 종료·설치·원본 런타임 적용은 하지 않는다.

계획: 최초 c39073f의 ADR/코드와 h/Esc 후속 수정 1026d48·05711b1을 대조한다. namespace의 격리/적용 대상 판별 역할과 실제 ConPTY 입력 보정을 구분한다. Neovim junction, WezTerm/PowerShell loader 및 Windows Terminal 대상 경로가 현재 체크아웃을 가리키는지 실제 상태로 확인한다. 기본 namespace에서도 입력 보정을 유지하는 실험은 .local scratch와 고유 PSMUX_DATA_DIR에서만 수행하며 실험 사본을 설치·기본 설정 원본으로 사용하지 않는다. 보정 없애기와 namespace 제거를 혼동하지 않고 실행·정적·모의 근거를 구분해 같은 검증 PR #16에 남긴다. 새로운 구조 결정은 역사 검토 후 ADR로 제안해야 하며 이번 문서로 과거 결정 이유를 새로 만들어 쓰지 않는다.

2026-10-08 KST 역사 재검토 결과: 최초 구현 c39073f에서 이미 -L dotfiles와 foreground/prompt namespace gate를 사용했다. insert Esc 수정 1026d48과 h/l 전달 수정 05711b1은 이후에 들어갔으며 namespace는 변경하지 않았다. 최초 ADR의 명시 근거는 이름 있는 서버와 bare kill-server 금지, 승인된 Windows 범위이며, namespace의 대안 비교·필수성 근거는 없다. 기존 psmux·설정과의 분리를 선택한 설계 의도로 읽는 것은 초기 기록과 코드에서의 추론이다. 기존 Unix tmux와 구별하기 위한 필수 장치였다고 확정했던 앞선 설명은 과도했다. h는 ConPTY의 Backspace 해석을 피하는 Alt+h 운반/M-h 연결, Esc는 OSC133 nvim-insert 감지와 Ctrl+\\ Ctrl+N 처리로 수정됐다. 이 보정 자체는 이름 있는 namespace를 필요로 하지 않지만 현재 적용 대상 gate는 해당 이름에 의존한다.

현재 호스트 원본 연결의 실제 점검: Neovim의 %LOCALAPPDATA%/nvim은 이 체크아웃 nvim junction이며 init.lua 해시도 원본과 일치했다. %USERPROFILE%/.wezterm.lua는 독립 설정 복사본이 아니라 저장소 .wezterm.lua를 dofile하는 loader다. PowerShell 5.1/7 profile은 저장소 powershell/psmux.ps1을 dot-source하는 loader이며 psmux 함수는 저장소 tmux/psmux.conf를 -f로 직접 읽는다. 디렉터리 symlink/junction 또는 원본을 실행하는 loader라는 기존 원칙을 충족한다. 파일을 링크 대상에서 수정해도 Git diff에 남는 원본 구조를 namespace 정책과 별개로 유지해야 한다.

Windows Terminal stable의 현재 LocalState는 일반 디렉터리이고 settings.json도 일반 파일이다. scripts/use-windows-terminal.ps1 -Check가 existing-directory를 보고했으며 저장소 연결 완료로 간주하지 않는다. 호스트 진행 기록도 다른 호스트의 과거 상태라고 진단하므로 해당 기록만으로 실제 연결을 보증하지 않는다. 원본 연결을 복구할 때 기존 설정을 먼저 백업하고 승인된 환경 선택·현재 호스트 진행 기록을 분리해야 한다. 이 검토에서 junction 교체·프로필 변경·설치를 실행하지 않았다.

2026-10-08 KST 실제 기본 namespace 키 회귀 실험: .local/namespace-key-review scratch에서 기존 tests/windows-psmux.py 기반 검사에 -L을 쓰지 않고 현재 원본 options/navigator/psmux 키 설정을 읽었다. Neovim config.psmux만 package.preload로 임시 gate를 제공했으며 승인된 Windows, 공식 default TMUX 형식, PSMUX_SESSION을 검사하도록 바꿨다. OSC/autocmd와 Alt+h/M-h·Ctrl+l 전송·nvim-insert/Esc 보정은 유지했다. 실제 ConPTY 최소 구성과 오프라인 현재 LazyVim 구성(--full-config)이 각각 23개/exit 0을 통과했다. Ctrl+h 우회 전송의 내부/외부 이동, insert 이동 문자 보존, 반복 Ctrl+l 후 raw 단일 Esc 정상 모드 복귀, Backspace, terminal Esc 유지, foreground clear, navigator routing, 한글·공백 경로를 확인했다. 다운로드·lockfile 변경 없이 private data 경로에서 생성한 세션만 이름 지정 종료했다. 사용자 세션·원본 runtime은 변경하지 않았다. 이는 대체 gate의 실험이지 저장소 구현/물리 WezTerm·Windows Terminal 입력의 완료 판정은 아니다.

별도 실제 pane 환경 검사에서도 -f로 지정한 원본 tmux/psmux.conf 경로가 PSMUX_CONFIG_FILE에 유지됨을 확인했다. TMUX와 PSMUX_SESSION은 psmux 여부를, 원본 설정 경로 동일성은 이 저장소의 보정 적용 범위를 판별하는 후보다. 다른 기본 psmux를 무조건 포함하지 않도록 원본 경로 정규화·현재 승인/활성화·잘못된 marker/다른 원본의 negative 검증을 후속 구현 완료 조건에 추가한다. 해당 경로 동일성 gate는 아직 코드로 구현·검증하지 않았다.

재검토 결론: namespace는 h/Esc 입력 보정 자체의 필수 조건이 아니며 기본 namespace에서도 기존 보정 유지가 실제 실험으로 가능했다. 다만 초기 결정의 적용 대상 분리 역할은 필요하므로 그 역할까지 제거하면 안 된다. 기본 namespace 정책은 새 ADR에서 범위 판별 방식·기존 기본 서버 책임·검증 조건과 함께 제안한 뒤 구현해야 한다. 원본 연결은 별도 불변 조건으로 유지하며 Windows Terminal의 발견된 독립 설정은 실제 연결 복구 대상으로 남긴다. 역사 검토·실험·현재 링크 점검 결과는 PR #16에 갱신하고, 이번 요청의 검토 단계에서 설치/사용자 환경 연결/세션 종료는 수행하지 않는다.

2026-10-08 KST 구현 계획: 사용자가 원하는 완료 기준은 부분 실험이 아니라 모든 작업 기능의 정상 동작임을 명확히 했다. 기본 namespace와 원본 설정 동일성 판별을 ADR 0006에서 제안하고 실제 저장소 runtime/Neovim 원본을 변경한다. 기존 h/l/insert/Esc 보정은 유지하고 F/D를 연결한다. 현재 다른 원본의 기본 세션은 덮어쓰지 않는다. 테스트 담당은 네 기존 통합·격리 검사만 수정하고 총괄은 runtime/키맵/문서/원본 연결 및 PR을 담당한다. 검증은 private PSMUX_DATA_DIR에서 실제 launcher·wrapper·t/fzf/dispatcher와 기존 Neovim 키 검사까지 이어서 실행한다. Windows Terminal 실제 원본 연결은 명시된 원본 연결 요구에 따라 기존 설정과 이전 호스트 기록을 백업하고 현재 승인된 호스트에서 연결·조회 검증하며, 물리 GUI/IME는 자동 완료로 쓰지 않는다. 사용자 lockfile·폰트·인증·다른 OS·의존성 버전은 변경하지 않는다.

2026-10-08 KST 전체 흐름 검사 보완: 실제 원본 launcher/main은 성공했지만 한글·공백 경로의 t 전환이 실패했다. 이름의 비ASCII 문자를 각각 _로 치환해 생성한 ___project는 namespace 구분자로 예약된 __를 포함하므로 기본 세션 목록에서도 제외됐다. 기본/named matrix의 ASCII 이름만으로 모든 경로를 검증하지 못한 누락을 실제 흐름에서 발견했다. 프로젝트 이름의 반복 underscore를 하나로 줄이고 양끝 underscore를 정리하며 명시 Session 인수의 __도 거부하도록 수정한다. 기존 이름의 해시 충돌 방지와 mux/t 보존은 유지한다. 초기 테스트 도구의 ~ 경로 해석/CLI command 인수/CP949 진단 문제도 수정했고, 성공하지 않은 시도를 통과 근거로 쓰지 않는다.

### 기본 namespace 구현 검증 및 Codex 재시작 인계

2026-10-08 KST: 실제 저장소 원본으로 기본 namespace를 구현했다. mux/t 유지, 공식 pane 신호·원본 config 동일성으로 보정 범위를 구분하고 다른 config의 기존 기본 세션은 거부한다. h/l·OSC133 insert/Esc 보정은 유지했고 F/D를 연결했다. D의 중첩 셸 인용이 실제 dispatcher에서 실패하여 원본 Invoke-DotfilesConfigProject가 기존 t에 저장소 경로를 전달하도록 수정했다. 한글 생성 이름의 __도 예약 구분자를 피하도록 수정하고 직접 __ 인수는 native 호출 전 거부한다.

검증 결과(windows-powershell, 현재 미커밋 diff): 원본 tests/windows-psmux.py 최소/오프라인 LazyVim --full-config 각 23개 통과. PowerShell 5.1과 7 runtime 검사에서 승인·호스트·사용자 mux/t 보존·config 소유권·normalized/foreign/missing/relative marker·예약 __/한글 이름·prompt 오류 상태 보존 통과. Lua foreground lifecycle와 원본 경로 negative 검사 통과. tests/windows-psmux-projects.py에서 실제 원본 launcher/main → 한글·공백 t 생성/전환 → 돌아오기 → 실제 F dispatcher/fzf 선택 → 전환 → 취소/PowerShell pane 생존 → D 원본 checkout 전환 → r 원본 reload를 검사한다. 다른 config 세션 거부·보존 및 private 세션 정리, 사용자 lockfile/프로젝트 루트 byte 보존도 포함한다. F/D/r의 실제 dispatcher는 private fixture prefix만 Ctrl+B로 바꾸어 입력했고 원본 prefix C-Space와 r 후 원본 복귀를 조회한다. 물리 Ctrl+Space 입력을 확인했다고 확대하지 않는다. 실제 WezTerm show-keys에서 기존 Ctrl+h Alt+h/ Ctrl+l 전달도 확인했다. Python check_environment의 네 OS 모의·선택/opt-in 격리, 문법·문서 상대링크·diff-check 통과. macOS/Windows 읽기 전용 리뷰와 최종 독립 리뷰에서 blocker는 없었고 취소 셸 생존·정리 통신 오류 판정을 보강했다. 다른 OS 실기기·물리 GUI·IME·클립보드는 미검증이다.

Windows Terminal 실제 연결: 기존 stable LocalState는 일반 디렉터리로 미연결이다. use-windows-terminal.ps1 -ArchivePreviousProgress로 백업/junction 연결과 이전 호스트 기록 아카이브를 적용하려는 호출은 자동 승인 검토에서 '구체적인 연결·아카이브 부작용에 대한 명시적 승인이 부족'하다는 이유로 거부됐다. 거부된 명령 전체는 실행되지 않았고 문서 갱신만 안전한 별도 호출로 완료했다. 사용자에게 해당 작업을 구체적으로 설명해 비동기 승인을 요청했으며 아직 답이 없으므로 우회·재시도하지 않는다. 현재 Neovim junction·WezTerm/PowerShell loader·psmux -f 원본 참조는 유지한다.

사용자가 현재 Codex가 mux 위에서 실행되므로 필요한 경우 자신이 mux를 종료하고 Codex를 다시 실행하겠다고 설명했다. 사용자 mux/터미널/Codex 프로세스는 종료하지 않는다. 이번 source 수정은 기존 프로세스가 읽은 함수·named namespace를 소급 변경하지 않으므로 새 프로세스에서 확인해야 한다. 현재 브랜치 fix/psmux-session-validation과 PR #16에 코드·ADR·검증·인계 기록을 제출하고 GUI/연결 확인이 남아 있으므로 draft로 전환한다. PR #15는 병합하지 않는다. 사용자 lockfile·폰트는 stage하지 않는다.

### 재시작 후 D/F 실패의 실제 연결 진단

2026-10-08 KST: 사용자가 재시작 후 Ctrl+Space D/F 모두 실패한다고 보고했다. 기준 HEAD `e0aede1`, windows-powershell이며 fetch 후 origin/main은 `1f1bf3d`, PR #16은 열린 draft다. 사용자 lockfile·폰트 변경은 보존한다. 분석·계획은 실제 연결 namespace와 키 등록을 읽기 전용으로 확인하고, 기존 서버가 남아 있으면 세션 삭제 없이 새 기본 mux로 진입하는 안내를 보완하는 것이다. ADR 0006의 기존 결정에 따른 안내 수정으로 새 ADR은 필요하지 않다.

실제 진단: 현재 프로세스의 TMUX는 공식 형식의 dotfiles named namespace이고 Test-DotfilesMuxPane은 false다. 해당 서버의 prefix는 C-Space지만 D/F binding은 없었다. 모든 TMUX/PSMUX 라우팅 변수를 제거한 자식 프로세스에서 조회한 기본 namespace는 세션이 없고, `-L dotfiles list-sessions`에는 attached main만 있었다. 로컬 승인·활성화 runtime 상태는 Ready, 원본 mux/t alias는 정상이다. 따라서 이번 프로세스 재시작은 새 기본 mux 진입까지 이어지지 않았다. Codex 재시작이나 원본 reload가 기존 서버 namespace를 바꾸지 않는다는 설명과 detach → 새 PowerShell 탭 → mux → pane TMUX 확인 절차를 사용 문서·PR에 보완한다. 실제 사용자 클라이언트 detach·서버 reload·세션 종료·설정 연결은 수행하지 않는다. 새 기본 mux의 물리 D/F 확인은 아직 남아 있으며 기존 격리 검증을 재실행한 것으로 기록하지 않는다.

재개 순서: (1) 이 기록과 ADR 0006, PR #16 및 실제 git status/저장된 호스트 승인 확인. (2) 사용자가 작업을 저장하고 기존 named mux를 종료하거나 detach한 뒤 새 터미널의 mux로 기본 main을 열고 Codex를 재실행. 기존 세션 종료는 사용자 수행을 기다리고 자동 kill-server 금지. (3) 새 환경에서 실제 Ctrl+Space → F/D/r, tmux list-sessions, 프로젝트 전환/복귀, h/l split 이동·insert Esc·Backspace를 사용자 GUI에서 확인. WezTerm과 Windows Terminal의 h 입력 경로는 다르므로 각 앱의 확인 결과를 구분한다. (4) Windows Terminal 백업/junction/진행 기록 아카이브 승인 답을 확인하기 전에는 적용하지 않고, 명시적 승인 후 기존 script로 적용·Check 및 실제 target 확인. (5) 실제 clipboard/IME까지 확인하고 draft 해제·병합 준비를 판단한다. merge는 별도 사용자 요청이다.

### 세션 전환 미해결 재신고 조사

2026-10-08 KST: 사용자가 이전 mux 세션 전환 문제가 해결되지 않았다고 재신고했다. 기준 HEAD 500b928, windows-powershell, fetch로 확인한 origin/main 1f1bf3d, PR #16은 열린 draft다. 사용자 lazy-lock.json 변경과 미추적 폰트는 보존한다. 현재 진단 프로세스에는 TMUX/PSMUX pane 변수가 없고 실제 호스트 기본/named dotfiles list-sessions 출력도 비었다. runtime prerequisites는 Ready다. 이전 named pane 잔류 진단을 이번 원인으로 확정할 수 없다.

계획: 실패하는 키/명령과 터미널·화면 반응을 사용자에게 확인하면서 private PSMUX_DATA_DIR의 원본 launcher/t/F/D 흐름을 재검증한다. 실패가 재현되면 관련 runtime과 키 설정을 수정하고 PR #16에 반영한다. 재현되지 않으면 GUI 입력과 실제 사용자 pane 연결 정보를 구분하여 추가 진단한다. 기존 사용자 세션·프로필·설정 링크·설치는 변경하지 않는다. ADR 0006의 제안 구현을 조사하는 범위이며 새 구조 결정은 아직 없다.

2026-10-08 KST 재검증 결과: py -3 -B tests/windows-psmux-projects.py exit 0. private registry에서 원본 launcher/main, 한글·공백 t 생성과 실제 client 전환/복귀, F dispatcher/fzf 선택·취소 셸 보존, D checkout 전환, r reload, 다른 config 세션 거부·보존, 테스트 세션 정리와 사용자 lockfile/프로젝트 목록 보존을 통과했다. F/D/r 입력은 기존 검사와 같이 임시 Ctrl+B이며 물리 Ctrl+Space는 미검증이다. 현재 mux/t alias와 WezTerm 원본 loader도 정상이다. wezterm cli list는 stale GUI socket 연결 실패로 활성 pane 조회를 못했다. 이번 조사에서는 runtime 결함을 재현하지 못했으며 실제 실패 명령/키·터미널·화면 반응 답을 기다린다. 해결 완료로 기록하지 않고 PR #16 draft를 유지한다. 실제 사용자 환경 적용은 수행하지 않았다.

2026-10-08 KST 후속 범위 확인: 사용자는 Ctrl+Space로 연 fzf에서 프로젝트 디렉터리를 선택한 후 세션이 실행되지 않는다고 설명했다. 기준 df11be4, origin/main 재fetch 1f1bf3d, PR #16 draft 유지. 호스트에는 원본 config marker와 F/D 등록이 있는 기본 main이 조회되지만 list-clients는 비었고 실제 실패 GUI client를 확인하지 못했다. 새 일반 PowerShell의 mux/t alias·pinned binary·profile loader는 정상이며 조사 프로세스/사용자·시스템 환경에서 FZF 출력 변경 옵션은 발견되지 않았다. 이 호스트 조회 결과를 실패한 pane 자체의 상태로 간주하지 않는다.

읽기 전용 하위 조사: 공식 로컬 3.3.8 소스에서 앞선 native -t 호출은 부모 PowerShell TMUX를 바꾸지 않으므로 source 라우팅 상실 가설을 배제했다. switch-client는 latest_client_id에 directive를 보내므로 다중 client 조건은 남은 후보이며 client 부재에도 exit 0일 수 있다. fzf 다중 출력/쿼리 출력 옵션도 경로 lookup 실패 후보지만 현재 호스트 근거가 없다. 기존 단일 ConPTY 검증을 사용자 실패의 해결 근거로 확대하지 않는다. 사용자 실패 pane의 TMUX·세션 목록과 선택 직후 오류를 요청했고, 확보 전 추정 runtime 수정/실제 적용/서버 종료는 하지 않는다.
