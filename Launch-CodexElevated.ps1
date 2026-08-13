<#
.SYNOPSIS
  以管理员身份重新启动 OpenAI Codex (MSIX 版) Desktop。
.DESCRIPTION
  Codex 是 MSIX 应用：正在运行的进程无法"事后提权"，且单实例 MSIX 不能同时存在
  两个不同完整性的实例。因此正确做法是——先关掉普通实例，再用 "Run as administrator"
  重新拉起。Codex 声明了 runFullTrust 能力，直接启动 exe 会绕过 RuntimeBroker，
  继承调用方（你批准 UAC 后的）管理员令牌。
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# 动态解析 Codex 安装路径：自动适配 MSIX 版本号升级，无需手动改路径
$pkg = Get-AppxPackage -Name "OpenAI.Codex" -ErrorAction Stop
if (-not $pkg) { throw "未找到 OpenAI.Codex 包，Codex 可能未安装。" }
$exe = Join-Path $pkg.InstallLocation "app\ChatGPT.exe"
if (-not (Test-Path $exe)) { throw "Codex 入口不存在: $exe" }

# 关掉所有现有 Codex 进程（普通/中完整性实例）
$running = Get-Process -Name "ChatGPT" -ErrorAction SilentlyContinue
if ($running) {
    Write-Host "正在关闭 $($running.Count) 个 Codex 进程..."
    $running | Stop-Process -Force
    Start-Sleep -Seconds 2
}

# 以管理员身份重新拉起（弹出 UAC，批准后即为管理员高完整性令牌）
Write-Host "正在以管理员身份启动 Codex..."
Start-Process -FilePath $exe -Verb RunAs

Write-Host "完成。若 UAC 已批准，新的 Codex 即为管理员实例。"
Write-Host "验证方法：在 Codex 终端运行  whoami /groups  应看到  S-1-16-12288 (High Mandatory Level)。"
