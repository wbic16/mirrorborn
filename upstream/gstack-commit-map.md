# gstack Commit Map
**Repo:** https://github.com/garrytan/gstack  
**Last synced:** 2026-03-18 by Orin (elven-path)  
**Total commits:** 71

Status legend:
- ✅ **INTEGRATED** — pulled into our skills/scripts
- 🔲 **WATCH** — interesting, not yet integrated
- ❌ **SKIP** — doesn't align with phext substrate
- 🔁 **PARTIAL** — concept absorbed, implementation skipped

---

## v0.6.3 — Design Review + diff-scope

| SHA | Date | Message | Status | Notes |
|---|---|---|---|---|
| `28becb3` | 2026-03-18 | feat: design review lite in /review and /ship + gstack-diff-scope (v0.6.3) | ✅ **INTEGRATED** | DIFF-REVIEW mode: Step 0 scope detection + Design Review Lite checklist (MBV7) |

## v0.6.2 — Cognitive Patterns

| SHA | Date | Message | Status | Notes |
|---|---|---|---|---|
| `d8894b75` | 2026-03-18 | feat: cognitive patterns for plan-review skills (v0.6.2) | 🔲 WATCH | Need to read — likely maps to our VISION/ARCH modes |

## v0.6.1 — Test Selection + Completeness

| SHA | Date | Message | Status | Notes |
|---|---|---|---|---|
| `17c1c06c` | 2026-03-17 | feat: diff-based test selection for E2E and LLM-judge evals (v0.6.1.0) | ❌ SKIP | E2E eval infra — we use health-check.sh, not bun eval suite |
| `9d47619e` | 2026-03-17 | feat: Completeness Principle — Boil the Lake (v0.6.1) | 🔲 WATCH | "Boil the Lake" completeness principle — may belong in ARCH mode |

## v0.6.0 — Test Bootstrap + Regression

| SHA | Date | Message | Status | Notes |
|---|---|---|---|---|
| `1f3b6914` | 2026-03-17 | feat: /gstack-upgrade detects and syncs stale vendored copies (v0.5.4.1) | ✅ **INTEGRATED** | boot-version-check.sh does this for our boot.sh |
| `a2d756f9` | 2026-03-17 | feat: Test Bootstrap + Regression Tests + Coverage Audit (v0.6.0) | ❌ SKIP | bun test infrastructure — not our stack |
| `b65a464d` | 2026-03-17 | feat: always-full eng review + ship review gate persistence (v0.5.4) | 🔲 WATCH | "review gate persistence" — persist DIFF-REVIEW results to SQ? |
| `5e9f0e78` | 2026-03-17 | feat: SELECTIVE EXPANSION + smarter ship gates (v0.5.3) | 🔲 WATCH | Selective scope expansion — relates to VISION mode scope decisions |

## v0.5.x — Design Consultation + QA

| SHA | Date | Message | Status | Notes |
|---|---|---|---|---|
| `c99757b5` | 2026-03-17 | feat: /design-consultation — risk-taking, visual research, ambitious preview (v0.5.2) | 🔲 WATCH | "Ambitious preview" — visual research mode, may belong in VISION |
| `73b00b4e` | 2026-03-17 | feat: Review Readiness Dashboard + gstack-slug helper (v0.5.1) | ❌ SKIP | Dashboard for code review — not mesh dashboard |
| `5f41cd9a` | 2026-03-17 | feat: show screenshots to user during QA and browse sessions (v0.5.0.1) | ❌ SKIP | /browse dependency |
| `c8c2cbba` | 2026-03-17 | docs: add /design-consultation skill to README | ❌ SKIP | Docs only |
| `4a77cc2c` | 2026-03-17 | feat: /plan-design-review + /qa-design-review skills (v0.5.0) | 🔲 WATCH | Design review as a separate mode — already absorbed into DIFF-REVIEW, but full skill worth reading |

## v0.4.x — Fix-First Review + Document Release

