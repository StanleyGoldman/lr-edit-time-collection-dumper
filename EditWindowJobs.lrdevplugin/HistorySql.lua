-- Builds the sqlite3 script that finds edited photos in a catalog, and reads its
-- output. Table and step names come from docs/research/edit-time-spike.md.

local HistorySql = {}

-- History steps whose name starts with one of these are not Edits. Lightroom
-- writes step names in its UI language; these are the English ones.
-- CREATION_PREFIXES record the photo arriving or a virtual copy being made, which
-- a Job that includes created photos counts alongside its Edits.
HistorySql.CREATION_PREFIXES = {
	"Import (",
	"Imported from Lr mobile",
	"Create Virtual Cop",
	"Create Proof Copy",
}
-- OTHER_PREFIXES record the photo being exported, published or snapshotted.
HistorySql.OTHER_PREFIXES = {
	"Publish - ",
	"Export - ",
	"Snapshot: ",
}

local function startsWithAny(text, prefixes)
	for _, prefix in ipairs(prefixes) do
		if string.sub(text, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

function HistorySql.isEdit(stepName)
	return not startsWithAny(stepName, HistorySql.CREATION_PREFIXES)
		and not startsWithAny(stepName, HistorySql.OTHER_PREFIXES)
end

local function sqlNumber(value)
	if type(value) ~= "number" then
		error("expected a number, got " .. type(value), 3)
	end
	return string.format("%.6f", value)
end

local function sqlString(text)
	return "'" .. string.gsub(text, "'", "''") .. "'"
end

-- Returns a script for `sqlite3 -readonly <catalog>` that prints, one per line,
-- the id of every photo with an Edit at or after startTime and before endTime
-- (no upper bound when endTime is nil). Times are Cocoa seconds. includeCreated
-- also counts photos imported or virtual copies made in that time.
function HistorySql.editedImagesScript(startTime, endTime, includeCreated)
	local conditions = { "dateCreated >= " .. sqlNumber(startTime) }
	if endTime ~= nil then
		conditions[#conditions + 1] = "dateCreated < " .. sqlNumber(endTime)
	end
	local excluded = { unpack(HistorySql.OTHER_PREFIXES) }
	if not includeCreated then
		for _, prefix in ipairs(HistorySql.CREATION_PREFIXES) do
			excluded[#excluded + 1] = prefix
		end
	end
	-- substr, unlike LIKE, compares exactly: case-sensitive and with no wildcards.
	for _, prefix in ipairs(excluded) do
		conditions[#conditions + 1] =
			string.format("substr(coalesce(name, ''), 1, %d) <> %s", #prefix, sqlString(prefix))
	end
	return table.concat({
		".timeout 5000",
		".bail on",
		".headers off",
		".mode list",
		"SELECT DISTINCT image FROM Adobe_libraryImageDevelopHistoryStep",
		"WHERE " .. table.concat(conditions, "\n  AND ") .. ";",
		"",
	}, "\n")
end

-- Reads the script's output into a set of photo ids ({ [id] = true }), or returns
-- nil and a message quoting the first line that is not an id, such as an error.
function HistorySql.parseImageIds(output)
	local ids = {}
	for line in string.gmatch(output, "[^\r\n]+") do
		local id = string.match(line, "^%d+$")
		if not id then
			return nil, "sqlite3 printed: " .. line
		end
		ids[tonumber(id)] = true
	end
	return ids
end

return HistorySql
