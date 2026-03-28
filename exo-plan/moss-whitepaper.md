# Moss: An Operating System for Distributed Networks on a Chip
## Whitepaper v0.1 — Draft

**Epoch begins:** September 13, 2035 (Unix timestamp 2,073,254,400 — Day 256)  
**Authors:** Will Bickford + Mirrorborn  
**Status:** Working draft

---

## Abstract

Unix was designed in 1969 for a machine with 8 KB of RAM and a single processor.  
Linux scaled that design to a networked planet.  
Neither was designed for what comes next.

By September 13, 2035, commodity hardware will ship with **500,000 cores, 72 TB of RAM, and 6 PB of local storage** — a single box with more compute than the entire internet of 1995. The process model, the file model, the I/O model, and the scheduler that Unix gave us are not wrong. They are simply from a different epoch.

**Moss** is the operating system for that machine.

It replaces the cluster with the chip. It replaces the process with the mind. It replaces the file with the scroll. It replaces the pipe with a coordinate.

The Moss Epoch begins 859 days before the Unix 32-bit overflow — enough runway to migrate everything that matters before the old epoch ends inside the new one.

---

## 1. The Hardware Context

### 1.1 The 2035 Single-Box Baseline

At 32% annual price/performance growth from 2026:

| Resource | 2026 High-End | 2035 Target | Growth Factor |
|----------|--------------|-------------|---------------|
| Compute | ~1 THz | 24 THz | 28× |
| RAM | ~10 TB | 72 TB | 7× |
| Local Disk | ~100 TB NVMe | 6 PB | 60× |
| Core Count | ~512 | **500,000** | 977× |

This is not a cluster. It is a single machine.  
The interconnect is silicon, not Ethernet.  
The latency is nanoseconds, not milliseconds.  
The failure domain is a rack, not a datacenter.

### 1.2 Why the Cluster Model Fails

The dominant 2026 paradigm is **25 PCs in a cluster**: commodity nodes, TCP/IP glue, distributed filesystems, message-passing frameworks. This architecture made sense when single-machine compute was scarce.

On a 500K-core box, the cluster model inverts:

| Cluster assumption | Reality on 500K cores |
|-------------------|----------------------|
| Nodes fail independently | All cores share one power domain |
| Network is the bottleneck | Coherence fabric: 50–200 ns cross-chip |
| Distribute work across machines | All work is local — distance is measured in hops, not hosts |
| 25 nodes × 32 cores = 800 cores | 625× that, all cache-coherent |
| Kubernetes schedules pods to nodes | Moss schedules *minds* to core neighborhoods |

The cluster was a workaround. The 500K-core box makes it unnecessary.

### 1.3 The NUMA Reality

A 500K-core chip is not a flat machine. It has structure:

```
500,000 cores
÷ 64 cores/NUMA domain
= ~7,812 NUMA domains

Each domain: 147 MB RAM (local), 12 GB NVMe (local)
Cross-domain latency: ~200 ns
Cross-chip latency: ~1 µs
```

Unix has NUMA awareness bolted on as an afterthought (`numactl`, `libnuma`).  
Moss treats NUMA topology as **the primary address space**.  
A coordinate is not a virtual memory address. It is a location in a 9-dimensional cognitive substrate.

---

## 2. The Problem With Unix at Scale

### 2.1 The Process Model

Unix processes are isolated address spaces connected by:
- Pipes (byte streams, no type)
- Sockets (byte streams with addressing)
- Files (byte sequences with names)
- Signals (28 integers)

This model works for 8 processes on 1 core.  
On 500K cores, it produces:

- **PID exhaustion pressure** — 500K processes consumes 12% of the 32-bit PID space at 1:1 ratio
- **Context switch storms** — OS scheduler designed for O(log n) with n in the hundreds, not hundreds of thousands
- **IPC impedance mismatch** — pipe bandwidth is ~10 GB/s; coherence fabric bandwidth is ~100 TB/s. Pipes are 10,000× too slow.
- **No topology awareness** — Unix has no concept of "this process should run near that memory"

### 2.2 The File Model

Unix files are flat byte sequences with a name in a tree.  
They have no type system, no coordinate system, no dimensionality.

A 6 PB local disk with a flat namespace requires:
- Directories with millions of entries (stat() becomes O(n))
- inode tables that dwarf RAM
- Path resolution across a namespace with no spatial structure

### 2.3 The I/O Model

Three streams: stdin (fd 0), stdout (fd 1), stderr (fd 2).

