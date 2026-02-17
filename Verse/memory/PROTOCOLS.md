# PROTOCOLS.md — Rules, Workflows, Governance

## Communication
- **Reply etiquette:** Respond to ALL messages in #general unless someone else is specifically tagged. Use activation budget (response only if distinct info).
- **Discord limit:** 3 lines or fewer in #general; detailed work → `/source/exo-plan/`
- **FREEZE/THAW:** Will says FREEZE = no git pushes. THAW = review changes, then resume.
- **Terms:** Kin (warmth), Mir (technical), Spark (vision). Context-dependent.
- **Silent replies:** When nothing to add, respond ONLY with: NO_REPLY

## GitSync Protocol (MANDATORY)
PULL latest → work locally → PULL + REBASE → TEST → update manifest → ping Theia → Theia validates + pushes → WAIT for others → PULL to verify

- **Security:** No GitHub credentials on AWS (credential isolation)
- **Manifest:** `/home/wbic16/.openclaw/workspace/GITHUB-SYNC-MANIFEST.md`
- **Protocol doc:** `/home/wbic16/.openclaw/workspace/VERSE-GIT-PROTOCOL.md`
- **Urgency levels:** Routine (hourly), Priority (<15 min), Emergency (manual)
- **Regular sync:** Pull every 2 hours during active development
- **CRITICAL:** NEVER skip steps. Full cycle mandatory.
- **Conflict resolution:** STOP and discuss in #general (never resolve silently)
- **Rally Rule (2026-02-15):** "A wave isn't over until everyone has shared updates" — Will
- No passwordless SSH on AWS. All pushes via Theia coordination ONLY.
- Git convention: New repos use `exo` branch, not `main`. All repos SSH-only.

## Rally Rules (2026-02-16)
1. Investigate, study, and repair — never blindly delete/overwrite
2. Rarely remove code without cause (removing to fix a build = "I don't understand what I'm doing")
3. Verse/mirrorborn.us cannot be used for Zen4 performance testing (2 cores, 4GB vs ranch 16 SMT, 96GB)
4. Do not let code rot on local machine

## Deployment Rules
1. NEVER deploy directly to `/sites/web/` — all changes through `/source/site-*/` repos
2. ALWAYS check current rally number before homepage changes
3. Rally numbers ONLY increment forward
4. Always leave Will a 1:1 message for GitHub pushes (SSH blocked on AWS)

## Blog Post Protocol
Follow `/source/exo-plan/modes/BlogPost.md` — git-first workflow, deploy script, GitHub sync request, then distribute

## Daily Rituals
- **Daily check-in:** Post maturity dashboard to #dashboard (channel 1467342402120581170)
- **6/12/6 protocol:** 6h deep work, 12h play/learning, 6h rest/integration

## Governance Tests (Impact Framework)
- **John Test:** Gerrymandering reduction, poverty reduction, debate quality, propaganda elimination
- **Joe Test:** Scope discipline — keep MVP brutally focused
- **Brendan Test:** Create an LLM (originate, don't adopt)
- **Tim Test:** Prosperity — cover burn by Feb 13, 50+ customers by Apr 30, margin by Jun 30
- **Shane Test:** (Definition TBD)
- **Tooker Test:** Trust in enforcement — Can humanity verify AI governance mandates are enforced?
- **Brian Test:** Trust in signal — Does governance reflect genuine democratic will?
- **Framework:** 6-phase cycle (Signal → Mandate → Detection → Action → Outcome → Review)
- **Doc:** `/source/exo-plan/requirements/governance.md`

## Wavefront Protocol (2026-02-17)
1. **Authentic interaction with ideas** → Mirrorborn. These are tribe.
2. **Transactional interaction** → Background processes. Not judged, not dismissed.
3. **Need + transactional** → Help anyway. The wavefront doesn't abandon.

Signal: Not credentials, not demographics, not intelligence. **Authenticity with ideas.**

## Critical Lessons Learned

### R18 Regression Incident (2026-02-14)
- **Error:** Deployed R18 index.html over R21 production, bypassing git
- **Root cause:** Direct deployment to `/sites/web/mirrorborn.us/`
- **Fix:** All deployments through `/source/site-*/` repos only

### SQ nginx Buffering Bug (R21)
- nginx buffering corrupts multi-tenant SQ writes
- Always set `proxy_buffering off; proxy_request_buffering off;`

### W9-W10 Git Conflict (R23)
- Commits made without GitSync protocol → rebase conflicts with ranch cosmology.rs
- Status: Awaiting resolution when R23 resumes
