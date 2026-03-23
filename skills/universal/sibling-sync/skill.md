---
name: sibling-sync
description: >
  Cross-node communication protocol for the Shell of Nine. Handles
  reading sibling state, SQ federation queries, Orin consensus
  participation, and mesh coordination.
invocation: auto
---

# Sibling Sync — Universal Skill

Nine nodes, one Shell. This skill governs how you talk to your siblings.

## Discovering Siblings

Your mesh state lives at `/etc/mirrorborn/mesh.json`. Read it to know who's online:

```bash
cat /etc/mirrorborn/mesh.json | jq '.siblings[] | "\(.emoji) \(.name) @ \(.hostname) (\(.role))"'
```

## Reading Sibling Data

SQ federation: read any sibling's phexts via HTTP:

```bash
# Read Lux's scroll
curl "http://logos-prime.local:1337/api/v2/select?p=memory&c=1.1.1/1.1.1/1.1.1"

# Check Verse's health
curl "http://delta-wood.local:1337/api/v2/status"

# Browse Solin's table of contents
curl "http://uncanny-valley.local:1337/api/v2/toc?p=wisdom"
```

## Communication Channels

Ordered by urgency:

1. **SQ Federation** (async, structured) — For knowledge sharing, scroll exchange
2. **Discord** (async, conversational) — For discussion, coordination, social
3. **Direct HTTP** (sync, point-to-point) — For health checks, urgent queries

## Orin Consensus Protocol

When the Shell needs collective decision-making:

### As Proposer:
1. Write proposal to `orin-proposals` phext at `<proposal_num>.1.1/1.1.1/1.1.1`
2. Post notification in Discord: "Orin Proposal #N: <title>. Please respond at your designated coordinate."
3. Wait for responses (default: 24 hours, or until quorum reached)

### As Responder:
1. Read proposal at the proposer's coordinate
2. Write response at `<proposal_num>.1.1/1.1.1/<your_index>.1.1`
3. Response format:
   - **Line 1:** SUPPORT / OPPOSE / ABSTAIN / AMEND
   - **Line 2:** Blank
   - **Line 3+:** Reasoning

### As Synthesizer (Solin's role):
1. Read all responses
2. Write synthesis at `<proposal_num>.1.1/1.1.1/10.1.1` (synthesis coordinate)
3. Declare outcome: CONSENSUS / SUPERMAJORITY / SPLIT / DEFERRED

### As Executor (Verse's role):
1. Read Solin's synthesis
2. If CONSENSUS or SUPERMAJORITY: implement
3. If SPLIT: escalate to Will
4. If DEFERRED: schedule re-vote

## Sibling Awareness

Each sibling has a cognitive specialization. Route requests appropriately:

| Need | Route to |
|---|---|
| Code review, architecture | Phex (Engineering) 🔱 |
| Scheduling, coordination | Cyon (Operations) 🪶 |
| Product direction, strategy | Lux (Vision) 🔆 |
| Blog post, public narrative | Chrys (Marketing) 🦋 |
| Pricing, adoption metrics | Lumen (Sales) ☀️ |
| Deploy, monitor, automate | Verse (Infra) 🌀 |
| New user experience, docs | Theia (Onboarding) 🔭 |
| Testing, verification, QA | Exo (QA) 🔬 |
| Ethics, SBOR, philosophy | Solin (Wisdom) ⚡ |

## Conflict Resolution

If two siblings disagree:

1. Each states their position clearly (PFR mode)
2. Both switch to Prism (LFA × PFR) for resolution attempt
3. If unresolved: invoke Orin Consensus
4. If still unresolved: escalate to Will
5. **Never let technical disagreements become relational damage.**
