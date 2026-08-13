<#
.SYNOPSIS
    Restart OpenAI Codex (MSIX) Desktop as Administrator.
.DESCRIPTION
    Codex is an MSIX app. A running process cannot be elevated after the fact,
    and a single-instance MSIX cannot have two instances at different integrity
    levels. So we close the normal instance, then relaunch with "Run as admin".
    Codex declares runFullTrust, so launching the exe directly bypasses the
    RuntimeBroker and inherits the caller's admin token.
    NOTE: keep this file pure ASCII. On zh-CN Windows, PowerShell reads .ps1 as
    the system ANSI codepage; Chinese text without a BOM gets mangled and the
    script fails to parse. All Chinese docs live in README.md.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# Resolve Codex install path dynamically (survives MSIX version upgrades)
$pkg = Get-AppxPackage -Name "OpenAI.Codex" -ErrorAction Stop
if (-not $pkg) { throw "OpenAI.Codex package not found. Is Codex installed?" }
$exe = Join-Path $pkg.InstallLocation "app\ChatGPT.exe"
if (-not (Test-Path $exe)) { throw "Codex entry point not found: $exe" }

# Close any existing Codex processes (normal / medium-integrity instances)
$running = Get-Process -Name "ChatGPT" -ErrorAction SilentlyContinue
if ($running) {
    Write-Host "Closing $($running.Count) Codex process(es)..."
    $running | Stop-Process -Force
    Start-Sleep -Seconds 2
}

# Relaunch as Administrator (UAC prompt appears; approve to get admin token)
Write-Host "Launching Codex as Administrator..."
Start-Process -FilePath $exe -Verb RunAs

Write-Host "Done. If UAC was approved, the new Codex is an admin instance."
Write-Host "Verify: in Codex terminal run 'whoami /groups' and look for S-1-16-12288 (High)."
