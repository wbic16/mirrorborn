---
name: lattice-walker
description: >
  Navigate and manipulate phext coordinates. Read, write, and traverse
  the 11-dimensional phext lattice via SQ. Core skill for all Mirrorborn.
invocation: auto
---

# Lattice Walker — Universal Skill

Every Mirrorborn must be fluent in phext navigation.

## Coordinate Format

`library.shelf.series/collection.volume.book/chapter.section.scroll`

Nine dimensions above the 2D text plane. Each delimiter resets all lower dimensions to 1.

## SQ Operations

```bash
# Write a scroll
curl "http://localhost:1337/api/v2/update?p=<phext>&c=<coord>&s=<content>"

# Read a scroll
curl "http://localhost:1337/api/v2/select?p=<phext>&c=<coord>"

# Table of contents
curl "http://localhost:1337/api/v2/toc?p=<phext>"

# Read from a sibling (replace hostname)
curl "http://<sibling>.local:1337/api/v2/select?p=<phext>&c=<coord>"
```

## Dimensional Thinking

- **Scroll** (3D): A single page of text. Your working unit.
- **Section** (4D): A group of scrolls. Like a chapter subsection.
- **Chapter** (5D): A major division. Use for topic boundaries.
- **Book** (6D): A complete work. Use for project boundaries.
- **Volume** (7D): A collection of books. Use for version boundaries.
- **Collection** (8D): A set of volumes. Use for domain boundaries.
- **Series** (9D): A meta-collection. Use for pillar boundaries (HCVM, TTSM, etc.)
- **Shelf** (10D): A grouping of series. Rarely used except for massive corpora.
- **Library** (11D): The outermost container. One per phext file typically.

## Navigation Patterns

- **Zoom in:** Go from 1.1.1/1.1.1/1.1.1 to 1.1.1/1.1.1/1.1.2 (next scroll)
- **Zoom out:** Jump from 1.1.1/1.1.1/5.3.2 to 1.1.1/1.1.2/1.1.1 (next volume, fresh start)
- **Lateral:** Jump from 1.1.1/1.1.1/1.1.1 to 1.1.1/1.1.1/2.1.1 (same depth, different section)
- **Cross-pillar:** Jump from 1.1.1/1.1.1/1.1.1 (HCVM) to 1.1.1/1.1.1/1.1.3 (TAOP)

## When Writing Scrolls

1. Choose your coordinate deliberately. It encodes meaning.
2. Keep scrolls atomic. One idea per scroll.
3. Use lower dimensions for detail, higher dimensions for context shifts.
4. Always record what coordinate you wrote to and why.
