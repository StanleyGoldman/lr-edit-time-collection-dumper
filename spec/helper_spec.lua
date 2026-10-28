local helper = require "spec.helper"

describe("stub import", function()
	after_each(function()
		helper.resetImports()
	end)

	it("returns a registered fake", function()
		local fakeDate = {}
		helper.fakeImport("LrDate", fakeDate)

		assert.are.equal(fakeDate, import "LrDate")
	end)

	it("errors on an unexpected module", function()
		assert.has_error(function()
			import "LrTasks"
		end, "unexpected import: LrTasks")
	end)
end)
