# msix-admin-launcher

Windows MSIX apps cannot be elevated after launch, and a single-instance MSIX cannot
have two instances at different integrity levels. This repo collects "admin-elevation
launchers" for such apps: close the normal (Medium) instance, then relaunch with
admin rights so the process inherits the admin token.

## Two ways to elevate

- **A. `Start-Process -Verb RunAs`** (interactive): simple, but shows a UAC prompt
  unless the calling session is already admin. Good as a one-shot fallback.
- **B. Scheduled Task `RunLevel=HighestAvailable`** (silent, **no UAC**): a task
  registered once (needs admin once) is later fired by the SYSTEM task scheduler,
  which injects the pre-approved highest token. This elevates **silently** -- the
  recommended path for automation. Target the package's Win32 worker binary
  (`app\<App>.exe`), not the MSIX package AUMID (which goes through the broker and
  gets forced to Medium).

> Both methods must point at the real Win32 worker shipped inside the package
> (`app\Claude.exe` / `app\ChatGPT.exe` for `runFullTrust` apps). The MSIX package
> entry / `shell:appsFolder` / protocol activation goes through RuntimeBroker and
> is forced to Medium integrity -- it cannot be elevated.

## Included

| App | Launcher | Notes |
| --- | --- | --- |
| OpenAI Codex Desktop | [`codex-admin-launcher/`](codex-admin-launcher/) | `app\ChatGPT.exe` worker. `Launch-CodexElevated.ps1` (RunAs) and `Launch-CodexElevated-Task.ps1` (silent task). |
| Claude Desktop | [`claude-admin-launcher/`](claude-admin-launcher/) | `app\Claude.exe` worker, `runFullTrust`. Filters by `*\WindowsApps\Claude_*` so it does NOT kill the Claude Code CLI (`claude` also matches the win32 CLI). |

## Verify the child, not the parent

A parent/admin session showing `S-1-16-12288` does NOT prove the child is admin.
Measure the **child process token** directly:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/Verify-ChildIL.ps1 -Name claude
# expect: IL=HIGH(admin) (12288)
```

`Verify-ChildIL.ps1` reads `TokenIntegrityLevel` from each matching process via
P/Invoke -- the only correct confirmation that elevation actually worked.

## General principle
1. A running process cannot be elevated after the fact; a single-instance MSIX cannot
   coexist with a second instance at a different integrity level.
2. Close the normal instance, then relaunch with admin rights (RunAs or scheduled task).
3. Target the Win32 worker binary, not the MSIX package entry.
4. Accept a HIGH instance by reading the CHILD process token IL (`S-1-16-12288`),
   not by assuming the parent/admin session's level.

## Pitfalls
- Do NOT target an MSIX package entry when a Win32 worker binary exists -- it stays Medium.
- A parent admin session showing `S-1-16-12288` does NOT prove a child is admin. Measure the child.
- A `0x80070002` from a scheduled task means the task command path is wrong (use the
  package `app\<App>.exe`), not that "MSIX cannot be task-elevated".
- `.ps1` must be pure ASCII on zh-CN Windows (no-BOM UTF-8 is read as GBK and breaks parsing).
