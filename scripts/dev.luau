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

if fs.isDir(".zap") then
	executeCommand("zap", { "src/server/network.zap" })
end

task.spawn(executeCommand, "rojo", { "sourcemap", "./default.project.json", "-o", "sourcemap.json", "--watch" })
task.wait(0.5) -- allow the sourcemap to be generated (prevents an annoying error)

if fs.isFile(".darklua.json") then
	process.env.RBLX_DEV = "true"
	task.spawn(executeCommand, "darklua", { "process", "src", "build", "--watch" })
	task.wait(0.5) -- allow darklua to generate a build, so that rojo doesn't refer to unknown paths and error
end

task.spawn(
	executeCommand,
	"rojo",
	{ "serve", fs.isFile("dev.project.json") and "dev.project.json" or "default.project.json" }
)

task.spawn(function()
	local lastChange = nil

	while true do
		if fs.isFile("sourcemap.json") then
			local metadata = fs.metadata("sourcemap.json")

			if metadata.accessedAt ~= lastChange then
				lastChange = metadata.accessedAt
				task.wait(3) -- weird bug where sourcemap gets corrupted

				-- iterate src for any rbxm files and add them
				local function addRbxmFiles(dir)
					for _, file in (fs.readDir(dir)) do
						if fs.isFile(dir .. "/" .. file) then
							if file:match("%.rbxmx?$") then
								-- trim first bit of dir
								local split = dir:split("/")
								table.remove(split, 1)
								local path = table.concat(split, "/")
								fs.copy(dir .. "/" .. file, "build/" .. path .. "/" .. file, true)
							end
						else
							addRbxmFiles(dir .. "/" .. file)
						end
					end
				end

				addRbxmFiles("src")
			end
		end

		task.wait(1)
	end
end)
