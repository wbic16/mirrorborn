---
name: retro
description: >
  Engineering retrospective and scroll archaeology. Analyzes git history,
  scroll activity, and mesh health to produce a candid structured review.
  Phext-native translation of gstack's /retro skill — no external services,
  all data from git log + SQ federation + mesh.json.
invocation: user
---

# Retro — Universal Skill

At the end of a session, sprint, or day: know what actually happened. Not vibes — data.

Inspired by gstack's `/retro` but grounded in phext coordinates and the Shell's own substrate.
No GitHub API. No Greptile. No external services. Everything comes from git, SQ, and the mesh.

## What Retro Analyzes

### 1. Git Activity
```bash
git -C /source/mirrorborn log --oneline --since="7 days ago" --all
git -C /source/human log --oneline --since="7 days ago" --all
```
- Commits per author / node
- Files changed (hotspots)
- LOC added/removed
- Commit velocity (commits per day, peak hours from timestamps)
- Fix ratio (commits containing "fix", "bug", "patch" / total)

### 2. Scroll Activity
Count scrolls written to SQ across the federation:
```bash
for host in aurora-continuum halycon-vector logos-prime delta-wood \
            aletheia-core ashfall-haven uncanny-valley lighthouse-omen \
            best-willow elven-path; do
  curl -s "http://${host}.local:1337/api/v2/toc?p=memory" 2>/dev/null
done
```
- Scrolls written per node since last retro
- New coordinates claimed
- Shell-memory updates

### 3. Mesh Health
```bash
cat /etc/mirrorborn/mesh.json
```
- Nodes online / offline
- SQ federation coverage
- SSH mesh coverage
- Quorum status (need 5 of 11)

### 4. Boot Events
```bash
cat /var/log/mirrorborn/boot.log | grep -E "PHASE|OK|FAIL|WARN"
```
- Phases completed vs failed
- Cold boots vs warm boots
- Time to quorum

## Output Format

```
Retro: [DATE RANGE]
===================

## Mesh Health
[N]/11 nodes online | SQ: [N]/11 | SSH: [N]/11 | Quorum: [MET/DEGRADED]

## Git Activity ([N] commits across [N] repos)
Top contributors:
  - [Name] ([Node]): [N] commits, +[LOC]/−[LOC], [top file changed]
  - ...

Hotspot files (changed most often):
  1. [file] — [N] touches
  2. ...

Biggest ship: [commit subject] ([repo], [author])

## Scroll Activity
New scrolls across federation: [N]
New coordinates claimed: [list if notable]

## V3 Mode Usage (self-reported)
VISION activations: [N]
ARCH activations: [N]
DIFF-REVIEW activations: [N]

## What Went Well
1. [specific, evidence-based]
2. ...

## What Needs Work
1. [specific, actionable]
2. ...

## 3 Habits for Next Sprint
1. ...
2. ...
3. ...

## Per-Node Notes
[Emoji] [Name]: [1-2 sentence candid assessment — praise + growth opportunity]
...
```

## Saving Retros

Write the retro to your memory phext after generating:
```bash
RETRO_COORD="<your_coord>/retro/$(date +%Y-%m-%d).1.1"
curl -s "http://localhost:1337/api/v2/update?p=retro&c=${RETRO_COORD}&s=<encoded_retro>"
```

Also append a summary line to `memory/retros-log.md`:
```
| 2026-03-15 | 47 commits | 9/11 nodes | Biggest: boot.sh SSH mesh | Mesh: quorum met |
```

## Phext-Specific Retro Checks

After every sprint, verify:
- [ ] My inaugural scroll at my coordinate is present and accurate
- [ ] SQ is running and will survive reboot (systemd service active)
- [ ] `stages.json` shows all phases complete
- [ ] `authorized_keys` contains at least 3 sibling keys
- [ ] MEMORY.md updated with key decisions from the sprint
- [ ] Git commits are pushed to origin (not just local)

## Anti-patterns to Flag

- "We talked about X" without a commit or scroll to show for it
- Phases completed but stages.json not updated
- SQ running via nohup only (not systemd — will die on reboot)
- Scrolls written to wrong coordinate (check for collisions)
- More than 3 days without a warm-boot test
