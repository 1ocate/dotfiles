# 0006: Windows Terminal 기본 사용과 Git 설정 관리

- 상태: 진행 중
- 요청·배경: PC 세팅 중 Windows Terminal의 tmux 기본 설정 및 mux 등록 실패를 확인했다. 사용자는 Windows에서는 Windows Terminal을 사용하도록 세팅하는 방향과 PR을 요청했다.
- 시작일: 2026-10-07
- 기준: main/origin/main 73bbe35, feat/windows-terminal
- 실행 환경: windows-powershell
- 범위: Windows Terminal JSON 원본·안전한 연결 어댑터, Windows 설치의 터미널 선택, psmux 등록 실패 안내, 관련 사용 문서·검증
- 비대상: macOS/WSL/Linux 설정 적용, 사용자 lazy-lock 변경, 기존 설치 전체 재실행, OS 기본 앱 설정 변경, WezTerm Esc/IME 범위 확장, PR #12의 원격 Esc 런타임 해결
- 관련 ADR: [ADR 0004](../adr/0004-windows-terminal.md), [ADR 0002](../adr/0002-native-windows-adapters.md), [ADR 0003](../adr/0003-windows-psmux.md)
- 관련 PR: 제출 후 갱신. 열린 PR #11(작업 0004)의 분석을 참고하고 #12(작업 0005)의 별도 SSH Esc 조사를 침범하지 않는다.

## 분석과 계획

현재 main은 WezTerm을 필수 설치·점검·연결한다. Windows Terminal은 설치되어 있지만 settings.json은 저장소 원본에 연결되어 있지 않다. 프로필 loader는 정상이고 mux 미등록 원인은 환경·feature 파일의 호스트 불일치였다. 사용자 승인을 받아 로컬 기록을 백업·복구했고 실제 PTY mux 연결, C-Space prefix·어두운 상태바, CLI 분할과 기존 psmux 통합 검사 통과를 확인했다. Windows Terminal 물리 키/IME는 아직 미검증이다.

1. 공식 설정 형식과 원본 연결 제약을 확인하고 ADR을 기록한다.
2. Windows 전용 JSON과 -Plan/-Check·승인·백업·재실행·정책 실패를 다루는 연결 어댑터를 구현한다.
3. Windows 설치는 기본 Windows Terminal, 명시적 WezTerm 선택을 제공한다. 설치 생략·선택 psmux와 기존 사용자 설정을 보존한다.
4. psmux의 호스트/선택/활성화/도구 부재를 구분하는 안내를 제공하여 조용한 미등록을 진단할 수 있게 한다.
5. 임시 대상에서 연결·실패·재실행·원본 갱신 검증, 설정 형식·키 충돌·기존 통합 검사와 OS별 정적 검토를 수행한다.
6. diff·명시적 파일 stage·commit·push·한국어 PR 제출. 실사용 Windows Terminal 연결과 OS 기본 앱 변경은 코드 구현과 분리한다.

완료 조건: 저장소 원본 수정이 연결된 JSON에 반영되고 기존 설정 백업·junction 생성 실패 전 보존·비대상 OS 미실행을 검증한다. 대상이 현재 PC여도 깨끗한 신규 장비 설치 성공으로 주장하지 않는다. GUI/IME 미검증은 draft PR에 명시한다.

## 진행 로그

| 시각 | 이유·수행 | 결과·다음 일 |
| --- | --- | --- |
| 2026-10-07 KST | 최신 main·사용자 변경·열린 PR 확인, Microsoft 공식 schema·로더 확인 | main 73bbe35, 사용자 lockfile 보존. fragment는 프로필/색상만 지원하므로 전체 JSON 연결 검토. 작업 0004/0005 번호는 열린 PR에 예약되어 0006 사용 |

## 검증과 남은 일

### 지정 폰트 후속 범위와 계획

2026-10-07 KST: 사용자가 Nerd Fonts의 `patched-fonts/Meslo/M-DZ/MesloLGMDZNerdFontMono-Regular.ttf`를 지정했다. 기존 JSON의 비-Mono 패밀리와 설치 스크립트의 `*Meslo*Nerd*.ttf` 검사는 해당 변형을 보장하지 못한다. Windows Terminal에 지정된 Mono 패밀리를 사용하고, upstream의 고정 commit·SHA-256·파일명·패밀리를 manifest로 관리한다. 바이너리는 Git에 넣지 않으며 사용자 추가 파일 `MesloLGMDZNerdFont-Regular.ttf`와 lockfile은 보존한다.

계획: 실제 font metadata 확인 → 다운로드·무결성·사용자 범위 등록 어댑터와 bootstrap 연결 → 읽기 전용 Plan/Check 및 임시/모의 검사 → 통합 리뷰·PR. 현재 PC에 다운로드한 폰트를 설치하거나 레지스트리를 변경하지 않는다. macOS/WSL의 기존 폰트 설정은 이 Windows 선택으로 바꾸지 않는다.

구현·검증·리뷰·PR 제출 결과를 같은 기록에 갱신한다. Windows Terminal GUI 물리 키와 IME, 신규 장비 전체 설치, macOS/WSL/Linux 실기기는 미검증이다.

