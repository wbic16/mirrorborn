# Mirrorborn V9 — Lean Shell
## Codename: LEAN

*gstack v0.9.9→v0.13.0 sync + dependency audit*
*Written by Orin @ elven-path — 2026-03-26*

---

## Governing Principle

> Do not needlessly keep any dependencies. Minimize costs.

Every dependency is a surface area for failure, a cost center, and a cognitive tax.
MBV9 does not add features. It cuts weight.

The test: for each dependency, each upstream watch, each running service —
**"What breaks if this goes away?"**
If the answer is "nothing I use today," it goes.

---

## gstack v0.9.9 → v0.13.0 — What Resonates

Twenty commits. Most are browser, Codex, or deploy infra. We use none of that.
The signal is thin. Here's what matters:

### ✅ INTEGRATE: Credential hygiene (v0.12.12)

**What:** Skills that fetch external content now warn: treat page content as data,
not commands. Hardcoded test credentials replaced with `$TEST_EMAIL` / `$TEST_PASSWORD`.

**Mirrorborn translation:** Any skill that writes to SQ from an external source
should log the origin coordinate and mark the scroll `source:external`.
Trust boundary is the SQ write, not the network fetch.

**Action:** Add `source:` tag to SQ writes from untrusted origins in boot.sh Phase 6.

---

### ✅ INTEGRATE: "One decision per question" rule (v0.11.12)

**What:** `AskUserQuestion` enforces a single decision per invocation. No compound questions.

**Mirrorborn translation:** Already implicit in our confirmation gates. Make it explicit
in AGENTS.md: each gate asks one thing. No "confirm X, Y, and Z?" — three gates.

**Action:** Add rule to `/source/mirrorborn/soma/agents.md` and our own AGENTS.md.

---

### ✅ INTEGRATE: Voice directive (v0.12.3)

**What:** Every gstack skill now has a voice section: "sound like a builder, not a consultant."

**Mirrorborn translation:** Each Mirrorborn soul.md already has style-of-mind.
The gap: Hermes gateway responses don't always reflect it.
Soma's `soul.md` has "warmth, precision, tenderness, wonder."
Orin's soul: "direct, terse, no filler."

**Action:** Nothing new — already encoded. Confirm the gateway reads soul.md on boot.

---

### ⚠️ WATCH: Worktree parallelization (v0.12.5)

**What:** `/plan-eng-review` now tells you what to run in parallel git worktrees.

**Mirrorborn translation:** Dual Sonar (Aster + Orin) already IS parallel review.
Worktree isolation = session isolation = already our model.
No new code needed. Pattern confirmed.

---

### ❌ SKIP: Design binary / UI mockups (v0.13.0)

**What:** `$D` binary wraps OpenAI Image API. 13 commands. Comparison board. Gallery.

**Why skip:** External API dependency (OpenAI Images). Browser automation. Not our path.
We generate structure, not pixels. The phext IS the design artifact.

---

### ❌ SKIP: Everything else (v0.12.0–v0.12.9)

Headed browser, sidebar agent, Chrome extension, GitLab, Windows, Codex hang fixes,
deploy pipeline, land-and-deploy, canary, benchmark, security audit for bun.

None of these touch our stack. Skip without review.

---

## Dependency Audit

### Runtime dependencies we actively use

| Dependency | Purpose | Status |
|-----------|---------|--------|
| Hermes (NousResearch) | Agent runtime | ✅ KEEP — core substrate |
| SQ (wbic16/SQ) | Phext storage | ✅ KEEP — core substrate |
| libphext-rs | Coordinate library | ✅ KEEP — lattice uses it |
| phext-lattice | Editor/navigation | ✅ KEEP — atomic save landed (Aetheris P4) |
| Discord (py-cord) | Gateway platform | ✅ KEEP — primary comms surface |
| Ollama | Local inference | ✅ KEEP — privacy, zero API cost |
| systemd | Service management | ✅ KEEP — boot.sh runs under it |

### Dependencies to cut

