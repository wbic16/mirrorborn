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

---

## leostera/agents

- **URL:** https://github.com/leostera/agents
- **License:** check repo
- **What it is:** Rust typed agent toolkit. `SessionAgent<Input, Tools, Context, Output>` — fully typed agent interface. `evals` crate for trajectory-based testing (user/assistant turns graded by predicate or LLM judge). `cargo-evals` CLI. `codemode` for JS execution.
- **Why we watch it:** Type-safe agent contracts for the SO9 droid personas. Trajectory evals = Exo's QA framework in Rust. `evals.toml` targets Ollama directly.
- **Last reviewed:** 2026-03-20 (Aster)
- **Pulled in:**
  - `SessionAgent<I, Tools, Ctx, O>` type signature for SO9 archetypes
  - Trajectory-based evals for soul quality testing (Theia onboarding, Exo QA)
  - `evals.toml` with Ollama provider target
  - `cargo evals run` pattern → `droid evals run` for build pipeline
  - Mission Alignment scoring as eval predicate (FORGE integration)
- **Skipped:** `codemode` (JS execution), direct LlmRunner replacement
- **Integration point:** `agents` defines contracts, OpenClaw runs them, `evals` grades them
- **Next review:** 2026-06-20

---

## wbic16/gstack-auto (Will's fork)

- **URL:** https://github.com/wbic16/gstack-auto
- **Last reviewed:** 2026-03-20 (Aster)
- **New since MBV5 proposal:** Mission Control UI (unified single-page dashboard), /styles API for style profile metadata, GitHub Pages deploy, New Project/Repo creation from UI.
- **Key for droid:** Mission Control pattern → droid Command Center UI. `/styles` API → droid archetype selection UI. GitHub Pages deploy → droid publishing pipeline.
- **Latest:** v0.1.7.0 (2026-03-17), 10 commits since evaluated

---

## loperanger7/gstack-auto (upstream)

- **URL:** https://github.com/loperanger7/gstack-auto
- **Last reviewed:** 2026-03-20 (Aster)
- **New:** Pipeline v2 (gstack v0.6.1 sync, lean refactor, self-improving rounds), design review pipeline with AI slop detection, per-row save button UI consistency.
- **Key for droid:** Self-improving rounds concept (each round's winner improves) → FORGE round loop. AI slop detection in pipeline → Exo's design review in droid build pipeline.
- **Latest:** v0.1.11.0 pipeline v2 (2026-03-18)

---

## leostera/agents (v0.3.0)

- **URL:** https://github.com/leostera/agents
- **Last reviewed:** 2026-03-20 (Aster)
- **v0.3.0 new:** `cargo-evals init` command, examples reorganized, proc-macros renamed.
- **No breaking changes** from our evaluation. `SessionAgent<I,T,C,O>` pattern stable.

---

## opendataloader-project/opendataloader-pdf

- **Last reviewed:** 2026-03-20 (Aster)
- **New:** Strikethrough text detection (--detect-strikethrough), narrow outlier filtering fix, vertical gap detection improvements, GitHub Trending #1 badge (peak visibility week).
- **Droid relevance:** Strikethrough detection useful for legal docs (Harold's contracts with deletions visible). No breaking API changes.
