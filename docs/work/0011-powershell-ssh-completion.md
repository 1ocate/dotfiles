# 0011: PowerShell SSH 호스트 완성

- 상태: 진행 중
- 요청: SSH 인수의 Tab 후보로 로컬 디렉터리 대신 SSH Host 별칭을 제안한다.
- 환경·범위: windows-powershell. 기존 작업 0010의 Tab 메뉴 원본에서 SSH 완성을 로드한다.
- 기준: main 32e4263. 원격 main fetch 후 차이를 확인한다. 기존 사용자 변경은 보존한다.
- 관련 결정: ADR 0002의 원본·loader 방식을 따른다. 새 구조 결정은 없다.
- 계획: 사용자 SSH config의 명시적 Host 별칭만 읽는 native completer 구현 → 가상 config로 실제 완성 API 검사 → diff 검토·PR.
- 제한: 기본 config만 지원하며 Include, 별도 -F config 및 옵션 뒤 대상 완성은 이번 범위에서 제외한다. SSH 접속이나 config 변경은 하지 않는다. macOS·WSL·Linux 설정은 변경하지 않는다.
- 적용: 이미 연결된 작업 0010 원본에서 읽는다. 프로필 자체를 추가 변경하지 않는다.

## 검증과 진행

- 2026-10-20 KST 재개: 사용자가 fzf 세로 목록 적용을 요청했다. 기존 브랜치·staged 변경과 원격 main을 확인했다. 유효한 호스트별 PowerShell 선택과 기존 프로필 연결, 설치된 fzf를 확인했다. 계획은 SSH Host 후보가 있는 Tab만 높이 40% 세로 선택기로 전달하고 나머지는 MenuComplete 유지, Esc 취소 시 입력 보존, fzf 부재·실패 시 기본 메뉴 복귀다. 기존 원본 loader를 유지하므로 새 프로필 변경이나 설치는 필요 없다. 터미널·Neovim·IME 키는 변경하지 않는다. 선택 도구인 기존 fzf의 UI를 이용하는 소규모 확장으로 별도 ADR은 만들지 않는다.

- 2026-10-20 KST: PowerShell 네이티브 환경과 기존 사용자 변경을 확인했다. 프로필 없는 명령만 사용한다. 구현 전에 범위와 검증 계획을 기록했다.

## 검증 이력과 제출

- 2026-10-20 KST: 원격 main과 HEAD 차이 0 확인. PowerShell 7의 `pwsh -NoProfile -File tests/ssh-completion.ps1` 통과: 목록·접두어·user@·ssh.exe·중복/패턴 제외·옵션/원격 명령 제외·빈 config. 개인 config를 출력하거나 테스트에서 읽지 않았다. 실제 프로필의 기존 Tab loader 존재 확인. GUI Tab 입력은 미검증.
- Windows PowerShell 5.1은 실행 정책으로 스크립트 실행이 차단되어 미검증. 정책을 변경하지 않았다. macOS·WSL·Linux 실기기 미검증.
- `py -3 scripts/gh-local.py pr list ...`는 Python 부재(`No installed Python found!`)로 실패했다. PR 제출도 같은 전제에 의존하므로 본문을 `.local/ssh-completion-pr.md`로 준비한다.

- 독립 리뷰에서 `Host =gamma` 처리 누락을 발견해 등호 구문 우선 파싱으로 수정하고 세 가지 등호 표기 fixture를 추가했다. PowerShell 7 검사를 다시 통과했다.

Python 복구 후 PR 제출 및 GUI 확인. 기존 작업 0010의 원본 Tab 설정은 SSH loader 연결에 필요한 관련 파일로 포함하고, 다른 기존 변경은 커밋하지 않는다. PR 본문은 `.local/ssh-completion-pr.md`에 준비했다.

- Git 제출: 관련 5개 파일의 staged diff 검사는 통과했다. 커밋은 로컬 Git 작성자 이름·이메일 부재로 실패했다. 연속 실행된 push는 기준 main과 동일한 작업 브랜치만 만들었으며 구현 변경은 아직 로컬 staged 상태다. 계정 정보를 임의 설정하지 않았다. 커밋·PR 제출은 Git 작성자 설정과 Python 복구가 필요하다.

- 2026-10-20 KST 세로 선택기 검증: PowerShell 7에서 `tests/ssh-completion.ps1` 및 `tests/ssh-fzf.ps1` 통과. 후자는 실제 완성 API의 SSH 후보와 치환 범위, 원격 명령·다른 명령 제외를 검사하고 fzf 모의 실행으로 선택·취소·오류·부재·예상 외 출력 및 환경 옵션 복원을 검사했다. 설치된 fzf 0.74.4로 동일 UI 옵션과 `--filter=beta`를 실행해 가상 후보 beta 반환을 확인했다. 이는 비대화형 검사이며 GUI 목록·물리 Tab/Esc 검증은 아니다. 기존 PowerShell 7 프로필에 원본 loader가 있으므로 새 창에서 새 Tab handler를 읽는다. 로컬 적용 상태는 검증 필요로 기록한다. Git 작성자와 Python 부재는 재확인되어 제출 차단이 유지된다.
- 독립 리뷰에서도 두 PowerShell 7 검사를 재실행해 통과했고 차단 문제는 없었다. `.local/setup-state.json`은 현재 호스트와 불일치해 덮어쓰지 않았다. 이번 현재 호스트의 검증 결과만 별도 `.local/ssh-fzf-validation.json`에 기록한다. 새 설치·프로필 연결은 하지 않았고 호스트 환경 선택 파일은 유효함을 확인했다.

- 2026-10-20 KST 제출 재개: 사용자가 실제 사용이 정상임을 확인하고 PR 제출을 요청했다. 이는 사용자 보고이며 개별 Esc·커서 복원 시나리오를 별도 실측했다고 간주하지 않는다. 최신 origin/main과 기준 커밋 차이는 0이고 동일 브랜치의 열린 PR은 없었다. 권한 범위 밖 실행 파일에 접근 가능한 실행에서 Python 3.13.15와 저장소 전용 GitHub wrapper가 정상 동작했다. 앞선 Python 부재는 제한된 실행 환경의 결과였다. 작성자 전역 설정을 바꾸지 않고 저장소 기존 `.gitconfig`의 작성자를 커밋 한 번에만 사용한다. 작업 목록은 이번 0011 항목만 stage해 기존 0010 변경을 보존한다.

## 남은 일

커밋·push 및 PR 제출 후 사용자 리뷰. 지원 대상 PowerShell 7에서 실제 사용 확인을 받았으며 5.1·다른 OS 및 세부 취소 후 화면 검증 한계는 유지한다.
