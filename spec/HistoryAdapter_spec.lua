local HistoryAdapter = require "HistoryAdapter"

describe("HistoryAdapter:editedImageIds", function()
	local tempDir = (os.getenv "TEMP" or "/tmp")
	local sqlitePath = tempDir .. "/fake-sqlite3.exe"

	-- execute fake: records the command, then writes `output` where the command
	-- redirects stdout, as sqlite3 would, and returns exitCode.
	local function fakeExecute(output, exitCode)
		local calls = {}
		local function execute(command)
			calls[#calls + 1] = command
			local outPath = string.match(command, '> "([^"]+)"')
			local file = assert(io.open(outPath, "w"))
			file:write(output)
			file:close()
			return exitCode or 0
		end
		return execute, calls
	end

	local function adapter(execute, overrides)
		local args = {
			execute = execute,
			sqlitePath = sqlitePath,
			catalogPath = [[C:\Users\Me\Pictures\Lightroom\My Catalog.lrcat]],
			tempDir = tempDir,
			isWindows = true,
		}
		for key, value in pairs(overrides or {}) do
			args[key] = value
		end
		return HistoryAdapter.new(args)
	end

	before_each(function()
		local file = assert(io.open(sqlitePath, "w"))
		file:write "stand-in"
		file:close()
	end)

	after_each(function()
		os.remove(sqlitePath)
	end)

	it("runs sqlite3 read-only on the catalog and returns the edited photo ids", function()
		local execute, calls = fakeExecute "12\n40\n"
		local ids = adapter(execute):editedImageIds(100, 200)
		assert.are.same({ [12] = true, [40] = true }, ids)
		assert.are.equal(1, #calls)
		assert.matches(
			'^""[^"]+fake%-sqlite3%.exe" %-readonly "C:\\Users\\Me\\Pictures\\Lightroom\\My Catalog%.lrcat" < "',
			calls[1]
		)
		assert.matches('2>&1"$', calls[1])
	end)

	it("leaves the command unwrapped outside Windows", function()
		local execute, calls = fakeExecute ""
		adapter(execute, { isWindows = false }):editedImageIds(100, nil)
		assert.matches('^"[^"]+fake%-sqlite3%.exe"', calls[1])
	end)

	it("cleans up its temporary files", function()
		local execute = fakeExecute "1\n"
		adapter(execute):editedImageIds(100, nil)
		assert.is_nil(io.open(tempDir .. "/EditWindowJobs-history.sql", "r"))
		assert.is_nil(io.open(tempDir .. "/EditWindowJobs-history.out", "r"))
	end)

	it("explains a missing sqlite3.exe", function()
		os.remove(sqlitePath)
		local ids, message = adapter(fakeExecute ""):editedImageIds(100, nil)
		assert.is_nil(ids)
		assert.matches("sqlite3.exe is missing", message, 1, true)
		assert.matches("README", message, 1, true)
	end)

	it("reports a failed sqlite3 run with its output", function()
		local execute = fakeExecute("Error: unable to open database file\n", 1)
		local ids, message = adapter(execute):editedImageIds(100, nil)
		assert.is_nil(ids)
		assert.matches("exited with code 1", message, 1, true)
		assert.matches("unable to open database file", message, 1, true)
	end)

	it("reports output that is not photo ids", function()
		local ids, message = adapter(fakeExecute "Error: no such table: x\n"):editedImageIds(100, nil)
		assert.is_nil(ids)
		assert.matches("no such table", message, 1, true)
	end)
end)
