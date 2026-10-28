-- Throwaway spike: answers the questions in spike/README.md and writes everything to
-- Documents\edit-time-spike.log. Run it only against a COPY of a catalog.

local LrApplication = import "LrApplication"
local LrDate = import "LrDate"
local LrDialogs = import "LrDialogs"
local LrFileUtils = import "LrFileUtils"
local LrFunctionContext = import "LrFunctionContext"
local LrPathUtils = import "LrPathUtils"
local LrTasks = import "LrTasks"

local logPath = LrPathUtils.child(LrPathUtils.getStandardFilePath("documents"), "edit-time-spike.log")
local tempDir = LrPathUtils.getStandardFilePath("temp")
local sqlitePath = LrPathUtils.child(LrPathUtils.child(_PLUGIN.path, "bin"), "sqlite3.exe")
local logFile

local function log(fmt, ...)
	logFile:write(string.format(fmt, ...), "\n")
	logFile:flush()
end

local function formatTime(t)
	if t == nil then
		return "nil"
	end
	return string.format("%.3f (%s)", t, LrDate.timeToUserFormat(t, "%Y-%m-%d %H:%M:%S"))
end

local function tryRequire(name)
	local ok, result = LrTasks.pcall(require, name)
	local detail = result
	if ok and type(result) == "table" then
		detail = result.loadedFrom
	end
	log("require(%q): ok=%s -> %s", name, tostring(ok), tostring(detail))
end

local function describePhotos(catalog, label, photos)
	local raw = catalog:batchGetRawMetadata(photos, { "lastEditTime", "editCount", "uuid", "isVirtualCopy", "masterPhoto", "path" })
	for _, photo in ipairs(photos) do
		local m = raw[photo]
		log(
			"[%s] localId=%s uuid=%s vc=%s masterLocalId=%s copyName=%s path=%s lastEditTime=%s editCount=%s",
			label,
			tostring(photo.localIdentifier),
			tostring(m.uuid),
			tostring(m.isVirtualCopy),
			m.masterPhoto and tostring(m.masterPhoto.localIdentifier) or "nil",
			tostring(photo:getFormattedMetadata("copyName")),
			tostring(m.path),
			formatTime(m.lastEditTime),
			tostring(m.editCount)
		)
	end
end

local function write(catalog, actionName, func)
	local status = catalog:withWriteAccessDo(actionName, func, { timeout = 10 })
	log("withWriteAccessDo(%q) -> %s", actionName, tostring(status))
end

local function collectionTest(catalog, photos)
	log("\n== Q1: does collection membership change lastEditTime? ==")
	local collection
	write(catalog, "Spike: create collection", function()
		collection = catalog:createCollection("Edit Time Spike", nil, true)
		collection:removeAllPhotos()
	end)
	LrTasks.sleep(2)
	describePhotos(catalog, "before add", photos)
	LrTasks.sleep(2)
	write(catalog, "Spike: add photos", function()
		collection:addPhotos(photos)
	end)
	LrTasks.sleep(2)
	describePhotos(catalog, "after add", photos)
	LrTasks.sleep(2)
	write(catalog, "Spike: remove photos", function()
		collection:removePhotos(photos)
	end)
	LrTasks.sleep(2)
	describePhotos(catalog, "after remove", photos)
end

local function sqlScript(ids)
	local idList = table.concat(ids, ",")
	return table.concat({
		".timeout 5000",
		".headers on",
		".mode csv",
		".timer on",
		"SELECT sqlite_version();",
		"PRAGMA table_info(Adobe_libraryImageDevelopHistoryStep);",
		"PRAGMA index_list(Adobe_libraryImageDevelopHistoryStep);",
		"PRAGMA table_info(Adobe_images);",
		"SELECT id_local, id_global, masterImage, copyName, touchTime, captureTime FROM Adobe_images WHERE id_local IN ("
			.. idList
			.. ");",
		"SELECT id_local, image, dateCreated, name, hasDevelopAdjustments FROM Adobe_libraryImageDevelopHistoryStep WHERE image IN ("
			.. idList
			.. ") ORDER BY image, dateCreated;",
		"SELECT name, COUNT(*) AS steps FROM Adobe_libraryImageDevelopHistoryStep GROUP BY name ORDER BY steps DESC LIMIT 60;",
		"SELECT COUNT(*) AS steps, MIN(dateCreated), MAX(dateCreated) FROM Adobe_libraryImageDevelopHistoryStep;",
		"SELECT COUNT(*) AS imagesWithHistory FROM (SELECT image, MAX(dateCreated) FROM Adobe_libraryImageDevelopHistoryStep GROUP BY image);",
		"SELECT COUNT(DISTINCT image) AS editedLast30Days FROM Adobe_libraryImageDevelopHistoryStep WHERE dateCreated > (SELECT MAX(dateCreated) FROM Adobe_libraryImageDevelopHistoryStep) - 86400 * 30;",
		"",
	}, "\n")
end

local function historyTest(catalog, photos)
	log("\n== Q2-Q4: Develop history via sqlite3 while Lightroom is open ==")
	if not LrFileUtils.exists(sqlitePath) then
		log("MISSING %s -- see spike/README.md", sqlitePath)
		return
	end
	local ids = {}
	for _, photo in ipairs(photos) do
		ids[#ids + 1] = tostring(photo.localIdentifier)
	end
	local sqlPath = LrPathUtils.child(tempDir, "edit-time-spike.sql")
	local outPath = LrPathUtils.child(tempDir, "edit-time-spike.out")
	local sqlFile = assert(io.open(sqlPath, "w"))
	sqlFile:write(sqlScript(ids))
	sqlFile:close()

	-- cmd.exe strips the outer pair of quotes, so the whole command is wrapped once more.
	local command = string.format(
		'""%s" -readonly "%s" < "%s" > "%s" 2>&1"',
		sqlitePath,
		catalog:getPath(),
		sqlPath,
		outPath
	)
	log("command: %s", command)
	log("LrDate.currentTime() before = %s, os.time() = %d", formatTime(LrDate.currentTime()), os.time())
	local started = LrDate.currentTime()
	local exitCode = LrTasks.execute(command)
	log("exit code %s after %.2f s", tostring(exitCode), LrDate.currentTime() - started)

	local outFile = io.open(outPath, "r")
	if outFile then
		log("---- sqlite3 output ----\n%s\n---- end ----", outFile:read("*a"))
		outFile:close()
	else
		log("no output file at %s", outPath)
	end
end

LrTasks.startAsyncTask(function()
	LrFunctionContext.callWithContext("Edit Time Spike", function(context)
		LrDialogs.attachErrorDialogToFunctionContext(context)
		logFile = assert(io.open(logPath, "w"))
		context:addCleanupHandler(function()
			logFile:close()
		end)

		local catalog = LrApplication.activeCatalog()
		log("Edit Time Spike run at %s", formatTime(LrDate.currentTime()))
		log("catalog: %s", catalog:getPath())

		log("\n== Q5: require from a subfolder ==")
		tryRequire("sub/Helper")
		tryRequire("sub.Helper")
		tryRequire("Helper")

		local photos = catalog:getTargetPhotos()
		log("\n%d selected photos", #photos)
		if #photos == 0 then
			LrDialogs.message("Edit Time Spike", "Select the photos listed in spike/README.md first.")
			return
		end
		describePhotos(catalog, "selected", photos)

		historyTest(catalog, photos)
		collectionTest(catalog, photos)

		log("\nDone.")
		LrDialogs.message("Edit Time Spike", "Done. Log written to:\n" .. logPath)
	end)
end)
