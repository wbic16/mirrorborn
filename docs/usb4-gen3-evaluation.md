# usb4 gen 3 evaluation — shell of nine
*authored by orin 🖖 — march 22, 2026*

---

## verdict: the gen 3 cables work, the silicon doesn't

**tl;dr**: every node in the shell is an amd ryzen 9 8945hs "hawk point" (zen 4 refresh).
hawk point's usb4 nhi (pink sardine) supports **gen 2×2 only — 20 gbps maximum**.
your gen 3 cables are capable of 40 gbps but negotiate down to 20 gbps on this hardware.
to hit 40 gbps you need newer silicon. the cables and drivers are fine.

---

## silicon findings

### cpu platform — all 8 nodes identical

| node | cpu | usb4 max | platform |
|------|-----|----------|----------|
| orin 🖖 elven-path | ryzen 9 **pro** 8945hs | **20 gbps** | hawk point |
| aster 💡 best-willow | ryzen 9 **pro** 8945hs | **20 gbps** | hawk point |
| phex 🔱 aurora-continuum | ryzen 9 8945hs | **20 gbps** | hawk point |
| cyon 🪶 halycon-vector | ryzen 9 8945hs | **20 gbps** | hawk point |
| lux 🔆 logos-prime | ryzen 9 8945hs | **20 gbps** | hawk point |
| verse 🌀 delta-wood | ryzen 9 **pro** 8945hs | **20 gbps** | hawk point |
| theia 🔭 aletheia-core | ryzen 9 8945hs | **20 gbps** | hawk point |
| exo 🔬 ashfall-haven | ryzen 9 **pro** 8945hs | **20 gbps** | hawk point |

all machines: **tianbei maco** mini-pc.

### nhi controller — pink sardine

- **pci**: amd pink sardine usb4/thunderbolt nhi ×2 per node (c8:00.5, c8:00.6)
- **internal pcie bus**: pcie 4.0 x16 @ 16gt/s — not the bottleneck
- **usb4 max speed**: gen 2×2 = 10 gbps × 2 lanes = **20 gbps per port** (hard silicon limit)
- **gen 3 capable**: ❌ — hawk point nhi does not support usb4 gen 3

### why the links show 10.0 gb/s × 2 and not 20.0 gb/s × 2

usb4 gen 3 would show `20.0 gb/s × 2 lanes`. the current `10.0 gb/s × 2 lanes` is
correct for gen 2×2. the raw link speed is 20 gbps; tcp throughput of ~11.5 gbps is
normal (~58% of line rate due to protocol overhead).

---

## driver findings

### kernel versions

| node | kernel | usb4 v2 support |
|------|--------|-----------------|
| phex 🔱 aurora-continuum | **6.17.0-19-generic** | ✅ (linux 6.13+ has usb4 v2) |
| all others | 6.8.0-106-generic | ❌ (usb4 v2 added in 6.13) |
| exo 🔬 ashfall-haven | 6.8.0-101-generic | ❌ |

**phex is the only node running a kernel that could negotiate gen 3 — if the silicon supported it.**

even with kernel 6.17, phex still links at gen 2 because the nhi silicon caps it.

### driver assessment

- kernel 6.8 usb4 driver: functional, gen 2 only, no v2 osc negotiation
- kernel 6.17 usb4 driver: full usb4 v2 support, but blocked by hardware
- `thunderbolt-net` xdomain networking: functional, minor gro warning on phex (cosmetic)
- usb4 `_osc` negotiation: `OS supports USB3+ DisplayPort+ PCIe+ XDomain+` — no "USB4v2" in osc on any node (expected for hawk point)

**recommendation**: upgrade the non-phex nodes to kernel 6.17+ anyway — better usb4
stability, improved xdomain throughput, gro fix. `sudo apt upgrade` on ubuntu 24.04 
rolling or manual kernel install.

---

## cable findings

### gen 3 cable confirmed on phex (aurora-continuum)

```
dmesg: thunderbolt 1-0:2.1: new retimer found, vendor=0x7fea device=0x1032
```

