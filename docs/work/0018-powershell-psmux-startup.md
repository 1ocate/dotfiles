# 0018: PowerShell·psmux 시작 시간과 전경 프로그램 인식

- 상태: 진행 중
- 요청·배경: psmux 3.4.0 적용 후 사용자가 세 가지를 보고했다.
  - 상태줄·창 이름이 `oh-my-posh`로 표시된다.
  - 세션을 켤 때 바로 뜨지 않고 느리다.
  - mux 안에서 프로젝트 새 세션을 만들면 이전 세션의 디렉터리에서 시작한다.
- 시작일: 2026-11-03
- 기준: main 3dee166, `perf/powershell-startup`. psmux 표시·runtime 변경은 열린 PR #30(`fix/psmux-search-escape`)에 추가한다.
- 실행 환경: windows-powershell
- 적용 범위·비대상:
  - 대상: `powershell/git-completion.ps1`, `powershell/history-fzf.ps1`, `powershell/ssh-fzf.ps1`, `tests/git-completion.ps1`, 사용 문서.
  - 비대상: Oh My Posh 초기화·streaming 설정, 사용자 프로필 loader, macOS·WSL.
- 관련 ADR: 새 결정 없음. 같은 기능의 로드 시점과 psmux 표시 방식만 바꾸며 [ADR 0002](../adr/0002-native-windows-adapters.md)의 Windows 어댑터 범위 안이다.
- 관련 PR: [PR #33](https://github.com/1ocate/dotfiles/pull/33)(이 작업), [PR #30](https://github.com/1ocate/dotfiles/pull/30)(상태줄 표시·`psmux.ps1` 로드 단축)

## 분석과 미확인 사항

### 창 이름 `oh-my-posh`

oh-my-posh 31의 streaming은 pwsh마다 `oh-my-posh serve` 자식 프로세스를 상주시킨다.

psmux는 OSC 133 표식이 없으면 pane 셸의 자식 중 PID가 가장 큰 것을 `pane_current_command`로 고른다(3.3.8 소스 `platform.rs`의 `deepest_descendant`). Windows PID는 생성 순서가 아니어서 결과가 사실상 무작위다.

- 격리 3.4.0 서버, 실제 프로필 pane: 대기 중에는 `oh-my-posh`로 보고됐다.
- `1..5 | fzf` 실행 중: 4회 중 2회만 `fzf`로 인식됐다. 나머지는 `oh-my-posh`였고, 이때 Ctrl+J/K가 목록 대신 pane 이동으로 처리될 수 있다.
- 저장소 Neovim 설정은 OSC 133 C 표식을 보내므로(`nvim/lua/config/psmux.lua`) 영향이 없다.
- `nvim -u NONE` 같은 표식 없는 실행은 영향을 받는다.

### 시작 지연

pwsh 시작은 프로필 없이 0.23초, 프로필 포함 1.77초였다. 부분별 측정:

| 부분 | 시간 |
| --- | --- |
| posh-git import(첫 cmdlet 비용 약 170ms 포함) | 약 640ms |
| oh-my-posh init(`--print` 실행 260ms + 스크립트 실행 380ms) | 약 560ms |
| `psmux.ps1` | 약 180ms |
| 첫 프롬프트 | 약 230ms |
| `mux` 명령 자체(`has-session`~`set-option`) | 약 230ms |

- `psmux.ps1`의 180ms 중 약 110ms는 사용자 명령 보존 확인에서 `Get-Command mux`/`t`를 찾지 못할 때 드는 탐색 비용이다.
- `ConvertFrom-Json`은 첫 cmdlet 비용을 빼면 23ms라 교체 효과가 없어 제외했다.

### 새 세션 디렉터리

다음 경우 모두 선택한 디렉터리에서 시작했다.

- pane 안에서 실행한 `new-session -c`
- popup 안에서 실행한 `new-session -c`
- 실제 F popup 스크립트(`-Path`)

재현 경로를 사용자에게 확인한다.

## 계획과 완료 조건

1. posh-git을 첫 git Tab에서 읽는다. 완성 결과와 프롬프트 보존을 기존 테스트로 확인한다.
2. 저장소의 Ctrl+R·SSH fzf 래퍼가 psmux pane 안에서만 OSC 133 C/D 표식을 보낸다. 격리 서버에서 fzf 인식이 4/4인지 확인한다.
3. PR #30에서 다음을 바꾼다.
   - 상태줄·자동 창 이름이 `oh-my-posh`를 `pwsh`로 표시한다.
   - `psmux.ps1`의 명령 존재 확인을 함수·별칭·PATH 직접 검사로 바꾼다.
4. 새 세션 디렉터리 문제는 사용자 재현 경로를 받은 뒤 처리한다.

## 다른 장치 적용 명세

| 항목 | 내용 |
| --- | --- |
| 구성요소·대상 환경 | PowerShell Git 완성, Ctrl+R·SSH fzf 선택기. windows-powershell, 선택 기능. macOS·WSL·Linux는 비대상 |
| 변경 원본·선행 조건 | 위 대상 파일. 기존 posh-git 1.1.0과 `tab-completion.ps1` loader가 연결된 장치. 이전에는 셸 시작 때 posh-git을 import했다 |
| 변경 종류 | 원본 갱신만. 새 설치·연결 없음 |
| 사전 확인·적용 | main 갱신 후 새 PowerShell 탭을 연다. 프로필 loader는 그대로다 |
| 검증·완료 판정 | 새 탭에서 `Get-Module posh-git`이 비어 있어야 한다. `git checkout <Tab>` 뒤 브랜치가 완성되고 모듈이 로드돼야 한다. psmux pane에서 Ctrl+R을 열고 Ctrl+J/K가 목록을 이동하는지 확인한다. 물리 키 확인이 필요하다 |
| 복구·로컬 기록 | 이전 커밋의 세 파일로 되돌린다. 결과는 해당 장치 `.local/setup-state.json`에 기록한다 |

## 진행 로그

| 시각(시간대 포함) | 이유·수행 내용 | 결과·근거 | 다음 일 |
| --- | --- | --- | --- |
| 2026-11-03 15:40 KST | 사용자 보고 세 가지 분석 | 위 분석. 실사용 세션 `main`·`WORK-…`은 변경하지 않음(격리 데이터 경로만 사용, 전후 목록 동일) | 구현 |
| 2026-11-03 16:10 KST | posh-git 지연 로드, fzf 표식 구현 | 아래 검증. JSON 교체는 측정 후 되돌림 | PR #30 표시·runtime 변경, 디렉터리 재현 경로 확인 |

## 검증 결과

| 대상 커밋 또는 diff | 환경·검사 종류 | 명령·시나리오 | 결과·한계 |
| --- | --- | --- | --- |
| 미커밋 diff(main 3dee166 기준) | windows-powershell, 실제 실행 | `pwsh -NoProfile -File tests/git-completion.ps1 -LoadSource` | 시작 시 posh-git 미로드, `git checkout/switch feat/` 완성, 첫 Tab 뒤 모듈 로드, 프롬프트 보존 통과 |
| 같은 diff | windows-powershell 5.1 | 소스 dot-source 후 `TabExpansion2 'git checkout feat/'` | 시작 시 미로드, 완성 15개, 이후 모듈 로드 |
| 같은 diff | windows-powershell, 실제 실행 | `tests/ssh-fzf.ps1`, `tests/history-fzf.ps1`, `tests/ssh-completion.ps1` | 모두 통과(psmux 밖이라 표식 없음) |
| 같은 diff | windows-powershell, 격리 psmux 3.4.0 + 실제 프로필 | 새 세션 4회, 변경한 `history-fzf.ps1` dot-source 후 Ctrl+R | 4/4 fzf 화면 표시·`pane_current_command=fzf`, Esc 뒤 원래 값으로 복귀 |
| 같은 diff | windows-powershell, 측정 | 실제 프로필 구성 순서로 각 부분 측정 | 합계 1.65초 → 1.31~1.36초. oh-my-posh init(약 0.56초)과 첫 프롬프트는 그대로 |

미검증: 물리 키 입력, Windows Terminal·WezTerm GUI, macOS·WSL.

## 남은 일

- PR #30에 상태줄 표시와 `psmux.ps1` 명령 확인 단축을 추가한다.
- 새 세션 디렉터리 문제의 재현 경로를 사용자에게 확인한다.
- oh-my-posh init 캐시는 프로필 loader와 oh-my-posh 버전 갱신 경계를 바꾸므로 별도로 검토한다.
