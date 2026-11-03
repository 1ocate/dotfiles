# 0017: 터미널 비밀번호·OTP AutoHotkey 단축키

- 상태: 리뷰 대기
- 요청·배경: 사용자가 터미널에 붙여 넣을 비밀번호 단축키와 OTP 등록을 AutoHotkey로 할 수 있는지 확인을 요청했다. 저장소에 해당 기능이 없음을 확인한 뒤 충돌하지 않는 단축키로 구현하도록 요청했다.
- 시작일: 2026-11-03
- 기준: main c6b271a, feat/ahk-credential-hotkeys
- 실행 환경: windows-powershell
- 적용 범위·비대상: `autoHotKey.ahk`, 새 `autohotkey/credentials.ahk`, `tests/autohotkey-credentials.ahk`, `scripts/setup-windows.ps1`의 필수 원본 목록, 사용 문서. 비대상: macOS Hammerspoon, 실제 AutoHotkey 재시작·비밀 값 등록, 여러 계정·HOTP
- 관련 ADR: [ADR 0014](../adr/0014-autohotkey-terminal-secrets.md)
- 관련 PR: [draft PR #28](https://github.com/1ocate/dotfiles/pull/28)

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
| 복구·로컬 기록 | `cmdkey /delete:dotfiles/autohotkey/password`, `cmdkey /delete:dotfiles/autohotkey/otp`로 값 삭제, 이전 커밋의 `autoHotKey.ahk`로 되돌림. 적용 결과는 해당 장치 `.local/setup-state.json`에만 기록하고 비밀 값은 기록하지 않음 |

## 진행 로그

| 시각(시간대 포함) | 이유·수행 내용 | 결과·근거 | 다음 일 |
| --- | --- | --- | --- |
| 2026-11-03 10:20 KST | 기능 존재 확인 | 저장소·`.local/` 사본·문서에 비밀번호·OTP 기능 없음 | 사용자 진행 요청 |
| 2026-11-03 10:40 KST | 기존 사용자 변경이 있는 체크아웃을 보존하려고 `.local/worktrees/ahk-credentials`에서 구현 | 함수 파일·테스트 작성. BOM 누락과 `;`·`round` 이름 충돌을 테스트에서 발견해 수정 | 문서·PR |
| 2026-11-03 10:55 KST | 문서·ADR 작성, 검증 | 아래 검증 결과 | 실기기 GUI 확인 |

## 검증 결과

| 대상 커밋 또는 diff | 환경·검사 종류 | 명령·시나리오 | 결과·한계 |
| --- | --- | --- | --- |
| 미커밋 diff (main c6b271a 기준) | windows-powershell, 실제 실행(단축키 미로드) | `AutoHotkey64.exe /ErrorStdOut tests\autohotkey-credentials.ahk` | 42개 검사 통과: RFC 6238 SHA1/256/512 18개, RFC 4226 10개, Base32·otpauth·저장 형식, 자격 증명 임시 항목 저장·덮어쓰기·조회·삭제. 실행 후 `cmdkey /list`에 남은 항목 없음 |
| 같은 diff | windows-powershell, 정적 | `AutoHotkey64.exe /ErrorStdOut /Validate autoHotKey.ahk` | 종료 코드 0. 오류 파일로 `/Validate`가 문법 오류를 보고함을 별도 확인 |
| 같은 diff | 미검증 | 물리 키·GUI 등록 대화상자·터미널 전달·SSH·psmux | 사용자 적용 후 확인 필요. 실행 중인 사용자 AutoHotkey는 재시작하지 않음 |

## 남은 일과 종료 근거

- 사용자 장치에서 AutoHotkey Reload 후 등록·입력을 GUI로 확인한다.
- PR 병합 후 상태를 `완료`로 갱신한다.
