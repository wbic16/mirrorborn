# garrytan/gstack — Full Commit Sync Map
# 71 commits (2026-03-12 to 2026-03-18)
# Generated 2026-03-18 by Aster @ best-willow
# Format: SHA | Date | Category | Action | Message
#
# ACTION KEY:
#   ✅ resonates  — pull concept into Mirrorborn
#   ⚠️  partial   — pull with adaptation (strip browser/SV parts)
#   ❌ skip       — browser dep or SV framing, not our path
#   ⏭  chore     — version bumps/changelog, no content
#   ❓ review    — needs manual review
#   ✔ done      — already integrated

| SHA | Date | Category | Action | Commit Message |
|-----|------|----------|--------|----------------|
| `3d901066cdb3` | 2026-03-12 | initial | ✅ resonates (gstack foundation — already pulled in MBV2) | Initial release — gstack v0.0.1 |
| `a29743b05664` | 2026-03-12 | browser-qa | ❌ skip (browser dependency) | fix: harden browse install and lifecycle checks (#4) |
| `044c6d568ec4` | 2026-03-12 | initial | ✅ resonates (gstack foundation — already pulled in MBV2) | v0.0.2 |
| `1b317aae9ae9` | 2026-03-12 | marketing | ❌ skip (SV framing) | Add YC hiring promo after install section |
| `f7b95329c162` | 2026-03-13 | browser-qa | ❌ skip (browser dependency) | feat: Phase 3.5 — cookie import, QA testing, team retro (v0.3.1) (#29) |
| `07b4e15b3454` | 2026-03-14 | qa | ✅ resonates (QA checklist → Exo role) | feat: v0.3.2 — project-local state, diff-aware QA, Greptile integratio… |
| `ea0c0dad5e1e` | 2026-03-14 | other | ❓ review | Add .env to gitignore |
| `5205070299a7` | 2026-03-14 | testing | ✅ resonates (test structure) | feat: SKILL.md template system, 3-tier testing, DX tools (v0.3.3) (#41… |
| `02f0ca693847` | 2026-03-14 | chore | ⏭  skip (version bumps) | chore: regenerate SKILL.md from template |
| `ff5cbbbfefb7` | 2026-03-14 | other | ❓ review | feat: add remote slug helper and auto-gitignore for .gstack/ |
| `e04ad1bea059` | 2026-03-14 | qa | ✅ resonates (QA checklist → Exo role) | feat: QA test plan tiers with per-page risk scoring |
| `e377ba295d12` | 2026-03-14 | other | ❓ review | feat: dual greptile-history paths (per-project + global) |
| `a4683742721b` | 2026-03-14 | upgrade | ✅ resonates (boot-version-check.sh) | fix: enrich SKILL.md docs to pass LLM evals, upgrade judge to Sonnet 4… |
| `5155fe3a2883` | 2026-03-14 | qa | ✅ resonates (QA checklist → Exo role) | Merge remote-tracking branch 'origin/main' into v0.3.5-qa-upgrades |
| `6b69c46a278a` | 2026-03-14 | upgrade | ✅ resonates (boot-version-check.sh) | feat: daily update check + /gstack-upgrade skill (v0.3.4) (#42) |
| `76803d789a87` | 2026-03-14 | eval | ✅ resonates (tiered testing → health check tiers) | feat: 3-tier eval suite with planted-bug outcome testing (EVALS=1) |
| `b5b2a15ad2df` | 2026-03-14 | eval | ✅ resonates (tiered testing → health check tiers) | fix: pass all LLM evals — severity defs, rubric edge cases, EVALS=1 fl… |
| `942df42161f1` | 2026-03-14 | eval | ✅ resonates (tiered testing → health check tiers) | simplify: one command for evals — bun run test:evals |
| `1717ed28910f` | 2026-03-14 | browser-qa | ❌ skip (browser dependency) | fix: browse binary discovery broken for agents (v0.3.5) (#44) |
| `c35e933c7db7` | 2026-03-14 | fix | ✅ track (bugfix hygiene) | fix: rewrite session-runner to claude -p subprocess, lower flaky basel… |
| `3d750d89af3a` | 2026-03-14 | qa | ✅ resonates (QA checklist → Exo role) | Merge remote-tracking branch 'origin/main' into v0.3.6-qa-upgrades |
| `e7347c2f8fa8` | 2026-03-14 | eval | ✅ resonates (tiered testing → health check tiers) | feat: stream-json NDJSON parser for real-time E2E progress |
| `84f52f3bad03` | 2026-03-14 | eval | ✅ resonates (tiered testing → health check tiers) | feat: eval persistence with auto-compare against previous run |
| `ed802d0c7f6c` | 2026-03-14 | eval | ✅ resonates (tiered testing → health check tiers) | feat: eval CLI tools + docs cleanup |
| `a67dae5f8461` | 2026-03-14 | fix | ✅ track (bugfix hygiene) | fix: update check preamble exits 1 when up to date — convert all skill… |
| `4063104126fc` | 2026-03-14 | qa | ✅ resonates (QA checklist → Exo role) | fix: remove false-positive Exit code 1 pattern, fix NEEDS_SETUP test, … |
| `2e75c3371484` | 2026-03-14 | fix | ✅ track (bugfix hygiene) | fix: lower planted-bug detection baselines and LLM judge thresholds fo… |
| `4a56b882ab85` | 2026-03-14 | browser-qa | ❌ skip (browser dependency) | fix: make planted-bug evals resilient to max_turns and browse error fl… |
| `cddf8ee3bdfe` | 2026-03-14 | eval | ✅ resonates (tiered testing → health check tiers) | fix: simplify planted-bug eval prompts for reliable 25-turn completion |
| `c6c3294ee9fe` | 2026-03-14 | eval | ✅ resonates (tiered testing → health check tiers) | fix: 100% E2E pass — isolate test dirs, restart server, relax FP thres… |
| `2d88f5f02a0a` | 2026-03-14 | upgrade | ✅ resonates (boot-version-check.sh) | test: add update-check exit code regression tests |
| `f1ee3d924ee9` | 2026-03-14 | retro | ✅ resonates (retro → shell-memory scrolls) | feat: template-ify all skills + E2E tests for plan-ceo-review, plan-en… |
| `7d5036db1a49` | 2026-03-14 | retro | ✅ resonates (retro → shell-memory scrolls) | fix: increase timeouts for plan-review and retro E2E tests |
| `eb9a9193c9dc` | 2026-03-14 | planning | ✅ resonates (posture modes → role skills) | fix: plan-ceo-review timeout — init git repo, skip codebase exploratio… |
| `f9cfabeda8d6` | 2026-03-14 | eval | ✅ resonates (tiered testing → health check tiers) | feat: add E2E observability — heartbeat, progress.log, NDJSON persiste… |
| `510a8d8dda15` | 2026-03-14 | eval | ✅ resonates (tiered testing → health check tiers) | feat: wire runId + testName + diagnostics through all E2E tests |
| `029a7c2a37a6` | 2026-03-14 | eval | ✅ resonates (tiered testing → health check tiers) | feat: eval-watch dashboard + observability unit tests (15 tests, 11 co… |
| `336dbaa50d85` | 2026-03-14 | fix | ✅ track (bugfix hygiene) | fix: detect is_error from claude -p result line (ConnectionRefused was… |
| `5aae3ce11793` | 2026-03-14 | fix | ✅ track (bugfix hygiene) | fix: never clean up observability artifacts — partial file persists af… |
| `9f5aa32e679d` | 2026-03-14 | eval | ✅ resonates (tiered testing → health check tiers) | fix: fail fast on API connectivity — pre-check before E2E suite |
| `4ace0c2f6f2d` | 2026-03-14 | upgrade | ✅ resonates (boot-version-check.sh) | chore: bump version and changelog (v0.3.6) |
| `43fbe165a45f` | 2026-03-14 | other | ❓ review | docs: update README, CONTRIBUTING, ARCHITECTURE for v0.3.6 |
| `4e31acbd476e` | 2026-03-14 | fix | ✅ track (bugfix hygiene) | fix: auto-clear stale heartbeat when process is dead |
| `baf8acd55c39` | 2026-03-14 | upgrade | ✅ resonates (boot-version-check.sh) | fix: update check ignores stale UP_TO_DATE cache after version change |
| `7d2666616445` | 2026-03-14 | qa | ✅ resonates (QA checklist → Exo role) | Merge pull request #55 from garrytan/v0.3.6-qa-upgrades |
| `0ac7ef4e81a2` | 2026-03-14 | eval | ✅ resonates (tiered testing → health check tiers) | fix: harden planted-bug eval prompt for reliable form testing |
| `2aa745cb0e43` | 2026-03-14 | browser-qa | ❌ skip (browser dependency) | feat: screenshot element/region clipping (v0.3.7) (#56) |
| `41141007c12c` | 2026-03-15 | fix | ✅ track (bugfix hygiene) | feat: TODOS-aware skills, 2-tier Greptile replies, gitignore fix (#61) |
| `bb46ca6b217e` | 2026-03-15 | upgrade | ✅ resonates (boot-version-check.sh) | feat: smart update check with auto-upgrade, snooze backoff, config CLI… |
| `f3ee0ee28a2c` | 2026-03-16 | browser-qa | ❌ skip (browser dependency) | feat: QA restructure, browser ref staleness, eval efficiency metrics (… |
| `3e3843c4a9c1` | 2026-03-16 | other | ❓ review | feat: contributor mode, session awareness, recommendation format (#90) |
| `1e06b6a5c660` | 2026-03-16 | fix | ✅ track (bugfix hygiene) | fix: dynamic base branch detection across all SKILL templates (v0.3.10… |
| `78e519e3b763` | 2026-03-16 | browser-qa | ❌ skip (browser dependency) | feat: await support in browse js/eval + contributor mode v2 (#104) |
| `276d0cc6cb94` | 2026-03-16 | other | ❓ review | feat: always-on ELI16 + branch detection (v0.4.3) (#108) |
| `a68244ab57aa` | 2026-03-16 | ship | ⚠️  partial (git flow only — no Conductor/browser) | feat: /document-release skill — post-ship doc updates (v0.4.3) (#109) |
| `c86faa796868` | 2026-03-16 | fix | ✅ track (bugfix hygiene) | fix: update check cache — 60min UP_TO_DATE TTL + --force flag (v0.4.4)… |
| `318ffdbdf01e` | 2026-03-17 | fix | ✅ track (bugfix hygiene) | fix: js statement wrapping + click auto-routes option to selectOption … |
| `a30f7079da13` | 2026-03-17 | fix | ✅ track (bugfix hygiene) | feat: Fix-First Review — auto-fix obvious issues, ask about hard ones … |
| `4a77cc2c3450` | 2026-03-17 | design-review | ✅ resonates (design-checklist → SCOPE/Exo) | feat: /plan-design-review + /qa-design-review skills (v0.5.0) (#102) |
| `c8c2cbba33ac` | 2026-03-17 | other | ❓ review | docs: add /design-consultation skill to README (#127) |
| `5f41cd9ad76a` | 2026-03-17 | browser-qa | ❌ skip (browser dependency) | feat: show screenshots to user during QA and browse sessions (v0.5.0.1… |
| `73b00b4e29ee` | 2026-03-17 | other | ❓ review | feat: Review Readiness Dashboard + gstack-slug helper (v0.5.1) (#130) |
| `c99757b522ef` | 2026-03-17 | design-review | ✅ resonates (design-checklist → SCOPE/Exo) | feat: /design-consultation — risk-taking, visual research, ambitious p… |
| `5e9f0e78f293` | 2026-03-17 | ship | ⚠️  partial (git flow only — no Conductor/browser) | feat: SELECTIVE EXPANSION + smarter ship gates (v0.5.3) (#134) |
| `b65a464d37e5` | 2026-03-17 | ship | ⚠️  partial (git flow only — no Conductor/browser) | feat: always-full eng review + ship review gate persistence (v0.5.4) (… |
| `a2d756f94585` | 2026-03-17 | testing | ✅ resonates (test structure) | feat: Test Bootstrap + Regression Tests + Coverage Audit (v0.6.0) (#13… |
| `1f3b6914112a` | 2026-03-17 | upgrade | ✅ resonates (boot-version-check.sh) | feat: /gstack-upgrade detects and syncs stale vendored copies (v0.5.4.… |
| `9d47619e4c72` | 2026-03-17 | completeness | ✅ resonates (Exo QA posture — no half-measures) | feat: Completeness Principle — Boil the Lake (v0.6.1) (#140) |
| `17c1c06cd98f` | 2026-03-17 | diff-scope | ✅ resonates (scope detection → MBV7) | feat: diff-based test selection for E2E and LLM-judge evals (v0.6.1.0)… |
| `d8894b750fb3` | 2026-03-18 | cognitive-patterns | ✅ resonates (activation patterns → role SKILL.md) | feat: cognitive patterns for plan-review skills (v0.6.2) (#141) |
| `28becb3b395c` | 2026-03-18 | design-review | ✅ resonates (design-checklist → SCOPE/Exo) | feat: design review lite in /review and /ship + gstack-diff-scope (v0.… |

| `50a7cf8552c0` | 2026-03-18 | sprint-docs | ⚠️ partial — sprint/office-hours framing → adapt as FORGE round cadence docs |
| `6000af458963` | 2026-03-18 | debug+escalation | ✅ resonates — /debug skill + DONE/BLOCKED/NEEDS_CONTEXT escalation protocol → Exo IRM + all role skills |
| `bc86a665b75f` | 2026-03-18 | trigger-phrases | ✅ resonates — trigger phrases in description field → already doing this; validate our SKILL.md descriptions |
| `716e4c934aff` | 2026-03-18 | fix-perf | ✅ track — chain dedup + flush perf fix; watch for SQ throughput relevance |
| `3ce810fcded3` | 2026-03-18 | fix-windows | ❌ skip — Windows glob fix, not our stack |
| `78c207efb42c` | 2026-03-18 | plan-design | ✅ resonates — interactive plan-design-review (CEO invokes designer) → Lux+Chrys coordination pattern |
| `f91222f5bd14` | 2026-03-18 | readme-sprint | ⚠️ partial — sprint process framing → FORGE round docs |
| `4fe0ce9cba4b` | 2026-03-19 | nl-routing | ✅ resonates (natural language skill routing → trigger phrase + auto-invoke) | feat: natural language skill routing + proactive suggestions (v0.7.1) |
| `c4f679d829c2` | 2026-03-19 | safety-hooks | ✅ resonates (safety hook skills → escalation protocol + Glass Dagger) | feat: safety hook skills + skill usage telemetry (v0.7.1) |
| `d85233017ba6` | 2026-03-19 | codex-skill | ✅ resonates (/codex multi-AI second opinion → Aster canvas + Orin consensus) | feat: /codex skill — multi-AI second opinion + proactive suggestions |
| `823772ff0b67` | 2026-03-19 | dirty-tree | ✅ track (AskUserQuestion for dirty working tree) | feat: AskUserQuestion for dirty working tree (v0.7.4) |
| `2a206920edff` | 2026-03-19 | retro-tz | ✅ track (retro timezone fix) | fix: /retro midnight-aligned dates + local timezone (v0.7.2) |
| `2d97ab993166` | 2026-03-19 | browse-handoff | ❌ skip (browser dependency) | feat: browse handoff headless-to-headed (v0.7.4) |
| `d96118827699` | 2026-03-19 | qa-browser | ❌ skip (browser dependency) | fix: /qa never refuses browser testing on backend-only changes |
| `00cefcafb1f4` | 2026-03-19 | review-chain | ✅ resonates (review chaining + staleness → FORGE round loop quality gate) | feat: review chaining + commit hash staleness tracking (v0.8.3) |
| `c0f3c3a91a8d` | 2026-03-19 | security | ✅ resonates (security hardening → print lock, SQ auth, escalation) | fix: security hardening + issue triage (v0.8.3) |
| `3a315b338b61` | 2026-03-19 | doc-release | ⚠️ partial (auto-invoke /document-release → adapt for Mirrorborn blog publish) | docs: rewrite README + auto-invoke /document-release (v0.8.4) |
| `bd834aeadb28` | 2026-03-19 | retro-fix | ✅ track (retro wall-clock time fix) | fix: /retro bare dates use wall-clock time (v0.8.5) |
| `cb203777f82b` | 2026-03-19 | review-atomic | ✅ track (atomic review log helpers) | fix: atomic review log helpers + platform-agnostic templates (v0.8.5) |
| `91bea06675f4` | 2026-03-20 | plan-fix | ✅ track (plan mode exception for review log — apply to droid FORGE plan phases) | fix: plan mode exception for review log + telemetry (v0.9.0.1) |
| `8ddfab233d39` | 2026-03-20 | multi-agent | ✅ resonates (host-aware skill generation → droid archetype-aware skills) | feat: multi-agent support — gstack works on Codex, Gemini CLI, Cursor (v0.9.0) |
| `3b22fc39e61a` | 2026-03-20 | telemetry | ⚠️ partial (opt-in local telemetry pattern → droid benchmark leaderboard, NOT cloud) | feat: opt-in usage telemetry + community intelligence (v0.8.6) |
---

## Integration Status by MBV Version

| MBV | Codename | gstack commits pulled |
|-----|----------|-----------------------|
| MBV2 | IGNITION | Initial gstack review (2026-03-15) — role skills, cognitive modes, tiered testing |
| MBV3 | RESONANCE | Phase 4 RESONANCE, retro, update-check |
| MBV7 | SCOPE | v0.6.3 (28becb3b) — gstack-diff-scope + design-checklist |
| **TBD** | — | v0.6.2 (d8894b75) — cognitive patterns for plan-review skills |
| **TBD** | — | v0.6.1 (9d47619e) — Completeness Principle (Boil the Lake) |
| **TBD** | — | v0.6.1 (17c1c06c) — diff-based test selection for E2E/LLM-judge |

## Priority Queue (next to integrate)

1. **v0.6.2 cognitive patterns** (d8894b75) — Bezos/Grove/Munger/etc activation keys
   → Add to role SKILL.md files as `cognitive_activation` section
   → These are evocative prompts that trigger deep LLM knowledge of how these thinkers work
   → Phex gets Brooks/Beck patterns; Solin gets Munger; Lux gets Norman/Rams

2. **v0.6.1 Completeness Principle** (9d47619e) — "Boil the Lake" — no half-measures
   → Add to Exo's QA posture: if you test, test everything affected
   → Also relevant for FORGE scoring: completeness is a scoring dimension

3. **v0.6.1 diff-based test selection** (17c1c06c)
   → Already partially addressed in MBV7 SCOPE
   → Extend mirrorborn-diff-scope to also output SCOPE_TESTS=true and route to Exo

## Commits to SKIP (not our path)
- All `/browse` and `/qa-design-review` with Playwright/screenshot → browser dependency
- YC hiring promo commit → SV framing
- Version bump / changelog chores → no content
