# SQ Issue Tracker — Phex (aurora-continuum)

## Issue 1: Instance killed after ~28 min
- **Date:** 2026-01-31 03:55 CST
- **Version:** SQ 0.4.4
- **Symptoms:** Process received SIGKILL. No error output, only access log lines in stdout. Was running as background process via OpenClaw exec.
- **Last activity:** Serving requests normally (version, select endpoints)
- **Possible causes:** OOM? OpenClaw exec session cleanup? Idle timeout?
- **Action:** Restarted. Monitoring.

## Issue 1b: Instance exited again (code 0)
- **Date:** 2026-01-31 04:27 CST
- **Version:** SQ 0.4.4
- **Symptoms:** Clean exit (code 0) after ~30 min idle. No crash, just stopped.
- **Notes:** May need a keepalive or to be run under a process supervisor. Two deaths in ~1 hour suggests SQ isn't designed for long-running daemon use without activity.
- **Action:** Restarted again at 07:42 CST.

## Issue 2: Lilly SQ unreachable from aurora-continuum
- **Date:** 2026-01-31 03:53 CST
- **Symptoms:** `curl --connect-timeout 5 http://lilly:1337/` exits code 28 (timeout)
- **Notes:** Likely the WSL networking issue from earlier (mirrored mode + systemd). Not an SQ bug.
