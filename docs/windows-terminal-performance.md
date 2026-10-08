# Windows 터미널 성능과 공통 작업 환경 제안

프로젝트 선택과 세션 시작의 지연은 **PowerShell 프로필 초기화를 먼저 줄이는 방향으로 개선 가능성이 있다**. 현재 Windows 기본 터미널은 [ADR 0004](adr/0004-windows-terminal.md)의 Windows Terminal이다. 아래 터미널 후보 비교는 초기 분석이며 현재 기본 선택을 변경하는 제안이 아니다. WezTerm의 화면 렌더링이 느리다는 결론은 아직 내릴 수 없다.

이 문서는 개선 제안이다. 기본 터미널·프로필·입력 설정을 변경하거나 프로그램을 설치하지 않았다. 요청·계획·검증·PR은 [작업 0004](work/0004-windows-terminal-performance.md), 기존 선택은 [ADR 0002](adr/0002-native-windows-adapters.md)와 [ADR 0003](adr/0003-windows-psmux.md)에 연결한다.

## 초기 셸 시작·prompt 측정

Windows 네이티브 PowerShell 7.6.6에서 자식 셸을 순차 실행했다. WezTerm은 `20240203-110809-5046fc22`, Oh My Posh는 `31.4.1`, Windows Terminal 설치 버전은 `1.24.12741.0`이다. Neovim junction과 WezTerm loader는 이 체크아웃 원본을 참조한다. GPU 이름은 Intel UHD Graphics이며 드라이버·실제 사용 backend의 성능은 검증하지 않았다.

| 시나리오 | 측정값 (ms) | 해석 |
| --- | --- | --- |
| `pwsh -NoLogo -NoProfile -Command 'exit 0'` 5회 | 240.2, 227.4, 225.1, 223.7, 230.7; 중앙값 227.4 | 프로필 없는 프로세스 시작·종료 기준 |
| `pwsh -NoLogo -Command 'exit 0'` 5회 | 2371.4, 2295.4, 2579.5, 2443.0, 2759.5; 중앙값 2443.0 | 현재 프로필이 시작 시간에 약 2.22초 추가 |
| 현재 프로필의 `prompt` 호출, 저장소 안 5회 | 377.8, 293.2, 270.3, 286.4, 301.1; 중앙값 293.2 | 명령 후 prompt 표시의 지연 후보 |
| 같은 prompt, 저장소 밖 임시 디렉터리 5회 | 294.4, 218.1, 223.2, 252.6, 255.8; 중앙값 252.6 | Git 표시만 제거해도 지연이 전부 없어지지는 않음 |
| 기본 PowerShell prompt 호출 5회 (NoProfile) | 16.7, 0.2, 0.0, 0.0, 0.0 (소수 첫째 자리 반올림) | 첫 호출 이후 비용이 작음; 같은 기능을 제공하는 비교는 아님 |
| 새 `-NoProfile` 셸에서 Git completion 원본 로드 1회 | 1063.9 | `posh-git` 초기화 비용 후보 |
| 같은 셸에서 Oh My Posh 초기화 1회 | 1046.1 | 초기화 비용 후보 |
| 같은 셸에서 psmux 로더 로드 1회 | 199.1 | 로컬 승인·파일 검사와 함수 정의; psmux attach 시간은 아님 |
| `oh-my-posh version` 호출 3회 | 335.8, 170.6, 168.4 | 외부 프로세스 실행 자체도 비용이 있음 |

구성요소 측정은 순서대로 수행한 단일 표본이며 전체 시작 시간과 정확히 합산할 수 없다. `oh-my-posh debug`의 별도 1회 결과는 총 74.1ms, Git 세그먼트 45ms였다. 실제 `prompt` 호출 시간과 debug 내부 시간의 차이는 실행·셸 연동 등의 추가 비용을 시사하지만, 그 차이 전체를 특정 코드나 Store 별칭 탓으로 단정하지 않는다.

