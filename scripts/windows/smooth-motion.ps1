# Toggle NVIDIA driver-level Smooth Motion for our executable via NVAPI DRS.
# Requires no admin; NVIDIA App must be closed while changing settings.
param(
    [ValidateSet('off','on','query')][string]$State = 'query',
    [string]$Exe = ''
)

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ([string]::IsNullOrWhiteSpace($Exe)) {
    $Exe = Join-Path $repoRoot 'target\release\victory_rtx.exe'
}

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class NvDr {
    public enum Status : int { OK = 0, ERROR = -1 }

    [StructLayout(LayoutKind.Sequential, Pack = 8, CharSet = CharSet.Unicode)]
    public struct Setting {
        public uint version;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 2048)] public string name;
        public uint id;
        public int type;
        public int location;
        public uint isCurrentPredefined;
        public uint isPredefinedValid;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 4100)] public byte[] predefined;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 4100)] public byte[] current;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 8, CharSet = CharSet.Unicode)]
    public struct Profile {
        public uint version;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 2048)] public string name;
        public uint gpuSupport;
        public uint isPredefined;
        public uint numApps;
        public uint numSettings;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 8, CharSet = CharSet.Unicode)]
    public struct Application {
        public uint version;
        public uint isPredefined;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 2048)] public string appName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 2048)] public string friendly;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 2048)] public string launcher;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 2048)] public string fileInFolder;
        public uint flags;
    }

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate IntPtr Query(uint id);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate Status Init();
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate Status Session(ref IntPtr h);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate Status Void(IntPtr h);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate Status FindApp(IntPtr h, [MarshalAs(UnmanagedType.LPWStr)] StringBuilder name, ref IntPtr profile, ref Application app);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate Status CreateProfile(IntPtr h, ref Profile p, ref IntPtr profile);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate Status CreateApp(IntPtr h, IntPtr profile, ref Application app);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate Status GetSetting(IntPtr h, IntPtr profile, uint id, ref Setting s, ref uint x);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate Status SetSetting(IntPtr h, IntPtr profile, ref Setting s, uint x, uint y);

    static Query q;
    public static Init Initialize;
    static Session _create;
    static Void _load, _save, _destroy;
    public static FindApp FindApplication;
    public static CreateProfile MakeProfile;
    public static CreateApp MakeApplication;
    public static GetSetting Get;
    public static SetSetting Set;

    public const uint ID = 0xB0D384C0; // Smooth Motion - Enable

    static NvDr() {
        IntPtr lib = LoadLibrary(IntPtr.Size == 8 ? "nvapi64.dll" : "nvapi.dll");
        if (lib == IntPtr.Zero) return;
        IntPtr p = GetProcOrdinal(lib, (IntPtr)2);
        if (p == IntPtr.Zero) return;
        q = (Query)Marshal.GetDelegateForFunctionPointer(p, typeof(Query));
        Initialize = D<Init>(0x0150E828);
        _create = D<Session>(0x0694D52E);
        _destroy = D<Void>(0xDAD9CFF8);
        _load = D<Void>(0x375DBD6B);
        _save = D<Void>(0xFCBC7E14);
        FindApplication = D<FindApp>(0xEEE566B2);
        MakeProfile = D<CreateProfile>(0xCC176068);
        MakeApplication = D<CreateApp>(0x4347A9DE);
        Get = D<GetSetting>(0xEA99498D);
        Set = D<SetSetting>(0x8A2CF5F5);
    }

    static T D<T>(uint id) where T : class {
        if (q == null) return null;
        IntPtr p = q(id);
        return p == IntPtr.Zero ? null : (T)(object)Marshal.GetDelegateForFunctionPointer(p, typeof(T));
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Auto)] static extern IntPtr LoadLibrary(string name);
    [DllImport("kernel32.dll", EntryPoint = "GetProcAddress")] static extern IntPtr GetProcOrdinal(IntPtr lib, IntPtr ordinal);

    public static bool Ready { get { return q != null && Initialize != null && _create != null; } }

    public static Status Open(out IntPtr session) {
        session = IntPtr.Zero;
        if (!Ready) return Status.ERROR;
        Status s = Initialize();
        if (s != Status.OK) return s;
        s = _create(ref session);
        if (s != Status.OK) return s;
        return _load(session);
    }
    public static Status Close(IntPtr session) {
        Status s = _save(session);
        _destroy(session);
        return s;
    }

    public static uint Version<T>(int v) { return (uint)((Marshal.SizeOf(typeof(T))) | (v << 16)); }

    public static Status EnsureProfile(IntPtr session, string exe, out IntPtr profile) {
        profile = IntPtr.Zero;
        Application app = new Application();
        app.version = Version<Application>(3);
        app.appName = exe;
        app.friendly = "VIctory";
        app.launcher = "";
        app.fileInFolder = "";
        StringBuilder name = new StringBuilder(exe);
        Status s = FindApplication(session, name, ref profile, ref app);
        if (s == Status.OK && profile != IntPtr.Zero) return s;
        Profile p = new Profile();
        p.version = Version<Profile>(1);
        p.name = "VIctory GPU Profile";
        p.gpuSupport = 1;
        s = MakeProfile(session, ref p, ref profile);
        if (s != Status.OK) return s;
        app.appName = exe;
        return MakeApplication(session, profile, ref app);
    }

    public static uint Read(IntPtr session, IntPtr profile) {
        Setting s = NewSetting();
        uint x = 0;
        Status r = Get(session, profile, ID, ref s, ref x);
        if (r != Status.OK) return uint.MaxValue;
        return BitConverter.ToUInt32(s.current, 0);
    }

    public static Status Write(IntPtr session, IntPtr profile, uint value) {
        Setting s = NewSetting();
        s.id = ID;
        s.type = 0;
        s.location = 0;
        byte[] bytes = BitConverter.GetBytes(value);
        Buffer.BlockCopy(bytes, 0, s.current, 0, 4);
        return Set(session, profile, ref s, 0, 0);
    }

    static Setting NewSetting() {
        Setting s = new Setting();
        s.version = Version<Setting>(1);
        s.name = "";
        s.predefined = new byte[4100];
        s.current = new byte[4100];
        return s;
    }
}
'@ -ErrorAction Stop

if (-not [NvDr]::Ready) { throw 'nvapi64.dll missing or NVAPI unavailable.' }
$session = [IntPtr]::Zero
$s = [NvDr]::Open([ref]$session)
if ($s -ne [NvDr+Status]::OK) { throw "NVAPI session open failed: $s" }
try {
    $profile = [IntPtr]::Zero
    $s = [NvDr]::EnsureProfile($session, $Exe, [ref]$profile)
    if ($s -ne [NvDr+Status]::OK) { throw "DRS profile lookup/create failed: $s" }
    $before = [NvDr]::Read($session, $profile)
    if ($State -eq 'query') {
        if ($before -eq [uint32]::MaxValue) { 'Smooth Motion: unset (default)' }
        elseif ($before -eq 0) { 'Smooth Motion: OFF' }
        else { 'Smooth Motion: ON' }
    } else {
        $value = if ($State -eq 'on') { [uint32]1 } else { [uint32]0 }
        $s = [NvDr]::Write($session, $profile, $value)
        if ($s -ne [NvDr+Status]::OK) { throw "DRS write failed: $s" }
        $after = [NvDr]::Read($session, $profile)
        "Smooth Motion: $before -> $after (takes effect on next process launch)"
    }
} finally {
    [void][NvDr]::Close($session)
}
