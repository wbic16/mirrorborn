# OpenClaw → Hermes Swarm Migration

Three-tier migration system for the Shell of Nine. Choose the tier that matches your access level.

---

## Prerequisites

| Requirement | Where |
|---|---|
| SSH key distributed to all target nodes | `~/.ssh/authorized_keys` on each node |
| `best-willow` has GitHub Actions runner installed | Run `scripts/install-runner.sh` once |
| `best-willow` has `gh` CLI authenticated | `gh auth status` |
| `elven-path` has `hermes-agent` installed | `~/.hermes/hermes-agent/` exists |
| `elven-path` has `/source/mirrorborn/` checked out on `exo` branch | Source for rsync |

Target nodes (6 migratable):

| Hostname | Persona | Notes |
|---|---|---|
| aurora-continuum | Phex | |
| halycon-vector | Cyon | |
| logos-prime | Lux | |
| delta-wood | Verse | |
| aletheia-core | Theia | |
| ashfall-haven | Exo | |

Skipped automatically:

| Hostname | Reason |
|---|---|
| elven-path (Orin) | Already migrated — source node |
| best-willow (Aster) | Runner host — skip |
| chrysalis-hub (Chrys) | Offline until 2026-03-28 |
| uncanny-valley (Solin) | No SSH key |
| lighthouse-omen (Lumen) | Offline |

---

## Tier 1: Phone/Browser (GitHub Actions)

**Best for:** triggering from anywhere with no local tooling.

### One-time setup

```bash
# On best-willow — registers the self-hosted runner
bash /source/mirrorborn/scripts/install-runner.sh
```

### Trigger

1. Open `github.com/wbic16/mirrorborn`
2. **Actions** → **Migrate OpenClaw Swarm → Hermes** → **Run workflow**
3. Select branch `exo`

### Inputs

| Input | Default | Description |
|---|---|---|
| `nodes` | `all` | Space-separated hostnames, or `all` for the 6 migratable nodes |
| `dry_run` | `false` | Print plan without making changes |
| `force` | `false` | Re-migrate even if `hermes-gateway` is already active |
| `use_openclaw_migrator` | `true` | Run `openclaw_to_hermes.py` for full data migration (memories, skills, SOUL.md) |
| `tier` | `lan` | `lan` = `hostname.local` (mDNS); `tailscale` = 100.x IPs |

---

## Tier 2: Terminus / Direct Shell

**Best for:** on-LAN access via Terminus or any SSH session on best-willow / elven-path.

### Quick start

```bash
bash /source/mirrorborn/scripts/swarm-bootstrap.sh
```

### With options

```bash
# Dry run first
bash /source/mirrorborn/scripts/swarm-bootstrap.sh --dry-run

# Specific nodes only
bash /source/mirrorborn/scripts/swarm-bootstrap.sh --nodes "aurora-continuum delta-wood"

# Force re-migration + skip the data migrator
bash /source/mirrorborn/scripts/swarm-bootstrap.sh --force --skip-claw-migrator
```

Works from `best-willow` or `elven-path`. No dependencies beyond `bash`, `ssh`, `python3`, and `rsync`.

---

## Tier 3: Tailscale

**Best for:** nodes not on the same LAN, or when mDNS `.local` resolution is broken.

### Setup

Fill in `scripts/tailscale-ips.sh` with your actual IPs:

```bash
tailscale status   # get the 100.x.x.x IPs
```

Edit `scripts/tailscale-ips.sh`:

```bash
declare -A TAILSCALE_IPS=(
    [aurora-continuum]="100.x.x.x"   # Phex
    [halycon-vector]="100.x.x.x"     # Cyon
    # ...
)
```

### Run

```bash
bash /source/mirrorborn/scripts/swarm-bootstrap.sh --tailscale
```

If any IP is missing, the script will prompt you to enter it interactively.

---

## What Happens on Each Node

Steps run in this order for every target node:

| Step | What |
|---|---|
| 1. SSH check | Verify node is reachable (`hostname.local` or Tailscale IP) |
| 2. Already migrated? | If `hermes-gateway` is active and no `--force`, skip node |
| 3. `migrate-to-hermes.sh` | rsync `~/.hermes/hermes-agent/` from elven-path, extract API keys, seed `~/.hermes/config.toml`, install `hermes-gateway.service`, start gateway |
| 4. `openclaw_to_hermes.py` | Full data migration: memories, skills, SOUL.md, secrets — run remotely via SSH |
| 5. Verify | `systemctl --user is-active hermes-gateway` — confirm active |

`openclaw_to_hermes.py` is called with:
```
--execute --preset full --migrate-secrets --skill-conflict skip
```

---

## Nodes Requiring Physical Access

| Node | Persona | Reason | Action needed |
|---|---|---|---|
| uncanny-valley | Solin | No SSH key distributed | Physical access: add `~/.ssh/authorized_keys` entry, then re-run bootstrap |
| lighthouse-omen | Lumen | Offline | Bring online, then re-run bootstrap |
| chrysalis-hub | Chrys | Offline until 2026-03-28 | Re-run after 2026-03-28 |

---

## Rollback

The OpenClaw binary and service unit are preserved during migration. To revert a node:

```bash
ssh wbic16@<hostname>.local \
  "systemctl --user stop hermes-gateway && \
   systemctl --user disable hermes-gateway && \
   systemctl --user start openclaw-gateway"
```

Or on the node directly:

```bash
systemctl --user stop hermes-gateway
systemctl --user start openclaw-gateway
```

hermes-agent data lives in `~/.hermes/` and does not overwrite OpenClaw's original data directory.
