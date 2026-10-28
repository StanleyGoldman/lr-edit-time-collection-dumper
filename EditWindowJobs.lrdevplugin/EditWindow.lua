-- Turns a Job's Edit Window into the times a Run searches between.

local EditWindow = {}

local SECONDS = { hours = 3600, days = 86400 }

local function isLeapYear(year)
	return (year % 4 == 0 and year % 100 ~= 0) or year % 400 == 0
end

local function daysInMonth(year, month)
	if month == 2 then
		return isLeapYear(year) and 29 or 28
	end
	return ({ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 })[month]
end

local function nextDay(date)
	if date.day < daysInMonth(date.year, date.month) then
		return { year = date.year, month = date.month, day = date.day + 1 }
	elseif date.month < 12 then
		return { year = date.year, month = date.month + 1, day = 1 }
	end
	return { year = date.year + 1, month = 1, day = 1 }
end

-- Returns { year, month, day } for "YYYY-MM-DD", or nil and a message.
function EditWindow.parseDate(text)
	local year, month, day = string.match(text or "", "^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
	year, month, day = tonumber(year), tonumber(month), tonumber(day)
	if not year or month < 1 or month > 12 or day < 1 or day > daysInMonth(year, month) then
		return nil, string.format("%q is not a date in the form YYYY-MM-DD", tostring(text))
	end
	return { year = year, month = month, day = day }
end

local function compareDates(a, b)
	if a.year ~= b.year then
		return a.year < b.year and -1 or 1
	elseif a.month ~= b.month then
		return a.month < b.month and -1 or 1
	elseif a.day ~= b.day then
		return a.day < b.day and -1 or 1
	end
	return 0
end

-- Returns true for a well-formed window, or nil and a message for the user.
function EditWindow.validate(window)
	local kind = window and window.kind
	if kind == "relative" then
		local amount = window.amount
		if type(amount) ~= "number" or amount < 1 or amount ~= math.floor(amount) then
			return nil, "The window's length must be a whole number of at least 1."
		end
		if not SECONDS[window.unit] then
			return nil, "The window's unit must be hours or days."
		end
		return true
	elseif kind == "fixed" then
		local startDate, startMessage = EditWindow.parseDate(window.startDate)
		if not startDate then
			return nil, "The start date: " .. startMessage
		end
		local endDate, endMessage = EditWindow.parseDate(window.endDate)
		if not endDate then
			return nil, "The end date: " .. endMessage
		end
		if compareDates(endDate, startDate) < 0 then
			return nil, "The end date must be on or after the start date."
		end
		return true
	end
	return nil, "The window must be fixed or relative."
end

-- Returns startTime and endTime in Cocoa seconds; endTime is nil when the window
-- has no end. Searching includes startTime and excludes endTime.
-- now: the Run's moment. localMidnight(year, month, day): that date's local
-- midnight in Cocoa seconds, which keeps daylight saving changes out of core.
-- Returns nil and a message for an invalid window.
function EditWindow.resolve(window, now, localMidnight)
	local ok, message = EditWindow.validate(window)
	if not ok then
		return nil, message
	end
	if window.kind == "relative" then
		return now - window.amount * SECONDS[window.unit], nil
	end
	local startDate = EditWindow.parseDate(window.startDate)
	local after = nextDay(EditWindow.parseDate(window.endDate))
	return localMidnight(startDate.year, startDate.month, startDate.day),
		localMidnight(after.year, after.month, after.day)
end

return EditWindow
