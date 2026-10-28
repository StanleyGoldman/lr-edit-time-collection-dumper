-- The New Job / Edit Job dialog. Its state and rules live in JobForm.lua.

local LrBinding = import "LrBinding"
local LrDialogs = import "LrDialogs"
local LrView = import "LrView"

local CollectionPaths = require "CollectionPaths"
local JobForm = require "JobForm"
local Jobs = require "Jobs"

local JobEditorDialog = {}

local FIELD_KEYS =
	{ "name", "sourceIds", "targetId", "newTargetName", "kind", "amount", "unit", "startDate", "endDate" }

local function selectedValues(value)
	if type(value) == "table" then
		return value
	end
	return value ~= nil and { value } or {}
end

local function isKind(kind)
	return LrView.bind({
		key = "kind",
		transform = function(value)
			return value == kind
		end,
	})
end

-- actions: { addSelected, addPicked, removePicked } button callbacks.
local function buildContents(f, props, selectedCount, actions)
	local labelWidth = LrView.share "labelWidth"
	local function label(title)
		return f:static_text({ title = title, alignment = "right", width = labelWidth })
	end

	return f:column({
		bind_to_object = props,
		spacing = f:control_spacing(),
		f:row({ label "Name:", f:edit_field({ value = LrView.bind "name", width_in_chars = 40 }) }),

		f:group_box({
			title = "Source Collections",
			fill_horizontal = 1,
			f:row({
				label "Find:",
				f:edit_field({ value = LrView.bind "sourceFilter", immediate = true, width_in_chars = 30 }),
				f:push_button({
					title = string.format("Add the %d selected in Lightroom", selectedCount),
					enabled = selectedCount > 0,
					action = actions.addSelected,
				}),
			}),
			f:simple_list({
				items = LrView.bind "availableItems",
				value = LrView.bind "availableSelection",
				allows_multiple_selection = true,
				width = 560,
				height = 140,
			}),
			f:row({
				f:push_button({
					title = "Add ↓",
					action = actions.addPicked,
				}),
				f:push_button({
					title = "Remove ↑",
					action = actions.removePicked,
				}),
			}),
			f:simple_list({
				items = LrView.bind "chosenItems",
				value = LrView.bind "chosenSelection",
				allows_multiple_selection = true,
				width = 560,
				height = 100,
			}),
		}),

		f:group_box({
			title = "Target Collection (the Job replaces its contents on every Run)",
			fill_horizontal = 1,
			f:row({
				label "Find:",
				f:edit_field({ value = LrView.bind "targetFilter", immediate = true, width_in_chars = 30 }),
			}),
			f:row({
				label "Collection:",
				f:popup_menu({ items = LrView.bind "targetItems", value = LrView.bind "targetId", width = 440 }),
			}),
			f:row({
				label "Or new:",
				f:edit_field({ value = LrView.bind "newTargetName", width_in_chars = 30 }),
				f:static_text({ title = "(created at the top level when you save)" }),
			}),
		}),

		f:group_box({
			title = "Edit Window",
			fill_horizontal = 1,
			f:row({
				f:radio_button({ title = "Last", value = LrView.bind "kind", checked_value = "relative" }),
				f:edit_field({ value = LrView.bind "amount", width_in_chars = 4, enabled = isKind "relative" }),
				f:popup_menu({
					items = { { title = "days", value = "days" }, { title = "hours", value = "hours" } },
					value = LrView.bind "unit",
					enabled = isKind "relative",
				}),
			}),
			f:row({
				f:radio_button({ title = "From", value = LrView.bind "kind", checked_value = "fixed" }),
				f:edit_field({ value = LrView.bind "startDate", width_in_chars = 10, enabled = isKind "fixed" }),
				f:static_text({ title = "to" }),
				f:edit_field({ value = LrView.bind "endDate", width_in_chars = 10, enabled = isKind "fixed" }),
				f:static_text({ title = "(YYYY-MM-DD, both days included)" }),
			}),
		}),
	})
end

-- Shows the editor for job (nil for a new Job) until it is saved valid or
-- canceled. selectedIds: collections selected in Lightroom when the command
-- started. Returns the Job to save, or nil when canceled.
function JobEditorDialog.edit(context, services, job, allJobs, selectedIds)
	local entries = CollectionPaths.flatten(services.catalog:collectionTree())
	local f = LrView.osFactory()
	local props = LrBinding.makePropertyTable(context)
	for key, value in pairs(JobForm.fields(job)) do
		props[key] = value
	end
	if not job then
		props.sourceIds = JobForm.addSources({}, selectedIds)
	end
	props.sourceFilter = ""
	props.targetFilter = ""

	local function refresh()
		props.availableItems = JobForm.sourceChoices(entries, props.sourceFilter, props.sourceIds)
		props.chosenItems = JobForm.chosenSources(entries, props.sourceIds)
		props.targetItems = JobForm.targetChoices(entries, props.targetFilter, props.targetId)
	end
	refresh()
	props:addObserver("sourceFilter", refresh)
	props:addObserver("targetFilter", refresh)

	local actions = {
		addSelected = function()
			props.sourceIds = JobForm.addSources(props.sourceIds, selectedIds)
			refresh()
		end,
		addPicked = function()
			props.sourceIds = JobForm.addSources(props.sourceIds, selectedValues(props.availableSelection))
			props.availableSelection = {}
			refresh()
		end,
		removePicked = function()
			props.sourceIds = JobForm.removeSources(props.sourceIds, selectedValues(props.chosenSelection))
			props.chosenSelection = {}
			refresh()
		end,
	}

	local id = job and job.id or Jobs.newId(allJobs)
	while true do
		local result = LrDialogs.presentModalDialog({
			title = job and "Edit Job" or "New Job",
			contents = buildContents(f, props, #selectedIds, actions),
			actionVerb = "Save",
		})
		if result ~= "ok" then
			return nil
		end

		local fields = {}
		for _, key in ipairs(FIELD_KEYS) do
			fields[key] = props[key]
		end
		local candidate, message = JobForm.toJob(fields, entries, id)
		local ok = candidate ~= nil
		if ok then
			ok, message = Jobs.validate(candidate, allJobs)
		end
		if ok and candidate.target.newName then
			local created, createMessage = services.catalog:createCollection(candidate.target.newName)
			if created then
				entries = CollectionPaths.flatten(services.catalog:collectionTree())
				props.newTargetName = ""
				props.targetId = created.id
				refresh()
				candidate.target = { id = created.id, path = created.path }
				-- An existing collection of that name may already be a source or a target.
				ok, message = Jobs.validate(candidate, allJobs)
			else
				ok, message = false, createMessage
			end
		end
		if ok then
			return candidate
		end
		LrDialogs.message(job and "Edit Job" or "New Job", message, "warning")
	end
end

return JobEditorDialog
