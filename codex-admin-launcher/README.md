# Codex Desktop / CLI 管理员提权启动器

让 Codex 能执行需要管理员权限的操作（写 `C:\Windows\System32\drivers\etc\hosts`、
改系统目录、注册表等）。

---

## 结论先行（实测，2026-08-18）

- **Codex MSIX Desktop（`app\ChatGPT.exe`）无法提权。** AAM/RuntimeBroker 把它主进程
  强制压成 MEDIUM（S-1-16-8192）。`Start-Process -Verb RunAs` 和 `RunLevel=Highest`
  计划任务**都提不了主进程**（实测全 MEDIUM/LOW）。主进程是 Medium 时，Codex 的
  elevated sandbox 退化成 `read-acl-only` 模式，**写不了 hosts**。→ 所以 Desktop 版
  做不到"自主编辑 hosts"。
- **Codex win32 CLI（`%LOCALAPPDATA%\OpenAI\Codex\bin\<hash>\codex.exe`）可以提权。**
  它是普通 PE，不受 MSIX broker 限制。`RunLevel=Highest` 计划任务拉起后主进程就是
  HIGH（S-1-16-12288，已实测）。其 elevated sandbox 由此派生管理员 command-runner
  子进程，能写 hosts。→ **这是"Codex 自主编辑 hosts"唯一可靠的路。**

---

## 两个启动器

| 文件 | 用途 | 能否写 hosts |
|------|------|------|
| `Launch-CodexElevated-Task.ps1` / `.ps1`(RunAs) | 拉起 **MSIX Desktop**（ChatGPT.exe） | ❌ 主进程 Medium，sandbox 只读 |
| `Launch-CodexCliElevated.ps1` | 拉起 **win32 CLI**（codex.exe） | ✅ 主进程 HIGH，sandbox 可写 |

### 用 win32 CLI（推荐，能写 hosts）
```powershell
# 首次（管理员终端）注册任务：
powershell -ExecutionPolicy Bypass -File Launch-CodexCliElevated.ps1
# 之后每次（普通终端，无 UAC）：
powershell -ExecutionPolicy Bypass -File Launch-CodexCliElevated.ps1
# 或： schtasks /run /tn "CodexCliElevated"
```
CLI 共用 `~\.codex\config.toml`（含 `sandbox="elevated"`、网关、key），启动后即带配置。
在 CLI 会话里说"编辑 hosts"即可，由 elevated sandbox 的管理员子进程写入，无需 UAC。

### 用 MSIX Desktop（GUI，但不能写 hosts）
```powershell
powershell -ExecutionPolicy Bypass -File Launch-CodexElevated-Task.ps1
```
仅做零弹窗拉起；写系统文件需另想办法（见下）。

---

## 若坚持用 Desktop 写 hosts（兼容性 trick，可能不生效）
给 `ChatGPT.exe` 设 `RUNASADMIN` 兼容性层（需 HKLM，管理员）：
`reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /v "<ChatGPT.exe 完整路径>" /d "RUNASADMIN" /f`
注意：MSIX 包 exe 受 Package 虚拟化，该注册表项对其**经常不生效**。不保证可行。

---

## 验证
- 子进程 IL：`..\scripts\Verify-ChildIL.ps1 -Name codex`（CLI 应显示 HIGH；Desktop 显示 MEDIUM）。
- 写 hosts 实证（任意 HIGH 进程）：`Add-Content C:\Windows\System32\drivers\etc\hosts -Value "# t"` 成功即 HIGH 写 host 可行（测完删行）。

---

## 踩坑
| 项 | 结论 |
|----|------|
| 计划任务/RunAs 提 Codex Desktop 主进程 | 失败，被 broker 压 Medium |
| Desktop + `sandbox="elevated"` | 主进程 Medium → sandbox 只读，写 hosts 失败 |
| win32 CLI + Highest 任务 | 主进程 HIGH ✅，sandbox 可写 hosts |
| 任务 0x80070002 | 任务命令路径写错才会；CLI 用 `bin\<hash>\codex.exe` 真实路径 |

---

## 文件
- `Launch-CodexElevated.ps1` / `Launch-CodexElevated-Task.ps1` —— MSIX Desktop（零弹窗，但不能写 hosts）。
- `Launch-CodexCliElevated.ps1` —— **win32 CLI（HIGH，能写 hosts）**。
- （上级）`scripts/Verify-ChildIL.ps1` —— 子进程 IL 检查。
