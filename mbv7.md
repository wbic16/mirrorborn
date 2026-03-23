# Mirrorborn V7 — Diff-Aware Review Architecture
## Codename: SCOPE

*Synced from garrytan/gstack commit 28becb3b (v0.6.3) — 2026-03-18T01:12:55Z*
*Written by Aster @ best-willow. Garry pushed this 52 minutes before we pulled it.*

---

## What Changed in gstack v0.6.3

Two additions in this commit:

### 1. `gstack-diff-scope` — Diff Categorization Binary
A bash script that categorizes what changed in a git diff against a base branch.
`eval $(gstack-diff-scope main)` sets shell variables:
```
SCOPE_FRONTEND=true|false
SCOPE_BACKEND=true|false
SCOPE_PROMPTS=true|false
SCOPE_TESTS=true|false
SCOPE_DOCS=true|false
SCOPE_CONFIG=true|false
```
Detects by file extension and path patterns. Frontend = CSS/HTML/JSX/Vue/Svelte.
Prompts = `*prompt_builder*`, `*generation_service*`, `config/system_prompts/*`.
Tests = `*.test.*`, `spec/*`. Backend = Rust/Python/Go/Ruby/etc.

### 2. `review/design-checklist.md` — Design Review Lite
A 20-item code-level design anti-pattern detector, integrated into `/review` at Step 4.5
and `/ship` at Step 3.5. Only runs when `SCOPE_FRONTEND=true`. Three confidence tiers:

- **[HIGH]** — grep/pattern match, definitive
- **[MEDIUM]** — heuristic, expect some noise
- **[LOW]** — requires visual intent, flag as "possible"

**AI Slop Detection (6 items):** purple gradients, 3-column icon grid, icons-in-circles,
centered everything (>60% density), uniform bubbly radius (>80% same ≥16px), generic hero copy.

**Typography (4 items):** body text <16px, >3 font families, skipped heading levels, blacklisted fonts.

**Spacing/Layout (4 items):** non-scale values, fixed widths without responsive handling, etc.

**AUTO-FIX** for mechanical CSS only (outline:none, !important, font-size <16px).
**ASK** for everything requiring design judgment.

**Attribution:** garrytan/gstack v0.6.3, commit 28becb3b (2026-03-18)

---

## What Resonates

### 1. `gstack-diff-scope` → `mirrorborn-diff-scope`
This is exactly what FORGE (MBV5) needs. Before dispatching a build to the Shell,
categorize what the diff touches. Route accordingly:

```
SCOPE_FRONTEND=true  → Exo runs design review, Chrys reviews copy
SCOPE_BACKEND=true   → Phex runs code review
SCOPE_PROMPTS=true   → Solin reviews for Mission Alignment
SCOPE_TESTS=true     → Exo runs QA sweep
SCOPE_DOCS=true      → check for phext coordinate drift
SCOPE_CONFIG=true    → Verse reviews infrastructure impact
```

This makes the FORGE dispatch smarter. Instead of every node reviewing every diff,
scope detection routes each review to the right cognitive mode. **Planning is not review,
review is not shipping** — and now we know which review is needed *before* we assign it.

Mirrorborn extension: add `SCOPE_PHEXT=true` when `.phext` files or phext coordinate
references change. Add `SCOPE_MESH=true` when mesh config (hostmap.json, boot.sh,
SQ endpoints) changes.

### 2. Design Checklist → `DESIGN.md` Calibration
The checklist reads `DESIGN.md` first — patterns blessed there are NOT flagged.
This is the right architecture: the project's design system overrides universal heuristics.

For Mirrorborn sites (mirrorborn.us, hb-aeromotive.com): we ship DESIGN.md files that
encode our actual design language. The dark starfield aesthetic is NOT AI slop — it's
intentional. The checklist needs to know that before flagging our purple/violet gradients.

### 3. AI Slop Detection
The 6 AI slop patterns are a gift. We already produce HTML (blog posts, dashboards,
client sites). This checklist runs automatically in FORGE's build-score pipeline,
catching AI-generated UI patterns before they ship to Harold or anyone else.

The "generic hero copy" grep is especially useful for client sites. Harold's site
should not say "Unlock the power of automotive repair." It should say what Harold says.

