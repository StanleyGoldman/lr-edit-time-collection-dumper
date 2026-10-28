-- Loaded by busted before every spec (see .busted).
--
-- Lightroom provides a global import() for SDK modules. Specs run outside
-- Lightroom, so this stub replaces it. A spec registers a fake for each module
-- its code under test imports; importing anything unregistered fails loudly, so
-- a hidden SDK dependency shows up as a test failure instead of a nil.

local fakes = {}

function import(name)
	local fake = fakes[name]
	if fake == nil then
		error("unexpected import: " .. tostring(name), 2)
	end
	return fake
end

local helper = {}

-- Register a fake for one SDK module, e.g. helper.fakeImport("LrDate", fakeDate).
function helper.fakeImport(name, fake)
	fakes[name] = fake
end

function helper.resetImports()
	fakes = {}
end

return helper
