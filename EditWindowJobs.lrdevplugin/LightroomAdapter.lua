-- The composition root: the one place that imports the SDK modules the other
-- adapters receive, and the shared plumbing behind every menu command.

local LrApplication = import "LrApplication"
local LrDate = import "LrDate"
local LrDialogs = import "LrDialogs"
local LrFunctionContext = import "LrFunctionContext"
local LrLogger = import "LrLogger"
local LrPathUtils = import "LrPathUtils"
local LrProgressScope = import "LrProgressScope"
local LrTasks = import "LrTasks"

local CatalogAdapter = require "CatalogAdapter"
local HistoryAdapter = require "HistoryAdapter"
local JobsAdapter = require "JobsAdapter"
local RunReport = require "RunReport"
local Runner = require "Runner"

local LightroomAdapter = {}

LightroomAdapter.TITLE = "Edit Window Jobs"

-- Writes to EditWindowJobs.log in Lightroom's log folder
-- (%LOCALAPPDATA%\Adobe\Lightroom\Logs\LrClassicLogs on Windows).
local logger = LrLogger "EditWindowJobs"
logger:enable "logfile"

function LightroomAdapter.message(text, style)
	LrDialogs.message(LightroomAdapter.TITLE, text, style or "info")
end

-- Runs body(context, services) for a menu command inside an async task, with
-- Lightroom's error dialog attached so an unexpected error is shown, not lost.
-- services: { catalog = CatalogAdapter, history = HistoryAdapter, jobs = JobsAdapter }.
function LightroomAdapter.command(name, body)
	LrTasks.startAsyncTask(function()
		LrFunctionContext.callWithContext(name, function(context)
			LrDialogs.attachErrorDialogToFunctionContext(context)
			local catalog = LrApplication.activeCatalog()
			body(context, {
				catalog = CatalogAdapter.new({ catalog = catalog, pcall = LrTasks.pcall }),
				jobs = JobsAdapter.new({ catalog = catalog, plugin = _PLUGIN, pcall = LrTasks.pcall }),
				history = HistoryAdapter.new({
					execute = LrTasks.execute,
					sqlitePath = LrPathUtils.child(LrPathUtils.child(_PLUGIN.path, "bin"), "sqlite3.exe"),
					catalogPath = catalog:getPath(),
					tempDir = LrPathUtils.getStandardFilePath "temp",
					isWindows = WIN_ENV,
				}),
			})
		end)
	end)
end

-- Returns the saved Jobs, or shows why they could not be read and returns nil.
function LightroomAdapter.loadJobs(services)
	local jobs, message = services.jobs:load()
	if not jobs then
		logger:error(message)
		LightroomAdapter.message(message, "critical")
	end
	return jobs
end

function LightroomAdapter.saveJobs(services, jobs)
	local ok, message = services.jobs:save(jobs)
	if not ok then
		logger:error(message)
		LightroomAdapter.message(message, "critical")
	end
	return ok
end

local function localMidnight(year, month, day)
	return LrDate.timeFromComponents(year, month, day, 0, 0, 0, "local")
end

-- Seconds a Run's toast stays up; a failure stays longer so it can be read.
local TOAST_SECONDS = 3
local FAILURE_TOAST_SECONDS = 8

-- Runs the Jobs under a cancellable progress bar, then logs the summary and
-- shows it as a toast, which needs no click to dismiss.
function LightroomAdapter.runJobs(context, services, jobs)
	local scope = LrProgressScope({ title = LightroomAdapter.TITLE, functionContext = context })
	local results = Runner.runAll(jobs, {
		now = LrDate.currentTime(),
		localMidnight = localMidnight,
		catalog = services.catalog,
		history = services.history,
		progress = {
			setCaption = function(_, text)
				scope:setCaption(text)
			end,
			isCanceled = function()
				return scope:isCanceled()
			end,
			setPortionComplete = function(_, done, total)
				scope:setPortionComplete(done, total)
			end,
		},
	})
	scope:done()
	logger:info(RunReport.format(results, #jobs))
	LrDialogs.showBezel(
		RunReport.toast(results, #jobs),
		RunReport.hasFailures(results) and FAILURE_TOAST_SECONDS or TOAST_SECONDS
	)
end

return LightroomAdapter
