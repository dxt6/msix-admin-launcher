# Claude Desktop 管理员提权启动器

## 用途
Claude Desktop 是 MSIX 应用，运行中的进程**无法事后提权**，且单实例 MSIX 不能在同一时刻存在两个不同完整性级别的实例。
做法：先关掉普通（Medium 完整性）的 Claude Desktop，再以"管理员"重拉。Claude 声明了 `runFullTrust`，
直接启动 exe 会绕过 RuntimeBroker，继承调用方（已是管理员）的令牌 → 新实例即 High（管理员）完整性。

---

## 方案 A：RunAs 交互路线（已存在，需一次 UAC 批准）
```powershell
powershell -ExecutionPolicy Bypass -File Launch-ClaudeElevated.ps1
```
在已管理员会话里会静默（不弹 UAC）以管理员重拉；普通会话里会弹 UAC，批准后即管理员实例。

---

## 方案 B：计划任务 Highest 路线（**零 UAC 弹窗**，推荐）
`Launch-ClaudeElevated-Task.ps1` 用任务计划程序（SYSTEM）拉起 Claude：
- 首次以管理员运行注册 `ClaudeElevated` 任务（RunLevel=HighestAvailable）。
- 之后任何时候运行 → 静默以管理员拉起，**不弹 UAC**。

```powershell
# 首次（管理员终端）：
powershell -ExecutionPolicy Bypass -File Launch-ClaudeElevated-Task.ps1
# 之后每次（普通终端即可）：
powershell -ExecutionPolicy Bypass -File Launch-ClaudeElevated-Task.ps1
# 或： schtasks /run /tn "ClaudeElevated"
```

---

## 关于 Claude Code CLI（重要）
任务管理器里名为 `claude` 的进程有两类，别混淆：
1. **Claude Desktop（MSIX）**：路径在 `C:\Program Files\WindowsApps\Claude_*`。本启动器只关/只拉这一类。
2. **Claude Code CLI（win32）**：路径在 `%LOCALAPPDATA%\Claude-3p\claude-code\*\claude.exe`。
   这是真正在终端里"自主编辑文件"的 agent。它不需要 MSIX 提权，直接以管理员启动即可：
   ```powershell
   Start-Process -FilePath "$env:LOCALAPPDATA\Claude-3p\claude-code\*\claude.exe" -Verb RunAs
   ```
   启动后在其会话里跑 `whoami /groups`，出现 `S-1-16-12288 (High)` 即管理员。

---

## 验证（测子进程，不要只信父进程）
```powershell
powershell -ExecutionPolicy Bypass -File ..\scripts\Verify-ChildIL.ps1 -Name claude
```
应看到 `IL=HIGH(admin) (12288)`（MSIX Desktop 进程路径含 `WindowsApps\Claude_*`）。
或在 Claude 终端里 `whoami /groups` 看到 `S-1-16-12288 (High)`；让其编辑
`C:\Windows\System32\drivers\etc\hosts` 应成功（需管理员令牌）。

---

## 踩坑记录
- `.ps1` 必须纯 ASCII：zh-CN 下 PowerShell 按系统 ANSI(GBK) 读取无 BOM 的 UTF-8，中文乱码会让整脚本解析失败。
- `claude` 进程名同时匹配 Desktop 与 CLI，关进程时必须按路径（`*\WindowsApps\Claude_*`）过滤，否则会误杀正在用的 Claude Code CLI。
- 任务计划方案若报 `0x80070002`，通常是任务命令路径/引号写错，确认指向包内 `app\Claude.exe` 而非 MSIX 包入口。
