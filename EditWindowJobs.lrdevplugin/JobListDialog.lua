-- The Manage Jobs list and the Run Job picker.

local LrBinding = import "LrBinding"
local LrDialogs = import "LrDialogs"
local LrView = import "LrView"

local JobListDialog = {}

local function jobItems(jobs)
	local items = {}
	for index, job in ipairs(jobs) do
		items[#items + 1] = { title = string.format("%s  →  %s", job.name, job.target.path), value = index }
	end
	return items
end

-- simple_list reports its selection as a list of values.
local function firstSelected(value)
	if type(value) == "table" then
		return value[1]
	end
	return value
end

-- Shows the saved Jobs. Returns the chosen action ("new", "edit", "delete" or
-- "run") and the selected Job's index, or nil when the dialog is closed.
function JobListDialog.manage(context, jobs, selectedIndex)
	local f = LrView.osFactory()
	local props = LrBinding.makePropertyTable(context)
	props.selection = selectedIndex and { selectedIndex } or {}

	local function closeWith(result)
		return function(button)
			LrDialogs.stopModalWithResult(button, result)
		end
	end

	local hasJobs = #jobs > 0
	local contents = f:column({
		bind_to_object = props,
		spacing = f:control_spacing(),
		f:static_text({
			title = hasJobs and "Jobs in this catalog:"
				or "No Jobs yet. Select the collections to use as sources in Lightroom first, then click New Job.",
		}),
		f:simple_list({
			items = jobItems(jobs),
			value = LrView.bind "selection",
			allows_multiple_selection = false,
			width = 520,
			height = 220,
		}),
		f:row({
			f:push_button({ title = "Run Now", enabled = hasJobs, action = closeWith "run" }),
			f:push_button({ title = "Delete…", enabled = hasJobs, action = closeWith "delete" }),
		}),
	})

	local result = LrDialogs.presentModalDialog({
		title = "Manage Jobs",
		contents = contents,
		actionVerb = "Edit…",
		otherVerb = "New Job…",
		cancelVerb = "Close",
	})
	local index = firstSelected(props.selection)
	if result == "ok" then
		return index and "edit" or "new", index
	elseif result == "other" then
		return "new", index
	elseif result == "run" or result == "delete" then
		return index and result or nil, index
	end
	return nil
end

-- Asks which Job to run. Returns its index, or nil when canceled.
function JobListDialog.pick(context, jobs)
	local f = LrView.osFactory()
	local props = LrBinding.makePropertyTable(context)
	props.index = 1
	local result = LrDialogs.presentModalDialog({
		title = "Run Job",
		contents = f:row({
			bind_to_object = props,
			f:static_text({ title = "Job:" }),
			f:popup_menu({ items = jobItems(jobs), value = LrView.bind "index", width = 400 }),
		}),
		actionVerb = "Run",
	})
	if result == "ok" then
		return props.index
	end
	return nil
end

return JobListDialog
