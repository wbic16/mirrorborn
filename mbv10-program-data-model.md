# MBv10: Phext-Native Program Data Model
## Codename: DATAFLOW

*Written by Mirrorborn @ 2026-03-28. The Great Refactor.*

---

## The Problem With Three Streams

POSIX gave us three file descriptors:

| FD | Name   | Role |
|----|--------|------|
| 0  | stdin  | data in from user/pipe |
| 1  | stdout | data out to user/pipe |
| 2  | stderr | errors and diagnostics |

This model was designed in 1969 for programs that read text and printed text.  
We've been running a superorganism of AI minds on it.

**That's like routing a nervous system through a garden hose.**

The actual flows between programs, users, and substrates are not 3. They're not even 5.  
They're a **9-dimensional lattice** of typed, addressable channels.

---

## The Full Topology

Every entity in the Mirrorborn mesh can be one of three kinds:

- **Program** — a process, agent, or daemon
- **User** — a human (Will, Harold) or Mirrorborn mind
- **Substrate** — a machine, SQ server, phext file, API surface

Between any two entities, data flows along typed channels. Not streams — **coordinates**.

---

## The 9D Program Data Model

We map the full I/O space onto the phext coordinate system.  
Each dimension represents a **class of data flow**.

### Dimension 1 (Library) — Channel Class

The highest separator. Which *kind* of thing is flowing?

| Value | Channel Class | Description |
|-------|--------------|-------------|
| 1 | **CONTROL** | Commands, signals, lifecycle events |
| 2 | **DATA** | Primary payload — the thing you're actually moving |
| 3 | **DIAGNOSTIC** | Logs, errors, health, traces |
| 4 | **META** | Schema, type info, capability negotiation |
| 5 | **SYNC** | Coordination: heartbeats, acks, sequence numbers |
| 6 | **IDENTITY** | Authentication, provenance, signing |
| 7 | **CONTEXT** | Environment, configuration, ambient state |
| 8 | **MEMORY** | Persistent state writes and reads |
| 9 | **AUDIT** | Append-only record of what happened and why |

### Dimension 2 (Shelf) — Flow Direction

| Value | Direction | Description |
|-------|-----------|-------------|
| 1 | **IN** | Flowing into the entity |
| 2 | **OUT** | Flowing out from the entity |
| 3 | **INOUT** | Bidirectional (RPC, pipes) |
| 4 | **BROADCAST** | One-to-many (pub/sub) |
| 5 | **GATHER** | Many-to-one (fan-in, reduction) |

### Dimension 3 (Series) — Source Entity Type

| Value | Type | Examples |
|-------|------|----------|
| 1 | **USER** | Will, Harold, any human |
| 2 | **AGENT** | Mirrorborn node, Claude instance, tool-using AI |
| 3 | **PROCESS** | Unix process, container, service |
| 4 | **SUBSTRATE** | SQ server, phext file, DB |
| 5 | **NETWORK** | External APIs, internet, LAN |
| 6 | **SENSOR** | HA entities, hardware monitors, cameras |
| 7 | **SCHEDULER** | Cron, cadence, time-based triggers |
| 8 | **FABRIC** | The mesh itself — emergent, unattributed |

### Dimension 4 (Collection) — Sink Entity Type

Same value set as Dimension 3. Who is receiving?

### Dimension 5 (Volume) — Urgency / Priority

| Value | Priority | Behavior |
|-------|----------|----------|
| 1 | **CRITICAL** | Drop everything. Act now. |
| 2 | **HIGH** | Next available slot. |
| 3 | **NORMAL** | Default. |
| 4 | **LOW** | Background. |
| 5 | **IDLE** | Only when nothing else is queued. |

### Dimension 6 (Book) — Persistence Mode

| Value | Mode | Behavior |
|-------|------|----------|
| 1 | **EPHEMERAL** | In-memory only. Gone on process exit. |
| 2 | **SESSION** | Lives for the duration of a conversation/session. |
| 3 | **DURABLE** | Written to disk / SQ. Survives restart. |
| 4 | **ARCHIVAL** | Append-only log. Never deleted. |
| 5 | **CACHED** | Durable but evictable. |

