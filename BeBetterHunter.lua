local _, addon = ...
local WHITE = "Interface\\Buttons\\WHITE8X8"
local GOLD, MUTED = {1, 0.78, 0.35}, {0.68, 0.72, 0.78}
local frame, abilityPane, rarePane, searchBox, listScroll, listContent
local teacherScroll, teacherContent, abilityTitle, familyText, rankLabel
local listRows, teacherRows, rankButtons = {}, {}, {}
local selectedAbility, selectedRank, selectedRare, mode = 1, 1, 1, "abilities"

local function label(parent, font, x, y, width, color)
    local value = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    value:SetPoint("TOPLEFT", x, y)
    value:SetWidth(width)
    value:SetJustifyH("LEFT")
    value:SetJustifyV("TOP")
    if color then value:SetTextColor(unpack(color)) end
    return value
end

local function panel(parent, x, y, width, height)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetPoint("TOPLEFT", x, y)
    box:SetSize(width, height)
    box:SetBackdrop({bgFile=WHITE, edgeFile=WHITE, edgeSize=1,
        insets={left=1, right=1, top=1, bottom=1}})
    box:SetBackdropColor(0.045, 0.065, 0.09, 0.97)
    box:SetBackdropBorderColor(0.29, 0.33, 0.38, 0.9)
    return box
end

local function button(parent, width, height, caption)
    local value = CreateFrame("Button", nil, parent, "BackdropTemplate")
    value:SetSize(width, height)
    value:SetBackdrop({bgFile=WHITE, edgeFile=WHITE, edgeSize=1,
        insets={left=1, right=1, top=1, bottom=1}})
    value:SetBackdropColor(0.09, 0.12, 0.16, 1)
    value:SetBackdropBorderColor(0.25, 0.32, 0.38, 1)
    value:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    value.caption = label(value, "GameFontHighlightSmall", 8, -5, width - 16)
    value.caption:SetText(caption or "")
    return value
end

local function scroll(parent, x, y, width, height)
    local value = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    value:SetPoint("TOPLEFT", x, y)
    value:SetSize(width, height)
    local content = CreateFrame("Frame", nil, value)
    content:SetSize(width - 22, 1)
    value:SetScrollChild(content)
    return value, content
end

