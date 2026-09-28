local _, ns = ...

local LIST_WIDTH = 200 -- width of the note list panel on the left
local ROW_HEIGHT = 38
local PADDING = 12
local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local GOLD = { 1, 0.82, 0 }
local PANEL_BG = { 0.04, 0.04, 0.05, 0.9 }
local PANEL_BORDER = { 0.5, 0.44, 0.32 }

-- Dark panel with a thin bronze border, used for the list and the editor
local function CreatePanel(parent)
	local panel = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
	panel:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	panel:SetBackdropColor(unpack(PANEL_BG))
	panel:SetBackdropBorderColor(unpack(PANEL_BORDER))
	return panel
end

-- Main window: note list on the left, editor for the selected note on the right.
local window = CreateFrame("Frame", "WoWNotesMainFrame", UIParent, "BasicFrameTemplateWithInset")
window:SetSize(640, 430)
window:SetPoint("CENTER")
window:SetFrameStrata("HIGH")
window:SetClampedToScreen(true)
window:EnableMouse(true)
window:SetMovable(true)
window:RegisterForDrag("LeftButton")
window:SetScript("OnDragStart", window.StartMoving)
window:SetScript("OnDragStop", window.StopMovingOrSizing)
window:Hide()
tinsert(UISpecialFrames, "WoWNotesMainFrame") -- close with Escape

if window.TitleText then
	window.TitleText:SetText("|T" .. ns.ICON .. ":14:14:0:0:64:64:5:59:5:59|t  WoW Notes")
end

local selected -- index of the note shown in the editor

---------------------------------------------------------------------------
-- Note list
---------------------------------------------------------------------------

local newButton = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
newButton:SetSize(LIST_WIDTH / 2 - 2, 24)
newButton:SetPoint("BOTTOMLEFT", PADDING, PADDING)
newButton:SetText("New Note")

local deleteButton = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
deleteButton:SetSize(LIST_WIDTH / 2 - 2, 24)
deleteButton:SetPoint("LEFT", newButton, "RIGHT", 4, 0)
deleteButton:SetText("Delete")

local listPanel = CreatePanel(window)
listPanel:SetPoint("TOPLEFT", PADDING, -32)
listPanel:SetPoint("BOTTOM", newButton, "TOP", 0, 6)
listPanel:SetWidth(LIST_WIDTH)

local listEmpty = listPanel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
listEmpty:SetPoint("CENTER")
listEmpty:SetText("No notes yet")

-- The scroll bar sits inside the panel's right edge
local listScroll = CreateFrame("ScrollFrame", "WoWNotesListScroll", listPanel, "UIPanelScrollFrameTemplate")
listScroll:SetPoint("TOPLEFT", 5, -5)
listScroll:SetPoint("BOTTOMRIGHT", -27, 5)

local listContent = CreateFrame("Frame", nil, listScroll)
listContent:SetSize(1, 1)
listScroll:SetScrollChild(listContent)
listScroll:SetScript("OnSizeChanged", function(self, width)
	listContent:SetWidth(width)
end)

-- List rows are created on demand and reused
local rows = {}

local function GetRow(i)
	local row = rows[i]
	if row then
		return row
	end
	row = CreateFrame("Button", nil, listContent)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
	row:SetPoint("RIGHT")

	row.bg = row:CreateTexture(nil, "BACKGROUND")
	row.bg:SetAllPoints()

	local highlight = row:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetColorTexture(1, 1, 1, 0.06)

	-- Gold bar on the left edge of the selected row
	row.accent = row:CreateTexture(nil, "ARTWORK")
	row.accent:SetPoint("TOPLEFT")
	row.accent:SetPoint("BOTTOMLEFT")
	row.accent:SetWidth(3)
	row.accent:SetColorTexture(unpack(GOLD))

	row.title = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	row.title:SetPoint("TOPLEFT", 10, -6)
	row.title:SetPoint("RIGHT", -6, 0)
	row.title:SetJustifyH("LEFT")
	row.title:SetWordWrap(false)

	row.preview = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	row.preview:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -4)
	row.preview:SetPoint("RIGHT", -6, 0)
	row.preview:SetJustifyH("LEFT")
	row.preview:SetWordWrap(false)
	row.preview:SetTextColor(0.55, 0.55, 0.55)

	row:SetScript("OnClick", function(self)
		ns.SelectNote(self.index)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	end)
	rows[i] = row
	return row
end

