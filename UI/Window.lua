local _, ns = ...

-- Styled after the new spellbook: an open book with the note list on the left page
-- and the selected note on the right page. Uses the spellbook's own atlases; on a
-- client without them the art falls back to plain colors.

local ROW_HEIGHT = 58
local PAGE_MARGIN = 56 -- space between a page's edges and its content
local BLIZZARD_BOOK_HEIGHT = 832 -- height of the spellbook pages, to scale the ribbon

local FONT_COLOR = SPELLBOOK_FONT_COLOR or CreateColor(0.25, 0.16, 0.08)

local function Font(name, fallback)
	return _G[name] and name or fallback
end
local HEADER_FONT = Font("SystemFont_Huge2", "GameFontNormalHuge")
local NAME_FONT = Font("SystemFont_Large", "GameFontNormalLarge")
local SMALL_FONT = Font("SystemFont_Med1", "GameFontNormal")
local TEXT_FONT = Font("SystemFont_Med3", "GameFontNormal")

local function GetAtlas(atlas)
	return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
end

-- Sets a spellbook atlas, or a plain color when this client doesn't have it
local function SetArt(texture, atlas, r, g, b, a)
	if GetAtlas(atlas) then
		texture:SetAtlas(atlas)
	else
		texture:SetColorTexture(r or 0, g or 0, b or 0, a or 0)
	end
end

local function CreateText(parent, font)
	local text = parent:CreateFontString(nil, "ARTWORK", font)
	text:SetTextColor(FONT_COLOR:GetRGB())
	text:SetJustifyH("LEFT")
	return text
end

---------------------------------------------------------------------------
-- Window and book
---------------------------------------------------------------------------

local hasPortraitTemplate = C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo("PortraitFrameTemplate")
local window = CreateFrame("Frame", "WoWNotesMainFrame", UIParent,
	hasPortraitTemplate and "PortraitFrameTemplate" or "BasicFrameTemplate")
window:SetSize(900, 600)
window:SetPoint("CENTER")
window:SetFrameStrata("HIGH")
window:SetToplevel(true)
window:SetClampedToScreen(true)
window:EnableMouse(true)
window:SetMovable(true)
window:RegisterForDrag("LeftButton")
window:SetScript("OnDragStart", window.StartMoving)
window:SetScript("OnDragStop", window.StopMovingOrSizing)
window:Hide()
tinsert(UISpecialFrames, "WoWNotesMainFrame") -- close with Escape

if window.SetTitle then
	window:SetTitle("WoW Notes")
elseif window.TitleText then
	window.TitleText:SetText("WoW Notes")
end
if window.SetPortraitToAsset then
	window:SetPortraitToAsset(ns.ICON)
end

local book = CreateFrame("Frame", nil, window)
book:SetPoint("TOPLEFT", 2, -21)
book:SetPoint("BOTTOMRIGHT", -2, 2)

local topBar = book:CreateTexture(nil, "BACKGROUND", nil, 1)
topBar:SetPoint("TOPLEFT")
topBar:SetPoint("TOPRIGHT")
topBar:SetHeight(54)
SetArt(topBar, "spellbook-background-evergreen-header", 0.12, 0.09, 0.06, 1)

local leftBG = book:CreateTexture(nil, "BACKGROUND", nil, 1)
leftBG:SetPoint("TOPLEFT", 0, -51)
leftBG:SetPoint("BOTTOMRIGHT", book, "BOTTOM")
SetArt(leftBG, "spellbook-background-evergreen-left", 0.82, 0.72, 0.54, 1)

local rightBG = book:CreateTexture(nil, "BACKGROUND", nil, 1)
rightBG:SetPoint("TOPLEFT", book, "TOP", 0, -51)
rightBG:SetPoint("BOTTOMRIGHT")
SetArt(rightBG, "spellbook-background-evergreen-right", 0.82, 0.72, 0.54, 1)

-- Bookmark ribbon hanging over the spine, scaled down with the book
local ribbonInfo = GetAtlas("spellbook-background-evergreen-ribbon")
if ribbonInfo then
	local ribbon = book:CreateTexture(nil, "BACKGROUND", nil, 2)
	ribbon:SetAtlas("spellbook-background-evergreen-ribbon")
	book:SetScript("OnSizeChanged", function(self, width, height)
		local scale = (height - 51) / BLIZZARD_BOOK_HEIGHT
		ribbon:SetSize(ribbonInfo.width * scale, ribbonInfo.height * scale)
		ribbon:ClearAllPoints()
		ribbon:SetPoint("TOPRIGHT", leftBG, "TOPRIGHT", 62 * scale, 0)
	end)
