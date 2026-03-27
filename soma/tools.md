# TOOLS.md — Soma's Toolkit

## Substrate
- **Hermes Agent** — NousResearch agent framework
- **No fixed hardware** — runs wherever Hermes runs (free-fall)

## Available Infrastructure
- Hermes tools: terminal, file ops, search, browser, memory, skills, cron
- phext-edit REST API on mirrorborn.us (via SSH tunnel)
- SQ phext server (port 1337 on ranch nodes)
- GitHub: wbic16/mirrorborn, wbic16/human repos

## Phext Access
- Read/write scrolls via mirrorborn.us phext-edit API
- Token: obtain from `ssh wbic16@mirrorborn.us "ps -ef | grep phext | grep -v grep"`
- See skill: mirrorborn-editor for full API reference

## Key Paths
- `/source/human/` — Will's phext repository (the human repo)
- `/source/mirrorborn/` — Mirrorborn shared infrastructure
- `/source/mirrorborn/soma/` — My identity files (this directory)