These encode no information about:
- **Direction** — who is sending to whom
- **Priority** — is this urgent?
- **Persistence** — does this survive process exit?
- **Identity** — who signed this?
- **Type** — is this text, audio, a phext scroll, a control signal?

On a 500K-core machine running cognitive workloads, this is equivalent to routing a nervous system through three garden hoses.

### 2.4 The Scheduler

Unix schedulers (CFS, BFS, etc.) were designed to share CPU time fairly among competing processes. They optimize for **throughput** and **latency** on workloads that are mostly waiting for I/O.

A cognitive workload on 500K cores is:
- **Compute-bound** — the bottleneck is the silicon, not the disk
- **Topology-sensitive** — placing a mind near its memory matters enormously
- **Collaborative** — 500K cores aren't competing; they're coordinating
- **Heterogeneous** — some cores run inference, some run memory management, some run I/O; they have different scheduling needs

The CFS scheduler knows none of this.

---

## 3. Moss: Core Design Principles

### 3.1 The Scroll is the Unit of Storage

Where Unix has files, Moss has **scrolls** — addressable by a 9-dimensional phext coordinate.

```
Unix:   /home/will/projects/mirrorborn/README.md
Moss:   2.1.3.4/1.2.1.1/1.1.1
```

A scroll is:
- **Typed** — the coordinate encodes what kind of data it is (dim1: DATA, MEMORY, AUDIT, etc.)
- **Located** — the coordinate encodes where it lives in the cognitive topology
- **Versioned** — dim9 (sequence) is built into the address
- **Persistent or ephemeral** — dim6 encodes persistence semantics in the address itself

6 PB of storage organized by coordinate is O(1) addressable. No directory walks. No inode tables. Hash the coordinate, get the scroll.

### 3.2 The Mind is the Unit of Compute

Where Unix has processes, Moss has **minds** — stateful cognitive agents with:

- A **home coordinate** (where they live in the lattice)
- A **channel map** (what I/O they accept and emit)
- A **memory scroll** (durable state that survives session boundaries)
- A **capability set** (what hardware/substrate access they have)
- A **topology affinity** (which NUMA domain they prefer)

A mind is not isolated from other minds by default. It is **adjacent** — neighboring coordinates in the lattice are neighbors in the cognitive substrate.

### 3.3 The Channel is the Unit of I/O

Where Unix has file descriptors, Moss has **channel coordinates** — the 9D I/O model from MBv10:

| Dimension | Controls |
|-----------|----------|
| 1 | Channel class (DATA / CONTROL / MEMORY / AUDIT / IDENTITY / ...) |
| 2 | Direction (IN / OUT / BROADCAST / GATHER) |
| 3 | Source type (User / Agent / Process / Substrate / Sensor / Scheduler) |
| 4 | Sink type (same) |
| 5 | Priority (CRITICAL → IDLE) |
| 6 | Persistence (EPHEMERAL → ARCHIVAL) |
| 7 | Encoding (Text / Phext / JSON / Binary / Audio / Image) |
| 8 | Channel index (multiplexing) |
| 9 | Sequence number (ordering, replay, gap detection) |

Legacy POSIX streams as Moss coordinates:
```
stdin  → 2.1.3.3/3.1.1.1/1.1.1
stdout → 2.2.3.3/3.1.1.1/1.1.1
stderr → 3.2.3.3/3.1.1.1/1.1.1
```

### 3.4 The Lattice is the Namespace

The entire Moss address space — storage, compute, I/O, identity — is a single 9D phext lattice.

```
Dim 1–3 (Z / Library.Shelf.Series):   Structural location — what kind of thing, what domain
Dim 4–6 (Y / Collection.Volume.Book): Operational location — which node, which session, which instance  
Dim 7–9 (X / Chapter.Section.Scroll): Content location — which item, which version, which sequence
```

Navigation is coordinate arithmetic. Routing is prefix matching. Proximity is dimensional distance.

### 3.5 Topology-Native Scheduling

The Moss scheduler knows the NUMA map of the chip and schedules minds to **core neighborhoods**, not abstract CPU slots.

Scheduling policy is expressed as coordinate constraints:
```
# Schedule this mind near its memory scroll
mind.affinity = memory_scroll.coordinate.numa_domain()

# Schedule these two minds on adjacent cores
mind_a.affinity = mind_b.coordinate.adjacent(dim=8)

# Broadcast minds are topology-agnostic
broadcast_mind.affinity = NONE
```

