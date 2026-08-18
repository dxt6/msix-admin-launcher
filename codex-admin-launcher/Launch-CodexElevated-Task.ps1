<#
.SYNOPSIS
    Launch OpenAI Codex (MSIX) Desktop silently (no UAC) via a pre-authorized
    Scheduled Task.
.DESCRIPTION
    IMPORTANT (verified 2026-08-18): Codex's MSIX entry app\ChatGPT.exe is forced
    to MEDIUM integrity by AAM/RuntimeBroker -- neither RunAs nor a Highest
    scheduled task can raise the MAIN process to High. This task therefore does
    NOT make ChatGPT.exe admin. Instead it launches Codex silently (no UAC), and
    admin file writes (hosts, system dirs) are performed by Codex's BUILT-IN
    elevated sandbox: configure [windows] sandbox = "elevated" in config.toml, and
    Codex spawns an admin command-runner child for privileged ops.
    Path resolved dynamically via Get-AppxPackage so MSIX upgrades need no edit.
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
    Write-Host "Registering scheduled task '$TaskName' (no-UAC launch)..."
    $action = New-ScheduledTaskAction -Execute $exe
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
    Register-ScheduledTask -TaskName $TaskName -Action $action -Principal $principal -ErrorAction Stop | Out-Null
}

Write-Host "Launching Codex (silent, no UAC). Admin writes use Codex elevated sandbox."
Start-ScheduledTask -TaskName $TaskName