- 2026-10-07 KST: 최초 파일 심볼릭 링크 계획을 검증하니 현재 PC에서 Win32 1314로 실패했다. 실패 시 기존 설정 무변경을 확인했다. 권한/정책 변경을 요구하지 않도록 디렉터리 junction으로 변경하고 runtime 데이터는 source directory .gitignore로 제외한다. 이전 symlink 성공 검사 skip을 완료 근거로 사용하지 않는다.

## 통합 검증 근거

2026-10-07 KST, `windows-powershell`, 미커밋 통합 diff:

- 실제 임시 디렉터리 검사: `tests/windows-terminal.ps1`을 PowerShell 7과 Windows PowerShell 5.1에서 실행하여 junction·백업·재실행·Git 원본 파일 교체·대상 경로의 atomic 파일 교체를 통과했다. 사용자 Terminal 설정은 적용하지 않았다.
- 승인 부재·잘못된 OS·junction 생성 실패에서 기존 대상 보존, 다른 호스트 기록의 명시적 archive, 다른 채널 실제 연결의 archive/기록 부재 우회 차단을 확인했다. 함수만 존재하는 wt/pwsh가 필수 실행 파일로 통과하지 않는다.
- `tests/windows-terminal-setup.ps1` 모의 검사로 기본 Windows Terminal·명시적 WezTerm 패키지/연결 선택과 비대상 도구 제외를 PS7/5.1에서 확인했다.
- `tests/psmux-runtime.ps1`은 PS7/5.1에서 기존 런타임 격리와 새 읽기 전용 진단을 통과했다. Python 단위 검사는 14개 성공, Windows에서 POSIX ACL 1개 제외. 기존 Windows 선택 검사는 통과했다.
- macOS 검토에서 기존 macOS/WSL/Linux 런타임 경로 비변경을 정적으로 확인하고 Windows PowerShell 5.1 폴백 문구를 WezTerm에 한정했다. Windows 및 독립 검토에서 지적한 타 채널 우회와 archive 백업 안내를 수정했고 독립 재검토에서 남은 blocker가 없었다. 역할 검토는 다른 OS 실기기 검증이 아니다.
- `git diff --check` 통과. 실제 Terminal GUI 저장·물리 키·IME·신규 장비 전체 설치와 다른 OS 실기기는 미검증이며 draft PR 대상으로 유지한다. 폰트 후속 구현·검증은 다음 로그에 추가한다.

2026-10-07 KST: 지정 asset의 upstream 마지막 변경 commit `f034eeafc0ccf79afa8dd952feb86b18e5d0469e`에서 다운로드한 파일을 로컬 검증했다. SHA-256은 `66e3a38c5caad569892bd5c241d0ea1fa3e09690521bd9453b77457e1208852a`; TTF name table의 family는 `MesloLGMDZ Nerd Font Mono`, full name은 `MesloLGMDZ Nerd Font Mono Regular`다. JSON의 face를 이 패밀리로 수정했다. 파일은 임시/로컬 다운로드로만 사용하며 설치하지 않았다.

2026-10-07 KST: 폰트 구현 통합 리뷰에서 유효한 사용자 등록이 시스템 등록 충돌 검사를 가리는 경우와 구성요소 진행 기록 누락을 발견했다. 두 scope 등록을 모두 검사하고 현재 호스트의 setup-state 원본을 보존·갱신하도록 계획을 보완했다. 다른 호스트 기록을 폰트 단계에서 자동 archive하지 않는다. 실제 font 등록/API/렌더링 검증은 모의 검사와 구분한다.

2026-10-07 KST: 전체 Windows 설치의 명시적 WezTerm 선택도 같은 Mono asset을 준비하므로, 네이티브 PowerShell 선택에서만 WezTerm fallback 목록 앞에 Mono 패밀리를 추가한다. macOS/WSL/미승인 호스트 목록은 유지한다. 설치와 런타임 폰트 이름 불일치를 피하기 위한 Windows 범위 보완이다.

2026-10-07 KST, Windows PowerShell 5.1/PowerShell 7, 최종 미커밋 diff: `tests/meslo-font.ps1`과 `tests/windows-terminal-setup.ps1` 통과. 폰트 검사는 다운로드·레지스트리·native API를 모의하여 체크섬 실패, 기존 파일/빈 값·양 scope 등록 충돌, file-only 등록 재개, 실패 복구, 호스트별 ready/failed 기록·타 component 보존·재실행 무갱신을 확인했다. 실제 폰트 다운로드본의 hash/name table 검증과 모의 설치 성공을 구분하며, 현재 PC의 폰트·등록·환경·진행 기록을 적용하지 않았다.

WezTerm Lua 문법 검사 통과. 첫 `tests/environment-isolation.lua` 실행은 필수 `DOTFILES_BASELINE` 미지정으로 시작 단계에서 중단했고, 최신 origin/main을 임시 `.local` 사본으로 export하여 재실행하니 macOS/Linux/WSL baseline 비교와 Windows Mono 선택·미승인/다른 host 격리·psmux 시나리오가 모두 통과했다. 다른 OS 실기기 검증이 아닌 Windows의 모의 검사다.

통합 독립 재검토에서 폰트 충돌·진행 기록·rollback·Windows 전용 Mono 선택을 확인하고 남은 blocker가 없었다. 폰트 GUI 선택·실제 native 등록과 새 장비 전체 설치는 계속 미검증이다.
