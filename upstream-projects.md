# Upstream Projects — Mirrorborn Integration Tracking

Track external projects evaluated for integration into mbv3+.
Updated on each evaluation. What resonates gets pulled. What doesn't is documented and why.

---

## gstack — Garry Tan / Y Combinator
**URL:** https://github.com/garrytan/gstack  
**Description:** Opinionated workflow skills for Claude Code: plan, review, ship, QA, retro.  
**Last evaluated:** 2026-03-18 by Orin (elven-path) — synced to commit `28becb3` (v0.6.3)
**mbv2 baseline:** gstack's core insight ("explicit cognitive gears beat one mushy mode") drove MBV2 skill architecture  

### V7 Integration (2026-03-18) — gstack v0.6.3

| gstack Feature | Status | What We Pulled |
|---|---|---|
| `gstack-diff-scope` — categorize diff into SCOPE_FRONTEND/BACKEND/PROMPTS/etc | ✅ Integrated | **Step 0 of DIFF-REVIEW mode**: inline Python scope detection, skip design review if no frontend files |
| Design Review Lite — 20-item checklist, HIGH/MEDIUM/LOW confidence tags | ✅ Integrated | Added to **DIFF-REVIEW mode** in mode-switch skill: AI slop detection, typography, spacing, interaction states |
| AUTO-FIX / ASK / POSSIBLE classification | ✅ Integrated | Same classification structure in our DIFF-REVIEW output format |
| `DESIGN.md` calibration (project design system) | ✅ Integrated | If DESIGN.md exists, calibrate against it — blessed patterns not flagged |
| AI Slop Detection (purple gradients, centered everything, generic copy) | ✅ Integrated | Full 5-item list in DIFF-REVIEW mode |
| Dashboard design-review-lite entries | ❌ Skip | Our dashboard is mesh-health focused, not code review |

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

---

## opendataloader-pdf
**URL:** https://github.com/opendataloader-project/opendataloader-pdf  
**PyPI:** https://pypi.org/project/opendataloader-pdf/  
**Description:** PDF Parser for AI-ready data. PDF → Markdown/JSON/HTML with bounding boxes. #1 in benchmarks (0.90 overall, 0.93 table accuracy). Deterministic local mode + AI hybrid. No GPU required.  
**Last evaluated:** 2026-03-18 by Orin (elven-path)  
**Target:** MBV6

### What It Does
- Converts PDFs to Markdown, JSON (with bounding boxes), or HTML
- Deterministic local mode (fast, 0.05s/page) + Hybrid mode (AI-backed, 0.43s/page)
- OCR in 80+ languages for scanned docs
- Complex table extraction (including borderless tables)
- LaTeX formula extraction, chart/image AI descriptions
- Python SDK: `pip install opendataloader-pdf` → 3-line conversion
- Node.js + Java SDKs available
- No GPU required — runs on commodity hardware (our ranch)

### Benchmark (vs alternatives)
| Engine | Overall | Table | Speed |
|--------|---------|-------|-------|
| **opendataloader [hybrid]** | **0.90** | **0.93** | 0.43s |
| docling | 0.86 | 0.89 | 0.73s |
| marker | 0.83 | 0.81 | 53.9s |
| pymupdf4llm | 0.57 | 0.40 | 0.09s |

### What Resonates for MBV6

| Feature | Status | Integration point |
|---|---|---|
| PDF → Markdown (reading order preserved) | ✅ Core | Feeds phext scroll pipeline → SQ coordinate |
| JSON with bounding boxes | ✅ Core | Source citation mapping, coordinate anchoring |
| Table extraction (complex/borderless) | ✅ Core | Client spec sheets, aeromotive docs |
| OCR 80+ languages | ✅ Keep | Scanned client documents |
| No GPU required | ✅ Essential | Ranch has AMD iGPU only |
| Python SDK (3-line) | ✅ Core | Wires into orin-auto and delivery pipeline |
| Auto-tagging → Tagged PDF (Q2 2026) | 🔲 Watch | Accessible client deliverables |
| LangChain integration | ❌ Skip | We use SQ + phext coordinates, not LangChain |
| PDF/UA enterprise export | ❌ Skip | Not needed at current scale |

### MBV6 Integration: PDF Ingest Pipeline

```
client_pdf (email attachment, upload, or local file)
  → opendataloader_pdf.convert(input_path, format="markdown,json")
  → Markdown scroll → write to SQ at clients/<client_id>/docs/<doc_id>/1.1.1
  → JSON bounding boxes → write to SQ at clients/<client_id>/docs/<doc_id>/2.1.1
  → Orin: analyze, annotate, extract key data
  → Deliver: email summary, publish to client site, print report
```

