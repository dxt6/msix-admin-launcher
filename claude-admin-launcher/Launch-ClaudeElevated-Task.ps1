<#
.SYNOPSIS
    Launch Claude Desktop (MSIX) as Administrator with NO UAC prompt, via a
    pre-authorized Scheduled Task (RunLevel=HighestAvailable).
.DESCRIPTION
    Unlike Start-Process -Verb RunAs (which shows a UAC prompt unless the caller
    is already admin), a Scheduled Task fired by the SYSTEM task scheduler inherits
    the pre-approved highest token and elevates SILENTLY. We target the package's
    Win32 worker app\Claude.exe directly, bypassing the RuntimeBroker/AAM that
    would otherwise force Medium integrity. Path is resolved dynamically via
    Get-AppxPackage so MSIX upgrades need no edit.
    Keep this file pure ASCII (zh-CN PowerShell reads .ps1 as GBK without BOM).
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File Launch-ClaudeElevated-Task.ps1
#>
[CmdletBinding()]
param(
    [string]$TaskName = "ClaudeElevated"
)

$ErrorActionPreference = "Stop"

# Resolve Claude Desktop install path dynamically (survives MSIX version upgrades)
$pkg = Get-AppxPackage -Name "Claude" -ErrorAction Stop
if (-not $pkg) { throw "Claude package not found. Is Claude Desktop installed?" }
$exe = Join-Path $pkg.InstallLocation "app\Claude.exe"
if (-not (Test-Path $exe)) { throw "Claude entry point not found: $exe" }

# Close only MSIX Desktop instances, filtering by the WindowsApps path so we do
# NOT kill the Claude Code CLI (AppData\Local\Claude-3p\...) which is also "claude".
$running = Get-Process -Name "claude" -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like "*\WindowsApps\Claude_*" }
if ($running) {
    Write-Host "Closing $($running.Count) Claude Desktop process(es)..."
    $running | Stop-Process -Force
    Start-Sleep -Seconds 2
}

# Create the pre-authorized highest-privilege task on first run (needs admin once).
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (-not $existing) {
    Write-Host "Registering scheduled task '$TaskName' (run once as highest)..."
    $action = New-ScheduledTaskAction -Execute $exe
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
    Register-ScheduledTask -TaskName $TaskName -Action $action -Principal $principal -ErrorAction Stop | Out-Null
}

# Fire it. The task scheduler (SYSTEM) launches it with the admin token -> no UAC.
Write-Host "Launching Claude Desktop as Administrator (silent, no UAC)..."
Start-ScheduledTask -TaskName $TaskName
Write-Host "Done. Verify in Claude: whoami /groups -> S-1-16-12288 (High)."
