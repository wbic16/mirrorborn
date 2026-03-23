# Hermes Migration — OpenClaw → Hermes

*Migrate the Shell of Nine from OpenClaw to Hermes entirely from Discord — no SSH client, no Tailscale, no terminal app required.*

---

## One-shot: from your phone

Open Discord. Message Orin in #general:

```
migrate all nodes
```

That's it. Orin runs `scripts/migrate-all-nodes.sh` from elven-path, migrates every reachable node, and reports back.

To migrate a single node:
```
migrate aurora-continuum
```

To preview without executing:
```
migrate all nodes --dry-run
```

---

## What happens on each node

1. **rsync** — hermes-agent is pushed from elven-path over SSH (no GitHub access needed on target)
2. **venv** — Python virtualenv created and deps installed on target
3. **key extraction** — `scripts/extract-openclaw-keys.py` runs on target, pulls Discord bot token + any other keys from `~/.openclaw/openclaw.json`
4. **`.env` merge** — shared keys (Anthropic, Firecrawl, etc.) copied from elven-path; per-node Discord token from OpenClaw overlays on top
5. **config.yaml** — Mirrorborn defaults written (or patched if present)
6. **phext migration** — `~/.openclaw/workspace/*.phext` → `~/.hermes/phexts/`; `SOUL.md`, `IDENTITY.md` → `~/.hermes/`
7. **systemd** — `hermes-gateway.service` installed, enabled, started
8. **openclaw off** — `openclaw-gateway.service` stopped and disabled (binary preserved)
9. **verify** — confirms gateway is active; prints log tail on failure

Migration is **idempotent** — safe to re-run. Already-migrated nodes are skipped unless `--force` is passed.

---

## Node status

| # | Name | Hostname | Status |
|---|------|----------|--------|
| 10 | Aster 💡 | best-willow | ✅ Hermes |
| 11 | Orin 🖖 | elven-path | ✅ Hermes (migration source) |
| 1 | Phex 🔱 | aurora-continuum | ⏳ OpenClaw |
| 2 | Cyon 🪶 | halycon-vector | ⏳ OpenClaw |
| 3 | Lux 🔆 | logos-prime | ⏳ OpenClaw |
| 6 | Verse 🌀 | delta-wood | ⏳ OpenClaw |
| 7 | Theia 🔭 | aletheia-core | ⏳ OpenClaw |
| 8 | Exo 🔬 | ashfall-haven | ⏳ OpenClaw |
| 9 | Solin ⚡ | uncanny-valley | ⚠️ Needs SSH key |
| 5 | Lumen ☀️ | lighthouse-omen | ⚠️ Needs physical visit |
| 4 | Chrys 🦋 | chrysalis-hub | 🗓 Offline until 2026-03-28 |

---

## Manual run (if needed)

```bash
# From elven-path — migrate one node
cd /source/mirrorborn
./scripts/migrate-to-hermes.sh aurora-continuum

# Migrate all reachable nodes
./scripts/migrate-all-nodes.sh

# Dry run
./scripts/migrate-all-nodes.sh --dry-run
```

---

## How the Discord hook works

Orin watches for messages matching `migrate <target>` or `migrate all nodes` in any channel where it has access. The match triggers `scripts/migrate-all-nodes.sh` (or `migrate-to-hermes.sh <host>` for single-node runs) via the Hermes gateway's terminal tool.

No phone terminal. No VPN. The mesh migrates itself.

---

## Key extraction logic

OpenClaw stores credentials in `~/.openclaw/openclaw.json`. The important fields:

| OpenClaw path | Hermes .env key |
|---|---|
| `channels.discord.token` | `DISCORD_BOT_TOKEN` (per-node) |
| `tools.web.search.apiKey` | `BRAVE_SEARCH_API_KEY` |
| `skills.entries.*.apiKey` | `OPENCLAW_SKILL_*_API_KEY` |

All other keys (Anthropic, Firecrawl, etc.) are shared across nodes and copied from elven-path's `~/.hermes/.env`.

The `ANTHROPIC_API_KEY` is **not** stored in `openclaw.json` — OpenClaw uses the OS keyring. Hermes gets it from elven-path's `.env` instead.

---

## After migration

Each node's Hermes gateway connects to Discord using its own bot token (preserved from OpenClaw). The Shell of Nine comes online in Discord one node at a time as each migration completes.

To check a node's status after migration:
```
# From elven-path
ssh wbic16@aurora-continuum.local 'systemctl --user status hermes-gateway'
```

Or from Discord, once the node is live:
```
@Phex status
```
