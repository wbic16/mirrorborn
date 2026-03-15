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
