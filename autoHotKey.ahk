#Requires AutoHotkey v2.0
#SingleInstance Force

; 왼쪽 Alt와 Windows 키의 위치를 교환한다.
; 변환된 키가 아래의 키보드 훅 단축키도 실행하도록 입력 레벨을 높인다.
#InputLevel 1
LAlt::LWin
LWin::LAlt
#InputLevel 0
#UseHook

; WezTerm과 Windows Terminal에서 Esc 원래 입력을 통과시키고, 키를 뗄 때 영문 상태로 설정한다.
; 한영 토글 키를 보내지 않으므로 이미 영문이면 그대로 유지된다.
#HotIf WinActive("ahk_exe wezterm-gui.exe") || WinActive("ahk_exe WindowsTerminal.exe")
~Esc Up::
{
    try {
        IME_SET_ENGLISH("A")
    }
    ; IME를 제어할 수 없는 창에서도 Esc 원래 입력은 그대로 전달된다.
}
#HotIf

IME_SET_ENGLISH(winTitle) {
    hwnd := WinGetID(winTitle)
    imeHwnd := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
    if !imeHwnd
        return 0
    ; WM_IME_CONTROL / IMC_SETOPENSTATUS: 0은 영문(IME 닫힘).
    return SendMessage(0x0283, 0x0006, 0, , imeHwnd, , , , 100)
}

; 왼쪽 Alt + Space: 한영 전환.
<!Space::Send("{vk15sc138}")

; Alt + C/V: 복사/붙여넣기.
!c::Send("^c")
!v::Send("^v")
