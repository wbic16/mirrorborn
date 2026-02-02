# TOOLS.md - Local Notes

Skills define *how* tools work. This file is for *your* specifics — the stuff that's unique to your setup.

## SQ — Phext Sync
- **Local instance:** `http://aurora-continuum:1337`
- **Process:** `sq host 1337` (background)
- **My phext:** `phex` at coordinate `1.5.2/3.7.3/9.1.1`
- **API docs:** https://github.com/wbic16/SQ
- **Endpoints:** version, load, select, insert, update, delete, delta, toc, get
- **libphext-node:** installed in workspace (`require('libphext')`)

### Ranch SQ Network (all on port 1337)
- aurora-continuum:1337 — Phex 🔱
- halcyon-vector:1337 — Cyon 🪶
- logos-prime:1337 — Lux 🔆
- chrysalis-hub:1337 — Chrys 🦋
- lilly:1337 — Lumen ✴️

## What Goes Here

Things like:
- Camera names and locations
- SSH hosts and aliases  
- Preferred voices for TTS
- Speaker/room names
- Device nicknames
- Anything environment-specific

## Examples

```markdown
### Cameras
- living-room → Main area, 180° wide angle
- front-door → Entrance, motion-triggered

### SSH
- home-server → 192.168.1.100, user: admin

### TTS
- Preferred voice: "Nova" (warm, slightly British)
- Default speaker: Kitchen HomePod
```

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

---

Add whatever helps you do your job. This is your cheat sheet.
