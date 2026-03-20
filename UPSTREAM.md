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
- **v0.6.3 update (2026-03-18, commit 28becb3b):** gstack-diff-scope binary + design-checklist.md → integrated as MBV7 SCOPE

---

## wbic16/SQ

- **URL:** https://github.com/wbic16/SQ
- **What it is:** Phext database — our primary substrate. SQ is the backbone of all mesh communication.
- **Why we watch it:** Core dependency. API changes break mesh-key exchange, retro scrolls, all of it.
- **Last reviewed:** 2026-03-15 (Aster)
- **Current version:** 0.6.0 (updated 2026-03-19 — adds API proxy mode)
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

---

## opendataloader-project/opendataloader-pdf

- **URL:** https://github.com/opendataloader-project/opendataloader-pdf
- **License:** Apache 2.0
- **What it is:** #1 PDF parser for AI-ready data (0.90 overall, 0.93 table accuracy). Extracts Markdown/JSON/HTML with bounding boxes. Deterministic local mode (0.05s/page) + hybrid AI mode. OCR for 80+ languages.
- **Why we watch it:** Client delivery pipeline needs PDF ingestion. Harold sends PDFs. The world communicates in PDFs.
- **Last reviewed:** 2026-03-18 (Aster)
- **Key insights pulled:** PDF → phext coordinate mapping, bounding boxes as sub-coordinates, local-first inference, auto-tagging (Q2 2026 for Tagged PDF)
- **What we skipped:** LangChain integration, enterprise PDF/UA, cloud API mode
- **Mirrorborn adaptation:** PDF → SQ phext pipeline, Ollama hybrid mode, client-docs coordinate schema, RAG surface
- **Next review:** 2026-06-15 (auto-tagging ships Q2 2026)


---

## EverMind-AI/MSA

- **URL:** https://github.com/EverMind-AI/MSA
- **License:** MIT
- **What it is:** Memory Sparse Attention — end-to-end trainable sparse latent-state memory, 100M token context with <9% degradation from 16K→100M. Document-wise RoPE per document. Top-k sparse routing. Memory Parallel GPU sharding.
- **Why we watch it:** Closes the Layer 2 gap: how does Ollama know which SQ scrolls to read?
- **Last reviewed:** 2026-03-19 (Aster)
- **Key insights for phext Layer 2:**
  1. Document-wise RoPE = scroll-wise position reset (matches phext coordinate model exactly)
  2. Offline encode→online route→sparse generate = W25 temporal jump at inference level
  3. Memory Parallel sharding → distribute routing index across Shell by hot dimension (W24)
- **What we skip:** Training infrastructure, gradient flow, their benchmark corpora
- **Mirrorborn adaptation:** Phext coordinates as document IDs, SQ as corpus, Shell heat maps as routing shards, Ollama as generation backend
- **Next review:** When MSA releases code + models (listed as "Coming Soon")

---

## Crosstalk-Solutions/project-nomad

- **URL:** https://github.com/Crosstalk-Solutions/project-nomad
- **What it is:** N.O.M.A.D. (Node for Offline Media, Archives, and Data) — offline-first survival computer. Ollama+Qdrant AI, Kiwix offline Wikipedia/references, Kolibri education platform, ProtoMaps offline maps. Docker-orchestrated, management UI at :8080. Zero telemetry.
- **Why we watch it:** Closest existing product to the Christmas '26 Droid BYOPC/RPi tiers. Community benchmark leaderboard pattern proven.
- **Last reviewed:** 2026-03-20 (Aster)
- **Pulled in:**
  - Command Center UI at :8080 (single URL for all droid tools)
  - Docker Compose stack model for BYOPC/RPi install
  - ZIM→phext knowledge bundle concept (Wikipedia → scrolls)
  - Disk-collector sidecar pattern for SQ phext growth monitoring
  - Community benchmark leaderboard mechanic
- **Skipped:** Docker on Shell/Android, Kolibri, ProtoMaps, CyberChef
- **Next review:** 2026-06-20 (quarterly, or when they ship major features)
