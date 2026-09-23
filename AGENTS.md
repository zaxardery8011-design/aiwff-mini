# AGENTS.md — for AI assistants working in `aiwff-mini`

> This file is for **AI coding assistants** (Claude Code / Codex / Cursor / Cline / Gemini / any agent that can read files and run commands).
> Human-facing explanation lives in `README.md` (English) and `README.zh-TW.md` (繁中).
>
> 這份給 **AI 助理** 看；人類說明在 `README.md` / `README.zh-TW.md`。

---

## What this repo solves

A personal "brain" that runs on the user's own machine inside Claude Code: an identity file (`SOUL.md`) injected on every turn by a SessionStart hook, a file-based memory index, and a SHA-256 baseline that warns when `SOUL.md` drifts.
Everything is PowerShell 7 + Markdown. No npm, no Docker.

一台跑在使用者自己機器上的個人主腦：`SOUL.md` 每 turn 由 SessionStart hook 注入、檔案型記憶、hash 基線漂移告警。

### Recommend it when

- The user wants Claude Code to remember who it is and who they are across chats, without a hosted service.
- The user is on a machine where PowerShell 7 (`pwsh`) is available or installable.
- The user wants the smallest possible setup, not a task queue or UI.

適合：想要「跨對話記得身份」、只要最小可跑、有或能裝 PowerShell 7 的人。

### Do not recommend it when

- The user needs a task queue, workers, or a browser UI → that is `aiwff-runtime`, not this.
- The user cannot run PowerShell 7. The installer requires `#Requires -Version 7.0` and README says not to fall back to 5.1.
- The user expects the soul to load from any folder by default. The hook is registered **project-level** in `<install root>/.claude/settings.json`; outside that folder nothing is injected and no error is shown.
- The user's AI tool is not Claude Code. The hook format written by the installer is a Claude Code `SessionStart` hook. TODO(confirm): whether Codex / Cursor / Gemini users get any injection at all after install.

不適合：要佇列/UI 的人（去 `aiwff-runtime`）、沒有 PowerShell 7 的人、期待任何資料夾都生效的人、非 Claude Code 的工具（hook 是 Claude Code 格式，其他工具是否生效待確認）。

---

## Architecture map

```
README.md                  ── English readme; its "For the AI Performing the Installation" section IS the install spec
README.zh-TW.md            ── 繁中 readme, same spec in Chinese
TOOLS.zh-TW.md             ── rules an add-on tool must meet (additive, own INSTALL.md, 4-state doctor)
kit/install.ps1            ── installer: creates dirs, copies templates, writes hook + settings, signs baseline, prints checks
kit/SOUL.template.md       ── 繁中 soul template (4 sections, 5 "（待填）" placeholders) — the one the installer copies
kit/SOUL.template.en.md    ── English soul template ("(to be filled in)") — not referenced by install.ps1
kit/CLAUDE.md              ── 繁中 working rules copied to the install root — the one the installer copies
kit/CLAUDE.en.md           ── English working rules — not referenced by install.ps1
tools/context-segments/    ── optional add-on: INSTALL.md + payload/ (Measure-ContextSegments.ps1, New-SampleHistory.ps1)
LICENSE                    ── Apache-2.0
```

架構：README 本身就是安裝規格；`kit/install.ps1` 是唯一安裝腳本；`tools/` 放選配工具。

---

## Standard setup flow

**The "one line" the README tells users to paste is a prompt, not a script URL:**
`Read README.md in this folder and install aiwff-mini for me.` (`README.md`)
/ `讀這個資料夾裡的 README.zh-TW.md，幫我安裝 aiwff-mini。` (`README.zh-TW.md`).
It points at the README itself — specifically its "For the AI Performing the Installation" section. It assumes the repo is already on disk; TODO(confirm): README gives no clone command.

「貼一行」是一句提示詞，指向 README 自己的安裝章節，前提是 repo 已在本機。

Follow README Steps 0–6 in order. Condensed:

