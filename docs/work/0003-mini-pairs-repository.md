# 0003: mini.pairs 저장소 이름 변경 경고 수정

- 상태: 리뷰 대기
- 요청·배경: LazyVim이 `echasnovski/mini.pairs`의 이름 변경 경고를 출력한다.
- 시작일: 2026-10-05
- 기준: main `38d1473`, `fix/mini-pairs-repository`
- 실행 환경: macos (Darwin)
- 적용 범위: common의 mini.pairs 저장소 주소. 기존 로컬 미추적 파일의 옵션을 보존하여 추적한다. 다른 사용자 변경, lockfile, 설치·연결은 제외한다.
- 관련 ADR: 새 구조나 정책 선택이 없는 작은 버그 수정으로 새 ADR 불필요.
- 관련 PR: [#9](https://github.com/1ocate/dotfiles/pull/9)

## 분석과 미확인 사항

원본을 참조하는 기존 Neovim 링크를 확인했다. 로컬 사용자 spec만 이전 주소를 사용하며 설치된 LazyVim의 coding spec은 새 주소를 사용한다. 최신 원격 main과 현재 main은 같다. 열린 PR #2는 로컬 설정 기준선 작업이며 이 작업 기록 번호와 중복되지 않는다.

## 계획과 완료 조건

저장소 주소만 변경하고 기존 옵션과 config 호출을 보존한다. 사용자 설정을 실행하지 않는 Neovim에서 Lua 구문과 spec을 검사한다. diff 검토 후 커밋·push·PR을 제출한다.

## 진행 로그

| 시각(시간대 포함) | 이유·수행 내용 | 결과·근거 | 다음 일 |
| --- | --- | --- | --- |
| 2026-10-05 KST | 경고 원인과 로컬 사용자 변경, 최신 main 확인 | 이전 주소가 미추적 mini-pairs spec에 존재 | 주소 수정·격리 검증 |

## 검증 결과

macos에서 미커밋 diff를 대상으로 `nvim --headless -u NONE -i NONE`으로 loadfile과 spec 이름·이벤트·config의 옵션 전달을 검사하여 통과했다. `git diff --check`도 통과했다. 기존 로컬 파일과 비교해 저장소 주소 한 줄만 바뀌었고 lockfile은 변경하지 않았다. Windows·WSL·Linux 실기기 실행과 GUI 재시작은 미검증이며 주소 변경에는 OS 분기가 없다. 키맵·셸·tmux·IME 동작은 변경하지 않는다.

## 남은 일과 종료 근거

검증과 PR 제출 후 사용자 리뷰·병합이 남는다.
