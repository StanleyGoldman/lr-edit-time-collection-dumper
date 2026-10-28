-- Carries out Runs through injected adapters, so the whole flow is testable
-- without Lightroom.
--
-- deps.now: the Run's moment in Cocoa seconds.
-- deps.localMidnight(year, month, day): local midnight in Cocoa seconds.
-- deps.catalog: collection(id) -> handle or nil; isSmart(handle);
--   photoIds(handle) -> ids; apply(target, plan, actionName) -> true or nil, message.
-- deps.history: editedImageIds(startTime, endTime, includeCreated) -> set or nil, message.
-- deps.progress: setCaption(text); isCanceled(); setPortionComplete(done, total).
--
-- A result is { jobName, added, removed, kept }, { jobName, error } or
-- { jobName, canceled = true }. A failed or canceled Run writes nothing.

local EditWindow = require "EditWindow"
local RunPlan = require "RunPlan"

local Runner = {}

local function failure(job, message)
	return { jobName = job.name, error = message }
end

function Runner.run(job, deps)
	local catalog, progress = deps.catalog, deps.progress

	-- On failure resolve returns nil and the message, which lands in endTime.
	local startTime, endTime = EditWindow.resolve(job.window, deps.now, deps.localMidnight)
	if not startTime then
		return failure(job, endTime)
	end

	progress:setCaption(job.name .. ": reading collections")
	local target = catalog:collection(job.target.id)
	if not target then
		return failure(job, string.format('The Target Collection "%s" no longer exists.', job.target.path))
	end
	if catalog:isSmart(target) then
		return failure(
			job,
			string.format('"%s" is a smart collection and cannot be a Target Collection.', job.target.path)
		)
	end
	local sourceIds = {}
	for _, source in ipairs(job.sources) do
		local collection = catalog:collection(source.id)
		if not collection then
			return failure(job, string.format('The Source Collection "%s" no longer exists.', source.path))
		end
		for _, id in ipairs(catalog:photoIds(collection)) do
			sourceIds[#sourceIds + 1] = id
		end
	end
	local targetIds = catalog:photoIds(target)
	if progress:isCanceled() then
		return { jobName = job.name, canceled = true }
	end

	progress:setCaption(job.name .. ": reading Develop history")
	local editedIds, historyMessage = deps.history:editedImageIds(startTime, endTime, job.includeCreated == true)
	if not editedIds then
		return failure(job, historyMessage)
	end
	if progress:isCanceled() then
		return { jobName = job.name, canceled = true }
	end

	local plan = RunPlan.build({ sourceIds = sourceIds, editedIds = editedIds, targetIds = targetIds })
	if plan.changes then
		progress:setCaption(job.name .. ": updating " .. job.target.path)
		local ok, applyMessage = catalog:apply(target, plan, "Run Job: " .. job.name)
		if not ok then
			return failure(job, applyMessage)
		end
	end
	return { jobName = job.name, added = #plan.add, removed = #plan.remove, kept = #plan.keep }
end

-- Runs the Jobs in order, continuing past failures and stopping at a cancel.
-- Also calls deps.progress:setPortionComplete(done, total) between Jobs.
function Runner.runAll(jobs, deps)
	local results = {}
	for index, job in ipairs(jobs) do
		deps.progress:setPortionComplete(index - 1, #jobs)
		local result = Runner.run(job, deps)
		results[#results + 1] = result
		if result.canceled then
			return results
		end
	end
	deps.progress:setPortionComplete(#jobs, #jobs)
	return results
end

return Runner