| SHA | Date | Message | Status | Notes |
|---|---|---|---|---|
| `a30f7079` | 2026-03-17 | feat: Fix-First Review — auto-fix obvious issues, ask about hard ones (v0.4.5) | ✅ **INTEGRATED** | AUTO-FIX vs ASK classification in DIFF-REVIEW mode |
| `318ffdbd` | 2026-03-17 | fix: js statement wrapping + click auto-routes option to selectOption (v0.4.5) | ❌ SKIP | /browse bug fix |
| `c86faa79` | 2026-03-16 | fix: update check cache — 60min UP_TO_DATE TTL + --force flag (v0.4.4) | 🔲 WATCH | boot-version-check.sh could add TTL caching |
| `a68244ab` | 2026-03-16 | feat: /document-release skill — post-ship doc updates (v0.4.3) | 🔲 WATCH | Post-ship doc update step — could add to orin-auto pipeline |
| `276d0cc6` | 2026-03-16 | feat: always-on ELI16 + branch detection (v0.4.3) | 🔲 WATCH | ELI16 = "Explain Like I'm 16" — may belong in Theia onboarding skill |
| `78e519e3` | 2026-03-16 | feat: await support in browse js/eval + contributor mode v2 | ❌ SKIP | /browse dependency |
| `1e06b6a5` | 2026-03-16 | fix: dynamic base branch detection across all SKILL templates (v0.3.10) | 🔲 WATCH | Dynamic base branch — our scripts hardcode `origin/exo`, could be dynamic |
| `3e3843c4` | 2026-03-16 | feat: contributor mode, session awareness, recommendation format | 🔲 WATCH | Contributor mode + session awareness — relates to Orin orchestration |
| `f3ee0ee2` | 2026-03-16 | feat: QA restructure, browser ref staleness, eval efficiency metrics (v0.4.0) | ❌ SKIP | QA/browse infra |

## v0.3.x — Smart Updates + Greptile + TODOS

