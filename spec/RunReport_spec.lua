local RunReport = require "RunReport"

describe("RunReport.format", function()
	it("describes the changes a Run made", function()
		assert.are.equal(
			'"This week": added 3, removed 2, kept 7.',
			RunReport.format({ { jobName = "This week", added = 3, removed = 2, kept = 7 } }, 1)
		)
	end)

	it("says when a Target Collection was already up to date", function()
		assert.are.equal(
			'"This week": already up to date (7 photos).',
			RunReport.format({ { jobName = "This week", added = 0, removed = 0, kept = 7 } }, 1)
		)
	end)

	it("reports a failure with its message", function()
		assert.are.equal(
			'"Broken" failed: The Target Collection "Gone" no longer exists.',
			RunReport.format({ { jobName = "Broken", error = 'The Target Collection "Gone" no longer exists.' } }, 1)
		)
	end)

	it("reports a cancel and the Jobs that never ran", function()
		assert.are.equal(
			'"A": added 1, removed 0, kept 0.\n'
				.. '"B" was canceled; its Target Collection is unchanged.\n'
				.. "2 more Jobs were not run.",
			RunReport.format({
				{ jobName = "A", added = 1, removed = 0, kept = 0 },
				{ jobName = "B", canceled = true },
			}, 4)
		)
	end)

	it("uses the singular for one Job not run", function()
		local text = RunReport.format({ { jobName = "B", canceled = true } }, 2)
		assert.matches("1 more Job was not run.", text, 1, true)
	end)
end)

describe("RunReport.hasFailures", function()
	it("is true when any Run failed", function()
		local results = {
			{ jobName = "A", added = 0, removed = 0, kept = 0 },
			{ jobName = "B", error = "x" },
		}
		assert.is_true(RunReport.hasFailures(results))
		assert.is_false(RunReport.hasFailures({ { jobName = "A", canceled = true } }))
	end)
end)
