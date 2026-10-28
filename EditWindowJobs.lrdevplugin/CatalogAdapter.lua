-- The plugin's only access to collections and photos in the Lightroom catalog.
-- Satisfies the deps.catalog interface in Runner.lua.

local CatalogAdapter = {}
CatalogAdapter.__index = CatalogAdapter

local WRITE_TIMEOUT_SECONDS = 30

-- args.catalog: LrApplication.activeCatalog(). args.pcall: LrTasks.pcall, which
-- can catch errors from SDK calls that yield.
function CatalogAdapter.new(args)
	return setmetatable({ catalog = args.catalog, pcall = args.pcall, photosById = {} }, CatalogAdapter)
end

local function isCollection(source)
	return type(source) == "table" and type(source.type) == "function" and source:type() == "LrCollection"
end

local function treeNodes(parent)
	local nodes = {}
	for _, collection in ipairs(parent:getChildCollections()) do
		nodes[#nodes + 1] = {
			kind = collection:isSmartCollection() and "smart" or "collection",
			name = collection:getName(),
			id = collection.localIdentifier,
		}
	end
	for _, set in ipairs(parent:getChildCollectionSets()) do
		nodes[#nodes + 1] = { kind = "set", name = set:getName(), children = treeNodes(set) }
	end
	return nodes
end

-- Returns the collections and sets as CollectionPaths.flatten expects them.
function CatalogAdapter:collectionTree()
	return treeNodes(self.catalog)
end

-- Returns the ids of the collections selected in Lightroom's Collections panel.
function CatalogAdapter:selectedCollectionIds()
	local ids = {}
	for _, source in ipairs(self.catalog:getActiveSources()) do
		if isCollection(source) then
			ids[#ids + 1] = source.localIdentifier
		end
	end
	return ids
end

function CatalogAdapter:collection(id)
	local found = self.catalog:getCollectionByLocalIdentifier(id)
	if isCollection(found) then
		return found
	end
	return nil
end

function CatalogAdapter:isSmart(collection)
	return collection:isSmartCollection()
end

-- Returns the ids of the collection's photos and remembers the photos, so a
-- later apply can hand them back to the SDK.
function CatalogAdapter:photoIds(collection)
	local ids = {}
	for _, photo in ipairs(collection:getPhotos()) do
		self.photosById[photo.localIdentifier] = photo
		ids[#ids + 1] = photo.localIdentifier
	end
	return ids
end

function CatalogAdapter:write(actionName, func)
	local ok, status = self.pcall(function()
		return self.catalog:withWriteAccessDo(actionName, func, { timeout = WRITE_TIMEOUT_SECONDS })
	end)
	if not ok then
		return nil, string.format("%s failed and made no changes: %s", actionName, tostring(status))
	end
	if status ~= "executed" then
		return nil, string.format("The catalog stayed busy, so %s made no changes. Try again.", actionName)
	end
	return true
end

-- Applies a RunPlan's add and remove lists to target as one undoable step.
-- Every id must have come through photoIds first.
function CatalogAdapter:apply(target, plan, actionName)
	local function photos(ids)
		local list = {}
		for _, id in ipairs(ids) do
			list[#list + 1] = self.photosById[id]
		end
		return list
	end
	local add, remove = photos(plan.add), photos(plan.remove)
	return self:write(actionName, function()
		if #add > 0 then
			target:addPhotos(add)
		end
		if #remove > 0 then
			target:removePhotos(remove)
		end
	end)
end

-- Creates a regular collection at the top level (or returns the existing one
-- with that name) and returns its { id, kind, path }, or nil and a message.
function CatalogAdapter:createCollection(name)
	local created
	local ok, message = self:write("Create Collection: " .. name, function()
		created = self.catalog:createCollection(name, nil, true)
	end)
	if not ok then
		return nil, message
	end
	return { id = created.localIdentifier, kind = "collection", path = name }
end

return CatalogAdapter
