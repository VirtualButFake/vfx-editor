local ChangeHistoryService = game:GetService("ChangeHistoryService")

return function(identifier: string, callback: () -> any): any
	local recording = ChangeHistoryService:TryBeginRecording(identifier)

	-- we want to still run the callback even if we can't record the changes
	local success, result, _check = pcall(callback)

	if _check then
		warn(
			"More than 1 value was returned from a callback inside historyHandler. This is not allowed; refactor the callback to use a single return value."
		)
	end

	if recording then
		if success then
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		else
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
			warn(`Failed to record changes for {identifier}: {result}`)
		end
	end

	return result
end
