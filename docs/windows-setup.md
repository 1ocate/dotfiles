# Windows 네이티브 설치와 사용

Windows 네이티브 PowerShell용 설치·원본 연결 절차입니다. 회사 정책상 WSL을 사용할 수 없는 환경을 대상으로 하며 macOS·WSL·Linux 설치는 처리하지 않습니다. 네 환경의 통합 설치 진입점은 아직 아닙니다.

기술 선택의 이유는 [ADR 0002](adr/0002-native-windows-adapters.md), 기존 버전표·검증 결과와 진행 상태는 [작업 0002](work/0002-windows-native-setup.md)가 원본입니다. 이 문서의 과거 실행 보고를 해당 작업 기록으로 이관했습니다. 공통 환경 승인·격리 원칙은 [설정 가드레일](setup-guardrails.md)을 따릅니다.

## 사전 준비와 의존성

winget과 공통 등록 도구 실행용 Python 3.10 이상을 먼저 준비하고 저장소를 장기간 유지할 위치에 둡니다. Python이 없으면 회사에서 승인한 설치 경로를 사용합니다. 명령은 저장소 루트에서 실행합니다.

| 구성 | 필요 범위와 부재 시 처리 |
| --- | --- |
| Python 3.10 이상 (`py -3` 또는 `python`) | 환경 등록·계획·점검·승인 확인에 필수. winget 준비 단계 이전에 필요 |
| winget | 패키지 설치 시 필수. 준비된 의존성을 사용할 때 `-SkipPackages`로 설치 생략 |
| WezTerm, Neovim, PowerShell 7, Oh My Posh | 전체 설치의 사전 점검에 필수. 런타임 셸만 PowerShell 7 부재 시 Windows PowerShell 5.1로 폴백 |
| Git, Node.js·npm, rg, fd, fzf, GCC, Python | 플러그인·검색·parser·Mason 도구 준비 시 필수. 현재 컴파일러는 WinLibs. `-SkipPlugins`로 준비 생략 가능 |
| AutoHotkey v2 | 현재 실행 또는 로그인 등록 시 필수. 실행만 생략하려면 `-SkipAutoHotkey`, 등록 옵션도 지정하지 않음 |
| Meslo Nerd Font | 아이콘·화면용 선택 준비. 없으면 설치를 시도하며 `-SkipFonts`로 생략 가능 |

winget은 설치된 패키지를 유지하며 없는 패키지는 공급되는 버전을 설치합니다. 버전 숫자를 고정하지 않습니다. 현재 패키지 ID 목록의 원본은 [setup-windows.ps1](../scripts/setup-windows.ps1)입니다. 개별 기능 생략 옵션은 패키지 목록을 줄이지 않으므로 패키지를 전혀 설치하지 않을 때는 `-SkipPackages`도 지정합니다. 각 프로젝트의 LSP·포맷 런타임은 추가로 필요할 수 있습니다.

## 계획·점검과 최초 설치

```powershell
# 읽기 전용 계획과 로컬 사전 점검
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1 -Plan
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1 -Check

# 네이티브 PowerShell 사용 선택을 명시하고 설치·연결
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1 -ApprovePowerShell
```

`-Plan`·`-Check`는 Python으로 상태를 조회하지만 상태 생성·패키지 설치·설정 연결이나 적용 대상 프로그램의 시작·재시작은 하지 않습니다. `-Check`는 필요한 도구가 없으면 중단하므로 새 장비에서는 누락 목록 확인용입니다. 네트워크·설치 권한이나 GUI 기능을 보증하는 검사는 아닙니다.

최초 설치는 `.local/environment.json`에 사용 환경을 명시적으로 기록하고 이후에는 현재 호스트의 승인된 `windows-powershell` 선택을 재사용합니다. 부재·손상·호스트 불일치·다른 선택에서는 승인 없이 적용하지 않습니다. `-ApprovePowerShell`은 공통 도구의 명시적 `select` 호출이며 기존 유효한 다른 선택을 변경할 수 있습니다. 환경 변경을 의도할 때만 사용합니다. 자세한 규칙은 [공통 환경 등록](environment-registration.md)을 따릅니다. `.local/`을 다른 장비로 복제하지 않습니다.

