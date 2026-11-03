#Requires AutoHotkey v2.0

; 터미널 비밀번호·OTP 입력용 함수. 단축키는 autoHotKey.ahk에서 정의한다.
; 비밀 값은 Windows 자격 증명 관리자(현재 사용자, 이 장치 한정)에만 저장하고 저장소에는 두지 않는다.

DOTFILES_CRED_PASSWORD := "dotfiles/autohotkey/password"
DOTFILES_CRED_OTP := "dotfiles/autohotkey/otp"
DOTFILES_CRED_TYPE_GENERIC := 1
DOTFILES_CRED_PERSIST_LOCAL_MACHINE := 2
DOTFILES_ERROR_NOT_FOUND := 1168

; ---------------------------------------------------------------------------
; Windows 자격 증명 관리자

DotfilesCredOffsets() {
    p := A_PtrSize
    o := {}
    o.target := 8
    o.blobSize := 16 + 2 * p
    blob := o.blobSize + 4
    o.blob := Mod(blob, p) ? blob + p - Mod(blob, p) : blob
    o.persist := o.blob + p
    o.userName := o.persist + 8 + 2 * p
    o.size := o.userName + p
    return o
}

DotfilesCredWrite(target, value) {
    o := DotfilesCredOffsets()
    blob := Buffer(StrLen(value) * 2)
    if blob.Size
        StrPut(value, blob, StrLen(value), "UTF-16")
    userName := "dotfiles"
    cred := Buffer(o.size, 0)
    NumPut("UInt", DOTFILES_CRED_TYPE_GENERIC, cred, 4)
    NumPut("Ptr", StrPtr(target), cred, o.target)
    NumPut("UInt", blob.Size, cred, o.blobSize)
    NumPut("Ptr", blob.Ptr, cred, o.blob)
    NumPut("UInt", DOTFILES_CRED_PERSIST_LOCAL_MACHINE, cred, o.persist)
    NumPut("Ptr", StrPtr(userName), cred, o.userName)
    ok := DllCall("advapi32\CredWriteW", "Ptr", cred, "UInt", 0, "Int")
    DllCall("RtlFillMemory", "Ptr", blob, "UPtr", blob.Size, "UChar", 0)
    if !ok
        throw OSError(A_LastError, -1, "CredWriteW " target)
}

