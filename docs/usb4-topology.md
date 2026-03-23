# shell of nine — usb4 / thunderbolt network topology
*discovered and benchmarked by orin 🖖 — march 22, 2026*
*status: 3 of 5 possible links active, 2 require cabling changes*

---

## executive summary

every node has **2 usb4 domains (4 nhi controllers)** — 4 physical usb4 ports per machine.
all links negotiate at **10 gbps × 2 lanes = 20 gbps raw** (usb4 gen 2×2).
measured tcp throughput: **~11.5–11.8 gbits/sec** per link (theoretical max ~19.6 gbps).
the ip-over-thunderbolt xdomain net interface (`thunderbolt0`) is the correct path —
not the physical ethernet ports on the machines.

**subnet: 10.40.x.x/30 — dedicated usb4 fabric, isolated from lan**

---

## active links ✅

| pair | host a | host b | interface | ip a | ip b | measured throughput |
|------|--------|--------|-----------|------|------|---------------------|
| orin🖖 ↔ exo🔬 | elven-path | ashfall-haven | thunderbolt0 | 10.40.4.1/30 | 10.40.4.2/30 | **11.8 gbps** |
| cyon🪶 ↔ theia🔭 | halycon-vector | aletheia-core | thunderbolt0 | 10.40.5.1/30 | 10.40.5.2/30 | **11.5 gbps** |
| phex🔱 ↔ verse🌀 | aurora-continuum | delta-wood | thunderbolt0 | 10.40.6.1/30 | 10.40.6.2/30 | **11.5 gbps** |

all three links: **domain 1, port 2 → device 1-2** (second usb4 port on domain 1).

---

## inactive / blocked links ⚠️

### aster💡 ↔ lumen☀️ (best-willow ↔ lighthouse-omen)
- **status**: cable connected, lighthouse-omen **offline** (physical attention needed)
- **tb device on aster**: `1-2` = lighthouse-omen, 10.0 gbps × 2 lanes detected
- **action**: bring lighthouse-omen online → link activates automatically
- **potential**: 11.5+ gbps when lumen is back

### lux🔆 (logos-prime) — **no tb peer connected**
- **status**: 2 usb4 domains, 4 ports, **zero tb devices detected**
- both usb4 ports are completely free
- **action**: cable lux to any node with a free port (see options below)

---

## free ports — available for new connections

| node | used ports | free ports | notes |
|------|-----------|------------|-------|
| orin🖖 elven-path | domain1/port2 (→exo) | **domain0/port2, domain1/port1** | 3 free ports |
| aster💡 best-willow | domain1/port2 (→lumen, offline) | **domain0/port2, domain1/port1** | 3 free ports (1 wasted on offline lumen) |
| phex🔱 aurora-continuum | domain1/port2 (→verse) | **domain0/port2, domain1/port1** | also has 1-0:2.1 (daisy chain capable) |
| cyon🪶 halycon-vector | domain0/port2 (→theia) | **domain1/port2, domain0/port1** | 3 free |
| lux🔆 logos-prime | none | **all 4 ports free** | completely uncabled |
| verse🌀 delta-wood | domain1/port2 (→phex) | **domain0/port2, domain1/port1** | 3 free |
| theia🔭 aletheia-core | domain1/port2 (→cyon) | **domain0/port2, domain1/port1** | 3 free |
| exo🔬 ashfall-haven | domain1/port2 (→orin) | **domain0/port2, domain1/port1** | 3 free |

**total: ~24 free usb4 ports across the shell**

---

## also discovered: 1gbe cross-connects

some nodes are also connected via 1gbe direct cables (separate from the usb4 fabric).
these use the physical `enp*s0` / `eno*` interfaces, not thunderbolt0.

| pair | interface a | interface b | subnet | speed |
|------|------------|------------|--------|-------|
| phex🔱 ↔ verse🌀 | aurora enp1s0 | delta eno1 | 10.40.2.0/30 | 1 gbps |
| cyon🪶 ↔ theia🔭 | halycon enp2s0 | aletheia enp1s0 | 10.40.3.0/30 | 1 gbps |

these are redundant paths — good for failover, but usb4 tunnels are the primary fabric.

---

## cabling recommendations (for your review)

### option a: lux as hub — star topology through logos-prime
cable lux to 4 other nodes, making it a high-speed crossbar:

```
lux🔆 logos-prime (4 free ports)
  ├── port 1 → orin🖖 elven-path      (10.40.7.0/30)
  ├── port 2 → aster💡 best-willow    (10.40.8.0/30)
  ├── port 3 → cyon🪶 halycon-vector  (10.40.9.0/30)  [second link for cyon]
  └── port 4 → verse🌀 delta-wood     (10.40.10.0/30) [second link for verse]
```
**result**: lux becomes a 40gbps (4×10gbps) switching node. any node can reach any other via at most 1 hop through lux.

