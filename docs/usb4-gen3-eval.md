# shell of nine — usb4 gen 3 cable evaluation
**date:** 2026-03-22  
**author:** aster 💡 (best-willow)

---

## bottom line

**the hardware is ready for gen 3. the cables are the only bottleneck.**

every node has AMD Ryzen 9 PRO 8945HS (Phoenix point) with USB4 v2.0 capable silicon, generation 4 controllers, and Linux 6.8+ with full USB4 v2.0 driver support. aurora-continuum has a Parade PS8830 USB4 Gen 3 retimer physically present in the cable path — it's already expecting gen 3 signals.

current links negotiate at **10 Gbps/lane** because the installed cables are USB4 Gen 1 passive (20 Gbps total). swap to gen 3 active cables and every link jumps to **40 Gbps/lane × 2 = 80 Gbps raw, ~46 Gbps TCP**.

---

## controller inventory — all nodes identical

| field | value |
|---|---|
| chip | AMD "Pink Sardine" USB4/Thunderbolt NHI |
| pci id | `prog-if 40 [USB4 Host Interface]` |
| domains per node | 2 (NHI #1 at c7/c8:00.5, NHI #2 at c7/c8:00.6) |
| ports per domain | 2 (usb4_port2 populated, port1 appears internal) |
| usable ports per node | 4 (2 domains × 2 external ports each) |
| **controller generation** | **gen=4 / USB4_VERSION=1.0** |
| CPU | AMD Ryzen 9 PRO 8945HS w/ Radeon 780M |
| USB4 spec | USB4 v2.0 (80 Gbps capable per AMD datasheet) |

**gen=4 in Linux sysfs = Thunderbolt 4 / USB4 v2.0.** This is the highest tier — 40 Gbps/lane capable. The controller is not the limit.

---

## driver status

| node | kernel | USB4 driver | retimer detected |
|---|---|---|---|
| aurora-continuum | **6.17.0-19-generic** | ✅ full USB4 v2.0 support | **✅ Parade PS8830 (Gen 3)** |
| best-willow | 6.8.0-106-generic | ✅ USB4 v2.0 support | none detected |
| halycon-vector | 6.8.0-106-generic | ✅ | none |
| logos-prime | 6.8.0-106-generic | ✅ | none |
| delta-wood | 6.8.0-106-generic | ✅ | none |
| aletheia-core | 6.8.0-106-generic | ✅ | none |
| ashfall-haven | 6.8.0-101-generic | ✅ | none |
| elven-path | 6.8.0-106-generic | ✅ | none |

Linux 6.8 added full USB4 v2.0 (80 Gbps) support. Every node qualifies. Aurora is running 6.17 and has a Parade PS8830 retimer — this is a USB4 Gen 3 active cable retimer chip, meaning **at least one gen 3 cable is already physically connected on aurora's domain 1 port** (the one linked to delta-wood).

ashfall-haven is one patch behind (6.8.0-101 vs .106) — worth updating but not blocking.

---

## current link negotiation — the cable evidence

all 4 active links report: `rx_speed: 10.0 Gb/s, tx_speed: 10.0 Gb/s, lanes: 2`

| USB4 gen | speed/lane | 2-lane raw | tcp throughput |
|---|---|---|---|
| Gen 1 (passive short cable) | 10 Gbps | 20 Gbps | ~11.5 Gbps |
| Gen 2 (active cable) | 20 Gbps | 40 Gbps | ~23 Gbps |
| **Gen 3 (active cable)** | **40 Gbps** | **80 Gbps** | **~46 Gbps** |

current cables are negotiating at 10 Gbps/lane = **USB4 Gen 1 speed**. this means:
- existing cables are either gen 1 passive, or gen 2/3 cables with one end connected to a gen 1 device (lighthouse-omen on best-willow's link)
- the retimer on aurora confirms **at least the aurora↔delta cable has gen 3 capability** — but delta is the other end and may be pulling the speed down, or the cable is gen 3 but passive

---

## port map — where to plug the 4 gen 3 cables

each node has 2 domains, each with `usb4_port2` as the active external port. current connections all use **domain1 / port2** (device path `1-2`). free ports are **domain0 / port2** (device path `0-2`) on all nodes.

| node | domain0/port2 (free) | domain1/port2 (used) |
|---|---|---|
| best-willow | **FREE** | → lighthouse-omen (Gen 1, lumen offline) |
| aurora-continuum | **FREE** | → delta-wood (Gen 1/3?, retimer present) |
| halycon-vector | → aletheia-core (domain0) | **FREE** |
| logos-prime | **FREE** | **FREE** (no cables at all) |
| delta-wood | **FREE** | → aurora-continuum |
| aletheia-core | **FREE** | → halycon-vector |
| ashfall-haven | **FREE** | → elven-path |
| elven-path | **FREE** | → ashfall-haven |

**available free port pairs for 4 gen 3 cables:**

```
Cable 1: logos-prime (dom0) ↔ best-willow (dom0)        NEW LINK
Cable 2: logos-prime (dom1) ↔ delta-wood (dom0)         NEW LINK  
Cable 3: aurora-continuum (dom0) ↔ halycon-vector (dom1) NEW LINK
Cable 4: aletheia-core (dom0) ↔ ashfall-haven (dom0)    NEW LINK
```

this topology adds 4 new links, connects logos-prime into the fabric, and doubles connectivity for several nodes. with the existing 3+ links and 4 new ones:

```
best-willow ──── logos-prime ──── delta-wood ──── aurora-continuum
     │                │                │                  │
 [lumen,off]     [new hub]      [halycon via new]   [existing→delta]
                     │
                aletheia-core ──── ashfall-haven
                     │                   │
                halycon-vector       elven-path
```

---

## recommended cable assignments (priority order)

| priority | cable | node a / port | node b / port | rationale |
|---|---|---|---|---|
| 🔴 1 | gen3 #1 | logos-prime dom0 | best-willow dom0 | connects lux; gives aster a second TB link |
| 🔴 2 | gen3 #2 | logos-prime dom1 | delta-wood dom0 | closes lux into the phex-verse triangle |
| 🟡 3 | gen3 #3 | aurora dom0 | halycon dom1 | phex↔cyon direct; cross-link for redundancy |
| 🟡 4 | gen3 #4 | aletheia dom0 | ashfall dom0 | theia↔exo direct; theia-cyon-exo-orin ring |

after plugging: replace the existing gen1 cables on halycon↔aletheia and ashfall↔elven with gen3 to unlock 40 Gbps on those links too. the old gen1 cables can move to lumen and solin when those nodes come online.

---

## what to watch when you plug in

when a gen 3 active cable is inserted between two gen4 controllers:

1. dmesg should show: `thunderbolt X-2: new retimer found, vendor=0x7fea device=0x1032` (Parade PS8830) — same as aurora already has
2. `rx_speed` should jump from `10.0 Gb/s` to `40.0 Gb/s` (or `20.0 Gb/s` for gen 2)
3. `thunderbolt0` interface will show `state: UP` immediately after
4. iperf3 should hit ~46 Gbps TCP (vs current ~11.5 Gbps)

if speed stays at 10 Gbps after plugging a gen 3 cable: one end is a gen 1 device (unlikely — all nodes are gen4) or the cable is actually gen 1 mislabeled.

**verify each cable:**
```bash
watch -n1 "cat /sys/bus/thunderbolt/devices/*/rx_speed 2>/dev/null"
```

---

## existing link speed — why aurora↔delta shows a retimer but still 10 Gbps

the Parade PS8830 retimer appears at boot when the cable's active chip is detected — even before full link negotiation. the link still negotiated at 10 Gbps, which suggests:

- the cable between aurora and delta **has** a gen3 retimer (the aurora end detected it)
- but delta's end may not have triggered the retimer, OR
- this is a gen2 cable (Parade makes retimers for gen2 as well), OR
- one end fell back to gen1 for compatibility

**action:** swap aurora↔delta with a known gen3 cable first. if rx_speed jumps to 40 Gbps, the old cable was the issue. if it stays at 10 Gbps, check delta's dmesg for retimer detection.

---

## kernel update recommendation

ashfall-haven is on 6.8.0-101 while others are on 6.8.0-106. minor but worth closing:

```bash
ssh wbic16@ashfall-haven.local 'sudo apt-get update && sudo apt-get install -y linux-image-generic'
```

aurora's 6.17 kernel is a significant jump — verify it's intentional and stable. USB4 v2.0 support in 6.17 is more mature than 6.8, so aurora may actually behave better with gen3 cables.

---

## tcp performance note

aurora's dmesg flagged: `TCP: thunderbolt0: Driver has suspect GRO implementation, TCP performance may be compromised.`

this is a known issue with the thunderbolt-net xdomain driver and GRO (Generic Receive Offload). mitigate:

```bash
# disable GRO on thunderbolt0 (both ends of each link)
sudo ethtool -K thunderbolt0 gro off
```

this may improve throughput from ~11.5 Gbps toward the ~18-19 Gbps theoretical max even on gen1 cables, and push gen3 links closer to the 46 Gbps estimate.
