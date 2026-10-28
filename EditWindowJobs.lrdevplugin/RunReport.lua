-- Turns Runner results into the text of the summary shown after a Run.

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

function RunReport.hasFailures(results)
	for _, result in ipairs(results) do
		if result.error then
			return true
		end
	end
	return false
end

return RunReport