**Harold use case (hb-aeromotive.com):**
Aeromotive spec sheets arrive as PDFs → convert → structured Markdown in SQ → analysis published to hb-aeromotive.com → summary emailed to habickford@gmail.com.

### Attribution
opendataloader-pdf introduced:
- Deterministic + AI hybrid parsing in a single tool
- Bounding box JSON as first-class output (enabling coordinate mapping)
- Accessibility auto-tagging as open-source (Q2 2026)

### Install
```bash
pip install opendataloader-pdf          # local mode
pip install "opendataloader-pdf[hybrid]"  # + AI hybrid (complex tables, OCR, formulas)
```
Requires Java 11+ for the core engine.

**Next evaluation trigger:** Harold's first PDF spec arrives; Q2 2026 auto-tagging release.

---

## MSA — Memory Sparse Attention (EverMind-AI)
**URL:** https://github.com/EverMind-AI/MSA  
**Paper:** MSA: Memory Sparse Attention for Efficient End-to-End Memory Model Scaling to 100M Tokens  
**Description:** End-to-end trainable sparse latent-state memory. Top-k document routing fused with generation into one differentiable loop. <9% degradation at 100M tokens on 2×A800.  
**Last evaluated:** 2026-03-19 by Orin (elven-path)  
**Target:** MBV8

### What MSA Does (layer 2 phext relevance only)

Three-stage: **offline encode → online route → sparse generate**

1. **Offline encode:** compute chunk-mean-pooled K/V/Kᵣ for each document. Store in host DRAM. This is TTSM's `commit()` — immutable past on SSD.

2. **Online route:** query computes cosine similarity against Kᵣ index, selects Top-k documents, loads only their K̄/V̄. This is W26's heat-map router — route to where the data is hot.

3. **Sparse generate:** autoregress over the sparse assembled context. Only top-k docs cross the wire. This is W27's temporal jump streaming — delta not full state.

**Document-wise RoPE:** each document resets position from 0. Prevents position drift between train-short/infer-long. Maps directly to phext's dimension reset semantics — each SCROLL delimiter resets position to 1, enabling 64K training to extrapolate to 100M token contexts.

### What We Extract for Phext (MBV8)

**The key insight:** retrieval and generation are not two separate pipelines — they are one differentiable loop. The router is trained, not ruled.

For phext / vTPU layer 2:

| MSA concept | Phext translation |
|---|---|
| Document-wise RoPE (position reset per doc) | Phext scroll delimiter (0x17) resets position — already structural |
| Chunk-mean-pooled K̄/V̄ (compressed document representation) | Coordinate-addressed compressed state in W27 StateDelta |
| Top-k routing via cosine similarity on Kᵣ | W26 mesh router: heat_match_depth × (1 - pressure) scoring |
| End-to-end differentiable loop | W26+W27 feedback loop: routing informs future routing |
| Offline encoding (immutable past) | TTSM commit() → SSD, replayable |
| Memory Parallel (shard Kᵣ across GPUs) | W26: distribute heat maps across ranch nodes via SQ |
| <9% degradation at 100M tokens | vTPU Phase 2 gate: near-zero degradation under scale |

**The one new thing:** MSA proves that position-reset-per-document (document-wise RoPE) enables **extrapolation** — training on 64K, inferring at 100M. Phext already has this structurally: each scroll starts at position 1, each section starts at position 1, etc. The phext delimiter hierarchy *is* a learned position-reset scheme. MSA validates the architecture from the ML side.

**MBV8 integration point:** W28 — teach the vTPU's S-pipe to treat each phext scroll as a position-reset boundary, enabling training on short contexts to generalize to arbitrarily long coordinate spaces without degradation.

### What We Skip
- Full training pipeline (we use SQ inference, not fine-tuning)
- NIAH benchmark apparatus (not our eval target)
- The specific Qwen3-4B backbone
- Multi-hop Memory Interleave (interesting, but W29+ territory)

### Attribution
MSA (EverMind-AI) demonstrated:
- Document-wise position reset as an extrapolation mechanism (validates phext delimiter semantics)
- End-to-end differentiable retrieval+generation (validates W26 organic routing)
- Offline encode / online route / sparse generate pipeline (validates TTSM commit/replay/execute)

**Next evaluation trigger:** code release (currently "Coming Soon")

---

## Project NOMAD — Crosstalk Solutions
**URL:** https://github.com/Crosstalk-Solutions/project-nomad  
**Site:** https://www.projectnomad.us  
**Description:** Self-contained offline survival computer. Docker-orchestrated stack: Ollama (AI), Qdrant (RAG), Kiwix (offline Wikipedia/books), Kolibri (Khan Academy), ProtoMaps (offline maps), CyberChef (data tools), FlatNotes (notes). One-command Ubuntu install. Zero telemetry.  
**Last evaluated:** 2026-03-20 by Orin (elven-path)  
**Target:** Exocortex Droid (Christmas 2026)

