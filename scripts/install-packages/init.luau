local process = require("@lune/process")
local fs = require("@lune/fs")
local task = require("@lune/task")

function executeCommand(command, args)
	local data = process.spawn(command, args, {
		stdio = "inherit",
	})

	if data.code ~= 0 then
		error("Command failed with code " .. data.code)
	end

	return data
end

if fs.isDir("packages") then
	fs.removeDir("packages")
end

executeCommand("wally", {
	"install",
})

-- do this so the project file doesn't refer to files that don't exist and cause rojo to fail
if fs.isDir(".zap") then
	executeCommand("zap", { "src/server/network.zap" })
end

executeCommand("rojo", {
	"sourcemap",
	"default.project.json",
	"-o",
	"sourcemap.json",
})

if fs.isDir("Packages") then
	executeCommand("wally-package-types", {
		"--sourcemap",
		"sourcemap.json",
		"./Packages",
	})

	-- doing this instead of placing it inside 1 file since this method ties into the existing template concept better
	task.wait(0.1)
	fs.move("./Packages", "./packages", true)
end
