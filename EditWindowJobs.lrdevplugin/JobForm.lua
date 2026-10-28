-- The Job editor's state as plain values: what the fields hold, what each list
-- offers, and the Job they add up to. JobEditorDialog.lua only lays it out.
-- entries: CollectionPaths.flatten output, { id, kind, path }.

local CollectionPaths = require "CollectionPaths"

local JobForm = {}

local function trim(text)
	return string.match(text or "", "^%s*(.-)%s*$")
end

local function contains(list, value)
	for _, item in ipairs(list) do
		if item == value then
			return true
		end
	end
	return false
end

local function entryById(entries, id)
	for _, entry in ipairs(entries) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

local function pathOf(entries, id)
	local entry = entryById(entries, id)
	return entry and entry.path or string.format("Missing collection (%s)", tostring(id))
end

local function title(entry)
	return entry.kind == "smart" and (entry.path .. " (smart)") or entry.path
end

-- Returns the field values for editing job, or for a new Job when job is nil.
function JobForm.fields(job)
	local window = job and job.window or { kind = "relative", amount = 7, unit = "days" }
	local sourceIds = {}
	for _, source in ipairs(job and job.sources or {}) do
		sourceIds[#sourceIds + 1] = source.id
	end
	return {
		name = job and job.name or "",
		sourceIds = sourceIds,
		targetId = job and job.target and job.target.id or nil,
		newTargetName = "",
		kind = window.kind,
		amount = tostring(window.amount or 7),
		unit = window.unit or "days",
		startDate = window.startDate or "",
		endDate = window.endDate or "",
		includeCreated = job and job.includeCreated == true or false,
	}
end

-- Items { title, value = id } for the collections matching filterText that are
-- not already sources.
function JobForm.sourceChoices(entries, filterText, chosenIds)
	local items = {}
	for _, entry in ipairs(CollectionPaths.filter(entries, filterText)) do
		if not contains(chosenIds, entry.id) then
			items[#items + 1] = { title = title(entry), value = entry.id }
		end
	end
	return items
end

function JobForm.chosenSources(entries, chosenIds)
	local items = {}
	for _, id in ipairs(chosenIds) do
		local entry = entryById(entries, id)
		items[#items + 1] = { title = entry and title(entry) or pathOf(entries, id), value = id }
	end
	return items
end

-- Items for the regular collections matching filterText, plus the current
-- target so the popup can still show it.
function JobForm.targetChoices(entries, filterText, currentId)
	local items = {}
	for _, entry in ipairs(entries) do
		if entry.kind == "collection" then
			local shown = entry.id == currentId or #CollectionPaths.filter({ entry }, filterText) == 1
			if shown then
				items[#items + 1] = { title = entry.path, value = entry.id }
			end
		end
	end
	return items
end

function JobForm.addSources(chosenIds, ids)
	local result = { unpack(chosenIds) }
	for _, id in ipairs(ids) do
		if not contains(result, id) then
			result[#result + 1] = id
		end
	end
	return result
end

function JobForm.removeSources(chosenIds, ids)
	local result = {}
	for _, id in ipairs(chosenIds) do
		if not contains(ids, id) then
			result[#result + 1] = id
		end
	end
	return result
end

-- Returns the Job the fields describe, or nil and a message. When a new target
-- name is typed, target is { newName, path } for the caller to create before saving.
-- Everything else is checked by Jobs.validate.
function JobForm.toJob(fields, entries, id)
	local window
	if fields.kind == "relative" then
		local amount = tonumber(trim(fields.amount))
		if not amount then
			return nil, "The window's length must be a whole number of at least 1."
		end
		window = { kind = "relative", amount = amount, unit = fields.unit }
	else
		window = { kind = "fixed", startDate = trim(fields.startDate), endDate = trim(fields.endDate) }
	end

	local sources = {}
	for _, sourceId in ipairs(fields.sourceIds) do
		sources[#sources + 1] = { id = sourceId, path = pathOf(entries, sourceId) }
	end

	local target
	local newName = trim(fields.newTargetName)
	if newName ~= "" then
		target = { newName = newName, path = newName }
	elseif fields.targetId ~= nil then
		target = { id = fields.targetId, path = pathOf(entries, fields.targetId) }
	end

	return {
		id = id,
		name = trim(fields.name),
		sources = sources,
		target = target,
		window = window,
		includeCreated = fields.includeCreated == true,
	}
end

return JobForm