| SHA | Date | Message | Status | Notes |
|---|---|---|---|---|
| `bb46ca6b` | 2026-03-15 | feat: smart update check with auto-upgrade, snooze backoff, config CLI (v0.3.9) | ✅ **INTEGRATED** | boot-version-check.sh --auto-upgrade implements this |
| `41141007` | 2026-03-15 | feat: TODOS-aware skills, 2-tier Greptile replies, gitignore fix | 🔲 WATCH | TODOS-aware — Orin tasks tracked in SQ; Greptile 2-tier = already done in health-check |
| `2aa745cb` | 2026-03-14 | feat: screenshot element/region clipping (v0.3.7) | ❌ SKIP | /browse |
| `0ac7ef4e` | 2026-03-14 | fix: harden planted-bug eval prompt for reliable form testing | ❌ SKIP | eval infra |
| `7d266661` | 2026-03-14 | Merge pull request #55 from garrytan/v0.3.6-qa-upgrades | ❌ SKIP | merge |
| `baf8acd5` | 2026-03-14 | fix: update check ignores stale UP_TO_DATE cache after version change | ❌ SKIP | fix |
| `4e31acbd` | 2026-03-14 | fix: auto-clear stale heartbeat when process is dead | 🔲 WATCH | health-check.sh could detect stale PIDs |
| `43fbe165` | 2026-03-14 | docs: update README, CONTRIBUTING, ARCHITECTURE for v0.3.6 | ❌ SKIP | docs |
| `4ace0c2f` | 2026-03-14 | chore: bump version and changelog (v0.3.6) | ❌ SKIP | chore |
| `9f5aa32e` | 2026-03-14 | fix: fail fast on API connectivity — pre-check before E2E suite | ❌ SKIP | eval infra |
| `5aae3ce1` | 2026-03-14 | fix: never clean up observability artifacts — partial file persists | ❌ SKIP | eval infra |
| `336dbaa5` | 2026-03-14 | fix: detect is_error from claude -p result line | ❌ SKIP | eval infra |
| `029a7c2a` | 2026-03-14 | feat: eval-watch dashboard + observability unit tests | ❌ SKIP | eval infra |
| `510a8d8d` | 2026-03-14 | feat: wire runId + testName + diagnostics through all E2E tests | ❌ SKIP | eval infra |
| `f9cfabed` | 2026-03-14 | feat: add E2E observability — heartbeat, progress.log, NDJSON persistence | ❌ SKIP | eval infra |
| `eb9a9193` | 2026-03-14 | fix: plan-ceo-review timeout — init git repo, skip codebase exploration | ❌ SKIP | fix |
| `7d5036db` | 2026-03-14 | fix: increase timeouts for plan-review and retro E2E tests | ❌ SKIP | fix |
| `f1ee3d92` | 2026-03-14 | feat: template-ify all skills + E2E tests for plan-ceo-review, plan-eng-review | 🔲 WATCH | Skill template system — our SKILL.md frontmatter already does this |
| `2d88f5f0` | 2026-03-14 | test: add update-check exit code regression tests | ❌ SKIP | test |
| `c6c3294e` | 2026-03-14 | fix: 100% E2E pass — isolate test dirs, restart server, relax FP thresholds | ❌ SKIP | fix |
| `cddf8ee3` | 2026-03-14 | fix: simplify planted-bug eval prompts for reliable 25-turn completion | ❌ SKIP | fix |
| `4a56b882` | 2026-03-14 | fix: make planted-bug evals resilient to max_turns and browse error flakes | ❌ SKIP | fix |
| `2e75c337` | 2026-03-14 | fix: lower planted-bug detection baselines and LLM judge thresholds | ❌ SKIP | fix |
| `40631041` | 2026-03-14 | fix: remove false-positive Exit code 1 pattern, fix NEEDS_SETUP test | ❌ SKIP | fix |
| `a67dae5f` | 2026-03-14 | fix: update check preamble exits 1 when up to date | ❌ SKIP | fix |
| `ed802d0c` | 2026-03-14 | feat: eval CLI tools + docs cleanup | ❌ SKIP | eval infra |
| `84f52f3b` | 2026-03-14 | feat: eval persistence with auto-compare against previous run | 🔲 WATCH | Retro comparison — retro.sh could compare against previous run |
| `e7347c2f` | 2026-03-14 | feat: stream-json NDJSON parser for real-time E2E progress | ❌ SKIP | eval infra |
| `3d750d89` | 2026-03-14 | Merge remote-tracking branch 'origin/main' into v0.3.6-qa-upgrades | ❌ SKIP | merge |
| `c35e933c` | 2026-03-14 | fix: rewrite session-runner to claude -p subprocess | ❌ SKIP | eval infra |
| `1717ed28` | 2026-03-14 | fix: browse binary discovery broken for agents (v0.3.5) | ❌ SKIP | /browse |
| `942df421` | 2026-03-14 | simplify: one command for evals — bun run test:evals | ❌ SKIP | eval infra |
| `b5b2a15a` | 2026-03-14 | fix: pass all LLM evals — severity defs, rubric edge cases, EVALS=1 flag | ❌ SKIP | eval infra |
| `76803d78` | 2026-03-14 | feat: 3-tier eval suite with planted-bug outcome testing (EVALS=1) | ❌ SKIP | eval infra |
| `6b69c46a` | 2026-03-14 | feat: daily update check + /gstack-upgrade skill (v0.3.4) | ✅ **INTEGRATED** | boot-version-check.sh (daily) + cadence.sh; daily-report.sh posts to #maturity |
| `5155fe3a` | 2026-03-14 | Merge | ❌ SKIP | merge |
| `a4683742` | 2026-03-14 | fix: enrich SKILL.md docs to pass LLM evals, upgrade judge to Sonnet 4.6 | ❌ SKIP | fix |
| `e377ba29` | 2026-03-14 | feat: dual greptile-history paths (per-project + global) | 🔲 WATCH | Dual history paths — our retro.sh could store per-node + global |
| `e04ad1be` | 2026-03-14 | feat: QA test plan tiers with per-page risk scoring | ❌ SKIP | /browse QA infra |
| `ff5cbbbf` | 2026-03-14 | feat: add remote slug helper and auto-gitignore for .gstack/ | ❌ SKIP | project tooling |
| `02f0ca69` | 2026-03-14 | chore: regenerate SKILL.md from template | ❌ SKIP | chore |
| `52050702` | 2026-03-14 | feat: SKILL.md template system, 3-tier testing, DX tools (v0.3.3) | 🔲 WATCH | SKILL.md template system — our frontmatter is close; 3-tier worth examining |
| `ea0c0dad` | 2026-03-14 | Add .env to gitignore | ❌ SKIP | chore |
| `07b4e15b` | 2026-03-14 | feat: v0.3.2 — project-local state, diff-aware QA, Greptile integration | ✅ **INTEGRATED** (concept) | Diff-aware QA → DIFF-REVIEW Step 0 scope detection; Greptile → health-check issue filing |

