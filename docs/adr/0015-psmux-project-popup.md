# 0015: psmux 프로젝트 선택을 프로필 없는 popup으로 실행

- 상태: 제안
- 작성일: 2026-11-03
- 적용 범위: windows-powershell
- 관련 작업: [작업 0005](../work/0005-psmux-ssh-escape.md)
- 채택 근거: 사용자가 prefix+F의 fzf 표시 지연 개선과 `mux` 유지 필요성 재검토를 요청했다. PR 리뷰 대기다.
- 대체 관계: ADR 0006의 F/D 직접 PowerShell 실행과 `mux`의 F/D/reload 런타임 등록을 대체한다.

## 배경과 문제

F/D는 새 창에서 사용자 프로필을 읽는 PowerShell로 `t`를 실행했다. 측정 시 프로필 로드가 약 1.9~2.4초로 fzf 표시 지연의 대부분이었고(프로필 없는 pwsh 약 0.3초, 폴더 열거·fzf 시작 수십 ms) 취소나 선택 후에도 창이 남았다.
bare `pwsh`의 profile wrapper를 피하려고 `mux`가 절대 경로 바인딩을 접속 후 등록했지만 3.4.0의 CLI 따옴표 처리 변경으로 깨졌고, 대안인 부분 conf `source-file`은 설정의 다른 바인딩을 초기화했다.

## 검토한 대안

- 프로필 PowerShell 새 창 유지: 지연이 그대로이고 창이 남는다.
- 버전별 CLI 인수 따옴표 분기: 3.4.0 CLI는 `\;`에서 연쇄를 끊어 reload 재등록이 불가능하다.
- psmux `display-popup`: popup 명령은 `pwsh -NoProfile -Command`로 실행되고 서버 전역 환경(`DOTFILES_ROOT`, `PSMUX_DATA_DIR`)을 받으므로 절대 경로 없이 원본 설정에 둘 수 있다. 선택한다.

## 결정과 이유

F/D는 원본 `tmux/psmux.conf`의 `display-popup`으로 `scripts/psmux-project-popup.ps1`을 실행하고, 저장소 runtime의 `Invoke-DotfilesProject`를 사용한다. 사용자 프로필과 사용자 정의 `t`는 읽지 않는다.
popup에는 `TMUX`가 없고 psmux는 세션마다 서버를 두므로, 전환은 popup을 연 세션(`PSMUX_SESSION`)의 port로 `switch-client`를 보낸다.
`r`도 원본 설정에 두고 `source-file -F '#{@dotfiles_config}'`로 읽는다. `mux`는 바인딩을 바꾸지 않고 이 사용자 옵션에 원본 설정 경로만 기록한다.

## 영향과 재검토 조건

격리 측정에서 F→fzf 표시가 약 1.96초에서 0.9~1.06초로 줄었다. 남은 비용은 popup의 pwsh 시작과 runtime 로드(약 0.4초)이며 fzf 이후로 미룰 수 있다.
`mux`를 거치지 않고 만든 세션에서는 `r`이 동작하지 않는다. popup port 파일 구조는 psmux 내부 형식이므로 psmux 업그레이드 시 F 전환 검사로 재확인한다. macOS·WSL·Linux tmux 설정은 바꾸지 않는다.
