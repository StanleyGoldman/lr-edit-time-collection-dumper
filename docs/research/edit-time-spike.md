# Edit time spike: findings

Run on 2026-10-27 against the live catalog `Lightroom Catalog-v13-3.lrcat` (Lightroom Classic, Windows,
202,054 photos, 550,739 history steps), with Lightroom open. The throwaway plugin lives on branch
`spike/edit-time`; follow-up queries were run with the same `sqlite3.exe -readonly`.

## Reading history while Lightroom is open

- `sqlite3.exe -readonly <catalog> < script.sql` exits 0 while Lightroom has the catalog open; no lock errors.
- `Adobe_libraryImageDevelopHistoryStep` has an index on `(image, dateCreated)`. Lookups by image take
  milliseconds; "every image with a step after time T" over all 550k rows takes ~40 ms. Only a GROUP BY
  over step names was slow (1.2 s), and the plugin never needs it.
- Columns: `id_local, id_global, dateCreated, digest, hasBigData, hasDevelopAdjustments, image, name,
  relValueString, text, valueString`. `text` holds full settings; select named columns only.

## Ids and times

- `photo.localIdentifier` equals `Adobe_images.id_local`, and history's `image` column references it.
- `dateCreated` is Cocoa seconds (since 2001-01-01 UTC) with a fractional part, the same epoch as
  `LrDate.currentTime()`. Step names embed the same instant in local time, e.g. `Import (10/27/2026 10:57:02 PM)`.
- Timestamps follow the PC clock at write time. This catalog holds 1,538 steps stamped up to ~3½ hours
  ahead, written while the clock ran fast and followed by correctly-stamped rows (higher `id_local`).
  Relative Edit Windows therefore have no upper bound, so such steps still count.

## Which steps are Edits

- Rating, flag, keyword, label and caption changes create no history steps (none exist in the catalog).
- Every photo has an import step named `Import (<local date time>)`, also when a preset was applied on
  import (534 import steps carry `hasDevelopAdjustments` 0 or 1 instead of -1).
- Steps that record something other than a change to the image, excluded from Edits by decision:

  | Name prefix | Steps | What it records |
  |---|---|---|
  | `Import (` | 195,427 | The photo arriving |
  | `Imported from Lr mobile` | 2,968 | The photo arriving from Lightroom mobile |
  | `Publish - ` | 192,598 | A publish service (here jf Collection Publisher) sending the photo |
  | `Export - ` | 10,151 | An export |
  | `Create Virtual Cop` | 3,642 | Creating a virtual copy (`Copy` and `Copies`) |
  | `Create Proof Copy` | 1 | Soft-proofing copy |
  | `Snapshot: ` | 1 | Saving a snapshot |

- Kept as Edits: slider and tool steps (`Exposure`, `Crop Rectangle`, ...), `Auto Settings`, `Paste Settings`,
  `Reset Settings`, `From Lr mobile` (edits synced from mobile), `Update AI Settings`,
  `Edited in Adobe Photoshop`.
- Step names are written in Lightroom's UI language; the prefixes above are the English ones.

## Virtual copies

Each virtual copy is its own `Adobe_images` row (`masterImage` points at the master) with its own history
rows, so a copy and its master are judged on their own Edits with no extra logic.

## Collections and `lastEditTime`

`collection:addPhotos` and `removePhotos` leave `lastEditTime` and `editCount` unchanged. `lastEditTime` on
the never-edited test photo was still 10 minutes later than its import step, confirming it tracks more than
Develop changes.

## Loading plugin files

Lightroom's `require` loads only files at the top of the plugin folder: `require "sub/Helper"` fails with
"invalid characters in script name" and `require "sub.Helper"` with "doesn't seem to be in the toolkit".
All plugin `.lua` files therefore sit flat in `EditWindowJobs.lrdevplugin/`.
