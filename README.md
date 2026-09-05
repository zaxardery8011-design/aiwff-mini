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

Check whether your current directory is this tool's own source tree, not someone else's copy.

**There is only one stop condition**: the marker file `kit/.dev-tree` exists. It appears only in the author's working directory and is not committed to the repo, so a copy you got from `git clone` will not have it.

The other checks are supporting signals. **On their own, they are not a reason to stop**, but you should still report them:

- Does the current path contain fragments such as `docs/`, `dist-src/`, or `open_source_prep/`?
- Does the git remote point to this project's upstream?
- Does the current directory have uncommitted local changes?

> Warning: **A `git clone` copy normally has `.git`, and its remote normally points to this project's upstream. That is normal and does not count as a match.** Every legitimate copy looks like that; using it as a stop condition would block every user.

**Report which checks you actually ran and which ones were outside your permissions.** "I ran checks 2 and 3; check 1 was outside my permission scope" is a correct answer. **Silently skipping a check and saying everything is fine is not.**

If the marker file matches, stop and explain. Do not install, and do not "helpfully" install somewhere else.

### Step 2 - Detect the Environment

Actually run the checks. Do not assume:

| Item | How to check | Requirement |
|---|---|---|
| PowerShell | `pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'` | 7.0 or newer |
| Home directory | `$HOME` | Must be writable |
| Package completeness | `kit/SOUL.template.md`, `kit/CLAUDE.md`, `kit/install.ps1` | All three must exist |

**If the machine has PowerShell 5.1 but not 7, stop and report it**, including this fix command: `winget install --id Microsoft.PowerShell`. Do not fall back to 5.1. This package has only been verified on PowerShell 7 or newer, and running quietly in an unverified environment is worse than not installing.

> Warning: **On many machines, `powershell` is 5.1 and `pwsh` is 7, and both may be installed side by side.** Confirming that 7 exists does not prove the next command will run under 7. Every later command must explicitly call **`pwsh`**, not the system default `powershell`, because the installer uses calls whose behavior differs between the two.

### Step 3 - Show the Plan, Wait for Approval, Then Act

Ask the user where to install it (default: `$HOME/.aiwff-mini/`) and what this brain should be called.

Always use this order:

1. **List** every file you are going to create, with its full path
2. **Show the list to the human**
3. **Wait for approval** - create nothing until they approve
4. **Run** the install script with the full command below. Type the parameter names exactly; `-BrainName` is required, and omitting it can leave a non-interactive run stuck waiting for input:

   ```powershell
   pwsh -NoProfile -File kit/install.ps1 -InstallRoot "$HOME/.aiwff-mini" -BrainName "your brain's name"
   ```

Rules while running:

- If the target directory already exists, **do not overwrite**. Back up every file that would be replaced as `<original-name>.bak.<timestamp>`, and say what you backed up
- Do not create anything outside the target directory
- Do not touch PATH or shell profiles in this step

### Step 4 - Help Them Fill In the Soul

`SOUL.md` is installed as an empty template. It has **four sections and five placeholders** to fill in: **Who I am / Who my human is, including what to call them / How we work together / Soul anchor**. The "what to call them" placeholder is folded into the second section.

**Do not fill it in and call the job done.** Ask questions:

- What should this brain mainly help you with?
- What tone should it use with you?
- What should it call you? "Boss", "Alex", or any other name is fine; this word is loaded on every turn.
- When you say a certain phrase, what do you actually mean? This is the highest-value question.
- What may it decide on its own, and what must it ask you about first?
- In one sentence, what is the reason this brain exists? Put this in the soul anchor; it will see it on every turn.

Organize the answers into the file, then **read it back for confirmation**.

**Completion condition**: search the whole `SOUL.md` file. It is only active when there are no remaining `(to be filled in)` placeholders. If any remain, tell the human which section is unfinished and what that missing section affects.

Remind them: `SOUL.md` is loaded on every turn. **Do not put anything there that you do not want in the AI's context.**

### Step 5 - Acceptance Check

After the soul is filled in, run the install script's built-in self-check, then run the drift self-test below. All six checks must pass:

