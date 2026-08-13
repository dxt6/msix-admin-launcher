<#
.SYNOPSIS
    Restart Claude Desktop (MSIX) as Administrator.
.DESCRIPTION
    Claude Desktop is an MSIX app. A running process cannot be elevated after the
    fact, and a single-instance MSIX cannot have two instances at different
    integrity levels. So we close the normal (Medium) Desktop instance, then
    relaunch with "Run as admin". Claude declares runFullTrust, so launching the
    exe directly bypasses the RuntimeBroker and inherits the caller's admin token.
    NOTE: keep this file pure ASCII. On zh-CN Windows, PowerShell reads .ps1 as the
    system ANSI codepage; Chinese text without a BOM gets mangled and the script
    fails to parse. All Chinese docs live in README.md.
    IMPORTANT: this only touches the MSIX Desktop instance (path under
    \WindowsApps\Claude_*). It deliberately leaves the Claude Code CLI
    (Claude-3p\claude-code\...) alone, because that process also shows up as
    "claude" and is a separate win32 binary the user may be actively using.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# Resolve Claude Desktop install path dynamically (survives MSIX version upgrades)
$pkg = Get-AppxPackage -Name "Claude" -ErrorAction Stop
if (-not $pkg) { throw "Claude package not found. Is Claude Desktop installed?" }
$exe = Join-Path $pkg.InstallLocation "app\Claude.exe"
if (-not (Test-Path $exe)) { throw "Claude entry point not found: $exe" }

# Close only the MSIX Desktop instances. Filter by the WindowsApps path so we do
# NOT kill the Claude Code CLI (AppData\Local\Claude-3p\...) which is also "claude".
$running = Get-Process -Name "claude" -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like "*\WindowsApps\Claude_*" }
if ($running) {
    Write-Host "Closing $($running.Count) Claude Desktop process(es)..."
    $running | Stop-Process -Force
    Start-Sleep -Seconds 2
}

# Relaunch as Administrator. In an already-admin session this is silent (no UAC);
# in a normal session a UAC prompt appears. Either way the new instance inherits
# the admin token (runFullTrust bypasses the broker).
Write-Host "Launching Claude Desktop as Administrator..."
Start-Process -FilePath $exe -Verb RunAs

Write-Host "Done. If approved, the new Claude Desktop is an admin (High) instance."
Write-Host "Verify: in Claude run 'whoami /groups' and look for S-1-16-12288 (High)."