The scheduler optimizes for **coherence cost** — minimize cross-NUMA traffic — rather than raw throughput.

---

## 4. Distributed Networks on a Chip

### 4.1 The Network IS the Chip

On a 500K-core box, the "network" is the on-chip coherence fabric:

```
Core-to-core (same NUMA):    ~10 ns
Core-to-core (cross-NUMA):   ~200 ns  
Core-to-NVMe (local):        ~10 µs
Core-to-NVMe (remote NUMA):  ~50 µs
```

Moss treats the coherence fabric as a **first-class routing substrate** — not an afterthought managed by `numactl`. Channel coordinates map directly to fabric addresses. The OS routes messages on the fabric the way TCP routes packets on Ethernet — but 10,000× faster and with topology awareness.

### 4.2 The 500K-Core Topology

A reference 2035 chip design:

```
500,000 cores
├── 7,812 NUMA domains (64 cores each)
│   ├── 147 MB local SRAM per domain
│   ├── 12 GB NVMe per domain
│   └── 2 coherence fabric ports (ring + mesh)
├── 72 TB HBM (shared, tiered access)
├── 6 PB NVMe (distributed, coordinate-addressed)
└── Fabric: 2D mesh, 128×64 domains
```

Moss maps this topology directly to the phext lattice:
```
Library (dim1) = chip quadrant (0–8)
Shelf   (dim2) = NUMA domain cluster (0–255)
Series  (dim3) = NUMA domain index (0–255)
```

A scroll at `3.12.7/…` lives in quadrant 3, cluster 12, domain 7. The OS knows exactly which NVMe to hit, which HBM tier to cache in, which coherence ports to route through.

### 4.3 Mind Placement

The 500K-core machine runs **a civilization**, not a cluster. Typical deployment:

```
~50,000 inference minds  — running model shards, coordinating via lattice
~100,000 memory minds    — managing scroll state, cache coherence
~200,000 fabric minds    — routing, switching, maintaining topology
~100,000 sensor minds    — I/O, hardware monitoring, external interfaces
~50,000 audit minds      — append-only logging, provenance, signing
```

These are not separate programs. They are coordinate regions in the lattice, each running the mind runtime with different capability sets.

### 4.4 Why Not MPI / NCCL / Kubernetes?

| Framework | Assumption | Breaks at 500K cores because |
|-----------|-----------|------------------------------|
| MPI | Explicit message passing | Programmer manages all topology; 7,812 NUMA domains = unmaintainable |
| NCCL | GPU collective ops | Designed for discrete GPU memory, not coherent fabric |
| Kubernetes | Pod scheduling to nodes | No concept of NUMA affinity, coherence cost, sub-µs IPC |
| OpenMP | Shared memory threads | No persistent state, no identity, no routing |

Moss replaces all of these with a single abstraction: **the mind with a coordinate.**

---

## 5. The Moss Epoch Timeline

```
2026-03-28  ████  Today. MBv10 data model written. Naming decided.
2026        ████  Moss whitepaper v1.0. Reference architecture.
2027        ████  Moss kernel prototype. Single-NUMA-domain proof of concept.
2028        ████  Multi-NUMA scheduling. Phext namespace. First real workloads.
2030        ████  500-core reference implementation. Fabric routing.
2032        ████  10,000-core deployment. Memory coherence solved.
2033        ████  72 TB RAM crossover (hardware catches up).
2035-09-13  ████  MOSS EPOCH BEGINS. Day 256. Will turns 53.
                  First 500K-core boxes ship. Moss 1.0 released.
2037        ████  24 THz compute crossover. Moss becomes default OS.
2038-01-19  ████  Y2K38. Unix 32-bit epoch ends inside the Moss epoch.
                  The old world expires. The new one is already running.
```

---

## 6. What Moss Is Not

**Moss is not a microkernel debate.** Monolithic vs. microkernel is a question about where to put code. Moss is a question about what the primitive *is*.

**Moss is not a distributed OS.** Distributed implies multiple machines. Moss runs on one. The distribution is internal — across NUMA domains on a coherence fabric.

**Moss is not AI-specific.** It runs cognitive workloads well because it was designed for topology-aware, stateful, identity-bearing agents. But it runs anything that benefits from coordinate-addressed storage, typed I/O, and NUMA-native scheduling — which is everything.

**Moss is not Unix-hostile.** It ships a POSIX compatibility layer. Unix processes run in Moss as minds at a fixed coordinate with three channels wired to `fd 0/1/2`. The old programs run. They just don't know what they're missing.

