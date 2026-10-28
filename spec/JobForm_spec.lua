local JobForm = require "JobForm"

local entries = {
	{ id = 14, kind = "collection", path = "Archive" },
	{ id = 12, kind = "smart", path = "Family › 2026 › Edited lately" },
	{ id = 11, kind = "collection", path = "Family › 2026 › October" },
	{ id = 13, kind = "collection", path = "Family › best of" },
}

local function titles(items)
	local result = {}
	for index, item in ipairs(items) do
		result[index] = item.title
	end
	return result
end

describe("JobForm.fields", function()
	it("starts a new Job as the last 7 days", function()
		local fields = JobForm.fields(nil)
		assert.are.same({
			name = "",
			sourceIds = {},
			targetId = nil,
			newTargetName = "",
			kind = "relative",
			amount = "7",
			unit = "days",
			startDate = "",
			endDate = "",
		}, fields)
	end)

	it("fills the fields from a saved Job", function()
		local fields = JobForm.fields({
			id = "job-3",
			name = "October",
			sources = { { id = 11, path = "x" } },
			target = { id = 13, path = "y" },
			window = { kind = "fixed", startDate = "2026-10-01", endDate = "2026-10-31" },
		})
		assert.are.same({ 11 }, fields.sourceIds)
		assert.are.equal(13, fields.targetId)
		assert.are.equal("fixed", fields.kind)
		assert.are.equal("2026-10-01", fields.startDate)
		assert.are.equal("7", fields.amount)
	end)
end)

describe("JobForm choices", function()
	it("offers matching collections not already chosen as sources, marking smart ones", function()
		local items = JobForm.sourceChoices(entries, "family", { 13 })
		assert.are.same({ "Family › 2026 › Edited lately (smart)", "Family › 2026 › October" }, titles(items))
		assert.are.same({ 12, 11 }, { items[1].value, items[2].value })
	end)

	it("lists the chosen sources by path, keeping ids that no longer exist visible", function()
		local items = JobForm.chosenSources(entries, { 11, 404 })
		assert.are.same({ "Family › 2026 › October", "Missing collection (404)" }, titles(items))
	end)

	it("offers only regular collections as targets", function()
		assert.are.same(
			{ "Archive", "Family › 2026 › October", "Family › best of" },
			titles(JobForm.targetChoices(entries, "", nil))
		)
	end)

	it("keeps the current target in the list even when the filter hides it", function()
		assert.are.same({ "Archive", "Family › best of" }, titles(JobForm.targetChoices(entries, "best", 14)))
	end)

	it("adds sources once and removes them", function()
		assert.are.same({ 11, 12 }, JobForm.addSources({ 11 }, { 12, 11 }))
		assert.are.same({ 12 }, JobForm.removeSources({ 11, 12 }, { 11 }))
	end)
end)

describe("JobForm.toJob", function()
	local function fields(overrides)
		local result = {
			name = " This week ",
			sourceIds = { 11, 12 },
			targetId = 13,
			newTargetName = "",
			kind = "relative",
			amount = "7",
			unit = "days",
			startDate = "",
			endDate = "",
		}
		for key, value in pairs(overrides or {}) do
			result[key] = value
		end
		return result
	end

	it("builds a Job with paths for messages", function()
		local job = JobForm.toJob(fields(), entries, "job-1")
		assert.are.same({
			id = "job-1",
			name = "This week",
			sources = {
				{ id = 11, path = "Family › 2026 › October" },
				{ id = 12, path = "Family › 2026 › Edited lately" },
			},
			target = { id = 13, path = "Family › best of" },
			window = { kind = "relative", amount = 7, unit = "days" },
		}, job)
	end)

	it("builds a fixed window from the date fields", function()
		local job = JobForm.toJob(
			fields({ kind = "fixed", startDate = " 2026-10-01", endDate = "2026-10-31 " }),
			entries,
			"job-1"
		)
		assert.are.same({ kind = "fixed", startDate = "2026-10-01", endDate = "2026-10-31" }, job.window)
	end)

	it("asks for a new Target Collection by name when one is typed", function()
		local job = JobForm.toJob(fields({ targetId = 13, newTargetName = " Edited this week " }), entries, "job-1")
		assert.are.same({ newName = "Edited this week", path = "Edited this week" }, job.target)
	end)

	it("rejects an amount that is not a number", function()
		local job, message = JobForm.toJob(fields({ amount = "seven" }), entries, "job-1")
		assert.is_nil(job)
		assert.matches("whole number", message, 1, true)
	end)

	it("leaves a missing target for Jobs.validate to report", function()
		local noTarget = fields()
		noTarget.targetId = nil
		local job = JobForm.toJob(noTarget, entries, "job-1")
		assert.is_nil(job.target)
	end)
end)
