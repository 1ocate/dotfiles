# 0014: 터미널 비밀번호·OTP 입력을 AutoHotkey와 Windows 자격 증명 관리자로 처리

- 상태: 제안
- 작성일: 2026-11-03
- 적용 범위: windows-powershell (Windows 호스트의 WezTerm·Windows Terminal 창). windows-wsl은 같은 Windows 호스트 AutoHotkey를 공유하지만 별도 검증 전까지 미검증. macOS·linux 비대상
- 관련 작업·PR: [작업 0017](../work/0017-autohotkey-terminal-secrets.md)
- 채택·기각 근거: 미결정
- 대체 관계: 없음. [ADR 0005](0005-terminal-esc-ime.md)의 AutoHotkey 입력 담당·터미널 창 한정 범위를 따른다.

## 배경과 문제

사용자가 터미널 비밀번호 프롬프트에 붙여 넣을 비밀번호 단축키와 OTP 등록을 AutoHotkey로 처리하도록 요청했다. 비밀 값은 저장소·로그·PR에 남으면 안 되고, 기존 Alt/Win 교환·Alt+Space·Alt+C/V·Esc IME와 psmux·PSReadLine·Neovim 키와 충돌하면 안 된다. AutoHotkey v2에는 TOTP나 비밀 저장 기능이 내장되어 있지 않다.

## 검토한 대안

| 대안 | 장점 | 비용 |
| --- | --- | --- |
| 스크립트·설정 파일에 값 저장 | 단순 | 평문 노출, Git 유입 위험. 기각 |
| DPAPI로 암호화한 `.local/` 파일 | 저장소 밖, 사용자 범위 | 파일 경로·형식 관리와 백업 노출을 직접 처리 |
| Windows 자격 증명 관리자 일반 자격 증명 | OS 기본 기능, 현재 사용자 DPAPI 보호, `cmdkey`로 확인·삭제 | `advapi32` 구조체 호출 구현 필요 |
| 외부 비밀번호 관리자·OTP CLI | 기능 풍부 | 새 의존성과 회사 설치 승인 필요 |
| 셸(PowerShell) 함수로 구현 | 셸 안에서 완결 | SSH 원격·psmux 안쪽 프롬프트에서는 로컬 셸 함수를 쓸 수 없음 |

## 결정과 이유

- 입력 담당은 기존 Windows 입력 원본 `autoHotKey.ahk`로 하고, 로직은 단축키가 없는 `autohotkey/credentials.ahk`로 분리해 단독 테스트가 Alt/Win 교환을 로드하지 않게 한다.
- 비밀 값은 Windows 자격 증명 관리자의 일반 자격 증명에 `CRED_PERSIST_LOCAL_MACHINE`으로 저장한다. 로밍하지 않고 장치마다 등록한다. 새 외부 의존성은 추가하지 않는다.
- TOTP는 Windows CNG(`bcrypt.dll`)의 HMAC으로 RFC 6238을 구현한다.
- 단축키는 WezTerm·Windows Terminal 창에서만 `Ctrl+Alt+P`(비밀번호)·`Ctrl+Alt+O`(OTP), Shift를 더한 조합으로 등록한다. 저장소의 WezTerm·Windows Terminal·psmux·PSReadLine·Neovim 설정이 쓰지 않는 조합이며, 셸·Vim이 흔히 쓰는 단일 Alt·Ctrl 조합을 가리지 않는다. Enter는 보내지 않는다.

## 영향과 재검토 조건

- AutoHotkey는 선택 의존성으로 유지한다. 미실행이면 이 단축키도 동작하지 않을 뿐 다른 설정은 영향이 없다.
- 비밀번호 프롬프트가 아닌 곳에서 누르면 값이 화면·히스토리에 남는다. 프롬프트 감지는 하지 않는다.
- OTP 비밀키를 같은 PC에 두면 2단계 인증의 분리가 약해진다. 회사 정책이 금지하면 사용하지 않는다.
- 여러 계정, HOTP, macOS(Hammerspoon) 대응이 필요해지거나, 회사 정책이 자격 증명 관리자 사용을 제한하거나, 단축키가 다른 도구와 충돌하면 재검토한다.

## 상태 변경·정정

2026-11-03 10:55 KST: 제안으로 작성.