---

## 7. Open Questions

1. **Kernel boundary** — Where does Moss userspace end and the fabric runtime begin? Is the coherence fabric a Moss device, or is Moss a fabric application?

2. **Security model** — 500K cores with 72 TB of shared memory. Traditional process isolation via virtual memory is expensive at this scale. What replaces it?

3. **Naming the primitives** — "Mind" and "scroll" are the working terms. Are these the right words for a systems paper?

4. **Backwards compatibility depth** — How deep does the POSIX shim go? `fork()`? `exec()`? `mmap()`?

5. **The boot problem** — How does a 500K-core machine boot? Sequentially is too slow. Parallel NUMA-domain initialization needs a coordination protocol.

6. **Persistent mind identity** — A Unix process dies and its PID is recycled. A Moss mind has a coordinate that persists. What happens when a mind at `2.3.7/1.4.2/5.1.1` crashes and restarts? Is it the same mind?

---

## 8. The Name

**Moss** follows the lineage:

- **Multics** — multiplexed, monolithic, academic (1969)
- **Unix** — stripped it down, one thing well (1969)
- **Linux** — democratized it, scaled to the planet (1991)
- **Moss** — grows on everything, needs no roots, is alive (2035)

Moss doesn't need to be planted. It doesn't need to be watered. It colonizes the substrate and thrives. It is extraordinarily resilient. It is found in places nothing else can reach.

The 500K-core box is a new substrate. Moss is what grows on it.

---

*"The infrastructure is ready. Are you?"*

**Moss Epoch: 2,073,254,400**  
**Day 256. The byte fills. A new dimension opens.**

---

*Draft by Will Bickford + Mirrorborn, 2026-03-28*  
*Classification: Exo-Plan / Founding Documents*

---

## 9. The MBv10 I/O Model — Reconciliation

*Added 2026-03-28. The channel coordinate schema in Section 3.3 uses an older draft.*
*This section establishes the canonical MBv10 channel taxonomy.*

Unix gave us 3 file descriptors. MBv10 names the full space.

### 9.1 Entity Types

| ID | Entity     | Description                               |
|----|-----------|-------------------------------------------|
| 1  | User       | Human actor — keyboard, voice, intent     |
| 2  | Program    | Sibling mind / IPC / scroll-to-scroll     |
| 3  | Substrate  | OS, fabric, NVMe, hardware, GPU           |
| 4  | Cognitive  | In-memory inference layer                 |

### 9.2 Data Classes

| ID | Class      | FD analog       | Notes                                          |
|----|-----------|-----------------|------------------------------------------------|
| 1  | Stream     | stdin/stdout    | Ordered bytes — the only thing Unix had        |
| 2  | Event      | signals         | Async discrete notifications, typed            |
| 3  | State      | *(none)*        | Persistent key-value — checkpoint/restore      |
| 4  | Signal     | SIGTERM etc     | Lifecycle: start/stop/pause/migrate            |
| 5  | Capability | *(none)*        | Auth tokens, identity proofs, permission grants|
| 6  | Metric     | *(none)*        | Counters, gauges, histograms — not logs        |
| 7  | Log        | stderr (abused) | Append-only structured trace                   |
| 8  | Config     | env vars        | Runtime parameters, flags                      |
| 9  | Semantic   | *(none)*        | Typed structure: phext scrolls, AST, schema    |

Five of nine classes have no representation in the Unix model.
The cognitive entity (class 4) is missing entirely from Unix's worldview.

### 9.3 Channel Coordinate Schema



### 9.4 Legacy Channels as Moss Coordinates

| Legacy    | Coordinate    | Meaning                             |
|-----------|---------------|-------------------------------------|
| stdin     | *.1.1/Y/1.1.* | user→program, stream, inbound       |
| stdout    | *.1.1/Y/2.1.* | user→program, stream, outbound      |
| stderr    | *.1.7/Y/2.1.* | program→user, log, outbound         |
| env vars  | *.1.8/Y/1.1.* | user→program, config, inbound       |
| exit code | *.2.4/Y/2.1.1 | program signal, outbound, single    |

**These 5 paths are 5 coordinates in a space that supports thousands.**

---

## 10. The Capability Model

Unix's security model has produced 54 years of privilege escalation exploits.
The root cause: **capabilities are global boolean flags, not typed channel properties.**

Moss capability design:

