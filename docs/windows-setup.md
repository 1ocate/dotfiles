# Windows 네이티브 설치와 검증 기록

2026-10-03에 이 저장소로 구성한 Windows 네이티브 환경을 재현하기 위한 기록입니다.
공통화 설계가 끝나기 전의 임시 절차이며, 이후 OS별 설치 체계로 통합할 예정입니다.
회사 보안프로그램으로 WSL을 사용할 수 없어 PowerShell과 Windows용 도구를 사용합니다.

## 다음 장비에서 한 번에 실행

Windows에 winget이 있어야 합니다. 저장소를 장기간 유지할 위치에 내려받고 저장소 루트에서 실행합니다.
최초 설치에는 사용자의 네이티브 PowerShell 선택이 필요합니다. 아래 -ApprovePowerShell 옵션으로 이를 명시하고, 이후 실행에서는 현재 호스트의 로컬 선택을 재사용합니다. 선택 기록은 .local/environment.json이며 Git에 포함하지 않습니다. 다른 호스트로 복제하지 마세요. 이 진입점은 WSL 설치나 Windows와 WSL 사이의 전환을 구현하지 않습니다.

```powershell
# 변경 없이 실행 계획 확인
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1 -Plan

# 설치와 설정 적용
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1 -ApprovePowerShell
```

설치 프로그램이 필요한 경우 Windows 관리자 승인 창이 표시될 수 있습니다.
회사 정책에 의해 도구 설치·다운로드·스크립트 실행이 차단되면 해당 단계가 실패합니다.
실행 명령의 Bypass는 시작하는 프로세스 범위에만 적용되며 조직 정책을 해제하지 않습니다.
필요한 호스트는 winget의 다운로드 서버, GitHub, npm 및 Python 패키지 저장소 등입니다.

설치 완료 후 WezTerm을 새로 열고 `nvim`을 실행합니다.
첫 실행과 문법 파서 설치는 다운로드·컴파일 때문에 시간이 걸릴 수 있습니다.
재현 스크립트 전체를 새 장비에서 실행한 검증은 아직 하지 않았습니다.
현재 장비에서는 PowerShell 문법 검사, 변경 없는 `-Plan` 실행과
`setup-neovim.lua`의 플러그인·문법 파서·Mason 설치 완료 검사를 통과했습니다.

## 적용하는 내용과 확인한 버전

### 이전 선택 확인과 재사용

설치 대상의 정확한 이름은 `windows-powershell`입니다. Windows OS 감지만으로 이 환경을 승인하지 않습니다. `-Plan`과 `-Check`도 `.local/environment.json`의 기존 선택을 표시하며 상태를 생성하지 않습니다.

최초 설치는 `-ApprovePowerShell`로 선택을 승인하고 로컬 파일에 환경·호스트·승인 여부·시각을 기록합니다. 재실행은 같은 호스트의 승인된 `windows-powershell` 값을 먼저 확인해 재사용합니다. 기록이 없거나 다른 호스트의 기록이면 변경 전에 중단합니다. `windows-wsl`이 저장되어 있으면 이를 PowerShell로 자동 덮어쓰지 않습니다. 명시적으로 환경을 변경할 때만 다시 승인하며 기존 상태는 백업합니다.

Neovim과 WezTerm은 읽기 전용 `environment.lua`로 같은 상태 파일을 확인합니다. OS 판별과 선택값을 구분하며, 승인된 현재 호스트의 `windows-powershell` 선택에만 PowerShell 셸·도메인·Windows 클립보드 처리를 적용합니다. 선택이 없거나 손상되면 안내를 표시하고 공통 설정만 사용합니다. 저장된 WSL 선택에서도 네이티브 PowerShell 처리를 적용하지 않으며, WSL 설치/도메인 전환은 별도 구현 범위입니다. Unix 프로세스는 Windows 선택 파일을 읽지 않습니다.

`.local/`은 Git 추적에서 제외합니다. 이 파일과 토큰을 포함한 폴더를 다른 장비로 복제하지 않습니다.

