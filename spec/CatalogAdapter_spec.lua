local CatalogAdapter = require "CatalogAdapter"

-- Minimal stand-ins for LrPhoto, LrCollection, LrCollectionSet and LrCatalog.
local function photo(id)
	return { localIdentifier = id }
end

local function collection(id, name, photos, smart)
	local c =
		{ localIdentifier = id, name = name, photos = photos or {}, smart = smart or false, added = {}, removed = {} }
	function c:type()
		return "LrCollection"
	end
	function c:getName()
		return self.name
	end
	function c:isSmartCollection()
		return self.smart
	end
	function c:getPhotos()
		return self.photos
	end
	function c:addPhotos(list)
		self.added = list
	end
	function c:removePhotos(list)
		self.removed = list
	end
	return c
end

local function collectionSet(name, collections, sets)
	local s = { name = name }
	function s:type()
		return "LrCollectionSet"
	end
	function s:getName()
		return self.name
	end
	function s:getChildCollections()
		return collections or {}
	end
	function s:getChildCollectionSets()
		return sets or {}
	end
	return s
end

local function fakeCatalog(args)
	local byId = {}
	local function index(collections, sets)
		for _, c in ipairs(collections or {}) do
			byId[c.localIdentifier] = c
		end
		for _, s in ipairs(sets or {}) do
			index(s:getChildCollections(), s:getChildCollectionSets())
		end
	end
	index(args.collections, args.sets)
	local catalog = { writeStatus = args.writeStatus or "executed", writes = {} }
	function catalog:getChildCollections()
		return args.collections or {}
	end
	function catalog:getChildCollectionSets()
		return args.sets or {}
	end
	function catalog:getCollectionByLocalIdentifier(id)
		return byId[id]
	end
	function catalog:getActiveSources()
		return args.active or {}
	end
	function catalog:withWriteAccessDo(actionName, func, timeoutParams)
		self.writes[#self.writes + 1] = { actionName = actionName, timeout = timeoutParams and timeoutParams.timeout }
		if self.writeStatus == "executed" then
			func()
		end
		return self.writeStatus
	end
	function catalog:createCollection(name)
		local created = collection(77, name)
		byId[77] = created
		return created
	end
	return catalog
end

local function adapter(catalog)
	return CatalogAdapter.new({ catalog = catalog, pcall = pcall })
end

describe("CatalogAdapter", function()
	local october = collection(11, "October", { photo(1), photo(2) })
	local smart = collection(12, "Edited lately", { photo(2), photo(3) }, true)
	local archive = collection(14, "Archive", { photo(4) })
	local family = collectionSet("Family", {}, { collectionSet("2026", { october, smart }) })

	it("describes the collection tree for the pickers", function()
		local tree = adapter(fakeCatalog({ collections = { archive }, sets = { family } })):collectionTree()
		assert.are.same({
			{ kind = "collection", name = "Archive", id = 14 },
			{
				kind = "set",
				name = "Family",
				children = {
					{
						kind = "set",
						name = "2026",
						children = {
							{ kind = "collection", name = "October", id = 11 },
							{ kind = "smart", name = "Edited lately", id = 12 },
						},
					},
				},
			},
		}, tree)
	end)

	it("lists the collections selected in Lightroom, ignoring folders and sets", function()
		local folder = {
			type = function()
				return "LrFolder"
			end,
		}
		local catalog = fakeCatalog({
			collections = { archive },
			sets = { family },
			active = { october, folder, family, smart, "quick" },
		})
		assert.are.same({ 11, 12 }, adapter(catalog):selectedCollectionIds())
	end)

	it("finds collections by id and returns nil for anything else", function()
		local a = adapter(fakeCatalog({ collections = { archive }, sets = { family } }))
		assert.are.equal(october, a:collection(11))
		assert.is_true(a:isSmart(a:collection(12)))
		assert.is_nil(a:collection(999))
	end)

	it("adds and removes the planned photos in one write named for the Run", function()
		local target = collection(20, "Edited", { photo(4), photo(9) })
		local catalog = fakeCatalog({ collections = { archive, target }, sets = { family } })
		local a = adapter(catalog)
		assert.are.same({ 1, 2 }, a:photoIds(october))
		assert.are.same({ 4, 9 }, a:photoIds(target))

		assert.is_true(a:apply(target, { add = { 1, 2 }, remove = { 9 } }, "Run Job: This week"))
		assert.are.same({ 1, 2 }, { target.added[1].localIdentifier, target.added[2].localIdentifier })
		assert.are.same({ 9 }, { target.removed[1].localIdentifier })
		assert.are.same({ { actionName = "Run Job: This week", timeout = 30 } }, catalog.writes)
	end)

	it("reports a write that did not happen", function()
		local target = collection(20, "Edited", {})
		local a = adapter(fakeCatalog({ collections = { target }, writeStatus = "aborted" }))
		local ok, message = a:apply(target, { add = {}, remove = {} }, "Run Job: This week")
		assert.is_nil(ok)
		assert.matches("busy", message, 1, true)
	end)

	it("reports an error raised inside the write", function()
		local target = collection(20, "Edited", { photo(5) })
		function target:removePhotos()
			error "collection is locked"
		end
		local a = adapter(fakeCatalog({ collections = { target } }))
		a:photoIds(target)
		local ok, message = a:apply(target, { add = {}, remove = { 5 } }, "Run Job: x")
		assert.is_nil(ok)
		assert.matches("collection is locked", message, 1, true)
	end)

	it("creates a regular collection at the top level", function()
		local a = adapter(fakeCatalog({}))
		assert.are.same(
			{ id = 77, kind = "collection", path = "Edited this week" },
			a:createCollection "Edited this week"
		)
	end)
end)
