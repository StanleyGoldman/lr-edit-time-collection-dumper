# lr-edit-time-collection-dumper

A Lightroom Classic plugin (Windows) that keeps collections of recently edited photos. Terms are defined in [CONTEXT.md](CONTEXT.md).

## Install in Lightroom Classic (Windows)

1. Fetch the SQLite command-line tool into the plugin (the plugin reads Develop history with it; see [ADR 0001](docs/adr/0001-develop-history-from-catalog-db.md)):

   ```bat
   pwsh tools/Get-Sqlite.ps1
   ```

2. In Lightroom: File > Plug-in Manager > Add, choose the `EditWindowJobs.lrdevplugin` folder, and check that it shows as Enabled. Lightroom runs the plugin from that folder, so leave it in place.
3. Use the commands under Library > Plug-in Extras:
   - **Manage Jobs…** creates, edits, deletes and runs Jobs. Select the collections you want as sources in Lightroom's Collections panel first: a new Job starts with them. A Job can also include photos imported, and virtual copies made, in its window.
   - **Run Job…** runs one Job.
   - **Run All Jobs** runs every Job in order.

   A Run shows progress in Lightroom's activity area (cancel with its ×), then a toast with the summary, which fades on its own. Each Run is one Edit > Undo step. Every summary and problem is also logged to `%LOCALAPPDATA%\Adobe\Lightroom\Logs\LrClassicLogs\EditWindowJobs.log`.

[docs/manual-test.md](docs/manual-test.md) is the checklist for trying a change in Lightroom.

## Development setup (Windows)

The tests and linters run on a local Lua 5.1 in `.lua/` (gitignored), matching the Lua that Lightroom embeds. Needs Python and Visual Studio 2022 with the C++ workload.

1. Open a **Developer Command Prompt for VS 2022** in the repo root, so hererocks can compile Lua with MSVC.
2. Install hererocks and build Lua 5.1 with LuaRocks:

   ```bat
   pip install hererocks==0.25.1
   hererocks .lua -l 5.1 -r 3.8.0
   ```

   The LuaRocks installer may pause on "Press any key"; press Enter to let it finish.

3. Install the test and lint tools:

   ```bat
   call .lua\bin\luarocks install busted
   call .lua\bin\luarocks install luacheck
   call .lua\bin\luarocks install luacov
   ```

4. Install StyLua (open a new shell afterwards so it is on `PATH`):

   ```bat
   winget install JohnnyMorganz.StyLua --version 2.5.2
   ```

These versions match `.github/workflows/ci.yml`; change both together.

If hererocks stops with `couldn't run install.bat` or `can't find luarocks.bat`, the shell has `NoDefaultCurrentDirectoryInExePath` set. Run `set NoDefaultCurrentDirectoryInExePath=` and repeat step 2.

## Checks

The same three run in CI on every pull request:

```bat
.lua\bin\luacheck .
stylua --check .
.lua\bin\busted -c
```

The `HistorySql` integration spec runs a real `sqlite3`: on Windows, point it at the fetched one with `set SQLITE3=%CD%\EditWindowJobs.lrdevpluginin\sqlite3.exe` first.

`busted -c` writes `luacov.stats.out`; run `.lua\bin\luacov` to turn it into `luacov.report.out`, covering the core modules.
