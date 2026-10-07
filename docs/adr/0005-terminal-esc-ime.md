# 0005: Windows Terminal의 Esc 영어 전환을 기존 AutoHotkey로 처리

- 상태: 제안
- 작성일: 2026-10-07
- 범위: windows-powershell
- 관련 작업: [작업 0006](../work/0006-windows-terminal.md)
- 선행 결정: [ADR 0004](0004-windows-terminal.md)의 WezTerm 전용 Esc 범위를 변경하는 후속 결정. 나머지 터미널 선택·설정 연결 결정은 유지한다.
- 요청 근거: 사용자가 Windows Terminal에서도 Esc 영어 전환을 실제 적용하도록 명시적으로 요청했다. 로컬 적용 승인과 PR 병합·GUI 검증은 구분한다.

Windows Terminal에는 공식 키 액션으로 IME를 영어로 설정하는 기능이 없다. 셸이나 Neovim에 넣으면 SSH·다른 프로그램에서 동작이 달라지므로 기존 Windows 입력 담당 원본 `autoHotKey.ahk`를 재사용한다. 새 입력 도구나 터미널 JSON의 Esc 전송 바인딩은 추가하지 않는다.

활성 창이 `wezterm-gui.exe` 또는 `WindowsTerminal.exe`일 때만 기존 `~Esc Up`으로 원래 입력을 통과시키고 IME를 영어 상태로 설정한다. 한영 토글을 보내지 않아 이미 영어면 그대로 유지한다. Windows Terminal의 SSH를 포함한 모든 탭에 로컬 IME 전환이 적용되며 원격 IME를 바꾸거나 원격 Vim의 Esc 유실을 해결하는 기능은 아니다. 다른 프로그램과 macOS·WSL·Linux 설정은 변경하지 않는다.

AutoHotkey v2는 선택 의존성이며 미실행 시 Esc 입력만 전달된다. 현재 원본을 재실행하면 기존 Alt/Windows 교환·Alt+Space·복사/붙여넣기 설정도 함께 로드되지만 그 내용은 변경하지 않는다. IME 제어 실패 시 영어 전환은 생략되며 Esc 원래 입력은 유지된다. 한글 조합·Neovim/mux/SSH의 물리 입력은 GUI 검증 전까지 미검증이다.

근거: [Windows Terminal 액션](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/actions), [WM_IME_CONTROL](https://learn.microsoft.com/en-us/windows/win32/intl/wm-ime-control).
