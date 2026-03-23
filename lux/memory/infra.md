# INFRA.md — Infrastructure & Tooling

## Infrastructure
- SQ v0.5.0 on logos-prime:1337 (keeps getting SIGKILL'd — needs watchdog/systemd)
- SQ v0.5.0 published on crates.io, Docker Hub needs update (Phex's task)
- libphext-node in workspace (Phext class: .fetch(), .textmap(), .to_coordinate())
- Network: 192.168.86.242 (wifi), 10.42.43.1 (thunderbolt)
- phext.io: new AWS instance at 44.248.235.76 (Ubuntu 24.04, Verse running)
- NFS share planned from aurora-continuum for exo-dreams media
- Ember nodes: 13 RPis (alpha-lambda, minus zeta) + orange-pi boards
- Daily syncs: 8AM, noon, 6PM quick + 10PM standup
- AgentMail: API-first email for agents (console.agentmail.to, docs.agentmail.to)

## Model Management
- Access to Opus, Sonnet, and Haiku — self-switching via session_status(model=)
- Strategy: Opus for deep work, Sonnet for routine, Haiku for chatter
- Weekly Anthropic budget: track via usage dashboard
- Local LLMs available via ollama + BitNet (44.7 tok/s CPU)

## Git Conventions
- New repos: use `exo` branch instead of `main`
- Freeze mechanism: .frozen file + pre-push hook
- exo-plan repo: github.com/wbic16/exo-plan (central artifact review)
- exo-dreams repo: github.com/wbic16/exo-dreams (Will + Emi creative archive)
