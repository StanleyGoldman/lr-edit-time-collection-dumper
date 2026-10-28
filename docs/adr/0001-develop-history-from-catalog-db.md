# Read Develop history from the catalog database

An Edit is a Develop history step, and the Lightroom SDK exposes no history dates. Its nearest field, `lastEditTime`, also moves on rating, flag, keyword and caption changes, and it records only the latest change, so it can't tell whether an earlier Edit fell inside an Edit Window. We therefore read history step dates straight from the `.lrcat` (SQLite) with a bundled `sqlite3.exe` opened read-only, isolated in one adapter.

## Consequences

- The catalog schema is undocumented and Adobe may change it in any release. A Run that can't read history aborts with an error and leaves the Target Collection untouched, rather than guessing.
- The plugin ships a native executable and is Windows-only until a macOS binary is added.
- Reading a database Lightroom has open relies on SQLite's concurrent-reader behaviour; the spike (`docs/research/edit-time-spike.md`) checks this against a real catalog.
