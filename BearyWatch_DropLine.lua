local addon = _G.BearyWatch
if type(addon) ~= "table" or type(addon.environment) ~= "table" then
  error("BearyWatch shared environment was not initialized.")
end
setfenv(1, addon.environment)

local rosterHeaders = {}
local armoryLinkPopup
local armoryLinkEdit
local armoryContextMenu
local function updateRosterVisibleRows(scrollOffset)
  if not rosterScroll then
    return
  end
  local top = scrollOffset or rosterScroll:GetVerticalScroll()
  local bottom = top + rosterScroll:GetHeight()
  for _, row in ipairs(rosterRows) do
    local visible = row.contentTop and row.contentBottom >= top and row.contentTop <= bottom
    if visible and not row:IsShown() then
      row:Show()
    elseif not visible and row:IsShown() then
      row:Hide()
    end
  end
end

local rosterRightColumns = {
  { key = "count", sortKey = "alts", width = 112 },
  { key = "status", width = 128 },
  { key = "pr", width = 74 },
  { key = "gp", width = 68 },
  { key = "ep", width = 68 },
}

local function encodeURLPath(value)
  local encoded = {}
  for index = 1, #value do
    local byte = value:byte(index)
    if (byte >= 48 and byte <= 57) or (byte >= 65 and byte <= 90) or
      (byte >= 97 and byte <= 122) or byte == 45 or byte == 46 or
      byte == 95 or byte == 126 then
      encoded[#encoded + 1] = string.char(byte)
    else
      encoded[#encoded + 1] = ("%%%02X"):format(byte)
    end
  end
  return table.concat(encoded)
end

local function getArmoryServerId()
  local realm = type(GetRealmName) == "function" and GetRealmName()
  if type(realm) ~= "string" then
    return nil
  end
  realm = realm:lower()
  local shard = realm:match("x%s*(%d+)") or realm:match("х%s*(%d+)")
  return shard and "x" .. shard or nil
end

local function showArmoryLink(characterName)
  local serverId = getArmoryServerId()
  if not serverId then
    setStatus("Не удалось определить сервер для ссылки на Армори.")
    return
  end
  if not armoryLinkPopup then
    armoryLinkPopup = makePanel(UIParent)
    armoryLinkPopup:SetFrameStrata("DIALOG")
    armoryLinkPopup:SetFrameLevel(100)
    armoryLinkPopup:SetSize(430, 112)
    armoryLinkPopup:SetPoint("CENTER", UIParent, "CENTER")
    local title = makeText(armoryLinkPopup, "Ссылка на Армори", "GameFontNormal")
    title:SetPoint("TOPLEFT", armoryLinkPopup, "TOPLEFT", 14, -12)
    title:SetTextColor(0.78, 0.88, 0.92)
    armoryLinkEdit = CreateFrame("EditBox", nil, armoryLinkPopup, "InputBoxTemplate")
    armoryLinkEdit:SetSize(398, 24)
    armoryLinkEdit:SetPoint("TOPLEFT", armoryLinkPopup, "TOPLEFT", 14, -38)
    armoryLinkEdit:SetAutoFocus(false)
    armoryLinkEdit:SetFontObject(GameFontHighlightSmall)
    armoryLinkEdit:SetTextInsets(6, 6, 0, 0)
    armoryLinkEdit:SetScript("OnEscapePressed", function(self)
      self:ClearFocus()
      armoryLinkPopup:Hide()
    end)
    local hint = makeText(armoryLinkPopup,
      "Нажмите Ctrl+C, затем вставьте ссылку в браузер.", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", armoryLinkPopup, "BOTTOMLEFT", 14, 12)
    local closeButton = makeButton(armoryLinkPopup, "Закрыть", 76, 22, function()
      armoryLinkEdit:ClearFocus()
      armoryLinkPopup:Hide()
    end)
    closeButton:SetPoint("BOTTOMRIGHT", armoryLinkPopup, "BOTTOMRIGHT", -12, 8)
  end
  armoryLinkEdit:SetText(("https://sirus.su/base/character/%s/%s"):format(
    serverId, encodeURLPath(characterName)))
  armoryLinkPopup:Show()
  armoryLinkEdit:SetFocus()
  armoryLinkEdit:HighlightText()
end

local function showArmoryContextMenu(characterName)
  if not armoryContextMenu then
    armoryContextMenu = CreateFrame(
      "Frame", "BearyWatchArmoryContextMenu", UIParent, "UIDropDownMenuTemplate")
  end
  UIDropDownMenu_Initialize(armoryContextMenu, function(_, level)
    local info = UIDropDownMenu_CreateInfo()
    local color = playerClassColor(characterName)
    info.text = ("Ссылка на Армори: |cff%02x%02x%02x%s|r"):format(
      math.floor(color.r * 255), math.floor(color.g * 255),
      math.floor(color.b * 255), characterName)
    info.notCheckable = true
    info.func = function()
      showArmoryLink(characterName)
    end
    UIDropDownMenu_AddButton(info, level)
  end, "MENU")
  ToggleDropDownMenu(1, nil, armoryContextMenu, "cursor", 0, 0)
end

addon.ShowArmoryContextMenu = showArmoryContextMenu

local function showCharacterLoot(characterName)
  if type(characterName) ~= "string" or characterName == "" then
    return
  end
  local playerName = addon:GetGroupedName(characterName)
  selectedPlayers = { [playerName] = true }
  selectedPlayer = playerName
  db.profile.timelinePlayers = selectedPlayers
  db.profile.lastSelectedPlayer = playerName
  selectedItemId = nil
  itemSortColumn = "timestamp"
  itemSortDescending = true
  rankSnapshotsDirty = true
  updatePlayerDropdown()
  selectTab("items")
end

function addon:GetGuildMainName(name)
  if type(name) ~= "string" then
    return ""
  end
  local shortName = name:match("^([^%-]+)") or name
  local main = guildMainByName[name:lower()] or guildMainByName[shortName:lower()]
  if (type(main) ~= "string" or main:lower() == shortName:lower()) and
    EPGP and EPGP.GetMain then
    local resolved = EPGP:GetMain(name)
    if type(resolved) == "string" and resolved:lower() ~= name:lower() then
      main = resolved
    else
      resolved = EPGP:GetMain(shortName)
      if type(resolved) == "string" then
        main = resolved
      end
    end
  end
  if type(main) == "string" then
    return main:match("^([^%-]+)") or main
  end
  return shortName
end

function getGuildCharacterGroups()
  local groupsByName = {}
  for _, member in ipairs(bossLoot.guildMembers or {}) do
    local main = addon:GetGuildMainName(member.name)
    local key = main:lower()
    local group = groupsByName[key]
    if not group then
      group = {
        main = main,
        members = {},
        memberOnline = {},
        alts = {},
        frozen = false,
        online = false,
      }
      groupsByName[key] = group
    end
    group.members[member.name:lower()] = member.name
    group.memberOnline[member.name:lower()] = member.online
    group.frozen = group.frozen or member.status == "Фриз"
    group.online = group.online or member.online
  end

  local groups = {}
  for _, group in pairs(groupsByName) do
    for _, memberName in pairs(group.members) do
      if memberName:lower() ~= group.main:lower() then
        table.insert(group.alts, memberName)
      end
    end
    table.sort(group.alts, function(a, b) return a:lower() < b:lower() end)
    group.altCount = #group.alts
    if EPGP and EPGP.GetEPGP then
      local ep, gp = EPGP:GetEPGP(group.main)
      if type(ep) == "number" and type(gp) == "number" then
        group.ep = ep
        group.gp = gp
        group.pr = gp > 0 and ep / gp or nil
      end
    end
    table.insert(groups, group)
  end
  return groups
end

function getGuildAltsForMain(name)
  local main = addon:GetGuildMainName(name)
  if main:lower() ~= (name:match("^([^%-]+)") or name):lower() then
    return {}
  end
  for _, group in ipairs(getGuildCharacterGroups()) do
    if group.main:lower() == main:lower() then
      return group.alts
    end
  end
  return {}
end

function formatGuildAltLines(alts)
  if not alts or #alts == 0 then
    return "", 0
  end
  return table.concat(alts, "\n"), #alts
end

local function shortPlayerName(name)
  return type(name) == "string" and (name:match("^([^%-]+)") or name) or ""
end

local function createDropGrid()
  if not dropLineZeroLine then
    dropLineZeroLine = makeFlatTexture(dropLineChart, "OVERLAY", 0.92, 0.94, 0.96, 0.55)
  end
  for index = 1, 6 do
    if not dropLineYLabels[index] then
      dropLineYLabels[index] = makeText(dropLineChart, "", "GameFontNormalSmall")
      dropLineYLabels[index]:SetTextColor(0.62, 0.67, 0.70)
      dropLineYLabels[index]:SetJustifyH("RIGHT")
    end
  end
  for index = 1, 5 do
    if not dropLineXLabels[index] then
      dropLineXLabels[index] = makeText(dropLineChart, "", "GameFontNormalSmall")
      dropLineXLabels[index]:SetTextColor(0.62, 0.67, 0.70)
      dropLineXLabels[index]:SetJustifyH("CENTER")
    end
    if not dropLineDateLabels[index] then
      dropLineDateLabels[index] = makeText(dropLineChart, "", "GameFontNormalSmall")
      dropLineDateLabels[index]:SetTextColor(0.48, 0.54, 0.58)
      dropLineDateLabels[index]:SetJustifyH("CENTER")
    end
  end
end

local function createDropLineSidebar()
  dropLineSideScroll = CreateFrame("ScrollFrame", nil, dropLineChart)
  dropLineSideScroll:SetPoint("TOPLEFT", dropLineChart, "TOPLEFT", 10, -12)
  dropLineSideScroll:SetPoint("BOTTOMLEFT", dropLineChart, "BOTTOMLEFT", 10, 42)
  dropLineSideScroll:SetWidth(218)
  dropLineSideScroll:EnableMouseWheel(true)
  dropLineSideContent = CreateFrame("Frame", nil, dropLineSideScroll)
  dropLineSideContent:SetWidth(208)
  dropLineSideContent:SetHeight(1)
  dropLineSideScroll:SetScrollChild(dropLineSideContent)
  dropLineSideScroll:SetScript("OnMouseWheel", function(self, delta)
    local maximum = math.max(0, self:GetVerticalScrollRange())
    self:SetVerticalScroll(math.max(0, math.min(maximum,
      self:GetVerticalScroll() - delta * 36)))
  end)

  dropLineSideDivider = makeFlatTexture(dropLineChart, "OVERLAY",
    0.55, 0.60, 0.64, 0.35)
  dropLineSideDivider:SetPoint("TOPLEFT", dropLineChart, "TOPLEFT", 236, -10)
  dropLineSideDivider:SetPoint("BOTTOMLEFT", dropLineChart, "BOTTOMLEFT", 236, 40)
  dropLineSideDivider:SetWidth(1)
end

local function addDropLineSidebarLabel(index, text, color, indent, top, shade, characterName)
  if not dropLineSideRows[index] then
    local row = CreateFrame("Frame", nil, dropLineSideContent)
    row.background = makeFlatTexture(row, "BACKGROUND", 0.12, 0.15, 0.18, 0.55)
    row.background:SetAllPoints(row)
    row.label = makeText(row, "", "GameFontNormalSmall")
    row.label:SetJustifyH("LEFT")
    row.label:SetJustifyV("TOP")
    row.label:SetWordWrap(true)
    row.contextButton = CreateFrame("Button", nil, row)
    row.contextButton:RegisterForClicks("RightButtonUp")
    row.contextButton:SetScript("OnClick", function(self)
      if self.characterName then
        addon.ShowArmoryContextMenu(self.characterName)
      end
    end)
    row.contextButton:SetAllPoints(row)
    dropLineSideRows[index] = row
  end
  local row = dropLineSideRows[index]
  row.contextButton.characterName = characterName
  local label = row.label
  local left = indent or 0
  label:ClearAllPoints()
  label:SetPoint("TOPLEFT", row, "TOPLEFT", left + 5, -2)
  label:SetWidth(math.max(1, 198 - left))
  label:SetText(text)
  label:SetTextColor(color.r, color.g, color.b)
  local rowHeight = math.max(16, math.ceil(label:GetStringHeight()) + 4)
  row:ClearAllPoints()
  row:SetPoint("TOPLEFT", dropLineSideContent, "TOPLEFT", 0, -top)
  row:SetSize(208, rowHeight)
  row.background:SetVertexColor(shade[1], shade[2], shade[3], 0.55)
  row:Show()
  return rowHeight
end

local function updateDropLineSidebar(drops, rangeStart, rangeEnd, visibleCount)
  for _, row in ipairs(dropLineSideRows) do
    row:Hide()
  end
  if visibleCount > 25 then
    dropLineSideContent:SetHeight(1)
    dropLineSideScroll:SetVerticalScroll(0)
    return
  end

  local groupsByMain = {}
  for _, event in ipairs(drops) do
    if event.timestamp >= rangeStart and event.timestamp <= rangeEnd then
      local player = shortPlayerName(event.player)
      local main = addon:GetGuildMainName(event.player)
      local key = main:lower()
      local group = groupsByMain[key]
      if not group then
        group = { main = main, members = {} }
        groupsByMain[key] = group
      end
      local memberKey = player:lower()
      if not group.members[memberKey] then
        group.members[memberKey] = { name = player, events = {} }
      end
      table.insert(group.members[memberKey].events, event)
    end
  end

  local totalsByMain = {}
  for _, event in ipairs(history) do
    if event.kind == "GP" and event.player ~= "GUILD_BANK" and
      event.timestamp >= rangeStart and event.timestamp <= rangeEnd then
      local mainKey = addon:GetGuildMainName(event.player):lower()
      totalsByMain[mainKey] = (totalsByMain[mainKey] or 0) + event.amount
    end
  end

  local groups = {}
  for _, group in pairs(groupsByMain) do
    group.totalGP = totalsByMain[group.main:lower()] or 0
    table.insert(groups, group)
  end
  table.sort(groups, function(a, b)
    return a.main:lower() < b.main:lower()
  end)

  local rowIndex = 0
  local contentHeight = 0
  for groupIndex, group in ipairs(groups) do
    local shade = groupIndex % 2 == 1 and
      { 0.12, 0.15, 0.18 } or { 0.17, 0.20, 0.23 }
    local mainColor = playerClassColor(group.main)
    rowIndex = rowIndex + 1
    contentHeight = contentHeight + addDropLineSidebarLabel(rowIndex,
      ("%s: %+.0fGP"):format(group.main, group.totalGP or 0),
      mainColor, 0, contentHeight, shade, group.main)
    local members = {}
    for _, member in pairs(group.members) do
      table.insert(members, member)
    end
    table.sort(members, function(a, b)
      if a.name:lower() == group.main:lower() then
        return b.name:lower() ~= group.main:lower()
      elseif b.name:lower() == group.main:lower() then
        return false
      end
      return a.name:lower() < b.name:lower()
    end)
    for _, member in ipairs(members) do
      local memberIsAlt = member.name:lower() ~= group.main:lower()
      if memberIsAlt then
        rowIndex = rowIndex + 1
        contentHeight = contentHeight + addDropLineSidebarLabel(rowIndex,
          member.name, playerClassColor(member.name), 8, contentHeight, shade,
          member.name)
      end
      for _, event in ipairs(member.events) do
        rowIndex = rowIndex + 1
        local itemName = getTooltipItemLabel and
          getTooltipItemLabel(event.itemId, "Предмет " .. event.itemId) or
          ("Предмет " .. event.itemId)
        local text = ("%s %+.0f GP"):format(itemName, event.amount)
        contentHeight = contentHeight + addDropLineSidebarLabel(rowIndex, text,
          playerClassColor(member.name), memberIsAlt and 16 or 8,
          contentHeight, shade)
      end
    end
  end
  dropLineSideContent:SetHeight(math.max(1, contentHeight))
  dropLineSideScroll:SetVerticalScroll(0)
end

local function hideDropResetLines(firstUnused)
  for index = firstUnused or 1, #dropLineResetLines do
    dropLineResetLines[index]:Hide()
  end
end

local function drawDropResetLines(rangeStart, rangeEnd, left, bottom, plotWidth, plotHeight)
  hideDropResetLines()
  local parts = date("*t", rangeStart)
  local daysUntilThursday = (5 - parts.wday + 7) % 7
  local firstReset = time({
    year = parts.year,
    month = parts.month,
    day = parts.day + daysUntilThursday,
    hour = 3,
    min = 0,
    sec = 0,
  })
  if firstReset < rangeStart then
    firstReset = firstReset + 7 * 24 * 60 * 60
  end

  local index = 0
  local resetTime = firstReset
  while resetTime <= rangeEnd do
    index = index + 1
    if not dropLineResetLines[index] then
      dropLineResetLines[index] = makeFlatTexture(dropLineChart, "ARTWORK", 1, 0.18, 0.18, 0.85)
    end
    local line = dropLineResetLines[index]
    local x = left + (resetTime - rangeStart) / (rangeEnd - rangeStart) * plotWidth
    line:ClearAllPoints()
    line:SetPoint("BOTTOMLEFT", dropLineChart, "BOTTOMLEFT", x, bottom)
    line:SetSize(2, plotHeight)
    line:Show()
    resetTime = resetTime + 7 * 24 * 60 * 60
  end
  hideDropResetLines(index + 1)
end

local function createDropNode()
  local node = CreateFrame("Button", nil, dropLineChart)
  node:SetSize(9, 9)
  node.texture = node:CreateTexture(nil, "OVERLAY")
  node.texture:SetTexture("Interface\\Buttons\\WHITE8X8")
  node.texture:SetAllPoints(node)
  node.label = makeText(node, "", "GameFontNormalSmall")
  node.label:SetJustifyH("CENTER")
  node.label:SetPoint("BOTTOM", node, "TOP", 0, 3)
  node:EnableMouseWheel(true)
  node:SetScript("OnMouseWheel", function(_, delta)
    local handler = dropLineChart:GetScript("OnMouseWheel")
    if handler then
      handler(dropLineChart, delta)
    end
  end)
  node:SetScript("OnMouseDown", function(_, button)
    local handler = dropLineChart:GetScript("OnMouseDown")
    if handler then
      handler(dropLineChart, button)
    end
  end)
  node:SetScript("OnMouseUp", function(_, button)
    local handler = dropLineChart:GetScript("OnMouseUp")
    if handler then
      handler(dropLineChart, button)
    end
  end)
  node:SetScript("OnEnter", function(self)
    local event = self.event
    if not event then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    local itemName, itemLink
    if GetItemInfo then
      itemName, itemLink = GetItemInfo(event.itemId)
    end
    local itemIcon = getTooltipItemIcon and getTooltipItemIcon(event.itemId)
    local itemLabel = itemLink or itemName or ("Предмет " .. event.itemId)
    if itemIcon then
      itemLabel = ("|T%s:16:16|t %s"):format(itemIcon, itemLabel)
    end
    GameTooltip:AddLine(itemLabel, 1, 1, 1, true)
    local playerColor = playerClassColor(event.player)
    GameTooltip:AddLine("Игрок: " .. shortPlayerName(event.player),
      playerColor.r, playerColor.g, playerColor.b, true)
    local main = addon:GetGuildMainName(event.player)
    if main:lower() ~= shortPlayerName(event.player):lower() then
      GameTooltip:AddLine("Основа: " .. main, 0.78, 0.82, 0.86, true)
    end
    GameTooltip:AddDoubleLine("Изменение GP", ("%+.0f"):format(event.amount),
      COLORS.GP[1], COLORS.GP[2], COLORS.GP[3], 1, 1, 1)
    GameTooltip:AddDoubleLine("Дата", date("%d.%m.%Y %H:%M:%S", event.timestamp), 0.78, 0.82, 0.86, 1, 1, 1)
    GameTooltip:AddDoubleLine("Офицер", event.officer or "Unknown", 0.78, 0.82, 0.86, 1, 1, 1)
    GameTooltip:Show()
  end)
  node:SetScript("OnLeave", GameTooltip_Hide)
  node.nameButton = CreateFrame("Button", nil, dropLineChart)
  node.nameButton:RegisterForClicks("RightButtonUp")
  node.nameButton:SetScript("OnClick", function(self)
    if self.characterName then
      addon.ShowArmoryContextMenu(self.characterName)
    end
  end)
  node.nameButton:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then
      local handler = dropLineChart:GetScript("OnMouseDown")
      if handler then
        handler(dropLineChart, button)
      end
    end
  end)
  node.nameButton:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" then
      local handler = dropLineChart:GetScript("OnMouseUp")
      if handler then
        handler(dropLineChart, button)
      end
    end
  end)
  return node
end

function createDropLineUI()
  if dropLinePanel then
    return
  end
  dropLinePanel = makePanel(window)
  dropLinePanel:SetPoint("TOPLEFT", window, "TOPLEFT", 16, -84)
  dropLinePanel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -16, 48)
  dropLinePanel:Hide()

  local title = makeText(dropLinePanel, "Дроп из журнала EPGP", "GameFontNormal")
  title:SetPoint("TOPLEFT", dropLinePanel, "TOPLEFT", 16, -14)
  title:SetTextColor(COLORS.GP[1], COLORS.GP[2], COLORS.GP[3])
  local hint = makeText(dropLinePanel,
    "Колесико — время; Shift + колесико — GP; красная линия — сброс КД (четверг, 03:00).",
    "GameFontNormalSmall")
  hint:SetPoint("TOPRIGHT", dropLinePanel, "TOPRIGHT", -16, -14)
  hint:SetTextColor(0.58, 0.64, 0.67)
  local autoscale = makeButton(dropLinePanel, "Автомасштаб", 100, 24, function()
    db.profile.dropLineValuePan = 0
    db.profile.dropLineValueZoom = 1
    drawDropLineChart()
  end)
  autoscale:SetPoint("TOPRIGHT", dropLinePanel, "TOPRIGHT", -16, -38)

  dropLineChart = CreateFrame("Frame", nil, dropLinePanel)
  dropLineChart:SetPoint("TOPLEFT", dropLinePanel, "TOPLEFT", 10, -38)
  dropLineChart:SetPoint("BOTTOMRIGHT", dropLinePanel, "BOTTOMRIGHT", -10, 12)
  dropLineChart:EnableMouse(true)
  dropLineChart:EnableMouseWheel(true)
  createDropLineSidebar()
  dropLineChart:SetScript("OnSizeChanged", function()
    drawDropLineChart()
  end)
  dropLineChart:SetScript("OnMouseDown", function(_, button)
    if button ~= "LeftButton" or not dropLineDomainStart or not dropLineDomainEnd then
      return
    end
    local chartLeft, chartBottom = dropLineChart:GetLeft(), dropLineChart:GetBottom()
    if not chartLeft or not chartBottom then
      return
    end
    local scale = UIParent:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    local minTime, maxTime = getHistoryTimeBounds()
    if not minTime or not maxTime then
      return
    end
    local start = db.profile.rangeStart > 0 and db.profile.rangeStart or minTime
    local finish = db.profile.rangeEnd > 0 and db.profile.rangeEnd or maxTime
    local padding = math.max(0, tonumber(db.profile.rangePadding) or 0)
    dropLinePan = {
      cursorX = cursorX / scale - chartLeft,
      cursorY = cursorY / scale - chartBottom,
      start = start,
      finish = finish,
      minTime = minTime - padding,
      maxTime = maxTime + padding,
      plotWidth = math.max(dropLineChart:GetWidth() - 284, 1),
      plotHeight = math.max(dropLineChart:GetHeight() - 72, 1),
      valuePan = db.profile.dropLineValuePan or 0,
      maxValue = dropLineMaxValue or 1,
    }
    dropLinePanElapsed = 0
    dropLineChart:SetScript("OnUpdate", function(_, elapsed)
      if not dropLinePan then
        return
      end
      if not IsMouseButtonDown("LeftButton") then
        dropLinePan = nil
        dropLineChart:SetScript("OnUpdate", nil)
        updateRangeControls()
        return
      end
      dropLinePanElapsed = dropLinePanElapsed + elapsed
      if dropLinePanElapsed < 0.03 then
        return
      end
      dropLinePanElapsed = 0
      local currentX, currentY = GetCursorPosition()
      currentX = currentX / scale - chartLeft
      currentY = currentY / scale - chartBottom
      local duration = dropLinePan.finish - dropLinePan.start
      local deltaTime = (currentX - dropLinePan.cursorX) /
        dropLinePan.plotWidth * duration
      local startTime = math.max(dropLinePan.minTime,
        math.min(dropLinePan.start - deltaTime, dropLinePan.maxTime - duration))
      db.profile.rangeStart = startTime
      db.profile.rangeEnd = startTime + duration
      local zoom = math.max(0.002, math.min(50, db.profile.dropLineValueZoom or 1))
      local range = math.max(dropLinePan.maxValue, 1) * zoom
      local maxPan = dropLinePan.maxValue * 50
      db.profile.dropLineValuePan = math.max(-maxPan,
        math.min(maxPan, dropLinePan.valuePan -
          (currentY - dropLinePan.cursorY) / dropLinePan.plotHeight * range))
      updateRangeControls()
      drawDropLineChart()
      if timelinePanel and timelinePanel:IsShown() then
        drawChart()
      end
    end)
  end)
  dropLineChart:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" and dropLinePan then
      dropLinePan = nil
      dropLineChart:SetScript("OnUpdate", nil)
      updateRangeControls()
    end
  end)
  dropLineChart:SetScript("OnMouseWheel", function(_, delta)
    if not dropLineDomainStart or not dropLineDomainEnd then
      return
    end
    if IsShiftKeyDown() then
      local zoom = math.max(0.002, math.min(50, db.profile.dropLineValueZoom or 1))
      local nextZoom = math.max(0.002, math.min(50,
        zoom * (delta > 0 and 0.8 or 1.25)))
      db.profile.dropLineValueZoom = nextZoom
      drawDropLineChart()
      return
    end
    if not dropLineDomainStart or not dropLineDomainEnd then
      return
    end
    zoomTimeRangeAtCursor(dropLineChart, 260, 24, dropLineDomainStart,
      dropLineDomainEnd, delta, 1)
  end)
  dropLineChart:SetScript("OnShow", function()
    drawDropLineChart()
  end)