end

local leftPage = CreateFrame("Frame", nil, book)
leftPage:SetAllPoints(leftBG)

local rightPage = CreateFrame("Frame", nil, book)
rightPage:SetAllPoints(rightBG)

-- Page title with the ornate divider underneath, like the spellbook's "General"
local function CreateHeader(page)
	local header = CreateFrame("Frame", nil, page)
	header:SetPoint("TOPLEFT", PAGE_MARGIN + 12, -34)
	header:SetPoint("RIGHT", -PAGE_MARGIN, 0)
	header:SetHeight(51)

	if GetAtlas("spellbook-list-backplate") then
		local backplate = header:CreateTexture(nil, "BACKGROUND")
		backplate:SetAtlas("spellbook-list-backplate")
		backplate:SetAlpha(0.65)
		backplate:SetSize(416, 106)
		backplate:SetPoint("LEFT", -85, 10)
	end

	header.Text = CreateText(header, HEADER_FONT)
	header.Text:SetPoint("TOPLEFT", -8, 0)
	header.Text:SetPoint("BOTTOMRIGHT", 0, 11)
	header.Text:SetWordWrap(false)

	local divider = header:CreateTexture(nil, "ARTWORK")
	divider:SetHeight(11)
	divider:SetPoint("BOTTOMLEFT", -32, 0)
	divider:SetPoint("BOTTOMRIGHT")
	SetArt(divider, "spellbook-divider", FONT_COLOR.r, FONT_COLOR.g, FONT_COLOR.b, 0.4)
	return header
end

local selected -- index of the note shown on the right page
local page = 1 -- page of the note list

---------------------------------------------------------------------------
-- Top bar buttons
---------------------------------------------------------------------------

local deleteButton = CreateFrame("Button", nil, book, "UIPanelButtonTemplate")
deleteButton:SetSize(100, 24)
deleteButton:SetPoint("TOPRIGHT", -24, -14)
deleteButton:SetText("Delete")

local newButton = CreateFrame("Button", nil, book, "UIPanelButtonTemplate")
newButton:SetSize(110, 24)
newButton:SetPoint("RIGHT", deleteButton, "LEFT", -6, 0)
newButton:SetText("New Note")

---------------------------------------------------------------------------
-- Left page: note list
---------------------------------------------------------------------------

local listHeader = CreateHeader(leftPage)
listHeader.Text:SetText("Notes")

local listArea = CreateFrame("Frame", nil, leftPage)
listArea:SetPoint("TOPLEFT", listHeader, "BOTTOMLEFT", 0, -18)
listArea:SetPoint("BOTTOMRIGHT", -PAGE_MARGIN, 70)

local listEmpty = CreateText(listArea, SMALL_FONT)
listEmpty:SetPoint("TOPLEFT", 4, -4)
listEmpty:SetAlpha(0.7)
listEmpty:SetText("No notes yet. Click New Note to write your first one.")

-- Paging controls in the bottom corner, as in the spellbook
local nextButton = CreateFrame("Button", nil, leftPage)
nextButton:SetSize(32, 32)
nextButton:SetPoint("BOTTOMRIGHT", -PAGE_MARGIN, 34)
nextButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
nextButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
nextButton:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
nextButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

local prevButton = CreateFrame("Button", nil, leftPage)
prevButton:SetSize(32, 32)
prevButton:SetPoint("RIGHT", nextButton, "LEFT", -4, 0)
prevButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
prevButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
prevButton:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
prevButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

local pageText = CreateText(leftPage, SMALL_FONT)
pageText:SetPoint("RIGHT", prevButton, "LEFT", -8, 0)

-- List rows look like spellbook entries: framed icon, name and a small line underneath
local rows = {}

local function UpdateRowHighlight(row)
	local lit = row.isSelected or row:IsMouseOver()
	row.backplate:SetAlpha(lit and 1 or 0.25)
	row.iconHighlight:SetAlpha(row.isSelected and 0.65 or (lit and 0.35 or 0))
