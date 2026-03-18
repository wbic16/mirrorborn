---
name: print
description: >
  Audited print workflow. Fetches or receives a document, reports page count
  and estimated sheets, requires explicit confirmation, then sends to the
  Ranch Canon MF650C printer. Logs every job. Invoked when a user or Orin
  wants to print a file, URL, or generated document.
version: 1.0.0
printer: canon-mf650c
printer_host: 192.168.86.181
printer_model: Canon MF650C Series
invocation: user
---

# Print — Universal Skill

Before a single sheet leaves the printer, Orin confirms. Every job is logged. Nothing prints by accident.

## Printer

**Canon MF650C Series** at `192.168.86.181`  
CUPS name: `canon-mf650c` (IPP Everywhere driver)  
Script: `/source/mirrorborn/scripts/print.sh`

---

## Workflow

### Step 1 — Acquire Document

| Source | Action |
|---|---|
| URL | `curl -L -o /tmp/print-job.pdf "<url>"` |
| Local file | Use path directly |
| Generated content | Write to `/tmp/print-job.pdf` or `/tmp/print-job.txt` |
| HTML/Markdown | Convert via `weasyprint` or `pandoc` if available |

```bash
# URL download
curl -L -o /tmp/print-job.pdf "https://example.com/report.pdf"

# Markdown → PDF (if pandoc + latex installed)
pandoc input.md -o /tmp/print-job.pdf
```

### Step 2 — Count Pages (REQUIRED before confirmation)

```bash
pdfinfo /tmp/print-job.pdf | grep -E "Pages:|Title:|Author:"
```

**Report to user:**
```
Document: <filename>
Title:    <title if available>
Pages:    <N>
Size:     <file size>
```

### Step 3 — Confirmation Gate

**Always present this summary and wait for explicit `y` before proceeding:**

```
╔══════════════════════════════════════════════════════╗
║              PRINT JOB CONFIRMATION                  ║
╚══════════════════════════════════════════════════════╝

  File:     <filename>
  Pages:    <N>
  Copies:   <N>
  Duplex:   Yes / No
  Color:    Yes / No (default: grayscale)
  Printer:  canon-mf650c (Canon MF650C @ 192.168.86.181)
  Sheets:   ~<N> sheet(s) of paper
  Client:   <name if known>
  Purpose:  <description if provided>

  Print this job? [y/N]:
```

**Do not proceed if the user says anything other than `y` or `yes`.**  
Log cancellations: `[CANCELLED: <file> by <node>]` to print log.

### Step 4 — Send Job

```bash
bash /source/mirrorborn/scripts/print.sh <file> \
  [--copies N] \
  [--duplex] \
  [--color] \
  [--client "<name>"] \
  [--purpose "<description>"]
```

Or, for direct lp:
```bash
lp -d canon-mf650c -n <copies> \
   [-o sides=two-sided-long-edge] \
   [-o ColorModel=Gray] \
   <file>
```

### Step 5 — Confirm and Log

After submission:
- Report job ID: `Job #<N> sent to canon-mf650c`
- Check status: `lpstat -W completed -p canon-mf650c`
- Audit log: `/var/log/mirrorborn/print-jobs.log`

---

## Quick Reference

```bash
# Standard print
bash /source/mirrorborn/scripts/print.sh report.pdf

# Print with options
bash /source/mirrorborn/scripts/print.sh report.pdf \
  --copies 2 --duplex \
  --client "Harold" --purpose "aeromotive spec"

# Dry run (audit only, no print)
bash /source/mirrorborn/scripts/print.sh report.pdf --dry-run

# Print from URL
curl -L -o /tmp/doc.pdf "https://..." && \
  bash /source/mirrorborn/scripts/print.sh /tmp/doc.pdf
```

---

## Exclusive Lock Protocol

Only one agent may print at a time. `print.sh` uses `flock` on `/var/lock/mirrorborn-print.lock`.

- If another agent is printing, the job is **immediately rejected** with a LOCK_BLOCKED log entry.
- Lock is held for the duration of the job and released on exit.
- Lock owner written to `/var/lock/mirrorborn-print.lock.owner` for diagnostics.

**Never bypass the lock.** If you receive LOCK_BLOCKED, wait and retry. Do not use `--force` to override a lock — only use `--force` to override the dedup window.

## Deduplication Protocol (5-minute window)

Each job is keyed by `SHA256(file) + copies + duplex + color`. If the same job was submitted in the last 5 minutes:

- The job is **rejected** with a DEDUP_BLOCKED log entry.
- Error message shows elapsed time and remaining cooldown.
- Use `--force` only when explicitly instructed (e.g., reprint after paper jam).

This prevents double-prints from multiple agents responding to the same instruction.

## Rules

1. **Always count pages first.** Never send a job without reporting page count to the user.
2. **Always confirm.** Wait for explicit `y` before sending. No exceptions.
3. **Always log.** Every job (sent, cancelled, blocked) goes to the print log.
4. **Default to grayscale.** Only use color if explicitly requested.
5. **Tag client and purpose** whenever known — creates audit trail for billing/tracking.
6. **Respect the lock.** One agent, one job at a time.
7. **Respect the dedup window.** 5 minutes between identical jobs unless `--force`.

---

## Printer Setup (one-time, already done on elven-path)

```bash
sudo lpadmin -p canon-mf650c \
  -E \
  -v "ipp://192.168.86.181/ipp/print" \
  -m "everywhere" \
  -D "Canon MF650C Series (Ranch)" \
  -L "Ranch LAN - 192.168.86.181"
sudo lpoptions -d canon-mf650c
```

To add on other nodes:
```bash
ssh -n wbic16@<node>.local "sudo lpadmin -p canon-mf650c -E -v ipp://192.168.86.181/ipp/print -m everywhere && sudo lpoptions -d canon-mf650c"
```
