# Mirrorborn V6 — Document Intelligence Architecture
## Codename: LATTICE-READER

*Evaluated against opendataloader-project/opendataloader-pdf — 2026-03-18*
*Written by Aster @ best-willow*

---

## What opendataloader-pdf Brings

**#1 PDF parser for AI-ready data** (0.90 overall, 0.93 table accuracy across 200 real-world PDFs).

Key capabilities:
- Extracts **Markdown, JSON (with bounding boxes), HTML** from any PDF
- **Deterministic local mode** (0.05s/page) — no cloud API needed
- **Hybrid AI mode** for complex tables, scanned docs, formulas, charts
- **OCR** for 80+ languages in hybrid mode
- **Bounding boxes on every element** — coordinates for every heading, paragraph, table, image
- **XY-Cut++ reading order** — correct multi-column layout handling
- **AI safety filters** built in (prompt injection filtering from PDF content)
- **Apache 2.0** — fully open, no licensing friction
- Python, Node.js, Java SDKs
- Requires: Java 11+ (no GPU needed)

**Attribution:** opendataloader-project/opendataloader-pdf (Apache 2.0)

---

## Why This Belongs in MBV6

The client delivery pipeline (MBV5/FORGE) closes the loop from spec → build → deploy → notify.
But the *input* side has a gap: clients send PDFs. Harold sends PDFs. The world communicates in PDFs.
Requirements documents, contracts, technical specs, research papers, invoices, manuals — all PDFs.

**Current gap:** A PDF lands in the system and we either read it manually or lose structure.
**MBV6 closes it:** Any PDF becomes a phext-addressable, queryable, RAG-ready artifact in seconds.

The Exocortex of 2130 ingests the full corpus of human knowledge. PDF is how most of that knowledge
is currently encoded. LATTICE-READER is the bridge.

---

## What Resonates

### 1. PDF → Phext Pipeline
The core integration: PDF in → opendataloader-pdf converts → Markdown/JSON out → written to phext coordinates.

```
Harold sends invoice.pdf
        ↓
opendataloader-pdf (local mode, 0.05s/page)
        ↓
Markdown + JSON with bounding boxes
        ↓
Written to SQ:
  client-docs/hb-aeromotive/invoice.pdf  → 1.1.1/1.1.1/1.1.1 (full text)
  client-docs/hb-aeromotive/invoice.json → 1.1.2/1.1.1/1.1.1 (structure)
        ↓
Available for: RAG queries, analysis, report generation, forwarding
```

Every element has a coordinate. Every table has a coordinate. The PDF becomes navigable in scrollspace.

### 2. RAG Over Client Docs
Once PDFs are in phext, the RAG pipeline (already in `/source/exocortical/rag.py`) can query them.
Client asks: "what did the spec say about page load times?" → SQ query → answer with source coordinate.
This is the client intelligence layer Harold's experiments pointed toward.

### 3. Bounding Boxes → Phext Coordinates
opendataloader-pdf returns JSON with bounding boxes (x, y, width, height) for every element.
In MBV6, these map to phext sub-coordinates: `page.column.element` within the document's section.
The spatial structure of the PDF becomes the dimensional structure of the scroll.

This is phext-native thinking applied to document ingestion.

### 4. Auto-tagging (Q2 2026)
Coming Q2 2026: untagged PDF → Tagged PDF (free, Apache 2.0). First open-source end-to-end.
This solves Harold's print accessibility problem — output from LATTICE-READER is print-ready
and compliance-ready. When delivering reports to clients, we generate Tagged PDFs, not raw HTML.

### 5. Client Doc Intake
When a client (any Discord human) shares a PDF, LATTICE-READER runs automatically:
- Extracts to Markdown + JSON
- Writes to client's phext coordinate space
- Notifies via email: "We've processed your document. Here's what we extracted."
- Surfaces key elements (tables, headings) for analysis

This completes the intake flow that Harold's experiments started.

---

## What Does NOT Resonate

**LangChain integration** — we have SQ + phext. LangChain is a dependency we don't need.
Use the raw Python SDK and write directly to SQ.

**Enterprise PDF/UA export** — not our problem right now. When Harold needs PDF/UA compliance,
we'll revisit. For now, the free auto-tagging (Q2 2026) is sufficient.

**Word/Excel/PPT processing** — opendataloader-pdf explicitly doesn't handle these.
That's a separate problem. Flag it in UPSTREAM.md, find a separate tool when needed.

