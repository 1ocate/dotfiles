# 장치 통합 읽기 전용 점검

다른 장치에서 main을 반영하기 전, 실제 사용할 체크아웃에서 실행한다. Python 3.10 이상과 표준 라이브러리만 필요하다. 설치·프로필 실행·외부 도구 실행·명시적 네트워크 요청·선택/진행 기록 갱신을 하지 않는다.

```powershell
py -3 -B scripts/device-status.py
py -3 -B scripts/device-status.py --json
```

```sh
python3 -B scripts/device-status.py
python3 -B scripts/device-status.py --json
```

별도 worktree에서 코드를 검증하되 실제 원본 연결을 점검하려면 `--repo <실제 체크아웃 절대 경로>`를 지정한다. 대상 체크아웃의 스크립트나 프로필을 실행하지 않고 그 경로와 파일만 조사한다. 검사 기준 경로는 `sourceCheckout`에 표시된다. 실행 경로와 실제 설정 원본이 다르면 불일치가 정상적으로 나올 수 있다.

## 판정의 의미

| 상태 | 의미 |
| --- | --- |
| 발견 (`present`) | 실행 파일이 PATH에서 발견됐거나 파일/기록 구조가 존재함. 버전·실행·기능 완료를 의미하지 않음 |
| 참조 발견 (`reference-found`) | 실제 링크 또는 해석 가능한 원본 참조가 있음. 새 셸 동작은 미검증 |
| 누락 (`missing`) | 검사한 경로/PATH에서 찾지 못함. 미설치 확정이나 자동 설치 요청이 아님 |
| 불일치 (`mismatch`) | 다른 원본·다른 장치 기록·중복 초기화 등 수동 확인할 차이가 있음 |
| 확인 필요 (`unknown`) | 안전하게 해석할 수 없는 표현식, 읽기 오류 또는 이 버전의 검사 범위 밖 |
| 선택 안 함 (`not-selected`) | 현재 장치의 유효한 mux 기록이 명시적으로 비활성임 |

JSON의 `summary`는 상태별 개수이며 `checks`의 각 항목에 이유와 `runtimeVerified: false`를 제공한다. 현재 버전의 모든 항목은 정적 인벤토리다. 명령 종료값 0은 인벤토리 출력 성공을 뜻하며 모든 구성요소 정상/적용 완료를 뜻하지 않는다. 2는 환경을 판별하지 못했거나 원본 경로 자체를 점검할 수 없는 오류다. 부분 오류·기록 손상은 항목별 확인 필요로 보고해 다른 검사를 계속한다. 설정 내용·상태 파일 전문·인증 값은 출력하지 않는다. 로컬 경로인 검사 기준 체크아웃은 출력되므로 외부 공유 전 확인한다.

## 현재 검사 범위

- 공통: 기존 environment.py의 공식 플랫폼 판별·환경 선택 읽기·Neovim/WezTerm 링크/알려진 loader 검사, PATH 도구 존재, setup-state의 형식/환경/장치 일치. 누락된 환경 선택은 조사만 허용하며 승인으로 저장하지 않는다.
- Windows: OS Documents API로 실제 리다이렉션 경로를 찾는다. PowerShell 5.1/7의 CurrentUserCurrentHost 프로필만 읽어 aliases/Git/mux/Tab 원본 참조·중복·다른 원본과 OMP 초기화/테마 경로를 조사한다. Tab 참조가 있으면 SSH·fzf·히스토리 의존 파일 존재를 검사한다. pinned posh-git 1.1.0 manifest도 확인한다.
- Windows Terminal: stable/preview/unpackaged를 각각 파일 대상 경로로 비교한다. 정상 junction은 파일 resolve 결과로 확인하며 독립 복사본은 연결로 인정하지 않는다. 어떤 채널이 사용자의 활성 터미널인지는 추정하지 않는다.
- Windows 로컬 기록: aliases는 ADR 0010의 host-free 형식을 허용하고, setup-state와 mux는 현재 장치/환경을 구분한다. 기록상 완료는 실제 동작 완료로 승격하지 않는다. mux 선택 기록이 없으면 설치 요청으로 추정하지 않는다.
- macOS/WSL/Linux: 공통 조사와 해당 환경의 PATH만 검사한다. WSL에서 Windows Documents·Terminal·로컬 진행 파일을 추가로 조사하지 않는다. Linux 실기기 지원/설치 완료를 보증하지 않는다.

공통 경로 탐색은 기존 environment.py의 범위와 같다. Neovim은 `XDG_CONFIG_HOME`·`NVIM_APPNAME`을 반영한다. WezTerm은 `~/.wezterm.lua`와 XDG의 `wezterm/wezterm.lua` 후보만 확인하며 `WEZTERM_CONFIG_FILE`·실행 인자로 지정한 다른 경로나 Lua 실제 실행 결과는 확인하지 않는다. 맞춤 경로를 사용하는 장치의 누락/불일치는 이 한계를 함께 검토한다.

Documents 리다이렉션, PATH, 링크 대상이 네트워크 공유이면 파일 조회 자체가 공유 접근을 유발할 수 있다. 이 도구는 별도 네트워크 API나 SSH·클러스터 요청을 직접 호출하지 않으며, 기존 네트워크 경로에 대한 파일 접근까지 차단하는 도구는 아니다.

## 확인하지 않는 것

프로필 전체를 해석하지 않는다. 복잡한 표현식은 확인 필요이며, 발견된 loader도 앞선 return/조건문·뒤의 재정의·다른 프로필 scope 때문에 실행되지 않을 수 있다. Windows PowerShell BOM 없는 비UTF8 프로필은 임의 인코딩으로 해석하지 않는다. 실제 키맵, 현재 부모 셸의 환경변수, k9s/클러스터 접속, Neovim 플러그인, IME·GUI 동작을 확인하지 않는다. 도구 버전 명령이나 실제 모듈 import도 실행하지 않는다.

AutoHotkey 시작 바로가기 인자/프로세스와 Unix 셸 프로필, mux 실제 실행은 이번 범위 밖으로 명시한다. 이 결과만 보고 설치·연결하거나 로컬 상태를 완료 처리하지 않는다. 다음 단계의 적용 계획/선택 적용/자동 상태 갱신은 별도 구현 대상이다. 판정 후 Codex는 [장치 반영 절차](setup-guardrails.md#main-변경을-현재-장치에-반영하는-절차)를 이어서 수행한다.

## 검증

`py -3 -B -m unittest discover -s tests -p "test_device_status.py" -v`로 가상 장치의 환경·참조·기록 오류·격리·읽기 전용 출력을 확인한다. Unix는 python3를 사용한다. 실제 실행 OS와 모의 환경은 [작업 0016](work/0016-readonly-device-status.md)에 구분해 기록한다.
