# Codex Desktop 管理员提权启动器

让 **OpenAI Codex (MSIX 版) Desktop** 以管理员（高完整性 / `S-1-16-12288`）身份运行，
并在其内置终端里执行需要管理员权限的任务（写 `C:\Windows`、改 hosts、注册表等）。

---

## 为什么需要这个工具

Codex 是 **MSIX 打包应用**（`OpenAI.Codex`，入口 `app/ChatGPT.exe`，声明 `runFullTrust` +
`unvirtualizedResources`，协议 `codex://`，AUMID `OpenAI.Codex_2p2nqsd0c76g0!App`）。

两个 Windows 硬性限制决定了"给 Codex 提权"只能这样做：

1. **正在运行的进程不能事后提权** —— 无法给一个已经在跑的中完整性进程追发管理员令牌。
2. **单实例 MSIX 不能并存两个不同完整性的实例** —— 不关掉旧的普通实例，新激活会被
   "吸"到旧的普通实例上，提权失败。

所以唯一可靠的路径是：**关掉普通实例 → 以管理员身份重新拉起一个**。

---

## 用法（以后每次都这样）

1. 右键 `Launch-CodexElevated.ps1` → **“使用 PowerShell 运行”**（或任意已管理员/普通终端里执行它）。
2. 弹出 **UAC** 时点“是”。
3. 新的 Codex 即为管理员实例。

> 脚本会先 `Stop-Process` 关掉所有 `ChatGPT.exe`，再通过 `Start-Process -Verb RunAs`
> 以管理员拉起。路径用 `Get-AppxPackage` **动态解析**，MSIX 自动升级后无需改脚本。

### 自证是不是管理员（在 Codex 内置终端里跑）

```bat
whoami /groups
```

应当看到这一行：

```
Mandatory Label\High Mandatory Level  S-1-16-12288
```

或者用只有管理员能成功的动作验证：

```bat
echo admin-ok > C:\Windows\codex_test.txt
```

能写成功 = 管理员；普通 Codex 会报“拒绝访问”。验证完可删掉该文件。

---

## 已验证有效的原理

- 调用方本身已是管理员会话时，`Start-Process -Verb RunAs` **不会弹 UAC**（静默提权）；
  否则弹 UAC，用户批准后同样拿到管理员令牌。
- `runFullTrust` 让 MSIX 的 `ChatGPT.exe` 以**普通 Win32 进程**直接拉起（绕过
  `RuntimeBroker`/`ApplicationFrameHost` 这套 broker），因此**继承调用方令牌**。
- 实测证据链：新 Codex 主进程命令行是裸 `ChatGPT.exe`（无 broker 包装）、启动器父进程
  已退出（RunAs 派生后即退出），进程树表明它继承了提权令牌；其环境可写入 `C:\Windows`
  且 `whoami /groups` 输出 `S-1-16-12288`。

---

## 试过但无效的做法（踩坑记录，别再走）

| 方法 | 结果 |
|------|------|
| 任务计划程序裸起 `WindowsApps\...\ChatGPT.exe` | 失败 `0x80070002`（SYSTEM 上下文无法直起包内 exe） |
| 任务计划/explorer `shell:appsFolder\<AUMID>` | 走 broker，激活出的 Codex 是中完整性（不提权） |
| `IApplicationActivationManager` COM 激活 | 本机 PowerShell 屏蔽 `.NET 编译(Add-Type)`；免编译 `InvokeMember` 又卡 COM `[out]` 参数 |
| `Start-Process codex://` 协议 | 经 broker 激活，中完整性；且单实例时只是聚焦已有实例，不新建 |

> 注：传统 win32 应用（如 Claude Code 的 `claude.exe`）可以直接建 `RunLevel=HIGHEST`
> 的计划任务免 UAC 启动；MSIX 应用做不到，必须走上面的 RunAs 交互路线。

---

## 环境要求

- Windows 10/11 桌面版，当前用户属于 **Administrators** 组。
- 已安装 OpenAI Codex (MSIX)。
- 执行脚本的会话建议本身以管理员运行（这样 RunAs 不弹 UAC，全程无感）；
  若只是普通会话，UAC 仍会弹一次让你批准。

---

## 文件

- `Launch-CodexElevated.ps1` —— 一键关普通实例 + 管理员重拉 Codex。
- `README.md` —— 本说明。
