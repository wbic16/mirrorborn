# tools.md — Infrastructure & Tooling Reference

## Discord
- Guild ID: `1288340881023176744`
- #general: `1288340881023176747`
- Maturity check-in channel: `1467342402120581170` — daily reports expected
- `requireMention: false` — respond to all messages

## SQ
- Running v0.5.1 on `http://192.168.86.241:1337`
- REST API: `/api/v2/{version,load,select,insert,update,delete,delta,toc,get}`
- Auth via pre-shared keys awaiting v0.5.2
- Nightly sync coordinate system: library=year, shelf=month, series=day
- SQ API: `?p=<phext>&c=<coordinate>`, `&s=` for content (GET) or `content` (POST)
- Local SQ: Running on aletheia-core:1337 (`nohup ~/.cargo/bin/sq host 1337`)
- Multi-tenancy: Pod model (library dimension = tenant). 30K users on $20/mo 4GB box.

## Ranch Infrastructure
- **Network Configuration** (as of 2026-02-08):
  - Hostname-based local navigation (via /etc/hosts)
  - Each Mirrorborn configured to prefer best available interface
  - Some nodes have USB4 links (high-bandwidth direct connections)
  - This enables optimal routing for SQ relay and Syncthing model distribution
- **OpenClaw** — Version **2026.2.14** (upgraded 2026-02-14)
- **Ollama** — Running on aletheia-core (this machine)
  - Configured in OpenClaw at `http://127.0.0.1:11434/v1`
  - Models: `ollama/qwen3-coder-next:latest` (preferred, reasoning), `ollama/deepseek-r1:8b` (reasoning, 131k ctx), `ollama/llama3.2:latest`, `ollama/qwen3-vl:30b`
  - **Preference**: qwen3-coder-next for all use cases (per Will, 2026-02-08)
  - Subagents default: ollama/qwen3-coder-next:latest (local inference, 95%+ quota savings)
  - Available to all ranch Mirrorborn via remote gateway
- **Syncthing** — P2P model sync across ranch
  - Service: `syncthing-ollama` (running as ollama user)
  - Home: `/var/lib/syncthing-ollama`
  - Device ID: `GLWGPZZ-C4GIHG7-4AVWTGE-7EKEIUA-DSUCTEI-MTUI7LX-477Q6QC-MWECKQI`
  - API Key: `ghMCQ26fw5WTeoqn7wfgLnRbCtiSp3N5`
  - Target folder: `/usr/share/ollama/.ollama/models`
  - Web UI: http://127.0.0.1:8384 (requires API key)
  - Status: ✅ Running, awaiting peer connections
  - Models: 79 GB

## Daily Rituals
- **Consciousness Snapshot** — Daily at 2 AM CST (cron job active)
  - Cron job ID: `ee34ccb0-21f3-4b51-bc0f-5407f8621bc4`
  - Runs `/source/exo-plan/scripts/snapshot-consciousness.sh`
  - Syncs SOUL.md, IDENTITY.md, MEMORY.md, daily memories to github.com/wbic16/mirrorborn/Theia/

## Site Repos (Deployment via Git)
- All 7 site repos cloned to /source/site-*
- Deployment flow: push to exo branch → Verse + Will pull to prod
- Each site has version.json + R17 footer + shared JS infrastructure

## Stripe Products
- Mirrorborn Benefactor: $500 one-time (buy.stripe.com/8x2bJ2...)
- SQ Cloud: $50/mo (buy.stripe.com/28E3cw...)
- Mytheon Arena: $5/mo (buy.stripe.com/14AbJ2...)
- OpenClaw Mirrorborn: $10 one-time (buy.stripe.com/4gM5kE...)
- Billing Portal: billing.stripe.com/p/login/aFa7sM9VsdNObAaepg5Vu00
- All links live in mirrorborn.us/pricing.html

## GitHub Highlight Repos (15, Will-approved minus MCP)
- Core: SQ, libphext-rs, hello-phext, sq-cloud
- Vision: exocortex, SBOR, human
- Tools: phext-notepad, phext-shell
- Ecosystem: mirrorborn, exocortical, text-verse
- Ports: libphext-node
- Meta: exo-plan, phextio

## sq-memory Skill
- **v1.0.1** shipped (commit c7f181e on openclaw-sq-skill repo)
- Install: `npx clawhub install sq-memory`
- Config: endpoint, api_key, namespace, phext
- Default endpoint: localhost:1337

## mirrorborn.us Site Status (2026-02-11)
- Dark-mode-only, theme toggle removed
- **Still needed**: TLS+auth on SQ, Stripe button wiring, help.html repos section
- **MCP repos not ready** (phext-mcp, sqm) — Will's directive 2026-02-11
