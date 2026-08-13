# msix-admin-launcher

Windows 上 **MSIX 应用无法在启动后提权**，且单实例 MSIX 不能同存两个不同完整性级别的实例。
本仓库收集这类应用的「管理员提权启动器」：先关掉普通的 Medium 完整性实例，再以 `RunAs` 重拉，
利用应用声明的 `runFullTrust` 绕过 RuntimeBroker、继承管理员令牌，从而得到 High（管理员）实例。

## 已收录

| 应用 | 启动器 | 说明 |
| --- | --- | --- |
| OpenAI Codex Desktop | [`codex-admin-launcher/`](codex-admin-launcher/) | MSIX 应用，runFullTrust |
| Claude Desktop | [`claude-admin-launcher/`](claude-admin-launcher/) | MSIX 应用，runFullTrust。**注意** `claude` 进程名同时匹配 Desktop 与 Claude Code CLI，关进程已按路径过滤 |

## 通用原理

1. 运行中进程不能事后提权；单实例 MSIX 不能并存两个实例。
2. 做法：关普通实例 → `Start-Process -FilePath <exe> -Verb RunAs`。
3. 应用声明 `runFullTrust` 时，直接启动 exe 绕过 RuntimeBroker，继承调用方（管理员）令牌。
4. 验收：在应用终端跑 `whoami /groups`，看到 `S-1-16-12288 (High)` 即管理员；即可写受保护文件（如系统 hosts）。

## 通用坑

- `.ps1` 必须**纯 ASCII**：zh-CN 下 PowerShell 按 ANSI(GBK) 读无 BOM 的 UTF-8，中文乱码会让整脚本解析失败。中文说明放 README。
- 关进程要按**路径过滤**，避免误杀同名但不同的进程（如 Claude Desktop vs Claude Code CLI）。
- `RunAs` 在已管理员会话里静默通过，不弹 UAC。

> 各启动器的详细用法、验收与踩坑见对应子文件夹的 README。
