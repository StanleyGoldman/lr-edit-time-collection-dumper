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

describe("RunReport.toast", function()
	it("gives a single Job's summary as is", function()
		local results = { { jobName = "This week", added = 0, removed = 0, kept = 7 } }
		assert.are.equal('"This week": already up to date (7 photos).', RunReport.toast(results, 1))
	end)

	it("counts each outcome of several Jobs and points to the log", function()
		local results = {
			{ jobName = "A", added = 1, removed = 0, kept = 0 },
			{ jobName = "B", added = 0, removed = 2, kept = 3 },
			{ jobName = "C", added = 0, removed = 0, kept = 5 },
			{ jobName = "D", error = "x" },
			{ jobName = "E", canceled = true },
		}
		assert.are.equal(
			"6 Jobs: 2 updated, 1 up to date, 1 failed, 1 canceled, 1 not run. Details are in the log.",
			RunReport.toast(results, 6)
		)
	end)

	it("leaves out outcomes that did not happen", function()
		local results = {
			{ jobName = "A", added = 0, removed = 0, kept = 1 },
			{ jobName = "B", added = 0, removed = 0, kept = 2 },
		}
		assert.are.equal("2 Jobs: 2 up to date. Details are in the log.", RunReport.toast(results, 2))
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
