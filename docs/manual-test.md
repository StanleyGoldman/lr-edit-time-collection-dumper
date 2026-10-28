# Manual test in Lightroom Classic

The adapters, dialogs and menus can only be exercised inside Lightroom. Run this list after a change to
any `*Adapter.lua`, `*Dialog.lua`, `*Menu.lua` or `Info.lua`, on a catalog you have backed up.

Setup: `pwsh tools/Get-Sqlite.ps1`, then File > Plug-in Manager > Add (or Reload Plug-in) on
`EditWindowJobs.lrdevplugin`. Problems are logged to
`%LOCALAPPDATA%\Adobe\Lightroom\Logs\LrClassicLogs\EditWindowJobs.log`.

## Jobs

- [ ] With no Jobs, Run Job… and Run All Jobs say there are no Jobs yet.
- [ ] Select two collections (one smart) in the Collections panel, open Manage Jobs…, click New Job…: both
      appear under the chosen sources.
- [ ] Typing words in Find narrows the available list by full path, including parent set names.
- [ ] Add ↓ and Remove ↑ move collections between the lists.
- [ ] The Target popup lists only regular collections; Find narrows it.
- [ ] Typing a name in "Or new" creates that collection at the top level on Save.
- [ ] Save is refused, with a message, for: blank name, no sources, the target also a source, a target
      another Job uses, a duplicate name, length "0", dates in the wrong form, end before start.
- [ ] Close and reopen Manage Jobs…: the Jobs are still there. Restart Lightroom: still there.
- [ ] Edit… changes a Job; Delete… asks first and leaves the Target Collection alone.
- [ ] "Also include photos imported and virtual copies made in the window" starts unchecked for a new Job
      and keeps its state after Save, close and reopen.

## Runs

- [ ] Relative window "Last 7 days": the target ends up with exactly the source photos you changed in
      Develop this week. Rating or keywording a photo alone does not bring it in.
- [ ] Fixed window covering one past day: photos edited that day are in, even if edited again since.
- [ ] After a Run, a toast gives the summary and fades without a click; a failure stays up longer.
- [ ] A photo you dragged into the target by hand is removed by the next Run.
- [ ] A virtual copy edited in the window is added without its master (unless the master was also edited).
- [ ] With "Also include photos imported…" checked, a photo imported into a Source Collection in the window
      and a virtual copy made in the window come in without being edited; unchecked, they stay out.
- [ ] The progress bar shows in the activity area; clicking its × leaves the target unchanged and the
      toast says the Job was canceled.
- [ ] Edit > Undo after a Run reverts that Run in one step and names it "Run Job: <name>".
- [ ] Delete a Source Collection, run the Job: the toast names the missing collection and the target
      is unchanged.
- [ ] Run All Jobs with one broken Job: the others still run, the toast counts each outcome and the log lists each Job.
- [ ] Move `bin\sqlite3.exe` away and run: the toast explains it is missing and points to the README.