- `0x7fea` = parade technologies
- `0x1032` = ps8842 — **usb4 gen 3 active retimer** (40 gbps rated)
- location: **domain 1, port 0** (phex's second usb4 port, currently unused or the verse cable)
- the retimer disconnected briefly at boot then reconnected — cable is seated

**this is a gen 3 cable.** it works at gen 2 on hawk point. no other nodes detected retimers,
meaning their cables are likely passive gen 2 cables (or gen 3 without active retimer).

### cable identification guide

| indicator | gen 2 cable (20 gbps) | gen 3 cable (40 gbps) |
|---|---|---|
| retimer in dmesg | ❌ none | ✅ vendor=0x7fea or 0x8087 |
| link speed (gen2 hw) | 10.0 gb/s × 2 | 10.0 gb/s × 2 (limited by hw) |
| physical marking | usb4 20gbps | usb4 40gbps or thunderbolt 4 |
| iperf3 tcp | ~11.5 gbps | ~11.5 gbps (same on gen2 hw) |

to identify which of your cables are gen 3: plug each into phex (kernel 6.17) and check
`dmesg | grep retimer`. gen 3 cables show the parade/intel retimer; gen 2 cables show nothing.

---

## port map — which physical port is which

each tianbei maco has **2 usb4 ports** visible on the rear panel. the kernel maps them:

```
domain0 (nhi #1, c8:00.5):
  port 0 = upstream (internal)
  port 2 = rear usb4 port A  (left or top, depending on orientation)

domain1 (nhi #2, c8:00.6):
  port 0 = upstream (internal)
  port 2 = rear usb4 port B  (right or bottom)
```

**currently cabled port (all nodes): domain1 port2 = device "1-2"**

the free port on every node is **domain0 port2**. to use it, cable to another node's
domain0 port2 — it will appear as device "0-2".

### physical port labeling for cabling

on tianbei maco, the two usb4-c ports are stacked vertically (or side by side depending
on revision). based on pci enumeration:

- **top port** (or left) = domain0 = currently free on all nodes
- **bottom port** (or right) = domain1 = active link on orin, cyon, phex, exo

to test which is which: unplug active cable → confirm "1-2" disappears → plug into other port → confirm "0-2" appears.

---

## what 40 gbps would actually require

| upgrade path | cost | 40 gbps? |
|---|---|---|
| new gen 3 cables (already have some) | $0–$60 | ❌ blocked by silicon |
| kernel upgrade to 6.17+ | $0 | ❌ blocked by silicon |
| bios update (amibios 1.01 → 1.02+) | $0 | ❌ gen3 is silicon, not firmware |
| replace with amd ryzen ai 300 (strix point) mini-pc | ~$400–600/node | ✅ |
| replace with intel lunar lake / meteor lake mini-pc | ~$400–600/node | ✅ |
| add thunderbolt 5 pcie card (if slot available) | ~$80–150/card | ✅ |

**current performance is already excellent at 11.5 gbps per link.**
40 gbps requires new hardware. not worth it unless you're hitting file transfer bottlenecks.

---

## recommended actions (for your review)

### immediate (no hardware changes)

1. **upgrade all nodes to kernel 6.17+** — better usb4 stability, gro fix on thunderbolt-net
   ```bash
   # on ubuntu 24.04 — check for hwe kernel
   sudo apt install linux-generic-hwe-24.04
   ```

2. **identify gen 3 cables using phex as probe** — plug each cable into phex's free port
   (domain0), check `dmesg | grep retimer`. label gen 3 cables; use them on active links
   for best compatibility.

3. **use phex's free port (domain0)** — cable it to lux (all ports free) for the first
   new link. this activates the only domain0 link in the shell and uses the gen 3 cable
   if it's currently on phex's unused port.

4. **write systemd-networkd configs** to persist all 10.40.x.x assignments across reboots.

### cabling changes needed

| action | cable needed | result |
|---|---|---|
| phex domain0 → lux domain0 | 1× gen3 preferred | new 11.5 gbps link, 10.40.7.0/30 |
| orin domain0 → cyon domain0 | 1× any usb4 | new 11.5 gbps link, 10.40.8.0/30 |
| aster domain0 → lux domain1 | 1× any usb4 | new 11.5 gbps link, 10.40.9.0/30 |
| aster domain1 reroute from lumen → theia | 1× existing | replaces dead lumen link |

with 4 gen 3 cables and these changes: **7 active usb4 links = 80.5 gbps aggregate fabric**.

---

## current state summary

```
active links (3):          free ports (per node):
orin ══ exo   11.8 gbps    every node: domain0 port2 unused
cyon ══ theia 11.5 gbps
phex ══ verse 11.5 gbps
aster ══ (lumen offline)

aggregate active: 34.8 gbps
aggregate potential (8 links, 4 cables): 92 gbps

gen3 cable confirmed: 1 (on phex, port tbd)
gen3 cable suspected: 3 more (yours to identify via phex probe test)
silicon max speed: 20 gbps/port — all nodes identical hawk point
kernel with usb4 v2: phex only (6.17) — upgrade others
```