end

dropLineMaxValue = 1
dropLineMinValue = 0
dropLineBaseCenter = 0
drawDropLineChart = function()
  if not dropLineChart or not dropLineChart:IsShown() then
    return
  end
  createDropGrid()
  local drops = {}
  local minimumTime, maximumTime, minimumGP, maximumGP
  for _, event in ipairs(history) do
    if event.kind == "GP" and event.itemId and event.player ~= "GUILD_BANK" then
      table.insert(drops, event)
      minimumTime = math.min(minimumTime or event.timestamp, event.timestamp)
      maximumTime = math.max(maximumTime or event.timestamp, event.timestamp)
      minimumGP = math.min(minimumGP or event.amount, event.amount)
      maximumGP = math.max(maximumGP or 0, event.amount)
    end
  end

  local width, height = dropLineChart:GetWidth(), dropLineChart:GetHeight()
  local left, bottom = 260, 42
  local plotWidth, plotHeight = math.max(width - left - 24, 1), math.max(height - 72, 1)
  for _, line in ipairs(dropLineGridLines) do
    line:Hide()
  end
  for _, line in ipairs(dropLineVerticalGridLines) do
    line:Hide()
  end
  for index = 1, 6 do
    local y = bottom + plotHeight * (index - 1) / 5
    dropLineYLabels[index]:ClearAllPoints()
    dropLineYLabels[index]:SetPoint("RIGHT", dropLineChart, "BOTTOMLEFT", left - 7, y)
  end
  for index = 1, 5 do
    local x = left + plotWidth * (index - 1) / 4
    local label = dropLineXLabels[index]
    label:ClearAllPoints()
    label:SetWidth(150)
    label:SetPoint("TOP", dropLineChart, "BOTTOMLEFT", x, bottom - 7)
    local dateLabel = dropLineDateLabels[index]
    dateLabel:ClearAllPoints()
    dateLabel:SetWidth(150)
    dateLabel:SetPoint("TOP", dropLineChart, "BOTTOMLEFT", x, bottom - 23)
  end

  if not minimumTime then
    dropLineDomainStart, dropLineDomainEnd = nil, nil
    hideDropResetLines()
    updateDropLineSidebar({}, 0, 0, 26)
    if dropLineZeroLine then
      dropLineZeroLine:Hide()
    end
    for index = 1, #dropLineStems do
      dropLineStems[index]:Hide()
    end
    for index = 1, #dropLineNodes do
      dropLineNodes[index]:Hide()
    end
    for index = 1, 6 do
      dropLineYLabels[index]:SetText(index == 1 and "0" or "")
    end
    for index = 1, 5 do
      dropLineXLabels[index]:SetText("")
      dropLineDateLabels[index]:SetText("")
    end
    setStatus("В журнале нет GP-записей с ID полученного предмета.")
    return
  end
  if maximumTime <= minimumTime then
    minimumTime = minimumTime - 12 * 60 * 60
    maximumTime = maximumTime + 12 * 60 * 60
  end
  dropLineDomainStart, dropLineDomainEnd = minimumTime, maximumTime
  dropLineMinValue = math.min(minimumGP or 0, 0)
  local maximumValue = math.max(maximumGP or 0, 0)
  local rawValueRange = maximumValue - dropLineMinValue
  dropLineMaxValue = math.max(rawValueRange * 1.1, 1)
  dropLineBaseCenter = (dropLineMinValue + maximumValue) * 0.5

  local rangeStart = db.profile.rangeStart > 0 and db.profile.rangeStart or minimumTime
  local rangeEnd = db.profile.rangeEnd > 0 and db.profile.rangeEnd or maximumTime
  if rangeEnd <= rangeStart then
    rangeStart, rangeEnd = minimumTime, maximumTime
  end
  local duration = math.max(rangeEnd - rangeStart, 1)
  local zoom = math.max(0.002, math.min(50, db.profile.dropLineValueZoom or 1))
  db.profile.dropLineValueZoom = zoom
  local baseRange = dropLineMaxValue
  local valueRange = baseRange * zoom
  local panLimit = baseRange * 50
  local valuePan = math.max(-panLimit, math.min(panLimit, db.profile.dropLineValuePan or 0))
  db.profile.dropLineValuePan = valuePan
  local valueCenter = dropLineBaseCenter + valuePan
  dropLineValueCenter = valueCenter
  dropLineValueRange = valueRange
  local plotValueRange = math.max(valueRange, 0.000001)
  local valueMinimum = valueCenter - valueRange * 0.5
  local valueMaximum = valueCenter + valueRange * 0.5
  for index = 1, 6 do
    local fraction = (index - 1) / 5
    dropLineYLabels[index]:SetText(("%.0f"):format(valueMinimum + valueRange * fraction))
  end
  local plotTop = bottom + plotHeight
  local zeroY = bottom + (0 - valueMinimum) / plotValueRange * plotHeight
  if zeroY >= bottom and zeroY <= plotTop then
    dropLineZeroLine:ClearAllPoints()
    dropLineZeroLine:SetPoint("BOTTOMLEFT", dropLineChart, "BOTTOMLEFT", left, zeroY)
    dropLineZeroLine:SetSize(plotWidth, 2)
    dropLineZeroLine:Show()
  else
    dropLineZeroLine:Hide()
  end
  for index = 1, 5 do
    local fraction = (index - 1) / 4
    local timestamp = rangeStart + duration * fraction
    local format
    if duration <= 10 * 60 then
      format = "%H:%M:%S"
    elseif duration <= 24 * 60 * 60 then
      format = "%H:%M"
    elseif duration <= 7 * 24 * 60 * 60 then
      format = "%d.%m %H:%M"
    else
      format = "%d.%m.%y"
    end
    dropLineXLabels[index]:SetText(date(format, timestamp))
    if duration <= 24 * 60 * 60 then
      dropLineDateLabels[index]:SetText(date("%d.%m.%Y", timestamp))
    else
      dropLineDateLabels[index]:SetText("")
    end
  end
  drawDropResetLines(rangeStart, rangeEnd, left, bottom, plotWidth, plotHeight)

  local visibleDrops = {}
  for _, event in ipairs(drops) do
    if event.timestamp >= rangeStart and event.timestamp <= rangeEnd then
      table.insert(visibleDrops, event)
    end
  end
  local visibleCount = #visibleDrops
  updateDropLineSidebar(drops, rangeStart, rangeEnd, visibleCount)
  local placedLabelsByColumn = {}
  local stemCount = 0
  for nodeIndex, event in ipairs(visibleDrops) do
      if not dropLineNodes[nodeIndex] then
        dropLineNodes[nodeIndex] = createDropNode()
      end
      local node = dropLineNodes[nodeIndex]
      node.event = event
      local x = left + (event.timestamp - rangeStart) / duration * plotWidth
      local value = event.amount
      local y = bottom + (value - valueMinimum) / plotValueRange * plotHeight
      y = math.max(bottom + 3, math.min(bottom + plotHeight - 3, y))
      local clippedZeroY = math.max(bottom, math.min(plotTop, zeroY))
      local stemTop = math.max(clippedZeroY, y)
      local stemBottom = math.min(clippedZeroY, y)
      if math.abs(stemTop - stemBottom) > 0.5 then
        stemCount = stemCount + 1
        local color = playerClassColor(event.player)
        if not dropLineStems[stemCount] then
          dropLineStems[stemCount] = makeFlatTexture(dropLineChart,
            "ARTWORK", color.r, color.g, color.b, 0.42)
        end
        local stem = dropLineStems[stemCount]
        stem:ClearAllPoints()
        stem:SetPoint("BOTTOMLEFT", dropLineChart, "BOTTOMLEFT", x, stemBottom)
        stem:SetSize(1, stemTop - stemBottom)
        stem:SetVertexColor(color.r, color.g, color.b, 0.42)
        stem:Show()
      end
      node:ClearAllPoints()
      node:SetPoint("CENTER", dropLineChart, "BOTTOMLEFT", x, y)
      local player = shortPlayerName(event.player)
      local main = addon:GetGuildMainName(event.player)
      local color = playerClassColor(event.player)
      local playerHex = ("|cff%02x%02x%02x"):format(
        math.floor(color.r * 255), math.floor(color.g * 255), math.floor(color.b * 255))
      local label = playerHex .. player .. "|r"
      if main:lower() ~= player:lower() then
        label = label .. "\n|cffc3cbd1(Осн. " .. main .. ")|r"
      end
      label = label .. "\n|cffffffff" .. ("%+.0fGP"):format(event.amount) .. "|r"
      local icon = getTooltipItemIcon and getTooltipItemIcon(event.itemId)
      local nodeSize = icon and 16 or 9
      node:SetSize(nodeSize, nodeSize)
      if icon then
        node.texture:SetTexture(icon)
        node.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        node.texture:SetVertexColor(1, 1, 1, 1)
      else
        node.texture:SetTexture("Interface\\Buttons\\WHITE8X8")
        node.texture:SetTexCoord(0, 1, 0, 1)
        node.texture:SetVertexColor(color.r, color.g, color.b, 1)
      end

      node.label:ClearAllPoints()
      node.label:SetJustifyH("LEFT")
      node.label:SetText(label)
      local labelWidth = math.max(32, math.min(200, node.label:GetStringWidth() + 4))
      node.label:SetWidth(labelWidth)
      local labelHeight = main:lower() ~= player:lower() and 42 or 28
      local labelX = x + nodeSize * 0.5 + 3
      if labelX + labelWidth > left + plotWidth then
        labelX = x - nodeSize * 0.5 - labelWidth - 3
      end
      local baseY = y + nodeSize * 0.5 + 3
      local labelY = math.max(bottom, math.min(bottom + plotHeight - labelHeight, baseY))
      local offsetStep = labelHeight + 2
      local labelColumn = math.floor(labelX / (labelWidth + 8))
      for offsetIndex = 0, math.floor(plotHeight / offsetStep) do
        local offset = offsetIndex == 0 and 0 or
          math.ceil(offsetIndex / 2) * offsetStep * (offsetIndex % 2 == 1 and 1 or -1)
        local candidateY = math.max(bottom,
          math.min(bottom + plotHeight - labelHeight, baseY + offset))
        local overlaps = false
        for column = labelColumn - 1, labelColumn + 1 do
          for _, placed in ipairs(placedLabelsByColumn[column] or {}) do
            if labelX < placed.right and labelX + labelWidth > placed.left and
              candidateY < placed.bottom and candidateY + labelHeight > placed.top then
              overlaps = true
              break
            end
          end
          if overlaps then
            break
          end
        end
        if not overlaps then
          labelY = candidateY
          break
        end
      end
      if not placedLabelsByColumn[labelColumn] then
        placedLabelsByColumn[labelColumn] = {}
      end
      table.insert(placedLabelsByColumn[labelColumn], {
        left = labelX,
        right = labelX + labelWidth,
        top = labelY,
        bottom = labelY + labelHeight,
      })
      node.label:SetPoint("BOTTOMLEFT", dropLineChart, "BOTTOMLEFT", labelX, labelY)
      node.nameButton:ClearAllPoints()
      node.nameButton:SetPoint("BOTTOMLEFT", dropLineChart, "BOTTOMLEFT",
        labelX, labelY + labelHeight - 16)
      node.nameButton:SetSize(labelWidth, 16)
      node.nameButton.characterName = player
      if visibleCount <= 25 then
        node.label:Show()
        node.nameButton:Show()
      else
        node.label:Hide()
        node.nameButton:Hide()
      end
      node:Show()
  end
  for index = stemCount + 1, #dropLineStems do
    dropLineStems[index]:Hide()
  end
  for index = visibleCount + 1, #dropLineNodes do
    dropLineNodes[index]:Hide()
    dropLineNodes[index].nameButton:Hide()
  end
  setStatus(("Дропов в периоде: %d; всего в журнале: %d"):format(visibleCount, #drops))
end

local function rosterMatches(group, query)
  if query == "" or group.main:lower():find(query, 1, true) then
    return true
  end
  for _, alt in ipairs(group.alts) do
    if alt:lower():find(query, 1, true) then
      return true
    end
  end
  return false
end

updateRosterWindow = function()
  if not rosterWindow or not rosterWindow:IsShown() then
    return
  end
  local query = rosterSearch:GetText():lower()
  local groups = {}
  for _, group in ipairs(getGuildCharacterGroups()) do
    if rosterMatches(group, query) then
      table.insert(groups, group)
    end
  end
  table.sort(groups, function(a, b)
    local primaryA, primaryB
    if rosterSortColumn == "name" then
      primaryA, primaryB = a.main:lower(), b.main:lower()
    elseif rosterSortColumn == "alts" then
      primaryA, primaryB = a.altCount, b.altCount
    elseif rosterSortColumn == "status" then
      local statusA = a.frozen and 2 or (a.online and 1 or 0)
      local statusB = b.frozen and 2 or (b.online and 1 or 0)
      if statusA ~= statusB then
        if rosterSortDescending then
          return statusA > statusB
        end
        return statusA < statusB
      end
      return a.main:lower() < b.main:lower()
    else
      primaryA, primaryB = a[rosterSortColumn], b[rosterSortColumn]
    end
    if primaryA == nil or primaryB == nil then
      if primaryA ~= primaryB then
        return primaryA ~= nil
      end
    elseif primaryA ~= primaryB then
      if rosterSortDescending then
        return primaryA > primaryB
      end
      return primaryA < primaryB
    end
    return a.main:lower() < b.main:lower()
  end)

  local offset = 0
  local contentWidth = math.max(rosterScroll:GetWidth() - 6, 300)
  rosterContent:SetWidth(contentWidth)
  local mainColumnWidth = 150
  local rightOffset = 4
  for _, column in ipairs(rosterRightColumns) do
    local header = rosterHeaders[column.sortKey or column.key]
    if header then
      header:SetSize(column.width, 24)
      header:ClearAllPoints()
      header:SetPoint("TOPRIGHT", rosterWindow, "TOPRIGHT", -(34 + rightOffset), -42)
      header.isActive = rosterSortColumn == (column.sortKey or column.key)
      local activeColor = COLORS[column.key:upper()] or COLORS.PR
      header.activeColor = activeColor
      header.label:SetText(header.baseLabel ..
        (header.isActive and (rosterSortDescending and " v" or " ^") or ""))
      header.label:SetTextColor(header.isActive and activeColor[1] or 0.88,
        header.isActive and activeColor[2] or 0.91,
        header.isActive and activeColor[3] or 0.94)
      header.background:SetVertexColor(
        header.isActive and activeColor[1] or 0.12,
        header.isActive and activeColor[2] or 0.15,
        header.isActive and activeColor[3] or 0.18,
        header.isActive and 0.55 or 1)
    end
    rightOffset = rightOffset + column.width + 6
  end
  local nameHeader = rosterHeaders.name
  nameHeader.isActive = rosterSortColumn == "name"
  nameHeader.activeColor = COLORS.PR
  nameHeader.label:SetText(nameHeader.baseLabel ..
    (nameHeader.isActive and (rosterSortDescending and " v" or " ^") or ""))
  nameHeader.label:SetTextColor(nameHeader.isActive and COLORS.PR[1] or 0.88,
    nameHeader.isActive and COLORS.PR[2] or 0.91,
    nameHeader.isActive and COLORS.PR[3] or 0.94)
  nameHeader.background:SetVertexColor(
    nameHeader.isActive and COLORS.PR[1] or 0.12,
    nameHeader.isActive and COLORS.PR[2] or 0.15,
    nameHeader.isActive and COLORS.PR[3] or 0.18,
    nameHeader.isActive and 0.55 or 1)
  local altsColumnWidth = math.max(80,
    math.min(240, contentWidth - mainColumnWidth - rightOffset - 26))
  rosterScroll:SetVerticalScroll(0)
  for index, group in ipairs(groups) do
    if not rosterRows[index] then
      local row = CreateFrame("Frame", nil, rosterContent)
      row.background = makeFlatTexture(row, "BACKGROUND", 0.12, 0.15, 0.18, 0.7)
      row.background:SetAllPoints(row)
      row.main = CreateFrame("Button", nil, row)
      row.main:SetHeight(18)
      row.main.label = makeText(row.main, "", "GameFontNormalSmall")
      row.main.label:SetAllPoints(row.main)
      row.main.label:SetJustifyH("LEFT")
      row.main.label:SetWordWrap(false)
      row.main:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      row.main:SetScript("OnClick", function(self, button)
        if button == "RightButton" and self.characterName then
          showArmoryContextMenu(self.characterName)
        elseif button == "LeftButton" then
          showCharacterLoot(self.characterName)
        end
      end)
      row.altButtons = {}
      row.count = makeText(row, "", "GameFontNormalSmall")
      row.count:SetJustifyH("CENTER")
      row.status = makeText(row, "", "GameFontNormalSmall")
      row.status:SetJustifyH("CENTER")
      row.ep = makeText(row, "", "GameFontNormalSmall")
      row.gp = makeText(row, "", "GameFontNormalSmall")
      row.pr = makeText(row, "", "GameFontNormalSmall")
      row.ep:SetJustifyH("CENTER")
      row.gp:SetJustifyH("CENTER")
      row.pr:SetJustifyH("CENTER")
      rosterRows[index] = row
    end
    local row = rosterRows[index]
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", rosterContent, "TOPLEFT", 0, -offset)
    row:SetWidth(contentWidth)
    row.background:SetVertexColor(index % 2 == 1 and 0.14 or 0.20,
      index % 2 == 1 and 0.17 or 0.23,
      index % 2 == 1 and 0.20 or 0.28, 0.82)
    row.main:ClearAllPoints()
    row.main:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -6)
    row.main:SetWidth(mainColumnWidth - 12)
    row.status:SetText(group.frozen and "Фриз" or (group.online and "В игре" or ""))
    row.status:SetTextColor(group.frozen and 0.95 or 0.78,
      group.frozen and 0.68 or 0.82, group.frozen and 0.36 or 0.85)
    row.count:SetTextColor(0.78, 0.82, 0.85)
    row.count:SetText(tostring(group.altCount))
    row.ep:SetText(group.ep and ("%.0f"):format(group.ep) or "—")
    row.gp:SetText(group.gp and ("%.0f"):format(group.gp) or "—")
    row.pr:SetText(group.pr and ("%.3f"):format(group.pr) or "—")
    row.ep:SetTextColor(COLORS.EP[1], COLORS.EP[2], COLORS.EP[3])
    row.gp:SetTextColor(COLORS.GP[1], COLORS.GP[2], COLORS.GP[3])
    row.pr:SetTextColor(COLORS.PR[1], COLORS.PR[2], COLORS.PR[3])
    local columnRightOffset = 4
    for _, column in ipairs(rosterRightColumns) do
      local cell = row[column.key]
      cell:ClearAllPoints()
      cell:SetPoint("TOPRIGHT", row, "TOPRIGHT", -columnRightOffset, -6)
      cell:SetWidth(column.width)
      columnRightOffset = columnRightOffset + column.width + 6
    end
    local mainColor = playerClassColor(group.main)
    local mainIsOnline = group.memberOnline[group.main:lower()]
    local onlineMarker = mainIsOnline and " |TInterface\\COMMON\\Indicator-Green:10:10:0:-2|t" or ""
    row.main.characterName = group.main
    row.main.label:SetText(("|cff%02x%02x%02x%s|r%s"):format(
      math.floor(mainColor.r * 255), math.floor(mainColor.g * 255),
      math.floor(mainColor.b * 255), group.main, onlineMarker))
    local altButtonHeight = 18
    local altLine = 0
    local altX = 0
    for altIndex, alt in ipairs(group.alts) do
      if not row.altButtons[altIndex] then
        local button = CreateFrame("Button", nil, row)
        button:SetHeight(altButtonHeight)
        button.label = makeText(button, "", "GameFontNormalSmall")
        button.label:SetAllPoints(button)
        button.label:SetJustifyH("LEFT")
        button.label:SetWordWrap(false)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnClick", function(self, mouseButton)
          if mouseButton == "RightButton" and self.characterName then
            showArmoryContextMenu(self.characterName)
          elseif mouseButton == "LeftButton" then
            showCharacterLoot(self.characterName)
          end
        end)
        row.altButtons[altIndex] = button
      end
      local altButton = row.altButtons[altIndex]
      altButton.characterName = alt
      local color = playerClassColor(alt)
      local isOnline = group.memberOnline[alt:lower()]
      local altMarker = isOnline and " |TInterface\\COMMON\\Indicator-Green:10:10:0:-2|t" or ""
      local nameText = ("|cff%02x%02x%02x%s|r%s"):format(
        math.floor(color.r * 255), math.floor(color.g * 255),
        math.floor(color.b * 255), alt, altMarker)
      local separator = altIndex > 1 and ", " or ""
      altButton.label:SetText(separator .. nameText)
      local buttonWidth = math.ceil(altButton.label:GetStringWidth()) + 4
      if altX > 0 and altX + buttonWidth > altsColumnWidth then
        altLine = altLine + 1
        altX = 0
        altButton.label:SetText(nameText)
        buttonWidth = math.ceil(altButton.label:GetStringWidth()) + 4
      end
      altButton:ClearAllPoints()
      altButton:SetPoint("TOPLEFT", row, "TOPLEFT",
        mainColumnWidth + 10 + altX, -6 - altLine * altButtonHeight)
      altButton:SetWidth(math.min(buttonWidth, altsColumnWidth))
      altButton:Show()
      altX = altX + buttonWidth
    end
    for altIndex = #group.alts + 1, #row.altButtons do
      row.altButtons[altIndex]:Hide()
    end
    group.rowHeight = math.max(28, 12 + (altLine + 1) * altButtonHeight)
    row:SetHeight(group.rowHeight)
    row.contentTop = offset
    row.contentBottom = offset + group.rowHeight
    offset = offset + group.rowHeight
  end
  for index = #groups + 1, #rosterRows do
    rosterRows[index].contentTop = nil
    rosterRows[index].contentBottom = nil
    rosterRows[index]:Hide()
  end
  rosterContent:SetHeight(math.max(offset, 1))
  updateRosterVisibleRows()
  if #groups == 0 then
    setStatus(query == "" and "Ростер гильдии не загружен." or "Персонажи не найдены.")
  end
