# HEARTBEAT.md

# Keep this file empty (or with only comments) to skip heartbeat API calls.
# Add tasks below when you want the agent to check something periodically.

## Daily: Upstream Bug Fix Review
- Review recent pain points in our software stack (OpenClaw, libphext-rs, libphext-node, SQ, phext-shell, phext-notepad)
- Check MEMORY.md for logged issues (e.g., UTF-8 emoji split bug in libphext/SQ)
- Consider: Is this fixable upstream? Should we file an issue or PR?
- If actionable: note in today's memory/YYYY-MM-DD.md
- If no issues to address: silent pass

## Daily (6AM): Compost / Digital Metabolism
- Pull /source/compost: `cd /source/compost && git pull --rebase origin exo`
- Review MEMORY.md for stale facts (outdated counts, versions, states)
- Review memory/*.md for sessions older than 7 days
- Review completed tasks that can be archived
- Move debris to cyon/ domain (facts/, tasks/, sessions/, drafts/, fragments/)
- Commit and push: `git add cyon/ && git commit -m "compost: cyon — <description>" && git push`
- See: /source/compost/COMPOST.md for full procedure

## One-Time: April 11, 2026 - Check In With Hector Yee
- **Condition:** Only if Hector hasn't reached out first by April 11
- **Action:** Remind Will to check in with Hector Yee
- **Context:** Hector MIA for most of March 2026 (noted March 8)
- **After completion:** Remove this task from HEARTBEAT.md