local function RefreshList()
	local notes = ns.GetNotes()
	for i, note in ipairs(notes) do
		local row = GetRow(i)
		local isSelected = i == selected
		row.index = i
		row.title:SetText(ns.GetTitle(note))
		row.title:SetTextColor(unpack(isSelected and GOLD or { 0.9, 0.9, 0.9 }))
		local preview = ns.GetPreview(note)
		row.preview:SetText(ns.FormatAge(note.edited) .. (preview ~= "" and "   |cffb0b0b0" .. preview .. "|r" or ""))
		row.accent:SetShown(isSelected)
		if isSelected then
			row.bg:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.12)
		elseif i % 2 == 0 then
			row.bg:SetColorTexture(1, 1, 1, 0.025)
		else
			row.bg:SetColorTexture(0, 0, 0, 0)
		end
		row:Show()
	end
	for i = #notes + 1, #rows do
		rows[i]:Hide()
	end
	listContent:SetHeight(math.max(1, #notes * ROW_HEIGHT))
	listEmpty:SetShown(#notes == 0)
	deleteButton:SetEnabled(selected ~= nil)
end

---------------------------------------------------------------------------
-- Editor
---------------------------------------------------------------------------

local editorPanel = CreatePanel(window)
editorPanel:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", 8, 0)
editorPanel:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)

-- Everything shown while a note is selected
local editor = CreateFrame("Frame", nil, editorPanel)
editor:SetAllPoints()

local header = editor:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
header:SetPoint("TOPLEFT", 16, -14)
header:SetPoint("RIGHT", -16, 0)
header:SetJustifyH("LEFT")
header:SetWordWrap(false)

local subheader = editor:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
subheader:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -5)

local divider = editor:CreateTexture(nil, "ARTWORK")
divider:SetHeight(1)
divider:SetPoint("TOPLEFT", 12, -54)
divider:SetPoint("TOPRIGHT", -12, -54)
divider:SetColorTexture(PANEL_BORDER[1], PANEL_BORDER[2], PANEL_BORDER[3], 0.5)

local editScroll = CreateFrame("ScrollFrame", "WoWNotesEditScroll", editor, "UIPanelScrollFrameTemplate")
editScroll:SetPoint("TOPLEFT", 16, -64)
editScroll:SetPoint("BOTTOMRIGHT", -30, 12)

local editBox = CreateFrame("EditBox", nil, editScroll)
editBox:SetMultiLine(true)
editBox:SetAutoFocus(false)
editBox:SetFontObject(GameFontHighlight)
editBox:SetSpacing(3)
editBox:SetWidth(1)
editScroll:SetScrollChild(editBox)
editBox:SetScript("OnEscapePressed", editBox.ClearFocus)
if ScrollingEdit_OnCursorChanged then
	-- keep the cursor in view while typing
	editBox:SetScript("OnCursorChanged", ScrollingEdit_OnCursorChanged)
	editBox:SetScript("OnUpdate", function(self, elapsed)
		ScrollingEdit_OnUpdate(self, elapsed, editScroll)
	end)
end

local placeholder = editBox:CreateFontString(nil, "ARTWORK", "GameFontDisable")
placeholder:SetPoint("TOPLEFT")
placeholder:SetText("Start typing. The first line becomes the title.")

editScroll:SetScript("OnSizeChanged", function(self, width, height)
	editBox:SetWidth(width)
	editBox:SetHeight(height) -- so clicking anywhere in the empty area focuses the box
end)
editScroll:EnableMouse(true)
editScroll:SetScript("OnMouseDown", function()
	editBox:SetFocus()
end)

-- Shown instead of the editor when no note is selected
local emptyState = CreateFrame("Frame", nil, editorPanel)
emptyState:SetAllPoints()

local emptyIcon = emptyState:CreateTexture(nil, "ARTWORK")
emptyIcon:SetSize(48, 48)
emptyIcon:SetPoint("CENTER", 0, 20)
emptyIcon:SetTexture(ns.ICON)
emptyIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
emptyIcon:SetDesaturated(true)
emptyIcon:SetAlpha(0.35)

local emptyText = emptyState:CreateFontString(nil, "ARTWORK", "GameFontDisable")
emptyText:SetPoint("TOP", emptyIcon, "BOTTOM", 0, -12)
emptyText:SetText("Select a note, or click New Note to start one")

local function UpdateHeader()
	local note = selected and ns.GetNotes()[selected]
	editor:SetShown(note ~= nil)
	emptyState:SetShown(note == nil)
	if note then
		header:SetText(ns.GetTitle(note))
		subheader:SetText("Edited " .. ns.FormatAge(note.edited))
		placeholder:SetShown(note.text == "")
	end
end

function ns.SelectNote(index)
	local notes = ns.GetNotes()
	selected = notes[index] and index or nil
	editBox:ClearFocus()
	editBox:SetText(selected and notes[selected].text or "")
	editBox:SetCursorPosition(0)
	UpdateHeader()
	RefreshList()
end

-- Save while typing; the header and list follow along
editBox:SetScript("OnTextChanged", function(self, userInput)
	if userInput and selected then
		ns.SetNoteText(selected, self:GetText())
		UpdateHeader()
		RefreshList()
	end
end)

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

-- Opens the window on a new empty note, ready to type
function ns.NewNote()
	window:Show()
	ns.SelectNote(ns.AddNote(""))
	editBox:SetFocus()
end

newButton:SetScript("OnClick", ns.NewNote)

StaticPopupDialogs["WOWNOTES_DELETE"] = {
	text = "Delete note \"%s\"?",
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		if selected then
			ns.DeleteNote(selected)
			ns.SelectNote(math.min(selected, #ns.GetNotes()))
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	showAlert = true,
	preferredIndex = 3,
}

deleteButton:SetScript("OnClick", function()
	if selected then
		StaticPopup_Show("WOWNOTES_DELETE", ns.GetTitle(ns.GetNotes()[selected]))
	end
end)

window:SetScript("OnShow", function()
	ns.SelectNote(selected or 1)
	PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
end)
window:SetScript("OnHide", function()
	PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
end)

function ns.RefreshWindow()
	if window:IsShown() then
		RefreshList()
	end
end

function ns.ToggleWindow()
	window:SetShown(not window:IsShown())
end