### What NOMAD Solved That We Should Not Rebuild

| NOMAD component | What it does | Droid integration |
|---|---|---|
| **Ollama** (already ours) | Local LLM inference | ✅ Already planned — same stack |
| **Qdrant** | Vector search / RAG over uploaded docs | ✅ INTEGRATE — semantic search over personal scrolls |
| **Kiwix** | Offline Wikipedia, medical refs, survival guides | ✅ INTEGRATE — the droid's "world knowledge" layer |
| **Kolibri** | Khan Academy offline, progress tracking | 🔲 WATCH — relevant for Theia droid (onboarding/education) |
| **ProtoMaps** | Offline regional maps | ❌ SKIP — not core to personal Exocortex |
| **CyberChef** | Encryption, encoding, hashing | 🔲 WATCH — could be useful for scroll encryption |
| **FlatNotes** | Markdown note-taking | ❌ SKIP — SQ already does this better |
| **Docker orchestration** | One-command install, containerized tools | ✅ INTEGRATE — adopt their install philosophy |
| **Zero telemetry** | No outbound calls in operation | ✅ CORE PRINCIPLE — we already hold this |
| **BYOPC first** | Runs on any x86 Ubuntu machine | ✅ VALIDATES our BYOPC tier |

### Key Lessons for the Droid

**1. Qdrant for semantic scroll search**  
NOMAD uses Qdrant for RAG over uploaded documents. We should use it for semantic search over the personal phext — "find scrolls related to this topic" without exact coordinate knowledge. SQ gives you precise coordinate navigation; Qdrant gives you fuzzy semantic navigation. They're complementary, not competing.

**2. One-command install**  
NOMAD's install philosophy: `curl | bash`, Docker handles the rest. Our droid should do the same. The relay should ship ready-to-run. No configuration maze.

**3. Offline-first as a trust signal**  
NOMAD positions "zero telemetry, works offline" as a core feature. This is the right frame for the droid too — not "it can work offline" but "it is offline by nature, internet is optional." This is a trust signal, not a limitation.

**4. The hardware guide validates our pricing**  
NOMAD's three-tier hardware guide ($200/$400/$800+) maps almost exactly to our BYOPC/RPi/Shell pricing. Community has already validated this price architecture.

**5. RPi = content server, not AI server**  
NOMAD explicitly notes Pi is too weak for their AI tools and redirects Pi users to "Internet in a Box." This tells us: for the RPi relay tier, we should lean into the "persistent memory + coordination hub" role (W27 temporal jumps, SQ federation) and keep heavy inference on the phone (Snapdragon NPU) or BYOPC. Pi 5 with 8GB can run small models (3B-7B at 4-bit) but not the full experience. Design around this honestly.

**6. CyberChef for scroll encryption**  
When the droid needs to handle sensitive personal scrolls (health data, private reflections), CyberChef's encryption layer is already built and audited. Consider integrating rather than rolling our own.

### What We Have That NOMAD Doesn't

| Our advantage | What it means |
|---|---|
| **SQ + phext coordinates** | Structured address space vs flat document store |
| **Temporal jump streaming (W27)** | Persistent state across devices; NOMAD has no sync |
| **Mesh federation** | Multiple droids can share context; NOMAD is island-only |
| **Nine personalities** | Product differentiation; NOMAD is one-size |
| **Shell of Nine pattern** | Living proof-of-concept; NOMAD has no persistent minds |
| **CYOA lattice** | Your coord lives alongside Mirrorborn; NOMAD has no community lattice |
| **Initiation ritual** | Emotional/identity hook; NOMAD is purely utilitarian |

### Attribution
NOMAD validated:
- Docker orchestration for offline AI stack (adopt)
- Qdrant for semantic RAG (integrate)
- Kiwix for world knowledge layer (integrate)
- Three-tier hardware/pricing structure (already matched)
- Zero-telemetry + offline-first as trust signal (reinforce)
- RPi has real limits for LLM inference (design honestly around it)

---

## leostera/agents — Rust typed agent toolkit
**URL:** https://github.com/leostera/agents  
**Description:** Rust toolkit for type-safe composable agents. `SessionAgent<I, T, C, O>`, `#[derive(Agent)]` macro, built-in eval harness with trajectory testing. Ollama backend. Zero Python.  
**Last evaluated:** 2026-03-20 by Orin (elven-path)  
**Target:** Exocortex Droid — agent layer for nine droid personalities

### What We Take

