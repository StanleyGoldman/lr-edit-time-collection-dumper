-- Reads Develop history out of the catalog with the bundled sqlite3.exe
-- (see docs/adr/0001-develop-history-from-catalog-db.md). Satisfies the
-- deps.history interface in Runner.lua.

local HistorySql = require "HistorySql"

local HistoryAdapter = {}
HistoryAdapter.__index = HistoryAdapter

-- args.execute: LrTasks.execute. args.sqlitePath, args.catalogPath, args.tempDir:
-- absolute paths. args.isWindows: WIN_ENV, which decides the cmd.exe quoting.
function HistoryAdapter.new(args)
	return setmetatable({
		execute = args.execute,
		sqlitePath = args.sqlitePath,
		catalogPath = args.catalogPath,
		tempDir = args.tempDir,
		isWindows = args.isWindows,
	}, HistoryAdapter)
end

local function readFile(path)
	local file = io.open(path, "r")
	if not file then
		return nil
	end
	local text = file:read "*a"
	file:close()
	return text
end

-- Returns the set of photo ids with an Edit in [startTime, endTime), or nil and
-- a message. endTime nil means no upper bound.
function HistoryAdapter:editedImageIds(startTime, endTime)
	if not readFile(self.sqlitePath) then
		return nil,
			string.format(
				"sqlite3.exe is missing from %s. The README explains how to fetch it into the plugin.",
				self.sqlitePath
			)
	end
	-- Windows accepts "/" in paths, so one separator serves every platform.
	-- Every Run overwrites these two files and nothing deletes them, so the
	-- plugin holds no file-deleting code; the ">" redirect empties the output
	-- before sqlite3 writes, so a Run never reads an earlier Run's ids.
	local scriptPath = self.tempDir .. "/EditWindowJobs-history.sql"
	local outputPath = self.tempDir .. "/EditWindowJobs-history.out"
	local script = assert(io.open(scriptPath, "w"))
	script:write(HistorySql.editedImagesScript(startTime, endTime))
	script:close()

	local command = string.format(
		'"%s" -readonly "%s" < "%s" > "%s" 2>&1',
		self.sqlitePath,
		self.catalogPath,
		scriptPath,
		outputPath
	)
	if self.isWindows then
		-- cmd.exe strips the outermost quotes from a command that starts with one.
		command = '"' .. command .. '"'
	end
	local exitCode = self.execute(command)
	local output = readFile(outputPath) or ""

	if exitCode ~= 0 then
		return nil, string.format("sqlite3 exited with code %s: %s", tostring(exitCode), output)
	end
	return HistorySql.parseImageIds(output)
end

return HistoryAdapter
