# Read Develop history from the catalog database

An Edit is a Develop history step, and the Lightroom SDK exposes no history dates. Its nearest field, `lastEditTime`, also moves on rating, flag, keyword and caption changes, and it records only the latest change, so it can't tell whether an earlier Edit fell inside an Edit Window. We therefore read history step dates straight from the `.lrcat` (SQLite) with a bundled `sqlite3.exe` opened read-only, isolated in one adapter.

## Consequences

- The catalog schema is undocumented and Adobe may change it in any release. A Run that can't read history aborts with an error and leaves the Target Collection untouched, rather than guessing.
- The plugin ships a native executable and is Windows-only until a macOS binary is added.
- Reading a database Lightroom has open relies on SQLite's concurrent-reader behaviour. The spike confirmed it on a 202k-photo catalog with Lightroom open; see `docs/research/edit-time-spike.md`.
- Which steps are Edits, and which record a Created Photo, is decided by step name, and Lightroom writes step names in its UI language. The prefixes are English, matching the plugin's English-only scope. Created Photos also rely on every import writing an `Import (` step, which the spike saw for every photo in one catalog.
