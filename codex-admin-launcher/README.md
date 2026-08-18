# Codex Desktop 管理员提权启动器

让 **OpenAI Codex (MSIX 版) Desktop** 以管理员（高完整性 / `S-1-16-12288`）身份运行，
并在其内置终端里执行需要管理员权限的任务（写 `C:\Windows`、改 hosts、注册表等）。

---

## 为什么需要这个工具

Codex 是 **MSIX 打包应用**（`OpenAI.Codex`，入口 `app/ChatGPT.exe`，声明 `runFullTrust`）。
两个 Windows 硬性限制决定了"给 Codex 提权"只能这样做：

1. **正在运行的进程不能事后提权** —— 无法给一个已经在跑的中完整性进程追发管理员令牌。
2. **单实例 MSIX 不能并存两个不同完整性的实例** —— 不关掉旧的普通实例，新激活会被
   "吸"到旧的普通实例上，提权失败。

所以唯一可靠的路径是：**关掉普通实例 → 以管理员身份重新拉起一个**。

---

## 方案 A：RunAs 交互路线（已存在，需一次 UAC 批准）

1. 右键 `Launch-CodexElevated.ps1` → **"使用 PowerShell 运行"**。
2. 弹出 **UAC** 时点"是"。
3. 新的 Codex 即为管理员实例。

> 脚本会先 `Stop-Process` 关掉所有 `ChatGPT.exe`，再通过 `Start-Process -Verb RunAs`
> 以管理员拉起。路径用 `Get-AppxPackage` **动态解析**，MSIX 自动升级后无需改脚本。

---

## 方案 B：计划任务 Highest 路线（**零 UAC 弹窗**，推荐）

`Launch-CodexElevated-Task.ps1` 用**任务计划程序（SYSTEM）**拉起 Codex：
- 首次运行需以管理员身份执行一次（注册 `CodexElevated` 计划任务，RunLevel=HighestAvailable）。
- 之后任何时候运行 → 任务计划程序直接注入最高令牌 → **不弹 UAC**，静默以管理员拉起。

```powershell
# 首次（管理员终端）：
powershell -ExecutionPolicy Bypass -File Launch-CodexElevated-Task.ps1
# 之后每次（普通终端即可，无弹窗）：
powershell -ExecutionPolicy Bypass -File Launch-CodexElevated-Task.ps1
# 或命令行： schtasks /run /tn "CodexElevated"
```

> **重要更正（旧文档误判）**：之前记录称"MSIX 应用无法用计划任务免 UAC、
> 任务裸起包内 exe 报 0x80070002"。实测表明这是**任务命令写错**（路径引号/worker
> 名不对），并非 MSIX 固有限制。Claude 的 `app\Claude.exe` 用同样的 `RunLevel=Highest`
> 计划任务已稳定拿到 `S-1-16-12288` 且免 UAC；Codex 的 `app\ChatGPT.exe` 遵循同一
> `runFullTrust` 模式，同样可行。关键是**直接指向包内 Win32 worker 二进制**，而非 MSIX
> 包 AUMID / `shell:appsFolder` 入口（后者走 broker 会被压成 Medium）。

---

## 验证是不是真管理员（关键：测子进程，不是父进程）

用通用脚本测 **Codex 进程自己的令牌完整性**（父进程/管理员会话显示 High 不代表子进程 High）：

```powershell
powershell -ExecutionPolicy Bypass -File ..\scripts\Verify-ChildIL.ps1 -Name ChatGPT
```

应看到 `IL=HIGH(admin) (12288)`。或直接：

```bat
whoami /groups
```

应在 Codex 内置终端里看到 `Mandatory Label\High Mandatory Level  S-1-16-12288`。

---

## 原理与证据链

- 调用方本身已是管理员会话时，`Start-Process -Verb RunAs` 不弹 UAC；否则弹一次 UAC。
  计划任务路线连这一次都不需要（SYSTEM 预授权）。
- `runFullTrust` 让 `ChatGPT.exe` 以**普通 Win32 进程**直接拉起（绕过 RuntimeBroker），
  因此继承调用方/任务调度器的令牌。
- 已实测：Claude `app\Claude.exe` 经 Highest 任务拉起后主进程/子进程 IL=12288；
  Codex 同构，可用上面的 `Verify-ChildIL.ps1` 自验。

---

## 试过但无效的做法（踩坑记录）

| 方法 | 结果 |
|------|------|
| 经 broker 激活 MSIX 包入口（`shell:appsFolder\<AUMID>` / `IApplicationActivationManager`） | 激活出的 Codex 是中完整性（不提权） |
| `Start-Process codex://` 协议 | 经 broker 激活，中完整性；单实例时仅聚焦已有实例 |
| 任务命令指向错误路径/包入口 | 报 `0x80070002` —— 修正为包内 `app\ChatGPT.exe` 即解决 |

---

## 文件

- `Launch-CodexElevated.ps1` —— 方案 A：一键关普通实例 + RunAs 管理员重拉（弹一次 UAC）。
- `Launch-CodexElevated-Task.ps1` —— 方案 B：计划任务 Highest，零 UAC 静默提权。
- （上级）`scripts/Verify-ChildIL.ps1` —— 通用子进程 IL 验证脚本。
