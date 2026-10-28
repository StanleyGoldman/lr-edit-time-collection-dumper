-- Library > Plug-in Extras > Run All Jobs

local LightroomAdapter = require "LightroomAdapter"

LightroomAdapter.command("Run All Jobs", function(context, services)
	local jobs = LightroomAdapter.loadJobs(services)
	if not jobs then
		return
	end
	if #jobs == 0 then
		LightroomAdapter.message "There are no Jobs yet. Create one with Library > Plug-in Extras > Manage Jobs…"
		return
	end
	LightroomAdapter.runJobs(context, services, jobs)
end)
