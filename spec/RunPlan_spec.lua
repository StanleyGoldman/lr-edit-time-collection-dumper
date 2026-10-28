local RunPlan = require "RunPlan"

local function set(list)
	local result = {}
	for _, id in ipairs(list) do
		result[id] = true
	end
	return result
end

describe("RunPlan.build", function()
	it("adds edited source photos missing from the target", function()
		local plan = RunPlan.build({ sourceIds = { 3, 1, 2 }, editedIds = set({ 1, 3, 99 }), targetIds = {} })
		assert.are.same({ 1, 3 }, plan.add)
		assert.are.same({}, plan.remove)
		assert.are.same({}, plan.keep)
	end)

	it("removes target photos that do not qualify, including ones added by hand", function()
		local plan = RunPlan.build({ sourceIds = { 1, 2 }, editedIds = set({ 1 }), targetIds = { 1, 2, 50 } })
		assert.are.same({}, plan.add)
		assert.are.same({ 2, 50 }, plan.remove)
		assert.are.same({ 1 }, plan.keep)
	end)

	it("counts a photo in several sources once", function()
		local plan = RunPlan.build({ sourceIds = { 4, 4, 4 }, editedIds = set({ 4 }), targetIds = {} })
		assert.are.same({ 4 }, plan.add)
	end)

	it("empties the target when nothing qualifies", function()
		local plan = RunPlan.build({ sourceIds = { 1 }, editedIds = {}, targetIds = { 1, 2 } })
		assert.are.same({ 1, 2 }, plan.remove)
	end)

	it("reports whether the plan changes anything", function()
		assert.is_false(RunPlan.build({ sourceIds = { 1 }, editedIds = set({ 1 }), targetIds = { 1 } }).changes)
		assert.is_true(RunPlan.build({ sourceIds = { 1 }, editedIds = set({ 1 }), targetIds = {} }).changes)
	end)
end)
