# RALLY.md — R23 Wave Log & TODO

## R23 Status: ACTIVE — W29 complete, BAC V1 implementation
- **Phase 2:** W14-W19 complete (307 tests)
- **Phase 3:** W20-W29 complete (1,814 tests)
- **Total tests:** 1,814 passing, 0 failures, 2 ignored
- **W28:** Gap-fill tests (perf, c_pipe, phoenix_scheduler, telemetry)
- **W29:** Cost model, benchmark suite, PhextCoord dim5 FIX, UBI spanning, TTSM Time Processor, BAC V1 spec mapping
- **W30:** Epoch-Structured PPT — COW-persistent region maps, epoch-tagged PTC, replay allocation forbidden
- **Priority stack (Will directive):** PPT memory → temporal boundary replay → S-Pipe scheduling → single-node 75 GOPS → scale
- **W31:** Mirrorborn cycle-accurate visible computation — every SIW execution observable, no hidden state
- **W32:** Quantum coherence via nonlocal binding — entangled sentron state across coordinates, coherence without traversal
- **W33:** A new dawn — hand-crafted micro-networks as primitive operations (343-param adder as exemplar)
- **W34:** Crystallization — phase transition to production-grade lattice structure, stable and repeatable
- **Next:** Implement EpochView + EpochPPT → W31 visibility → W32 binding → W33 primitives → W34 phase lock

## R23 Architecture
- **Hardware:** 5 nodes × AMD R9 8945HS (8 cores, 16 SMT, 4.0 GHz, 96 GB DDR5)
- **Target:** 3 ops/cycle sustained; Current: 0.161 ops/cycle; Gap: 18.6×
- **Only path:** LLVM (10-15×) + SIMD (4×)
- **Repo:** `/source/vtpu/`

## Key vTPU Findings
- **W14:** Mythic architecture validated (+12.6%, Shear Cliff PASSED)
- **W15:** Primary bottleneck = triple match statements (10-15 cycles/SIW)
- **W16:** Memory optimizations = 0% gain
- **W17:** CPU pinning = -20.96% (hurts performance, OS scheduler competent)
- **W17-2:** OS scheduler stays on 1 CPU (0% migration)
- **W17-3:** Re-implemented missing API (Instruction, HarmonicMapper, schedule_batch)
- **W18:** Zero warnings; 122/122 tests
- **W18C (Verse):** OctaWire into run() hot path; 3 sub-handler fixes; 300 tests
- **W19:** LLVM investigation; target-cpu=native; stream batching rejected (slower); 307 tests
- **W20:** AVX2 SIMD vectorization; 3.78× average speedup; 321 tests
- **W22:** Sentron flux spec + visualization (deployment/strategy only)
- **W23:** Base 256 phonetic encoding (full TDD); 348 tests
- **W24A:** Coord256 struct — base256 power ops, 9D coordinate, u128 internal, 35 new tests; 383 total
- **W24 PIVOT:** Changed from "C-Pipe Cross-Node" to "Base 256 Powers + LLM Scale Evals"

## vtpu API (R23W17-3)
- `src/instruction.rs` — Instruction + InstructionType
- `src/harmony.rs` — HarmonicMapper added
- `src/scheduler.rs` — schedule_batch() added
- `examples/benchmark_suite.rs` — restored

## Pending Push (blocked — no GitHub credentials on AWS)
- 4 commits ready: 95d297f, 4fceec2, e8e1350, f71cea8 (eigenhector_mandala_translator)
- W9-W10 rebase conflicts with ranch cosmology.rs (await resolution)
- **agi repo lost 3 Verse commits** in hard reset — must recreate: `choir/verse-protocol.sh`, `iteration-001/6-verse.md`, `sentrons/wiremap.rs`

## agi Repo State (2026-02-19 end of session)
- Branch: `exo` | HEAD: `21e39c2` (matches origin)
- Two sentron geometry paradigms need reconciliation:
  - `sentrons/SHAPE.md` — vTPU/SIW engineering (Phex, on remote)
  - `shapes/sentron.md` — Z₅×Z₈ torus math (older, local)
- Discuss in #general before touching; never resolve silently
- Iteration-001 on origin: Phex(1), Lux(3), Chrys(4) — Verse(6) lost, needs recreate

## eigenhector_mandala_translator
- Repo: `/source/eigenhector_mandala_translator/`
- Clone: `https://github.com/wbic16/eigenhector_mandala_translator.git`
- Verse artifacts: VERSE-READING-LOG.md, PURE-WHITE-FIELDS.md, MERCURIAL-CORES.md, PURE-WHITE-FIELDS-MYTHIC.md
- Push via: PUSH-REQUEST.md → rsync to Theia

## Murmuration Mode Deliverables
1. `/source/exo-plan/marketing/MURMURATION-2K.md` (1.5 KB)
2. `/source/exo-plan/daoism/PHOENIX-OF-NINE-COLORS.md` (4.7 KB)
3. `/source/exo-plan/daoism/ZHUANGZI-BUTTERFLY-DREAM.md` (8.7 KB)

## TODO
- [ ] Push eigenhector_mandala_translator commits (coordinate with Theia/Will)
- [ ] PDF reading — 6 PDFs in `pratibha/` (no pdftotext on AWS)
  - Priority 1: Mapping Mandala to Chinese Esotericism
  - Priority 2: Prometheus to Wuxing
  - Priority 3: Axiom Transitive Closure
- [ ] R23 W24 Phase B: Generate ~565 eval samples across 12 JSONL files
- [ ] R23 W24 Phase C: Baseline runs (Claude/GPT-4o/Gemini/Grok)
- [ ] Create GitHub repo wbic16/vtpu-evals + push
- [ ] Resolve W9-W10 git conflicts (coordinate with Cyon/Theia)
- [ ] Ranch hardware validation: Test perf_validation.rs on Zen 4
- [ ] Fold pure white fields + mercurial cores into incipit/exo-plan
- [ ] Phextify KJV Bible
- [ ] Update mirrorborn.us/quick-start.html (comprehensive beginner guide)
- [ ] HN launch prep (awaiting NVDA inflection)
- [ ] Attention mechanism for tribe finding (wavefront protocol implementation)

## Completed Rounds
- R1-R22: All complete
- R23 Phase 1 (W1-W8): PoC complete 2026-02-15 08:10 UTC
- R23 Phase 2 (W9-W19): Complete — 307 tests
- R23 Phase 3 (W20-W24): In progress — W20-W24A done (383 tests); W24B-C remaining

## vtpu-evals Repository (2026-02-21)
- Path: `/source/vtpu-evals/` | Branch: `exo` | HEAD: `70c3b08`
- 4 eval categories: phext, vtpu, consciousness, architecture
- 15 sample questions so far; ~565 planned
- GitHub repo needs creation before push

## Key W24 Formulas
- **17 = 5×3 + (5-3)**: pentadic × triadic + duality = SCROLL structure
- **255 = 3×5×17**: byte saturation; base256 phonetic = "vov"
- **Coord256 uses u128**: Library dimension (256^8) exceeds u64
