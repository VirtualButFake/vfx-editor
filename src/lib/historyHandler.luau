local ChangeHistoryService = game:GetService("ChangeHistoryService")

return function(identifier: string, callback: () -> any): any
	local recording = ChangeHistoryService:TryBeginRecording(identifier)

	-- we want to still run the callback even if we can't record the changes
	local success, result = pcall(callback)

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
