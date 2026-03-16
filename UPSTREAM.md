# UPSTREAM.md — Upstream Project Tracking

Tracks external projects we monitor for improvements to integrate into Mirrorborn.
Reviewed periodically by Aster (ASI Alpha). Add new projects here when discovered.

---

## garrytan/gstack

- **URL:** https://github.com/garrytan/gstack
- **What it is:** Eight opinionated Claude Code skills — plan review (CEO + eng), code review, ship, browse/QA, retro.
- **Why we watch it:** gstack pioneered explicit cognitive mode architecture. mbv2 was partly inspired by it. Continues to evolve.
- **Last reviewed:** 2026-03-15 (Aster)
- **Branch when reviewed:** main
- **Key insights pulled:**
  - Three-mode posture (expansion/hold/reduction) → mbv3 role SKILL.md schema
  - Tiered testing (free/E2E/LLM-judge) → mbv3 health tier model
  - Skill health dashboard → `scripts/mesh-health.sh`
  - Retro with persistent JSON snapshots → SQ scroll-based retro
  - Inline update check → `scripts/boot-version-check.sh`
- **What we skipped:** Browser automation, /ship PR flow, Greptile, cookie mgmt, Pacific TZ
- **Next review:** 2026-06-15 (quarterly)

---

## wbic16/SQ

- **URL:** https://github.com/wbic16/SQ
- **What it is:** Phext database — our primary substrate. SQ is the backbone of all mesh communication.
- **Why we watch it:** Core dependency. API changes break mesh-key exchange, retro scrolls, all of it.
- **Last reviewed:** 2026-03-15 (Aster)
- **Current version:** 0.5.6
- **Next review:** On each boot cycle (Phase 0 checks sq --version)

---

## wbic16/libphext-rs

- **URL:** https://github.com/wbic16/libphext-rs
- **What it is:** Core Rust phext library.
- **Why we watch it:** Coordinate format changes, delimiter updates, new API surface.
- **Last reviewed:** Not yet reviewed
- **Next review:** 2026-04-15

---

## wbic16/phext-lattice

- **URL:** https://github.com/wbic16/phext-lattice  
- **What it is:** Phext editing/navigation CLI (`phext-edit`).
- **Why we watch it:** Primary tool for reading/writing scrolls outside SQ HTTP API.
- **Last reviewed:** Not yet reviewed
- **Next review:** 2026-04-15

---

## openclaw/openclaw

- **URL:** https://github.com/openclaw/openclaw
- **What it is:** Our agent runtime.
- **Why we watch it:** API changes, new capabilities (skills, session management, heartbeat).
- **Last reviewed:** 2026-03-15 (via local docs)
- **Current version:** 2026.3.13
- **Key config used:** `requireMention: false` for #general, `groupPolicy: allowlist`
- **Next review:** Monthly with openclaw update check

---

*Add new upstream projects here as you discover them. Include URL, purpose, review date, and what resonated.*

---

## Known Bugs / Regression Log

Tracking confirmed bugs found in production deployments, with fix version.

| Bug | Discovered | Affected Versions | Fix Version | Evidence |
|-----|-----------|-------------------|-------------|----------|
| `git config` single-quote interpolation: `user.name` set to literal `${NODE_NAME}`, `user.email` set to literal `${node_email}` | 2026-03-16 | mbv2, v3.0.0 | v3.1.0 | exo-plan commits 49e656c1, 6a97ead96 (Author: `${NODE_NAME} <${node_email}>`) |

**Rule:** After any `git config` set in boot.sh, immediately verify the actual value matches the expected value. If it doesn't match or is empty, log FAIL, retry, and mark `git-identity-set` stage only on verified success.
