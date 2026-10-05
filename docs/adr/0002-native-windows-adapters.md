# 0002: 공통 원본에 Windows 네이티브 어댑터 연결

- 상태: 제안
- 작성일: 2026-10-03
- 기록 유형: 기존 구현의 사후 정리와 PR #7의 기술 결정 제안
- 적용 범위: common의 원본 구조, windows-powershell 설치·셸·클립보드·IME, Windows 호스트의 명시적 windows-wsl 선택
- 관련 작업: [작업 0002](../work/0002-windows-native-setup.md)
- 관련 PR: [PR #7](https://github.com/1ocate/dotfiles/pull/7)
- 채택 근거: PR #7 리뷰·병합 대기. 구현되어 있다는 사실만으로 채택 처리하지 않음
- 대체 관계: 없음. [ADR 0001](0001-decision-and-work-records.md)의 기록 기준을 적용

## 배경과 문제

회사 Windows에서는 WSL을 사용할 수 없고 macOS에서는 기존 LazyVim·셸·tmux 흐름을 유지해야 한다. 기존 설정은 HOME 문자열, 고정 WSL 도메인·경로, Unix 셸과 클립보드를 가정한다. 파일 전체를 OS별로 나누면 같은 키맵·테마·편집 옵션을 여러 곳에서 유지해야 한다.

PR #7의 구현·리뷰와 [기존 환경 평가](../environment-direction.md)를 근거로 결정 이유를 사후 정리한다. 아래 대안 비교는 현재 정리 시점의 평가이며, 원래 구현 전에 모든 대안을 검토했다고 주장하지 않는다. 과거 변경·검증의 출처와 한계는 작업 0002에 모은다.

## 대안과 선택 이유

| 대안 | 평가 |
| --- | --- |
| Windows에서도 WSL·Unix 설치를 전제 | 회사 정책과 맞지 않고 기존 삭제 방식의 설치를 재사용하기 어려움 |
| Neovim·WezTerm 설정 전체를 OS별 복제 | Windows 변경은 쉽지만 공통 키맵·테마와 버전 유지가 분산됨 |
| 공통 원본과 작은 OS 분기, 별도 Windows 설치 어댑터 | 현재 작업 경험을 공유하면서 플랫폼 차이·적용 권한을 제한할 수 있어 선택 |
| 설정을 호스트에 독립 복사하거나 자동 양방향 동기화 | 실사용 변경의 Git 원본이 불분명해져 연결 방식보다 관리 비용이 큼 |

## 결정

| 영역 | 방식과 이유 | 구현 원본 |
| --- | --- | --- |
| 원본·연결 | `nvim/`·`.wezterm.lua`를 단일 원본으로 유지. Windows는 junction·loader로 참조해 일반 symlink 권한 의존을 줄임. 기존 설정은 백업하고 중첩 경로는 거부 | [Neovim 연결](../../scripts/use-neovim.ps1), [WezTerm 연결](../../scripts/use-wezterm.ps1) |
| 환경 선택 | 플랫폼 탐지와 사용 환경 승인을 분리. 상태 형식·쓰기는 공통 Python 도구에 맡기고 Lua는 읽기 전용으로 사용하여 승인 로직 중복을 줄임 | [Windows 어댑터](../../scripts/windows-environment.ps1), [공통 등록](../environment-registration.md) |
| Windows 런타임 | 현재 호스트의 승인된 PowerShell 선택에서만 PowerShell 셸·Windows yank를 적용. 선택 누락·손상·불일치에서는 안내하고 해당 분기를 강제하지 않음. Unix는 Windows 선택 파일을 읽지 않음 | [Neovim 초기화](../../nvim/init.lua), [옵션](../../nvim/lua/config/options.lua), [yank](../../nvim/lua/plugins/yankclip.lua), [WezTerm](../../.wezterm.lua) |
| 셸·입력 | PowerShell 7 우선, 없으면 5.1 폴백. 설치 사전 점검은 7을 요구. AutoHotkey v2가 Windows 키 교환·복사·붙여넣기를 담당하고 Esc 영문 전환은 WezTerm에 제한하여 다른 앱의 Esc를 보존 | [AutoHotkey](../../autoHotKey.ahk), [Windows 사용 지침](../windows-setup.md) |
| WSL 유지 | 회사 환경의 전제로 삼지 않음. 다른 호스트가 명시적으로 WSL을 선택하면 발견한 첫 도메인과 기존 fish 로그인 셸 사용. 배포판·사용자 홈을 고정하지 않음 | [WezTerm](../../.wezterm.lua) |
| 의존성·잠금 | Windows winget 설치와 parser·Mason 준비를 분리. 설치 중 lockfile 바이트를 복구하여 버전 갱신을 별도 작업으로 유지. Unix 전용 선택 빌드를 Windows에서 생략 | [설치](../../scripts/setup-windows.ps1), [Neovim 도구 준비](../../scripts/setup-neovim.lua), [CopilotChat](../../nvim/lua/plugins/CopilotChat.lua) |

환경 선택의 승인·재사용 규칙은 [설정 가드레일](../setup-guardrails.md), 명령과 선택 옵션은 Windows 사용 지침이 원본이다. ADR에는 선택 이유를 남기고 실행 절차를 복제하지 않는다.

## 영향과 한계

macOS·Unix 옵션과 키맵을 유지하지만 실기기 회귀 검증을 대신하지 않는다. WSL 도메인은 발견 순서에 의존하며 fish가 설치되어 있어야 한다. 특정 배포판 지정과 tmux·프로젝트 전환의 Windows 대체는 이 결정에 포함하지 않는다. 기존 Ctrl+V의 Neovim Visual Block 충돌도 남아 있다.

Copilot·CopilotChat은 최신 main의 비활성화 상태를 유지한다. Windows 빌드 생략은 향후 활성화 시의 의존성 차이만 다루며 서비스 사용을 승인하지 않는다. 필수·선택 도구의 현재 목록은 사용 지침과 스크립트에서 확인한다.

설치는 패키지·프로필·실행 정책·설정 연결을 변경할 수 있다. 선택 등록과 설치 완료는 다르고 자동 전체 롤백은 없다. PowerShell 프로필의 저장소 원본화, setup-state 자동 기록, macOS 설치 통합은 후속 범위다. 설치·GUI·OS별 검증 근거와 남은 일은 작업 0002에서 관리한다.

신규 장비의 성공을 기존 설치 장비의 점검 결과에서 추정하지 않는다. [신규 설치 재현성 기준](../setup-guardrails.md#신규-장비-설치와-재현성-검증)에 따라 최소 사전 준비에서 전체 설치·최초 시작·재실행과 합의한 기본 기능을 확인해야 대상 범위의 재현성을 주장할 수 있다. 기준을 문서화한 것만으로 설치 검증을 완료 처리하지 않는다.

## 재검토 조건

회사에서 허용하는 도구가 달라지거나 새 장비 전체 설치 검증에서 문제가 발견되면 의존성·설치 경계를 재검토한다. WSL 도메인 선택, 키 담당 계층, 공통 설치 진입점 또는 프로필 연결 구조를 바꾸는 작업은 새 ADR 또는 이 ADR을 대체하는 결정으로 기록한다.

AutoHotkey 로그인 등록은 사용자가 선택한다. 대화형 세팅은 기본 아니오로 질문하고, 비대화형 실행에서는 명시 등록 옵션만 허용한다. 현재 실행과 로그인 등록을 분리하여 세팅 승인만으로 지속 실행을 자동 적용하지 않는다.