설치 프로그램이 필요하면 관리자 승인 창이 표시될 수 있습니다. 회사 정책으로 설치·다운로드·스크립트 실행이 막히면 해당 단계에서 중단합니다. Bypass는 시작하는 프로세스에만 적용되며 조직 정책을 해제하지 않습니다. 다운로드에는 winget 공급 서버, GitHub, npm·Python 패키지 저장소 등의 접근이 필요합니다.

설치 후 WezTerm을 새로 열고 `nvim`을 실행합니다. 첫 플러그인·parser 준비에는 다운로드·컴파일 시간이 걸릴 수 있습니다. 새 장비 전체 설치는 미검증이며 검증의 근거·남은 범위는 작업 0002에서 확인합니다. 재현성 완료의 판단은 [공통 신규 설치 기준](setup-guardrails.md#신규-장비-설치와-재현성-검증)을 따릅니다.

## 기존 환경 등록과 선택 옵션

Git의 명령·브랜치 Tab 완성은 `posh-git` 1.1.0으로 제공합니다. 기본 세팅이 사용자 `Documents/WindowsPowerShell/Modules`에 모듈을 준비하고 5.1·7 프로필에 저장소의 `powershell/git-completion.ps1`을 읽는 loader를 추가합니다. 기존 프로필은 백업하고 인코딩·Oh My Posh 프롬프트를 보존합니다. 설치에는 PowerShell 7.4 이상 또는 `Save-PSResource`를 제공하는 PSResourceGet과 PSGallery 접근이 필요합니다. PSGallery 신뢰 설정은 전역으로 변경하지 않습니다.

이미 세팅된 장비에서 Git 완성만 추가하려면 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup-git-completion.ps1`을 실행합니다. 새 PowerShell 탭부터 적용됩니다. 모듈이 없으면 런타임에서 기능만 생략하며, 기본 세팅에서는 준비 실패를 알리고 프로필 연결 전에 중단합니다. `-SkipGitCompletion`은 일반 세팅의 해당 설치·연결·점검을 생략하고 기존 연결을 제거하지 않습니다. `-SkipPackages`는 모듈 다운로드도 생략하므로 이미 모듈이 있거나 `-SkipGitCompletion`을 함께 사용해야 합니다. standalone의 `-Plan`·`-Check`는 읽기 전용이며 `-SkipInstall`은 기존 모듈만 사용합니다.

참고: [posh-git](https://github.com/dahlbyk/posh-git), [Save-PSResource](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.psresourceget/save-psresource).

이미 구성된 환경은 설치를 다시 실행하기 전에 읽기 전용 점검으로 등록할 수 있습니다.

```powershell
py -3 scripts/environment.py check --environment windows-powershell
py -3 scripts/environment.py adopt-existing --environment windows-powershell
```

두 명령은 패키지·프로필·loader·junction을 바꾸거나 AutoHotkey를 재시작하지 않습니다. 등록 성공이 설치·기능 완료를 보증하지는 않습니다.

```powershell
# 패키지·글꼴·플러그인 준비 생략. 연결·프로필 처리는 진행하고 AutoHotkey는 실행
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1 -SkipPackages -SkipFonts -SkipPlugins

# 로그인 시 AutoHotkey 실행도 등록. 나머지 설치 단계는 그대로 진행
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1 -RegisterAutoHotkeyStartup
```

기본 AutoHotkey 동작은 현재 실행입니다. 대화형 세팅에서는 로그인 자동 시작 등록 여부를 묻고, `y` 또는 `yes`로 답할 때만 바로가기를 작성합니다(기본 아니오). `-RegisterAutoHotkeyStartup`은 질문 없이 등록하고, `-SkipAutoHotkeyStartup`은 질문과 등록을 생략합니다. 두 옵션은 함께 지정할 수 없습니다. 비대화형 실행에서는 명시 등록 옵션이 없으면 등록하지 않습니다. `-Plan`·`-Check`는 질문하거나 등록하지 않습니다. `-SkipAutoHotkey`는 현재 실행과 질문을 생략하지만 명시 등록 옵션은 유효합니다. 생략·거절 시 기존 바로가기는 제거하지 않습니다. `-SkipFonts`·`-SkipPlugins`는 해당 준비 단계를 생략합니다. 개별 옵션은 프로필 변경·설정 연결을 생략하지 않습니다. 사용자 실행 정책이 Undefined/Restricted이면 CurrentUser RemoteSigned로 설정합니다.

## 설정 원본과 런타임 동작

Windows loader는 `wezterm.GLOBAL.dotfiles_repo`로 체크아웃 경로를 원본에 전달합니다. WezTerm에는 Lua `debug` 라이브러리가 없으므로 경로 판별에 사용하지 않습니다. 이 변경 전 loader를 사용하는 장비는 원본 업데이트 후 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/use-wezterm.ps1`로 반드시 다시 연결해야 합니다. 기존 파일은 백업되며 다른 설치 단계는 실행하지 않습니다. 원본 직접 로드는 `wezterm.config_dir`을 사용합니다.

기존 Windows 플러그인이 설치된 장비에서는 저장소 루트에서 `python tests/windows-runtime.py`로 Neovim 설정의 격리 시작·저장·검색·창 이동·터미널 job 시작을 검사할 수 있습니다. 임시 설정·플러그인 복사본으로 PowerShell·한글 출력·yank 이벤트를 확인하며, 실제 클립보드 쓰기는 모의합니다. 검사 중 Mason/Treesitter 도구 설치는 제외합니다. 설치·원본 연결·신규 다운로드·GUI 기능 검증은 수행하지 않습니다. Enter 완성 매핑은 `nvim --headless -u NONE -i NONE -l tests/completion-mappings.lua`로 별도 모의 검사합니다.

Windows PowerShell용 WezTerm은 `TERM=xterm-256color`를 전달하여 Git 페이저의 `'wezterm': unknown terminal type` 오류를 방지합니다. 변경 후 새 탭을 열어 `$env:TERM`과 `git log`를 확인하세요. 기존 탭의 환경 변수는 바뀌지 않습니다. macOS·WSL·Linux의 기존 터미널 값은 유지합니다. 설정 항목은 [WezTerm term 문서](https://wezterm.org/config/lua/config/term.html)를 참고하세요.

전체 설치 대신 필요한 설정만 연결할 때는 Python과 해당 프로그램을 먼저 준비하고 다음 어댑터를 사용할 수 있습니다. 최초 선택 이후 명령은 현재 호스트의 승인을 재사용합니다. 두 명령은 패키지·프로필 준비를 하지 않습니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\use-neovim.ps1 -ApprovePowerShell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\use-wezterm.ps1
```

| 원본·진입점 | 역할 |
| --- | --- |
| `.wezterm.lua`, `nvim/` | 공통 설정과 플랫폼별 작은 분기 |
| `scripts/use-wezterm.ps1`, `scripts/use-neovim.ps1` | 사용자 설정을 loader·junction으로 체크아웃 원본에 연결 |
| `scripts/setup-windows.ps1` | Windows 전용 패키지·프로필·글꼴·도구 준비와 연결 |
| `scripts/setup-neovim.lua` | 승인된 Windows PowerShell에서 parser·Mason 도구 준비 및 완료 검사 |
| `autoHotKey.ahk` | Windows 키·IME 처리. macOS Hammerspoon은 그대로 유지 |

Neovim과 WezTerm은 Windows에서 현재 호스트의 저장된 선택을 읽습니다. 승인된 PowerShell 선택에만 해당 셸·도메인·Windows yank 처리를 적용하며 부재·손상·불일치에서는 안내하고 공통 설정을 사용합니다. Unix 프로세스는 Windows 선택 파일을 읽지 않습니다.

Windows 호스트가 명시적으로 WSL을 선택했다면 WezTerm은 발견한 첫 WSL 도메인과 fish 로그인 셸을 사용합니다. 발견한 도메인이 없으면 기본 도메인을 강제하지 않습니다. 특정 배포판·사용자 홈 경로를 고정하지 않으며 WSL 설치나 선택 전환을 자동으로 수행하지 않습니다. 회사 정책으로 WSL이 금지된 호스트에서는 이 방식을 사용하지 않습니다.

- 왼쪽 Alt와 Windows 키를 교환합니다. 교환 후 Alt 위치의 `Alt+Space`는 한영 전환, `Alt+C/V`는 복사·붙여넣기입니다.
- WezTerm에서만 Esc 원래 입력을 통과시키고 키를 놓을 때 영문 상태를 설정합니다. 이미 영문이면 유지하며 다른 앱의 Esc는 그대로입니다.
- Neovim의 yank는 승인된 PowerShell 환경에서 Windows 클립보드로 전달하고 F9로 연동을 켜거나 끕니다.
- 내부 셸은 PowerShell 7을 우선 사용하고 Windows 실행 별칭을 처리합니다.
- Copilot·CopilotChat은 비활성화 상태를 유지합니다. 향후 활성화하더라도 Windows의 선택적인 `make tiktoken` 빌드는 생략합니다.

## 연결 보존과 복구

기존 설정을 바꾸면 `.backup-날짜` 백업을 만들며 같은 연결의 재실행은 변경하지 않습니다. 기존 Oh My Posh 초기화는 프로필에 중복 추가하지 않습니다. 플러그인 준비 중 바뀔 수 있는 lockfile은 실행 전 원본 바이트로 복구합니다.

WezTerm loader는 `%USERPROFILE%\.wezterm.lua`, Neovim junction은 `%LOCALAPPDATA%\nvim`입니다. PowerShell 프로필은 Documents 아래 `WindowsPowerShell/`·`PowerShell/`에 있고 로그인 바로가기는 시작프로그램 폴더의 `dotfiles-AutoHotkey.lnk`입니다. 저장소 위치를 바꾸면 새 체크아웃에서 연결을 다시 적용합니다.

복구는 loader·junction 참조를 해제한 뒤 백업을 기존 이름으로 되돌리는 방식입니다. junction 대상인 저장소 폴더를 재귀 삭제하지 않습니다. 자동 제거·전체 롤백 기능은 없습니다. Git 인증·SSH·개인 Git 정보는 자동 배포하지 않습니다.

## 검사 방법과 남은 범위

`py -3 tests/check_environment.py`는 fetch된 main 파일을 임시 경로에 추출하고 Neovim·WezTerm API를 모의하여 Unix 결과와 Windows 분기·선택 격리를 검사합니다. Git·Neovim이 PATH에 필요하며 플러그인 다운로드와 외부 셸 실행은 차단합니다.

`powershell -NoProfile -ExecutionPolicy Bypass -File tests/windows-selection.ps1`는 임시 상태로 최초 승인·재사용·호스트·환경 불일치와 비Windows 거부를 검사합니다. 이 검사와 Plan/Check는 실제 설치·GUI 기능 검증을 대신하지 않습니다.

setup-state 자동 저장·PowerShell 프로필 원본화·macOS 설치 통합과 tmux·프로젝트 전환의 WezTerm 이식은 아직 포함하지 않습니다. LSP·포맷 런타임과 외부 서비스의 회사 사용 허용 여부는 프로젝트별로 확인합니다. 구체적인 과거·현재 검증 결과와 후속 작업은 작업 0002에서만 누적합니다.
## psmux와 Neovim pane 이동

Windows에서 tmux 대안으로 psmux 3.3.8을 선택적으로 사용합니다. PowerShell 7과 Windows x64가 필요합니다. 공식 portable 릴리스의 SHA256을 확인하며 최신 버전으로 자동 업데이트하지 않습니다. 원본은 [psmux.conf](../tmux/psmux.conf), 선택 이유는 [ADR 0003](adr/0003-windows-psmux.md), 검증은 [작업 0003](work/0003-windows-psmux.md)에 있습니다.

```powershell
# 기존 PowerShell 환경 승인과 설치된 도구를 확인한 뒤 별도 적용
pwsh -NoProfile -File .\scripts\setup-psmux.ps1 -Plan
pwsh -NoProfile -File .\scripts\setup-psmux.ps1
pwsh -NoProfile -File .\scripts\setup-psmux.ps1 -Check

# 새 Windows 설치에서 선택: 환경 승인 절차는 기존과 동일
powershell -NoProfile -File .\scripts\setup-windows.ps1 -ApprovePowerShell -WithPsmux
```

기존 장비의 유효한 `.local/environment.json`을 재사용합니다. 최초 장비에서는 앞의 환경 등록 절차로 PowerShell 선택을 먼저 저장합니다. psmux는 `%LOCALAPPDATA%\Programs\psmux\3.3.8`에 준비하며 기존 다른 버전이나 홈의 tmux/psmux 설정을 덮어쓰지 않습니다. 두 사용자 프로필에 저장소 `powershell/psmux.ps1`을 읽는 loader를 추가하며 기존 파일은 백업합니다. 사용자 PATH 변경 전 값은 `.local/path-before-psmux-*.txt`에 보관합니다. 호스트별 활성화 값 `.local/psmux.json`은 Git에 포함하지 않습니다.

WezTerm을 새로 열면 `main` 세션을 만들거나 다시 연결합니다. 별도 `dotfiles` 이름의 서버와 저장소의 `-f` 설정을 사용합니다. 도구가 없거나 시작이 실패하면 PowerShell 셸로 돌아갑니다. pane의 프로필은 기존 prompt 내용과 오류 표시를 보존하며 이전 전경 상태를 초기화하고, tmux.exe를 PATH 앞에 두어 Neovim navigator가 psmux를 호출하도록 합니다. PowerShell 밖에서 직접 psmux/tmux를 실행하면 이 설정·서버 선택이 적용되지 않으므로 아래 함수를 사용합니다.

| 키·명령 | 동작 |
| --- | --- |
| `mux` | main 세션 연결 |
| `mux -Session work -Path 'C:\work\프로젝트 이름'` | 지정 디렉터리의 세션 생성·연결 |
| `t 'C:\work\프로젝트 이름'` | 경로별 프로젝트 세션 생성·전환 |
| `t` | fzf로 프로젝트 선택; 현재 디렉터리와 바로 아래 폴더가 기본 목록 |
| `Ctrl+Space` 다음 `\|` / `-` | 현재 pane 경로에서 좌우 / 상하 분할 |
| `Ctrl+h/j/k/l` | 왼쪽·아래·위·오른쪽 이동; Neovim 삽입 모드는 종료 후 이동, fzf에는 키 전달 |
| `Esc` | Neovim 삽입 모드 종료; 다른 모드와 셸에는 원래 Escape 전달 |
| prefix 다음 `h/j/k/l`, `n/p`, `Space` | pane, 창, 직전 창 이동 |
| prefix 다음 `r` | 현재 체크아웃 psmux 설정 다시 읽기 |
| prefix 다음 `v`, 복사 모드 `v/q/y` | 복사 모드, 선택·블록 선택·Windows clipboard 복사 |
| prefix 다음 `d`, 다시 `mux` | detach 후 세션 재연결 |

프로젝트 목록을 따로 관리하려면 `.local/project-paths.txt`에 검색 루트를 한 줄에 하나씩 절대 경로로 적습니다. 공백·한글 경로를 지원하며 Unix `~/.project_path`의 공백 구분/eval 형식은 읽지 않습니다. 같은 폴더 이름도 전체 경로의 해시로 세션을 구분합니다. 기존 사용자 `mux`/`t` 명령이 있으면 보존하므로 `Invoke-DotfilesMux`/`Invoke-DotfilesProject` 전체 이름을 사용합니다.

Unix tmux의 Bash 프로젝트 키 `F/D`, `expr/grep/cut` 창 교환 `N/P`, `:!cat` 입력은 이 Windows 설정에 포함하지 않습니다. Windows에서는 `t`를 사용합니다.

Ctrl+H가 Ctrl+Backspace 이벤트로 전달되는 경로를 위해 두 입력을 같은 왼쪽 이동에 연결합니다. 표준 ConPTY helper의 raw 0x08은 modifier 없는 Backspace로도 해석되므로 자동 검사 결과를 모든 터미널의 물리 Ctrl+H 검증으로 간주하지 않습니다. 일반 Backspace는 유지되지만 Ctrl+Backspace의 단어 삭제는 psmux pane에서 사용할 수 없습니다.

승인된 Windows PowerShell에서 psmux가 활성화되고 실행 파일이 있을 때 WezTerm은 Ctrl+h를 Alt+h 입력으로 전달하고 psmux가 왼쪽 이동으로 처리합니다. Ctrl+l은 오른쪽 이동 입력을 명시적으로 전달합니다. 일반 Backspace는 변환하지 않습니다. 이 psmux 설정에서는 Alt+h도 왼쪽 이동으로 예약됩니다. WezTerm 키 설정은 탭 전체에 적용되므로 psmux 종료 후 일반 PowerShell fallback과 별도로 연 SSH·다른 탭에서도 Ctrl+h는 Alt+h로 전달됩니다. 이 탭들에는 psmux 이동 바인딩이 없으며 기존 Ctrl+h 편집 동작을 보장하지 않습니다. 비활성화하면 WezTerm의 기본 입력으로 돌아갑니다.

변경 반영은 Neovim에서 파일을 저장한 뒤 `Ctrl+Space` → `r`로 psmux 원본을 다시 읽고, WezTerm에서 `Ctrl+Shift+r`로 설정을 다시 읽습니다. 설치 스크립트를 재실행할 필요는 없습니다.

상하 분할은 Ctrl+J/K, 좌우 분할은 Ctrl+H/L로 이동합니다. 삽입 모드에서 반복 Ctrl+L 뒤 Escape가 멈추는 psmux/ConPTY 입력 문제를 피하기 위해, Neovim이 삽입 모드를 표시한 동안만 Esc와 이동 키를 Ctrl+\ 다음 Ctrl+N으로 일반 모드에 복귀시켜 처리합니다. Neovim 터미널 모드의 Escape는 변환하지 않습니다.

WezTerm의 Ctrl+V 붙여넣기, AutoHotkey Alt·Esc/IME 동작은 기존과 같습니다. Ctrl+Space는 pane의 PSReadLine 메뉴 완성보다 psmux prefix로 먼저 처리되며, 중첩 환경에는 prefix를 두 번 눌러 전달합니다.

```powershell
# 자동 시작 해제: 현재 서버·세션은 종료하지 않음
pwsh -NoProfile -File .\scripts\setup-psmux.ps1 -Disable
```

해제 후 WezTerm을 새로 열면 기존 PowerShell 시작으로 돌아갑니다. 프로그램·profile loader·PATH와 백업은 보존합니다. v3.3.8의 bare `psmux kill-server`는 다른 이름의 서버까지 종료할 수 있으므로 사용하지 않습니다. 필요한 경우 `psmux -L dotfiles kill-server`의 영향 범위와 작업 저장을 먼저 확인합니다. 세션은 서버가 살아 있을 때 유지되며 재부팅 후 프로세스 복원을 제공하지 않습니다.

이 변경은 현재 장비 적용과 자동 검사 범위를 제공하며 깨끗한 새 장비의 전체 설치 성공이나 GUI/IME까지 보증하지 않습니다. Neovim/psmux 검사는 기존 navigator·도구가 있는 Windows에서 `py -3 -B tests/windows-psmux.py`로 실행합니다. 실제 연결된 클라이언트에 키 바이트를 보내는 테스트 helper를 임시 경로에서 컴파일하므로 `%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe`가 필요합니다. 이 .NET Framework 컴파일러는 테스트 전용이며 일반 psmux 실행 의존성은 아닙니다. 별도 테스트 namespace/data 경로만 사용하며 플러그인을 다운로드하지 않습니다.

현재 LazyVim 설정을 함께 읽는 검사는 `py -3 -B tests/windows-psmux.py --full-config`로 실행합니다. 자동 다운로드·설치와 Lua bytecode cache를 차단한 검사이며, 일반 캐시 경로나 GUI 전체 기능 검증과 구분합니다. 셸 함수의 승인·경로 검사는 PowerShell 5.1/7에서 `tests/psmux-runtime.ps1`, 다른 환경의 설정 격리는 `py -3 -B tests/check_environment.py`로 확인합니다.

자동 검사는 Ctrl+H(Alt+h 형식)/K/L·Backspace·Esc의 실제 attached-client 입력과 Ctrl+J의 CLI 명령 전달을 구분합니다. 표준 ConPTY에서 raw Ctrl+J의 LF가 Enter로 해석되는 경로와 GUI 물리 키·IME는 별도 확인이 필요합니다.

Neovim은 승인된 Windows의 dotfiles psmux 안에서만 OSC 133 실행·종료·삽입 모드 표시를 사용합니다. LSP/terminal job 자식 프로세스가 있어도 pane의 전경 프로그램을 Neovim으로 유지하고, 종료·중지 시 해제합니다. 전체 설정 검사는 LazyVim을 통해 navigator를 로드하며 키맵을 직접 다시 덮어쓰지 않습니다.
