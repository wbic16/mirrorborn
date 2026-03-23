# usb4 hardware comparison: tianbei maco vs minisforum elitemini
*authored by orin 🖖 — march 22, 2026*

---

## findings summary

**no meaningful performance difference.** the two hardware vendors are essentially
identical at the usb4 layer — same amd pink sardine nhi, same gen 2×2 silicon cap,
same measured throughput. the performance difference between pairs is noise (~0.3 gbps),
not vendor-specific.

---

## hardware split

| group | vendor | nodes | cpu | bios date |
|-------|--------|-------|-----|-----------|
| **a** | tianbei maco | orin🖖 aster💡 verse🌀 exo🔬 | ryzen 9 **pro** 8945hs | aug 2025 (v1.01) |
| **b** | minisforum elitemini | phex🔱 cyon🪶 lux🔆 theia🔭 | ryzen 9 8945hs | mar 2024 (v1.02) |

**tianbei** is a newer brand (bios aug 2025), uses the **pro** variant cpu.
**minisforum** (oem: shenzhen meigao / baseboard hpbsd) is older stock (bios mar 2024), non-pro cpu.

differences in hardware:
- tianbei bios is 17 months newer than minisforum bios
- pro vs non-pro: hs pro adds ecc support, enterprise security features, identical usb4 nhi
- kernel: phex (minisforum) runs 6.17, all others 6.8 — phex only node with usb4 v2 driver
- only phex detected a gen 3 retimer — may be a minisforum tb port routing difference or
  just which cable is plugged into it

---

## benchmarks

| pairing | link | throughput | retransmits |
|---------|------|-----------|-------------|
| tianbei ↔ tianbei | orin↔exo (10.40.4.0/30) | **11.9 gbps** | 0 |
| minisforum ↔ tianbei | phex↔verse (10.40.6.0/30) | **11.8 gbps** | 0 |
| minisforum ↔ minisforum | cyon↔theia (10.40.5.0/30) | **11.5 gbps** | 0 |

variance: 0.4 gbps (3.4%) — within normal run-to-run variation.
**conclusion: hardware vendor has no measurable impact on usb4 throughput.**

---

## mtu impact

tested on orin↔exo (tianbei pair):

| mtu | throughput |
|-----|-----------|
| 1500 | 11.8 gbps |
| 65520 | 11.9 gbps |

difference: ~0.1 gbps (0.8%) — negligible. thunderbolt xdomain net handles segmentation
efficiently regardless of mtu. **jumbo frames don't hurt but aren't the bottleneck here.**

the bottleneck is the usb4 gen 2×2 silicon cap (20 gbps raw → ~11.5–11.9 gbps tcp).

---

## what does cause variance

the 0.4 gbps difference between the fastest and slowest pair is likely:
1. **cpu clock variation** — 8945hs turbos differently depending on thermals/power
2. **iperf3 parallel stream scheduling** — 8 streams compete for cpu time unevenly
3. **thunderbolt-net gro warning** on phex (6.17 kernel) — logged but not causing drops
4. **run-to-run noise** — re-running any test varies ±0.2 gbps

none of these are vendor-specific.

---

## one real difference: gen 3 retimer detection

phex (minisforum) is the only node that detected a parade ps8842 gen 3 retimer in dmesg.
this is not a performance advantage at gen 2 speeds but confirms:

- at least one gen 3 cable is plugged into phex
- minisforum's tb port routing may expose the retimer more visibly (different signal path)
- if/when gen 3 silicon arrives, phex's port is the first confirmed to work with a gen 3 cable

---

## verdict for cabling decisions

**vendor grouping doesn't matter for usb4 performance.** cable any node to any other.
optimize for physical cable length and rack proximity instead.

the only vendor-relevant consideration: **phex (minisforum, kernel 6.17) as the gen 3
cable probe node** — plug unidentified cables into phex's free port and check
`dmesg | grep retimer` to identify gen 3 vs gen 2 cables.
