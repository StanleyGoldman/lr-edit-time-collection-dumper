-- Modelled on rcloran/lr-inaturalist-publish.
-- Core modules get plain Lua 5.1, so an SDK call in core fails lint; only
-- the role-suffixed files below (see docs/coding-standards.md) may import.
std = "lua51"
-- Adapters and fakes implement shared method interfaces, so some methods ignore self.
self = false

-- .claude/ holds local agent worktrees and spike/ the untracked spike leftovers.
exclude_files = { ".lua/", ".luarocks/", "lua_modules/", ".claude/", "spike/" }

-- Lightroom's plugin environment: Lua 5.1 plus the SDK's own globals.
stds.lightroom = {
	read_globals = {
		"MAC_ENV",
		"WIN_ENV",
		"_PLUGIN",
		"import",
	},
}
for k, v in pairs(stds.lua51.read_globals) do
	stds.lightroom.read_globals[k] = v
end
-- Lightroom's os lacks remove, rename, execute and exit; os.remove crashed a Run.
stds.lightroom.read_globals.os = { fields = { "clock", "date", "difftime", "time" } }

-- Present in plain Lua 5.1 but absent from, or unsafe in, Lightroom's environment.
not_globals = {
	"getfenv",
	"package",
	"print",
	"setfenv",
}

-- Info.lua runs in a smaller environment than the rest of the plugin.
stds.lightroom_plugin_info = {
	read_globals = {
		"MAC_ENV",
		"WIN_ENV",
		"_VERSION",
	},
}
files["*/Info.lua"].std = "lightroom_plugin_info"

for _, suffix in ipairs { "Adapter", "Dialog", "Menu" } do
	files["EditWindowJobs.lrdevplugin/*" .. suffix .. ".lua"].std = "lightroom"
end

files["spec/**"].std = "+busted"
files["spec/**"].read_globals = { "import" }
-- spec/helper.lua installs the stub import, so it must write that global.
files["spec/helper.lua"].globals = { "import" }