아래 버전은 현재 장비에서 확인한 기록입니다. winget 설치는 설치된 패키지를 유지하고,
없는 패키지는 저장소에서 제공하는 버전을 설치합니다. 아래 숫자로 버전을 고정하지는 않습니다.

| 구성 | 확인한 버전 / 상태 | 적용 방식 |
| --- | --- | --- |
| Windows | Windows 11 Pro, 빌드 26200 | 테스트한 OS |
| Windows PowerShell | 5.1.26100.9168 | 기본 제공, 프로필 유지 |
| PowerShell | 7.6.6 | WezTerm 및 Neovim 내부 셸에서 우선 사용 |
| Oh My Posh | 31.4.0 | PowerShell 5.1·7 사용자 프로필에 초기화 추가 |
| AutoHotkey | 2.0.28 | 저장소의 `autoHotKey.ahk` 실행 |
| WezTerm | 20240203-110809-5046fc22 | 사용자 홈 로더가 저장소 `.wezterm.lua`를 읽음 |
| Neovim | 0.12.5 | `%LOCALAPPDATA%\nvim`을 저장소 `nvim/`에 junction으로 연결 |
| Neovim 플러그인 | 52개 | `nvim/lazy-lock.json` 기준 복원 |
| 문법 파서 | 33개 설치 확인 | Treesitter 구성의 언어 목록으로 설치 |
| 글꼴 | MesloLGMDZ Nerd Font | 기존 설치를 활용했으며, 재현 스크립트는 없으면 Meslo 설치 |
| Git | 2.55.0.5 | 플러그인 다운로드와 Git 작업 |
| Node.js LTS | 24.19.0 | 플러그인·npm 기반 언어 도구 |
| Python | 3.13.15 | SQL/Python 기반 도구 |
| fd / fzf | 10.5.0 / 0.74.4 | 파일 검색과 선택 |
| ripgrep | 기존 설치 15.2.0 | 텍스트 검색 |
| WinLibs GCC | 16.2.0-14.0.0-r1 | Treesitter 문법 파서 컴파일 |

## 설정 파일과 키 동작

| 파일 | 현재 역할 |
| --- | --- |
| `.wezterm.lua` | 공통 색상·글꼴, 실제 OS 판별, Windows의 네이티브 PowerShell 실행 |
| `autoHotKey.ahk` | AutoHotkey v2 문법 및 Windows 키 동작 |
| `nvim/` | 기존 LazyVim 설정과 Windows 호환 처리 |
| `scripts/use-wezterm.ps1` | WezTerm 설정 연결 |
| `scripts/use-neovim.ps1` | Neovim 설정 연결 |
| `scripts/setup-windows.ps1` | 이번 기록을 재현하는 임시 진입점 |
| `scripts/setup-neovim.lua` | 문법 파서·Mason 도구 설치 완료 확인 |

- 왼쪽 Alt와 왼쪽 Windows 키를 교환합니다.
- 교환 후 Alt 위치에서 `Alt+Space`는 한영 전환, `Alt+C/V`는 복사·붙여넣기입니다.
- **WezTerm에서만** Esc 원래 입력을 전달하고 키를 놓을 때 IME를 영문 상태로 설정합니다.
- Esc는 한영 토글 키를 보내지 않으므로 이미 영문이면 영문을 유지합니다.
- 다른 앱의 Esc에는 영문 전환 처리가 적용되지 않습니다.
- Neovim에서 yank는 Windows 클립보드로 전달하고 F9로 연동을 켜거나 끕니다.
- Neovim 내부 셸은 PowerShell 7을 우선 사용하며, Windows 실행 별칭도 처리합니다.
- Windows에서는 CopilotChat의 선택적인 `make tiktoken` 빌드를 실행하지 않습니다.

사용자가 WezTerm의 Esc 영문 전환이 정상 동작함을 확인했습니다.
자동 검사에서는 Markdown 파일 열기·문법 파서와 Neovim 내부 PowerShell 명령 실행을 확인했습니다.
언어별 LSP·포맷과 Copilot 서버 연결은 모든 기능을 검증한 상태가 아닙니다.

