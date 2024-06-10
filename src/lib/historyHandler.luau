local ChangeHistoryService = game:GetService("ChangeHistoryService")

return function(identifier: string, callback: () -> any): any
	local recording = ChangeHistoryService:TryBeginRecording(identifier)

	if not recording then
		warn(`Failed to begin recording for {identifier}`)
		return
	end

	local success, result = pcall(callback)

	if success then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	else
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
		warn(`Failed to record changes for {identifier}: {result}`)
	end

	return result
end