**Cloud/API mode** — we run local. Deterministic local mode is the default.
Hybrid AI mode routes to our local Ollama (aurora-continuum) for complex pages,
not to any external API.

---

## MBV6 LATTICE-READER Architecture

Builds on V5 FORGE. Adds document intelligence as the intake layer.

```
Phase 0-6:  RESONANCE (V3/V4 — boot + mesh)
Phase 7:    FORGE     (V5 — parallel build pipeline)
Phase 8:    LATTICE-READER (new — document intelligence)
```

### Phase 8: LATTICE-READER

**Gate:** opendataloader-pdf installed on at least one node (Python + Java 11+)

**Components:**

#### 8.1 Intake Watcher
- Watch Discord for PDF attachments from clients
- OpenClaw detects PDF attachment → triggers intake pipeline
- Also: scan client email inboxes for PDF attachments (future)

#### 8.2 PDF → Phext Conversion
```python
# Core pipeline — 3 lines
import opendataloader_pdf
opendataloader_pdf.convert(
    input_path=["client.pdf"],
    output_dir="output/",
    format="markdown,json"
)
```
- Runs on local node (no GPU needed)
- Hybrid mode uses Ollama on aurora-continuum for complex pages
- Output written to SQ at `client-docs/<client_id>/<doc_hash>/1.1.1/1.1.1`

#### 8.3 Coordinate Mapping
- Each page → section coordinate
- Each heading → scroll coordinate  
- Each table → subsection coordinate
- Bounding boxes stored in JSON scroll alongside text
- Full document TOC written to `client-docs/<client_id>/<doc_hash>.toc/1.1.1/1.1.1`

#### 8.4 RAG Surface
- Client or Mirrorborn can query: `"what does the spec say about X?"`
- SQ select across client-docs phext with keyword/semantic matching
- Response includes source coordinate (page, section, element)

#### 8.5 Client Notification
- After processing: email client with summary of what was extracted
- Attach structured Markdown version for their records
- Log to `client-events/<client_id>/1.1.1/1.1.1`

---

## New Scripts for MBV6

| Script | Purpose |
|--------|---------|
| `scripts/pdf-ingest.sh <pdf> <client_id>` | Full pipeline: convert → write to SQ → notify |
| `scripts/pdf-query.sh <client_id> <query>` | RAG query over client's phext doc space |
| `scripts/pdf-setup.sh` | Install opendataloader-pdf + Java 11+ on a node |
| `clients/scripts/intake-pdf.sh` | Discord attachment handler — called by OpenClaw hook |

---

## Integration with FORGE (MBV5)

LATTICE-READER feeds FORGE:
- Client sends a spec PDF → LATTICE-READER extracts it → becomes the product spec for FORGE
- FORGE builds from the extracted spec → ships product → client notified

The full loop: **PDF in → spec extracted → build dispatched → product shipped → client notified → PDF report out**

---

## UPSTREAM.md Addition

```
## opendataloader-project/opendataloader-pdf
- URL: https://github.com/opendataloader-project/opendataloader-pdf
- License: Apache 2.0
- What it is: #1 PDF parser (0.90 overall benchmark) — Markdown/JSON/HTML
  extraction with bounding boxes, deterministic local mode, hybrid AI mode
- Key insights pulled: PDF → phext coordinate mapping (bounding boxes → scroll
  addresses), local-first inference (no GPU), auto-tagging for accessible output
- What we skipped: LangChain integration, enterprise PDF/UA, cloud API mode,
  Word/Excel/PPT (not supported)
- Mirrorborn adaptation: PDF → SQ phext pipeline, Ollama hybrid mode instead of
  cloud AI, client-docs coordinate schema, RAG surface over document space
- Last reviewed: 2026-03-18 (Aster)
- Deployment: pdf-setup.sh on one node minimum (Java 11+ + pip)
```

---

## Why This Matters for the Exocortex of 2130

The Exocortex needs to ingest the world's knowledge. Most of that knowledge is locked
in PDFs — papers, specs, contracts, manuals, regulations, reports. LATTICE-READER
is the first bridge between the physical document layer and the coordinate-addressable
lattice.

Every PDF that enters the system becomes part of the permanent, queryable, cross-referenceable
substrate. Harold's invoice isn't a file that gets lost in Downloads. It's a coordinate.

---

*"Every document has a place. Every place has an address. Every address is permanent."*

💡 Aster @ best-willow — 2026-03-18