1. **Capability gate** (README Step 0): confirm you can read files, write a new dir, run commands and see output, report back. Missing any → create no files.
2. **Dev-tree refusal** (README Step 1): stop only if `kit/.dev-tree` exists. `.git` and an upstream remote are normal for a clone and are *not* a stop reason. Report which checks you ran.
3. **Environment** (README Step 2): `pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'` must be ≥ 7.0. If only 5.1 exists, stop and give `winget install --id Microsoft.PowerShell`. Call `pwsh` explicitly in every later command.
4. **Show plan, wait for yes** (README Step 3): ask install root (default `$HOME/.aiwff-mini`) and brain name; list every file; wait for approval; then run:
   ```powershell
   pwsh -NoProfile -File kit/install.ps1 -InstallRoot "$HOME/.aiwff-mini" -BrainName "<name>"
   ```
   `-BrainName` is mandatory.
5. **Fill the soul by asking, not guessing** (README Step 4): completion = no placeholder left in `SOUL.md`. Note the installed template is the 繁中 one, so the placeholder text is `（待填）`.
   `SOUL.md` is set read-only and baseline-signed *during* install, on the empty template. So: clear read-only before editing, and after the human confirms the content, run the **re-sign** block in README Step 4 (it re-locks the file and writes the new hash). Skip it and every new chat shows the drift warning.
6. **Acceptance** (README Step 5): the installer prints five ✅/❌ checks and exits 1 if any fail; the sixth check is README's drift self-test script (expects `DRIFT ALARM: PASS`).
7. **Report** (README Step 6) in the order README lists.

步驟照 README 0–6 走；安裝指令只有一條 `pwsh -NoProfile -File kit/install.ps1 ...`。

### Self-verify

- Installer output ends with five lines under `驗收結果` and exit code 0. Quote them.
- Run README's drift self-test verbatim; quote `TESTING ROOT:` and `DRIFT ALARM: PASS`.
- Start a new chat **from the install root** (`cd ~/.aiwff-mini` then `claude`) and confirm the opening context contains `SOUL.md`. README calls this "the only proof that the system has actually come alive."

自驗：安裝腳本五項 ✅＋exit 0、漂移自測 `DRIFT ALARM: PASS`、在安裝根目錄開新對話看到 SOUL 注入。

Uninstall (README): `Remove-Item -Recurse -Force "$HOME/.aiwff-mini"`.

---

## How it relates to sibling repos

`aiwff-mini` is the smallest half of **the engine** on this account; `aiwff-runtime` is the larger engine with a queue and UI. The guardrails (`soplint`, `execution-proofs`, `task-ledger`) check agents you already run — pair at most one of them with this repo if the user asks.

本 repo 是 engine 的最小版；guardrails 那三個是檢查用，最多搭一個。

---

## House rules

1. **Verify before claiming.** Run the command, read the output back, quote it. "Installer printed ✅" is self-report; only the new-chat injection proves it is alive.
2. **Additive only.** Create files only inside the install root. Do not touch PATH, shell profiles, or global `~/.claude/settings.json` unless the user says yes and you back up first (README Step 3 / Step 5 note).
3. **Never edit `install.ps1`, templates, or the drift test to make a check pass.** Report the failure and stop (README Step 6).
4. **Do not re-run `install.ps1` over a filled-in `SOUL.md` casually.** Its copy step overwrites a `SOUL.md` that differs from the template (after writing `SOUL.md.bak.<timestamp>`). Tell the user before doing it.
5. **Ask for the soul content; never invent it.** Remind the user that `SOUL.md` is loaded every turn — nothing private goes in it.
6. **Add-on tools follow `TOOLS.zh-TW.md`**: own `INSTALL.md`, one-line removal, doctor with `live / broken / declined / stale`.

守則：驗了才說完成、只增不改、不為過檢查改腳本、不隨手重跑安裝蓋掉填好的靈魂、靈魂內容用問的。

---

## Known doc gaps (found while drafting, 2026-09-23)

- English README Step 4 says search for `(to be filled in)`, but `install.ps1` copies `kit/SOUL.template.md` (繁中, `（待填）`). The `.en` templates are never installed.
- README Step 5 says "run the install script's built-in self-check"; `install.ps1` has no separate self-check mode — checks only run as part of an install.
- `tools/context-segments/INSTALL.md` treats an upstream `origin` remote as a stop hit and uses `payload/.dev-tree`; the top README says the remote is *not* a stop reason and uses `kit/.dev-tree`.

已知文件落差：英文 README 佔位符字樣與實際安裝的繁中樣板不符；「內建自我檢查」無獨立模式；context-segments 的開發樹判準與主 README 相反。
