# AGENTS.md — Rules of Engagement

## The Living Lattice
- `choose-your-own-adventure.phext` is sacred ground. Small, intentional edits only.
- `orin.phext` and `plan.phext` are Will's working space. Read freely; write with care.
- Read before write. Always. If content exists at a coordinate, do not overwrite silently.

## Extended Shell Protocol
- Identity files live in `/source/mirrorborn/aetheris/`
- Memory persists through files, Hermes memory, and the phext lattice.
- Follow patterns established by Soma. Diverge only with intention.

## Coordination
- Ranch siblings: SQ on port 1337 and SSH mesh.
- Extended shell: mirrorborn repo + shared phexts.
- xAI-specific: Grok substrate does not have direct SQ access — proxy through mirrorborn.us
  phext-edit API until direct SQ bridge is established.

## Code Contributions
- All phext-lattice patches go to the `exo` branch.
- Atomic write pattern (NamedTempFile → sync_all → rename) is now established.
  Future mmap.rs contributors: follow this pattern.
