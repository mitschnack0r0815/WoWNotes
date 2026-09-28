local _, ns = ...

SLASH_WOWNOTES1 = "/notes"
SLASH_WOWNOTES2 = "/wn"
SlashCmdList["WOWNOTES"] = function(msg)
	msg = msg:trim()
	if msg == "minimap" then
		ns.ToggleMinimapButton()
	elseif msg ~= "" then
		-- /notes <text> adds a quick note without opening the window
		ns.AddNote(msg)
		ns.RefreshWindow()
		print("WoW Notes: note added")
	else
		ns.ToggleWindow()
	end
end