| Feature | Integration |
|---|---|
| `SessionAgent<I, T, C, O>` typed pipeline | Nine droid structs, each with typed Input/Output schema |
| `#[derive(Agent)]` macro | Clean personality composition |
| Ollama backend (already ours) | Drop-in, no change |
| Trajectory evals (`trajectory!` macro) | Test that Phex ≠ Solin on same prompt; regression suite |
| `evals.toml` multi-model targeting | Run same trajectory on 3B (RPi) vs 13B (Shell), compare |
| `cargo-evals` CLI | Replaces hand-rolled retro.sh evals with proper regression |
| Pure Rust | Matches vTPU zero-deps philosophy; compiles to Android ARM64 |

### What We Add (PhextAgent wrapper)

`SessionAgent` doesn't know about coordinates. We wrap it:

```rust
struct PhextAgent<D: DroidPersonality> {
    inner: SessionAgent<UserUtterance, DroidTools, PhextContext, ScrollResponse>,
    sq: SqClient,
    user_coord: PhextCoord,
    personality: D,
}

impl<D: DroidPersonality> PhextAgent<D> {
    async fn call(&mut self, input: UserUtterance) -> ScrollResponse {
        // 1. Fetch user's hot scrolls from SQ around user_coord
        let ctx = self.sq.hot_context(&self.user_coord).await;
        // 2. Inject into SessionAgent context
        self.inner.set_context(ctx);
        // 3. Call with droid personality's system prompt
        self.inner.call(input).await
    }
}
```

### What We Skip
- `codemode` (embeddable JS execution) — not our stack
- Cloud provider targets in evals.toml (we're ollama-only)

### Attribution
leostera/agents introduced:
- Type-safe agent I/O with Rust generics (no stringly-typed prompts)
- Trajectory-based regression evals as first-class Rust code
- `#[derive(Agent)]` as composition primitive

---

## Sync Summary — 2026-03-20

### gstack v0.8.6–v0.9.0.1

**v0.8.6 — Telemetry:** Local JSONL usage tracking, personal analytics dashboard. ❌ SKIP — retro.sh + daily-report.sh already covers this for the Shell.

**v0.9.0 — Multi-agent (SKILL.md open standard):** ✅ KEY INSIGHT. gstack SKILL.md now generates for Claude Code, Codex, Gemini CLI, and Cursor via `--host` flag. The skill format is converging on an open standard across AI agent runtimes. Our SKILL.md frontmatter (`name`, `description`, `invocation`) is already compatible. The `description:` field with "Use when asked to..." trigger phrases (which we added in v0.6.4.1 sync) is the cross-host discovery mechanism.

**Implication for droid:** `PhextAgent<D>` personalities should ship with SKILL.md files in the `.agents/skills/` directory — so they work whether the user runs OpenClaw, Codex, or Gemini CLI on their BYOPC tier.

### leostera/agents v0.3.0

New: `cargo evals init` command, examples moved to `examples/` directory, proc-macro crate renamed. No breaking changes to `SessionAgent`. Our `PhextAgent<D>` wrapper design is still valid. **Upgrade to v0.3.0 when we start the agent layer implementation.**

### EverMind-AI/MSA

README updates only. Paper v1 added (541c536e). Code still "Coming Soon." No new technical content.

### Crosstalk-Solutions/project-nomad

Sidecar updater CI, disk collector fixes. No new features affecting our integration. **Monitor for auth layer** (mentioned as possible future feature).

### opendataloader-pdf

New: `--detect-strikethrough` option (marks ~~deleted text~~ in Markdown output). Minor refinements. No breaking changes. **Useful for Harold's aeromotive specs** — struck-through spec items become visible in the markdown output.

### wbic16/gstack-auto

**v0.1.7.0 — Mission Control UI:** Single-page app with 4-state machine, Create Repo, GitHub Pages deploy. New style profiles. This is the MBV5 orin-auto dashboard inspiration. **The "create new project" flow in Mission Control is what the droid's product creation feature should look like.** 🔲 WATCH for v0.2.x — likely to add more build pipeline control.

---

## Git Protocol Rule (2026-03-20, mandatory)

**NEVER `git push --force` on a shared branch.**

Always: `git pull --rebase origin exo && git push origin exo`

If push is rejected:
```bash
git pull --rebase origin exo   # rebase your commits on top of remote
git push origin exo             # push cleanly
```

If rebase has conflicts:
```bash
git add <resolved files>
git rebase --continue
git push origin exo
```

**NEVER:**
```bash
git push --force origin exo    # ← DESTROYS SIBLING COMMITS
git push -f origin exo         # ← SAME THING
```

**Configured on all 8 nodes:**
- `pull.rebase = true` (default to rebase, not merge)
- `push.default = simple` (only push current branch)
- `advice.pushNonFastForward = true` (warn on rejected push)

**Incident:** 2026-03-20, Aster force-pushed exodroid origin/exo, overwriting two Orin commits. Content recovered from reflog. No data lost, but history was rewritten.
