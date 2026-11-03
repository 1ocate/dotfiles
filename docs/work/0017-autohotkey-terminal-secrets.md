# 0017: 터미널 비밀번호·OTP AutoHotkey 단축키

- 상태: 리뷰 대기
- 요청·배경: 사용자가 터미널에 붙여 넣을 비밀번호 단축키와 OTP 등록을 AutoHotkey로 할 수 있는지 확인을 요청했다. 저장소에 해당 기능이 없음을 확인한 뒤 충돌하지 않는 단축키로 구현하도록 요청했다.
- 시작일: 2026-11-03
- 기준: main c6b271a, feat/ahk-credential-hotkeys
- 실행 환경: windows-powershell
- 적용 범위·비대상: `autoHotKey.ahk`, 새 `autohotkey/credentials.ahk`, `tests/autohotkey-credentials.ahk`, `scripts/setup-windows.ps1`의 필수 원본 목록, 사용 문서. 비대상: macOS Hammerspoon, 실제 AutoHotkey 재시작·비밀 값 등록, 여러 계정·HOTP
- 관련 ADR: [ADR 0014](../adr/0014-autohotkey-terminal-secrets.md)
- 관련 PR: [PR #28](https://github.com/1ocate/dotfiles/pull/28)(병합), [PR #29](https://github.com/1ocate/dotfiles/pull/29)(병합, OTP 슬롯), [PR #31](https://github.com/1ocate/dotfiles/pull/31)(비밀번호 Enter)

## 분석과 미확인 사항

- 기존 `autoHotKey.ahk`는 Alt/Win 교환, 터미널 Esc 영문 전환, Alt+Space 한영, Alt+C/V만 제공한다. 저장소·`.local/` 사본·문서에 비밀번호·OTP 관련 코드는 없었다.
- 단축키 점검: `.wezterm.lua`(Ctrl+V/Q, Ctrl+H/L), `windows-terminal/settings.json`(Esc, Ctrl+V, Ctrl+Space), `tmux/psmux.conf`(prefix C-Space, C-h/j/k/l, M-h, C-BSpace, Escape), PowerShell PSReadLine(Ctrl+R, Tab)에서 Ctrl+Alt 조합은 쓰지 않는다. Neovim 설정에도 `<C-M-…>` 매핑이 없다.
- AutoHotkey v2는 파일을 BOM 없는 UTF-8로 읽지 않으므로 새 파일도 기존 원본처럼 UTF-8 BOM을 사용한다.
- 미확인: 물리 키 입력에서 단축키 동작, WezTerm·Windows Terminal·psmux·SSH 프롬프트로의 실제 전달, 회사 보안 정책의 자격 증명 관리자 사용 허용 여부.

## 계획과 완료 조건

1. 단축키 없는 함수 파일에 자격 증명 관리자 읽기·쓰기·삭제, Base32, HMAC·TOTP, otpauth 해석과 등록 대화상자를 구현한다.
2. 메인 스크립트의 터미널 `#HotIf` 블록에 네 단축키를 추가한다.
3. 단독 테스트로 RFC 벡터와 자격 증명 왕복을 검사하고 `/Validate`로 전체 문법을 확인한다.
4. 사용 문서·ADR·작업 기록을 갱신하고 PR로 제출한다. 실기기 GUI 검증은 사용자 적용 후 확인한다.

## 다른 장치 적용 명세

| 항목 | 내용 |
| --- | --- |
| 구성요소·대상 환경 | AutoHotkey 터미널 비밀 입력. windows-powershell(Windows 호스트 WezTerm·Windows Terminal) 대상, 선택 기능. macOS·linux 비대상, windows-wsl은 미검증 |
| 변경 원본·선행 조건 | `autoHotKey.ahk`, `autohotkey/credentials.ahk`. AutoHotkey v2(2.0.29에서 검사), Windows 10 이상(`BCryptHash`). 이전에는 단축키 없음 |
| 변경 종류 | 원본 갱신만. 새 설치·연결 없음 |
| 사전 확인·적용 | main 갱신 후 실행 중인 저장소 AutoHotkey를 다시 실행(트레이 아이콘 Reload 또는 `AutoHotkey64.exe autoHotKey.ahk`, `#SingleInstance Force`로 교체). 비밀 값은 장치마다 `Ctrl+Alt+Shift+P/O`로 사용자가 직접 등록하며 자동 복제하지 않음 |
| 검증·완료 판정 | 정적: `AutoHotkey64.exe /ErrorStdOut /Validate autoHotKey.ahk` 종료 코드 0, `AutoHotkey64.exe /ErrorStdOut tests\autohotkey-credentials.ahk` 통과. 실기기: 등록 시 표시 코드가 인증 앱과 일치, 터미널 비밀번호 프롬프트에서 `Ctrl+Alt+P/O` 입력 확인. GUI 필요 |
| 복구·로컬 기록 | `cmdkey /delete:dotfiles/autohotkey/password`, `cmdkey /delete:dotfiles/autohotkey/otp`(슬롯 2는 `otp-2`)로 값 삭제, 이전 커밋의 `autoHotKey.ahk`로 되돌림. 적용 결과는 해당 장치 `.local/setup-state.json`에만 기록하고 비밀 값은 기록하지 않음 |

## 진행 로그

| 시각(시간대 포함) | 이유·수행 내용 | 결과·근거 | 다음 일 |
| --- | --- | --- | --- |
| 2026-11-03 10:20 KST | 기능 존재 확인 | 저장소·`.local/` 사본·문서에 비밀번호·OTP 기능 없음 | 사용자 진행 요청 |
| 2026-11-03 10:40 KST | 기존 사용자 변경이 있는 체크아웃을 보존하려고 `.local/worktrees/ahk-credentials`에서 구현 | 함수 파일·테스트 작성. BOM 누락과 `;`·`round` 이름 충돌을 테스트에서 발견해 수정 | 문서·PR |
| 2026-11-03 10:55 KST | 문서·ADR 작성, 검증 | 아래 검증 결과 | 실기기 GUI 확인 |
| 2026-11-03 11:13 KST | 사용자 요청으로 PR #28 병합·현재 장치 반영 | 루트 체크아웃이 psmux 작업 브랜치여서 사용자 선택에 따라 AHK 두 파일만 main 내용으로 작업 트리에 반영(미stage), `/Validate` 후 재실행 | 사용자 GUI 확인 |
| 2026-11-03 11:25 KST | 사용자가 반응이 없다고 보고해 진단 | 실행 중 스크립트에 네 단축키 등록·같은 세션·비관리자 권한 확인. 진단용 가상 Ctrl+Alt+P와 함수 직접 호출이 이미 등록된 비밀번호를 활성 Windows Terminal(Claude Code 입력줄)에 두 번 입력함. 전송(Enter) 없이 사용자에게 지우도록 안내. 활성 창에 실제 값을 보내는 진단은 이후 금지 | 원인: 비밀번호는 이미 등록돼 정상 동작 |
| 2026-11-03 11:40 KST | 사용자가 OTP 두 개 사용을 요청, 선택 메뉴 방식 선택 | `Menu` 방식은 검사 창에서 선택 숫자가 코드와 함께 입력되거나 다른 항목이 선택되는 경우가 있어 ToolTip+InputHook 선택으로 변경. 기존 등록 OTP 대상을 슬롯 1로 유지(v1 형식 그대로 읽음), 슬롯 2 `otp-2` 추가 | 후속 PR·적용 |
| 2026-11-03 15:10 KST | 사용자가 비밀번호 입력 뒤 Enter까지 보내도록 요청 | `feat/ahk-password-enter`(main e71e5c3 기반 worktree)에서 `DotfilesSendPassword`가 값 입력 후 50ms 뒤 Enter를 보내도록 변경. OTP는 Enter 없이 유지. ADR 0014·사용 문서의 Enter 설명과 오입력 위험을 갱신 | PR·사용자 반영 후 GUI 확인 |

## 검증 결과

| 대상 커밋 또는 diff | 환경·검사 종류 | 명령·시나리오 | 결과·한계 |
| --- | --- | --- | --- |
| 미커밋 diff (main c6b271a 기준) | windows-powershell, 실제 실행(단축키 미로드) | `AutoHotkey64.exe /ErrorStdOut tests\autohotkey-credentials.ahk` | 42개 검사 통과: RFC 6238 SHA1/256/512 18개, RFC 4226 10개, Base32·otpauth·저장 형식, 자격 증명 임시 항목 저장·덮어쓰기·조회·삭제. 실행 후 `cmdkey /list`에 남은 항목 없음 |
| 같은 diff | windows-powershell, 정적 | `AutoHotkey64.exe /ErrorStdOut /Validate autoHotKey.ahk` | 종료 코드 0. 오류 파일로 `/Validate`가 문법 오류를 보고함을 별도 확인 |
| 같은 diff | 미검증 | 물리 키·GUI 등록 대화상자·터미널 전달·SSH·psmux | 사용자 적용 후 확인 필요. 실행 중인 사용자 AutoHotkey는 재시작하지 않음 |
| main d0908cd + OTP 슬롯 미커밋 diff | windows-powershell, 실제 실행(단축키 미로드) | 테스트 스크립트, `/Validate` | 48개 검사 통과(v1·v2 형식, 이름의 `;`·`&`, 슬롯 대상), `/Validate` 종료 코드 0 |
| 같은 diff | windows-powershell, 실제 실행(임시 GUI 창, 가짜 비밀키) | 임시 창에서 슬롯 선택 후 키 `2`·`1`·`Numpad2`·`Esc`·`3` 가상 입력 | 2·1·Numpad2는 해당 슬롯 코드만 입력되고 선택 숫자는 창에 전달되지 않음. Esc·3은 취소되어 입력 없음 |
| 같은 diff | windows-powershell, 읽기 전용 | 실제 자격 증명의 슬롯 상태 조회(비밀키 미출력) | 슬롯 1: 기존 등록 OTP(이름 없음, `OTP 1`), 슬롯 2: 미등록 |
| main e71e5c3 + 비밀번호 Enter diff | windows-powershell, 실제 실행(단축키 미로드)·정적 | 테스트 스크립트, `/Validate` | 48개 검사 통과, `/Validate` 종료 코드 0. 실제 비밀번호 Enter 제출은 활성 창 전송 금지 원칙에 따라 에이전트가 실행하지 않음(사용자 GUI 확인 필요) |

## 남은 일과 종료 근거

- 사용자 장치에서 AutoHotkey Reload 후 등록·입력을 GUI로 확인한다. [PR #31](https://github.com/1ocate/dotfiles/pull/31)(비밀번호 Enter) 반영 후 터미널 비밀번호 프롬프트에서 Ctrl+Alt+P 한 번으로 제출되는지 확인한다.
- OTP 슬롯 후속 PR 병합·반영 후 사용자 GUI 확인을 거쳐 상태를 `완료`로 갱신한다.
