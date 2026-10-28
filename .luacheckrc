-- Modelled on rcloran/lr-inaturalist-publish.
std = "lightroom"

exclude_files = { ".lua/", ".luarocks/", "lua_modules/" }

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

files["spec/**"].std = "+busted"
-- spec/helper.lua installs the stub import, so it must write that global.
files["spec/helper.lua"].globals = { "import" }
