local _, ns = ...

-- Notes live in WoWNotesDB.notes (account-wide) as { text = "...", edited = <time()> }.
-- The first line is the title. WoWNotesDB.minimap holds the minimap button angle and hidden state.
function ns.GetDB()
	WoWNotesDB = WoWNotesDB or {}
	WoWNotesDB.notes = WoWNotesDB.notes or {}
	return WoWNotesDB
end

function ns.GetNotes()
	return ns.GetDB().notes
end

function ns.AddNote(text)
	local notes = ns.GetNotes()
	tinsert(notes, { text = text or "", edited = time() })
	return #notes
end

function ns.SetNoteText(index, text)
	local note = ns.GetNotes()[index]
	note.text = text
	note.edited = time()
end

function ns.DeleteNote(index)
	tremove(ns.GetNotes(), index)
end

function ns.GetTitle(note)
	local title = note.text:match("^[^\n]*"):trim()
	return title ~= "" and title or ns.UNTITLED
end

-- First non-empty line after the title, for the list
function ns.GetPreview(note)
	local body = note.text:match("\n(.*)")
	local line = body and body:match("[^\n]*%S[^\n]*")
	return line and line:trim() or ""
end

-- "just now", "5 min ago", "3 h ago", then the date
function ns.FormatAge(timestamp)
	if not timestamp then
		return ""
	end
	local age = time() - timestamp
	if age < 60 then
		return "just now"
	elseif age < 3600 then
		return floor(age / 60) .. " min ago"
	elseif age < 86400 then
		return floor(age / 3600) .. " h ago"
	end
	return date("%b %d", timestamp)
end
