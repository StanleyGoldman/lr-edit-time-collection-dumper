-- Library > Plug-in Extras > Run Job…

local JobListDialog = require "JobListDialog"
local LightroomAdapter = require "LightroomAdapter"

LightroomAdapter.command("Run Job", function(context, services)
	local jobs = LightroomAdapter.loadJobs(services)
	if not jobs then
		return
	end
	if #jobs == 0 then
		LightroomAdapter.message "There are no Jobs yet. Create one with Library > Plug-in Extras > Manage Jobs…"
		return
	end
	local index = JobListDialog.pick(context, jobs)
	if index then
		LightroomAdapter.runJobs(context, services, { jobs[index] })
	end
end)