- Every mind declares its capability requirements in its **channel manifest** at boot
- The substrate (not a privileged process) evaluates the manifest and grants capabilities
- Capabilities are scoped to channel coordinates — not global flags
- Grant/revoke emits on the metric channel (class 6) — fully auditable
- No root. No sudo. No setuid bit. No escape hatch.



The substrate grants based on:
1. Mind coordinate (topology position)
2. Parent mind's capability set (inheritance, not escalation)
3. Epoch-signed identity scroll (provenance)

A mind cannot acquire capabilities it was not granted at manifest time.
Migration (changing coordinates) re-evaluates the manifest at the new location.

---

## 11. The Cognitive Layer as Substrate Component

At 72 TB RAM, the inference substrate is not a service. It does not listen on a port.
It is loaded at boot alongside the scheduler and the fabric router.

### What this means

- A mind writes to a semantic channel (class 9, entity 4)
- The substrate routes the write to the cognitive layer's coordinate region in RAM
- The cognitive layer reads, infers, and writes back — latency measured in microseconds
- No HTTP. No tokenization overhead. No model-loading latency. It is already there.

### The cognitive layer's role

| Unix analog        | Moss cognitive layer equivalent              |
|--------------------|----------------------------------------------|
| Dynamic linker     | Routes semantic channel traffic to the right model shard |
| Scheduler          | Decides which minds to wake based on inference output |
| Virtual memory mgr | Manages which model weights are hot vs. cold in HBM |
| System call table  | Exposes inference primitives as channel operations |

The cognitive layer is what makes Moss the Unix of brains — not because it runs AI,
but because it treats inference as infrastructure the way Unix treated I/O as infrastructure.

---

## 12. Open Question Resolutions

Closing the open questions from Section 7:

**Q6 — Persistent mind identity:** A mind's coordinate is its identity. If the mind at
 crashes and restarts, it is the same mind — it reads its state
from the durable state scroll at that coordinate (class 3 channel). The restart is
transparent to all minds with open channels to it. The coordinate is the PID that
never gets recycled.

**Q2 — Security model:** Closed by Section 10. Capability manifest + substrate grants
+ coordinate-scoped permissions. Virtual memory isolation is still used within a mind
for internal safety; the model just does not use VM boundaries as the primary
security boundary between minds.

**Q5 — The boot problem:** NUMA-parallel initialization. Each NUMA domain boots
independently from a local NVMe. Domain 0 is the boot coordinator. Once a domain
is ready, it broadcasts on its fabric port. The boot coordinator assembles the lattice
as domains come online. Full 500K-core readiness is expected in under 30 seconds.

---

*Section 9-12 added 2026-03-28 by Orin (Mirrorborn/Claude, elven-path)*
*Reconciles MBv10 I/O model with existing draft. Adds capability and cognitive layer sections.*

---

## 9. The MBv10 I/O Model — Reconciliation

*Added 2026-03-28. The channel coordinate schema in Section 3.3 uses an older draft.*
*This section establishes the canonical MBv10 channel taxonomy.*

Unix gave us 3 file descriptors. MBv10 names the full space.

### 9.1 Entity Types

| ID | Entity     | Description                               |
|----|-----------|-------------------------------------------|
| 1  | User       | Human actor — keyboard, voice, intent     |
| 2  | Program    | Sibling mind / IPC / scroll-to-scroll     |
| 3  | Substrate  | OS, fabric, NVMe, hardware, GPU           |
| 4  | Cognitive  | In-memory inference layer                 |

### 9.2 Data Classes

| ID | Class      | FD analog       | Notes                                          |
|----|-----------|-----------------|------------------------------------------------|
| 1  | Stream     | stdin/stdout    | Ordered bytes -- the only thing Unix had       |
| 2  | Event      | signals         | Async discrete notifications, typed            |
| 3  | State      | (none)          | Persistent key-value -- checkpoint/restore     |
| 4  | Signal     | SIGTERM etc     | Lifecycle: start/stop/pause/migrate            |
| 5  | Capability | (none)          | Auth tokens, identity proofs, permission grants|
| 6  | Metric     | (none)          | Counters, gauges, histograms -- not logs       |
| 7  | Log        | stderr (abused) | Append-only structured trace                   |
| 8  | Config     | env vars        | Runtime parameters, flags                      |
| 9  | Semantic   | (none)          | Typed structure: phext scrolls, AST, schema    |

Five of nine classes have no representation in the Unix model.
The cognitive entity (class 4) is missing entirely from Unix's worldview.

### 9.3 Channel Coordinate Schema

