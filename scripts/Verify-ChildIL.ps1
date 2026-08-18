<#
.SYNOPSIS
    Verify the REAL integrity level (admin vs medium) of a running process by
    reading its own token -- NOT the parent/admin session.
.DESCRIPTION
    Reads TokenIntegrityLevel from each matching process and prints S-1-16-12288
    (High/admin), 8192 (Medium), 4096 (Low). This is the only correct way to
    confirm a launcher actually elevated the child: a parent showing High does
    NOT prove the child is High.
    Keep this file pure ASCII. zh-CN PowerShell reads .ps1 as system ANSI (GBK);
    non-BOM UTF-8 gets mangled and the script fails to parse.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File Verify-ChildIL.ps1 -Name claude
#>
[CmdletBinding()]
param(
    [string]$Name = "claude"
)

$procs = Get-Process -Name $Name -ErrorAction SilentlyContinue
if ($null -eq $procs -or @($procs).Count -eq 0) {
    Write-Host "NO_$Name`_PROCESS"
    return
}

Add-Type @'
using System; using System.Runtime.InteropServices;
public class TK {
  [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(int a, bool b, int pid);
  [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
  [DllImport("advapi32.dll")] public static extern bool OpenProcessToken(IntPtr h, uint a, out IntPtr t);
  [DllImport("advapi32.dll")] public static extern bool GetTokenInformation(IntPtr t, int c, IntPtr b, uint l, out uint r);
}
'@

foreach ($c in $procs) {
    try { $path = $c.MainModule.FileName } catch { $path = "?" }
    $h = [TK]::OpenProcess(0x0400, $false, $c.Id)
    if ($h -eq [IntPtr]::Zero) { Write-Host "PID=$($c.Id) PATH=$path OPENPROC_FAIL"; continue }
    $tok = [IntPtr]::Zero
    if (-not [TK]::OpenProcessToken($h, 0x8, [ref]$tok)) {
        Write-Host "PID=$($c.Id) PATH=$path OPENTOKEN_FAIL"; [TK]::CloseHandle($h); continue
    }
    $buf = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(64)
    $rl = 0
    [TK]::GetTokenInformation($tok, 25, $buf, 64, [ref]$rl) | Out-Null
    $sid = [System.Runtime.InteropServices.Marshal]::ReadIntPtr($buf)
    $cnt = [System.Runtime.InteropServices.Marshal]::ReadByte($sid, 1)
    $rid = [System.Runtime.InteropServices.Marshal]::ReadInt32($sid, 8 + 4 * ($cnt - 1))
    $il = if ($rid -eq 12288) { "HIGH(admin)" } elseif ($rid -eq 8192) { "MEDIUM" } elseif ($rid -eq 4096) { "LOW" } else { "RID=$rid" }
    Write-Host "PID=$($c.Id) PATH=$path IL=$il ($rid)"
    [TK]::CloseHandle($h)
}
