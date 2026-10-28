-- Reads Develop history out of the catalog with the bundled sqlite3.exe
-- (see docs/adr/0001-develop-history-from-catalog-db.md). Satisfies the
-- deps.history interface in Runner.lua.

local HistorySql = require "HistorySql"

local HistoryAdapter = {}
HistoryAdapter.__index = HistoryAdapter

-- args.execute: LrTasks.execute. args.sqlitePath, args.catalogPath, args.tempDir:
-- absolute paths. args.isWindows: WIN_ENV.
function HistoryAdapter.new(args)
	return setmetatable({
		execute = args.execute,
		sqlitePath = args.sqlitePath,
		catalogPath = args.catalogPath,
		tempDir = args.tempDir,
		separator = args.isWindows and "\\" or "/",
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
	local scriptPath = self.tempDir .. self.separator .. "EditWindowJobs-history.sql"
	local outputPath = self.tempDir .. self.separator .. "EditWindowJobs-history.out"
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
	os.remove(scriptPath)
	os.remove(outputPath)

	if exitCode ~= 0 then
		return nil, string.format("sqlite3 exited with code %s: %s", tostring(exitCode), output)
	end
	return HistorySql.parseImageIds(output)
end

return HistoryAdapter
