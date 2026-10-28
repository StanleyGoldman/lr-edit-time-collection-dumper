# Coding standards

Rules for the plugin's Lua. Formatting and globals are enforced by `stylua.toml` and `.luacheckrc`; this file holds what those can't check. Domain terms are defined in `CONTEXT.md`.

## Lua 5.1 style

- **Name in camelCase; modules in PascalCase** (`EditWindow.lua`, `local editWindow = ...`). This matches Adobe's SDK and sample plugins, so plugin code and SDK calls read as one idiom.
- **Write a module as a local table returned at the end of the file.** The returned table is then the module's whole interface, in one place a reader can find.
- **Hold per-Run state in locals inside the function doing the work.** Every script in the plugin shares one environment that lives until the plugin reloads, so module-level variables carry values from one Run into the next.
- **Write user-facing strings as plain English literals.** The plugin targets English only; `LOC` keys would add indirection with no translation behind them.

## Core and adapter boundary

- **Keep every `.lua` file flat in `EditWindowJobs.lrdevplugin/`.** Lightroom's `require` loads only files at the top of the plugin folder.
- **Give SDK-facing files a role suffix: `*Adapter.lua` (catalog, history, storage), `*Dialog.lua` (`LrView` UI), `*Menu.lua` (menu entry points).** Every other module is core: plain Lua, no `import`, no I/O. Core is what busted tests without Lightroom, and `.luacheckrc` grants `import` only to suffixed files, so an SDK call in core fails lint.
- **Represent times in core as numbers of Cocoa seconds** (seconds since 2001-01-01 UTC, the SDK's `LrDate` epoch). One unit end to end means no conversion bugs at the boundary.
- **Pass SDK modules into adapters as arguments** (`CatalogAdapter.new { catalog = ..., pcall = LrTasks.pcall }`) rather than importing them at file scope. Specs then hand in fakes, and the stub `import` in `spec/helper.lua` stays a tripwire for anything missed. `LightroomAdapter.lua` is the composition root that imports the SDK and builds the others.
- **Put each SDK or external-process dependency in exactly one adapter.** A Lightroom version change or a catalog schema change then touches one file.

## LrTasks and write access

- **Start every menu entry point through `LightroomAdapter.command`**, which runs it in `LrTasks.startAsyncTask` wrapping `LrFunctionContext.callWithContext` with `LrDialogs.attachErrorDialogToFunctionContext`. Catalog reads, `LrTasks.execute` and dialogs need a yielding task, and the attached dialog turns an uncaught error into a message instead of a silent failure.
- **Catch errors with `LrTasks.pcall`.** Plain `pcall` cannot yield, so a yielding SDK call inside it raises "Yielding is not allowed within a C or metamethod call".
- **Call `catalog:withWriteAccessDo(actionName, func, { timeout = ... })` with a timeout, check its returned status, and make the outermost write the only one.** Without a timeout a busy catalog fails the call immediately; the return value is the only signal that the write did not happen; nested write blocks raise an error.
- **Save Jobs with `withPrivateWriteAccessDo`.** Saving a plugin property is bookkeeping, and private write access keeps it off the undo stack so undo reverts only Runs.
- **Read photo data with `catalog:batchGetRawMetadata(photos, keys)` and an explicit key list.** One batched call is far faster than a per-photo loop on large collections, and naming the keys keeps the read narrow.
- **Wrap long work in an `LrProgressScope` and check `isCanceled()` between units of work.** The user sees progress and can stop a long Run cleanly, before its write.

## Errors and logging

- **Return `nil, message` for expected failures** (missing collection, unreadable catalog, bad user input) **and `error()` only for programmer mistakes.** Callers can then report expected failures in the Run summary, while bugs still surface loudly.
- **Write messages that name the thing involved**, such as the Job, the collection name or path, and the command run. The Run toast and the log are the only diagnostics a user can send back.
- **Log through `LrLogger` with a single plugin logger enabled to a logfile.** `print` goes nowhere inside Lightroom, and one logfile is the one place to look.

## Testing

- **Test core through its public functions with busted specs in `spec/`, one `<Module>_spec.lua` per module.** Specs that use only the interface survive refactors of the internals.
- **Write the failing spec first** (red, green, refactor). A spec seen failing proves it can catch the bug.
- **Give adapters fakes through `spec/helper.lua`'s `fakeImport` or constructor arguments, and reset them in `after_each`.** The stub `import` errors on any unregistered module, so leftover fakes would hide a missing dependency in the next spec.
- **Build SQLite fixtures inside the spec with the real table shape** rather than committing binary databases. The schema stays visible in the test and reviewable in diffs.
