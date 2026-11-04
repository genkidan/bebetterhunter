local _, addon = ...
local HALO = "Interface\\AddOns\\BeBetterHunter\\Media\\Halo"
local tiles, overlays, halos, overlayCount = {}, {}, {}, 0

local function clear()
    for _, texture in ipairs(tiles) do texture:Hide() end
    for _, texture in ipairs(overlays) do texture:Hide() end
    for _, texture in ipairs(halos) do texture:Hide() end
    overlayCount = 0
end

local function fileSize(pixels)
    local size = 16
    while size < pixels do size = size * 2 end
    return size
end

local function drawOverlay(canvas, key, files, layerW, layerH, tileW, tileH, drawW, drawH)
    local width, height, offsetX, offsetY = key:match("^(%d+):(%d+):(%-?%d+):(%-?%d+)$")
    width, height, offsetX, offsetY = tonumber(width), tonumber(height), tonumber(offsetX), tonumber(offsetY)
    if not (width and height and offsetX and offsetY) then return end
    local ids = {}
    for id in files:gmatch("%d+") do ids[#ids + 1] = tonumber(id) end
    local columns = math.ceil(width / tileW)
    for row = 0, math.ceil(height / tileH) - 1 do
        for column = 0, columns - 1 do
            local id = ids[row * columns + column + 1]
            if id then
                local pixelW = math.min(tileW, width - column * tileW)
                local pixelH = math.min(tileH, height - row * tileH)
                overlayCount = overlayCount + 1
                local texture = overlays[overlayCount]
                if not texture then
                    texture = canvas:CreateTexture(nil, "OVERLAY", nil, 0)
                    overlays[overlayCount] = texture
                end
                texture:ClearAllPoints()
                texture:SetPoint("TOPLEFT", canvas, "TOPLEFT",
                    (offsetX + column * tileW) * drawW / layerW,
                    -(offsetY + row * tileH) * drawH / layerH)
                texture:SetSize(pixelW * drawW / layerW, pixelH * drawH / layerH)
                texture:SetTexCoord(0, pixelW / fileSize(pixelW), 0, pixelH / fileSize(pixelH))
                texture:SetTexture(id)
                texture:Show()
            end
        end
    end
end

local function mapForArea(areaID)
    if not (areaID and QuestieLoader and QuestieLoader.ImportModule) then return nil end
    local ok, zoneDB = pcall(QuestieLoader.ImportModule, QuestieLoader, "ZoneDB")
    if not (ok and zoneDB and zoneDB.GetUiMapIdByAreaId) then return nil end
    local okMap, mapID = pcall(zoneDB.GetUiMapIdByAreaId, zoneDB, areaID)
    if okMap and type(mapID) == "number" and mapID > 0 then return mapID end
end

function addon.ShowMap(name, npcID, preferredArea)
    local canvas, title, hint = addon.mapCanvas, addon.mapTitle, addon.mapHint
    clear()
    title:SetText(name or "Carte")
    hint:SetText("")
    if not (QuestieDB and QuestieDB.QueryNPCSingle) then
        hint:SetText("Questie est nécessaire pour afficher les emplacements précis.")
        return
    end
    local ok, spawns = pcall(QuestieDB.QueryNPCSingle, npcID, "spawns")
    if not (ok and type(spawns) == "table") then
        hint:SetText("Aucune coordonnée connue pour cette bête.")
        return
    end
    local area = preferredArea and spawns[preferredArea] and preferredArea or nil
    if not area then
        for key, points in pairs(spawns) do
            if type(points) == "table" and #points > 0 then area = key; break end
        end
    end
    local points = area and spawns[area]
    local mapID = mapForArea(area)
    if not (mapID and points and C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures) then
        hint:SetText("Aperçu de carte indisponible pour cette zone.")
        return
    end
    local okLayer, layers = pcall(C_Map.GetMapArtLayers, mapID)
    local okTextures, textures = pcall(C_Map.GetMapArtLayerTextures, mapID, 1)
    local layer = okLayer and type(layers) == "table" and layers[1]
    if not (layer and okTextures and type(textures) == "table" and #textures > 0) then
        hint:SetText("Aperçu de carte indisponible pour cette zone.")
        return
    end
    local layerW, layerH = layer.layerWidth or 1002, layer.layerHeight or 668
    local tileW, tileH = layer.tileWidth or 256, layer.tileHeight or 256
    if layerW <= 0 or layerH <= 0 or tileW <= 0 or tileH <= 0 then return end
    local drawW = math.min(520, 240 * layerW / layerH)
    local drawH = math.min(240, drawW * layerH / layerW)
    canvas:SetSize(drawW, drawH)
    local columns = math.max(1, math.ceil(layerW / tileW))
    for i, textureID in ipairs(textures) do
        local tile = tiles[i]
        if not tile then tile = canvas:CreateTexture(nil, "ARTWORK"); tiles[i] = tile end
        local column, row = (i - 1) % columns, math.floor((i - 1) / columns)
        tile:ClearAllPoints()
        tile:SetPoint("TOPLEFT", canvas, "TOPLEFT", column * tileW * drawW / layerW,
            -row * tileH * drawH / layerH)
        tile:SetSize(math.min(tileW, layerW - column * tileW) * drawW / layerW,
            math.min(tileH, layerH - row * tileH) * drawH / layerH)
        tile:SetTexture(textureID)
        tile:Show()
    end
    local okArt, artID = false, nil
    if C_Map.GetMapArtID then okArt, artID = pcall(C_Map.GetMapArtID, mapID) end
    if not okArt then artID = nil end
    local mapOverlays = artID and BeBetterHunterMapOverlays and BeBetterHunterMapOverlays[artID]
    if mapOverlays then
        for key, files in pairs(mapOverlays) do
            drawOverlay(canvas, key, files, layerW, layerH, tileW, tileH, drawW, drawH)
        end
    end
    if C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures then
        local okExplored, explored = pcall(C_MapExplorationInfo.GetExploredMapTextures, mapID)
        if okExplored and type(explored) == "table" then
            for _, info in ipairs(explored) do
                if type(info.fileDataIDs) == "table" and info.textureWidth and info.textureHeight
                    and info.offsetX and info.offsetY then
                    local key = table.concat({info.textureWidth, info.textureHeight,
                        info.offsetX, info.offsetY}, ":")
                    if not (mapOverlays and mapOverlays[key]) then
                        drawOverlay(canvas, key, table.concat(info.fileDataIDs, ","),
                            layerW, layerH, tileW, tileH, drawW, drawH)
                    end
                end
            end
        end
    end
    local count = 0
    for _, point in ipairs(points) do
        local x, y = tonumber(point[1]), tonumber(point[2])
        if x and y and x >= 0 and x <= 100 and y >= 0 and y <= 100 then
            count = count + 1
            local halo = halos[count]
            if not halo then
                halo = CreateFrame("Button", nil, canvas)
                halo.glow = halo:CreateTexture(nil, "OVERLAY", nil, 2)
                halo.glow:SetAllPoints()
                halo.glow:SetTexture(HALO)
                halo:SetScript("OnEnter", function(self)
                    if not GameTooltip then return end
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(self.npcName)
                    GameTooltip:AddLine(string.format("%.1f, %.1f", self.x, self.y), 1, 0.78, 0.35)
                    GameTooltip:Show()
                end)
                halo:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
                halos[count] = halo
            end
            halo:ClearAllPoints()
            halo:SetPoint("CENTER", canvas, "TOPLEFT", x * drawW / 100, -y * drawH / 100)
            halo:SetSize(34, 34)
            halo.npcName, halo.x, halo.y = name, x, y
            halo:Show()
        end
    end
    hint:SetText(count > 0 and (count .. " emplacement(s) connu(s) · halos indicatifs") or
        "Aucune coordonnée exploitable dans Questie.")
end