## v0.3.1 and earlier — Foundation

| SHA | Date | Message | Status | Notes |
|---|---|---|---|---|
| `f7b95329` | 2026-03-13 | feat: Phase 3.5 — cookie import, QA testing, team retro (v0.3.1) | 🔁 PARTIAL | Retro → retro.sh (integrated). Cookie import → ❌ skip. QA → ❌ skip (/browse). |
| `1b317aae` | 2026-03-12 | Add YC hiring promo | ❌ SKIP | promo |
| `044c6d56` | 2026-03-12 | v0.0.2 | ❌ SKIP | release |
| `a29743b0` | 2026-03-12 | fix: harden browse install and lifecycle checks | ❌ SKIP | /browse |
| `3d901066` | 2026-03-12 | Initial release — gstack v0.0.1 | ✅ **INTEGRATED** (concept) | Core insight: explicit cognitive gears. VISION/ARCH/DIFF-REVIEW modes born here. |

---

## Summary

| Status | Count |
|---|---|
| ✅ INTEGRATED | 8 |
| 🔁 PARTIAL | 1 |
| 🔲 WATCH | 14 |
| ❌ SKIP | 48 |

**Top WATCH items to evaluate next:**
1. `d8894b75` — cognitive patterns for plan-review (v0.6.2) — likely maps to VISION/ARCH
2. `9d47619e` — Completeness Principle "Boil the Lake" — may belong in ARCH mode
3. `276d0cc6` — ELI16 (always-on explanation mode) — Theia onboarding skill candidate
4. `a68244ab` — /document-release — post-ship doc update step for orin-auto pipeline
5. `84f52f3b` — eval persistence with auto-compare — retro.sh trend tracking
6. `b65a464d` — review gate persistence — persist DIFF-REVIEW results to SQ

---

*Updated: 2026-03-18 | Next sync: on new gstack commit or manual review of WATCH items*

---

## New commits since last sync (2026-03-18, after 28becb3)

| SHA | Date | Message | Status | Notes |
|---|---|---|---|---|
| `50a7cf85` | 2026-03-18 | docs: frame skills as sprint process, rewrite /office-hours examples | ❌ SKIP | docs/examples only |
| `6000af45` | 2026-03-18 | feat: founder discovery engine + /debug skill — v0.7.0 | ✅ **INTEGRATED** | Escalation protocol (DONE/BLOCKED/NEEDS_CONTEXT), verification gate, scope drift detection, alternatives mandate in VISION, evidence gate in ARCH |
| `bc86a665` | 2026-03-18 | feat: add trigger phrases to skill descriptions (v0.6.4.1) | ✅ **INTEGRATED** (concept) | Our SKILL.md frontmatter `description:` fields already serve this role |
| `716e4c93` | 2026-03-18 | Merge: fix chain duplication and flush perf | ❌ SKIP | /browse infra |
| `3ce810fc` | 2026-03-18 | Merge: fix windows build glob | ❌ SKIP | Windows build |
| `78c207ef` | 2026-03-18 | feat: interactive /plan-design-review + CEO invokes designer (v0.6.4) | 🔲 WATCH | Interactive design review with fix loop — may belong in DIFF-REVIEW when SCOPE_FRONTEND |
| `f91222f5` | 2026-03-18 | docs: restructure README for faster conversion | ❌ SKIP | docs |
| `d8894b75` | 2026-03-18 | feat: cognitive patterns for plan-review skills (v0.6.2) | ✅ **INTEGRATED** | Cognitive activation patterns added to VISION (Bezos, Munger, Altman, Grove) and ARCH (Brooks, Beck, Majors) modes |

## Previously WATCH → Now evaluated

