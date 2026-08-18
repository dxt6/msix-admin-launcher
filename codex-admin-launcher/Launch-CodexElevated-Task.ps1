<#
.SYNOPSIS
    Launch OpenAI Codex (MSIX) Desktop as Administrator with NO UAC prompt, via a
    pre-authorized Scheduled Task (RunLevel=HighestAvailable).
.DESCRIPTION
    NOTE / correction to earlier docs: an MSIX app CAN be elevated silently via a
    Scheduled Task as long as you target the package's real Win32 worker binary
    (app\ChatGPT.exe for Codex), not the MSIX package AUMID. The task scheduler
    (SYSTEM) launches it with the pre-approved highest token, bypassing both UAC
    and the RuntimeBroker that would otherwise force Medium integrity. This was
    verified against Claude's app\Claude.exe (IL=12288 High, no UAC); Codex's
    app\ChatGPT.exe follows the same runFullTrust pattern.
    Path resolved dynamically via Get-AppxPackage so upgrades need no edit.
    Keep this file pure ASCII (zh-CN PowerShell reads .ps1 as GBK without BOM).
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File Launch-CodexElevated-Task.ps1
#>
[CmdletBinding()]
param(
    [string]$TaskName = "CodexElevated"
)

$ErrorActionPreference = "Stop"

$pkg = Get-AppxPackage -Name "OpenAI.Codex" -ErrorAction Stop
if (-not $pkg) { throw "OpenAI.Codex package not found. Is Codex installed?" }
$exe = Join-Path $pkg.InstallLocation "app\ChatGPT.exe"
if (-not (Test-Path $exe)) { throw "Codex entry point not found: $exe" }

$running = Get-Process -Name "ChatGPT" -ErrorAction SilentlyContinue
if ($running) {
    Write-Host "Closing $($running.Count) Codex process(es)..."
    $running | Stop-Process -Force
    Start-Sleep -Seconds 2
}

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (-not $existing) {
    Write-Host "Registering scheduled task '$TaskName' (run once as highest)..."
    $action = New-ScheduledTaskAction -Execute $exe
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
    Register-ScheduledTask -TaskName $TaskName -Action $action -Principal $principal -ErrorAction Stop | Out-Null
}

Write-Host "Launching Codex as Administrator (silent, no UAC)..."
Start-ScheduledTask -TaskName $TaskName
Write-Host "Done. Verify in Codex: whoami /groups -> S-1-16-12288 (High)."
