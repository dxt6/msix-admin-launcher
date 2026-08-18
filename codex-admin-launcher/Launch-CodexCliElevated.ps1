<#
.SYNOPSIS
    Launch the WIN32 Codex CLI as Administrator (HIGH integrity) via a
    pre-authorized Scheduled Task -- this is the ONLY Codex flavor that can
    actually be elevated, and therefore the only one whose elevated sandbox can
    write protected files like C:\Windows\System32\drivers\etc\hosts.
.DESCRIPTION
    The MSIX Desktop (app\ChatGPT.exe) is forced to MEDIUM by AAM/RuntimeBroker
    and CANNOT be elevated -- its elevated sandbox falls back to read-only ACLs.
    The win32 CLI (under %LOCALAPPDATA%\OpenAI\Codex\bin\<hash>\codex.exe) is a
    normal PE, so RunLevel=Highest makes the MAIN process HIGH, and Codex's
    elevated sandbox then spawns admin command-runner children that CAN write hosts.
    Verified: the CLI launched this way shows IL=S-1-16-12288 (High).
    Keep this file pure ASCII.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File Launch-CodexCliElevated.ps1
#>
[CmdletBinding()]
param(
    [string]$TaskName = "CodexCliElevated"
)

$ErrorActionPreference = "Stop"
$cli = Get-ChildItem "$env:LOCALAPPDATA\OpenAI\Codex\bin" -Recurse -Filter "codex.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $cli) { throw "win32 codex.exe not found under $env:LOCALAPPDATA\OpenAI\Codex\bin" }
$exe = $cli.FullName

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (-not $existing) {
    Write-Host "Registering scheduled task '$TaskName' (HIGH, no UAC)..."
    $action = New-ScheduledTaskAction -Execute $exe
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
    Register-ScheduledTask -TaskName $TaskName -Action $action -Principal $principal -ErrorAction Stop | Out-Null
}

Write-Host "Launching win32 Codex CLI as Administrator (HIGH). Its elevated sandbox can write hosts."
Start-ScheduledTask -TaskName $TaskName