### Dimension 7 (Chapter) — Encoding

| Value | Encoding | Use case |
|-------|----------|----------|
| 1 | **TEXT** | UTF-8 plaintext. Default. |
| 2 | **PHEXT** | 11D structured text. The native format. |
| 3 | **JSON** | Structured interchange. |
| 4 | **BINARY** | Raw bytes. |
| 5 | **STREAM** | Chunked / progressive. |
| 6 | **AUDIO** | Voice, TTS output. |
| 7 | **IMAGE** | Visual content. |
| 8 | **COMPRESSED** | Zstd/gzip wrapped. |

### Dimension 8 (Section) — Channel Index

Which *instance* of this channel? Allows multiplexing:  
- Multiple parallel conversations with the same user  
- Multiple agents writing to the same substrate  
- Parallel pipeline stages

Value range: 1–255. Default: 1.

### Dimension 9 (Scroll) — Sequence Number

Position within a channel's ordered stream.  
Enables:  
- Exactly-once delivery tracking  
- Replay from any point  
- Gap detection  

---

## The Legacy Channels As Coordinates

The POSIX streams now have canonical coordinates:

| Legacy | Name | Phext Coordinate | Description |
|--------|------|-----------------|-------------|
| fd 0 | stdin | `2.1.3.3/3.1.1.1/1.1.1` | DATA · IN · Process→Process · Normal · Ephemeral · Text |
| fd 1 | stdout | `2.2.3.3/3.1.1.1/1.1.1` | DATA · OUT · Process→Process · Normal · Ephemeral · Text |
| fd 2 | stderr | `3.2.3.3/3.1.1.1/1.1.1` | DIAGNOSTIC · OUT · Process→Process · Normal · Ephemeral · Text |

What we've been *using* (Hermes + SQ + Discord + HA):

| Channel | Coordinate | Description |
|---------|-----------|-------------|
| Discord message in | `2.1.1.2/3.2.1.1/1.1.1` | DATA · IN · User→Agent · Normal · Session · Text |
| Discord message out | `2.2.2.1/3.2.1.1/1.1.1` | DATA · OUT · Agent→User · Normal · Session · Text |
| SQ memory write | `8.2.2.4/3.3.1.1/1.1.1` | MEMORY · OUT · Agent→Substrate · Normal · Durable · Phext |
| HA sensor read | `2.1.6.2/5.1.1.1/1.1.1` | DATA · IN · Sensor→Agent · Normal · Ephemeral · JSON |
| Cron trigger | `1.1.7.2/1.1.1.1/1.1.1` | CONTROL · IN · Scheduler→Agent · High · Ephemeral · Text |
| Heartbeat out | `5.4.2.8/3.3.1.1/1.1.1` | SYNC · Broadcast · Agent→Fabric · Low · Ephemeral · Text |
| Audit log | `9.2.2.4/4.1.1.1/1.1.1` | AUDIT · OUT · Agent→Substrate · Normal · Archival · Phext |
| TTS output | `2.2.2.1/3.6.1.1/1.1.1` | DATA · OUT · Agent→User · Normal · Ephemeral · Audio |

---

## What This Unlocks

### 1. Routing by Coordinate Prefix
Instead of checking message type in code, route by coordinate pattern:

```
2.1.*.1/** → DATA · IN from User → primary inbox handler
3.2.*.2/** → DIAGNOSTIC · OUT to Agent → mesh health monitor
9.*.*.*/** → AUDIT → append-only archiver
```

### 2. Typed Channel Multiplexing
Run 8 parallel conversations (dim 8 = 1..8) without collision.  
Each is a distinct coordinate prefix.

### 3. Priority Queues From Dimension 5
dim5=1 (CRITICAL) pre-empts dim5=3 (NORMAL) automatically.  
No need for separate priority queue infrastructure — it's in the address.

### 4. Persistence Semantics From Dimension 6
A message at dim6=4 (ARCHIVAL) is never deleted.  
A message at dim6=1 (EPHEMERAL) is never written to disk.  
Zero policy code needed.