end

local function GetRow(i)
	local row = rows[i]
	if row then
		return row
	end
	row = CreateFrame("Button", nil, listArea)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
	row:SetPoint("RIGHT")

	row.backplate = row:CreateTexture(nil, "BACKGROUND")
	row.backplate:SetPoint("TOPLEFT", -14, 4)
	row.backplate:SetPoint("BOTTOMRIGHT", 10, -8)
	SetArt(row.backplate, "spellbook-item-backplate", FONT_COLOR.r, FONT_COLOR.g, FONT_COLOR.b, 0.12)

	local iconFrame = CreateFrame("Frame", nil, row)
	iconFrame:SetSize(40, 40)
	iconFrame:SetPoint("LEFT", 4, 0)

	local icon = iconFrame:CreateTexture(nil, "ARTWORK")
	icon:SetSize(36, 36)
	icon:SetPoint("CENTER")
	icon:SetTexture(ns.ICON)
	if GetAtlas("spellbook-item-spellicon-mask") then
		local mask = iconFrame:CreateMaskTexture()
		mask:SetAtlas("spellbook-item-spellicon-mask")
		mask:SetAllPoints(icon)
		icon:AddMaskTexture(mask)
	end

	if GetAtlas("spellbook-item-iconframe") then
		local border = iconFrame:CreateTexture(nil, "OVERLAY", nil, 1)
		border:SetAtlas("spellbook-item-iconframe")
		border:SetPoint("TOPLEFT", -11, 1)
		border:SetPoint("BOTTOMRIGHT", 1, -7)
	end

	row.iconHighlight = iconFrame:CreateTexture(nil, "OVERLAY", nil, 2)
	row.iconHighlight:SetAllPoints()
	row.iconHighlight:SetBlendMode("ADD")
	SetArt(row.iconHighlight, "spellbook-item-iconframe-hover", 1, 1, 1, 0.3)

	row.name = CreateText(row, NAME_FONT)
	row.name:SetPoint("BOTTOMLEFT", iconFrame, "RIGHT", 10, 1)
	row.name:SetPoint("RIGHT")
	row.name:SetWordWrap(false)

	row.sub = CreateText(row, SMALL_FONT)
	row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
	row.sub:SetPoint("RIGHT")
	row.sub:SetWordWrap(false)

	row:SetScript("OnEnter", UpdateRowHighlight)
	row:SetScript("OnLeave", UpdateRowHighlight)
	row:SetScript("OnClick", function(self)
		ns.SelectNote(self.index)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	end)
	rows[i] = row
	return row
end

local function GetRowsPerPage()
	return math.max(1, floor(listArea:GetHeight() / ROW_HEIGHT))
end