## 선택 옵션과 재실행

```powershell
# 설치된 도구를 활용하고 설정만 다시 연결
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1 -SkipPackages -SkipFonts -SkipPlugins

# 다음 로그인부터 AutoHotkey도 자동 실행
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1 -RegisterAutoHotkeyStartup
```

현재 장비에는 AutoHotkey 시작프로그램 등록을 하지 않았습니다.
기본 스크립트는 현재 실행만 하며, `-RegisterAutoHotkeyStartup`을 지정할 때만 로그인 바로가기를 만듭니다.
`-SkipAutoHotkey`는 현재 실행을 생략하며, `-SkipFonts`·`-SkipPlugins`는 해당 설치 단계를 생략합니다.
이미 설치된 패키지는 업데이트하지 않습니다. 기존 프로필의 Oh My Posh 초기화는 중복 추가하지 않습니다.
기존 사용자 설정을 바꿀 때는 `.backup-날짜` 백업을 남기며, 설정 연결은 반복 적용할 수 있습니다.
사용자 실행 정책이 Undefined/Restricted인 경우에만 CurrentUser RemoteSigned로 설정합니다.
플러그인 설치 중 변경될 수 있는 잠금 파일은 실행 전 원본으로 복구합니다.

## 장비별로 남겨둔 작업

- Git 사용자 정보와 인증, SSH 키, 프로젝트 경로는 기존 사용자 설정을 사용합니다.
- Copilot 인증과 회사의 외부 서비스 사용 가능 여부는 별도로 확인합니다.
- PHP·Java 등 각 프로젝트 런타임은 프로젝트 요구사항에 맞게 별도 설치합니다.
- tmux 기능과 프로젝트 전환을 WezTerm workspace로 옮기는 작업은 아직 하지 않았습니다.
- macOS 셸을 PowerShell로 변경하거나 기존 Unix `install`을 실행하지 않습니다.

## 복구와 이후 공통화

WezTerm 사용자 설정은 `%USERPROFILE%\.wezterm.lua`, Neovim 연결은 `%LOCALAPPDATA%\nvim`입니다.
PowerShell 프로필은 Windows의 Documents 경로 아래 `WindowsPowerShell/`와 `PowerShell/`에 있습니다.
설정 연결을 해제할 때 Neovim junction의 대상인 저장소 폴더를 재귀 삭제하지 않도록 주의합니다.
백업이 있다면 로더·junction을 해제한 뒤 기존 이름으로 복원합니다.
로그인 바로가기는 사용자 시작프로그램 폴더의 `dotfiles-AutoHotkey.lnk`입니다.
이 스크립트는 자동 제거·전체 복구 기능을 제공하지 않습니다.

공통화에서는 이 기록의 동작을 기준으로 유지하고, OS별 구현과 장비별 예외를 분리합니다.
PowerShell 프로필도 파일로 관리하고 설치 절차를 macOS/Windows 공통 구조에 통합할 예정입니다.
현재 연결은 저장소 경로를 사용하므로 폴더를 이동했다면 새 위치에서 설치 스크립트를 재실행합니다.

관련 방향: [개발 환경의 평가와 방향](environment-direction.md)

## 환경 격리 검증

`py -3 tests/check_environment.py`는 main 파일을 임시 경로에 추출하고 Neovim·WezTerm API를 모의하여 macOS/Linux/WSL 결과가 기존 설정과 같은지 비교합니다. Windows 분기 진입도 확인합니다. 플러그인 다운로드와 외부 셸 실행은 차단합니다.

`powershell -NoProfile -File tests/windows-selection.ps1`는 임시 상태 파일로 최초 승인, 재실행, 호스트·환경 불일치, 비Windows 거부를 확인합니다. 설치 스크립트 문법과 -Plan/-Check도 확인했습니다.

이 검사는 다른 OS의 실기기 검증을 대신하지 않습니다. 새 Windows 장비 전체 설치, macOS/Linux/WSL 실기기 회귀 검증, 모든 LSP·Copilot 기능은 미검증입니다.
