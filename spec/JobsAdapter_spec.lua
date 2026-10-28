local JobsAdapter = require "JobsAdapter"
local Jobs = require "Jobs"

local PLUGIN = { id = "com.stanleygoldman.editwindowjobs" }

local function fakeCatalog(stored, status)
	local catalog = { properties = { jobs = stored }, privateWrites = 0 }
	function catalog:getPropertyForPlugin(plugin, key)
		assert(plugin == PLUGIN)
		return self.properties[key]
	end
	function catalog:setPropertyForPlugin(plugin, key, value)
		assert(plugin == PLUGIN)
		self.properties[key] = value
	end
	function catalog:withPrivateWriteAccessDo(func, timeoutParams)
		assert(timeoutParams and timeoutParams.timeout)
		self.privateWrites = self.privateWrites + 1
		if (status or "executed") == "executed" then
			func()
		end
		return status or "executed"
	end
	return catalog
end

local job = {
	id = "job-1",
	name = "This week",
	sources = { { id = 11, path = "October" } },
	target = { id = 20, path = "Edited" },
	window = { kind = "relative", amount = 7, unit = "days" },
}

describe("JobsAdapter", function()
	it("loads no Jobs from a catalog that has none", function()
		local adapter = JobsAdapter.new({ catalog = fakeCatalog(nil), plugin = PLUGIN, pcall = pcall })
		assert.are.same({}, adapter:load())
	end)

	it("saves Jobs outside the undo history and loads them back", function()
		local catalog = fakeCatalog(nil)
		local adapter = JobsAdapter.new({ catalog = catalog, plugin = PLUGIN, pcall = pcall })
		assert.is_true(adapter:save({ job }))
		assert.are.equal(1, catalog.privateWrites)
		assert.are.equal(Jobs.encode({ job }), catalog.properties.jobs)
		assert.are.same({ job }, adapter:load())
	end)

	it("reports stored text it cannot read", function()
		local adapter = JobsAdapter.new({ catalog = fakeCatalog "garbage", plugin = PLUGIN, pcall = pcall })
		local jobs, message = adapter:load()
		assert.is_nil(jobs)
		assert.matches("saved Jobs", message, 1, true)
	end)

	it("reports a save that did not happen", function()
		local adapter = JobsAdapter.new({ catalog = fakeCatalog(nil, "aborted"), plugin = PLUGIN, pcall = pcall })
		local ok, message = adapter:save({ job })
		assert.is_nil(ok)
		assert.matches("not saved", message, 1, true)
	end)
end)