통상 셸 프로필을 실행했으며 psmux 세션은 생성·종료·재설정하지 않았다. 도구 프로세스가 상속한 `TMUX` 환경도 있으므로 일반 새 GUI 탭·새 pane에서 재측정해야 한다. 위 수치는 headless 진단이며 창 표시, 화면 출력, 첫 interactive prompt, PSReadLine 입력·실제 IME 반응의 측정값이 아니다. 첫 실행을 포함한 5회이며 재부팅 후 cold start를 보증하지 않는다.

초기 sandbox 측정에서는 Store 실행 별칭의 Oh My Posh 접근이 실패하고 Python 등록 정보·WezTerm 홈 경로 접근도 제한됐다. 실패 상태의 수치는 비교에서 제외하고 sandbox 밖 읽기 전용 진단을 다시 수행했다. 도구 호출 대기 시간을 터미널 성능으로 계산하지 않았다.

## 프로젝트 선택·세션 시작의 지연

측정 대상은 [PR #16](https://github.com/1ocate/dotfiles/pull/16)의 `85a4896` 원본과 현재 호스트 프로필이다. F는 `pwsh -NoLogo -NoExit -Command t`로 새 셸을 시작해 프로필을 읽고 프로젝트 목록을 만든다. 선택한 세션이 없으면 별도 PowerShell pane을 생성하며, 기존 세션은 다시 사용한다. fzf 표시 전 대기, 사람의 선택 시간, 선택 후 연결, 새 pane의 첫 prompt 준비는 서로 다른 단계다.

| 구간 | 5회 측정 중앙값 | 범위와 해석 |
| --- | --- | --- |
| 프로필 없는 자식 셸 시작·종료 | 246.9ms | GUI·첫 interactive prompt 제외 |
| 현재 전체 프로필의 자식 셸 시작·종료 | 2188.2ms | 프로필이 약 1.94초 추가 |
| mux 원본만 읽고 Ready 검사한 자식 셸 | 778.7ms | 전체 프로필보다 약 1.41초 짧지만 사용자 prompt·Git 완성·t override를 제외한 비동등 비교 |
| Git completion loader | 870.3ms | 새 NoProfile 셸에서 구성요소를 순서대로 측정 |
| Oh My Posh 초기화 | 862.1ms | 같은 구성요소 측정; 전체 시작값과 단순 합산하지 않음 |
| mux loader | 214.4ms | 로컬 승인·도구 확인 및 함수 정의 |
| 현재 prompt 한 번 평가 | 405.6ms | 초기화와 분리한 비용; 첫 호출 기준 |
| 현재 프로젝트 목록 생성 | 5.6ms | 후보 2개, 첫 표본 41.1ms; 대규모·네트워크 루트 미검증 |
| fzf 비대화형 필터 실행 | 19.3ms | `--filter` 기준, 대화형 화면 표시·입력 성능은 아님 |
| private registry 새 세션 생성 명령 | 135.2ms | background pane의 프로필·첫 prompt 준비 완료를 기다리지 않음 |
| 세션 존재 확인 / config 조회 / reload 바인딩 | 39.3 / 38.0 / 36.1ms | 실제 native 호출, attach/switch 및 화면 표시 제외 |

셸 시작 원시 표본(ms)은 bare `246.9, 247.3, 301.1, 233.7, 233.9`, full profile `2342.3, 2174.8, 2169.8, 2188.2, 2199.6`, mux-only `728.5, 833.6, 775.2, 778.7, 803.3`이다. 첫 실행을 포함한 반복 측정이며 재부팅 후 cold start를 보증하지 않는다. native 세션 표본은 각각 독립 이름으로 생성한 private registry 세션이며 생성한 이름만 정리했다.

이 근거에서는 fzf 필터 자체보다 새 PowerShell 프로필이 큰 비용이다. 프로젝트 폴더 캐시나 터미널 교체보다 Git completion의 첫 사용 시 로드와 Oh My Posh 초기화 시점 조정을 먼저 검토하는 것이 타당하다. 특히 F picker가 prompt를 보여주기 전에 전체 prompt 초기화를 하는 비용을 줄일 여지가 있다. 초기화를 뒤로 옮기면 첫 Git Tab·첫 prompt에서 비용을 낼 수 있으므로 세션의 총 준비 시간까지 함께 평가해야 한다.

약 1.41초 차이는 경량 경로의 개선 여지를 보여주는 비교값이며 실제 F 흐름의 개선율이 아니다. 단순히 F에 NoProfile을 붙이면 기존 t override·Git completion·prompt·취소 후 셸의 기대 동작이 빠질 수 있다. 구현 전에는 기존 t 보존, 선택/취소 후 셸 준비, 한글·공백 경로, source config·호스트 승인, h/Esc foreground 보정과 신규/기존 세션의 첫 prompt까지 검증해야 한다. 새 pane의 프로필 비용도 남으므로 F만 가볍게 해서는 전체 대기가 없어졌다고 판단할 수 없다.

이번에는 프로필·설정 연결·패키지·실사용 세션을 변경하지 않았다. 원본 전체 흐름은 앞선 기능 검사에서 통과했으나 이번 시간 측정용 격리 ConPTY probe는 4회 모두 launcher 세션 생성 단계에서 실패해 F→대화형 fzf와 선택→실제 연결의 새 시간 표본을 확보하지 못했다. 실패한 실행은 성능 수치에서 제외했다. 사용자 GUI에서 현재 전환이 정상이라는 보고와 간헐 실패의 원인 미확정도 구분한다. 물리 Ctrl+Space, GUI·IME·클립보드, 다른 OS 실기기 성능은 미검증이다.

## 개선 우선순위

1. **프로필 경량화:** 현재 호스트 프로필의 초기화 순서를 저장소 원본 loader로 정리하는 후속 작업을 먼저 한다. Git completion은 첫 Git 완성 요청 때 로드하는 구현을 검토하되 첫 Tab 지연과 등록 누락을 확인한다. Oh My Posh를 사용하는 경로와 간단한 PowerShell prompt 경로를 임시 자식 셸에서 비교한다. 모든 탭에 `-NoProfile`을 적용하면 Git 완성·`t`·psmux 전경 복귀 처리가 빠지므로 기본 설정으로 대체하지 않는다.
2. **프롬프트 경량화:** 명시적인 저장소 로컬 Oh My Posh 테마로 표시 항목을 관리하고 Git 상세 상태, 불필요한 언어 탐지 등 비용을 비교한다. Git 세그먼트가 45ms였지만 저장소 밖에도 약 0.25초가 걸렸으므로 Git만 조정하고 완료로 판단하지 않는다. 기능 손실을 받아들일 수 있다면 단순 prompt가 가장 직접적인 비교 기준이다. [Oh My Posh 공식 문서](https://ohmyposh.dev/docs/installation/customize)는 성능을 위해 로컬 설정 파일을 권장한다.
3. **psmux 유무 비교:** 일반 PowerShell과 같은 프로필의 psmux pane에서 동일 입력·출력·Neovim 스크롤을 비교한다. 현재 `warm off`, `prediction-dimming off`, `escape-time 1`은 기존 입력 동작 보존을 위한 설정이다. 속도만을 이유로 값을 뒤집거나 기존 서버를 종료하지 않는다. launcher의 여러 CLI 호출은 시작 경로 후보이며 지속 타이핑 지연과 구분한다.
4. **GUI 렌더러 비교:** 동일 셸·프로필·글꼴·창 크기로 WezTerm과 Windows Terminal을 비교한다. WezTerm은 `front_end`를 지정하지 않았으며 날짜 status callback에 Windows 외부 프로세스 호출은 없다. `where.exe pwsh.exe`는 설정 로드 때 실행하므로 시작/reload 후보다. 필요하면 적용되지 않는 별도 실험 설정에서 OpenGL과 WebGpu를 비교한다. GPU가 다르면 결과도 다르므로 WebGpu가 항상 빠르다고 가정하지 않는다. [WezTerm backend 문서](https://wezterm.org/config/lua/config/front_end.html)
5. **Esc만 둔할 때 입력 경로 확인:** AutoHotkey는 Esc key-up에 IME 메시지를 보내고 timeout이 100ms다. 원래 Esc 입력은 통과하므로 이것만으로 Neovim Esc 지연을 확정할 수 없다. psmux의 Insert 모드 Esc 보정, 한글 조합 중/후, 키 down/up을 별도로 확인한다.

보안 검사 제외, 관리자 정책 변경, WSL 도입은 개선안에 포함하지 않는다. 프로필 변경과 터미널 설치·연결은 별도 적용 요청으로 수행한다.

## Windows용 터미널 후보

| 후보 | 추천 상황 | 현재 구성에서의 비용·한계 |
| --- | --- | --- |
| **Windows Terminal — Windows 기본값** | PowerShell·psmux 원본을 유지할 때 | JSON 원본과 junction 연결 스크립트 구현됨. AHK 실행 시 Esc 영어 전환 대상이며 실제 연결·물리 입력은 호스트별 검증 필요 |
| **WezTerm 유지** | macOS/Windows의 Lua 설정과 화면을 직접 공유하는 것이 가장 중요할 때 | 현재 원본·loader 유지 가능. 먼저 prompt 병목 개선 후 렌더러를 비교하면 교체 비용을 줄일 수 있음 |
| **Alacritty — 두 번째 비교** | 단순한 OpenGL 터미널과 multiplexer 중심 작업을 원할 때 | 현재 장비 실행 파일 미발견. 기존 TOML에 macOS Command 키, `open`, Ctrl+Q prefix 전송이 있어 그대로 Windows psmux 설정으로 쓸 수 없음 |

Windows Terminal은 색·글꼴·렌더링과 키 동작을 설정할 수 있다. 기본 하드웨어 렌더링과 부분 repaint 설정을 유지하고 실제 문제가 있을 때만 비교한다. software rendering/전체 repaint를 성능 개선 기본값으로 켜지 않는다. [렌더링 문서](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/rendering), [화면 설정](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/profile-appearance)

Alacritty는 macOS·Windows·Linux 등을 지원하는 OpenGL 터미널이다. 탭·분할 등은 별도 도구에 맡기는 성격이므로 psmux와 조합할 수 있지만 이 장비에서 더 빠르다는 실측은 없다. [프로젝트 소개](https://alacritty.org/), [설정 문서](https://alacritty.org/config-alacritty.html)

## 동일 세팅을 유지하는 방법

동일하게 유지할 핵심은 LazyVim 설정, 검색·Git 도구와 프로젝트/세션 작업, 분할·이동·복사 기대 동작이다. 터미널 제품이 달라도 이 계층은 유지할 수 있다.

| 계층 | 공통 원본과 현재 Windows 어댑터 |
| --- | --- |
| 편집기 | `nvim/`을 단일 원본으로 유지. 현재 junction과 플러그인 lockfile 보존 |
| 셸 | Windows의 `powershell/git-completion.ps1`, `powershell/psmux.ps1` 공유. 호스트에 남아 있는 prompt 초기화는 후속 작업으로 저장소 원본화. macOS fish/zsh 문법까지 강제로 같게 만들지는 않음 |
| 세션·pane | Windows는 `tmux/psmux.conf`, macOS는 기존 tmux. `Ctrl+Space`, 분할·이동·`t`의 작업 의미를 유지. Windows Terminal 자체 pane 키와 psmux pane 키를 중복 배정하지 않음 |
| 터미널 | `.wezterm.lua` 단일 원본 유지. Windows Terminal의 시작 명령·색·글꼴·키 전송은 `windows-terminal/settings.json` 원본에서 관리. Lua 설정을 JSON에 직접 로드하지 않음 |
| 원본 연결 | 호스트마다 안정적인 체크아웃 참조. Windows Terminal은 기존 설정을 백업한 뒤 저장소 디렉터리를 junction으로 참조하는 구현. [현재 연결 지침](windows-terminal.md)을 따르며 구현 존재와 현재 호스트 적용 완료는 구분 |
| 색·글꼴 | 현재 `locate` 팔레트와 Nerd Font를 기준으로 맞춤. ANSI 16색 외에 foreground/background/cursor 등 inherited 값도 실제 WezTerm에서 확인한 후 옮김. Windows Terminal의 한글 fallback·폭·아이콘은 실제 화면 확인 |
| 입력·IME | 터미널별 입력 전송과 OS별 IME만 어댑터화. 현재 AHK 원본은 WezTerm·Windows Terminal의 Esc 영어 전환을 처리. AHK가 없거나 미실행이면 원래 Esc만 전달되며 GUI 검증은 별도 |

현재 Windows Terminal 프로필은 `pwsh.exe -NoLogo`로 기존 사용자 프로필을 읽고 `mux`를 명시적으로 실행한다. WezTerm의 opt-in 자동 시작은 `scripts/start-psmux.ps1`을 사용한다. 비교할 때 이 시작 방식의 차이를 기록하며 실제 실행 파일·원본 연결과 저장된 `windows-powershell` 선택을 확인한다. 일반 PowerShell에서의 비용과 mux pane 비용을 분리하고 장비 절대 경로를 공유 설정에 고정하지 않는다.

키 검증에서 반드시 확인할 항목:

- 현재 WezTerm은 psmux opt-in 시 `Ctrl+h`를 ESC+h로, `Ctrl+l`을 `0x0c`로 전달한다. Windows Terminal의 `sendInput`으로 같은 문자를 표현할 수 있지만 물리 키 동작은 미검증이다. JSON escape는 `\u001b`를 사용한다. [공식 입력 전송 문서](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/actions#send-input)
- 이런 키 바인딩이 터미널 전체에 적용되면 plain PowerShell·SSH 탭도 영향을 받는다. psmux 전용 터미널 실행 설정 또는 키 동작 분리 방안을 검토한다.
- `Ctrl+Space`는 psmux prefix와 PSReadLine 완성 간 선택이 필요하다. 현재 psmux 사용 흐름을 유지한다. `Ctrl+Backspace`는 psmux 왼쪽 이동으로 사용되므로 단어 삭제와 충돌한다.
- 현재 WezTerm `Ctrl+V` 붙여넣기는 Neovim Visual Block과 충돌한다. Windows Terminal 원본은 Ctrl+V를 해제하고 Ctrl+Shift+V 붙여넣기를 사용한다. AHK의 Alt+C/V도 Ctrl+C/V를 보내므로 함께 확인한다.
- Windows Terminal 기본 Alt+Space는 시스템 메뉴이므로 AHK 한영 전환과 겹친다. 키 전달과 OS remap을 함께 검증한다. [기본 키 문서](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/actions#open-system-menu)
- macOS Command와 Windows Control/Alt의 물리 키를 모두 같게 만드는 것보다 같은 작업 의미를 맞춘다. Alt/Win 교환, 한글 조합, Esc 이후 영어 전환, 여러 줄 붙여넣기는 각각 실제 확인한다.

## 후속 비교의 완료 기준

현재 장비에 Windows Terminal이 있으므로 설치 없이 비교 계획을 세울 수 있다. GUI 실행·세션 접속 등 실제 작업환경 적용은 후속 요청 범위에서 진행한다.

1. 두 터미널에서 plain PowerShell과 psmux를 각각 비교한다. 같은 프로필·프로젝트·글꼴·화면 크기·동일 내용의 파일을 사용한다.
2. 창/탭 시작부터 첫 prompt, Enter 후 prompt, 일반 타이핑, 대량 출력, Neovim 스크롤과 pane 이동을 따로 측정한다. 첫 실행과 반복 실행을 구분한다.
3. 한글 조합·Esc·Backspace·Ctrl+h/j/k/l·Ctrl+Space·복사/붙여넣기와 detach/재접속을 검증한다. 화면만 빨라지고 세션·입력이 퇴행하면 전환 완료로 보지 않는다.
4. 결과에 따라 프로필 경량화와 터미널 어댑터를 별도 구현한다. Windows 기본 터미널 변경 또는 공통 터미널 방향 변경을 선택할 때 새 제안 ADR을 작성한다.

macOS·WSL·네이티브 Linux 실기기 성능, Windows Terminal/Alacritty와 psmux의 실제 GUI 연동, 설정 적용 후 개선율은 미검증이다.
