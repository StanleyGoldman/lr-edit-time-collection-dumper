-- Lists collections by their full path through collection sets, for pickers
-- that narrow a long, deeply nested list as the user types.

local CollectionPaths = {}

CollectionPaths.SEPARATOR = " › "

local function addEntries(nodes, parentPath, entries)
	for _, node in ipairs(nodes) do
		local path = parentPath and (parentPath .. CollectionPaths.SEPARATOR .. node.name) or node.name
		if node.kind == "set" then
			addEntries(node.children or {}, path, entries)
		else
			entries[#entries + 1] = { id = node.id, kind = node.kind, path = path }
		end
	end
end

-- nodes: a list of { kind = "set", name, children } and
-- { kind = "collection" | "smart", name, id }, as the catalog nests them.
-- Returns { id, kind, path } for every collection, sorted by path ignoring case.
function CollectionPaths.flatten(nodes)
	local entries = {}
	addEntries(nodes, nil, entries)
	table.sort(entries, function(a, b)
		return string.lower(a.path) < string.lower(b.path)
	end)
	return entries
end

-- Returns the entries whose path contains every whitespace-separated word of
-- query, ignoring case. A blank query keeps them all.
function CollectionPaths.filter(entries, query)
	local words = {}
	for word in string.gmatch(string.lower(query or ""), "%S+") do
		words[#words + 1] = word
	end
	local matches = {}
	for _, entry in ipairs(entries) do
		local path = string.lower(entry.path)
		local matchesAll = true
		for _, word in ipairs(words) do
			if not string.find(path, word, 1, true) then
				matchesAll = false
				break
			end
		end
		if matchesAll then
			matches[#matches + 1] = entry
		end
	end
	return matches
end

return CollectionPaths
