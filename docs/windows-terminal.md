# Windows Terminal 사용과 설정 원본

Windows 네이티브 PowerShell의 기본 터미널은 Windows Terminal입니다. macOS의 WezTerm, 기존 WSL·Unix tmux와 공통 Neovim 원본은 유지합니다. 선택 이유는 [ADR 0004](adr/0004-windows-terminal.md), 구현·검증은 [작업 0006](work/0006-windows-terminal.md)에 기록합니다.

## 설치와 최초 연결

Windows Terminal과 PowerShell 7을 먼저 준비합니다. 회사 정책으로 설치·실행이 제한되면 중단합니다. 전체 설치의 패키지·사전 준비는 [Windows 설치 지침](windows-setup.md)을 따릅니다.

```powershell
# 읽기 전용. 설치·연결·승인 파일 생성 없음
powershell -NoProfile -File scripts/use-windows-terminal.ps1 -Plan
powershell -NoProfile -File scripts/use-windows-terminal.ps1 -Check

# 현재 호스트의 유효한 PowerShell 선택이 있으면 재사용
powershell -NoProfile -File scripts/use-windows-terminal.ps1
```

처음 장비에서 PowerShell 사용을 명시적으로 선택하려면 연결 명령에 `-ApprovePowerShell`을 추가합니다. 이미 세팅된 장비는 `py -3 scripts/environment.py adopt-existing --environment windows-powershell`로 읽기 전용 점검 후 선택을 등록할 수 있습니다. 호스트 불일치와 손상된 기록은 자동 승인하지 않습니다. `.local/setup-state.json`의 진행 기록이 다른 호스트·환경에 속하면 연결 전에 중단합니다. 기록을 확인한 뒤 `-ArchivePreviousProgress`를 명시하면 원본을 백업하고 현재 호스트의 새 진행 기록을 시작합니다. 환경 승인을 대신하거나 이전 완료 상태를 재사용하지 않습니다. 실행 정책은 변경하지 않으므로 정책에 의해 실행이 차단되면 승인된 실행 경로를 사용합니다.

연결할 때 Windows Terminal 창을 닫고 별도 PowerShell에서 실행하는 것을 권장합니다. 스크립트는 실행 중인 터미널이나 세션을 강제 종료·재시작하지 않습니다. Windows 설정의 **기본 터미널 애플리케이션**은 별도 OS 설정이므로 자동 변경하지 않습니다. Windows Terminal 설정 → 시작에서 사용자가 선택할 수 있습니다.

## 자동으로 원본을 읽는 방식

일반 설치는 다음 설정 디렉터리를 저장소 `windows-terminal/`로 연결합니다.

```text
%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState
    → <checkout>\windows-terminal
```

연결은 디렉터리 junction입니다. 사용자가 매번 JSON을 import하거나 복사하지 않습니다. Windows Terminal은 원래 `LocalState/settings.json`을 읽지만 실제 파일은 저장소의 `windows-terminal/settings.json`입니다. 파일 심볼릭 링크 권한·Developer Mode 변경을 요구하지 않습니다. 회사 정책이 junction도 막으면 기존 설정을 이동하기 전에 중단합니다.

기존 설정 디렉터리 전체는 같은 부모 아래 `LocalState.backup-<ID>`로 보존합니다. 개인 프로필·설정과 runtime state를 공유 JSON으로 자동 복제하지 않습니다. 같은 연결의 재실행은 새 백업을 만들지 않습니다. 새 설정은 기존 개인 프로필을 기본으로 제공하지 않으므로 필요한 개인 설정은 백업을 확인하여 추가하고 공개 Git diff를 검토하세요.

Preview 또는 비패키지 설치는 `-Channel preview` / `-Channel unpackaged`로 해당 설정 경로만 선택합니다. 한 checkout을 한 호스트·한 channel에서 사용합니다. 다른 channel로 바꾸기 전 기존 연결을 복구하며 실행 중인 여러 channel이 같은 runtime state를 공유하지 않게 합니다.

## 수정과 복구

