local process = require("@lune/process")
local fs = require("@lune/fs")

function executeCommand(command, args)
	local data = process.spawn(command, args, {
		stdio = "inherit",
	})

	if data.code ~= 0 then
		error("Command failed with code " .. data.code)
	end

	return data
end

if fs.isDir(".zap") then
	executeCommand("zap", { "src/server/network.zap" })
end

if not fs.isDir("packages") and not fs.isDir("Packages") and fs.isFile("wally.toml") then
	executeCommand("lune", { "run", "scripts/install-packages" })
end

local hasDarkLua = fs.isFile(".darklua.json")
local buildPath = hasDarkLua and "build" or "default"

process.env.RBLX_DEV = "false"

if not fs.isDir("build") then
	print("Creating build directory..")
	executeCommand("rojo", { "sourcemap", "default.project.json", "-o", "sourcemap.json" })
	executeCommand("darklua", { "process", "src", "build" })
end

executeCommand("rojo", { "sourcemap", "default.project.json", "-o", "sourcemap.json" })

if hasDarkLua then
	executeCommand("darklua", { "process", "src", "build" })
end

-- get rid of stories; no need for those to be in the actual build
if fs.isDir("build/client/ui/stories") then
	fs.removeDir("build/client/ui/stories")
end

executeCommand("rojo", { "build", `{buildPath}.project.json`, "-o", "build.rbxlx" })
