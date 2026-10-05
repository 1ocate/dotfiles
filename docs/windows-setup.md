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

기존 Windows 플러그인이 설치된 장비에서는 저장소 루트에서 `python tests/windows-runtime.py`로 커밋된 Neovim 설정의 격리 시작을 검사할 수 있습니다. 임시 설정·플러그인 복사본으로 PowerShell·한글 출력·yank 이벤트를 확인하며, 실제 클립보드 쓰기는 모의합니다. 설치·원본 연결·신규 다운로드·GUI 기능 검증은 수행하지 않습니다.

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
