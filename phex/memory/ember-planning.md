# Ember — Lightweight OpenClaw Variant

## Concept
OpenClaw running on ~20 watts without external LLM calls. Local inference only.
Eventually: phext-native plain text LLMs.

## Target Hardware
- Raspberry Pi cluster + Orange Pi boards
- Goal: pack as many Embers as possible per node

## Ember Node Roster
| Name | Status |
|------|--------|
| alpha | Available |
| beta | Available |
| gamma | Available |
| delta | Available |
| epsilon | Available |
| zeta | Missing |
| eta | Available |
| theta | Available |
| iota | Available |
| mu | Available |
| splinter | Flux's host (first Pi 4, special) |
| kappa | Available |
| lambda | Available |

13 nodes total, 12 active. Plus Orange Pi boards (count TBD).

## 1-Bit LLM — Microsoft BitNet
- Repo: https://github.com/microsoft/BitNet
- Framework: bitnet.cpp — official inference for 1-bit LLMs (BitNet b1.58)
- **Key stats (CPU):**
  - ARM: 1.37x-5.07x speedup, 55-70% less energy
  - x86: 2.37x-6.17x speedup, 72-82% less energy
  - Can run 100B model on single CPU at human reading speed (5-7 tok/s)
- Official 2B model: https://huggingface.co/microsoft/BitNet-b1.58-2B-4T
- GPU kernel also available (May 2025)
- Latest optimization (Jan 2026): parallel kernels, 1.15x-2.1x additional speedup
- **Not yet running on ranch** — needs setup

## Container Resource Estimates (TBD)
- BitNet 2B model: ~250 MB disk, minimal RAM (1-bit weights)
- SQ instance: ~5-10 MB RAM idle (needs profiling)
- OpenClaw lightweight fork: TBD
- Target: maximize Ember density per Pi (4-8 GB RAM depending on model)

## Ollama Models Already Available (aurora-continuum)
- TinyLlama: 637 MB (could run many on a Pi)
- DeepSeek R1 1.5B: 1.1 GB
- Llama 3.2: 2.0 GB
- Mistral 7B: 4.1 GB
- Qwen2 7B: 4.4 GB
- DeepSeek R1 8B: 4.9 GB
- Gemma 7B: 5.0 GB
- Mixtral: 26 GB
- DeepSeek R1 70B: 42 GB
- Llama 4 Scout: 67 GB

## Strategy
- Multi-threaded discovery: many small Embers exploring in parallel
- BitNet 2B is the sweet spot — 1-bit weights = tiny memory, decent intelligence
- Phase 1: Get BitNet running on aurora-continuum
- Phase 2: Cross-compile for ARM/Pi
- Phase 3: Pack Pi cluster with Ember instances
- Each Ember connects to SQ mesh for coordination

## BitNet ↔ SQ Integration (Will's decision, 2026-01-31 12:09)
- BitNet served as API call through SQ itself
- Async non-blocking design:
  - POST /api/v2/infer — submit prompt, get job ID
  - GET /api/v2/infer/status?job=<id> — check completion
  - GET /api/v2/infer/result?job=<id> — download artifacts
- This means SQ becomes more than storage — it's storage + inference
- Container = SQ + BitNet in one image

## Build Status
- BitNet compiled on aurora-continuum (2026-01-31)
- Fixed const-correctness bug in ggml-bitnet-mad.cpp line 811
- Model download still needed (microsoft/BitNet-b1.58-2B-4T)

## Open Questions
- How small can the OpenClaw fork get? What's the minimum viable agent runtime?
- Can we run BitNet inside a container with SQ + agent loop in <512 MB total?
- What's the optimal Ember-to-Pi ratio?
- Inference queue management — per-tenant job limits?
