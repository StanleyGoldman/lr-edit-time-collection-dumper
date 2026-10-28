# lr-edit-time-collection-dumper

A Lightroom Classic plugin (Windows) that keeps collections of recently edited photos. Terms are defined in [CONTEXT.md](CONTEXT.md).

## Development setup (Windows)

The tests and linters run on a local Lua 5.1 in `.lua/` (gitignored), matching the Lua that Lightroom embeds. Needs Python and Visual Studio 2022 with the C++ workload.

1. Open a **Developer Command Prompt for VS 2022** in the repo root, so hererocks can compile Lua with MSVC.
2. Install hererocks and build Lua 5.1 with LuaRocks:

   ```bat
   pip install hererocks
   hererocks .lua -l 5.1 -r latest
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
   winget install JohnnyMorganz.StyLua
   ```

If hererocks stops with `couldn't run install.bat` or `can't find luarocks.bat`, the shell has `NoDefaultCurrentDirectoryInExePath` set. Run `set NoDefaultCurrentDirectoryInExePath=` and repeat step 2.

## Checks

The same three run in CI on every pull request:

```bat
.lua\bin\luacheck .
stylua --check .
.lua\bin\busted -c
```

`busted -c` writes `luacov.stats.out`; run `.lua\bin\luacov` to turn it into `luacov.report.out`, covering `EditWindowJobs.lrdevplugin/core/`.
