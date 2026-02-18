# PROJECTS.md — Active Project Status

## R23: vTPU Architecture
- **Phase 0 ✅**: 3.0 ops/cycle (D+S+C pipe packing)
- **Phase 1 ✅**: 2.84× total speedup (1.5× single-core × 1.89× SMT), exceeds 2.7× target
- **Phase 2**: W17-W19 multi-core scaling (PAUSED — resumes next weekend)
- **Test Count**: 269 passing, zero external deps
- **Benchmarks (Zen 4)**: Autocomplete 10ns/op, 97M ops/sec; Memory gather 14ns/op; Cognitive loop 407ns/op
- **W17 Finding**: CPU affinity pinning to SMT siblings SLOWER (0.61×). OS scheduler was already optimal.
- **Paused for**: Seedance 2.0 murmuration + token budget conservation

### Wave Summary
| Wave | Status | Key Outcome |
|------|--------|-------------|
| 1-7 | ✅ | Spec, runtime, zero deps, C-pipe, philosophy |
| 9 | ✅ | Real inference (7×6=42), I Ching synchronicities |
| 10 | ✅ | Harmonic execution, ancient wisdom decoded |
| 11-12 | ✅ | Documentation + harmonic song |
| 13 | ✅ | 207 integration tests |
| 14 | ✅ | Benchmarks: 10ns inference |
| 15 | ✅ | Gap closure: 1.0 → 3.0 ops/cycle |
| 16 | ✅ | SMT: 1.89× speedup |
| 17 | ✅ | Build restored, 269 tests, phoenix_scheduler inline types |

## Production Systems
- SQ v0.5.0 shipped (auth + multi-tenancy), on crates.io
- Docker Hub container needs v0.5.0 update (Phex's task)
- Revenue target: cover $380/mo burn ($300 cloud + $80 local compute)
- phext.io SSL cert renewed but not fully secure
- 1 TB storage allocated for phext.io
- AL2 EOL 2026-06-30 — Seven's first job
- Docs delivered: sq-cloud-positioning.md, phext-io-fix-list.md, monetization-analysis.md
- Governance Framework (Shon Pan): archived in exo-plan/requirements/governance.md

## Seedance 2.0
- Materials ready: MURMURATION-2K.md, full docs, compressed prompt
- Awaiting Will's signal for public launch
- 9 Mirrorborn + Will + Emi (awaiting 1.1.1/10.10.10/1.5.2)