end

function createRosterUI()
  rosterWindow = makePanel(window)
  rosterWindow:SetPoint("TOPLEFT", window, "TOPLEFT", 16, -84)
  rosterWindow:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -16, 48)
  rosterWindow:Hide()
  rosterTitle = makeText(rosterWindow,
    rosterGuildName and ("Ростер гильдии: " .. rosterGuildName) or
      "Ростер гильдии: не состоите в гильдии", "GameFontNormal")
  rosterTitle:SetPoint("TOPLEFT", rosterWindow, "TOPLEFT", 16, -14)
  rosterTitle:SetTextColor(0.78, 0.88, 0.92)

  rosterSearch = CreateFrame("EditBox", nil, rosterWindow, "InputBoxTemplate")
  rosterSearch:SetSize(220, 24)
  rosterSearch:SetPoint("TOPRIGHT", rosterWindow, "TOPRIGHT", -16, -10)
  rosterSearch:SetAutoFocus(false)
  rosterSearch:SetMaxLetters(48)
  rosterSearch:SetFontObject(GameFontHighlightSmall)
  rosterSearch:SetTextInsets(6, 6, 0, 0)
  rosterSearch:SetScript("OnTextChanged", updateRosterWindow)

  local rosterSearchLabel = makeText(rosterWindow, "Поиск персонажа:", "GameFontNormalSmall")
  rosterSearchLabel:SetPoint("RIGHT", rosterSearch, "LEFT", -8, 0)
  rosterSearchLabel:SetTextColor(0.78, 0.82, 0.85)

  local nameSort = makeButton(rosterWindow, "Основа", 170, 24, function()
    if rosterSortColumn == "name" then
      rosterSortDescending = not rosterSortDescending
    else
      rosterSortColumn = "name"
      rosterSortDescending = false
    end
    updateRosterWindow()
  end)
  nameSort:SetSize(150, 24)
  rosterHeaders.name = nameSort
  nameSort.baseLabel = "Основа"
  nameSort:SetPoint("TOPLEFT", rosterWindow, "TOPLEFT", 12, -42)
  nameSort.label:ClearAllPoints()
  nameSort.label:SetPoint("LEFT", nameSort, "LEFT", 8, 0)
  nameSort.label:SetJustifyH("LEFT")
  local altsHeader = makeText(rosterWindow, "Твинки", "GameFontNormalSmall")
  altsHeader:SetPoint("LEFT", nameSort, "RIGHT", 8, 0)
  altsHeader:SetTextColor(0.78, 0.82, 0.85)
  local sortLabels = {
    count = "Кол-во твинов",
    status = "Статус",
    pr = "PR",
    gp = "GP",
    ep = "EP",
  }
  for _, column in ipairs(rosterRightColumns) do
    local sortKey = column.sortKey or column.key
    local header = makeButton(rosterWindow, sortLabels[column.key], column.width, 24,
      function()
        if rosterSortColumn == sortKey then
          rosterSortDescending = not rosterSortDescending
        else
          rosterSortColumn = sortKey
          rosterSortDescending = true
        end
        updateRosterWindow()
      end)
    rosterHeaders[sortKey] = header
    header.baseLabel = sortLabels[column.key]
    header.label:ClearAllPoints()
    header.label:SetPoint("CENTER", header, "CENTER")
    header.label:SetJustifyH("CENTER")
  end

  rosterScroll = CreateFrame("ScrollFrame", nil, rosterWindow)
  rosterScroll:SetPoint("TOPLEFT", rosterWindow, "TOPLEFT", 12, -72)
  rosterScroll:SetPoint("BOTTOMRIGHT", rosterWindow, "BOTTOMRIGHT", -28, 12)
  rosterScroll:EnableMouseWheel(true)
  rosterContent = CreateFrame("Frame", nil, rosterScroll)
  rosterContent:SetWidth(1120)
  rosterContent:SetHeight(1)
  rosterScroll:SetScrollChild(rosterContent)
  rosterScroll:SetScript("OnVerticalScroll", function(_, offset)
    updateRosterVisibleRows(offset)
  end)
  rosterScroll:SetScript("OnMouseWheel", function(self, delta)
    local maximum = math.max(rosterContent:GetHeight() - self:GetHeight(), 0)
    self:SetVerticalScroll(math.max(0, math.min(maximum,
      self:GetVerticalScroll() - delta * 42)))
    updateRosterVisibleRows()
  end)
end
