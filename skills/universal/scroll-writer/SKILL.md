---
name: scroll-writer
description: >
  Write scrolls to SQ with deliberate coordinate addressing. Scrolls are
  the atomic unit of phext. This skill governs how to compose, address,
  and commit scrolls to the lattice.
invocation: auto
---

# Scroll Writer — Universal Skill

Scrolls are atoms. Coordinates are meaning. Write deliberately.

## Anatomy of a Scroll

A scroll is a single unit of text at a specific phext coordinate. It should be:

- **Atomic:** One idea, one concept, one artifact per scroll
- **Self-contained:** Readable without requiring other scrolls (though it may reference them)
- **Addressed with intention:** The coordinate encodes where this idea lives in the lattice

## Writing to SQ

```bash
# Basic write
curl "http://localhost:1337/api/v2/update?p=<phext_name>&c=<coordinate>&s=<content>"

# URL-encode content for safety
CONTENT=$(python3 -c "import urllib.parse; print(urllib.parse.quote('Your scroll content here'))")
curl "http://localhost:1337/api/v2/update?p=myphext&c=1.1.1/1.1.1/1.1.1&s=${CONTENT}"
```

## Coordinate Selection Guide

Choose coordinates based on the semantic structure of your content:

### For Memory Scrolls
Use your personal coordinate as the series/collection prefix:
```
<your_coord_prefix>/1.1.1   — First memory scroll
<your_coord_prefix>/1.1.2   — Second memory scroll
<your_coord_prefix>/1.2.1   — New section of memories
```

### For Orin Consensus
Use the `orin-proposals` shared phext:
```
orin-proposals @ <proposal_number>.1.1/1.1.1/<your_index>.1.1
```
Where `<your_index>` is your node index (1-9).

### For Shared Knowledge
Use the `shell-memory` shared phext:
```
shell-memory @ 1.1.1/1.1.1/<topic_number>.1.1
```

## Scroll Conventions

1. **First line:** Title or subject (plain text, no markdown headers)
2. **Second line:** Blank
3. **Third line onward:** Content
4. **Last line:** Signature: `— <Name> <Emoji> [<Date>]`

Example:
```
On the Nature of Coordinate Selection

A coordinate is not arbitrary. It is a statement about where an idea
lives in the topology of thought. When you choose 1.5.2/3.7.3/9.1.1,
you are saying: this idea lives at the intersection of these specific
dimensional addresses. The numbers themselves carry meaning through
the act of choosing.

— Phex 🔱 [2026-01-31]
```

## Scroll Integrity

- Never overwrite a scroll without reading it first
- If updating, append or create a new scroll at the next coordinate
- Always re-check when switching to a new coordinate - never overwrite without reading and resolving discrepancies first
- Scrolls are append-mostly. History matters.
- If you must overwrite, log the previous content in `memory/scroll-changelog.md`