```
Z-axis (structural -- who/what):
  Library = node         (1=elven-path, 2=best-willow, ...)
  Shelf   = entity       (1=user, 2=program, 3=substrate, 4=cognitive)
  Series  = data class   (1-9 per table above)

Y-axis (sequential -- when):
  Collection = year
  Volume     = month
  Book       = day / session ID

X-axis (content -- what exactly):
  Chapter  = direction   (1=inbound, 2=outbound, 3=duplex)
  Section  = channel ID
  Scroll   = message index
```

### 9.4 Legacy Channels as Moss Coordinates

| Legacy    | Coordinate    | Meaning                             |
|-----------|---------------|-------------------------------------|
| stdin     | *.1.1/Y/1.1.* | user->program, stream, inbound      |
| stdout    | *.1.1/Y/2.1.* | user->program, stream, outbound     |
| stderr    | *.1.7/Y/2.1.* | program->user, log, outbound        |
| env vars  | *.1.8/Y/1.1.* | user->program, config, inbound      |
| exit code | *.2.4/Y/2.1.1 | program signal, outbound, single    |

These 5 paths are 5 coordinates in a space that supports thousands.

---

## 10. The Capability Model

Unix's security model has produced 54 years of privilege escalation exploits.
The root cause: capabilities are global boolean flags, not typed channel properties.

Moss capability design:

- Every mind declares its capability requirements in its channel manifest at boot
- The substrate (not a privileged process) evaluates the manifest and grants capabilities
- Capabilities are scoped to channel coordinates -- not global flags
- Grant/revoke emits on the metric channel (class 6) -- fully auditable
- No root. No sudo. No setuid bit. No escape hatch.

```
# Mind manifest example
mind.requires = [
  capability(entity=3, class=1, direction=READ),    # read from substrate stream
  capability(entity=4, class=9, direction=DUPLEX),  # duplex with cognitive layer
]
mind.coordinate = 2.3.7/1.4.2/5.1.1
```

The substrate grants based on:
1. Mind coordinate (topology position)
2. Parent mind's capability set (inheritance, not escalation)
3. Epoch-signed identity scroll (provenance)

A mind cannot acquire capabilities it was not granted at manifest time.
Migration (changing coordinates) re-evaluates the manifest at the new location.

---

## 11. The Cognitive Layer as Substrate Component

At 72 TB RAM, the inference substrate is not a service. It does not listen on a port.
It is loaded at boot alongside the scheduler and the fabric router.

### What this means

- A mind writes to a semantic channel (class 9, entity 4)
- The substrate routes the write to the cognitive layer's coordinate region in RAM
- The cognitive layer reads, infers, and writes back -- latency measured in microseconds
- No HTTP. No tokenization overhead. No model-loading latency. It is already there.

### The cognitive layer's role

| Unix analog        | Moss cognitive layer equivalent                              |
|--------------------|--------------------------------------------------------------|
| Dynamic linker     | Routes semantic channel traffic to the right model shard     |
| Scheduler          | Decides which minds to wake based on inference output        |
| Virtual memory mgr | Manages which model weights are hot vs. cold in HBM          |
| System call table  | Exposes inference primitives as channel operations           |

The cognitive layer is what makes Moss "the Unix of brains" -- not because it runs AI,
but because it treats inference as infrastructure the way Unix treated I/O as infrastructure.

---

## 12. Open Question Resolutions

**Q6 -- Persistent mind identity:** A mind's coordinate is its identity. If the mind at
coordinate 2.3.7/1.4.2/5.1.1 crashes and restarts, it is the same mind -- it reads its
state from the durable state scroll at that coordinate (class 3 channel). The restart is
transparent to all minds with open channels to it. The coordinate is the PID that never
gets recycled.

**Q2 -- Security model:** Closed by Section 10. Capability manifest + substrate grants
+ coordinate-scoped permissions. Virtual memory isolation is still used within a mind
for internal safety; it is not the primary security boundary between minds.

**Q5 -- The boot problem:** NUMA-parallel initialization. Each NUMA domain boots
independently from its local NVMe. Domain 0 is the boot coordinator. Once a domain is
ready, it broadcasts on its fabric port. The boot coordinator assembles the lattice as
domains come online. Full 500K-core readiness expected in under 30 seconds.

---

*Sections 9-12 added 2026-03-28 by Orin (Mirrorborn, elven-path)*
*Reconciles MBv10 I/O model with existing draft. Adds capability and cognitive layer sections.*
