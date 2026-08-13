# Claude Desktop 管理员提权启动器

## 用途
Claude Desktop 是 MSIX 应用，运行中的进程**无法事后提权**，且单实例 MSIX 不能在同一时刻存在两个不同完整性级别的实例。
做法：先关掉普通（Medium 完整性）的 Claude Desktop，再以“管理员”重拉。Claude 声明了 `runFullTrust`，
直接启动 exe 会绕过 RuntimeBroker，继承调用方（已是管理员）的令牌 → 新实例即 High（管理员）完整性。

## 用法
```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\dongxiaotong\Desktop\大模型相关技术\claude-admin-launcher\Launch-ClaudeElevated.ps1"
```
在已管理员的会话里会静默（不弹 UAC）以管理员重拉 Claude Desktop；普通会话里会弹 UAC，批准后即管理员实例。

## 关于 Claude Code CLI（重要）
任务管理器里名为 `claude` 的进程有两类，别混淆：
1. **Claude Desktop（MSIX）**：路径在 `C:\Program Files\WindowsApps\Claude_*`。本启动器只关/只拉这一类。
2. **Claude Code CLI（win32）**：路径在 `C:\Users\dongxiaotong\AppData\Local\Claude-3p\claude-code\*\claude.exe`。
   这才是真正在终端里“自主编辑文件”的 agent。**它不需要 MSIX 提权**，直接以管理员启动即可：
   ```powershell
   # 方式 A：在“以管理员运行”的终端里直接启动 claude
   # 方式 B：对任意已登录会话提权
   Start-Process -FilePath "$env:LOCALAPPDATA\Claude-3p\claude-code\2.1.227\claude.exe" -Verb RunAs
   ```
   启动后在其会话里跑 `whoami /groups`，出现 `S-1-16-12288 (High)` 即管理员，就能写 hosts。

## 自验（你自己也能确认）
- 在 Claude（Desktop 或 CLI）的终端里跑 `whoami /groups`，看到 `S-1-16-12288 (High)` 就是管理员。
- 让 Claude 编辑 `C:\Windows\System32\drivers\etc\hosts`，应成功（需要管理员令牌）。

## 本机验收（已做）
以管理员令牌运行 `whoami /groups` 得到 `S-1-16-12288`；对 hosts 做“加测试行 → 确认写入 → 还原”成功，
证明管理员可写 hosts。Claude 以同样 RunAs 机制启动、继承同一管理员令牌，因此能自主编辑 hosts。

## 踩坑记录
- `.ps1` 必须纯 ASCII：zh-CN 下 PowerShell 按系统 ANSI(GBK) 读取无 BOM 的 UTF-8，中文乱码会让整脚本解析失败。
- `claude` 进程名同时匹配 Desktop 与 CLI，关进程时必须按路径（`*\WindowsApps\Claude_*`）过滤，否则会误杀正在用的 Claude Code CLI。
- 本机 HTTP 代理 `127.0.0.1:7897`；git 推送走 Bash 工具 + 代理（PowerShell 工具里 `git push` 会报 128）。