local function showTeachers()
    local rank = addon.data[selectedAbility].ranks[selectedRank]
    rankLabel:SetText("Rang " .. rank[1] .. " · Familier niveau " .. rank[2] ..
        (rank[3] and (" · " .. rank[3] .. " points") or " · coût non confirmé"))
    local teachers = rank[4]
    for i, beast in ipairs(teachers) do
        local row = teacherRows[i]
        if not row then
            row = button(teacherContent, 507, 35)
            teacherRows[i] = row
            row:SetScript("OnClick", function(self) addon.ShowMap(self.name, self.npcID) end)
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -((i - 1) * 38))
        row.npcID, row.name = beast[1], beast[2]
        row.caption:SetText((beast[6] and "|cffffcc55★ |r" or "") .. beast[2] ..
            " |cffabb8c6niv. " .. beast[3] ..
            (beast[4] ~= beast[3] and ("–" .. beast[4]) or "") ..
            " · " .. beast[5] .. "|r")
        row:Show()
    end
    for i = #teachers + 1, #teacherRows do teacherRows[i]:Hide() end
    teacherContent:SetHeight(math.max(1, #teachers * 38))
    teacherScroll:SetVerticalScroll(0)
    if #teachers > 0 then
        addon.ShowMap(teachers[1][2], teachers[1][1])
    else
        addon.ShowMap("Aucune bête répertoriée pour ce rang", 0)
        addon.mapHint:SetText("Ce rang peut venir d'un maître, d'une progression automatique ou d'une source inconnue.")
    end
end

local function showAbility(index)
    selectedAbility, selectedRank = index, 1
    local ability = addon.data[index]
    abilityTitle:SetText(ability.name)
    familyText:SetText("Familles : " .. ability.families)
    for i, rank in ipairs(ability.ranks) do
        local value = rankButtons[i]
        if not value then
            value = button(abilityPane, 62, 27)
            rankButtons[i] = value
            value:SetScript("OnClick", function(self)
                selectedRank = self.rankIndex
                showTeachers()
            end)
        end
        value.rankIndex = i
        value:ClearAllPoints()
        value:SetPoint("TOPLEFT", 12 + ((i - 1) % 8) * 65,
            -91 - math.floor((i - 1) / 8) * 30)
        value.caption:SetText("Rang " .. rank[1])
        value:Show()
    end
    for i = #ability.ranks + 1, #rankButtons do rankButtons[i]:Hide() end
    showTeachers()
end

local function showRare(index)
    selectedRare = index
    local rare = addon.rares[index]
    rarePane.title:SetText(rare[2] .. (rare[7] and " |cffffcc55★ élite rare|r" or " |cffffcc55★ rare|r"))
    rarePane.details:SetText("Niveau " .. rare[3] ..
        (rare[4] ~= rare[3] and ("–" .. rare[4]) or "") .. " · " .. rare[5])
    addon.ShowMap(rare[2], rare[1], rare[6])
end

local function refreshList()
    local source = mode == "abilities" and addon.data or addon.rares
    local query = string.lower(searchBox:GetText() or "")
    local matches = {}
    for i, item in ipairs(source) do
        local name = mode == "abilities" and item.name or item[2]
        local place = mode == "rares" and item[5] or ""
        if query == "" or string.find(string.lower(name .. " " .. place), query, 1, true) then
            matches[#matches + 1] = i
        end
    end
    if mode == "rares" then
        table.sort(matches, function(a, b) return source[a][2] < source[b][2] end)
    end
    for position, index in ipairs(matches) do
        local row = listRows[position]
        if not row then
            row = button(listContent, 226, 37)
            listRows[position] = row
            row:SetScript("OnClick", function(self)
                if mode == "abilities" then showAbility(self.dataIndex) else showRare(self.dataIndex) end
            end)
        end
        row.dataIndex = index
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(position - 1) * 40)
        local item = source[index]
        row.caption:SetText(mode == "abilities" and
            (item.name .. " |cffabb8c6(" .. #item.ranks .. " rangs)|r") or
            ("|cffffcc55★|r " .. item[2] .. " |cffabb8c6niv. " .. item[3] .. "|r"))
        row:Show()
    end
    for i = #matches + 1, #listRows do listRows[i]:Hide() end
    listContent:SetHeight(math.max(1, #matches * 40))
    listScroll:SetVerticalScroll(0)
end

local function setMode(value)
    mode = value
    abilityPane:SetShown(value == "abilities")
    rarePane:SetShown(value == "rares")
    frame.tabAbilities.caption:SetTextColor(unpack(value == "abilities" and GOLD or MUTED))
    frame.tabRares.caption:SetTextColor(unpack(value == "rares" and GOLD or MUTED))
    local mapTop = value == "abilities" and -439 or -205
    addon.mapTitle:ClearAllPoints()
    addon.mapTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 301, mapTop)
    addon.mapCanvas:ClearAllPoints()
    addon.mapCanvas:SetPoint("TOP", frame, "TOP", 125, mapTop - 26)
    addon.mapHint:ClearAllPoints()
    addon.mapHint:SetPoint("TOPLEFT", frame, "TOPLEFT", 301, mapTop - 277)
    searchBox:SetText("")
    refreshList()
    if value == "abilities" then showAbility(selectedAbility) else showRare(selectedRare) end
end

local function createUI()
    frame = CreateFrame("Frame", "BeBetterHunterFrame", UIParent, "BackdropTemplate")
    frame:SetSize(850, 760)
    frame:SetPoint("CENTER")
    if UIParent:GetHeight() < 800 then
        frame:SetScale(math.min(1, (UIParent:GetHeight() - 40) / 760))
    end
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({bgFile=WHITE, edgeFile=WHITE, edgeSize=1,
        insets={left=1, right=1, top=1, bottom=1}})
    frame:SetBackdropColor(0.02, 0.035, 0.055, 0.98)
    frame:SetBackdropBorderColor(unpack(GOLD))
    frame:Hide()
    label(frame, "GameFontNormalLarge", 17, -14, 500, GOLD):SetText("BeBetterHunter")
    label(frame, "GameFontDisableSmall", 19, -39, 600):SetText(
        "Capacités de familiers et lieux d'apprivoisement · WoW Forever")
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    frame.tabAbilities = button(frame, 118, 27, "Capacités")
    frame.tabAbilities:SetPoint("TOPLEFT", 18, -67)
    frame.tabAbilities:SetScript("OnClick", function() setMode("abilities") end)
    frame.tabRares = button(frame, 118, 27, "Familiers rares")
    frame.tabRares:SetPoint("TOPLEFT", 140, -67)
    frame.tabRares:SetScript("OnClick", function() setMode("rares") end)
    panel(frame, 17, -103, 263, 637)
    searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    searchBox:SetSize(226, 24)
    searchBox:SetPoint("TOPLEFT", 31, -116)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", refreshList)
    searchBox:SetScript("OnEscapePressed", searchBox.ClearFocus)
    label(frame, "GameFontDisableSmall", 31, -142, 230):SetText("Rechercher un nom ou une zone")
    listScroll, listContent = scroll(frame, 28, -168, 234, 552)

    abilityPane = panel(frame, 289, -103, 544, 637)
    abilityTitle = label(abilityPane, "GameFontNormalLarge", 12, -11, 510, GOLD)
    familyText = label(abilityPane, "GameFontHighlightSmall", 12, -39, 510, MUTED)
    familyText:SetHeight(42)
    rankLabel = label(abilityPane, "GameFontNormal", 12, -160, 510)
    teacherScroll, teacherContent = scroll(abilityPane, 12, -188, 511, 135)

    rarePane = panel(frame, 289, -103, 544, 637)
    rarePane.title = label(rarePane, "GameFontNormalLarge", 12, -11, 510, GOLD)
    rarePane.details = label(rarePane, "GameFontHighlight", 12, -43, 510)
    label(rarePane, "GameFontDisableSmall", 12, -78, 510):SetText(
        "Les halos montrent des points connus, pas une présence actuelle.")

    local mapLayer = CreateFrame("Frame", nil, frame)
    mapLayer:SetAllPoints(frame)
    mapLayer:SetFrameLevel(rarePane:GetFrameLevel() + 2)
    addon.mapTitle = label(mapLayer, "GameFontNormal", 301, -439, 510, GOLD)
    addon.mapCanvas = CreateFrame("Frame", nil, mapLayer)
    addon.mapCanvas:SetPoint("TOP", frame, "TOP", 125, -465)
    addon.mapCanvas:SetSize(360, 240)
    addon.mapHint = label(mapLayer, "GameFontDisableSmall", 301, -716, 510, MUTED)
    setMode("abilities")
end

SLASH_BEBETTERHUNTER1 = "/bbh"
SLASH_BEBETTERHUNTER2 = "/bebetterhunter"
SlashCmdList.BEBETTERHUNTER = function()
    if not frame then createUI() end
    frame:SetShown(not frame:IsShown())
end
