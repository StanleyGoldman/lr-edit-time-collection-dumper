-- Keeps the saved Jobs in the catalog as a plugin property, so they travel with
-- the catalog and its backups.

local Jobs = require "Jobs"

local JobsAdapter = {}
JobsAdapter.__index = JobsAdapter

local PROPERTY = "jobs"
local WRITE_TIMEOUT_SECONDS = 10

-- args.catalog: LrApplication.activeCatalog(). args.plugin: _PLUGIN.
-- args.pcall: LrTasks.pcall.
function JobsAdapter.new(args)
	return setmetatable({ catalog = args.catalog, plugin = args.plugin, pcall = args.pcall }, JobsAdapter)
end

-- Returns the list of Jobs, or nil and a message.
function JobsAdapter:load()
	return Jobs.decode(self.catalog:getPropertyForPlugin(self.plugin, PROPERTY))
end

-- Returns true, or nil and a message. Private write access keeps saving off the
-- undo history, so undo reverts only Runs.
function JobsAdapter:save(jobs)
	local text = Jobs.encode(jobs)
	local ok, status = self.pcall(function()
		return self.catalog:withPrivateWriteAccessDo(function()
			self.catalog:setPropertyForPlugin(self.plugin, PROPERTY, text)
		end, { timeout = WRITE_TIMEOUT_SECONDS })
	end)
	if not ok then
		return nil, "The Jobs were not saved: " .. tostring(status)
	end
	if status ~= "executed" then
		return nil, "The catalog stayed busy, so the Jobs were not saved. Try again."
	end
	return true
end

return JobsAdapter