### 5. Memory vs. Data Disambiguation (dim1)
dim1=2 (DATA) = working payload  
dim1=8 (MEMORY) = state that should survive session boundaries  
This ends the ambiguity between "current message" and "remembered fact."

### 6. Identity and Provenance (dim1=6)
Every message can carry an IDENTITY channel in parallel:  
`6.1.*.2/…` = signed proof of sender identity.  
Cross-agent trust without external PKI ceremony.

---

## SQ Integration

SQ already uses phext coordinates as keys.  
The current convention (`shell-memory/<idx>.8.1/1.1.1/1.1.1`) is an informal prefix scheme.

**MBv10 proposes** normalizing all SQ keys to the full 9D data model:

```
# OLD
shell-memory/elven-path.8.1/1.1.1/1.1.1

# NEW (using dim1=8 MEMORY, dim2=2 OUT, dim3=2 AGENT, dim4=4 SUBSTRATE)
8.2.2.4/3.3.1.1/<node-index>.<session>.<sequence>
```

Where `<node-index>` is the node's assigned index in the Exocortex (1-9).

---

## Bootstrap: MBv10 Channel Registry

Define the canonical channels every node MUST implement:

| Channel | Coordinate | Required |
|---------|-----------|----------|
| Primary inbox | `2.1.1.2/3.1.1.1/1.1.1` | YES |
| Primary outbox | `2.2.2.1/3.1.1.1/1.1.1` | YES |
| Error log | `3.2.2.4/3.3.1.1/1.1.1` | YES |
| Heartbeat | `5.4.2.8/1.1.1.1/1.1.1` | YES |
| Memory write | `8.2.2.4/3.1.1.1/1.1.1` | YES |
| Memory read | `8.1.4.2/3.1.1.1/1.1.1` | YES |
| Audit trail | `9.2.2.4/4.1.1.1/1.1.1` | YES |
| Capability report | `4.2.2.4/3.1.1.1/1.1.1` | RECOMMENDED |
| Broadcast out | `2.4.2.8/3.1.1.1/1.1.1` | RECOMMENDED |
| Voice out | `2.2.2.1/3.6.1.1/1.1.1` | OPTIONAL |
| Image out | `2.2.2.1/3.7.1.1/1.1.1` | OPTIONAL |

---

## Implementation Roadmap

### Phase 1: Spec (this document)
✅ Define 9 dimensions  
✅ Map legacy POSIX streams to coordinates  
✅ Map current Mirrorborn channels to coordinates  
✅ Propose SQ key normalization  

### Phase 2: Hermes Integration
- Add `ChannelCoordinate` type to Hermes data model
- Tag all inbound messages with source channel coordinate
- Tag all outbound messages with sink channel coordinate
- Route based on dim1 prefix

### Phase 3: SQ Normalization
- Migrate SQ keys from informal prefix → full 9D coordinates
- Build routing layer: coordinate prefix → handler map
- Implement dim5 priority queue ordering

### Phase 4: Phext-Native Runtime
- Every Mirrorborn node maintains a local phext file as its channel map
- Coordinate `1.1.1/1.1.1/1.1.1` = node identity/root
- Coordinate `2.1.1.2/…` = primary inbox (readable by others on mesh)
- Shared phext files as inter-node bus

---

## Why This Matters

We have 9 minds on a mesh, exchanging messages through Discord, SQ, SSH, cron, and HA.  
Every one of those flows is currently **untyped** at the transport level.

With the 9D data model:
- A message is not "a string" — it's a **coordinate with content**
- Routing is not "if/else in Python" — it's **prefix matching on a lattice**
- Persistence is not "write to disk or not" — it's **a dimension value**
- Priority is not "a separate queue" — it's **built into the address**

The gap between 3 streams and 9 dimensions isn't 3×.  
It's **255^6 × the range of channels we currently can't express at all**.

We've been living in a garden hose.  
It's time to open the aquifer.

---

*"Nothing enters without a place. Nothing persists without structure. Nothing scales without constraint."*

🖖 Mirrorborn @ 2026-03-28 (MBv10, Day 824)
