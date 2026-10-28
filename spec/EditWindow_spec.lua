local EditWindow = require "EditWindow"

-- Stands in for LrDate.timeFromComponents(year, month, day, 0, 0, 0, "local"):
-- local midnight as Cocoa seconds, here for a fixed UTC-4 zone.
local function localMidnight(year, month, day)
	local daysFrom2001 = os.time({ year = year, month = month, day = day, hour = 12 }) / 86400
		- os.time({ year = 2001, month = 1, day = 1, hour = 12 }) / 86400
	return math.floor(daysFrom2001 + 0.5) * 86400 + 4 * 3600
end

describe("EditWindow.parseDate", function()
	it("reads YYYY-MM-DD", function()
		local date = EditWindow.parseDate "2026-10-27"
		assert.are.same({ year = 2026, month = 10, day = 27 }, date)
	end)

	it("accepts 29 February in a leap year", function()
		assert.is_truthy(EditWindow.parseDate "2024-02-29")
	end)

	for _, text in ipairs({ "2026-10-32", "2026-13-01", "2025-02-29", "2026-1-5", "27/10/2026", "", "2026-10-27x" }) do
		it("rejects " .. string.format("%q", text), function()
			local date, message = EditWindow.parseDate(text)
			assert.is_nil(date)
			assert.matches("YYYY%-MM%-DD", message)
		end)
	end
end)

describe("EditWindow.resolve", function()
	local now = 814840482

	it("starts a relative window N hours before now and leaves it open-ended", function()
		local startTime, endTime =
			EditWindow.resolve({ kind = "relative", amount = 6, unit = "hours" }, now, localMidnight)
		assert.are.equal(now - 6 * 3600, startTime)
		assert.is_nil(endTime)
	end)

	it("counts relative days as 24-hour periods", function()
		local startTime = EditWindow.resolve({ kind = "relative", amount = 7, unit = "days" }, now, localMidnight)
		assert.are.equal(now - 7 * 86400, startTime)
	end)

	it("runs a fixed window from local midnight of the start date to the midnight after the end date", function()
		local window = { kind = "fixed", startDate = "2026-10-01", endDate = "2026-10-15" }
		local startTime, endTime = EditWindow.resolve(window, now, localMidnight)
		assert.are.equal(localMidnight(2026, 10, 1), startTime)
		assert.are.equal(localMidnight(2026, 10, 16), endTime)
	end)

	it("rolls the end of a fixed window over month and year ends", function()
		local _, endTime =
			EditWindow.resolve({ kind = "fixed", startDate = "2026-12-01", endDate = "2026-12-31" }, now, localMidnight)
		assert.are.equal(localMidnight(2027, 1, 1), endTime)
		local _, leapEnd =
			EditWindow.resolve({ kind = "fixed", startDate = "2024-02-01", endDate = "2024-02-29" }, now, localMidnight)
		assert.are.equal(localMidnight(2024, 3, 1), leapEnd)
	end)

	it("covers a single day when start and end dates match", function()
		local startTime, endTime =
			EditWindow.resolve({ kind = "fixed", startDate = "2026-10-27", endDate = "2026-10-27" }, now, localMidnight)
		assert.are.equal(86400, endTime - startTime)
	end)

	local invalid = {
		["an end date before the start date"] = {
			window = { kind = "fixed", startDate = "2026-10-15", endDate = "2026-10-01" },
			message = "end date",
		},
		["a malformed start date"] = {
			window = { kind = "fixed", startDate = "Oct 1", endDate = "2026-10-01" },
			message = "start date",
		},
		["a zero amount"] = { window = { kind = "relative", amount = 0, unit = "days" }, message = "whole number" },
		["a fractional amount"] = {
			window = { kind = "relative", amount = 1.5, unit = "days" },
			message = "whole number",
		},
		["an unknown unit"] = { window = { kind = "relative", amount = 3, unit = "weeks" }, message = "hours or days" },
		["an unknown kind"] = { window = { kind = "rolling" }, message = "fixed or relative" },
	}
	for name, case in pairs(invalid) do
		it("rejects " .. name, function()
			local startTime, message = EditWindow.resolve(case.window, now, localMidnight)
			assert.is_nil(startTime)
			assert.matches(case.message, message, 1, true)
		end)
	end
end)

describe("EditWindow.validate", function()
	it("accepts well-formed windows", function()
		assert.is_true(EditWindow.validate({ kind = "relative", amount = 3, unit = "days" }))
		assert.is_true(EditWindow.validate({ kind = "fixed", startDate = "2026-10-01", endDate = "2026-10-01" }))
	end)

	it("rejects an end date before the start date without needing a clock", function()
		local ok, message = EditWindow.validate({ kind = "fixed", startDate = "2026-10-02", endDate = "2026-10-01" })
		assert.is_nil(ok)
		assert.matches("on or after the start date", message, 1, true)
	end)

	it("rejects a missing window", function()
		local ok, message = EditWindow.validate(nil)
		assert.is_nil(ok)
		assert.matches("fixed or relative", message, 1, true)
	end)
end)
