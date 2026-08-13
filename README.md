# msix-admin-launcher

Windows MSIX apps cannot be elevated after launch, and a single-instance MSIX cannot
have two instances at different integrity levels. This repo collects "admin-elevation
launchers" for such apps: close the normal (Medium) instance, then relaunch with `RunAs`
so the process inherits the admin token (for plain Win32 apps) or is launched directly
to bypass the RuntimeBroker (for `runFullTrust` MSIX apps).

## Included

| App | Launcher | Notes |
| --- | --- | --- |
| OpenAI Codex CLI | [`codex-admin-launcher/`](codex-admin-launcher/) | **Use the Win32 `codex.exe`, NOT the MSIX `ChatGPT.exe`** -- the MSIX shell is forced to Medium by AAM and cannot be elevated. See its README. |
| Claude Desktop | [`claude-admin-launcher/`](claude-admin-launcher/) | MSIX app with `runFullTrust`. Note `claude` also matches the Claude Code CLI (win32); the launcher filters by path. |

## General principle
1. A running process cannot be elevated after the fact; a single-instance MSIX cannot
   coexist with a second instance at a different integrity level.
2. The working move: close the normal instance, then `Start-Process -FilePath <exe> -Verb RunAs`.
3. For a plain Win32 PE, RunAs elevates successfully -> HIGH integrity. For an MSIX app
   launched via its package entry, AAM/RuntimeBroker forces Medium and RunAs has no effect;
   the real worker binary is usually a Win32 PE shipped alongside the package.
4. Accept a HIGH instance by reading the CHILD process token IL directly
   (`S-1-16-12288`), not by assuming the parent/admin session's level.

## How a launcher was verified (Codex)
- Relaunch Win32 `codex.exe` with RunAs; read its process token -> `IL=12288 (High)`.
- Impersonate that HIGH token and write `C:\Windows\System32\drivers\etc\hosts` -> success,
  then restored. So Codex (admin) can edit the protected hosts file on its own.

## Pitfalls
- Do NOT target an MSIX package exe when a Win32 worker binary exists -- RunAs won't elevate it.
- A parent admin session showing `S-1-16-12288` does NOT prove a child is admin. Measure the child.
- `CreateProcessWithTokenW`/`CreateProcessAsUserW` from a non-interactive window station are
  blocked by DACL (error 5), even with SeDebug/SeImpersonate. Use `-Verb RunAs` on a Win32 PE.
- `.ps1` must be pure ASCII on zh-CN Windows (no-BOM UTF-8 is read as GBK and breaks parsing).
