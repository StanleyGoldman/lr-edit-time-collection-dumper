# Edit Time Spike (throwaway)

A one-menu-item plugin that answers the open questions before the real plugin is built.
It is not meant to be merged; its findings go to `docs/research/edit-time-spike.md`.

## Questions it answers

1. Does adding or removing a photo from a collection change its `lastEditTime`?
2. Can `sqlite3.exe -readonly` read the catalog's Develop history while Lightroom is open, and how fast?
3. What history steps does a fresh import create, and what epoch is `dateCreated` in?
4. Does `photo.localIdentifier` equal `Adobe_images.id_local`, and how do virtual copies link to history?
5. Does Lightroom's `require` load files from a subfolder?

## Setup

1. Put `sqlite3.exe` (from `sqlite-tools-win-x64-3540100.zip`, sqlite.org) in
   `EditTimeSpike.lrdevplugin\bin\`. It is gitignored.
2. Close Lightroom. Copy your catalog folder's `.lrcat` to a new folder (for example
   `Pictures\Lightroom Spike\Spike.lrcat`) and open the **copy** in Lightroom.
3. File > Plug-in Manager > Add, pick `spike\EditTimeSpike.lrdevplugin`, make sure it is enabled.

## Prepare the photos

Do these in order, each a minute or so apart so their times are distinguishable:

1. **Import** one new photo (any file that is not already in the catalog), with no develop preset.
2. **Import** one more new photo, this time with a develop preset applied in the Import dialog.
3. Pick an existing photo, **create a virtual copy** of it (Ctrl+'), and change the exposure on the
   **virtual copy only**.
4. Pick another existing photo and change its **rating** and add a **keyword** (no Develop change).

Then select all five photos (the two imports, the virtual copy, its master, the rated photo) in Grid view.

## Run

Library > Plug-in Extras > Run Edit Time Spike. Wait for the "Done" dialog (about 10 seconds plus the
SQLite time), then send back `Documents\edit-time-spike.log`.

The run creates a collection called "Edit Time Spike" in the copied catalog; delete it, or the whole
copy, afterwards.
