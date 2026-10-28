-- Turns Runner results into the text logged and shown after a Run.

local RunReport = {}

local function describe(result)
	if result.error then
		return string.format('"%s" failed: %s', result.jobName, result.error)
	elseif result.canceled then
		return string.format('"%s" was canceled; its Target Collection is unchanged.', result.jobName)
	elseif result.added == 0 and result.removed == 0 then
		return string.format('"%s": already up to date (%d photos).', result.jobName, result.kept)
	end
	return string.format(
		'"%s": added %d, removed %d, kept %d.',
		result.jobName,
		result.added,
		result.removed,
		result.kept
	)
end

-- results: from Runner.run or Runner.runAll. jobCount: how many Jobs were asked
-- to run, so a cancel can say how many never started.
function RunReport.format(results, jobCount)
	local lines = {}
	for _, result in ipairs(results) do
		lines[#lines + 1] = describe(result)
	end
	local notRun = jobCount - #results
	if notRun == 1 then
		lines[#lines + 1] = "1 more Job was not run."
	elseif notRun > 1 then
		lines[#lines + 1] = string.format("%d more Jobs were not run.", notRun)
	end
	return table.concat(lines, "\n")
end

-- One line for the toast after a Run: a single Job's summary, or for several
-- Jobs a count per outcome, since format's full text goes to the log.
function RunReport.toast(results, jobCount)
	if jobCount == 1 and #results == 1 then
		return describe(results[1])
	end
	local counts = { updated = 0, upToDate = 0, failed = 0, canceled = 0 }
	for _, result in ipairs(results) do
		if result.error then
			counts.failed = counts.failed + 1
		elseif result.canceled then
			counts.canceled = counts.canceled + 1
		elseif result.added == 0 and result.removed == 0 then
			counts.upToDate = counts.upToDate + 1
		else
			counts.updated = counts.updated + 1
		end
	end
	local parts = {}
	local function add(count, label)
		if count > 0 then
			parts[#parts + 1] = string.format("%d %s", count, label)
		end
	end
	add(counts.updated, "updated")
	add(counts.upToDate, "up to date")
	add(counts.failed, "failed")
	add(counts.canceled, "canceled")
	add(jobCount - #results, "not run")
	return string.format("%d Jobs: %s. Details are in the log.", jobCount, table.concat(parts, ", "))
end

function RunReport.hasFailures(results)
	for _, result in ipairs(results) do
		if result.error then
			return true
		end
	end
	return false
end

return RunReport