일상적인 수정 대상은 `windows-terminal/settings.json`입니다. 파일 저장 후 Windows Terminal의 재로드 또는 새 창에서 확인합니다. 설정 화면에서 저장하면 원본에도 변경이 남으므로 `git diff -- windows-terminal/settings.json`을 검토합니다. Git checkout과 설정 UI 방식의 파일 교체 뒤에도 디렉터리 연결이 유지되는 것을 임시 대상에서 검증했습니다. 실제 UI 저장은 별도 확인이 필요합니다.

터미널이 만드는 `state.json`·캐시 등은 `windows-terminal/.gitignore`에서 제외합니다. 설정을 커밋할 때 관리할 JSON만 명시적으로 stage하고 개인 경로·SSH 프로필·계정 정보가 들어갔는지 확인합니다. runtime 파일을 force-add하지 않습니다.

복구할 때는 Windows Terminal을 닫고 `Get-Item <LocalState> -Force`의 `LinkType`·`Target`이 현재 저장소를 가리키는 junction인지 먼저 확인합니다. 확인한 junction 항목만 `[IO.Directory]::Delete(<LocalState>, $false)`로 제거하고 백업 디렉터리를 원래 이름으로 `Move-Item -LiteralPath` 합니다. 재귀 삭제·`Remove-Item -Recurse`로 연결을 제거하지 않습니다. 기록된 `.local/setup-state.json`의 `components.windows_terminal` 상태도 실제 연결과 함께 갱신합니다. 일반 연결의 백업 경로는 명령 출력과 `.local/setup-state.json`의 `components.windows_terminal.backup`에서 확인합니다. 이전 호스트의 진행 기록을 archive한 뒤 이미 연결된 대상을 재사용하면 새 컴포넌트의 backup은 비어 있을 수 있습니다. 이때 `previous_progress_backup`이 가리키는 보존된 JSON에서 이전 백업 경로를 확인합니다. 이전 완료 상태나 호스트 경로를 그대로 신뢰하지 말고 현재 LocalState의 부모 아래 실제 백업 디렉터리가 있는지 확인한 뒤 복구합니다.

## 지정 폰트

