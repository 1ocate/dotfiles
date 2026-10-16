# 0007: PowerShell 7 프롬프트 streaming 적용

- 상태: 리뷰 대기
- 요청·배경: 빈 Enter마다 프롬프트 생성이 느리며 사용자가 임시 streaming 개선을 체감한 뒤 현재 PowerShell 7 테마를 유지한 영구 적용을 요청했다.
- 시작일: 2026-10-16
- 기준: main/origin-main 8aef321, fix/powershell-prompt-streaming
- 실행 환경: windows-powershell
- 적용 범위: Windows PowerShell 7용 테마 원본, 현재 호스트 PowerShell 7 프로필의 해당 원본 참조, 사용 안내. 5.1 프로필·설치 기본값·macOS/WSL/Linux 변경 제외.
- 관련 ADR: [ADR 0002](../adr/0002-native-windows-adapters.md)의 원본 참조 방식을 따르는 작은 성능 개선이며 새 구조 결정은 없다.
- 관련 PR: [Draft PR #17](https://github.com/1ocate/dotfiles/pull/17)

## 분석과 미확인 사항

PowerShell 7 프로필은 테마를 명시하지 않는다. 실행 부모의 POSH_CONFIG를 물려받을 수 있어 테스트 테마가 현재 테마와 동일하다고 단정할 수 없다. 부모 변수와 사용자·시스템 변수를 구분하고 명시적 테마 없는 PowerShell 7의 해석 결과를 config export로 보존한다. 현재 oh-my-posh 31.8.0에서 내보낸 시각·Git·언어별 세그먼트를 그대로 두고 streaming 정수 100만 추가한다.

앞선 로컬 비교에서 기존 테스트 테마는 저장소 중앙값 324ms, streaming 118ms였고 임시 저장소의 브랜치·untracked·종료 코드 보존 검사를 통과했다. 이는 이전 실행 결과이며 이번 실제 적용 테마의 재측정과 구분한다. streaming은 베타이며 GUI 재표시·한글·psmux/Neovim 왕복은 미검증이다.

## 계획과 완료 조건

1. 내보낸 테마와 streaming 원본 사이의 유일한 의미 차이가 streaming=100인지 검증한다.
2. 별도 프로세스로 실제 테마 반복 측정과 새 렌더 cycle/daemon, Git completion/mux/t 등록을 확인한다.
3. 유효한 호스트 승인을 검사하고 현재 PowerShell 7 프로필만 백업 후 저장소 원본을 참조하도록 연결한다.
4. 새 pwsh에서 원본 경로·streaming·daemon·프롬프트 생성 확인, 로컬 상태 갱신, diff 검토 후 PR 제출.

## 진행 로그

| 시각(시간대 포함) | 이유·수행 내용 | 결과·근거 | 다음 일 |
| --- | --- | --- | --- |
| 2026-10-16 09:06 +09:00 | 현재 프로필·부모 환경·승인과 최신 main, 열린 PR 확인 | 기존 사용자 diff 보존; 테마 미지정 및 사용자/시스템 POSH_CONFIG 없음 확인 | 원본과 반복 검사 |

## 검증 결과

Windows 실제 실행 검사(현재 브랜치 미커밋 diff):

- 내보낸 원본과 대상 JSON에서 streaming 키를 제거하고 정규화 비교: 동일. 테마 색상·템플릿·세그먼트 보존.
- 새 PowerShell 7.6.6 프로세스, 저장소 폴더, 후보별 새 프롬프트 14회 중 초기 2회 제외: 기존 중앙값 240.87ms/최댓값 261.10ms, 적용 후보 중앙값 119.63ms/최댓값 133.87ms. 약 50% 감소. 이전 테스트 테마의 324ms와 직접 혼용하지 않는다.
- streaming 14개 새 render cycle 및 지속 daemon 확인. 실제 Enter/PSReadLine/GUI 전체 지연과는 구분한다.
- 임시 Git 저장소에서 브랜치 변경, untracked 표시, LASTEXITCODE 17 보존 통과.
- 승인된 windows-powershell 호스트에서 현재 PowerShell 7 프로필을 백업하고 저장소 테마 참조로 초기화 줄만 교체. Windows PowerShell 5.1 프로필 미변경.
- 새 pwsh 프로필에서 명시한 config 경로, Streaming=True, ServeAlive=True, 프롬프트 생성, posh-git 로딩, mux/t alias 확인.
- 로컬 백업/상태/상세 결과는 .local에만 보존. 공개 기록에는 호스트·개인 절대 경로 미포함.
- macOS/WSL/Linux와 물리 GUI/IME·psmux/Neovim 왕복은 미검증. 기존 psmux pane은 셸이 재시작되기 전에는 새 프로필을 읽지 않는다.

## 남은 일과 종료 근거

GUI 화면/IME 및 psmux 재표시는 별도 확인 필요. PR 제출을 적용·병합 또는 다른 OS 검증 완료로 간주하지 않는다.

## 최종 검토와 제출

- 독립 검토 기준 8aef321..cfc7db9: JSON 의미 비교로 streaming만 변경됨을 재확인하고 최종 문서·범위 정적 검토에서 수정 필요 사항 없음.
- Draft PR #17 제출. 물리 GUI/IME·psmux/Neovim 왕복 확인과 PR 리뷰·병합은 남아 있다.
