# aiwff-mini

**A personal brain that runs on your own machine.** It has a soul, memory across chats, and guards that keep it from silently breaking its own identity.

This is not a chatbot wrapper or a prompt pack. It solves four concrete problems:

| Problem | How aiwff-mini handles it |
|---|---|
| Every new chat starts with amnesia | File-based memory, with an index and individual memory notes that survive across sessions |
| You keep having to explain who it is and who you are | `SOUL.md` is injected automatically on every turn |
| The AI may quietly rewrite its own settings | The soul file is read-only and hash-signed; drift triggers a warning |
| The AI says "done" when it has not actually done the work | The Kernel requires proof of effect, not proof of liveness; self-reported success only counts as self-reported success |

---

## Install

Paste this into your AI tool (Claude Code, Codex, Cursor, Cline, Gemini, or similar):

```
Read README.md in this folder and install aiwff-mini for me.
```

It will first check whether it can complete the installation, show you the files it plans to create, wait for your approval, and then run a self-check after installation.

**No npm, no Docker, and no documentation you have to read first.**

Requirement: PowerShell 7 or newer. If it is missing, the installer should stop and tell you instead of trying to push through.

---

## For the AI Performing the Installation

You are installing aiwff-mini for your human.

This installation is **additive only**: create only this tool's own files. Do not touch their other settings, do not edit their shell profile, and do not modify any existing files unless they explicitly allow it and you make a backup first.

### Step 0 - Capability Check First

**Do not start an installation you cannot finish.** Confirm that you can do all four:

1. Read files
2. Write files into a new directory
3. Run commands and see their output
4. Report the result back to the human

If any one is missing, stop here, state exactly what is missing, and **create no files at all**. A clean refusal is better than a half-installed system.

### Step 1 - Do Not Install Inside the Development Tree

**Never modify the author's own system.**

Check whether your current directory is this tool's source tree rather than someone else's copy. Run the checks you are allowed to run, in order:

1. Does the current directory contain `.git`, with a remote pointing to this project's upstream?
2. Does the current path contain fragments such as `docs/`, `dist-src/`, or `open_source_prep/`?
3. Does `kit/.dev-tree` exist?

**Report which checks you actually ran and which ones were outside your permissions.** "I ran checks 2 and 3; check 1 was outside my permission scope" is a correct answer. **Silently skipping a check and saying everything is fine is not.**

If any check matches, stop and explain. Do not install, and do not "helpfully" install somewhere else.

### Step 2 - Detect the Environment

Actually run the checks. Do not assume:

| Item | How to check | Requirement |
|---|---|---|
| PowerShell | `pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'` | 7.0 or newer |
| Home directory | `$HOME` | Must be writable |
| Package completeness | `kit/SOUL.template.md`, `kit/CLAUDE.md`, `kit/install.ps1` | All three must exist |

**If the machine has PowerShell 5.1 but not 7, stop and report it**, including this fix command: `winget install --id Microsoft.PowerShell`. Do not fall back to 5.1. This package has only been verified on PowerShell 7 or newer, and running quietly in an unverified environment is worse than not installing.

### Step 3 - Show the Plan, Wait for Approval, Then Act

Ask the user where to install it (default: `$HOME/.aiwff-mini/`) and what this brain should be called.

Always use this order:

1. **List** every file you are going to create, with its full path
2. **Show the list to the human**
3. **Wait for approval** - create nothing until they approve
4. **Run** `kit/install.ps1`, passing in the install path and the brain name as parameters

Rules while running:

- If the target directory already exists, **do not overwrite**. Back up every file that would be replaced as `<original-name>.bak.<timestamp>`, and say what you backed up
- Do not create anything outside the target directory
- Do not touch PATH or shell profiles in this step

### Step 4 - Help Them Fill In the Soul

`SOUL.md` is installed as an empty template. It has three sections to fill in: **Who I am / Who my human is / How we work together**.

**Do not fill it in and call the job done.** Ask questions:

- What should this brain mainly help you with?
- What tone should it use with you?
- When you say a certain phrase, what do you actually mean? This is the highest-value question.
- What may it decide on its own, and what must it ask you about first?

Organize the answers into the file, then **read it back for confirmation**. If any of the three sections still contains the placeholder, tell the human that this brain is not truly active yet.

Remind them: `SOUL.md` is loaded on every turn. **Do not put anything there that you do not want in the AI's context.**

### Step 5 - Acceptance Check

After the soul is filled in, run the install script's built-in self-check. All checks must pass:

1. Directory structure exists
2. `SOUL.md` is read-only
3. Baseline signature exists and matches the current hash of `SOUL.md`
4. SessionStart hook is configured
5. Memory index file exists

Then **start a new chat** and confirm that the beginning really includes the injected `SOUL.md` content. This is the only proof that the system has actually come alive.

### Step 6 - Report Back

Report in this order:

1. Which Step 1 checks you actually ran, and which ones were outside your permissions
2. The file list you showed before acting in Step 3
3. The result of each of the five acceptance checks in Step 5
4. Whether a new chat actually injected the soul; this is the most important item
5. Anything you guessed, bypassed, or could not verify

If any item fails, say it failed and stop. **Do not edit the script or template just to make the checks pass.** An honest failure is more useful than a secretly fixed success.

---

## What You Get After Installation

```
~/.aiwff-mini/
|-- SOUL.md          <- identity, read-only, loaded every turn
|-- CLAUDE.md        <- working rules
|-- memory/
|   `-- MEMORY.md    <- memory index
`-- .soul_baseline/  <- integrity signature
```

## Definition of Alive

It is only alive when all four are true:

1. It remembers things across chats
2. It knows who it is on every turn
3. It warns you when the soul changes
4. It verifies before saying "done"

## Uninstall

```powershell
Remove-Item -Recurse -Force "$HOME/.aiwff-mini"
```

It did not touch anything else, so there is nothing else to restore.

---

## Design Philosophy

**Lock only the lowest-level kernel. Leave everything above it open.**

The Kernel has only six rules: identity, integrity, evolution, consent chain, boundaries, and honesty. They live in `SOUL.md` and must not be changed. Everything else is yours to shape - what it should become, what it should help with, and how it should work.

Every extra rule you lock in also lowers the ceiling on what it can become.

---

*Traditional Chinese version: [README.zh-TW.md](README.zh-TW.md)*
