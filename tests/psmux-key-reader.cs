using System;
using System.IO;
using System.Runtime.InteropServices;
class KeyReader {
 [DllImport("kernel32.dll")] static extern IntPtr GetStdHandle(int n);
 [DllImport("kernel32.dll")] static extern bool SetConsoleMode(IntPtr h,uint mode);
 [DllImport("kernel32.dll")] static extern bool ReadFile(IntPtr h,byte[] b,uint n,out uint count,IntPtr ov);
 [DllImport("kernel32.dll",EntryPoint="ReadConsoleInputW")] static extern bool ReadConsoleInput(IntPtr h,out InputRecord record,uint n,out uint count);
 [StructLayout(LayoutKind.Explicit,Size=20)] struct InputRecord {
  [FieldOffset(0)] public ushort Type;
  [FieldOffset(4)] public int Down;
  [FieldOffset(8)] public ushort Repeat;
  [FieldOffset(10)] public ushort VirtualKey;
  [FieldOffset(12)] public ushort Scan;
  [FieldOffset(14)] public char Character;
  [FieldOffset(16)] public uint Controls;
 }
 static void Main(string[] args) {
  string file=args[1]; string mode=args[0];
  IntPtr input=GetStdHandle(-10);
  if(!SetConsoleMode(input,mode=="raw"?0x0200u:0u)) throw new Exception("SetConsoleMode failed");
  File.WriteAllText(file+".ready","ready");
  while(true) {
   string line;
   if(mode=="raw") { byte[] b=new byte[4096]; uint count; if(!ReadFile(input,b,4096,out count,IntPtr.Zero)) break; line=BitConverter.ToString(b,0,(int)count); }
   else if(mode=="events") { InputRecord r; uint count; if(!ReadConsoleInput(input,out r,1,out count)) break; if(r.Type!=1) continue; line="char="+((int)r.Character).ToString("X2")+" vk="+r.VirtualKey+" scan="+r.Scan+" down="+r.Down+" repeat="+r.Repeat+" controls="+r.Controls; }
   else { ConsoleKeyInfo k=Console.ReadKey(true); line=((int)k.KeyChar).ToString("X2")+" key="+k.Key+" modifiers="+k.Modifiers; }
   File.AppendAllText(file,line+Environment.NewLine);
  }
 }
}
