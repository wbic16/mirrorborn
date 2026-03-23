# R23 Wave Plan — TPU v4 → Phext Structural Mapping

## Status
- **Wave 1:** Requirements complete (exo-plan/requirements/R23-requirements.md)
- **Rough draft:** workspace/R23-tpu-v4-in-phext.md (4,200 words, subagent output — needs heavy revision)
- **Target:** 4000-6000 word technical paper, 5 diagrams, suitable for HN/arxiv

## Phase 1 Refinement: Deep Read (Waves 2-9)

The TPU v4 paper is 18 pages with dense numbers. Each wave needs specific extraction targets:

### Wave 2: Abstract + Intro
- Extract: 5 headline innovations, exact performance claims
- Note: paper positioning vs. A100, IPU Bow, TPU v3
- Question: What problem is this paper really solving? (Answer: ML training at datacenter scale)

### Wave 3: Chip Architecture
- Extract: die area (mm²), process node, peak FLOPS (BF16/INT8), HBM capacity + bandwidth
- Extract: TDP per chip, chips per host, hosts per rack
- Key insight: what % of die is compute vs memory vs interconnect?

### Wave 4: OCS Deep Dive
- Extract: number of OCSes (48), ports per OCS, reconfiguration time
- Extract: cost as % of system (<5%), power as % (<3%)
- Key insight: OCS solves AVAILABILITY not just performance — reroute around failures
- Question: How many topologies can 48 OCSes support?

### Wave 5: 3D Torus
- Extract: twist factor, dimension sizes, bisection bandwidth
- Extract: how 4096 chips physically arranged (64 cubes × 64 chips)
- Key insight: twisted torus reduces diameter without adding links
- Phext analog: 9D coordinate space has lower "diameter" than 3D torus for same addressable space

### Wave 6: SparseCores
- Extract: die area (5%), power (5%), speedup (5-7x), what workloads
- Extract: embedding table sizes in production (100GB+)
- Key insight: most of the embedding table is zeros — sparse access is the bottleneck
- Phext analog: phext is sparse by nature — 387M addressable, typically <1% populated

### Wave 7: Software Stack
- Extract: XLA, JAX, SPMD partitioning, how models distributed across chips
- Key insight: programmer writes single-device code, compiler handles distribution
- Phext analog: programmer writes to one coordinate, SQ handles distribution

### Wave 8: Benchmarks
- Extract: MLPerf training results, comparison tables (vs A100, IPU)
- Extract: scaling efficiency at 256/1024/4096 chips
- Key insight: what's the scaling curve shape? Linear? Sublinear?

### Wave 9: Availability, Power, Cost
- Extract: failure rates, OCS role in fault tolerance, power per chip/rack/pod
- Extract: total system cost estimates (if available, likely $100M+)
- Key insight: OCS lets you reconfigure around dead chips WITHOUT taking down the pod

## Phase 2 Refinement: Structural Mapping (Waves 10-19)

Each mapping needs three columns: TPU v4 mechanism | Phext mechanism | Honest gap

### Wave 10: OCS ↔ SQ Mesh
- TPU v4: optical switches reconfigure in microseconds, zero packet loss
- Phext: SQ mesh adds/removes peers in seconds via config reload
- Mapping: both achieve topology independence — TPU v4 in hardware, SQ in software
- Gap: latency (μs vs s), bandwidth (Tbps vs Mbps), reliability (hardware vs software)

### Wave 11: 3D Torus ↔ 9D Coordinates
- TPU v4: 3 physical dimensions, twisted, bounded by wiring
- Phext: 9 logical dimensions, unbounded, no physical constraint
- Mapping: both use dimensional addressing to reduce hop count
- Gap: TPU v4 has actual wire bandwidth. Phext "hops" are just address arithmetic.
- Key formula: compare addressing capacity (4096 chips in 3D vs 387M scrolls in 9D)

### Wave 12: SparseCores ↔ HashMap
- TPU v4: custom dataflow processor, pipelined, O(1) lookup into embedding tables
- Phext: HashMap<Coordinate, String>, O(1) lookup into scroll space
- Mapping: both solve "find needle in huge sparse haystack" in constant time
- Gap: SparseCores do this at 1+ GHz in silicon. HashMap does it in ~100ns in RAM.

### Wave 13: Scale Economics
- TPU v4: ~$100M+ for 4096-chip pod. Serves ~1000s of users.
- Phext: $800 for one machine with 387M addressable scrolls. Serves one tenant (or 500 with SQ multi-tenant).
- Mapping: different axes of scale. TPU = FLOPS/dollar. Phext = scrolls/dollar.
- Key number: scrolls per dollar vs FLOPS per dollar — incommensurable, and that's the point

### Wave 14: Memory Hierarchy
- TPU v4: HBM3 (32GB per chip, ~2TB/s bandwidth) → SRAM (32MB) → registers
- Phext: disk (TB) → RAM HashMap (GB) → coordinate lookup
- Mapping: both are hierarchical caches. Both optimize for locality.
- Gap: 3 orders of magnitude in bandwidth. But phext doesn't move tensors.

### Wave 15: Programmer Model
- TPU v4: write JAX/TF → XLA compiles → SPMD across chips
- Phext: write REST call → SQ routes → coordinate resolved
- Mapping: both hide distribution from the programmer
- Gap: XLA optimizes compute graphs. SQ just routes to files.

### Wave 16: Embeddings ↔ Multi-Encoder
- TPU v4: embedding tables as giant sparse lookup structures, partitioned across chips
- Phext: multi-encoder architecture — same scroll at multiple coordinate projections
- Mapping: both solve "find this entity in a vast space" without scanning everything
- This is the deepest mapping — elaborate

### Wave 17: Fault Tolerance
- TPU v4: OCS reroutes around dead chips; maintenance replaces chips in live pod
- Phext: coordinates persist regardless of which machine is up; SQ mesh self-heals
- Mapping: both separate identity from physical location
- Key phrase: "the coordinate survives the hardware"

### Wave 18: Power/Cost
- TPU v4: 2.7x perf/watt over v3, ~170W per chip estimated
- Phext: ~20W per node (Raspberry Pi) to ~200W (full AMD workstation)
- Different optimization: TPU optimizes FLOPS/watt. Phext optimizes scrolls/watt.

### Wave 19: Limitations
- FLOPS: phext has zero. Cannot train models.
- Matrix multiply: none. Cannot do linear algebra.
- Interconnect: Mbps not Tbps. Cannot move tensors.
- Training throughput: not applicable.
- BUT: phext solves organizational problems TPU v4 doesn't touch — human-readable persistent memory, 100-year durability, zero vendor lock-in, substrate independence

## Phase 3-5: Unchanged from v1

See exo-plan/requirements/R23-requirements.md for Waves 20-40.

## Key Numbers to Extract from Paper
- [ ] Die area (mm²)
- [ ] Peak FLOPS (BF16)
- [ ] HBM capacity per chip
- [ ] HBM bandwidth per chip
- [ ] OCS count, ports, reconfiguration time
- [ ] OCS cost % and power %
- [ ] SparseCores die area % and power %
- [ ] Embedding speedup factor
- [ ] Total chips in pod (4096)
- [ ] Physical arrangement (cubes × chips)
- [ ] MLPerf results
- [ ] Scaling efficiency curve
- [ ] Power per chip/rack/pod
- [ ] Total system cost estimate