; 저장된 값이 있으면 value에 넣고 true, 없으면 false를 돌려준다.
DotfilesCredRead(target, &value) {
    value := ""
    pcred := 0
    if !DllCall("advapi32\CredReadW", "WStr", target, "UInt", DOTFILES_CRED_TYPE_GENERIC, "UInt", 0, "Ptr*", &pcred, "Int") {
        if (A_LastError = DOTFILES_ERROR_NOT_FOUND)
            return false
        throw OSError(A_LastError, -1, "CredReadW " target)
    }
    o := DotfilesCredOffsets()
    try {
        size := NumGet(pcred, o.blobSize, "UInt")
        blob := NumGet(pcred, o.blob, "Ptr")
        value := size ? StrGet(blob, size // 2, "UTF-16") : ""
        return true
    } finally {
        DllCall("advapi32\CredFree", "Ptr", pcred)
    }
}

DotfilesCredDelete(target) {
    if DllCall("advapi32\CredDeleteW", "WStr", target, "UInt", DOTFILES_CRED_TYPE_GENERIC, "UInt", 0, "Int")
        return true
    if (A_LastError = DOTFILES_ERROR_NOT_FOUND)
        return false
    throw OSError(A_LastError, -1, "CredDeleteW " target)
}

; ---------------------------------------------------------------------------
; TOTP (RFC 6238)

DotfilesBase32Decode(text) {
    alphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    clean := RegExReplace(StrUpper(text), "[\s=-]")
    if (clean = "")
        throw ValueError("Empty Base32 secret")
    out := Buffer(StrLen(clean) * 5 // 8)
    bits := 0, value := 0, index := 0
    loop parse clean {
        n := InStr(alphabet, A_LoopField, true)
        if !n
            throw ValueError("Invalid Base32 character")
        value := ((value << 5) | (n - 1)) & 0xFFFF
        bits += 5
        if (bits >= 8) {
            bits -= 8
            NumPut("UChar", (value >> bits) & 0xFF, out, index++)
        }
    }
    if (index = 0)
        throw ValueError("Base32 secret is too short")
    return out
}

DotfilesHmac(algorithm, key, message) {
    lengths := Map("SHA1", 20, "SHA256", 32, "SHA512", 64)
    if !lengths.Has(algorithm)
        throw ValueError("Unsupported OTP algorithm: " algorithm)
    hAlg := 0
    ; BCRYPT_ALG_HANDLE_HMAC_FLAG = 0x8
    status := DllCall("bcrypt\BCryptOpenAlgorithmProvider", "Ptr*", &hAlg, "WStr", algorithm, "Ptr", 0, "UInt", 0x8, "UInt")
    if status
        throw OSError(status, -1, "BCryptOpenAlgorithmProvider")
    try {
        out := Buffer(lengths[algorithm])
        status := DllCall("bcrypt\BCryptHash", "Ptr", hAlg, "Ptr", key, "UInt", key.Size
            , "Ptr", message, "UInt", message.Size, "Ptr", out, "UInt", out.Size, "UInt")
        if status
            throw OSError(status, -1, "BCryptHash")
        return out
    } finally {
        DllCall("bcrypt\BCryptCloseAlgorithmProvider", "Ptr", hAlg, "UInt", 0)
    }
}

DotfilesTotpCode(key, unixTime, digits := 6, period := 30, algorithm := "SHA1") {
    counter := unixTime // period
    message := Buffer(8, 0)
    loop 8
        NumPut("UChar", (counter >> (8 * (8 - A_Index))) & 0xFF, message, A_Index - 1)
    hash := DotfilesHmac(algorithm, key, message)
    offset := NumGet(hash, hash.Size - 1, "UChar") & 0x0F
    binary := ((NumGet(hash, offset, "UChar") & 0x7F) << 24)
        | (NumGet(hash, offset + 1, "UChar") << 16)
        | (NumGet(hash, offset + 2, "UChar") << 8)
        | NumGet(hash, offset + 3, "UChar")
    return Format("{:0" digits "}", Mod(binary, 10 ** digits))
}

DotfilesUnixTime() {
    return DateDiff(A_NowUTC, "19700101000000", "Seconds")
}

; Base32 비밀키 또는 otpauth://totp/... URI를 받아 검증한 설정 객체를 돌려준다.
DotfilesParseOtpInput(text) {
    text := Trim(text)
    otp := {secret: text, digits: 6, period: 30, algorithm: "SHA1"}
    if RegExMatch(text, "i)^otpauth://([^/]+)/[^?]*\?(.*)$", &uri) {
        if (StrLower(uri[1]) != "totp")
            throw ValueError("Only TOTP is supported")
        otp.secret := ""
        loop parse uri[2], "&" {
            pair := StrSplit(A_LoopField, "=", , 2)
            if (pair.Length < 2)
                continue
            name := StrLower(pair[1]), value := pair[2]
            switch name {
                case "secret": otp.secret := value
                case "digits": otp.digits := Integer(value)
                case "period": otp.period := Integer(value)
                case "algorithm": otp.algorithm := StrUpper(value)
            }
        }
    }
    otp.secret := RegExReplace(StrUpper(otp.secret), "[\s=-]")
    if !(otp.digits >= 6 && otp.digits <= 8)
        throw ValueError("OTP digits must be 6-8")
    if (otp.period < 1)
        throw ValueError("OTP period must be positive")
    DotfilesHmac(otp.algorithm, DotfilesBase32Decode(otp.secret), Buffer(8, 0))
    return otp
}

DotfilesOtpSerialize(otp) {
    return "v1;" otp.algorithm ";" otp.digits ";" otp.period ";" otp.secret
}

DotfilesOtpDeserialize(stored) {
    parts := StrSplit(stored, ";")
    if (parts.Length != 5 || parts[1] != "v1")
        throw ValueError("Unknown stored OTP format")
    return {algorithm: parts[2], digits: Integer(parts[3]), period: Integer(parts[4]), secret: parts[5]}
}

DotfilesCurrentOtp(otp, &remaining := 0) {
    now := DotfilesUnixTime()
    remaining := otp.period - Mod(now, otp.period)
    return DotfilesTotpCode(DotfilesBase32Decode(otp.secret), now, otp.digits, otp.period, otp.algorithm)
}

; ---------------------------------------------------------------------------
; 단축키 동작

DotfilesSendPassword() {
    try {
        found := DotfilesCredRead(DOTFILES_CRED_PASSWORD, &value)
    } catch Error as e {
        MsgBox("비밀번호를 읽지 못했습니다: " e.Message, "dotfiles", "Iconx")
        return
    }
    if (!found || value = "") {
        MsgBox("등록된 비밀번호가 없습니다. Ctrl+Alt+Shift+P로 등록하세요.", "dotfiles", "Icon!")
        return
    }
    SendText(value)
    value := ""
}

DotfilesSendOtp() {
    try {
        if !DotfilesCredRead(DOTFILES_CRED_OTP, &stored) {
            MsgBox("등록된 OTP가 없습니다. Ctrl+Alt+Shift+O로 등록하세요.", "dotfiles", "Icon!")
            return
        }
        otp := DotfilesOtpDeserialize(stored)
        code := DotfilesCurrentOtp(otp, &remaining)
        ; 만료 직전 코드는 입력 도중 바뀔 수 있으므로 다음 코드까지 기다린다.
        if (remaining <= 2) {
            Sleep(remaining * 1000 + 200)
            code := DotfilesCurrentOtp(otp)
        }
    } catch Error as e {
        MsgBox("OTP를 만들지 못했습니다: " e.Message, "dotfiles", "Iconx")
        return
    }
    SendText(code)
}

DotfilesRegisterPassword() {
    first := InputBox("터미널에 입력할 비밀번호를 입력하세요.`n이 장치의 Windows 자격 증명 관리자에 저장됩니다.", "dotfiles 비밀번호 등록", "Password w360 h150")
    if (first.Result != "OK" || first.Value = "")
        return
    second := InputBox("확인을 위해 한 번 더 입력하세요.", "dotfiles 비밀번호 등록", "Password w360 h130")
    if (second.Result != "OK")
        return
    if (first.Value !== second.Value) {
        MsgBox("두 입력이 다릅니다. 저장하지 않았습니다.", "dotfiles", "Icon!")
        return
    }
    try {
        DotfilesCredWrite(DOTFILES_CRED_PASSWORD, first.Value)
    } catch Error as e {
        MsgBox("저장하지 못했습니다: " e.Message, "dotfiles", "Iconx")
        return
    }
    MsgBox("비밀번호를 저장했습니다. Ctrl+Alt+P로 입력합니다.", "dotfiles", "Iconi")
}

DotfilesRegisterOtp() {
    input := InputBox("OTP 비밀키(Base32) 또는 otpauth://totp/... URI를 입력하세요.`n이 장치의 Windows 자격 증명 관리자에 저장됩니다.", "dotfiles OTP 등록", "Password w420 h150")
    if (input.Result != "OK" || Trim(input.Value) = "")
        return
    try {
        otp := DotfilesParseOtpInput(input.Value)
        code := DotfilesCurrentOtp(otp, &remaining)
    } catch Error as e {
        MsgBox("OTP 비밀키를 확인하세요: " e.Message, "dotfiles", "Iconx")
        return
    }
    answer := MsgBox("현재 코드: " code " (" remaining "초 남음)`n인증 앱의 코드와 같으면 저장합니다.", "dotfiles OTP 등록", "YesNo Iconi")
    if (answer != "Yes")
        return
    try {
        DotfilesCredWrite(DOTFILES_CRED_OTP, DotfilesOtpSerialize(otp))
    } catch Error as e {
        MsgBox("저장하지 못했습니다: " e.Message, "dotfiles", "Iconx")
        return
    }
    MsgBox("OTP를 저장했습니다. Ctrl+Alt+O로 입력합니다.", "dotfiles", "Iconi")
}