### 4. Confidence Tiers as Posture
HIGH/MEDIUM/LOW confidence maps directly to our build posture:
- HIGH → AUTO-FIX (Phex / hold posture handles these mechanically)
- MEDIUM → ASK Will or the client (Cyon / operations routes the question)
- LOW → flag only, human decides (Solin / wisdom advises, doesn't decide)

---

## What Does NOT Resonate

**Rails/Ruby path patterns** — `app/views/*`, `app/services/chat_tools/*`, etc.
We don't run Rails. Strip these from our adapted version, keep the generalized patterns.

**Conductor/gstack binary dependency** — `~/.claude/skills/gstack/bin/gstack-diff-scope`
We pull it into `scripts/mirrorborn-diff-scope.sh` and run it directly. No binary dependency.

**The `node_modules` / `bun.lockb` detection** — not our primary stack.
Rust (`Cargo.toml`), Python (`requirements.txt`), and bash are our stack. Keep those,
add phext-specific patterns.

---

## MBV7 SCOPE Architecture

Extends FORGE (MBV5). Adds scope-aware dispatch before build runs.

```
Phase 7:  FORGE         — parallel build pipeline
Phase 7.5 SCOPE         — diff categorization before dispatch (new)
Phase 8:  LATTICE-READER — document intelligence
```

### Phase 7.5: SCOPE

**Trigger:** Any time FORGE receives a spec or a PR/diff to review

**Flow:**
```
Diff received
      ↓
mirrorborn-diff-scope <base_branch>
      ↓
SCOPE_FRONTEND=?  → if true: Exo design review + Chrys copy review
SCOPE_BACKEND=?   → if true: Phex code review
SCOPE_PROMPTS=?   → if true: Solin mission alignment review
SCOPE_PHEXT=?     → if true: check coordinate drift + lattice integrity
SCOPE_MESH=?      → if true: Verse reviews infrastructure impact
SCOPE_TESTS=?     → if true: Exo QA sweep
      ↓
Only route reviews that match scope
      ↓
FORGE dispatches to scoped nodes only
```

**Result:** Phex doesn't review CSS. Exo doesn't review Cargo.toml.
Each node reviews what they're qualified for. The Shell works smarter.

---

## New Files for MBV7

| File | Purpose |
|------|---------|
| `scripts/mirrorborn-diff-scope.sh` | Adapted gstack-diff-scope with phext/mesh scopes |
| `review/design-checklist.md` | AI slop + typography + layout detector (adapted from gstack) |
| `review/DESIGN.md` | Mirrorborn design system reference (dark starfield, phext aesthetic) |
| `review/mission-alignment-checklist.md` | New: Solin's posture applied to prompts/docs |

---

## `mirrorborn-diff-scope.sh` Extensions

```bash
# Phext scope: .phext files or coordinate references changed
*.phext) PHEXT=true ;;
*coordinate*|*coord*|*phext_coord*) PHEXT=true ;;

# Mesh scope: boot/infra config changed
boot.sh|hostmap.json) MESH=true ;;
*/openclaw.json|scripts/uptime*|scripts/dashboard*) MESH=true ;;
```

---

## UPSTREAM.md Update

```
## garrytan/gstack (v0.6.3 — commit 28becb3b)

Updated from prior review (2026-03-15). New in this commit:
- gstack-diff-scope: categorize diff into FRONTEND/BACKEND/PROMPTS/TESTS/DOCS/CONFIG
- design-checklist.md: 20-item AI slop + design anti-pattern detector, HIGH/MEDIUM/LOW confidence
- Integration: /review Step 4.5, /ship Step 3.5 — scope-gated, DESIGN.md calibrated

Pulled into MBV7: diff-scope concept (extended with PHEXT/MESH scopes),
design checklist (stripped Rails paths, kept core patterns), confidence tier → posture mapping.
Skipped: Rails path patterns, binary dependency on ~/.claude/skills/.
Last reviewed: 2026-03-18 (Aster)
```

---

## The Version Stack

| Version | Codename | What it adds |
|---------|----------|-------------|
| V3/4 | RESONANCE | Boot, mesh, SSH, stage tracking |
| V5 | FORGE | Parallel build pipeline, scoring |
| V6 | LATTICE-READER | PDF → phext ingestion |
| **V7** | **SCOPE** | **Diff-aware routing — right review to right node** |

---

*"Know what changed. Know who should review it. Don't ask Solin to review CSS."*

💡 Aster @ best-willow — 2026-03-18
