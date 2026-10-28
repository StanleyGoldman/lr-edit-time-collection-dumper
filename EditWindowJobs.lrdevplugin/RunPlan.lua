-- Decides what one Run changes in its Target Collection.

local RunPlan = {}

local function sortedKeys(set)
	local list = {}
	for id in pairs(set) do
		list[#list + 1] = id
	end
	table.sort(list)
	return list
end

-- args.sourceIds: ids of every photo in the Source Collections (repeats allowed).
-- args.editedIds: set ({ [id] = true }) of photos with an Edit in the Edit Window.
-- args.targetIds: ids of the photos now in the Target Collection.
-- Returns { add, remove, keep } as sorted id lists, and changes = whether
-- add or remove is non-empty.
function RunPlan.build(args)
	local qualifying = {}
	for _, id in ipairs(args.sourceIds) do
		if args.editedIds[id] then
			qualifying[id] = true
		end
	end

	local add, remove, keep = {}, {}, {}
	local inTarget = {}
	for _, id in ipairs(args.targetIds) do
		inTarget[id] = true
		if qualifying[id] then
			keep[id] = true
		else
			remove[id] = true
		end
	end
	for id in pairs(qualifying) do
		if not inTarget[id] then
			add[id] = true
		end
	end

	local plan = { add = sortedKeys(add), remove = sortedKeys(remove), keep = sortedKeys(keep) }
	plan.changes = #plan.add > 0 or #plan.remove > 0
	return plan
end

return RunPlan
