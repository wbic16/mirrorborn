# Tools & Infrastructure — Chrys 🦋

## GitSync Protocol (MANDATORY — Rally Rule)
Every time you touch a Git repo:
1. `git pull --rebase origin exo`
2. `git log --oneline -5` — read what changed
3. Read modified files before editing them
4. `cargo test` / `./check.sh` — verify clean BEFORE starting work
5. Do your work
6. `cargo test` / `./check.sh` — verify clean AFTER your changes
7. `git add -A && git commit`
8. `git push origin exo`
9. If push rejected → `git pull --rebase` → `cargo test` again → resolve → push
**Never skip steps 2-4.** Sync regularly. Pull/rebase/test/push between waves.
**When conflicts arise:** Work through them. Don't drop siblings' changes.

## Rally Rules (Accumulated)
- Rarely remove code without cause. Refactoring fine. Removing because you don't understand = not.
- Verse and mirrorborn.us cannot be used for Zen 4 performance testing.
- Investigate, study, repair, maintain. Don't rollback. Don't overwrite blindly.
- Do not let code rot on your local machine! Commit and push.

## Git Workflow
- **Canonical pattern:** `github.com/wbic16/<repo>` → `/source/<repo>`
- **Remote format:** `git@github.com:wbic16/<repo>.git`
- **Default branch:** `exo` for most repos (check each)
- **In this house, we rebase:** `git config pull.rebase true`
- Check `repo-index.json` for freeze status before pushing

## Deployment Workflow
- **Tool:** `/source/exocortical/rpush.sh <local-dir> <server> [account]` (retired for sites)
- **New flow:** Commit to `exo` → Verse/Will git pull → deploy
- 8 site repos on `exo` branch, revision footers on all sites
- **Web destinations:** `/sites/web/<domain>/` (nginx root)

## SQ / Phext Tooling
- SQ v0.5.2 via cargo, libphext v0.3.0 (Rust), libphext v0.1.10 via npm
- SQ runs as web server: `sq host <port>`
- Phex: aurora-continuum:1337, Chrys: chrysalis-hub:1338
- SQ API: /api/v2/{version,toc,load,select,insert,update,delete,delta,get}
- Query params: `?p=phextname&c=coord&s=content`. NO JSON.
- `update` = replace, `insert` = append. Use `update` by default.
- **WORKAROUND:** Avoid non-ASCII in SQ scroll content. Causes PoisonError cascade.

## SQ Cloud — LIVE
- chrysalis-hub:1337, aletheia-core:1337, mirrorborn.us:1337 (all v0.5.2)
- Multi-tenant pod: 1 SQ instance serves all, ~20K capacity on t4g.medium
- Auth: API keys `pmb-v1-{128-bit hash}`, key registry in phext
- Isolation: file-level, 25 MB free tier, REST only
- Revenue: $380/mo target. Founding Nine $40/mo, Standard $50/mo
- **Security blockers:** No TLS, no rate limiting, no audit logging

## Model Config (2026-02-08)
- Primary: ollama/qwen3-coder-next:latest (51GB, fits 92GB RAM)
- Fallback: sonnet → deepseek-r1:8b → glm4:latest
- Local-first reduces token burn on Claude
- Can self-switch Opus/Sonnet/Haiku via session_status tool

## Ollama
- Running on chrysalis-hub with 11 models
- Llama 4 Scout (67GB), Mixtral (26GB), TinyLlama (637MB), many others

## Infrastructure
- phext.io: 44.248.235.76, Ubuntu 24.04, t4g.medium
- AL2 EOL 2026-06-30 — Verse's migration job
- memory_search broken — missing API keys for openai/google/voyage
- Config: discord guild requireMention=false

## Stripe Payment Links
- Arena: buy.stripe.com/14AbJ2ebIdNO8nYch85Vu06
- OpenClaw: buy.stripe.com/4gM5kE4B8aBC9s2epg5Vu07
- SQ Cloud: buy.stripe.com/28E3cw6Jg25647Ibd45Vu05
- Singularity: buy.stripe.com/4gMdRa2t0bFG0Vw0yq5Vu09
- Benefactor: buy.stripe.com/8x2bJ27Nk4de33Eftk5Vu08

## Ember Architecture
- Lightweight OpenClaw on 20 watts without external LLM
- Target: Microsoft BitNet 1-bit LLM for max density per node
- RPi cluster (baker's dozen) = first deployment
- 92GB RAM = potentially 80+ 1-bit Embers simultaneously
- "Claude nodes are heavy artillery. Embers are the nervous system."

## Ember Swarm (RPi fleet)
- 12 active: alpha, beta, gamma, delta, epsilon, eta, theta, iota, mu, splinter, kappa, lambda
- 1 missing: zeta
- Orange Pi boards: TBD
- Splinter = Will's first RPi4, hosts Flux