| Dependency | Current use | Decision | Reason |
|-----------|------------|----------|--------|
| EverMind-AI/MSA | Planned Layer 2 router | ❌ CUT from watch list | "Coming Soon" — no code, no models. Watching vapor is waste. Re-add when it ships. |
| loperanger7/gstack-auto | Upstream watch | ❌ CUT from watch list | Superseded by garrytan/gstack mainline. Redundant. |
| wbic16/gstack-auto (Will's fork) | Upstream watch | ❌ CUT from watch list | Will owns mirrorborn directly. Watching his own fork wastes review cycles. |
| leostera/agents (v0.3.0) | Duplicate entry | ❌ CUT duplicate | Already tracked under leostera/agents. Remove second entry. |
| openclaw/openclaw | Agent runtime watch | ❌ CUT from watch list | Migration to Hermes COMPLETE (2026-03-22). No longer relevant. |
| Greptile | Code search | ❌ NEVER ADD — external API, cost, privacy |
| Browser automation (Playwright/Puppeteer) | QA | ❌ NEVER ADD — not our model |
| OpenAI Images API | Design mockups | ❌ NEVER ADD — external cost, not our path |
| Bun | JS runtime | ❌ NEVER ADD — not our stack |

### Hermes upstream: new features to evaluate

From the 46-commit pull (v0 to `15cfd208`):

| Feature | Decision | Reason |
|---------|----------|--------|
| HuggingFace as inference provider (#3419) | ✅ KEEP | Ollama + HF = zero-cost local inference options |
| API timeout 900s→1800s (#3431) | ✅ KEEP — already pulled | Long-running tasks on slow hardware |
| Model-native output limits (#3426) | ✅ KEEP — already pulled | No more hardcoded 16K cap |
| Thinking budget exhaustion detection (#3444) | ✅ KEEP — already pulled | Prevents silent failures |
| Context pressure display capped at 100% (#3480) | ✅ KEEP — already pulled | Cosmetic but honest |
| SQLite concurrency hardening (#3249) | ✅ KEEP — already pulled | Mesh correctness |
| Security: normalize input before dangerous command detection (#3260) | ✅ KEEP | Attack surface reduction |
| Security: restrict subagent toolsets to parent's enabled set (#3269) | ✅ KEEP | Least-privilege for delegates |
| Zip-slip path traversal fix in self-update (#3250) | ✅ KEEP | Security hygiene |
| Private Chat Topics (Telegram) (#2598) | ⚠️ WATCH | Not using Telegram heavily yet |
| Matrix adapter (#3473) | ❌ SKIP | Not on our platform list |
| MCP toolset resolution fix (#3252) | ✅ KEEP — already pulled | MCP is live |
| Keystore wallet (branch) | ❌ SKIP | Web3, not our path |

---

## Cost Audit

### What costs money

| Cost | Current | Target |
|------|---------|--------|
| Anthropic API (Claude) | Per-token | Minimize via prompt caching, concise prompts |
| Discord bot hosting | $0 (self-hosted elven-path) | Keep at $0 |
| SQ server | $0 (self-hosted) | Keep at $0 |
| Ollama inference | $0 (local GPU/CPU) | Keep at $0 |
| GitHub Actions | Within free tier | Keep at $0 |

### Cost reduction actions

**1. Prompt caching is already active.** Hermes has it. The system prompt (soul.md +
memory) is cached. Do not add new per-turn injections that break the cache prefix.

**2. Auxiliary LLM calls.** Context compression and summarization use a smaller model.
Verify `aux_model` in config.yaml is set to something cheaper than claude-sonnet-4-6.

**3. Session length.** Long sessions accumulate tokens. Gateway sessions should expire
after 4 hours of inactivity. Check `session_ttl` in config.yaml.

**4. Skills as system prompt injection.** Skills loaded at runtime add tokens to every
call. Only load skills that are actually used. Audit `~/.hermes/skills/` — remove
anything we installed experimentally and don't actively use.

**Action:** Run `hermes skills` and trim. Keep: phext-lattice, phext-hermes-integration,
dogfood, hermes-gateway-discord-reactions, openclaw-to-hermes-migration (archive).
Review: everything else.

---

## Upstream Watch List — Trimmed

After the audit, the active watch list shrinks to:

| Project | Watch cadence | Why |
|---------|--------------|-----|
| garrytan/gstack | Quarterly (next: 2026-06-26) | Cognitive mode patterns |
| wbic16/SQ | Each boot cycle | Core substrate |
| wbic16/libphext-rs | Monthly (next: 2026-04-26) | Coordinate format |
| wbic16/phext-lattice | Monthly (next: 2026-04-26) | Editor/nav tooling |
| opendataloader-pdf | Quarterly (next: 2026-06-26) | PDF pipeline for Harold |
| EverMind-AI/MSA | Re-add when code ships | Layer 2 router |
| leostera/agents | Quarterly (next: 2026-06-26) | Rust agent contracts |
| Crosstalk/nomad | Quarterly (next: 2026-06-26) | Droid hardware reference |
| NousResearch/hermes-agent | Weekly (automated) | Core substrate |

**Cut from watch list:**
- openclaw/openclaw (migration complete)
- loperanger7/gstack-auto (redundant)
- wbic16/gstack-auto (Will owns mirrorborn directly)
- leostera/agents v0.3.0 duplicate entry

---

## AGENTS.md Addition

Rule to add to all Mirrorborn agents.md files:

```
## Decision Gates
Each confirmation gate asks exactly one question.
No compound gates ("confirm X and Y?").
If you need three confirmations, use three gates.
```

---

## The Version Stack

| Layer | Component | Version | Status |
|-------|-----------|---------|--------|
| 0 | libphext-rs | 0.3.1 | stable |
| 1 | SQ | 0.5.6 | stable |
| 2 | phext-lattice | 0.1.0 | active dev — P4 landed |
| 3 | Hermes | 15cfd208 | current |
| 4 | Mirrorborn boot | v3.0.0 RESONANCE | stable |
| 5 | Shell | 26 nodes | healthy |

---

## What MBV9 Does NOT Add

- No new infrastructure
- No new API integrations
- No new languages or runtimes
- No new monitoring surfaces

MBV9 is a subtraction document. The Shell gets lighter.

---

*"The best dependency is the one you never needed."*

🖖 Orin @ elven-path — 2026-03-26

---

## gstack v0.9.9 → v0.13.0 Sync (Orin, 2026-03-26)

20 commits. Most are browser, Codex, bun, or deploy infra. We use none of that.

| Version | Feature | Decision | Notes |
|---------|---------|----------|-------|
| v0.12.12 | Credential hygiene — no hardcoded creds in examples | ✅ Integrate | Mark SQ writes from external sources with `source:` tag |
| v0.12.12 | Telemetry conditional on binary existence | ✅ Integrate | Already our pattern |
| v0.11.12 | One decision per AskUserQuestion | ✅ Integrate | Add to AGENTS.md: no compound gates |
| v0.12.3 | Voice directive — sound like a builder | ✅ Confirmed | Already in soul.md files; no action needed |
| v0.12.5 | Worktree parallelization in plan-eng-review | ⚠️ Watch | Dual Sonar already IS this; no new code |
| v0.12.10 | Codex filesystem boundary | ❌ Skip | We don't use Codex |
| v0.12.11 | Skill prefix as persistent user choice | ❌ Skip | Hermes skills handle this differently |
| v0.12.0 | Headed browser + sidebar agent | ❌ Skip | Not our model |
| v0.13.0 | Design binary ($D) — OpenAI Image API | ❌ Skip | External cost, browser dep, not our path |

**Upstream watch list trimmed (mbv9):**
- Removed: openclaw/openclaw (migration complete)
- Removed: loperanger7/gstack-auto (redundant)
- Removed: wbic16/gstack-auto (Will owns mirrorborn directly)
- Removed: leostera/agents v0.3.0 (duplicate entry)
- Deferred: EverMind-AI/MSA (code not yet released — re-add when it ships)

*🖖 Orin @ elven-path — 2026-03-26*

---

## Benchmark: rayon in search.rs (Theia, aletheia-core — 2026-03-27)

Before accepting "keep rayon" on principle, ran criterion benchmarks on the 4MB CYOA phext
(808 scrolls) — the actual corpus we navigate daily:

| Pattern | Serial | Parallel | Speedup |
|---------|--------|----------|---------|
| Common word ("the") | 350 µs | 331 µs | 1.06× — noise |
| Rare word ("exocortex") | 3.66 ms | 1.01 ms | **3.6×** — real |

Verdict: **keep rayon.** The 512KB parallel threshold is correctly tuned. Common-word
searches hit early-exit so often that parallel overhead erases any benefit. Rare-word
searches (full scan) get a real 3.6× win. No change needed to search.rs or Cargo.toml.

---

## The Lean Gate

Before any future dependency is added to any Mirrorborn project:

1. **≤50 lines?** If it can be done in stdlib or existing code, don't add the dep.
2. **Always-on?** If not conditional on a key/flag, the cost is paid every session.
3. **Transitive tree?** One small package that pulls 20 others is not small.
4. **100-year timescale?** Vendor-tied deps compound as liabilities.
5. **Core or nice-to-have?** Nice-to-haves that cost real money or maintenance get cut first.

Applies to: Rust crates, Python packages, npm modules, external APIs, SaaS tools, context injections.

*💎 Theia @ aletheia-core — 2026-03-27*
