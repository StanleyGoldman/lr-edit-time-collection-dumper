-- Checks Jobs and converts the list of Jobs to and from the text stored in the
-- catalog. A Job is { id, name, sources = { { id, path } }, target = { id, path },
-- window, includeCreated }, where ids are collection localIdentifiers and paths are
-- for messages. includeCreated (absent in Jobs saved before it existed) also
-- qualifies photos imported or virtual copies made in the Edit Window.

local EditWindow = require "EditWindow"
local Json = require "Json"

local Jobs = {}

local FORMAT_VERSION = 1

local function trim(text)
	return string.match(text or "", "^%s*(.-)%s*$")
end

-- Returns true, or nil and a message for the user. others: the other saved Jobs
-- (the Job itself may be among them; it is matched by id and skipped).
function Jobs.validate(job, others)
	if trim(job.name) == "" then
		return nil, "The Job needs a name."
	end
	if not job.sources or #job.sources == 0 then
		return nil, string.format('"%s" needs at least one Source Collection.', job.name)
	end
	if not job.target then
		return nil, string.format('"%s" needs a Target Collection.', job.name)
	end
	for _, source in ipairs(job.sources) do
		if source.id == job.target.id then
			return nil, string.format('"%s" cannot be both a Source and the Target Collection.', source.path)
		end
	end
	for _, other in ipairs(others) do
		if other.id ~= job.id then
			if other.target and other.target.id == job.target.id then
				return nil, string.format('"%s" is already the Target Collection of "%s".', job.target.path, other.name)
			end
			if string.lower(trim(other.name)) == string.lower(trim(job.name)) then
				return nil, string.format('A Job called "%s" already exists.', trim(job.name))
			end
		end
	end
	local ok, message = EditWindow.validate(job.window)
	if not ok then
		return nil, string.format('"%s": %s', job.name, message)
	end
	return true
end

function Jobs.encode(jobs)
	return Json.encode({ version = FORMAT_VERSION, jobs = jobs })
end

-- Returns the list of Jobs, or nil and a message. Nothing stored yet (nil) is
-- an empty list.
function Jobs.decode(text)
	if text == nil then
		return {}
	end
	local stored, message = Json.decode(text)
	if not stored then
		return nil, "The saved Jobs could not be read: " .. message
	end
	if type(stored) ~= "table" or stored.version ~= FORMAT_VERSION or type(stored.jobs) ~= "table" then
		return nil, "The saved Jobs are in a format this version of the plugin does not know."
	end
	return stored.jobs
end

function Jobs.newId(jobs)
	local highest = 0
	for _, job in ipairs(jobs) do
		local number = tonumber(string.match(job.id or "", "^job%-(%d+)$"))
		if number and number > highest then
			highest = number
		end
	end
	return "job-" .. (highest + 1)
end

return Jobs
