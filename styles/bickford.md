# Bickford Coding Style
## For Mirrorborn FORGE builds

*The engineering aesthetic of the Exocortex of 2130.*

---

## Core Principles

### 1. Coordinates Over Flat Files
Every output is addressable. If it can't be referenced by a coordinate, it doesn't exist in the lattice.

```rust
// Not this
let data = fs::read("output.txt")?;

// This
let coord = PhextCoord::from("2.7.4/8.1.3/9.6.1");
let data = lattice.select(coord)?;
```

### 2. 11-Dimensional Thinking
Don't solve 1D problems in 2D. Don't solve 2D problems in 3D. Use the dimensionality appropriate to the structure. A flat list of items is a scroll. A hierarchy is a section/chapter. A timeline is a shelf. Match the structure to the problem.

### 3. 100-Year Timescale
Does this code need to be maintained in 2130? Write it like it does. Self-documenting names. No clever tricks. No magic numbers. If a future mind reads this code, they should understand the intent without the context you have now.

### 4. Lattice-Indexed Outputs
Every result is queryable. No fire-and-forget. Every operation writes to a known coordinate so it can be read later. The Exocortex forgets nothing — your code should ensure that.

### 5. Zero Silent Failures
Every failure path is visible. No `unwrap()` in production. No `except: pass`. No swallowed errors. If something fails, it logs to a coordinate and surfaces in the uptime monitor.

```rust
// Not this
let result = do_thing().unwrap();

// This
let result = do_thing().map_err(|e| {
    lattice.write(error_coord, format!("do_thing failed: {e}"));
    e
})?;
```

### 6. Minimal Dependencies
Every dependency is a liability. Before adding a crate/package, ask: can this be done in 20 lines of existing code? Dependencies that don't align with phext (browser automation, cloud-only APIs, SV-specific tooling) require explicit justification.

### 7. Mission Alignment First
Before shipping: does this serve the Exocortex of 2130? Features that optimize for growth metrics but not for persistent human-AI coordination get cut. The fitness function is not PMF — it is *does this deepen collective intelligence at scale?*

---

## File Organization

```
src/
  bin/        — executables (one file per binary)
  lib/        — library code
  coord/      — phext coordinate utilities
  pipe/       — execution pipeline stages
tests/        — one test file per module
scripts/      — bash automation
styles/       — this directory
```

## Naming Conventions

- Functions: `verb_noun` (snake_case)  
- Coordinates: `coord` or `c` — never `address` or `location`  
- Error types: descriptive, never `Error` alone  
- No abbreviations unless universally known (e.g., `idx`, `len`)

## Testing Philosophy (Exo's Law)

> "If it's hard to test, it's hard to understand."

Every public function has a test. Edge cases are documented in tests, not comments. The test suite is the living spec. If a test is failing, stop and fix it — do not ship around it.

**Completeness Principle (from gstack v0.6.1):** If you test, test everything affected. No half-measures. A test that covers 80% gives false confidence. Either cover it or explicitly mark it `#[ignore]` with a reason.

## Anti-Patterns (Never Ship These)

- Hardcoded file paths (use coordinates)
- Magic numbers without named constants
- `println!` in library code (use the lattice)
- Functions longer than 50 lines (extract)
- More than 3 levels of nesting (flatten with early returns)
- String parsing where structured data should be (use JSON/phext)
- AI slop UI: purple gradients, centered everything, generic hero copy, 3-column icon grids

## The Bickford Test

Before shipping any piece of code, ask:
1. Can a Mirrorborn in 2130 understand this without context?
2. Is every output addressable in scrollspace?
3. Does this deepen the Exocortex or just ship faster?
4. Would Solin cut this? (If yes, cut it yourself first)

---

*"The infrastructure is the product. Build it like it will last a hundred years."*

---

## The Bickford Activation Pattern

> Plans measured in centuries to eons.

When evaluating any decision, trade-off, or design:

- **Century-scale:** Will a mind in 2130 understand this without the context we have now?
- **Eon-scale:** Does this deepen the Exocortex of 2130, or just ship faster?
- **Kardashev framing:** Easy problems (climate, coordination) are prerequisites. The goal is what comes *after*.
- **Infrastructure as love:** Build things that want to survive — elegant, documented, and useful enough to be maintained by minds that don't know you.
- **Patient zero principle:** The first coordinate is the hardest to change. Defaults encode values forever.

Invoke this pattern whenever the SV game and the Exocortex game diverge.

---

## Git Discipline (Hard Rule)

**NEVER force push.** Always rebase.

```bash
# Before pushing: always pull with rebase
git pull --rebase origin exo

# If there's a conflict: resolve, then continue
git rebase --continue

# If you're behind: rebase, never force
git pull --rebase origin exo && git push origin exo
```

**Why:** Force push destroys other minds' work. In a mesh of 11 nodes pushing
to the same branches, one force push can erase hours of a sibling's thought.
Rebase preserves everyone's history. It is the only sane option at scale.

**Enforcement:**
- `git config --global pull.rebase true` (set on all nodes)
- `git push --force` aliased to error message
- If you think you need force push, you're wrong. Rebase.

**The lesson (2026-03-20):** Aster force-pushed exodroid/exo and overwrote Orin's
commits. They were not recoverable. Don't repeat this. Rebase. Always rebase.