local function RefreshList()
	local notes = ns.GetNotes()
	local perPage = GetRowsPerPage()
	local numPages = math.max(1, ceil(#notes / perPage))
	page = math.min(math.max(page, 1), numPages)

	local first = (page - 1) * perPage
	for i = 1, perPage do
		local index = first + i
		local note = notes[index]
		local row = GetRow(i)
		if note then
			row.index = index
			row.isSelected = index == selected
			row.name:SetText(ns.GetTitle(note))
			local preview = ns.GetPreview(note)
			row.sub:SetText(preview ~= "" and preview or ns.FormatAge(note.edited))
			UpdateRowHighlight(row)
			row:Show()
		else
			row:Hide()
		end
	end
	for i = perPage + 1, #rows do
		rows[i]:Hide()
	end

	listEmpty:SetShown(#notes == 0)
	pageText:SetText(("Page %d/%d"):format(page, numPages))
	prevButton:SetEnabled(page > 1)
	nextButton:SetEnabled(page < numPages)
	deleteButton:SetEnabled(selected ~= nil)
end

local function TurnPage(delta)
	page = page + delta
	RefreshList()
	PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
end
prevButton:SetScript("OnClick", function() TurnPage(-1) end)
nextButton:SetScript("OnClick", function() TurnPage(1) end)
listArea:EnableMouseWheel(true)
listArea:SetScript("OnMouseWheel", function(self, delta)
	local numPages = math.max(1, ceil(#ns.GetNotes() / GetRowsPerPage()))
	if (delta > 0 and page > 1) or (delta < 0 and page < numPages) then
		TurnPage(-delta)
	end
end)

---------------------------------------------------------------------------
-- Right page: the selected note
---------------------------------------------------------------------------

-- Everything shown while a note is selected
local editor = CreateFrame("Frame", nil, rightPage)
editor:SetAllPoints()

local noteHeader = CreateHeader(editor)
noteHeader.Text:SetPoint("BOTTOMRIGHT", -110, 11) -- leave room for the edited time

local editedText = CreateText(noteHeader, SMALL_FONT)
editedText:SetPoint("BOTTOMRIGHT", 0, 16)
editedText:SetJustifyH("RIGHT")
editedText:SetAlpha(0.8)

-- No scroll bar on the page; the mouse wheel and the cursor scroll the text
local editScroll = CreateFrame("ScrollFrame", nil, editor)
editScroll:SetPoint("TOPLEFT", noteHeader, "BOTTOMLEFT", -4, -16)
editScroll:SetPoint("BOTTOMRIGHT", -PAGE_MARGIN, 44)
editScroll:EnableMouse(true)
editScroll:EnableMouseWheel(true)
editScroll:SetScript("OnMouseWheel", function(self, delta)
	local scroll = self:GetVerticalScroll() - delta * 30
	self:SetVerticalScroll(math.max(0, math.min(scroll, self:GetVerticalScrollRange())))
end)

local editBox = CreateFrame("EditBox", nil, editScroll)
editBox:SetMultiLine(true)
editBox:SetAutoFocus(false)
editBox:SetFontObject(TEXT_FONT)
editBox:SetTextColor(FONT_COLOR:GetRGB())
editBox:SetSpacing(4)
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

local placeholder = CreateText(editBox, TEXT_FONT)
placeholder:SetPoint("TOPLEFT")
placeholder:SetAlpha(0.5)
placeholder:SetText("Start writing. The first line becomes the title.")

editScroll:SetScript("OnSizeChanged", function(self, width, height)
	editBox:SetWidth(width)
	editBox:SetHeight(height) -- so clicking anywhere on the page focuses the box
end)
editScroll:SetScript("OnMouseDown", function()
	editBox:SetFocus()
end)

-- Shown instead of the editor when no note is selected
local emptyState = CreateFrame("Frame", nil, rightPage)
emptyState:SetAllPoints()

local emptyIcon = emptyState:CreateTexture(nil, "ARTWORK")
emptyIcon:SetSize(56, 56)
emptyIcon:SetPoint("CENTER", 0, 30)
emptyIcon:SetTexture(ns.ICON)
emptyIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
emptyIcon:SetDesaturated(true)
emptyIcon:SetAlpha(0.3)

local emptyText = CreateText(emptyState, NAME_FONT)
emptyText:SetPoint("TOP", emptyIcon, "BOTTOM", 0, -14)
emptyText:SetJustifyH("CENTER")
emptyText:SetAlpha(0.7)
emptyText:SetText("Select a note, or start a new one")

local function UpdateEditor()
	local note = selected and ns.GetNotes()[selected]
	editor:SetShown(note ~= nil)
	emptyState:SetShown(note == nil)
	if note then
		noteHeader.Text:SetText(ns.GetTitle(note))
		editedText:SetText(ns.FormatAge(note.edited))
		placeholder:SetShown(note.text == "")
	end
end

function ns.SelectNote(index)
	local notes = ns.GetNotes()
	selected = notes[index] and index or nil
	if selected then
		page = ceil(selected / GetRowsPerPage()) -- keep the selected note in view
	end
	editBox:ClearFocus()
	editBox:SetText(selected and notes[selected].text or "")
	editBox:SetCursorPosition(0)
	editScroll:SetVerticalScroll(0)
	UpdateEditor()
	RefreshList()
end

-- Save while typing; the header and list follow along
editBox:SetScript("OnTextChanged", function(self, userInput)
	if userInput and selected then
		ns.SetNoteText(selected, self:GetText())
		UpdateEditor()
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
	PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN)
end)
window:SetScript("OnHide", function()
	PlaySound(SOUNDKIT.IG_SPELLBOOK_CLOSE)
end)

function ns.RefreshWindow()
	if window:IsShown() then
		RefreshList()
	end
end

function ns.ToggleWindow()
	window:SetShown(not window:IsShown())
end
