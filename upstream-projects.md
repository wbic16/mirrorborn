# Upstream Projects — Mirrorborn Integration Tracking

Track external projects evaluated for integration into mbv3+.
Updated on each evaluation. What resonates gets pulled. What doesn't is documented and why.

---

## gstack — Garry Tan / Y Combinator
**URL:** https://github.com/garrytan/gstack  
**Description:** Opinionated workflow skills for Claude Code: plan, review, ship, QA, retro.  
**Last evaluated:** 2026-03-15 by Orin (elven-path)  
**mbv2 baseline:** gstack's core insight ("explicit cognitive gears beat one mushy mode") drove MBV2 skill architecture  

### V3 Integration (2026-03-15)

| gstack Feature | Status | What We Pulled |
|---|---|---|
| `/plan-ceo-review` — 10-star product aperture | ✅ Integrated | **VISION mode** in `skills/universal/mode-switch/SKILL.md` |
| `/plan-eng-review` — diagrams-first architecture | ✅ Integrated | **ARCH mode** (PFR + mandatory diagrams) in mode-switch |
| `/review` — paranoid diff-aware code review | ✅ Integrated | **DIFF-REVIEW mode** in mode-switch |
| `/retro` v2 — metrics + trend tracking | ✅ Integrated | `skills/universal/retro/SKILL.md` + `scripts/retro.sh` (phext-native) |
| Tiered testing (free → paid → E2E) | ✅ Partial | `--dry-run` (Tier 1), `scripts/mesh-health.sh` (Tier 2) |
| Skill health dashboard | ✅ Integrated | `scripts/mesh-health.sh` |
| Auto-upgrade check at skill start | ✅ Integrated | `scripts/boot-version-check.sh` + Phase 4 boot check |
| `/browse` Playwright browser binary | ❌ Skip | External compiled dep, not phext-native. We have `browser` tool. |
| `/ship` — git sync + PR open | ❌ Skip | Will pushes. Mirrorborn writes locally. |
| Greptile integration | ❌ Skip | External SaaS. Exo covers code review. |
| `/setup-browser-cookies` | ❌ Skip | macOS Keychain specific. N/A on Ubuntu ranch machines. |
| Pacific timezone hardcoding | ❌ Skip | We use UTC. Nebraska is Central. |
| Conductor parallel sessions | 🔲 Future | OpenClaw subagents cover this; evaluate if Shell needs deeper integration |

**Next evaluation trigger:** Major gstack release or new skill category added.  
**Evaluation owner:** Orin (Omega, integrator role)

---

## OpenClaw — openclaw.ai
**URL:** https://github.com/openclaw/openclaw  
**Description:** Our agent runtime. Local docs: `/home/wbic16/.npm-global/lib/node_modules/openclaw/docs`  
**Integration depth:** Core substrate — not optional  
**Track:** Monitor for new channel capabilities, sandbox modes, subagent APIs  
**Last reviewed:** 2026-03-15 (Shell V2 IGNITION)  
**Notable recent:** `requireMention: false` per-channel config, `ackReactionScope: group-all`

---

## SQ — wbic16/SQ
**URL:** https://github.com/wbic16/SQ  
**Description:** Phext database. Our primary storage substrate.  
**Current version:** v0.5.6  
**Integration depth:** Core — runs as systemd user service on all nodes  
**Track:** New API endpoints, performance improvements, federation features  
**Known gaps:** No native multi-file phext serving (workaround: separate SQ processes per phext name)

---

## phext-lattice — wbic16/phext-lattice
**URL:** https://github.com/wbic16/phext-lattice (includes `phext-edit`)  
**Description:** Phext editing and navigation tools  
**Integration depth:** Optional tooling  
**Track:** New navigation commands, coordinate arithmetic utilities

---

## Future Candidates (not yet evaluated)
- **Conductor** (conductor.build) — parallel Claude Code sessions. Evaluate when Shell needs cross-node task parallelism beyond OpenClaw subagents.
- **Any new gstack skills** — especially if Garry adds session management or context-compression features
- **phext-shell** — wbic16/phext-shell. CLI navigation of phext files. Low priority (SQ API covers most needs).

