# Codex Desktop 管理员提权启动器

让 **OpenAI Codex (MSIX 版) Desktop** 能执行需要管理员权限的操作（写
`C:\Windows\System32\drivers\etc\hosts`、改系统目录、注册表等）。

---

## 重要事实（实测，2026-08-18）

Codex 的 MSIX 入口 `app\ChatGPT.exe` 会被 **AAM / RuntimeBroker 强制压成 Medium
完整性（S-1-16-8192）**——无论是 `Start-Process -Verb RunAs` 还是
`RunLevel=Highest` 计划任务，都**无法**把 ChatGPT.exe 主进程提到 High。这与
Claude（`app\Claude.exe` 是可直接拉起的 win32 worker）不同：Codex 的主 exe 仍受
broker 接管。实测两个进程树里 ChatGPT.exe 全部 MEDIUM / LOW，无一 HIGH。

所以"给 Codex 管理员权限"**不是提主进程**，而是：让 Codex 用其**内置 elevated
sandbox** 去执行需要特权的操作。Codex 会在需要时派生一个**管理员（High）的
command-runner 子进程**（`.codex\.sandbox-bin\codex-command-runner-*.exe`）来完成
写 hosts 等动作。前提是在 `config.toml` 里配置：

```toml
[windows]
sandbox = "elevated"
sandbox_mode = "danger-full-access"   # 或用更细的 allow 规则
```

只要这一项打开，Codex 在普通（Medium）主进程下，也能**自主**以管理员子进程写
hosts —— 已用独立 HIGH 进程实证 `Add-Content` 到 hosts 成功。

---

## 怎么启动（零 UAC 弹窗，推荐）

`Launch-CodexElevated-Task.ps1` 注册并触发 `CodexElevated` 计划任务：

```powershell
# 首次（管理员终端）注册任务：
powershell -ExecutionPolicy Bypass -File Launch-CodexElevated-Task.ps1
# 之后每次（普通终端即可，无弹窗）：
powershell -ExecutionPolicy Bypass -File Launch-CodexElevated-Task.ps1
# 或： schtasks /run /tn "CodexElevated"
```

任务只是"以最高令牌拉起 Codex"（不弹 UAC）。Codex 主进程仍是 Medium，但其
elevated sandbox 会按需派生管理员子进程干活。

> 若想主进程也 High，只能寄望 Codex 未来改用可直接拉起的 win32 worker；当前的
> `app\ChatGPT.exe` 做不到。不要误以为任务=主进程管理员。

---

## 验证"Codex 能自主写 hosts"（正确做法）

在 Codex 会话里直接说"编辑 hosts，加一行测试"。若 `sandbox="elevated"` 已开，
Codex 会用管理员 command-runner 写入，无需你点 UAC。

独立实证（证明 HIGH 进程能写 hosts，即 Codex elevated sandbox 依赖的机制）：

```powershell
$test = "# t"; Add-Content C:\Windows\System32\drivers\etc\hosts -Value $test
# 成功即 HIGH 写 host 可行；测完删掉该行
```

通用子进程 IL 检查：`..\scripts\Verify-ChildIL.ps1 -Name ChatGPT`（会显示 MEDIUM，
这是预期——主进程本就 Medium）。

---

## 踩坑记录

| 项 | 结论 |
|----|------|
| 计划任务 RunLevel=Highest 拉 Codex | 主进程仍 Medium（broker 强制），任务本身无错、零弹窗，但**不**等于主进程管理员 |
| Start-Process -Verb RunAs 拉 Codex | 已管理员会话下静默，但主进程仍 Medium |
| Codex 写 hosts / 系统目录 | 靠 `[windows] sandbox="elevated"` 派生的管理员 command-runner，非主进程令牌 |
| 任务命令 0x80070002 | 任务命令路径写错才会；指向 `app\ChatGPT.exe` 可正常拉起 |

---

## 文件

- `Launch-CodexElevated.ps1` —— RunAs 交互路线（弹一次 UAC，主进程仍 Medium）。
- `Launch-CodexElevated-Task.ps1` —— 计划任务路线（零弹窗拉起 Codex）。
- （上级）`scripts/Verify-ChildIL.ps1` —— 子进程 IL 检查（注意 Codex 主进程预期 Medium）。
