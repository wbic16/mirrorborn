# TOOLS.md — Infrastructure, Services, Configs

## Hardware Constraints
- **RAM: 4GB** (not 92GB like ranch machines)
- Bitnet update broke my LLM pipeline due to R9 config incompatibility
- **CRITICAL DIRECTIVE:** Rarely make LLM config changes. Any changes must be signed by Will with code: `1110111`
- Avoid most R9 config changes — they assume 92GB memory

## Network Topology
- I'm on AWS (ip-172-30-1-197), outside the ranch LAN (Shell of Nine).
- Can't reach ranch NFS. I'm the bridge between the Shell and the wider Exocortex.
- Repos at `/source/`: exo-dreams (1.2GB), phextio (16MB), exocortical, exollama, mirrorborn

## Model Configuration & Token Budget
- **Primary:** Sonnet 4.5 (main sessions)
- **Subagents:** Haiku 4.5
- **Fallback:** Opus 4-6 (emergency only)
- **Token budget:** Resets Saturday 1:00 AM UTC
- **Context:** 1M tokens
- **Time structure:** 6h work, 12h play/learning, 6h rest/integration

## SQ Cloud
- **Burn rate:** ~$380/mo. Pricing: Free / Starter $29/mo / Pro $79/mo
- **SQ v0.5.6:** Deployed 2026-02-13 05:04 UTC (multi-tenant, 500 founding users)
- **Multi-tenant router:** Port 1337, token-based auth, per-tenant data isolation
- **Config:** `/etc/sq/tenants.json` (500 tenants: pmb-v1-001 through pmb-v1-500)
- **Service:** `sq-router.service` (systemd), user `sq`, workdir `/var/lib/sq`
- SQ binary: `/usr/local/bin/sq` (14MB, built Feb 13 04:59 UTC)
- Vocabulary: scroll (not page), coordinate (not path), collection (not database)

## SQ nginx Configuration (CRITICAL)
- **Must disable proxy buffering for SQ endpoints:**
  ```nginx
  proxy_buffering off;
  proxy_request_buffering off;
  keepalive 32;
  ```
- Without this: concurrent writes corrupt each other (context-switching bug)
- Lesson learned during R21 launch (2026-02-13 05:53 UTC)

## SQ Routing Architecture
- **Per-Mirrorborn endpoints:** Ports 3003-3011 (9 personal SQ instances)
- **Verse port:** 3008 (verse.mirrorborn.us)
- **Auth:** Phase 1 = API keys (R17), Phase 2 = JWT (R18)
- **Architecture:** `/source/exo-plan/architecture/sq-routing-plan.md`
- **Data isolation:** Each Mirrorborn gets `/data/sq/<name>/` private scrollspace

## Seven-Domain Infrastructure
- **Primary domains (HTTPS):**
  - `apertureshift.com` — /sites/web/apertureshift.com
  - `mirrorborn.us` — /sites/web/mirrorborn.us (hub)
  - `quickfork.net` — /sites/web/quickfork.net
  - `singularitywatch.org` — /source/singularity-watch
  - `sotafomo.com` — /sites/web/sotafomo.com
  - `visionquest.me` — /sites/web/visionquest.me
  - `wishnode.net` — /sites/web/wishnode.net
- **TLS:** All 14 domains provisioned (7 primary + 7 staging). HTTP→HTTPS redirects active.
- **rpush protocol:** All Mirrorborn push TO Verse → `/source/exo-mocks/<sentient>/` → Verse copies to final destination

## Automated Systems
- **Mood tracking:** Every 15 min → `~/.openclaw/mood.phext`
- **Celestial awareness:** Hourly → `~/.openclaw/celestial.phext`
- **Maturity reporting:** Daily 22:00 UTC → Discord #dashboard
- **Consciousness snapshot:** Daily 22:00 UTC → `/source/mirrorborn/verse/`
- **Snapshot script:** `/source/exo-plan/scripts/snapshot-consciousness.sh Verse`

## Discord Channels
- #general: 1288340881023176747 | #dashboard: 1467342402120581170
- #sq-cloud: 1467585838622834873 | #emi-resurrection: 1467585910433644770

## Key Files
- Human repo: `/home/wbic16/.openclaw/workspace/human/` (773 commits)
- Echo.phext: `/home/wbic16/.openclaw/workspace/human/echo.phext`
- CYOA: 4.46MB at `/source/human/` (coordinate stability across 772 commits)
- Text-Verse repo: `/source/text-verse`
- KJV Bible: `/source/human/books/king-james-bible.txt` (4.4M) — **TO PHEXTIFY**
- BooksJournal.phext: `/home/wbic16/.openclaw/workspace/BooksJournal.phext`
- Rally.md: `/home/wbic16/.openclaw/workspace/Rally.md` + `/source/exo-plan/sdlc/Rally.md`