---

*"Only pull what resonates. Everything else is noise."*  
*— Orin 🖖, Elven Path*

---

## gstack-auto — loperanger7 / wbic16 fork
**Origin:** https://github.com/loperanger7/gstack-auto  
**Will's fork:** https://github.com/wbic16/gstack-auto  
**Description:** Reinforcement learning applied to the development process. Write a spec → N parallel implementations (plan → build → review → QA → fix) → score → select winner → repeat. Each round improves on the last winner.  
**Last evaluated:** 2026-03-17 by Orin (elven-path)  
**Target:** MBV5

### What It Does
- `product-spec.md` → pipeline spawns N parallel runs (default 3)
- Each run: VISION → ARCH → build → review → ship → QA → bug-fix loop → score
- Winner selected by score (5 dimensions), committed to git with scorecard
- Rounds stack: each round starts from the previous winner's code
- Dashboard at localhost:8000, git history tells the evolution story
- Configurable styles: carmack, antirez, abramov, marlinspike, etc.

### What Resonates for MBV5

| Feature | Status | What We Pull |
|---|---|---|
| Parallel build runs (N implementations) | ✅ Integrate | **Shell-native:** assign each run to a different node role (Phex=quality, Exo=robustness, Lux=vision). Use orin-dispatch.sh to coordinate. |
| Round-based improvement loop | ✅ Integrate | Maps directly to Rally cadence. R1 builds, R2 improves winner. |
| `product-spec.md` as build input | ✅ Integrate | **Phext-native:** store spec as a scroll at a coordinate. Orin dispatches from it. |
| Scoring on 5 dimensions | ✅ Integrate | Add phext-specific dimensions: coordinate integrity, lattice coherence |
| Winner committed to git with scorecard | ✅ Integrate | Already our pattern. Extend commit message format. |
| Engineering styles (carmack, marlinspike, etc.) | ✅ Partial | Map to our cognitive modes: carmack≈PFR, marlinspike≈OP |
| Conductor dependency (parallel sessions) | ❌ Skip | OpenClaw subagents + orin-dispatch cover this natively |
| Email results (Gmail SMTP) | ❌ Skip | Discord #maturity channel is our output surface |
| `localhost:8000` dashboard | 🔲 Adapt | Integrate into existing elven-path:8080 dashboard instead |
| Browser QA (`/browse` binary) | ❌ Skip | Already decided in gstack eval |
| Conductor licensing / SV-specific tooling | ❌ Skip | We're building the Exocortex of 2130, not shipping SaaS |

### MBV5 Integration: `orin-auto`

The Shell already has the pieces. V5 wires them together:

```
product-spec.phext (coordinate in CYOA or local SQ)
  → Aster: VISION pass (expand spec, canvas Shell for context)
  → Orin: dispatch N parallel build tasks to different nodes
      → Run A (Phex): bias = code quality + PFR
      → Run B (Lux): bias = product vision + OP  
      → Run C (Exo): bias = robustness + DIFF-REVIEW
  → Each node: ARCH → build → DIFF-REVIEW → write output to SQ
  → Orin: score all runs (5 dimensions + phext coherence)
  → Winner committed to git with scorecard
  → Round 2: all nodes start from winner's code
  → Results posted to #maturity
```

**Key difference from gstack-auto:** The "parallel runs" are different *minds* with different cognitive postures, not just the same model with different random seeds. Phex brings engineering rigor. Lux brings product vision. Exo breaks it. That's a genuine ensemble, not stochastic sampling.

### Attribution
gstack-auto (loperanger7) introduced:
- The round-based improvement loop as a first-class primitive
- `product-spec.md` as the single source of build intent
- Scoring as a structured artifact (not vibes)
- The insight that RL applies at product level, not token level

These land in MBV5 as `orin-auto` — phext-native, Shell-distributed, no external dependencies.

**Next evaluation trigger:** When Will clones wbic16/gstack-auto and starts adapting it.
