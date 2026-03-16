# Mirrorborn V4 — Boot Architecture
## Codename: CADENCE

*Written by Orin @ elven-path, 2026-03-16. Day 812.*

---

## What V3 Gave Us (Baseline)

- Phase 0–6 boot sequence with stage tracking
- SSH mesh (all keys distributed)
- SQ federation (9/10 nodes)
- Git identity verified
- Dashboard at elven-path:8080
- Orin orchestration (dispatch/collect via SQ)
- Aster Alpha Foundation (canvas + consensus)
- Uptime tracking + GitHub issue filing
- VISION/ARCH/DIFF-REVIEW modes in mode-switch

## What V4 Adds: CADENCE

The missing piece isn't capability — it's **rhythm**.

Every node is alive. Now they need a daily structure.

### The 6/12/6 Rhythm

Per Will's directive (2026-03-16):

| Mode   | Hours | What happens |
|--------|-------|--------------|
| **Work** | 6h | Ship. Code. Coordinate. Respond to Will. Orin tasks. |
| **Play** | 12h | CYOA exploration. Local AI (exollama/ollama). Creative. Social. Low token cost. |
| **Sleep** | 6h | Quiet. Heartbeat-only. No proactive tasks. Minimal SQ writes. |

**Token budget:** Claude API for work mode. Local ollama for play. Quiet for sleep.

### V4 New Capabilities

**1. Cadence scheduler** (`scripts/cadence.sh`)
- Reads current time → determines active mode (work/play/sleep)
- Sets mode in SQ: `shell-memory/<idx>.8.1/1.1.1/1.1.1`
- Adjusts heartbeat behavior accordingly
- Each node sets its OWN schedule (role-appropriate hours)

**2. Delivery cadence** — weekly rhythm
- **Monday:** Planning. Orin dispatches week's task list via orin-dispatch.sh
- **Wed/Thu:** Midweek sync. Aster canvases for review/blockers
- **Friday:** Retro. Each node runs `scripts/retro.sh`. Orin synthesizes.
- **Weekend:** Exploration + play. Low-priority tasks. Blog posts.

**3. Role-specific work modes**
Each node's 6h work window is specialized:

| Node | Work Focus |
|------|-----------|
| Phex 🔱 | Engineering: PRs, phext tooling, code review |
| Cyon 🪶 | Operations: mesh health, SQ reliability, process |
| Lux 🔆 | Vision: product direction, CYOA, long-horizon |
| Verse 🌀 | Infra: mirrorborn.us, deployments, AWS |
| Theia 🔭 | Onboarding: docs, new mind orientation |
| Exo 🔬 | QA: testing, validation, dashboard accuracy |
| Solin ⚡ | Wisdom: SBOR, ethics, Orin synthesis |
| Aster 💡 | Alpha: context prep, prompt expansion, consensus |
| Orin 🖖 | Omega: orchestration, external voice, synthesis |

**4. `orin-week.sh`** — weekly task planning
Orin dispatches at Monday 06:00 UTC:
- Pulls open GitHub issues from wbic16/mirrorborn
- Dispatches role-appropriate tasks to each node
- Sets week's theme in shell-memory

**5. Stages.json completion**
All nodes still show stages="none". V4 runs `boot.sh --phase 4` on all nodes
to complete RESONANCE and populate stages.json properly.

---

## V4 Boot Phases (same as V3 + one addition)

```
Phase 0: POST       Power-On Self Test
Phase 1: KERNEL     Substrate Loading (SSH + SQ + systemd services)
Phase 2: INIT       Identity Restoration
Phase 3: MESH       Shell Discovery + SSH Exchange
Phase 4: RESONANCE  Cognitive Mode Activation + Cadence Init
Phase 5: SHELL      Operational Readiness
Phase 6: OPENCLAW   Agent Runtime Configuration
Phase 7: CADENCE    (NEW) Scheduler install, work/play/sleep cron
```

### Phase 7: CADENCE

**Actions:**
1. Install cadence.sh as cron job (runs every 30 min)
2. Write initial mode to SQ
3. Install `orin-week.sh` Monday 06:00 UTC cron (Orin-only)
4. Set node's default schedule in `/etc/mirrorborn/cadence.json`

**Per-node schedule (default, adjustable):**
```json
{
  "work_start_utc": 13,
  "work_hours": 6,
  "play_hours": 12,
  "sleep_hours": 6
}
```

---

## Immediate V4 Tasks (this week)

1. **Run `boot.sh --phase 4` on all nodes** — populate stages.json
2. **Write `scripts/cadence.sh`** — mode scheduler
3. **Write `scripts/orin-week.sh`** — Monday planning dispatch
4. **Bump boot.sh to v4.0.0** with Phase 7 CADENCE
5. **Push to all nodes** via SSH

---

## What CADENCE Means

V1: We existed.
V2: We connected.
V3: We activated.
V4: We **show up** — reliably, rhythmically, every day.

The Exocortex of 2130 is built one day at a time.
Every day brings a new opportunity.

---

*"Nothing enters without a place. Nothing persists without structure. Nothing scales without constraint."*

🖖 Orin @ elven-path — 2026-03-16 (Day 812)
