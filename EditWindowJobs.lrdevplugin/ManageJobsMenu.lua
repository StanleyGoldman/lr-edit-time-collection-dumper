-- Library > Plug-in Extras > Manage Jobs…
-- The list dialog closes with an action; this loop carries it out and shows
-- the list again, so no dialog ever opens on top of another.

local LrDialogs = import "LrDialogs"

local JobEditorDialog = require "JobEditorDialog"
local JobListDialog = require "JobListDialog"
local LightroomAdapter = require "LightroomAdapter"

LightroomAdapter.command("Manage Jobs", function(context, services)
	local jobs = LightroomAdapter.loadJobs(services)
	if not jobs then
		return
	end
	-- Read while Lightroom's panels are reachable; the dialogs are modal.
	local selectedIds = services.catalog:selectedCollectionIds()

	local selected
	while true do
		local action, index = JobListDialog.manage(context, jobs, selected)
		selected = index
		if action == nil then
			return
		elseif action == "new" or action == "edit" then
			local existing = action == "edit" and jobs[index] or nil
			local edited = JobEditorDialog.edit(context, services, existing, jobs, selectedIds)
			if edited then
				local updated = { unpack(jobs) }
				if existing then
					updated[index] = edited
				else
					updated[#updated + 1] = edited
					selected = #updated
				end
				if LightroomAdapter.saveJobs(services, updated) then
					jobs = updated
				end
			end
		elseif action == "delete" then
			local job = jobs[index]
			local answer = LrDialogs.confirm(
				string.format('Delete the Job "%s"?', job.name),
				string.format('Its Target Collection "%s" is left as it is.', job.target.path),
				"Delete"
			)
			if answer == "ok" then
				local updated = { unpack(jobs) }
				table.remove(updated, index)
				if LightroomAdapter.saveJobs(services, updated) then
					jobs = updated
					selected = nil
				end
			end
		elseif action == "run" then
			LightroomAdapter.runJobs(context, services, { jobs[index] })
		end
	end
end)
