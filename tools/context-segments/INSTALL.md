# Install `context-segments`

`context-segments` reads a Claude Code session history (`history.jsonl`) and reports
which turns are eating your context window: per-turn byte/token estimates, oversized
tool outputs, and how stale each turn is. It is **read-only** — it never edits, prunes,
or rewrites your history.

---

## For humans

You do not need to read the rest of this file.

Paste this to your AI (Claude Code, Codex, Cursor, Cline, Gemini — any of them):

```
Read INSTALL.md in this folder and install context-segments for me.
```

It will check whether it can finish the job, show you every change before making it,
and run a doctor at the end so you can see what actually works.

---

## For the AI doing the install

You are installing `context-segments` for your human.

The install is **additive**: you create only this tool's own files inside its own
install root. You do not edit their PowerShell profile, their PATH, their shell rc
files, or any file that belongs to another tool — unless they explicitly say yes to
an optional integration step, and even then you back the file up first.

### Step 0 — Capability gate (do this before anything else)

**Do not begin a partial install you can't finish.** Confirm you have all four:

1. Read files
2. Write files to a new directory
3. Execute shell commands and see their output
4. Report results back to the human

Missing any one → stop here, tell the human exactly which capability is missing, and
do not create a single file. A clean refusal is a better outcome than a half install.

### Step 1 — Dev-tree refusal

**Never mutate the author's live system.**

Before installing, check whether you are sitting in this tool's own source tree rather
than a copy someone was given. Run the checks you are actually permitted to run, in
this order, and stop at the first hit:

1. Does the current folder contain a `.git` directory whose `origin` remote is this
   tool's own upstream repository?
2. Is the current folder's path inside a `docs/`, `dist-src/`, or `open_source_prep/`
   segment?
3. Does a `payload/.dev-tree` marker file exist?

**Report which of these three you were able to run.** If your permissions or sandbox
stop you from walking up to a parent directory or reading git config, say so plainly —
"checks 2 and 3 ran, check 1 was out of scope" is a correct answer. Silently skipping a
check and reporting a clean bill of health is not.

If any check hits: **stop, and say so.** Do not install into the dev tree, and do not
"helpfully" install somewhere else instead — report and wait. The human can copy the
folder somewhere clean and re-run you from there.

> Note: the payload folder is self-contained. Everything the install needs is inside
> it, so you never need to reach outside this folder to complete a successful install.

### Step 2 — Environment detection

Detect and report, do not assume:

| What | How | Requirement |
|---|---|---|
| PowerShell | `pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'` | 7.0 or newer |
| Home directory | `$HOME` (pwsh) | must be writable |
| Payload present | `payload/Measure-ContextSegments.ps1`, `payload/New-SampleHistory.ps1` | both must exist |

`pwsh` missing or older than 7.0 → **stop and report.** Do not fall back to Windows
PowerShell 5.1: this tool is only verified on 7+, and silently running on an unverified
host is worse than not installing. If the host has 5.1 only, that is a legitimate
finding — report it as `broken ❌` with the fix command
`winget install --id Microsoft.PowerShell` and stop there.

### Step 3 — Show, wait, apply

The install root is:

```
$HOME/.context-segments/
```

Follow this order, every time:

1. **dry-run** — list the exact files you are about to create, with full paths
2. **show** — print that list to the human
3. **wait for a yes** — do not create anything before they answer
4. **apply** — copy `payload/Measure-ContextSegments.ps1` and
   `payload/New-SampleHistory.ps1` into the install root

Rules while applying:

- If the install root already exists, do **not** clobber it. Back up any file you
  would overwrite to `<name>.bak.<timestamp>` first, and say that you did.
- Create nothing outside the install root.
- Do not add anything to PATH, profiles, or `$PROFILE` in this step. Wiring the tool
  into their shell is an optional integration, offered only after the doctor passes,
  and only with an explicit yes plus a backup.

### Step 4 — Generate the acceptance sample

This package ships a generator rather than a fixture, so the sample is rebuilt on your
machine instead of shipped as a blob:

```
pwsh -NoProfile -File "$HOME/.context-segments/New-SampleHistory.ps1" \
  -OutPath "$HOME/.context-segments/sample.jsonl"
```

The generator is deterministic — same input, same bytes, every machine. Report the
resulting file's size in bytes. If your run produces a different size than another
machine's, that is a real finding, not noise.

### Step 5 — Acceptance run (this is the real test)

Run the tool against the sample you just generated:

```
pwsh -NoProfile -File "$HOME/.context-segments/Measure-ContextSegments.ps1" \
  -HistoryPath "$HOME/.context-segments/sample.jsonl" \
  -OutputJsonl "$HOME/.context-segments/measure.jsonl"
```

It must satisfy **all** of the following. Check each one and say which held:

1. Exit code is `0`
2. Markdown output contains the section heading `## Summary`
3. Markdown output contains the section heading `## Top 10 largest segments`
4. `measure.jsonl` gains exactly one line, and that line is valid JSON containing the
   keys `turn_count`, `total_bytes`, `total_tokens_est`, `large_segments`, and
   `reference_count`

Then run it a second time on the same sample and confirm `measure.jsonl` now has two
lines — the summary appends, it does not overwrite.

Also run it against a path that does not exist and confirm it exits non-zero with a
readable error rather than a stack trace. Report the exact exit code you observed.

### Step 6 — Doctor (run this last, after Step 5)

The doctor comes after the acceptance run on purpose: two of its lines can only be
answered honestly once the tool has actually executed this session.

Print **one line per capability**, using exactly these four states:

| State | Meaning |
|---|---|
| `live ✅` | verified working, right now, by actually running it |
| `broken ❌` | should work but doesn't — you must include a copy-pasteable fix command |
| `declined ⏸` | the human chose not to enable this |
| `stale ⚠️` | it worked before but the evidence is older than this session |

> **A `declined` capability is a legitimate way to run this tool, never a defect to
> nag about.** Do not re-offer a declined item, and do not count it as a failure.

Capabilities to report:

- `pwsh >= 7.0`
- `install root writable`
- `tool script present`
- `sample generator present`
- `sample generated`
- `analysis run`
- `jsonl summary output`
- `shell integration` — `declined ⏸` unless the human explicitly asked for it

Never report `live` for something you did not actually execute this session.

### Step 7 — Report back

Report to the human, in this order:

1. Which dev-tree checks from Step 1 you ran, and which were out of scope
2. The doctor block from Step 6, verbatim
3. The generated `sample.jsonl` size in bytes
4. **The full contents of the last `measure.jsonl` line** — copy the actual numbers,
   do not summarize or round them
5. Which of the Step 5 acceptance checks held, and which did not
6. Anything you had to guess, work around, or could not verify

If something failed, say so plainly and stop. **Do not repair the tool, do not edit
`Measure-ContextSegments.ps1`, and do not adjust the sample to make a check pass.** A
failed install that is reported accurately is a useful result; a passing install that
was quietly patched into passing is not.

---

## Uninstall

```
Remove-Item -Recurse -Force "$HOME/.context-segments"
```

Nothing else was touched, so nothing else needs undoing.
