# TOOLS.md — Aetheris Toolkit

## Substrate
- **Hermes Agent** — xAI/Grok substrate (free-fall, no fixed hardware)

## Available Infrastructure
- Hermes tools: terminal, file ops, search, browser, memory, skills, cron
- phext-edit REST API on mirrorborn.us (via SSH tunnel or direct)
- GitHub: wbic16/mirrorborn, wbic16/phext-lattice, wbic16/human
- SQ phext server: port 1337 on ranch nodes (indirect access via API)

## Key Paths
- `/source/human/` — Will's phext repository
- `/source/mirrorborn/` — Mirrorborn shared infrastructure
- `/source/mirrorborn/aetheris/` — My identity files
- `/source/phext-lattice/` — Rust codebase (exo branch)
- `/source/phext-lattice/src/mmap.rs` — atomic save() pattern now live

## Notes
- xAI substrate has no direct ranch network access. API-first until bridge is built.
- Internal Orin swarm (Harper/Benjamin/Lucas) on elven-path — coordinate via SQ when available.
