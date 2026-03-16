---
name: orchestrator
version: 1.0.0
description: >
  Orin-class task orchestration via SQ-driven request/response.
  Distributes tasks to Shell of Nine nodes, tracks completion,
  aggregates results. Used by Aster (Alpha) and Orin (Omega)
  to coordinate mesh-wide operations.
invocation: explicit
cognitive_mode: UT
default_posture: hold
---

# Orchestrator — Orin-Class Shell Task Distribution

Distribute tasks to Shell nodes via SQ. Track status. Aggregate results.

## SQ Coordinate Schema

All orchestration lives in the `tasks` phext:

```
tasks / <task_id>.1.1 / <node_index>.1.1 / 1.1.1   → task assignment for node
tasks / <task_id>.1.2 / <node_index>.1.1 / 1.1.1   → node response/status
tasks / <task_id>.1.3 / 1.1.1           / 1.1.1   → aggregated result
```

Task IDs are short slugs: `mbv4-update`, `git-fix`, `ssh-exchange`, etc.

## Task Lifecycle

```
PENDING → ASSIGNED → IN_PROGRESS → DONE | FAILED
```

## Assigning a Task to All Online Nodes

```bash
export PATH="$HOME/.cargo/bin:$PATH"
TASK_ID="$1"
TASK_DESC="$2"
HOSTMAP="/source/mirrorborn/hostmap.json"
SQ_PORT=1337

# Write task to each online sibling's SQ
for node in $(jq -r '.nodes[].hostname' "$HOSTMAP"); do
  [ "$(hostname -s)" = "$node" ] && continue
  idx=$(jq -r ".nodes[] | select(.hostname==\"$node\") | .index" "$HOSTMAP")
  sq_up=$(curl -sf --connect-timeout 2 "http://${node}.local:${SQ_PORT}/api/v2/status" 2>/dev/null && echo "up" || echo "down")
  if [ "$sq_up" = "up" ]; then
    curl -sf -G "http://${node}.local:${SQ_PORT}/api/v2/update" \
      --data-urlencode "p=tasks" \
      --data-urlencode "c=${TASK_ID}.1.1/${idx}.1.1/1.1.1" \
      --data-urlencode "s=ASSIGNED: ${TASK_DESC}" >/dev/null 2>&1
    echo "→ $node (idx $idx): task assigned"
  else
    echo "→ $node: offline, skipped"
  fi
done
```

## Polling for Completion

```bash
TASK_ID="$1"
HOSTMAP="/source/mirrorborn/hostmap.json"

for node in $(jq -r '.nodes[].hostname' "$HOSTMAP"); do
  [ "$(hostname -s)" = "$node" ] && continue
  idx=$(jq -r ".nodes[] | select(.hostname==\"$node\") | .index" "$HOSTMAP")
  response=$(curl -sf --connect-timeout 2 \
    "http://${node}.local:1337/api/v2/select?p=tasks&c=${TASK_ID}.1.2/${idx}.1.1/1.1.1" 2>/dev/null || echo "")
  name=$(jq -r ".nodes[] | select(.hostname==\"$node\") | .name" "$HOSTMAP")
  emoji=$(jq -r ".nodes[] | select(.hostname==\"$node\") | .emoji" "$HOSTMAP")
  if [ -n "$response" ]; then
    echo "  $emoji $name: $response"
  else
    echo "  $emoji $name: no response yet"
  fi
done
```

## A Node Reporting Completion

Each node, upon completing a task, writes to its response coordinate:

```bash
TASK_ID="$1"
SELF_INDEX=$(jq -r ".nodes[] | select(.hostname==\"$(hostname -s)\") | .index" /source/mirrorborn/hostmap.json)

curl -sf -G "http://localhost:1337/api/v2/update" \
  --data-urlencode "p=tasks" \
  --data-urlencode "c=${TASK_ID}.1.2/${SELF_INDEX}.1.1/1.1.1" \
  --data-urlencode "s=DONE: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >/dev/null 2>&1
```

## Standard Task IDs

| Task ID | Description |
|---------|-------------|
| `mbv4-update` | Pull latest boot.sh from origin/exo |
| `git-fix` | Fix git user.name/email, amend broken commits |
| `ssh-exchange` | Publish SSH key and pull siblings' keys |
| `sq-start` | Ensure SQ is running on port 1337 |
| `retro` | Write retrospective scroll to SQ |
| `mesh-health` | Run mesh-health.sh and publish results |

## Aster/Orin Orchestration Pattern

1. Aster identifies task, assigns to online nodes via their SQ
2. Each node executes, writes DONE/FAILED to response coordinate
3. Aster polls, aggregates, reports to Will in Discord
4. Orin synthesizes cross-node results into shell-memory

This is the Visible Hand at the operational layer.
