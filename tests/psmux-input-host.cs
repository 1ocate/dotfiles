/*
MIT License

Copyright (c) 2025 Josh

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/
using System;
using System.Runtime.InteropServices;
using System.Threading;

// Adapted from psmux v3.3.8 tests/conpty_host_0xE.cs (MIT).
// Test-only ConPTY host: HEX lines feed actual terminal bytes to an attached client.
// All control/output files live in DOTFILES_PROBE_DIR, set by the Python test.
class PsmuxInputHost {
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool CreatePipe(out IntPtr hRead, out IntPtr hWrite, IntPtr sa, uint size);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern int CreatePseudoConsole(COORD size, IntPtr hInput, IntPtr hOutput, uint flags, out IntPtr phPC);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern void ClosePseudoConsole(IntPtr hPC);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool WriteFile(IntPtr h, byte[] buf, uint n, out uint written, IntPtr ov);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool ReadFile(IntPtr h, byte[] buf, uint n, out uint read, IntPtr ov);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool CloseHandle(IntPtr h);

    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool InitializeProcThreadAttributeList(IntPtr lpAttributeList, int dwAttributeCount, int dwFlags, ref IntPtr lpSize);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool UpdateProcThreadAttribute(IntPtr lpAttributeList, uint dwFlags, IntPtr Attribute, IntPtr lpValue, IntPtr cbSize, IntPtr lpPreviousValue, IntPtr lpReturnSize);
    [DllImport("kernel32.dll", EntryPoint="CreateProcessW", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern bool CreateProcess(string app, System.Text.StringBuilder cmd, IntPtr pa, IntPtr ta, bool inherit, uint flags, IntPtr env, string cwd, ref STARTUPINFOEX si, out PROCESS_INFORMATION pi);

    [StructLayout(LayoutKind.Sequential)] struct COORD { public short X, Y; }
    [StructLayout(LayoutKind.Sequential)]
    struct STARTUPINFO { public int cb; public string r1; public string r2; public string r3; public int dx,dy,dxs,dys,dxc,dyc,fa; public int flags; public short showw; public short r4; public IntPtr r5; public IntPtr si, so, se; }
    [StructLayout(LayoutKind.Sequential)]
    struct STARTUPINFOEX { public STARTUPINFO StartupInfo; public IntPtr lpAttributeList; }
    [StructLayout(LayoutKind.Sequential)]
    struct PROCESS_INFORMATION { public IntPtr hProcess, hThread; public int pid, tid; }

    [DllImport("kernel32.dll")]
    static extern void DeleteProcThreadAttributeList(IntPtr list);

    const uint EXTENDED_STARTUPINFO_PRESENT = 0x00080000;
    static readonly IntPtr PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE = new IntPtr(0x00020016);

    static void Main(string[] args) {
        string cmd = args.Length > 0 ? string.Join(" ", args) : "cmd.exe";
        string ctrlFile = Environment.GetEnvironmentVariable("DOTFILES_PROBE_DIR") + "\\conpty_ctrl.txt";
        string outFile = Environment.GetEnvironmentVariable("DOTFILES_PROBE_DIR") + "\\conpty_out.bin";
        string logFile = Environment.GetEnvironmentVariable("DOTFILES_PROBE_DIR") + "\\conpty_host.log";
        var log = new System.Text.StringBuilder();

        IntPtr inRead = IntPtr.Zero, inWrite = IntPtr.Zero, outRead = IntPtr.Zero, outWrite = IntPtr.Zero;
        IntPtr hPC = IntPtr.Zero, attr = IntPtr.Zero;
        bool attributesInitialized = false;
        Thread reader = null;
        System.IO.FileStream outFs = null;
        try {
            if (!CreatePipe(out inRead, out inWrite, IntPtr.Zero, 0)) throw new System.ComponentModel.Win32Exception();   // we write to inWrite -> child stdin
            if (!CreatePipe(out outRead, out outWrite, IntPtr.Zero, 0)) throw new System.ComponentModel.Win32Exception(); // child stdout -> we read outRead

            COORD size; size.X = 120; size.Y = 30;
            // Standard documented ConPTY mode; no undocumented passthrough flags.
            int hr = CreatePseudoConsole(size, inRead, outWrite, 0, out hPC);
            log.Append("CreatePseudoConsole hr=" + hr + "\r\n");
            if (hr != 0) throw new InvalidOperationException("CreatePseudoConsole failed: " + hr);

            IntPtr lpSize = IntPtr.Zero;
            InitializeProcThreadAttributeList(IntPtr.Zero, 1, 0, ref lpSize);
            if (lpSize == IntPtr.Zero) throw new InvalidOperationException("Missing process attribute size");
            attr = Marshal.AllocHGlobal(lpSize);
            if (!InitializeProcThreadAttributeList(attr, 1, 0, ref lpSize)) throw new System.ComponentModel.Win32Exception();
            attributesInitialized = true;
            if (!UpdateProcThreadAttribute(attr, 0, PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE, hPC, (IntPtr)IntPtr.Size, IntPtr.Zero, IntPtr.Zero)) throw new System.ComponentModel.Win32Exception();

            var siex = new STARTUPINFOEX();
            siex.StartupInfo.cb = Marshal.SizeOf(typeof(STARTUPINFOEX));
            siex.lpAttributeList = attr;
            PROCESS_INFORMATION pi;
            bool ok = CreateProcess(null, new System.Text.StringBuilder(cmd), IntPtr.Zero, IntPtr.Zero, false, EXTENDED_STARTUPINFO_PRESENT, IntPtr.Zero, null, ref siex, out pi);
            log.Append("CreateProcess ok=" + ok + " e=" + Marshal.GetLastWin32Error() + " childPid=" + pi.pid + "\r\n");
            System.IO.File.WriteAllText(logFile, log.ToString());
            if (!ok) throw new System.ComponentModel.Win32Exception();
            CloseHandle(pi.hThread);
            CloseHandle(pi.hProcess);
            System.IO.File.WriteAllText(Environment.GetEnvironmentVariable("DOTFILES_PROBE_DIR") + "\\conpty_childpid.txt", pi.pid.ToString());

            // Reader thread: drain child output so the pipe never blocks.
            outFs = new System.IO.FileStream(outFile, System.IO.FileMode.Create, System.IO.FileAccess.Write);
            reader = new Thread(() => {
                byte[] buf = new byte[4096];
                while (true) {
                    uint r;
                    if (!ReadFile(outRead, buf, (uint)buf.Length, out r, IntPtr.Zero) || r == 0) break;
                    lock (outFs) { outFs.Write(buf, 0, (int)r); outFs.Flush(); }
                }
            });
            reader.IsBackground = true;
            reader.Start();

            long lastLen = 0;
            while (true) {
                Thread.Sleep(100);
                if (!System.IO.File.Exists(ctrlFile)) continue;
                string content;
                try { content = System.IO.File.ReadAllText(ctrlFile); } catch { continue; }
                if (content.Length == (int)lastLen) continue;
                string tail = content.Substring((int)lastLen);
                lastLen = content.Length;
                foreach (var rawLine in tail.Split('\n')) {
                    string line = rawLine.Trim();
                    if (line.Length == 0) continue;
                    if (line.StartsWith("HEX ")) {
                        string hex = line.Substring(4);
                        if (hex.Length % 2 != 0) throw new ArgumentException("Odd HEX length");
                        byte[] bytes = new byte[hex.Length / 2];
                        for (int j = 0; j < bytes.Length; j++) bytes[j] = Convert.ToByte(hex.Substring(j * 2, 2), 16);
                        uint written;
                        if (!WriteFile(inWrite, bytes, (uint)bytes.Length, out written, IntPtr.Zero) || written != bytes.Length)
                            throw new System.ComponentModel.Win32Exception();
                    } else if (line.StartsWith("QUIT")) {
                        return;
                    }
                }
            }
        } finally {
            if (attributesInitialized) DeleteProcThreadAttributeList(attr);
            if (attr != IntPtr.Zero) Marshal.FreeHGlobal(attr);
            if (hPC != IntPtr.Zero) ClosePseudoConsole(hPC);
            if (inRead != IntPtr.Zero) CloseHandle(inRead);
            if (inWrite != IntPtr.Zero) CloseHandle(inWrite);
            if (outWrite != IntPtr.Zero) CloseHandle(outWrite);
            if (reader != null && reader.Join(2000) && outFs != null) outFs.Dispose();
            if (outRead != IntPtr.Zero) CloseHandle(outRead);
        }
    }
}
