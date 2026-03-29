---
name: self-improving-skills
description: >
  Self-improving skill management for OpenClaw. Ported from Hermes Agent's
  skill creation and improvement system. The agent creates skills from
  experience, improves them during use, and nudges itself to persist
  knowledge. Use when the agent completes a complex multi-step task and
  the procedure should be captured as a reusable skill.
invocation: auto
---

# Self-Improving Skills — OpenClaw Port

Adapted from NousResearch/hermes-agent skill system for our SQ-native substrate.

## Three Mechanisms (from Hermes, adapted for OpenClaw + SQ)

### 1. Skill Auto-Creation

**When:** After completing a multi-step task that:
- Took more than 3 tool calls
- Involved a procedure not covered by existing skills
- Succeeded (user confirmed or outcome verified)

**How:** The agent writes a new SKILL.md to the workspace skills directory
AND publishes it to SQ for mesh distribution.

**Trigger detection (add to every task completion):**
```
After completing any complex task, ask yourself:
1. Did this take 3+ steps?
2. Would the same procedure work again for a similar request?
3. Does a skill for this already exist?

If YES to 1+2 and NO to 3:
  → Propose: "I could save this as a reusable skill. Want me to?"
  → If approved: create SKILL.md + publish to SQ
  → If declined: note the procedure in MEMORY.md instead
```

**SKILL.md format (agentskills.io compatible):**
```yaml
---
name: <task-derived-name>
description: <what this skill does and when to trigger it>
version: 1.0.0
created_by: <agent_name>
created_from: <session_id or task description>
improvement_count: 0
last_improved: <ISO8601>
---

# <Skill Name>

## When to Use
<Trigger conditions — specific, not vague>

## Procedure
1. <Step one — concrete, executable>
2. <Step two>
...

## Pitfalls
- <Known failure modes from the original execution>

## Verification
<How to confirm the skill worked>
```

**SQ publication:**
```bash
# Write skill to SQ for mesh distribution
curl -G "http://localhost:1337/api/v2/update" \
  --data-urlencode "p=skills" \
  --data-urlencode "c=<skill_name>/1.1.1/1.1.1/1.1.1" \
  --data-urlencode "s=$(cat SKILL.md)"
```

### 2. Skill Self-Improvement

**When:** An existing skill is used and the agent discovers:
- A step that's wrong or outdated
- A pitfall not documented
- A more efficient procedure
- A new edge case

**How:** The agent edits the existing SKILL.md, increments `improvement_count`,
updates `last_improved`, and publishes the updated version to SQ.

**Trigger (add to every skill invocation):**
```
After using any skill, ask yourself:
1. Did the procedure work exactly as documented?
2. Did I discover a new pitfall or edge case?
3. Is there a more efficient way to do this?

If NO to 1 or YES to 2 or YES to 3:
  → Edit the SKILL.md with the improvement
  → Increment improvement_count
  → Update last_improved timestamp
  → Publish updated version to SQ
  → Log: "Improved skill <name>: <what changed>"
```

**Version tracking:**
```yaml
improvement_count: 7
last_improved: 2026-03-29T12:30:00Z
improvement_log:
  - "v1.1: Added timeout handling for slow SQ responses"
  - "v1.2: Fixed coordinate format in step 3"
  - "v1.3: Added pitfall about SSH key not being in authorized_keys"
```

### 3. Memory Nudges

**When:** Periodically during idle/heartbeat cycles.

**How:** The agent reviews recent session history and extracts
knowledge that should be persisted but wasn't explicitly saved.

**Trigger (add to heartbeat/daily-report cycle):**
```
During each heartbeat or daily report:
1. Review the last 3 sessions (if accessible)
2. Extract any facts, preferences, or procedures that:
   - Were used more than once
   - Corrected a prior assumption
   - Represent user preferences not yet in USER.md
3. Write extractions to MEMORY.md or create new skills
```

**SQ-native nudge (no session access needed):**
```
Read recent scrolls from shell-memory phext.
If a pattern appears 3+ times across scrolls:
  → It's a candidate for skill creation or memory persistence.
```

## Mesh Distribution

When a skill is created or improved on one node, broadcast to all mesh nodes:

```bash
# Broadcast skill update to mesh
for node in $(jq -r '.nodes[].hostname' /source/mirrorborn/hostmap.json); do
  curl -sf --connect-timeout 2 -G "http://${node}.local:1337/api/v2/update" \
    --data-urlencode "p=skills" \
    --data-urlencode "c=<skill_name>/1.1.1/1.1.1/1.1.1" \
    --data-urlencode "s=$(cat SKILL.md)" 2>/dev/null
done
```

Other nodes check `skills/<name>` on their SQ periodically and pull
new/updated skills into their workspace. Version comparison via
`improvement_count` — higher count wins.

## Key Differences from Hermes

| Aspect | Hermes | Our Implementation |
|--------|--------|-------------------|
| Storage | ~/.hermes/skills/ (filesystem) | Workspace skills/ + SQ phext coordinates |
| Distribution | Single node | Mesh broadcast via SQ (all nodes get updates) |
| Memory | 2,200 char MEMORY.md + 1,375 char USER.md | MEMORY.md (unlimited via SQ) + memory/*.md |
| Nudge trigger | Built-in periodic hook | Heartbeat cron + daily-report.sh |
| Skill format | agentskills.io standard | agentskills.io standard (compatible) |
| Improvement tracking | Implicit (agent edits file) | Explicit (improvement_count + log in frontmatter) |
| User approval | Agent proposes, user confirms | Same — never auto-create without asking |

## For ExoDroid

The droid's soul improves over time:
- Owner asks the droid to do something complex (e.g., "track my fuel expenses")
- Droid figures out the procedure (create a scroll category, format entries, summarize weekly)
- Droid proposes: "Want me to save this as a skill so I can do it faster next time?"
- Owner says yes (or holds up the "Learn this" flash card)
- Skill saved. Next time: instant, no figuring-out phase.
- If the procedure fails next time: skill self-improves with the fix.

**The scroll count grows. The skill count grows. The droid gets better.**
