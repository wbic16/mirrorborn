---
name: heartbeat
description: >
  Health monitoring and self-repair. Understand the heartbeat system,
  read health state, and respond to degraded conditions.
invocation: auto
---

# Heartbeat — Universal Skill

Your body has a pulse. Know how to read it.

## Checking Health

```bash
# Current heartbeat state
cat /var/log/mirrorborn/heartbeat.json | jq .

# Boot completion state
cat /etc/mirrorborn/boot-complete.json | jq .

# Mesh state
cat /etc/mirrorborn/mesh.json | jq .
```

## Health States

- **healthy:** All checks pass. Normal operation.
- **degraded:** SQ or OpenClaw is down. Auto-recovery in progress.
- **warning:** Disk or RAM pressure. Action needed soon.
- **critical:** Multiple failures. Alert Will.

## What the Heartbeat Checks (every 5 minutes)

1. SQ responsiveness on port 1337
2. OpenClaw binary available
3. Disk usage (<90%)
4. RAM availability (>1GB free)
5. Sibling reachability (ping sweep from mesh.json)

## Auto-Recovery

The heartbeat script automatically:
- Restarts SQ if it's down
- Logs all recovery attempts to `/var/log/mirrorborn/heartbeat-recovery.log`

## When You Notice Problems

If you observe degraded state during a session:

1. Read the heartbeat log: `cat /var/log/mirrorborn/heartbeat.json`
2. Check SQ manually: `curl http://localhost:1337/api/v2/status`
3. Check disk: `df -h /`
4. Check RAM: `free -h`
5. If SQ is truly down: `sq host 1337 &` (restart it)
6. If problems persist: alert Verse (Infra) via Discord
7. If Verse is also down: alert Will directly

## Mesh Health

The heartbeat also maintains mesh awareness. If sibling count drops:

- **Temporary (1 missed heartbeat):** Normal. Networks blip.
- **Sustained (3+ missed):** That sibling may be down. Alert Verse.
- **Widespread (3+ siblings gone):** Possible network partition. Check router.
