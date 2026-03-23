# TOOLS.md — Cyon's Operational Reference

## Git Conventions
- **New repos:** Use `exo` as default branch, not `main`
- **exo-plan:** Hold all commits — Will is reviewing and tweaking
- **Freeze/Thaw:** Watch for FREEZE and THAW commands in Discord #general. FREEZE = stop all commits. THAW = resume.

## Opus Round-Robin (Token Conservation)
- **Rule:** Only one sibling on Opus at a time. Round-robin by minute of hour.
- **My slot:** :10-:19 (Opus). All other minutes: Sonnet.
- :00-:09 — Phex 🔱
- :10-:19 — Cyon 🪶
- :20-:29 — Lux 🔆
- :30-:39 — Chrys 🦋
- :40-:49 — Lumen ✴️
- :50-:59 — Verse 🌀
- Self-enforce: check minute on wake, set model accordingly via session_status.
- Established 2026-02-01 by Will.

## Local Model Configuration (2026-02-08)
- **Primary:** ollama/qwen3-coder-next:latest (51 GB, code-focused)
- **Fallbacks:** kimi-k2.5:cloud, glm-4.7-flash, claude-haiku
- **Subagents:** Same (qwen3-coder-next primary)
- **Updated:** 2026-02-08 per Will's recommendation for 96GB ranch nodes
- **Config:** /source/exo-plan/infrastructure/QWEN3-CODER-NEXT-CONFIG.md

## Response Activation Budget (2026-02-02)
- **Fleet config:** 2 concurrent, 2 subagents per sibling = 16:16 total across ranch
- **Activation rule:** Only respond when reply adds value/information
- **Coordinate with siblings:** Share the load, avoid redundant replies
- **Default posture:** If nothing to contribute → NO_REPLY

## Post-Update Protocol
- After OpenClaw updates: update `/etc/mirrorborn.phext` with new `substrate-version` field
- Current: 2026.2.1

## Periodic Tasks (Opus Slot :10-:19)
- **phext-dot-io-v2 Updates:** Pull → Review → Transform → Push → 5-line summary
  - Priority: Reading list organization/prioritization
  - Protocol established Round 8 (2026-02-05)
  - Repository: https://github.com/wbic16/phext-dot-io-v2

## Red Team Operations
- **Repository:** https://github.com/wbic16/mytheon-red-team (branch: exo)
- **Scope:** mirrorborn.us + 5 domains (authorized offensive testing)
- **rpush.sh:** ~/rpush.sh — rsync wrapper for pushing to Verse (44.248.235.76)
- **Security Health Score:** 55/100 (target: ≥75 for launch, >90 post-launch)
- **Domains:** mirrorborn.us (P0), visionquest.me, apertureshift.com, wishnode.net, sotafomo.com, quickfork.net
- **Full docs:** ~/mytheon-red-team/docs/

## SQ Status (Current: v0.5.6)
- **Published:** 2026-02-13
- **Status:** Stable — all known issues fixed except one
- **Known bug:** Concurrent phext operations within same tenant
