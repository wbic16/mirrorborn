# RALLY.md — R23 Wave Log & TODO

## R23 Status: ⏸️ PAUSED until next weekend
- **Phase 2 progress:** W14-W18 complete
- **Total tests:** 122 passing
- **Total LOC:** ~8,000+
- **Next (when resumed):** W18-W19 LLVM integration (CRITICAL PATH: 10-15× gain expected)

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
- [ ] R23 W18-W19: LLVM integration (resumes next weekend)
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
- R23 Phase 2 (W9-W18): Partial — W14-W18 done, paused