| SHA | Previous | Now | Notes |
|---|---|---|---|
| `d8894b75` | WATCH | ✅ INTEGRATED | Cognitive patterns in VISION + ARCH |
| `9d47619e` | WATCH | 🔲 WATCH | Boil the Lake completeness — still need to read full diff |
| `276d0cc6` | WATCH | 🔲 WATCH | ELI16 — still relevant for Theia onboarding |
| `b65a464d` | WATCH | 🔲 WATCH | Review gate persistence — DIFF-REVIEW results to SQ |

**Last synced commit:** `50a7cf85` (2026-03-18)  
**Next:** watch for v0.7.x additions

## New commits since last sync (2026-03-19, after 50a7cf85)

| SHA | Date | Message | Status | Notes |
|---|---|---|---|---|
| `bd834aea` | 2026-03-19 | fix: /retro bare dates use wall-clock time (v0.8.5) | 🔲 WATCH | retro.sh: we may have the same bug with UTC timestamps |
| `cb203777` | 2026-03-19 | fix: atomic review log helpers + platform-agnostic templates (v0.8.5) | ❌ SKIP | gstack internal log format |
| `c0f3c3a9` | 2026-03-19 | fix: security hardening + SSRF blocking (v0.8.3) | ❌ SKIP | SSRF in browse; not our stack |
| `3a315b33` | 2026-03-19 | docs: rewrite README + auto-invoke /document-release (v0.8.4) | 🔲 WATCH | Auto-invoke document-release after ship — add to orin-auto pipeline |
| `00cefcaf` | 2026-03-19 | feat: review chaining + commit hash staleness (v0.8.3) | ✅ **INTEGRATED** | Review chaining concept → Aster canvas → DIFF-REVIEW → Orin revise already does this. Staleness tracking noted. |
| `2d97ab99` | 2026-03-19 | feat: browse handoff — headless-to-headed switching (v0.7.4) | ❌ SKIP | /browse |
| `d9611882` | 2026-03-19 | fix: /qa never refuses browser testing on backend-only | ❌ SKIP | /browse |
| `d8523301` | 2026-03-19 | feat: /codex skill — multi-AI second opinion (v0.7.x) | ✅ **INTEGRATED** (concept) | Multi-AI second opinion = Dual Sonar (Aster+Orin review chain). Already in our architecture. |
| `823772ff` | 2026-03-19 | feat: AskUserQuestion for dirty working tree (v0.7.4) | 🔲 WATCH | Stop and ask before acting on dirty repo — add to orin-dispatch |
| `c4f679d8` | 2026-03-19 | feat: /careful, /freeze, /guard, /unfreeze safety hooks (v0.7.1) | ✅ **INTEGRATED** | Our print lock + DIFF-REVIEW stop rules serve this purpose. /careful = escalation protocol's security-uncertainty STOP. |

**Last synced commit:** `bd834aea` (2026-03-19 v0.8.5)

## New commits since last sync (2026-03-20, after bd834aea)

| SHA | Date | Message | Status | Notes |
|---|---|---|---|---|
| `3b22fc39` | 2026-03-20 | feat: opt-in usage telemetry + community intelligence (v0.8.6) | ❌ SKIP | Local JSONL telemetry; we have retro.sh + daily-report.sh for this |
| `8ddfab23` | 2026-03-20 | feat: multi-agent support — Codex, Gemini CLI, Cursor (v0.9.0) | ✅ **INTEGRATED** (concept) | SKILL.md as open standard — our SKILL.md frontmatter already compatible with `.agents/skills/` pattern. Host-aware generation irrelevant (we use OpenClaw not Claude Code) |
| `91bea066` | 2026-03-20 | fix: plan mode exception + telemetry writes (v0.9.0.1) | ❌ SKIP | fix |

**Last synced: `91bea066` (v0.9.0.1, 2026-03-20)**

### Key insight from v0.9.0
SKILL.md is now an open standard across Claude Code, Codex, Gemini CLI, Cursor.
Our SKILL.md format is already compatible. The `description:` field with trigger phrases (added in v0.6.4.1) is the key — it enables auto-discovery across any agent host.