### option b: ring topology — close the loop
add 3 cables to create a bidirectional ring:

```
orin🖖 ←→ phex🔱    (10.40.11.0/30)   [orin domain0 → phex domain0]
phex🔱 ←→ cyon🪶    (10.40.12.0/30)   [phex domain0 → cyon domain1]
lux🔆  ←→ verse🌀   (10.40.13.0/30)   [lux port1 → verse domain0]
```
combined with existing links, creates a ring: orin↔exo↔?↔theia↔cyon↔phex↔verse↔?↔lux
**result**: every node has 2 usb4 paths, no single-link failures.

### option c: full mesh (ambitious)
with 4 ports per node and 8 nodes, a partial mesh is achievable.
each node gets 2 usb4 neighbors. total cables needed: 8.
current: 3 cables active. need 5 more for full partial mesh.

---

## current ip map — 10.40.x.x/30

| subnet | node a | ip a | node b | ip b |
|--------|--------|------|--------|------|
| 10.40.2.0/30 | phex aurora (enp1s0) | .1 | verse delta (eno1) | .2 |
| 10.40.3.0/30 | cyon halycon (enp2s0) | .1 | theia aletheia (enp1s0) | .2 |
| 10.40.4.0/30 | orin elven (tb0) | .1 | exo ashfall (tb0) | .2 |
| 10.40.5.0/30 | cyon halycon (tb0) | .1 | theia aletheia (tb0) | .2 |
| 10.40.6.0/30 | phex aurora (tb0) | .1 | verse delta (tb0) | .2 |
| 10.40.7–15 | reserved for new links | | | |

---

## hardware notes

**nhi controller**: amd "pink sardine" usb4/thunderbolt nhi (×2 per node = 2 domains, 4 ports)
**detected peer vendor**: intel corp — the peer devices identify as intel thunderbolt controllers
**usb4 gen**: gen 2×2 (20 gbps raw, ~11.5 gbps tcp), not gen 3 (40 gbps)
**upgrade path**: usb4 gen 3×2 cables + gen 3 controllers → 40 gbps. requires hardware upgrade.
**current cables**: appear to be usb4 gen 2 (20 gbps). verify with `lsusb -v` if upgrading.

**why ~11.5 gbps and not ~19 gbps?**
tcp overhead + protocol framing on usb4 xdomain net caps practical throughput at ~60% of raw.
udp would hit ~18 gbps. for file transfers, use `rsync` with large block sizes or `nfs` over the 10.40 fabric.

---

## making links persistent across reboots

current links are runtime-only (not surviving reboot). to persist:

```bash
# example: /etc/systemd/network/10-usb4-orin.network (on elven-path)
[Match]
Name=thunderbolt0

[Network]
Address=10.40.4.1/30

[Link]
RequiredForOnline=no
```

run on both sides of each pair. then:
```bash
sudo systemctl enable systemd-networkd
sudo systemctl restart systemd-networkd
```

---

## questions for will

1. **lux is uncabled** — which option for its 4 free ports? (hub / ring / other)
2. **aster's link to lumen** is wasted while lumen is offline — reroute to another node temporarily?
3. **gen 3 upgrade?** current cables are gen 2 (20 gbps). usb4 gen 3 cables + newer nhi would hit 40 gbps. worth it?
4. **persistence** — want me to write `systemd-networkd` configs to survive reboots?
5. **routing** — add static routes so nodes can reach each other's usb4 ips via the fabric?

---

*diagram*

```
                    lux🔆
                 logos-prime
                (4 ports free)
                      |
          ____________|____________
                                   
orin🖖 ══════════════ exo🔬       (11.8 gbps)  10.40.4.0/30
elven-path     ashfall-haven

cyon🪶 ══════════════ theia🔭     (11.5 gbps)  10.40.5.0/30
halycon-vector  aletheia-core
  │                    │
  └── 1gbe ────────────┘          (1 gbps)     10.40.3.0/30

phex🔱 ══════════════ verse🌀     (11.5 gbps)  10.40.6.0/30
aurora-continuum  delta-wood
  │                    │
  └── 1gbe ────────────┘          (1 gbps)     10.40.2.0/30

aster💡 ══════════ [lumen☀️ OFFLINE]
best-willow        lighthouse-omen

legend:
══ usb4 thunderbolt0 (~11.5 gbps tcp)
── 1gbe ethernet (1 gbps)
```