Windows Terminal의 `font.face`는 `MesloLGMDZ Nerd Font Mono`, 크기는 `11`입니다. 사용자가 지정한 [Meslo M-DZ Mono Regular 원본](https://github.com/ryanoasis/nerd-fonts/blob/master/patched-fonts/Meslo/M-DZ/MesloLGMDZNerdFontMono-Regular.ttf)을 사용합니다. 파일명과 폰트 패밀리 이름은 다르므로 JSON에는 `.ttf` 파일명을 넣지 않습니다.

설치 원본 commit과 SHA-256은 `fonts/meslo.json`에서 관리하며 폰트 바이너리는 Git에 포함하지 않습니다. 전체 설치는 해당 폰트를 준비하고 `-SkipFonts`는 생략합니다. Windows Terminal 연결만 실행하면 폰트를 설치하지 않습니다. 별도 읽기 전용 점검은 `scripts/setup-meslo-font.ps1 -Check`, 설치 계획은 `-Plan`으로 확인합니다. 실제 설치는 현재 호스트의 PowerShell 선택을 확인하고 사용자 Fonts 경로와 HKCU Fonts에 등록합니다. 같은 이름의 다른 파일·등록은 덮어쓰지 않고 중단하므로 기존 설정을 검토합니다. 설치 결과는 `.local/setup-state.json`의 `components.meslo_font`에 남기며 파일·등록 검증과 화면 표시 미검증을 구분합니다. 다른 호스트·환경의 진행 기록은 폰트 변경 전에 중단하므로, 앞의 Terminal 연결 절차에서 기록을 검토하고 명시적으로 archive한 후 다시 진행합니다. 설치 후 새 Windows Terminal 창에서 선택된 폰트와 아이콘을 확인합니다.

`master`의 최신 파일을 매번 받는 방식이 아니므로 버전 변경은 manifest의 commit·체크섬을 함께 검토하는 별도 변경입니다. 명시적으로 선택한 WezTerm도 Windows 네이티브 PowerShell에서는 Mono 패밀리를 우선하며, macOS·WSL의 기존 폰트 선택은 유지합니다. per-user 등록 근거는 [Microsoft winget Fonts 구현](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCommonCore/Fonts.cpp)입니다.

## PowerShell·psmux·키 입력

기본 프로필 `Dotfiles PowerShell`은 PowerShell 7과 기존 사용자 프로필을 읽습니다. psmux는 [선택 설치](windows-setup.md#psmux와-neovim-pane-이동)이며 터미널 시작 시 강제로 실행하지 않습니다. `mux`로 저장소 설정의 main 세션에 연결합니다. `tmux`를 직접 실행하면 해당 설정·서버 선택을 거치지 않습니다.

프로젝트 선택기는 prefix → `Shift+F`로 열지만 psmux 3.3.8의 namespace 전환 결함 때문에 선택 후 자동 세션 전환은 실패할 수 있습니다. 오류에 표시된 세션은 보존됩니다. [psmux 사용 지침](windows-setup.md#psmux와-neovim-pane-이동)의 detach 후 바깥 PowerShell 연결 방법을 따릅니다.

`mux`가 없으면 먼저 새 PowerShell 탭을 열고 `Get-DotfilesMuxStatus`로 진단합니다. 명령 자체가 없다면 `powershell/psmux.ps1` 프로필 loader가 연결되지 않았거나 이전 원본을 읽는지 확인합니다. 임시 진단은 `. .\powershell\psmux.ps1` 후 호출할 수 있으며 재설치·환경 자동 승인은 하지 않습니다.

| 키 | 동작·담당 |
| --- | --- |
| `Ctrl+Space` → `\|` / `-` | psmux 좌우 / 상하 분할. Windows Terminal은 키를 선점하지 않음 |
| prefix → `Shift+F` | 현재 pane 경로에서 `t` 프로젝트 선택을 새 PowerShell 창으로 실행 |
| prefix → `h/j/k/l` | psmux pane 이동 |
| `Ctrl+h/j/k/l` | 기존 psmux/Neovim 이동. 터미널의 물리 입력 경로는 별도 검증 |
| `Alt+h` | 기존 psmux 왼쪽 이동 대체. psmux 밖에는 터미널의 기본 입력 유지 |
| `Ctrl+Shift+V` | 터미널 붙여넣기 |
| `Ctrl+V` | Neovim Visual Block 등에 전달하도록 터미널 붙여넣기 해제 |
| `Esc` | 원래 입력 전달. 저장소 AutoHotkey v2 실행 시 키를 뗄 때 영어 IME로 전환 |

Windows Terminal 전역 단축키를 SSH 탭까지 바꾸지 않도록 Ctrl+h→Alt+h 전송을 추가하지 않습니다. Esc 영어 전환은 `autoHotKey.ahk`가 활성 Windows Terminal 또는 WezTerm 창에만 적용하며 이미 영어면 그대로 유지합니다. AutoHotkey를 실행하지 않으면 영어 전환 없이 Esc만 전달됩니다. Windows Terminal 창의 모든 탭(SSH 포함)에 적용하며 원격 서버의 IME를 변경하는 기능은 아닙니다. Alt+Space의 터미널 메뉴와 기존 AutoHotkey 입력 전환, 물리 Ctrl+Space·Ctrl+h·Esc/IME는 GUI에서 별도로 확인해야 합니다. 원격 Vim Esc 문제는 [PR #12](https://github.com/1ocate/dotfiles/pull/12)의 독립 조사이며 이번 변경으로 해결됐다고 판단하지 않습니다.

공식 근거: [설정 경로](https://learn.microsoft.com/en-us/windows/terminal/install), [fragment 범위](https://learn.microsoft.com/en-us/windows/terminal/json-fragment-extensions), [단축키와 sendInput](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/actions), [기본 터미널 OS 설정](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/startup).