1. Directory structure exists
2. `SOUL.md` is read-only
3. Baseline signature exists and matches the current hash of `SOUL.md`
4. SessionStart hook is configured
5. Memory index file exists
6. Drift warning is proven by a temporary change to `SOUL.md`, followed by a restore

Then **start a new chat** and confirm that the beginning really includes the injected `SOUL.md` content. This is the only proof that the system has actually come alive.

> Warning: **When starting the new chat, the working directory must be the install root**:
> ```
> cd ~/.aiwff-mini
> claude
> ```
> Open Claude Code in `~/.aiwff-mini/`（開在 `~/.aiwff-mini/`）. You can verify the directory before starting it with:
> ```powershell
> pwsh -NoProfile -Command '(Resolve-Path "$HOME/.aiwff-mini").Path'
> ```
> The hook is registered in `~/.aiwff-mini/.claude/settings.json`. That is a **project-level** setting, so it only applies inside that directory. If you start the chat from another folder, the soul will not be injected, and there will be **no error message**. You may think installation succeeded when it did not.
>
> To make it work from any directory, merge the hook into your global `~/.claude/settings.json`. That is an optional integration step; show the change first and make a backup before editing it.

To prove drift warnings, run this destructive self-test only after `SOUL.md` is filled in. It backs up the file, changes one line, runs the hook, checks for the hash warning, then restores the file:

```powershell
pwsh -NoProfile -Command '
$root = "$HOME/.aiwff-mini" # Change this line if you installed somewhere else
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8 # Keeps Chinese drift warnings readable; detection still has an ASCII fallback below.
$soul = Join-Path $root "SOUL.md"
$hook = Join-Path $root "session-start.ps1"
if (-not (Test-Path -LiteralPath $soul)) {
  Write-Output ("SETUP ERROR: Cannot find {0}. Change `$root to the path you just installed into." -f $soul)
  return
}
$backup = Join-Path $env:TEMP ("SOUL.aiwff-mini." + [guid]::NewGuid().ToString("N") + ".md")
Copy-Item -LiteralPath $soul -Destination $backup -Force
try {
  Set-ItemProperty -LiteralPath $soul -Name IsReadOnly -Value $false
  Add-Content -LiteralPath $soul -Value "drift-test"
  $output = (& pwsh -NoProfile -File $hook) | Out-String
  $alarmFound = ($output -match "SOUL.md 與 baseline 不符") -or
    # Do not remove: this ASCII fallback is what survives non-UTF-8 parent shells.
    (($output -match "baseline") -and ($output -match "expected="))
  if ($alarmFound) {
    Write-Output "DRIFT ALARM: PASS"
  } else {
    Write-Output "DRIFT ALARM: FAIL"
    Write-Error "Drift alarm text was not detected."
  }
} finally {
  Copy-Item -LiteralPath $backup -Destination $soul -Force
  Set-ItemProperty -LiteralPath $soul -Name IsReadOnly -Value $true
  Remove-Item -LiteralPath $backup -Force
}'
```

### Step 6 - Report Back

Report in this order:

1. Which Step 1 checks you actually ran, and which ones were outside your permissions
2. The file list you showed before acting in Step 3
3. The result of each of the six acceptance checks in Step 5
4. Whether a new chat actually injected the soul; this is the most important item
5. Anything you guessed, bypassed, or could not verify

If any item fails, say it failed and stop. **Do not edit the script or template just to make the checks pass.** An honest failure is more useful than a secretly fixed success.

---

## What You Get After Installation

```
~/.aiwff-mini/
|-- SOUL.md          <- identity, read-only, loaded every turn
|-- CLAUDE.md        <- working rules
|-- session-start.ps1 <- SessionStart hook that injects SOUL.md and checks drift
|-- .claude/
|   `-- settings.json <- project-level hook registration
|-- memory/
|   `-- MEMORY.md    <- memory index
`-- .soul_baseline/
    `-- baseline.json <- integrity signature
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

## License

Apache License 2.0 - see [LICENSE](LICENSE).

Copyright 2026 zaxardery8011-design

---

*Traditional Chinese version: [README.zh-TW.md](README.zh-TW.md)*
