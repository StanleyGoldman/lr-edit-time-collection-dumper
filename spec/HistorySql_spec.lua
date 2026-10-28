local HistorySql = require "HistorySql"

describe("HistorySql.isEdit", function()
	local notEdits = {
		"Import (10/27/2026 10:57:02 PM)",
		"Imported from Lr mobile (4/2/2024 9:01:11 AM)",
		"Publish - jf Collection Publisher (9/13/2022 1:21:28 AM)",
		"Export - Hard Drive (1/5/2025 3:00:00 PM)",
		"Create Virtual Copy (3/3/2023 8:00:00 PM)",
		"Create Virtual Copies (3/3/2023 8:00:00 PM)",
		"Create Proof Copy (3/3/2023 8:00:00 PM)",
		"Snapshot: 16:9 Crop - Export - Hard Drive (3/3/2023 8:00:00 PM)",
	}
	for _, name in ipairs(notEdits) do
		it("rejects " .. name, function()
			assert.is_false(HistorySql.isEdit(name))
		end)
	end

	local edits = {
		"Exposure",
		"Auto Settings",
		"From Lr mobile",
		"Update AI Settings",
		"Paste Settings",
		"Edited in Adobe Photoshop",
		"Importance",
		"",
	}
	for _, name in ipairs(edits) do
		it("accepts " .. string.format("%q", name), function()
			assert.is_true(HistorySql.isEdit(name))
		end)
	end
end)

describe("HistorySql.parseImageIds", function()
	it("reads one image id per line", function()
		local ids = HistorySql.parseImageIds "70473804\n12\n70473804\n"
		assert.are.same({ [70473804] = true, [12] = true }, ids)
	end)

	it("accepts empty output as no edited photos", function()
		assert.are.same({}, HistorySql.parseImageIds "")
	end)

	it("tolerates Windows line endings", function()
		assert.are.same({ [5] = true }, HistorySql.parseImageIds "5\r\n")
	end)

	it("fails on anything else, quoting the line", function()
		local ids, message = HistorySql.parseImageIds "5\nError: no such table: Adobe_libraryImageDevelopHistoryStep\n"
		assert.is_nil(ids)
		assert.matches("no such table", message, 1, true)
	end)
end)

describe("HistorySql.editedImagesScript", function()
	it("bounds the search on both sides for a fixed window", function()
		local script = HistorySql.editedImagesScript(100.5, 200)
		assert.matches("dateCreated >= 100.5", script, 1, true)
		assert.matches("dateCreated < 200", script, 1, true)
	end)

	it("leaves out the upper bound for an open window", function()
		local script = HistorySql.editedImagesScript(100, nil)
		assert.is_nil(string.find(script, "dateCreated <", 1, true))
	end)

	it("rejects a start time that is not a number", function()
		assert.has_error(function()
			HistorySql.editedImagesScript("100; DROP TABLE x", nil)
		end)
	end)
end)

-- Runs the generated script with a real sqlite3 against a database that has the
-- catalog's history table shape (see docs/research/edit-time-spike.md).
describe("HistorySql against sqlite3", function()
	local isWindows = os.getenv "OS" == "Windows_NT"
	local sqlite3 = os.getenv "SQLITE3" or "sqlite3"
	local tempDir = os.getenv "TEMP" or "/tmp"
	local dbPath = tempDir .. "/history_spec.db"
	local scriptPath = tempDir .. "/history_spec.sql"

	local function run(sqlText)
		local file = assert(io.open(scriptPath, "w"))
		file:write(sqlText)
		file:close()
		local command = string.format('"%s" "%s" < "%s" 2>&1', sqlite3, dbPath, scriptPath)
		if isWindows then
			command = '"' .. command .. '"'
		end
		local pipe = assert(io.popen(command))
		local output = pipe:read "*a"
		pipe:close()
		return output
	end

	local function sqlString(text)
		return "'" .. text:gsub("'", "''") .. "'"
	end

	local steps = {
		-- image, dateCreated, name
		{ 1, 150, "Exposure" },
		{ 2, 150, "Import (10/27/2026 10:57:02 PM)" },
		{ 3, 150, "Publish - jf Collection Publisher (9/13/2022 1:21:28 AM)" },
		{ 4, 50, "Exposure" },
		{ 5, 250, "Crop Rectangle" },
		{ 6, 150, "Create Virtual Copy (3/3/2023 8:00:00 PM)" },
		{ 6, 160, "From Lr mobile" },
		{ 7, 100, "Auto Settings" },
		{ 8, 200, "Auto Settings" },
		{ 9, 150, "Snapshot: Before (3/3/2023 8:00:00 PM)" },
		{ 10, 150, "O'Brien's preset" },
		{ 11, 150, nil },
	}

	setup(function()
		os.remove(dbPath)
		local rows = {}
		for index, step in ipairs(steps) do
			local name = step[3] and sqlString(step[3]) or "NULL"
			rows[#rows + 1] = string.format(
				"INSERT INTO Adobe_libraryImageDevelopHistoryStep (id_local, id_global, dateCreated, image, name)"
					.. " VALUES (%d, 'g%d', %s, %d, %s);",
				index,
				index,
				step[2],
				step[1],
				name
			)
		end
		local output = run(
			"CREATE TABLE Adobe_libraryImageDevelopHistoryStep (id_local INTEGER PRIMARY KEY,"
				.. " id_global UNIQUE NOT NULL, dateCreated, digest, hasBigData INTEGER NOT NULL DEFAULT 0,"
				.. " hasDevelopAdjustments, image INTEGER, name, relValueString, text, valueString);\n"
				.. table.concat(rows, "\n")
				.. "\n"
		)
		assert.are.equal("", output)
	end)

	teardown(function()
		os.remove(dbPath)
		os.remove(scriptPath)
	end)

	it("finds photos with an Edit inside a fixed window", function()
		local ids = assert(HistorySql.parseImageIds(run(HistorySql.editedImagesScript(100, 200))))
		assert.are.same({ [1] = true, [6] = true, [7] = true, [10] = true, [11] = true }, ids)
	end)

	it("finds photos with an Edit any time after the start of an open window", function()
		local ids = assert(HistorySql.parseImageIds(run(HistorySql.editedImagesScript(100, nil))))
		assert.are.same({ [1] = true, [5] = true, [6] = true, [7] = true, [8] = true, [10] = true, [11] = true }, ids)
	end)

	it("reports a catalog without the history table as an error", function()
		os.remove(dbPath)
		local ids, message = HistorySql.parseImageIds(run(HistorySql.editedImagesScript(100, nil)))
		assert.is_nil(ids)
		assert.matches("no such table", message, 1, true)
	end)
end)
