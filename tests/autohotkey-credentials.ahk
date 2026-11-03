#Requires AutoHotkey v2.0
#NoTrayIcon
#Include ..\autohotkey\credentials.ahk

; 실행: AutoHotkey64.exe /ErrorStdOut tests\autohotkey-credentials.ahk
; 단축키·Alt/Win 교환은 로드하지 않는다. 자격 증명 왕복 검사는 임시 대상을 만들고 즉시 삭제한다.

failures := 0
checks := 0

Check(name, actual, expected) {
    global failures, checks
    checks++
    if (actual !== expected) {
        failures++
        FileAppend("FAIL " name ": expected " expected ", got " actual "`n", "*")
    }
}

AsciiBuffer(text) {
    buf := Buffer(StrLen(text))
    StrPut(text, buf, StrLen(text), "CP0")
    return buf
}

BufferHex(buf) {
    out := ""
    loop buf.Size
        out .= Format("{:02x}", NumGet(buf, A_Index - 1, "UChar"))
    return out
}

; RFC 6238 Appendix B (8자리)
keys := Map(
    "SHA1", AsciiBuffer("12345678901234567890"),
    "SHA256", AsciiBuffer("12345678901234567890123456789012"),
    "SHA512", AsciiBuffer("1234567890123456789012345678901234567890123456789012345678901234"))
vectors := [
    [59, "94287082", "46119246", "90693936"],
    [1111111109, "07081804", "68084774", "25091201"],
    [1111111111, "14050471", "67062674", "99943326"],
    [1234567890, "89005924", "91819424", "93441116"],
    [2000000000, "69279037", "90698825", "38618901"],
    [20000000000, "65353130", "77737706", "47863826"]]
for v in vectors {
    for i, alg in ["SHA1", "SHA256", "SHA512"]
        Check(alg " T=" v[1], DotfilesTotpCode(keys[alg], v[1], 8, 30, alg), v[i + 1])
}

; RFC 4226 Appendix D (HOTP 6자리 = TOTP period 1, 시간 = counter)
hotp := ["755224", "287082", "359152", "969429", "338314", "254676", "287922", "162583", "399871", "520489"]
for i, expected in hotp
    Check("HOTP counter " (i - 1), DotfilesTotpCode(keys["SHA1"], i - 1, 6, 1, "SHA1"), expected)

; Base32
Check("base32", BufferHex(DotfilesBase32Decode("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ")), BufferHex(keys["SHA1"]))
Check("base32 lower/space", BufferHex(DotfilesBase32Decode("gezd gnbv gy3t qojq gezd gnbv gy3t qojq")), BufferHex(keys["SHA1"]))
Check("base32 padding", BufferHex(DotfilesBase32Decode("MZXW6===")), "666f6f")
for bad in ["", "ABC1", "!!!!"] {
    try {
        DotfilesBase32Decode(bad)
        Check("base32 reject '" bad "'", "accepted", "rejected")
    }
}

; otpauth URI와 저장 형식
otp := DotfilesParseOtpInput("otpauth://totp/Corp:me?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ&issuer=Corp&algorithm=sha256&digits=8&period=60")
Check("uri algorithm", otp.algorithm, "SHA256")
Check("uri digits", otp.digits, 8)
Check("uri period", otp.period, 60)
restored := DotfilesOtpDeserialize(DotfilesOtpSerialize(otp))
Check("serialize", DotfilesOtpSerialize(restored), "v2;SHA256;8;60;GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ;")
plain := DotfilesParseOtpInput(" gezd gnbv gy3t qojq gezd gnbv gy3t qojq ")
Check("plain defaults", DotfilesOtpSerialize(plain), "v2;SHA1;6;30;GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ;")
legacy := DotfilesOtpDeserialize("v1;SHA1;6;30;GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ")
Check("legacy v1 name", legacy.name, "")
Check("legacy v1 label", DotfilesOtpLabel({slot: 1, otp: legacy}), "OTP 1")
named := DotfilesOtpDeserialize("v2;SHA1;6;30;GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ;VPN; 서버 & 2")
Check("v2 name with separators", named.name, "VPN; 서버 & 2")
Check("v2 roundtrip", DotfilesOtpSerialize(named), "v2;SHA1;6;30;GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ;VPN; 서버 & 2")
Check("empty slot label", DotfilesOtpLabel({slot: 2, otp: false}), "OTP 2")
Check("slot targets", DOTFILES_OTP_TARGETS[1] "|" DOTFILES_OTP_TARGETS[2], "dotfiles/autohotkey/otp|dotfiles/autohotkey/otp-2")
for bad in ["otpauth://hotp/x?secret=GEZDGNBV&counter=1", "otpauth://totp/x?secret=GEZDGNBV&digits=4", "otpauth://totp/x?secret=GEZDGNBV&algorithm=MD5"] {
    try {
        DotfilesParseOtpInput(bad)
        Check("reject " bad, "accepted", "rejected")
    }
}

; 자격 증명 관리자 왕복 (임시 대상)
target := "dotfiles/autohotkey/test-" A_TickCount "-" Random(100000, 999999)
sample := "p@ss 한글 `;=0"
try {
    DotfilesCredWrite(target, sample)
    Check("cred found", DotfilesCredRead(target, &value), true)
    Check("cred value", value, sample)
    DotfilesCredWrite(target, "0")
    DotfilesCredRead(target, &value)
    Check("cred overwrite", value, "0")
} finally {
    deleted := DotfilesCredDelete(target)
}
Check("cred deleted", deleted, true)
Check("cred missing", DotfilesCredRead(target, &value), false)
Check("cred delete missing", DotfilesCredDelete(target), false)

FileAppend((failures ? failures " failure(s)" : "AutoHotkey credential/TOTP checks passed: " checks) "`n", "*")
ExitApp(failures ? 1 : 0)
