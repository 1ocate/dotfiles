# 공통 환경 선택과 기존 설정 등록

각 호스트의 체크아웃에서 사용할 환경을 선택하고 `.local/environment.json`에 저장한다. 이 기능은 패키지 설치·프로필 변경·설정 연결·프로그램 실행을 하지 않는다. 설치와 실행 설정은 후속 OS별 어댑터가 저장된 선택을 확인한 뒤 처리한다.

환경 ID는 `macos`, `windows-wsl`, `windows-powershell`, `linux`다. 자동 판별은 현재 프로세스의 실행 위치를 알려주며 사용자의 선택을 대신하지 않는다. Windows 네이티브에서 WSL을 선택할 수 있지만 기존 WSL 설정 점검은 WSL 내부에서 실행해야 한다. 회사 정책으로 금지된 환경을 설치하거나 우회하지 않는다.

## 실행

Python 3.10 이상이 필요하다. macOS/Linux/WSL은 `python3`, Windows 네이티브는 `py -3`을 사용한다. 이 도구는 Python 자체를 설치하지 않는다.

```powershell
# 선택 여부와 현재 실행 환경 확인: 파일을 만들지 않음
py -3 scripts/environment.py status

# 기존 설정 연결과 도구 탐지: 실행·다운로드 없이 읽기만 수행
py -3 scripts/environment.py check --environment windows-powershell

# 처음 사용할 환경의 명시적 선택: 로컬 상태만 기록
py -3 scripts/environment.py select --environment windows-powershell

# 이미 세팅된 환경 등록: 읽기 전용 점검 후 로컬 상태만 기록
py -3 scripts/environment.py adopt-existing --environment windows-powershell
```

```sh
python3 scripts/environment.py adopt-existing --environment macos
# Linux 또는 WSL에서는 실행 위치에 맞는 ID를 지정
python3 scripts/environment.py adopt-existing --environment linux
python3 scripts/environment.py adopt-existing --environment windows-wsl
```

`select`와 `adopt-existing`은 `--environment`를 필수로 받는다. 이 명시적 값이 환경 선택·승인이며 값을 추측하거나 기본값으로 저장하지 않는다. 같은 호스트의 같은 선택은 파일을 다시 쓰지 않고 재사용한다. `check`는 저장된 유효한 같은 호스트의 선택을 우선하며, 기록이 없으면 읽기 전용 점검을 위해 현재 실행 환경을 사용한다.

## 기존 설정 등록

`adopt-existing`은 현재 환경에서 Neovim·WezTerm 설정 경로와 실행 파일 유무를 조사한다. symlink/junction 연결은 원본과 실제 대상 경로를 비교하고, 알려진 WezTerm loader는 원본 참조를 확인한다. 독립 복사본·다른 체크아웃 연결·미설치 도구는 결과로 보고한다. 설정 파일 내용이나 인증 정보를 출력하지 않는다.

점검의 누락 항목은 선택값 기록을 막지 않는다. **환경 등록 완료와 프로그램 세팅 완료는 구분한다.** 등록은 기존 설정을 교체하거나 설치 완료를 보증하지 않는다. 기존 체크아웃과 다른 worktree에서 점검하면 원본 불일치가 표시될 수 있으므로 실제 사용할 원본의 도구로 등록한다. WSL에서는 게스트 경로만 조사하며 Windows 홈·레지스트리·시작프로그램을 읽거나 변경하지 않는다.

## 저장과 검증

상태 파일의 형식은 다음과 같다. 이 예시는 문서이며 다른 호스트로 복사할 승인 파일이 아니다.

```json
{
  "schemaVersion": 1,
  "environment": "linux",
  "host": "example-host",
  "approved": true,
  "approvedAt": "2026-10-03T00:00:00+00:00",
  "approvalSource": "explicit --environment",
  "registrationMode": "adopt-existing"
}
```

`.local/`은 Git에서 제외한다. 호스트 이름은 대소문자를 구분하지 않으며, 같은 이름의 다른 호스트까지 구별하는 보안 신원 확인 수단은 아니다. 파일이나 `.local` 디렉터리를 다른 호스트로 복제하지 않는다. 기존 Windows PR의 unversioned 선택 기록도 읽을 수 있지만 자동으로 내용을 변경하지 않는다.

다른 호스트 또는 다른 환경의 기존 기록은 자동 승인으로 사용하지 않는다. 사용자가 명시적으로 다시 `select`할 때 기존 파일을 백업하고 원자적으로 교체한다. 손상된 기록은 기본적으로 중단하며, 확인 후 `--replace-invalid`를 지정하면 기존 바이트를 백업하고 새 선택을 기록한다. 기존 프로그램 설정은 이 경우에도 변경하지 않는다.

OS별 설치는 `scripts/environment.py require --environment <ID>`로 같은 호스트의 해당 선택을 요구할 수 있다. Python의 `read_selection`/`require_selection`과 읽기 전용 `environment.lua`의 `selection(repo, decode, host)`가 같은 상태 형식을 사용한다. Lua reader는 선택값만 반환하며 실제 프로세스와 선택 환경의 일치 검사는 사용하는 어댑터가 수행한다. 이 PR에서는 Neovim·WezTerm 설정을 reader에 연결하지 않는다.

## 검증 범위

Python 검사는 네 환경의 판별·선택 저장·기존 설정 보존·재실행·호스트 불일치·WSL 점검 범위·손상된 기록의 명시적 복구를 모의한다. Lua 검사는 네 ID, 승인·호스트·스키마·손상 상태를 확인한다.

```powershell
py -3 -B -m unittest discover -s tests -v
nvim --headless -u NONE -i NONE -l tests/environment-state.lua
```

Windows에서 실제 실행한 `status`/`check`는 읽기 전용으로 확인했다. macOS/Linux/WSL 실기기, 다른 이름을 사용하는 Windows 호스트, Windows ACL은 미검증이다. 등록 테스트는 임시 디렉터리에서 수행하며 실사용 호스트의 선택이나 프로그램 설정을 변경하지 않는다.
