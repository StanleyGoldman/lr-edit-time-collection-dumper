local CollectionPaths = require "CollectionPaths"

local tree = {
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
			{ kind = "collection", name = "best of", id = 13 },
		},
	},
	{ kind = "collection", name = "Archive", id = 14 },
	{ kind = "set", name = "Empty set", children = {} },
}

describe("CollectionPaths.flatten", function()
	it("lists every collection under its full path, sorted, leaving out sets", function()
		assert.are.same({
			{ id = 14, kind = "collection", path = "Archive" },
			{ id = 12, kind = "smart", path = "Family › 2026 › Edited lately" },
			{ id = 11, kind = "collection", path = "Family › 2026 › October" },
			{ id = 13, kind = "collection", path = "Family › best of" },
		}, CollectionPaths.flatten(tree))
	end)

	it("sorts paths without regard to case", function()
		local entries = CollectionPaths.flatten({
			{ kind = "collection", name = "beta", id = 1 },
			{ kind = "collection", name = "Alpha", id = 2 },
		})
		assert.are.same({ "Alpha", "beta" }, { entries[1].path, entries[2].path })
	end)
end)

describe("CollectionPaths.filter", function()
	local entries = CollectionPaths.flatten(tree)

	local function paths(list)
		local result = {}
		for index, entry in ipairs(list) do
			result[index] = entry.path
		end
		return result
	end

	it("keeps paths containing every word of the query, in any case and order", function()
		assert.are.same({ "Family › 2026 › October" }, paths(CollectionPaths.filter(entries, "oct FAM")))
	end)

	it("matches words inside parent set names", function()
		assert.are.same(
			{ "Family › 2026 › Edited lately", "Family › 2026 › October" },
			paths(CollectionPaths.filter(entries, "2026"))
		)
	end)

	it("returns everything for a blank query", function()
		assert.are.equal(#entries, #CollectionPaths.filter(entries, "   "))
	end)

	it("treats pattern characters literally", function()
		assert.are.same({}, paths(CollectionPaths.filter(entries, "%a")))
	end)
end)
