local Runner = require "Runner"

local function set(list)
	local result = {}
	for _, id in ipairs(list) do
		result[id] = true
	end
	return result
end

-- A catalog fake: collections by id, each { smart = bool, photos = { ids } }.
local function fakeCatalog(collections)
	local catalog = { applied = {} }
	function catalog:collection(id)
		return collections[id] and id or nil
	end
	function catalog:isSmart(handle)
		return collections[handle].smart == true
	end
	function catalog:photoIds(handle)
		return collections[handle].photos
	end
	function catalog:apply(target, plan, actionName)
		if self.applyError then
			return nil, self.applyError
		end
		self.applied[#self.applied + 1] = { target = target, plan = plan, actionName = actionName }
		return true
	end
	return catalog
end

local function fakeHistory(editedIds)
	local history = { calls = {} }
	function history:editedImageIds(startTime, endTime, includeCreated)
		self.calls[#self.calls + 1] = { startTime = startTime, endTime = endTime, includeCreated = includeCreated }
		if self.error then
			return nil, self.error
		end
		return set(editedIds)
	end
	return history
end

local function fakeProgress()
	local progress = { captions = {}, cancelAfter = nil }
	function progress:setCaption(text)
		self.captions[#self.captions + 1] = text
	end
	function progress:setPortionComplete(done, total)
		self.portions = self.portions or {}
		self.portions[#self.portions + 1] = done .. "/" .. total
	end
	function progress:isCanceled()
		return self.cancelAfter ~= nil and #self.captions >= self.cancelAfter
	end
	return progress
end

local NOW = 1000000

local function job(overrides)
	local result = {
		id = "job-1",
		name = "This week",
		sources = { { id = 1, path = "Family" }, { id = 2, path = "Smart" } },
		target = { id = 9, path = "Edited" },
		window = { kind = "relative", amount = 2, unit = "hours" },
	}
	for key, value in pairs(overrides or {}) do
		result[key] = value
	end
	return result
end

local function deps(overrides)
	local result = {
		now = NOW,
		localMidnight = function()
			error "not used by relative windows"
		end,
		catalog = fakeCatalog({
			[1] = { photos = { 10, 11, 12 } },
			[2] = { smart = true, photos = { 12, 13 } },
			[9] = { photos = { 11, 50 } },
		}),
		history = fakeHistory({ 10, 12, 13, 99 }),
		progress = fakeProgress(),
	}
	for key, value in pairs(overrides or {}) do
		result[key] = value
	end
	return result
end

describe("Runner.run", function()
	it("brings the Target Collection up to date and reports the counts", function()
		local d = deps()
		local result = Runner.run(job(), d)

		assert.are.same({ jobName = "This week", added = 3, removed = 2, kept = 0 }, result)
		assert.are.same({ { startTime = NOW - 2 * 3600, endTime = nil, includeCreated = false } }, d.history.calls)
		local applied = d.catalog.applied[1]
		assert.are.equal(9, applied.target)
		assert.are.same({ 10, 12, 13 }, applied.plan.add)
		assert.are.same({ 11, 50 }, applied.plan.remove)
		assert.are.equal("Run Job: This week", applied.actionName)
	end)

	it("asks the history for created photos when the Job includes them", function()
		local d = deps()
		Runner.run(job({ includeCreated = true }), d)
		assert.is_true(d.history.calls[1].includeCreated)
	end)

	it("skips the write when nothing changes", function()
		local d = deps({ history = fakeHistory({ 11 }) })
		d.catalog = fakeCatalog({ [1] = { photos = { 11 } }, [2] = { photos = {} }, [9] = { photos = { 11 } } })
		local result = Runner.run(job(), d)
		assert.are.same({ jobName = "This week", added = 0, removed = 0, kept = 1 }, result)
		assert.are.same({}, d.catalog.applied)
	end)

	local function failsWith(description, setup, expected)
		it("fails and leaves the target untouched when " .. description, function()
			local j, d = job(), deps()
			setup(j, d)
			local result = Runner.run(j, d)
			assert.are.equal("This week", result.jobName)
			assert.matches(expected, result.error, 1, true)
			assert.are.same({}, d.catalog.applied)
		end)
	end

	failsWith("the window is invalid", function(j)
		j.window = { kind = "relative", amount = 0, unit = "days" }
	end, "whole number")
	failsWith("the Target Collection is gone", function(_, d)
		d.catalog = fakeCatalog({ [1] = { photos = {} }, [2] = { photos = {} } })
	end, 'The Target Collection "Edited" no longer exists')
	failsWith("the Target Collection became a smart collection", function(_, d)
		d.catalog = fakeCatalog({ [1] = { photos = {} }, [2] = { photos = {} }, [9] = { smart = true, photos = {} } })
	end, '"Edited" is a smart collection')
	failsWith("a Source Collection is gone", function(_, d)
		d.catalog = fakeCatalog({ [1] = { photos = {} }, [9] = { photos = {} } })
	end, 'The Source Collection "Smart" no longer exists')
	failsWith("the history cannot be read", function(_, d)
		d.history.error = "sqlite3 printed: Error: no such table"
	end, "no such table")

	it("reports a failed write", function()
		local d = deps()
		d.catalog.applyError = "The catalog was busy."
		local result = Runner.run(job(), d)
		assert.are.equal("The catalog was busy.", result.error)
	end)

	it("stops before writing when canceled", function()
		local d = deps()
		d.progress.cancelAfter = 1
		local result = Runner.run(job(), d)
		assert.are.same({ jobName = "This week", canceled = true }, result)
		assert.are.same({}, d.catalog.applied)
	end)
end)

describe("Runner.runAll", function()
	it("runs every Job and keeps going after a failure", function()
		local d = deps()
		local broken = job({ id = "job-2", name = "Broken", target = { id = 404, path = "Gone" } })
		local results = Runner.runAll({ broken, job() }, d)
		assert.are.equal(2, #results)
		assert.is_string(results[1].error)
		assert.are.equal(3, results[2].added)
	end)

	it("moves the progress bar from Job to Job", function()
		local d = deps()
		Runner.runAll({ job(), job({ id = "job-2", name = "Other", target = { id = 404, path = "Gone" } }) }, d)
		assert.are.same({ "0/2", "1/2", "2/2" }, d.progress.portions)
	end)

	it("stops at the first canceled Job", function()
		local d = deps()
		d.progress.cancelAfter = 1
		local results = Runner.runAll({ job(), job({ id = "job-2", name = "Other" }) }, d)
		assert.are.same({ { jobName = "This week", canceled = true } }, results)
	end)
end)
