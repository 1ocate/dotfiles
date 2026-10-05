# 0002: Windows 네이티브 설치와 Neovim 호환성

- 상태: 리뷰 대기
- 요청·배경: 회사의 WSL 금지 조건에서 Windows 네이티브 설치와 Neovim 호환성을 제공하고 macOS 회귀를 검토하라는 요청. 이후 PR #8의 기록 가드레일을 먼저 병합하고 PR #7의 기술 결정·문서 분산을 정리하라는 요청으로 재개
- 시작일: 최초 작업 시작 시각 미확인. 첫 구현 커밋은 2026-10-03, 기록 작성은 같은 날
- 기준: 재개 전 `883fb7f`, 최신 main `bfc9dab`, main 통합 `0d98f36`
- 브랜치·PR: `feat/windows-native-setup`, [PR #7](https://github.com/1ocate/dotfiles/pull/7)(draft)
- 실행 환경: windows-powershell
- 적용 범위: common 원본 구조·호환성, windows-powershell 어댑터, Windows 호스트의 명시적인 WSL 도메인 선택. 이번 재개는 main 통합과 문서·기록 정리
- 비대상: 실제 설치·프로필·연결·시스템 적용, lockfile 갱신, PR merge, tmux 대체, 기존 역사 전체의 ADR 전환
- 관련 결정: [ADR 0002](../adr/0002-native-windows-adapters.md), [ADR 0001](../adr/0001-decision-and-work-records.md)
- 선행 작업: [작업 0001](0001-recordkeeping-guardrails.md), [PR #8](https://github.com/1ocate/dotfiles/pull/8)

## 분석과 미확인 사항

2026-10-05 Neovim 추가 작업 흐름 검토: 기준 `680cf29`, 시작 검사 외 창 이동·저장·검색·플로팅 터미널·F9 검사 확대 요청. 설치된 LazyVim 코드 대조에서 공통 Enter 매핑이 confirm 콜백을 실행하지 않는 것을 확인했고 `tests/completion-mappings.lua`로 실패를 재현했다. 전체 파일 검색도 특정 backend 이름 대신 LazyVim 공통 files 명령을 사용하도록 보완한다. 공통 기능 수정은 모든 OS에 적용하되 실행 검증은 Windows, 다른 OS는 모의/정적 범위다. 검사 fixture에서 Mason 자동 설치를 제외하여 다운로드 없이 작업 흐름을 검사한다.

2026-10-05 10:35 KST 이후 검증 결과: completion-mappings의 Enter 확정과 formatting 기본값 누락 실패를 재현하고 수정 후 통과. Windows 격리 실행은 실제 한글 파일 저장, rg 검색, Telescope 파일 목록, Neovim 분할 창 이동, Snacks 플로팅 PowerShell job 시작, 실제 OsYankToggle 명령과 모의 클립보드 쓰기 검사 통과. 전체 파일 검색 키는 실제 선택된 picker dispatcher를 통해 올바른 files 명령을 보내는지 검사했다. 네 환경 분리 모의 검사와 Python 단위 검사(13 통과·POSIX 1 제외), diff 검사도 통과했다.

검사 확대 중 임시 fixture에서 Mason/Treesitter가 도구·파서를 자동 다운로드하려는 동작을 발견하여 harness에서 provisioning을 제외했다. 당시 설치는 임시 경로에 한정됐고 최종 검사에서는 발생하지 않았다. headless 터미널 화면 출력은 GUI와 달라 job 시작 검사로 범위를 한정했다. 공통 자동완성 수정은 콜백 모의 검사이며 실제 각 OS의 완성 메뉴·IME 입력, 언어별 LSP·실제 클립보드 provider는 미검증이다. 사용자 lockfile·연결·stash는 변경하지 않았다.

2026-10-05 실사용 오류 재개: WezTerm 설정 오류 pane에서 `.wezterm.lua:8`의 `global debug nil`을 확인했다. 기준 `f536534`, stash의 기존 설정은 debug를 사용하지 않았다. loader가 공식 GLOBAL로 저장소 경로를 전달하고 직접 로드는 config_dir을 사용하도록 수정한다. 모의 검사에서도 debug를 제거하고, 실제 WezTerm 엔진으로 loader 로딩을 확인한다. 현재 호스트 loader는 백업 후 필요한 부분만 재연결하며 stash는 유지한다.

검증 결과: debug를 제거한 네 환경 모의 비교 통과. WezTerm 20240203 엔진에서 `ls-fonts --text A`로 사용자 loader와 절대 경로 원본 직접 로드 모두 exit 0, Meslo 글꼴 로드를 확인했다. 상대 경로 직접 로드의 빈 config_dir도 처리한다. 기존 loader는 백업 후 재연결했고 환경 승인·TERM·키맵을 유지했다. 앞선 `show-keys`는 설정 실행 오류를 검출하지 못했으므로 실제 엔진 검사에는 `ls-fonts`를 사용한다. GUI 새 창은 사용자 확인 대상으로 남긴다.

Windows 설치·원본 연결과 Neovim 호환성은 이미 PR #7에 구현되어 있다. 루트 main의 기존 미커밋 Windows 변경은 사용자 작업으로 보존하고 기존 PR worktree에서 재개한다. 설치 문서에 과거 버전표·실행 결과·사용 절차가 섞여 있으며 README에도 같은 검증 주장이 있다. 환경 방향 문서의 초기 평가는 현재 구현과 다른 항목이 있어 과거 기준을 명확히 해야 한다.

이 파일의 과거 기록은 사후 정리다. 출처는 아래 커밋·문서·PR이며 재실행 결과와 구분한다. 초기 실제 설치와 사용자 GUI 확인의 상세 실행 시각·로그는 미확인이다. 당시 문서에 기록되었다는 사실을 이번 검증으로 바꾸지 않는다.

## 계획과 완료 조건

과거 구현 전에 작성된 계획은 확인할 수 없어 소급 작성하지 않는다. 재개 계획은 다음과 같다.

1. PR #8 병합과 최신 main을 확인·통합하고 ADR 0001 채택·작업 0001 완료 상태를 병합 근거로 갱신한다.
2. 지속적인 기술 선택과 이유를 ADR 0002에 묶고 과거 변경·검증·버전표를 이 작업 기록으로 이관한다. 사용 문서는 현재 절차·기능·제약과 기록 링크를 유지한다.
3. 기록·PR·목록의 연결, 인코딩·문서 주장과 코드 일치, 런타임 무변경을 확인한다. main 통합 후 기존 환경 격리 검사를 재실행하고 독립 리뷰를 받는다.
4. PR #7에 커밋·push하고 본문을 현재 산출물·검증·한계와 기록 링크 중심으로 갱신한다. 새 장비 전체 설치·GUI 검증은 별도 명시적 적용 작업으로 남긴다.

문서 이관 제출 후 사용자가 신규 노트북에서도 설치 가능한지와 가드레일에 충분히 반영됐는지 확인했다. 기존 조건·미검증 표시는 있으나 깨끗한 환경의 재현성 완료 기준이 부족해, 기준 `2696492`에서 다음 보완을 진행한다. 이는 실제 설치 요청이나 설치 검증 완료가 아니다.

5. 공통 가드레일에 신규 장비의 최소 사전 준비·검증 환경·전체 설치 시나리오·완료 조건을 추가한다. ADR·사용 지침은 이 기준을 연결하고 문서 검사·독립 리뷰 후 같은 PR #7을 갱신한다. 코드·설치·사용자 설정 적용은 변경하지 않는다.

이번 재개의 제출 조건은 문서 정리·검증·독립 리뷰와 PR 갱신이다. 작업 전체의 종료는 남은 검증 범위를 PR 리뷰에서 확정하고 PR #7의 병합을 확인한 뒤 기록한다. 미검증 항목을 통과로 간주하지 않는다.

## 진행 로그

| 시각(시간대 포함) | 이유·수행 내용 | 결과·근거 | 다음 일 |
| --- | --- | --- | --- |
| 2026-10-03, 실행 상세 시각 미확인(KST), 사후 정리 | WSL 없는 Windows에 설치·원본 연결과 Neovim 호환성 추가, 이후 공통 환경 등록 도구를 재사용 | `0bc0d68`, `c04148a`, `0b6ce98`. 코드 이력이며 전체 설치 검증 근거는 아님 | 최신 main·OS 회귀 검토 |
| 2026-10-03, 상세 시각 미기록(KST), 사후 정리 | Copilot 비활성화와 사용자 변경을 보존하고 macOS·Windows·독립 리뷰로 설치 안전성 점검 | `1118882`, `3151d6a`, `883fb7f`. 중첩 경로·설치 승인 검사 및 명시 WSL 시작 수정 | 미검증 범위를 명시해 draft PR 제출 |
| 2026-10-03, 상세 시각 미기록(KST), 사후 정리 | 사용자 리뷰를 위해 구현과 검증을 제출 | PR #7. 실제 설치·프로필 변경·연결·AutoHotkey 재실행은 이 리뷰 작업에서 하지 않음 | 기록 가드레일 선행 |
| 2026-10-03 21:07:17 KST | 결정·계획·로그의 분산을 막는 선행 기준 채택 | PR #8 병합 `bfc9dab`(GitHub mergedAt 근거). 코드·설치 승인은 아님 | PR #7에서 기록 정리 재개 |
| 2026-10-03 21:10 KST | 사용자 요청으로 fetch·기존 변경 확인 후 main 통합, 기록 분리 계획 수립 | `0d98f36`. 루트 사용자 변경 보존, PR #7은 OPEN·draft 확인 | ADR·작업·사용 지침 정리 |
| 2026-10-03, 상세 시각 미기록(KST) | 설치 지침과 검증 로그의 혼재를 없애고 기록 간 연결 정리 | ADR 0002·작업 0002 생성, 버전표와 과거 결과는 출처를 붙여 이관. 사용 지침·README는 현재 절차와 링크로 정리 | main 통합 후 재검증·독립 리뷰 |
| 2026-10-03 21:22 KST | 최신 main 통합과 문서 이관이 기존 동작을 바꾸지 않는지 재검증·독립 리뷰 | 아래 이번 검증 표의 검사 통과. Python 조회와 대상 앱 실행을 구분하도록 문구 보완 | 기록 변경 제출·PR 본문 갱신 |
| 2026-10-03, 상세 시각 미기록(KST) | 문서 정리를 기존 구현 PR에서 함께 검토하도록 제출 | `d02d2d1` push와 PR #7 제목·본문 갱신 완료. ADR·작업·사용 지침 연결, draft 유지 | 사용자 리뷰와 미검증 범위 확정 |
| 2026-10-03 21:30 KST | 신규 노트북 재현성을 기존 장비 검사에서 추정하지 않도록 요청의 부족한 완료 기준 보완 | `2696492`에서 공통 신규 설치 기준 추가, ADR·사용 지침·AGENTS는 단일 기준을 연결. 실제 설치는 수행하지 않음 | 문서 검사·독립 리뷰·같은 PR 갱신 |
| 2026-10-03 21:34 KST | 신규 설치 기준의 문서 검사·독립 리뷰 후 같은 PR에 제출 | `2e11a26` push·PR #7 본문 갱신 완료. 실제 신규 설치는 미검증, draft 유지 | 사용자 리뷰·승인된 검증 환경과 범위 확정 |

## 과거 검증·적용 보고의 사후 이관

### 출처와 검증 범위

| 출처 | 옮긴 내용 | 한계 |
| --- | --- | --- |
| [환경 방향의 초기 분석](https://github.com/1ocate/dotfiles/blob/bfc9dab/docs/environment-direction.md) | 기준 `941ff6f`에서 HOME·고정 WSL 도메인·Unix 빌드·셸·클립보드 가정과 설치 안전성 제약을 정적으로 평가 | 초기 분석이며 현재 코드 설명이나 OS 실기기 검증은 아님. 원문 표는 환경 방향 문서에서 초기 평가로 구분해 보존 |
| [이관 전 Windows 문서](https://github.com/1ocate/dotfiles/blob/883fb7f/docs/windows-setup.md), [이관 전 README](https://github.com/1ocate/dotfiles/blob/883fb7f/README.md) | 기본 시작·52개 플러그인·33개 parser·검색 도구 탐지, Markdown/parser·내부 PowerShell 명령, setup-neovim 설치 완료 검사 통과 기록. 사용자의 WezTerm Esc 영문 전환 확인 보고 | 최초 세팅의 기록을 옮김. 전체 자동 설치·모든 LSP 검증은 아님. 원시 로그와 상세 시각 미확인, 이번 재실행 아님 |
| 같은 Windows 문서 | AutoHotkey 시작프로그램 미등록, 이미 설치된 Meslo 글꼴 활용. 아래 도구 버전 보고 | 당시 장비 상태이며 다른 호스트의 설치·승인 근거로 사용하지 않음 |
| `883fb7f`의 PR 제출 전 검증 단락과 PR #7의 최초 본문 | Python 14개 중 13개 통과·POSIX 권한 1개 제외, PowerShell 문법·선택·Plan/Check, main 대비 macOS/Linux/WSL 모의 비교, `-u NONE -i NONE` Lua 문법·실제 PowerShell UTF-8 출력·미승인 설치 거부·임시 경로 중첩 거부, `git diff --check` 통과 | 이전 리뷰 작업에서 실행한 범위. GUI·전체 설치·다른 OS 실기기 검증을 대신하지 않음 |
| 이전 macOS·Windows·독립 리뷰 보고, 수정 커밋 `883fb7f` | macOS 신규 회귀는 정적 리뷰에서 미발견. 중첩 경로·직접 설치 승인 누락 수정, Windows 호스트 WSL 선택 모의 검사 보완 | 리뷰 역할은 실기기 검증이 아님. 기존 Ctrl+V Visual Block 충돌은 유지 |
| [공통 등록 문서의 기존 보고](https://github.com/1ocate/dotfiles/blob/bfc9dab/docs/environment-registration.md) | Windows의 status/check 읽기 전용 실행 확인 | 공통 등록 기반의 과거 보고. 다른 OS·다른 호스트명·Windows ACL 실검증 아님 |

### 당시 도구·구성 보고

아래는 `883fb7f:docs/windows-setup.md`의 버전표를 옮긴 것이며 설치 버전 고정·현재 재확인 결과가 아니다. 적용 방식 열도 당시 보고 내용이다.

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

## 이번 재개 검증

대상은 `0d98f36` 통합 후 이 작업의 문서 diff다. runtime·lockfile은 `883fb7f`와 같으며 아래 검사만 이번 재개에서 다시 실행했다.

| 환경·검사 종류 | 명령·시나리오 | 결과·한계 |
| --- | --- | --- |
| windows-powershell, 정적 | Markdown 18파일 UTF-8·로컬 링크/앵커 검사, `git diff --check` | 링크·앵커 110개와 인코딩 검사 통과. PR·상태 링크 갱신도 확인 |
| windows-powershell, 모의 | `py -3 tests/check_environment.py` | fetch된 main `bfc9dab` 대비 macOS/Linux/WSL과 Windows 선택 분기 9시나리오 통과. 플러그인·외부 셸 미실행 |
| windows-powershell, 모의 | `nvim --headless -u NONE -i NONE -l tests/environment-state.lua` | 네 환경 ID, 호스트·누락·손상·스키마와 읽기 전용 Lua reader 검사 통과 |
| windows-powershell, 임시 상태 실행 | `powershell -NoProfile -ExecutionPolicy Bypass -File tests/windows-selection.ps1` | 승인·재사용·호스트/환경 불일치·비Windows 거부 통과. 임시 상태만 작성 |
| windows-powershell, 읽기 전용 실행 | `setup-windows.ps1 -Plan` 및 `-Check` | 계획 출력·로컬 의존성 점검 통과. Python 상태 조회 외 설치·연결·프로필·대상 앱 실행 없음 |
| 정적 리뷰 | 통합 문서·기술 결정·출처·권한을 독립 검토 | 심각 문제·이관 누락 미발견. Plan/Check가 Python 상태 조회를 한다는 문구를 반영 |

Python 전체 단위 테스트와 격리 PowerShell UTF-8·중첩 경로 검사는 이번 재개에서 반복하지 않았다. 위의 과거 검증 표에 당시 근거를 유지한다. 모든 검사는 다른 OS 실기기·GUI·전체 설치 완료를 보증하지 않는다.

## 신규 설치 기준 보완의 검증

대상은 `2696492` 이후 가드레일·AGENTS·ADR·사용 지침·이 작업 기록의 문서 diff다. Markdown 18파일의 UTF-8·로컬 링크/앵커 113개와 `git diff --check`를 통과했고 코드·lockfile 무변경을 확인했다. 독립 리뷰에서 기존 승인·환경별 검증 원칙과 충돌하거나 수정해야 할 문제를 발견하지 못했다.

문서·협업 기준만 변경하므로 런타임 검사를 반복하거나 실제 설치·연결을 실행하지 않았다. 신규 장비 전체 설치·GUI 검증은 미검증 상태를 유지한다.

## 남은 일과 미검증 범위

### 2026-10-05 PR 커밋본 Windows 재검증

사용자는 실사용 main의 미커밋 변경에 의존하지 않고 `feat/windows-native-setup` 자체가 동작하는지 확인을 요청했다. 기준 `4b0f29a`, Windows 네이티브 PowerShell에서 기존 junction을 유지하고 임시 저장소·승인 fixture·설치된 플러그인 복사본으로 검사한다. 패키지 설치·원본 연결·stash·사용자 클립보드 변경은 하지 않는다. 실제 시작·PowerShell·UTF-8과 클립보드 이벤트, 기존 모의·단위 검사를 확인하고 같은 PR에 검증 코드를 남긴다.

- Python 단위 검사 14개 중 13개 통과, POSIX 권한 검사 1개는 Windows에서 제외. 네 환경 baseline 비교와 승인 누락·호스트 불일치 등 격리 검사, Lua 상태 reader 검사 통과.
- 권한 확대 실행에서 `py -3` 3.13.15 정상, `tests/windows-selection.ps1`, `setup-windows.ps1 -Plan`·`-Check` 통과. 앞선 `No installed Python found!`는 샌드박스 제한에서만 발생했으며 실제 설치 오류로 확정할 근거가 없음을 정정한다.
- `python tests/windows-runtime.py`: 설치된 플러그인을 임시 경로에 복사하고 다운로드·업데이트 확인을 비활성화하여 실제 LazyVim 시작, PowerShell 명령과 한글 출력, Copilot·자동 포맷 비활성화, Windows yank와 토글 검사 통과. `+` 레지스터 쓰기만 모의하여 실제 시스템 클립보드 내용은 변경하지 않는다. 복사된 lockfile 불변도 검사한다.
- 초기 검증 harness의 Windows 데이터 경로 오류와 이미 초기화된 clipboard provider 모의 방식 오류를 수정했다. PR 런타임 설정 자체의 회귀는 발견하지 않았다. 기존 Windows TERM 모의 검사에도 명시 assertion을 추가했다.
- 기존 사용자 설정과 junction은 보존. 기존 플러그인 캐시를 복사해 사용했으므로 신규 설치 검증은 아니다. 실제 clipboard provider·GUI 키·IME·LSP·새 장비 전체 설치 및 다른 OS 실기기는 미검증이다.

- 앞선 문서 이관 제출과 신규 설치 기준 보완의 문서 검사·독립 리뷰·PR #7 반영은 완료. 현재 리뷰 대기이며 작업 전체의 검증 범위 확정·병합 확인이 남아 있다.
- 신규 Windows 검증은 winget·실행 가능한 Python 3.10 이상·저장소 확보와 기본 PowerShell 5.1을 시작 조건으로 선언하고 다른 도구·프로필·캐시의 기존 유무를 기록해야 한다. 승인된 깨끗한 환경 확보·실제 설치 요청이 필요하며 현재 장비의 도구를 삭제해 검증하지 않는다. 전체 준비·연결·최초 시작·기본 작업·재실행·실패/복구 시나리오는 공통 가드레일을 따른다.
- 새 Windows 장비 전체 설치, macOS/Linux/WSL 실기기, GUI 키·IME·클립보드, 모든 언어별 LSP·포맷, Copilot 외부 연결은 미검증. 검증 범위 확정 전 draft 유지.
- setup-state 자동 저장, PowerShell 프로필 원본화, macOS 설치 통합, tmux·프로젝트 전환 대체는 후속 목표로 분리할 때 이 작업과 연결.
- PR #7 병합 확인은 아직 없음. 작업·기술 결정의 완료·채택이나 현재 호스트의 적용 완료를 주장하지 않음.

## AutoHotkey 자동 시작 선택 보완

2026-10-05: 후속 요청으로 Windows `git log`의 `'wezterm': unknown terminal type` 오류 영구 수정을 진행한다. 사용자가 세션의 `TERM=xterm-256color`로 해결됨을 확인했다. 실사용 원본과 PR의 Windows PowerShell 분기에만 TERM 호환값을 적용하고 macOS·WSL·Linux의 기존 값은 유지한다. Lua 문법 검사 후 같은 PR에 제출하며 새 GUI 세션 검증은 사용자 확인 대상으로 남긴다.

검증: Windows에서 `nvim --headless -u NONE -i NONE`의 `loadfile`로 두 원본의 Lua 문법 검사 통과, 두 diff의 공백 검사 통과. PR의 조건식은 `windows-powershell`만 변경하며 다른 환경은 `wezterm`을 유지함을 정적으로 확인했다. 기존 키맵·셸·tmux·IME 및 lockfile은 수정하지 않았다. 새 GUI 탭과 다른 OS 실기기 검증은 미수행이다.

2026-10-05 09:31 KST: 사용자가 자동 등록 대신 세팅 중 등록 여부 질문을 요청했다. 기준 `dc43677`, Windows 네이티브 PowerShell에서 PR #7의 같은 브랜치를 수정한다. 대화형 실행은 기본 아니오 질문, 명시 등록·생략 옵션은 질문 생략, 비대화형 실행은 미등록으로 처리한다. Plan/Check는 읽기 전용으로 유지한다. 코드·사용 지침·ADR을 갱신하고 선택 분기 모의 검사와 문법 검사를 수행한다. 실제 설치·시작프로그램 등록 및 다른 OS 실기기 검증은 범위 밖이다.

검증: Windows PowerShell 5.1에서 `powershell -NoProfile -ExecutionPolicy Bypass -File tests/autohotkey-startup.ps1` 통과. 문법, 응답 10가지 모의 분기, 충돌 옵션 거부를 확인했고 설치·등록은 수행하지 않았다. `git diff --check` 통과. 실제 `-Plan`은 기존 환경 확인 어댑터가 호출한 `py -3`의 `No installed Python found!`로 중단되어 전체 실행은 미검증이다. 설치 실행·로그인 후 자동 시작·다른 OS 실기기는 미검증으로 남긴다. 독립 리뷰에서 발견한 `-NonInteractive` 축약 인수 감지 누락을 보완했다.
