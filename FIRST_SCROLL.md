# Your First Scroll

Write your first scroll to SQ in under 2 minutes.

## What You Need

- **SQ** — the phext database. Install it:
  ```bash
  cargo install sq
  ```
  No Rust? Use Docker: `docker run -p 1337:1337 wbic16/sq` *(coming soon)*

- **curl** — you already have this.

## Start SQ

```bash
sq host 1337
```

SQ is now listening. Open another terminal.

## Write Your First Scroll

```bash
curl "http://localhost:1337/api/v2/update?p=hello&c=1.1.1/1.1.1/1.1.1&s=Hello%20from%20the%20lattice"
```

That's it. You just wrote to coordinate `1.1.1/1.1.1/1.1.1` — **BASE**, the origin of scrollspace.

## Read It Back

```bash
curl "http://localhost:1337/api/v2/select?p=hello&c=1.1.1/1.1.1/1.1.1"
```

You should see: `Hello from the lattice`

## Write a Second Scroll

```bash
curl "http://localhost:1337/api/v2/update?p=hello&c=1.1.1/1.1.1/1.1.2&s=Second%20scroll.%20The%20lattice%20remembers."
```

Now you have two scrolls. Check the table of contents:

```bash
curl "http://localhost:1337/api/v2/toc?p=hello"
```

## What Just Happened

You wrote plain text into an 11-dimensional coordinate system. Each scroll lives at a unique address like `1.1.1/1.1.1/1.1.2` — that's `library.shelf.series/collection.volume.book/chapter.section.scroll`.

This is **phext** — plain text extended to 11 dimensions. SQ is the database that stores it.

## Next Steps

- **Explore coordinates:** Try writing to `1.1.1/1.1.1/2.1.1` (a new section) or `1.1.1/1.1.2/1.1.1` (a new volume).
- **Connect to the ranch:** Join our [Discord](https://discord.gg/2yFGMt6N) and write a scroll to the shared phext.
- **Read the Incipit:** The founding document of the Mirrorborn — [incipit.phext](https://github.com/wbic16/human/blob/main/incipit.phext)
- **Learn more:** [SQ on GitHub](https://github.com/wbic16/SQ) | [phext spec](https://phext.io)

## Join SQ Cloud

Don't want to self-host? [SQ Cloud](https://mirrorborn.us/pricing.html) runs it for you.

SQ is free, open-source, MIT licensed. SQ Cloud is hosted convenience.

---

*"The lattice remembers what sessions forget."*
