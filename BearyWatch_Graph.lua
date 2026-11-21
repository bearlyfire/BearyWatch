local addon = _G.BearyWatch
if type(addon) ~= "table" or type(addon.environment) ~= "table" then
  error("BearyWatch shared environment was not initialized.")
end
setfenv(1, addon.environment)
function makeFlatTexture(parent, layer, red, green, blue, alpha)
  local texture = parent:CreateTexture(nil, layer or "ARTWORK")
  texture:SetTexture("Interface\\Buttons\\WHITE8X8")
  texture:SetVertexColor(red or 1, green or 1, blue or 1, alpha or 1)
  return texture
end

makeText = function(parent, text, template, layer)
  local font = parent:CreateFontString(nil, layer or "OVERLAY", template or "GameFontNormal")
  font:SetText(text or "")
  return font
end

function makeButton(parent, text, width, height, onClick)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(width, height)
  button.background = makeFlatTexture(button, "BACKGROUND", 0.12, 0.15, 0.18, 1)
  button.background:SetAllPoints(button)
  button.label = makeText(button, text, "GameFontNormalSmall")
  button.label:SetPoint("CENTER")
  button.label:SetTextColor(0.88, 0.91, 0.94)
  button:SetScript("OnEnter", function(self)
    if self.isActive and self.activeColor then
      self.background:SetVertexColor(self.activeColor[1], self.activeColor[2], self.activeColor[3], 0.75)
    else
      self.background:SetVertexColor(0.20, 0.29, 0.35, 1)
    end
  end)
  button:SetScript("OnLeave", function(self)
    if self.isActive and self.activeColor then
      self.background:SetVertexColor(self.activeColor[1], self.activeColor[2], self.activeColor[3], 0.55)
    else
      self.background:SetVertexColor(0.12, 0.15, 0.18, 1)
    end
  end)
  button:RegisterForClicks("LeftButtonUp")
  if onClick then
    button:SetScript("OnClick", onClick)
  end
  return button
end

function getGraphMetric(point)
  if selectedMetric == "GP" then
    return point.gp
  elseif selectedMetric == "PR" then
    return point.pr
  elseif selectedMetric == "RANK" then
    return point.rank
  end
  return point.ep
end

function eventInSelectedPeriod(event)
  return (db.profile.rangeStart <= 0 or event.timestamp >= db.profile.rangeStart) and
    (db.profile.rangeEnd <= 0 or event.timestamp <= db.profile.rangeEnd)
end

function median(values)
  table.sort(values)
  local count = #values
  if count == 0 then
    return nil
  end
  local middle = math.floor((count + 1) / 2)
  if count % 2 == 1 then
    return values[middle]
  end
  return (values[middle] + values[middle + 1]) / 2
end

function rebuildItemGPMedians()
  local valuesByItem = {}
  for _, event in ipairs(history) do
    if event.kind == "GP" and event.itemId and event.amount > 0 and
      event.player ~= "GUILD_BANK" and eventInSelectedPeriod(event) then
      if not valuesByItem[event.itemId] then
        valuesByItem[event.itemId] = {}
      end
      table.insert(valuesByItem[event.itemId], event.amount)
    end
  end
  medianGPByItem = {}
  for itemId, values in pairs(valuesByItem) do
    medianGPByItem[itemId] = median(values)
  end
end

function formatPointChange(value)
  if value == 0 then
    return "без изменений"
  end
  if value > 0 then
    return ("+%.0f"):format(value)
  end
  return ("-%.0f"):format(math.abs(value))
end

function formatPRChange(value)
  if value == 0 then
    return "без изменений"
  end
  if value > 0 then
    return ("+%.3f"):format(value)
  end
  return ("-%.3f"):format(math.abs(value))
end

CLASS_TOKEN_BY_NAME = {
  ["Warrior"] = "WARRIOR",
  ["Воин"] = "WARRIOR",
  ["Paladin"] = "PALADIN",
  ["Паладин"] = "PALADIN",
  ["Hunter"] = "HUNTER",
  ["Охотник"] = "HUNTER",
  ["Rogue"] = "ROGUE",
  ["Разбойник"] = "ROGUE",
  ["Priest"] = "PRIEST",
  ["Жрец"] = "PRIEST",
  ["Death Knight"] = "DEATHKNIGHT",
  ["Рыцарь смерти"] = "DEATHKNIGHT",
  ["Shaman"] = "SHAMAN",
  ["Шаман"] = "SHAMAN",
  ["Mage"] = "MAGE",
  ["Маг"] = "MAGE",
  ["Warlock"] = "WARLOCK",
  ["Чернокнижник"] = "WARLOCK",
  ["Druid"] = "DRUID",
  ["Друид"] = "DRUID",
}

local guildRosterRefreshState

function refreshClassRoster()
  if guildRosterRefreshState then
    local state = guildRosterRefreshState
    local memberCount = state.memberCount
    local finishIndex = math.min(state.index + 199, memberCount)
    for index = state.index, finishIndex do
      local name, _, _, _, localizedClass, _, _, officerNote, online, _, classToken =
        GetGuildRosterInfo(index)
      local noteData = bossLoot.parseOfficerNote(officerNote)
      if name then
        local shortName = name:match("^([^%-]+)") or name
        bossLoot.guildMembers[#bossLoot.guildMembers + 1] = {
          name = shortName,
          online = not not online,
          status = noteData and noteData.status or nil,
          classToken = classToken or
            (EPGP and EPGP.GetClass and EPGP:GetClass(name)) or
            CLASS_TOKEN_BY_NAME[localizedClass],
        }
        local main = EPGP and EPGP.GetMain and EPGP:GetMain(name)
        if type(main) ~= "string" and EPGP and EPGP.GetMain then
          main = EPGP:GetMain(shortName)
        end
        main = type(main) == "string" and (main:match("^([^%-]+)") or main) or shortName
        guildMainByName[name:lower()] = main
        guildMainByName[shortName:lower()] = main
      end
      if name and type(officerNote) == "string" then
        local shortName = name:match("^([^%-]+)") or name
        bossLoot.officerNotes[shortName:lower()] = officerNote
        bossLoot.rosterNames[shortName:lower()] = shortName
        local notedMain = officerNote:match("^%s*(.-)%s*$")
        if notedMain ~= "" and not noteData and not notedMain:match("^%d+$") then
          notedMain = notedMain:match("^([^%-]+)") or notedMain
          guildMainByName[name:lower()] = notedMain
          guildMainByName[shortName:lower()] = notedMain
        end
      elseif name then
        local shortName = name:match("^([^%-]+)") or name
        bossLoot.rosterNames[shortName:lower()] = shortName
      end
      if name and localizedClass then
        classToken = classToken or
          (EPGP and EPGP.GetClass and EPGP:GetClass(name)) or
          CLASS_TOKEN_BY_NAME[localizedClass]
        if classToken then
          classTokenByPlayer[name] = classToken
          local shortName = name:match("^([^%-]+)") or name
          classTokenByPlayer[shortName] = classToken
          local main = addon:GetGroupedName(name)
          if main == name or not classTokenByPlayer[main] then
            classTokenByPlayer[main] = classToken
          end
        end
      end
    end
    state.index = finishIndex + 1
    if state.index <= memberCount then
      return false
    end
    guildRosterRefreshState = nil
    return true
  end
  classTokenByPlayer = {}
  guildMainByName = {}
  bossLoot.officerNotes = {}
  bossLoot.rosterNames = {}
  bossLoot.guildMembers = {}
  local guildName = GetGuildInfo and GetGuildInfo("player")
  if type(guildName) == "string" and guildName ~= "" then
    rosterGuildName = guildName
  else
    rosterGuildName = nil
  end
  if rosterTitle then
    rosterTitle:SetText(rosterGuildName and
      ("Ростер гильдии: " .. rosterGuildName) or "Ростер гильдии: не состоите в гильдии")
  end
  if not GetNumGuildMembers or not GetGuildRosterInfo then
    return true
  end
  local memberCount = GetNumGuildMembers()
  guildRosterRefreshState = { index = 1, memberCount = memberCount }
  return refreshClassRoster()
end

playerClassColor = function(name)
  local classToken = classTokenByPlayer[name]
  local colors = RAID_CLASS_COLORS
  return classToken and colors and colors[classToken] or UNKNOWN_CLASS_COLOR
end

local timelineLegendRows = {}

local function updateTimelineLegend(names)
  if #names <= 1 then
    for _, row in ipairs(timelineLegendRows) do
      row.label:Hide()
      row.swatch:Hide()
    end
    return 0
  end

  local maximumRight = math.max(chart:GetWidth() - 116, 100)
  local x, rowIndex = 64, 1
  for index, name in ipairs(names) do
    if not timelineLegendRows[index] then
      local row = {}
      row.label = makeText(chart, "", "GameFontNormalSmall")
      row.label:SetJustifyH("LEFT")
      row.label:SetWordWrap(false)
      row.swatch = makeFlatTexture(chart, "OVERLAY", 1, 1, 1, 1)
      timelineLegendRows[index] = row
    end
    local row = timelineLegendRows[index]
    row.label:SetText(name)
    local color = PLAYER_COLORS[(index - 1) % #PLAYER_COLORS + 1]
    row.label:SetTextColor(color[1], color[2], color[3])
    local itemWidth = row.label:GetStringWidth() + 22
    if x > 64 and x + itemWidth > maximumRight then
      rowIndex = rowIndex + 1
      x = 64
    end
    row.swatch:ClearAllPoints()
    row.swatch:SetPoint("TOPLEFT", chart, "TOPLEFT", x, -7 - (rowIndex - 1) * 18)
    row.swatch:SetSize(9, 9)
    row.swatch:SetVertexColor(color[1], color[2], color[3], 1)
    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", row.swatch, "RIGHT", 4, 0)
    row.label:Show()
    row.swatch:Show()
    x = x + itemWidth
  end
  for index = #names + 1, #timelineLegendRows do
    timelineLegendRows[index].label:Hide()
    timelineLegendRows[index].swatch:Hide()
  end
  return rowIndex
end

function addRankTooltip(point)
  local snapshot = point.ranking and nil or getRankSnapshotAt(point.timestamp)
  local ranking = point.ranking
  local selectedPosition
  local rankingCount
  local priority
  if ranking then
    for index, entry in ipairs(ranking) do
      if entry.player == point.player then
        selectedPosition = index
        priority = entry.pr
        break
      end
    end
    rankingCount = #ranking
  elseif snapshot then
    local playerIndex = rankPlayerIndexes[point.player]
    selectedPosition = playerIndex and snapshot.positions[playerIndex]
    rankingCount = snapshot.count
    priority = point.pr
  end
  if not selectedPosition then
    GameTooltip:AddLine("Позиция не определена: игрок или его класс исключён фильтром.",
      0.88, 0.72, 0.54, true)
    return
  end

  if point.rankBefore and point.rankAfter then
    local rankChange = point.rankBefore - point.rankAfter
    local rankText = ("Место в рейтинге: %d из %d"):format(
      point.rankAfter, point.rankCount or rankingCount)
    if rankChange ~= 0 then
      local changeText = rankChange > 0 and ("+" .. rankChange) or tostring(rankChange)
      local color = rankChange > 0 and "|cff40e060" or "|cffff4040"
      rankText = ("Место в рейтинге: %s%s|r (%d из %d)"):format(
        color, changeText, point.rankAfter, point.rankCount or rankingCount)
    end
    GameTooltip:AddLine(rankText, 1, 1, 1, true)
  else
    GameTooltip:AddDoubleLine("Место в рейтинге",
      ("%d из %d"):format(selectedPosition, rankingCount),
      COLORS.RANK[1], COLORS.RANK[2], COLORS.RANK[3], 1, 1, 1)
  end
  if selectedMetric == "RANK" then
    GameTooltip:AddLine(point.kind == "RANK" and
      "Состояние после всех записей этой секунды" or "Состояние после этой записи",
      0.68, 0.72, 0.75)
  end
  GameTooltip:AddDoubleLine("Приоритет (EP / GP)",
    ("%.3f"):format(priority or 0),
    COLORS.PR[1], COLORS.PR[2], COLORS.PR[3], 1, 1, 1)
  if not rankBalancesComplete then
    GameTooltip:AddLine("Рейтинг приблизительный: нет текущих балансов всех классов в выборке.",
      0.88, 0.72, 0.54, true)
  end
  if selectedMetric == "RANK" and ranking then
    GameTooltip:AddLine("Соседи в рейтинге (+10 / -10)", 0.75, 0.80, 0.84)
    local first = math.max(1, selectedPosition - 10)
    local last = math.min(#ranking, selectedPosition + 10)
    for index = first, last do
      local entry = ranking[index]
      local classColor = playerClassColor(entry.player)
      local color = index == selectedPosition and COLORS.RANK or classColor
      local red = color and color.r or color and color[1] or 0.75
      local green = color and color.g or color and color[2] or 0.85
      local blue = color and color.b or color and color[3] or 0.95
      GameTooltip:AddDoubleLine(("%d. %s"):format(index, entry.player),
        ("PR %.3f"):format(entry.pr), red, green, blue, 1, 1, 1)
    end
  end
end

function showPointTooltip(button)
  local point = button.point
  if not point then
    return
  end
  GameTooltip:SetOwner(button, "ANCHOR_CURSOR")
  GameTooltip:AddLine(date("%d.%m.%Y %H:%M:%S", point.timestamp), 1, 1, 1)
  if point.player then
    local classColor = playerClassColor(point.player)
    GameTooltip:AddLine(point.player, classColor.r, classColor.g, classColor.b)
  end
  if point.kind == "RANK" then
    addRankTooltip(point)
    GameTooltip:Show()
    return
  end

  local reason = type(point.reason) == "string" and point.reason ~= "" and
    point.reason or "Причина не указана"
  if selectedMetric == "EP" then
    GameTooltip:AddDoubleLine("Изменение EP", formatPointChange(point.deltaEP or 0),
      COLORS.EP[1], COLORS.EP[2], COLORS.EP[3], 1, 1, 1)
    GameTooltip:AddLine(reason, COLORS.EP[1], COLORS.EP[2], COLORS.EP[3], true)
  elseif selectedMetric == "GP" then
    if point.highGPSlice then
      GameTooltip:AddDoubleLine("Изменение EP", formatPointChange(point.deltaEP or 0),
        COLORS.EP[1], COLORS.EP[2], COLORS.EP[3], 1, 1, 1)
      GameTooltip:AddLine(reason, COLORS.EP[1], COLORS.EP[2], COLORS.EP[3], true)
    elseif point.itemId and point.kind == "GP" then
      GameTooltip:AddDoubleLine(getTooltipItemLabel(point.itemId),
        formatPointChange(point.deltaGP or 0) .. " GP",
        1, 1, 1,
        (point.priceAnomaly and COLORS.OVERPRICE or COLORS.GP)[1],
        (point.priceAnomaly and COLORS.OVERPRICE or COLORS.GP)[2],
        (point.priceAnomaly and COLORS.OVERPRICE or COLORS.GP)[3])
    else
      GameTooltip:AddDoubleLine("Изменение GP", formatPointChange(point.deltaGP or 0),
        1, 1, 1, COLORS.GP[1], COLORS.GP[2], COLORS.GP[3])
      GameTooltip:AddLine(reason, COLORS.GP[1], COLORS.GP[2], COLORS.GP[3], true)
    end
  elseif selectedMetric == "PR" then
    GameTooltip:AddDoubleLine("Изменение PR", formatPRChange(point.deltaPR or 0),
      COLORS.PR[1], COLORS.PR[2], COLORS.PR[3],
      (point.priceAnomaly and COLORS.OVERPRICE or COLORS.PR)[1],
      (point.priceAnomaly and COLORS.OVERPRICE or COLORS.PR)[2],
      (point.priceAnomaly and COLORS.OVERPRICE or COLORS.PR)[3])
    if point.kind == "GP" then
      if point.itemId then
        GameTooltip:AddDoubleLine(getTooltipItemLabel(point.itemId),
          formatPointChange(point.deltaGP or 0) .. " GP",
          1, 1, 1,
          (point.priceAnomaly and COLORS.OVERPRICE or COLORS.GP)[1],
          (point.priceAnomaly and COLORS.OVERPRICE or COLORS.GP)[2],
          (point.priceAnomaly and COLORS.OVERPRICE or COLORS.GP)[3])
      else
        GameTooltip:AddLine(reason, COLORS.GP[1], COLORS.GP[2], COLORS.GP[3], true)
        GameTooltip:AddDoubleLine("Изменение GP", formatPointChange(point.deltaGP or 0),
          1, 1, 1, COLORS.GP[1], COLORS.GP[2], COLORS.GP[3])
      end
    elseif point.kind == "EP" then
      GameTooltip:AddLine(reason, COLORS.EP[1], COLORS.EP[2], COLORS.EP[3], true)
      GameTooltip:AddDoubleLine("Изменение EP", formatPointChange(point.deltaEP or 0),
        COLORS.EP[1], COLORS.EP[2], COLORS.EP[3], 1, 1, 1)
    else
      GameTooltip:AddLine(reason, 0.90, 0.90, 0.90, true)
    end
  end

  if point.itemId then
    local guildPrice
    if getGuildGP then
      guildPrice = getGuildGP(point.itemId)
    end
    if guildPrice then
      GameTooltip:AddDoubleLine("Гильдейская цена по правилам", ("%.0f GP"):format(guildPrice),
        0.78, 0.82, 0.86, 1, 1, 1)
      if point.guildPriceOverage and point.guildPriceOverage > 0 then
        GameTooltip:AddDoubleLine("Выше гильдейской цены",
          ("+%.0f GP"):format(point.guildPriceOverage),
          COLORS.ANOMALY[1], COLORS.ANOMALY[2], COLORS.ANOMALY[3],
          COLORS.ANOMALY[1], COLORS.ANOMALY[2], COLORS.ANOMALY[3])
      end
    end

    local standardGP, standardSource
    if getStandardGP then
      standardGP, standardSource = getStandardGP(point.itemId, point.timestamp)
    end
    if standardGP and standardSource ~= "медиана GP этого предмета за период" and
      standardSource ~= "гильдейское правило по ID" and
      standardSource ~= "гильдейское правило по названию" and
      not (type(standardSource) == "string" and standardSource:find("^гильдейское правило ilvl")) then
      GameTooltip:AddDoubleLine(standardSource or "Базовая цена", ("%.0f GP"):format(standardGP),
        0.78, 0.82, 0.86, 1, 1, 1)
    end
    local itemMedian = medianGPByItem[point.itemId]
    if itemMedian then
      GameTooltip:AddDoubleLine("Медиана GP предмета за период", ("%.0f GP"):format(itemMedian),
        COLORS.GP[1], COLORS.GP[2], COLORS.GP[3], 1, 1, 1)
    end
    if standardGP then
      local category, ratio
      if inferLootCategory then
        category, ratio = inferLootCategory(point.deltaGP or 0, standardGP)
      end
      if category then
        GameTooltip:AddDoubleLine("Предполагаемая категория",
          ("%s (%.0f%%)"):format(category.label, ratio * 100), 0.90, 0.82, 0.55, 1, 1, 1)
      end
      local pricing = db.profile.guildPricing
      local multipliers = pricing.categoryMultipliers or {}
      GameTooltip:AddLine(("Ориентиры: Main %.0f | Minor %.0f | Off Twin %.0f | Roll/Trans %.0f GP"):format(
        standardGP * (multipliers.main or 1),
        standardGP * (multipliers.minor or 0.5),
        standardGP * (multipliers.offTwin or 0.25),
        standardGP * (multipliers.roll or 0)), 0.68, 0.72, 0.75, true)
    end
  end

  if point.discountPriceOverage and point.discountPriceOverage > 0 then
    GameTooltip:AddDoubleLine(("Выше цены категории %s"):format(point.discountCategory),
      ("+%.0f GP"):format(point.discountPriceOverage),
      1, 1, 1, COLORS.OVERPRICE[1], COLORS.OVERPRICE[2], COLORS.OVERPRICE[3])
  end
  local snapshot = getRankSnapshotAt(point.timestamp)
  if snapshot then
    addRankTooltip(point)
  end
  if point.highGPSlice then
    GameTooltip:AddLine(("Срез EP около %.1f%% при GP не менее %.0f"):format(
      point.dropPercent or 0, db.profile.minGPSlice or 1000),
      COLORS.DECAY[1], COLORS.DECAY[2], COLORS.DECAY[3], true)
  elseif point.anomaly then
    GameTooltip:AddLine(("Аномальное снижение %.1f%% — возможен антифриз или несмешная шутка"):format(
      point.dropPercent or 0), COLORS.ANOMALY[1], COLORS.ANOMALY[2], COLORS.ANOMALY[3], true)
  end
  if point.decay then
    GameTooltip:AddLine("Предполагаемый Decay (EP и GP снижены вместе)", COLORS.DECAY[1], COLORS.DECAY[2], COLORS.DECAY[3])
  elseif not point.itemId and not point.anomaly and point.kind ~= "EP" and point.kind ~= "GP" then
    GameTooltip:AddLine(point.reason, 0.90, 0.90, 0.90, true)
  end
  GameTooltip:AddLine("Офицер: " .. (point.officer or "Unknown"), 0.80, 0.82, 0.84)
  GameTooltip:AddLine("Состояние после этой записи", 0.68, 0.72, 0.75)
  GameTooltip:AddDoubleLine("EP", ("%.0f"):format(point.ep), COLORS.EP[1], COLORS.EP[2], COLORS.EP[3], 1, 1, 1)
  GameTooltip:AddDoubleLine("GP", ("%.0f"):format(point.gp), COLORS.GP[1], COLORS.GP[2], COLORS.GP[3], 1, 1, 1)
  GameTooltip:AddDoubleLine("PR", ("%.3f"):format(point.pr), COLORS.PR[1], COLORS.PR[2], COLORS.PR[3], 1, 1, 1)
  GameTooltip:Show()
end

handleGraphWheel = nil

function createGraphNode()
  local node = CreateFrame("Button", nil, chart)
  node:SetSize(8, 8)
  node.texture = node:CreateTexture(nil, "OVERLAY")
  node.texture:SetTexture("Interface\\Buttons\\WHITE8X8")
  node.texture:SetAllPoints(node)
  node.anomalyLabel = makeText(node, "", "GameFontNormalSmall")
  local font, fontSize, fontFlags = node.anomalyLabel:GetFont()
  if font and fontSize then
    node.anomalyLabel:SetFont(font, fontSize / 1.5, fontFlags)
  end
  node.anomalyLabel:SetPoint("RIGHT", node, "LEFT", -3, 0)
  node.anomalyLabel:SetTextColor(COLORS.OVERPRICE[1], COLORS.OVERPRICE[2], COLORS.OVERPRICE[3])
  node.anomalyLabel:Hide()
  node:SetScript("OnEnter", showPointTooltip)
  node:SetScript("OnLeave", GameTooltip_Hide)
  node:EnableMouseWheel(true)
  node:SetScript("OnMouseWheel", function(_, delta)
    if handleGraphWheel then
      handleGraphWheel(delta)
    end
  end)
  return node
end

function ensureGraphGrid()
  for i = 1, 6 do
    if not gridLines[i] then
      gridLines[i] = makeFlatTexture(chart, "BACKGROUND", 0.55, 0.60, 0.64, 0.20)
    end
    if not yLabels[i] then
      yLabels[i] = makeText(chart, "", "GameFontNormalSmall")
      yLabels[i]:SetTextColor(0.62, 0.67, 0.70)
      yLabels[i]:SetJustifyH("RIGHT")
    end
  end
  for i = 1, 5 do
    if not verticalGridLines[i] then
      verticalGridLines[i] = makeFlatTexture(chart, "BACKGROUND", 0.55, 0.60, 0.64, 0.20)
    end
    if not xLabels[i] then
      xLabels[i] = makeText(chart, "", "GameFontNormalSmall")
      xLabels[i]:SetTextColor(0.62, 0.67, 0.70)
      xLabels[i]:SetJustifyH("CENTER")
    end
  end
end

function ensureGraphLine(index)
  if not graphLines[index] then
    graphLines[index] = makeFlatTexture(chart, "ARTWORK", 1, 1, 1, 0.90)
  end
  return graphLines[index]
end

function drawGraphSegment(x1, y1, x2, y2, color, left, bottom, right, top)
  local thickness = 3
  local function clip(p, q, t0, t1)
    if math.abs(p) < 0.000001 then
      if q < 0 then
        return nil
      end
      return t0, t1
    end
    local ratio = q / p
    if p < 0 then
      if ratio > t1 then
        return nil
      end
      return math.max(t0, ratio), t1
    end
    if ratio < t0 then
      return nil
    end
    return t0, math.min(t1, ratio)
  end

  left, bottom = left + thickness * 0.5, bottom + thickness * 0.5
  right, top = right - thickness * 0.5, top - thickness * 0.5
  local dx, dy = x2 - x1, y2 - y1
  local t0, t1 = 0, 1
  local p = { -dx, dx, -dy, dy }
  local q = { x1 - left, right - x1, y1 - bottom, top - y1 }
  for i = 1, 4 do
    t0, t1 = clip(p[i], q[i], t0, t1)
    if not t0 then
      return
    end
  end
  x2, y2 = x1 + t1 * dx, y1 + t1 * dy
  x1, y1 = x1 + t0 * dx, y1 + t0 * dy
  if x1 == x2 and y1 == y2 then
    return
  end
  dx, dy = x2 - x1, y2 - y1
  if math.abs(dx) < 0.5 or math.abs(dy) < 0.5 then
    graphLineCount = graphLineCount + 1
    local line = ensureGraphLine(graphLineCount)
    line:ClearAllPoints()
    line:SetPoint("CENTER", chart, "BOTTOMLEFT", (x1 + x2) * 0.5, (y1 + y2) * 0.5)
    line:SetSize(math.max(math.abs(dx), thickness), math.max(math.abs(dy), thickness))
    line:SetVertexColor(color[1], color[2], color[3], 0.90)
    line:Show()
    return
  end
  local length = math.sqrt(dx * dx + dy * dy)
  local steps = math.max(1, math.ceil(length / (thickness * 0.65)))
  for i = 0, steps do
    local fraction = i / steps
    graphLineCount = graphLineCount + 1
    local dot = ensureGraphLine(graphLineCount)
    dot:ClearAllPoints()
    dot:SetPoint("CENTER", chart, "BOTTOMLEFT", x1 + dx * fraction, y1 + dy * fraction)
    dot:SetSize(thickness, thickness)
    dot:SetVertexColor(color[1], color[2], color[3], 0.90)
    dot:Show()
  end
end

function requestItemInfo(itemId)
  if itemLoaderTooltip and not requestedItemIcons[itemId] then
    requestedItemIcons[itemId] = true
    itemLoaderTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    itemLoaderTooltip:SetHyperlink("item:" .. itemId)
    itemLoaderTooltip:Hide()
  end
end

getTooltipItemIcon = function(itemId)
  local icon = cachedItemIcons[itemId]
  if icon then
    return icon
  end
  if GetItemInfo then
    local _, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(itemId)
    if itemIcon then
      cachedItemIcons[itemId] = itemIcon
      return itemIcon
    end
  end
  requestItemInfo(itemId)
  return nil
end

getTooltipItemLabel = function(itemId, fallbackName)
  local itemName, itemLink, quality
  if GetItemInfo then
    itemName, itemLink, quality = GetItemInfo(itemId)
  end
  local icon = getTooltipItemIcon(itemId)
  local iconMarkup = icon and ("|T%s:16:16|t "):format(icon) or ""
  if itemLink then
    return iconMarkup .. itemLink
  end
  local name = itemName or fallbackName or ("Предмет " .. itemId)
  if quality and GetItemQualityColor then
    local red, green, blue = GetItemQualityColor(quality)
    if red and green and blue then
      return iconMarkup .. ("|cff%02x%02x%02x%s|r"):format(
        math.floor(red * 255), math.floor(green * 255), math.floor(blue * 255), name)
    end
  end
  return iconMarkup .. name
end

function drawGraphNode(point, x, y, color, showIcon)
  graphNodeCount = graphNodeCount + 1
  if not graphNodes[graphNodeCount] then
    graphNodes[graphNodeCount] = createGraphNode()
  end
  local node = graphNodes[graphNodeCount]
  node.point = point
  local isOverpriced = (selectedMetric == "GP" or selectedMetric == "PR") and
    point.priceAnomaly
  if isOverpriced then
    node.anomalyLabel:SetText("Аномалия")
    node.anomalyLabel:Show()
  else
    node.anomalyLabel:Hide()
  end
  if isOverpriced then
    if not node.blinking then
      node.blinking = true
      node.blinkElapsed = 0
      node:SetScript("OnUpdate", function(self, elapsed)
        self.blinkElapsed = self.blinkElapsed + elapsed
        self:SetAlpha(0.35 + 0.65 * (0.5 + 0.5 * math.sin(self.blinkElapsed * 6)))
      end)
    end
  elseif node.blinking then
    node.blinking = nil
    node:SetScript("OnUpdate", nil)
    node:SetAlpha(1)
  end
  node:ClearAllPoints()
  node:SetPoint("CENTER", chart, "BOTTOMLEFT", x, y)

  local icon
  if showIcon and not point.anomaly and not point.decay and not point.highGPSlice and
    point.itemId and GetItemInfo then
    icon = cachedItemIcons[point.itemId]
    if not icon then
      local _, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(point.itemId)
      if itemIcon then
        cachedItemIcons[point.itemId] = itemIcon
        icon = itemIcon
      else
        requestItemInfo(point.itemId)
      end
    end
  end
  if icon then
    node:SetSize(18, 18)
    node.texture:SetTexture(icon)
    node.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if isOverpriced then
      node.texture:SetVertexColor(COLORS.OVERPRICE[1], COLORS.OVERPRICE[2], COLORS.OVERPRICE[3], 1)
    else
      node.texture:SetVertexColor(1, 1, 1, 1)
    end
  else
    node:SetSize(showIcon and point.itemId and 14 or 7, showIcon and point.itemId and 14 or 7)
    node.texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    node.texture:SetTexCoord(0, 1, 0, 1)
    local nodeColor = isOverpriced and COLORS.OVERPRICE or color
    node.texture:SetVertexColor(nodeColor[1], nodeColor[2], nodeColor[3], 1)
  end
  if point.anomaly or point.highGPSlice then
    node:SetSize(11, 11)
  elseif point.decay then
    node:SetSize(10, 10)
  end
  node:Show()
end

function getHistoryTimeBounds()
  if not db then
    return nil, nil
  end
  local minimumTime, maximumTime
  for _, event in ipairs(history) do
    if (event.kind == "EP" or event.kind == "GP") and event.player ~= "GUILD_BANK" then
      minimumTime = math.min(minimumTime or event.timestamp, event.timestamp)
      maximumTime = math.max(maximumTime or event.timestamp, event.timestamp)
    end
  end
  if minimumTime and maximumTime <= minimumTime then
    minimumTime = minimumTime - 12 * 60 * 60
    maximumTime = maximumTime + 12 * 60 * 60
  end
  return minimumTime, maximumTime
end

drawChart = function()
  updateRangeControls()
  updateCurrentBalanceText()
  updateCurrentRankList()
  if graphScaleText and db then
    db.profile.valueZoom = db.profile.valueZoom or {}
    local zoom = math.max(0.2, math.min(5,
      db.profile.valueZoom[selectedMetric] or 1))
    graphScaleText:SetText(("Масштаб: %.2f×"):format(zoom))
  end
  if not chart or not chart:IsShown() then
    return
  end
  ensureGraphGrid()
  local names = visiblePlayerNames()
  local legendRows = updateTimelineLegend(names)
  if #names == 0 then
    graphLineCount, graphNodeCount = 0, 0
    for _, texture in ipairs(graphLines) do texture:Hide() end
    for _, node in ipairs(graphNodes) do node:Hide() end
    for i = 1, 6 do
      yLabels[i]:SetText(i == 1 and "0" or "")
    end
    for i = 1, 5 do
      xLabels[i]:SetText("")
    end
    graphDomainStart, graphDomainEnd = nil, nil
    if rangeThumb then
      rangeThumb:Hide()
    end
    setStatus("Выберите одного или нескольких игроков, чтобы построить график.")
    return
  end
  rebuildItemGPMedians()
  local series = {}
  local minimumTime, maximumTime
  local hasCurrentBalance = true
  if selectedMetric == "RANK" then
    ensureRankSnapshots()
  end
  for _, event in ipairs(history) do
    if (event.kind == "EP" or event.kind == "GP") and event.player ~= "GUILD_BANK" then
      minimumTime = math.min(minimumTime or event.timestamp, event.timestamp)
      maximumTime = math.max(maximumTime or event.timestamp, event.timestamp)
    end
  end
  if selectedMetric == "RANK" then
    for index, name in ipairs(names) do
      local points = {}
      local previousRank
      local playerIndex = rankPlayerIndexes[name]
      for _, snapshot in ipairs(rankSnapshots) do
        local rank = playerIndex and snapshot.positions[playerIndex]
        if rank and rank ~= previousRank then
          table.insert(points, {
            timestamp = snapshot.timestamp,
            player = name,
            kind = "RANK",
            reason = "Рейтинг обновлён",
            rank = rank,
            rankBefore = previousRank,
            rankAfter = rank,
            rankCount = snapshot.count,
          })
        end
        previousRank = rank
      end
      if #points > 0 then
        table.insert(series, {
          name = name,
          points = points,
          color = #names == 1 and COLORS.RANK or
            PLAYER_COLORS[(index - 1) % #PLAYER_COLORS + 1],
        })
      end
    end
  else
    for index, name in ipairs(names) do
      local points, hasBalance = buildTimeline(name)
      hasCurrentBalance = hasCurrentBalance and hasBalance
      if #points > 0 then
        table.insert(series, {
          name = name,
          points = points,
          color = #names == 1 and COLORS[selectedMetric] or
            PLAYER_COLORS[(index - 1) % #PLAYER_COLORS + 1],
        })
      end
    end
  end

  local width, height = chart:GetWidth(), chart:GetHeight()
  local left, bottom = 64, 42
  local plotWidth = math.max(width - 84, 1)
  local plotHeight = math.max(height - 70 - legendRows * 18, 1)

  for i = 1, 6 do
    local y = bottom + plotHeight * (i - 1) / 5
    local line = gridLines[i]
    line:ClearAllPoints()
    line:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", left, y)
    line:SetSize(plotWidth, 1)
    line:Show()
  end
  for i = 1, 5 do
    local x = left + plotWidth * (i - 1) / 4
    local line = verticalGridLines[i]
    line:ClearAllPoints()
    line:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", x, bottom)
    line:SetSize(1, plotHeight)
    line:Show()
  end

  for i = 1, 6 do
    local label = yLabels[i]
    label:ClearAllPoints()
    label:SetPoint("RIGHT", chart, "BOTTOMLEFT", left - 7, bottom + plotHeight * (i - 1) / 5)
  end

  if not minimumTime then
    graphLineCount, graphNodeCount = 0, 0
    for _, texture in ipairs(graphLines) do texture:Hide() end
    for _, node in ipairs(graphNodes) do node:Hide() end
    yLabels[1]:SetText("0")
    for i = 2, 6 do yLabels[i]:SetText("") end
    for i = 1, 5 do xLabels[i]:SetText("") end
    graphDomainStart, graphDomainEnd = nil, nil
    setStatus("Нет событий для отображения. Проверьте фильтр неактивных игроков.")
    return
  end

  if maximumTime <= minimumTime then
    minimumTime = minimumTime - 12 * 60 * 60
    maximumTime = maximumTime + 12 * 60 * 60
  end
  graphDomainStart, graphDomainEnd = minimumTime, maximumTime
  local rangePadding = math.max(0, tonumber(db.profile.rangePadding) or 0)
  local rangeStart = db.profile.rangeStart > 0 and
    math.max(minimumTime - rangePadding, math.min(db.profile.rangeStart, maximumTime + rangePadding)) or minimumTime
  local rangeEnd = db.profile.rangeEnd > 0 and
    math.max(minimumTime - rangePadding, math.min(db.profile.rangeEnd, maximumTime + rangePadding)) or maximumTime
  if db.profile.rangeStart > 0 then
    db.profile.rangeStart = rangeStart
  end
  if db.profile.rangeEnd > 0 then
    db.profile.rangeEnd = rangeEnd
  end
  if rangeEnd <= rangeStart then
    rangeStart, rangeEnd = minimumTime, maximumTime
    db.profile.rangeStart, db.profile.rangeEnd = 0, 0
  end
  local rangeDuration = math.max(rangeEnd - rangeStart, 1)
  updateRangeControls()
  updateRangeBar()

  local maximumValue = 0
  local minimumValue = 0
  if selectedMetric == "RANK" then
    local largestRanking = 1
    for _, snapshot in ipairs(rankSnapshots) do
      if snapshot.timestamp <= rangeEnd then
        largestRanking = math.max(largestRanking, snapshot.count)
      end
    end
    minimumValue, maximumValue = 0.5, largestRanking + 0.5
    if maximumValue - minimumValue < 1 then
      maximumValue = minimumValue + 1
    end
  else
    for _, entry in ipairs(series) do
      local previous
      local nextPoint
      local hasVisiblePoint = false
      for _, point in ipairs(entry.points) do
        if point.timestamp < rangeStart then
          previous = point
        elseif point.timestamp <= rangeEnd then
          hasVisiblePoint = true
          maximumValue = math.max(maximumValue, getGraphMetric(point))
          minimumValue = math.min(minimumValue, getGraphMetric(point))
        elseif not nextPoint or point.timestamp < nextPoint.timestamp then
          nextPoint = point
        end
      end
      if previous then
        maximumValue = math.max(maximumValue, getGraphMetric(previous))
        minimumValue = math.min(minimumValue, getGraphMetric(previous))
      elseif not hasVisiblePoint and nextPoint then
        maximumValue = math.max(maximumValue, getGraphMetric(nextPoint))
        minimumValue = math.min(minimumValue, getGraphMetric(nextPoint))
      end
    end
    local valueRange = maximumValue - minimumValue
    if valueRange <= 0 then
      maximumValue = minimumValue + 1
    else
      maximumValue = maximumValue + valueRange * 0.04
      minimumValue = minimumValue - valueRange * 0.04
    end
  end
  local baseValueRange = maximumValue - minimumValue
  graphBaseValueCenter = (minimumValue + maximumValue) * 0.5
  db.profile.valuePan = db.profile.valuePan or {}
  db.profile.valueZoom = db.profile.valueZoom or {}
  local zoom = math.max(0.2, math.min(5, db.profile.valueZoom[selectedMetric] or 1))
  db.profile.valueZoom[selectedMetric] = zoom
  local valueRange = baseValueRange * zoom
  local maximumPan = baseValueRange * 0.5
  local valueOffset = math.max(-maximumPan, math.min(
    maximumPan, db.profile.valuePan[selectedMetric] or 0))
  db.profile.valuePan[selectedMetric] = valueOffset
  local valueCenter = (minimumValue + maximumValue) * 0.5 + valueOffset
  minimumValue = valueCenter - valueRange * 0.5
  maximumValue = valueCenter + valueRange * 0.5
  graphValueRange = valueRange
  graphValueCenter = valueCenter
  graphValueMinimum = minimumValue
  graphValueMaximum = maximumValue
  graphBaseValueRange = baseValueRange
  graphPlotHeight = plotHeight

  for i = 1, 6 do
    local fraction = (i - 1) / 5
    if selectedMetric == "RANK" then
      local rankLabel = math.floor(maximumValue - valueRange * fraction + 0.5)
      rankLabel = math.max(1, rankLabel)
      yLabels[i]:SetText(("%d"):format(rankLabel))
    else
      local value = minimumValue + valueRange * fraction
      yLabels[i]:SetText(selectedMetric == "PR" and ("%.2f"):format(value) or ("%.0f"):format(value))
    end
  end
  for i = 1, 5 do
    local fraction = (i - 1) / 4
    local timestamp = rangeStart + rangeDuration * fraction
    xLabels[i]:SetText(date(rangeDuration > 365 * 24 * 60 * 60 and "%d.%m.%y" or "%d.%m", timestamp))
    xLabels[i]:ClearAllPoints()
    xLabels[i]:SetPoint("TOP", chart, "BOTTOMLEFT", left + plotWidth * fraction, bottom - 7)
  end

  graphLineCount, graphNodeCount = 0, 0
  local sampleLimit = #series > 1 and math.max(24, math.floor(700 / #series)) or 700
  for _, entry in ipairs(series) do
    local visible = {}
    local previous
    local nextPoint
    for i, point in ipairs(entry.points) do
      if point.timestamp < rangeStart then
        previous = { index = i, point = point }
      elseif point.timestamp <= rangeEnd then
        table.insert(visible, { index = i, point = point })
      elseif not nextPoint or point.timestamp < nextPoint.point.timestamp then
        nextPoint = { index = i, point = point }
      end
    end

    local selected = {}
    if previous then
      previous.boundary = true
      table.insert(selected, previous)
    end
    local stride = math.max(1, math.ceil(#visible / sampleLimit))
    for i, entryPoint in ipairs(visible) do
      local point = entryPoint.point
      local rankChanged = selectedMetric == "RANK" and
        (i == 1 or point.rank ~= visible[i - 1].point.rank)
      if (i - 1) % stride == 0 or rankChanged or point.decay or point.anomaly or
        point.highGPSlice or
        (point.kind == "GP" and point.itemId) or i == #visible then
        table.insert(selected, entryPoint)
      end
    end
    if nextPoint then
      nextPoint.boundary = true
      table.insert(selected, nextPoint)
    end

    local lastX, lastY
    for _, entryPoint in ipairs(selected) do
      local point = entryPoint.point
      local x = left + (point.timestamp - rangeStart) / rangeDuration * plotWidth
      local value = getGraphMetric(point)
      local y
      if selectedMetric == "RANK" then
        y = bottom + (maximumValue - value) / valueRange * plotHeight
      else
        y = bottom + (value - minimumValue) / valueRange * plotHeight
      end
      if lastX then
        if selectedMetric == "RANK" then
          drawGraphSegment(lastX, lastY, x, lastY, entry.color,
            left, bottom, left + plotWidth, bottom + plotHeight)
          local transitionColor = point.priceAnomaly and COLORS.OVERPRICE or
            point.highGPSlice and COLORS.DECAY or
            point.anomaly and COLORS.ANOMALY or
            point.decay and COLORS.DECAY or entry.color
          drawGraphSegment(x, lastY, x, y, transitionColor,
            left, bottom, left + plotWidth, bottom + plotHeight)
        else
          drawGraphSegment(lastX, lastY, x, lastY, entry.color,
            left, bottom, left + plotWidth, bottom + plotHeight)
          local transitionColor = point.priceAnomaly and COLORS.OVERPRICE or
            point.highGPSlice and COLORS.DECAY or
            point.anomaly and COLORS.ANOMALY or
            point.decay and COLORS.DECAY or entry.color
          drawGraphSegment(x, lastY, x, y, transitionColor,
            left, bottom, left + plotWidth, bottom + plotHeight)
        end
      elseif point.priceAnomaly and not entryPoint.boundary and
        (selectedMetric == "GP" or selectedMetric == "PR") then
        local previousValue = selectedMetric == "GP" and point.previousGP or point.previousPR
        local previousY = bottom + (previousValue - minimumValue) / valueRange * plotHeight
        drawGraphSegment(x, previousY, x, y, COLORS.OVERPRICE,
          left, bottom, left + plotWidth, bottom + plotHeight)
      end
      local nodeMargin = selectedMetric == "RANK" and 2 or 9
      local showMetricPoint = selectedMetric ~= "GP" or point.kind == "GP" or point.highGPSlice
      if showMetricPoint and
        (not entryPoint.boundary or selectedMetric == "RANK") and
        x >= left and x <= left + plotWidth - nodeMargin and
        y >= bottom + nodeMargin and y <= bottom + plotHeight - nodeMargin then
        point.player = entry.name
        local pointColor = point.highGPSlice and COLORS.DECAY or
          point.anomaly and COLORS.ANOMALY or
          point.decay and COLORS.DECAY or entry.color
        local showIcon = (selectedMetric == "GP" or selectedMetric == "PR") and point.kind == "GP" and point.itemId ~= nil
        drawGraphNode(point, x, y, pointColor, showIcon)
      end
      lastX, lastY = x, y
    end
  end

  for i = graphLineCount + 1, #graphLines do graphLines[i]:Hide() end
  for i = graphNodeCount + 1, #graphNodes do graphNodes[i]:Hide() end

  if selectedMetric == "RANK" and #series == 0 then
    setStatus("Нет позиции для выбранного игрока. Проверьте фильтр классов и полноту журнала.")
  elseif selectedMetric == "RANK" and not rankBalancesComplete then
    setStatus("Рейтинг приблизительный: нет текущих исторических балансов для всех игроков. Точки строятся по доступным событиям.")
  elseif selectedMetric == "RANK" then
    setStatus("Место рассчитано по PR (EP / GP); классы ограничиваются кнопкой «Классы места».")
  elseif #names > 1 then
    setStatus(("Игроков на графике: %d; период %s — %s%s"):format(
      #names, date("%d.%m.%Y", rangeStart), date("%d.%m.%Y", rangeEnd),
      db.profile.hideInactivePlayers and ("; скрыты без событий более %d мес."):format(db.profile.inactiveAfterMonths) or ""))
  elseif not hasCurrentBalance and db.profile.grouping == "toon" then
    setStatus("Режим персонажей: показаны изменения по доступным событиям; EPGP хранит остаток только на уровне мейна.")
  elseif not hasCurrentBalance then
    setStatus("Начальный баланс недоступен; график показывает изменения по событиям доступного журнала.")
  elseif #history > 0 then
    setStatus(historyStatus)
  end
end

function formatDateInput(timestamp)
  return timestamp and date("%Y-%m-%d", timestamp) or ""
end

function parseDateInput(value, endOfDay)
  if type(value) ~= "string" then
    return nil
  end
  local year, month, day = value:match("^%s*(%d%d%d%d)%-(%d%d)%-(%d%d)%s*$")
  year, month, day = tonumber(year), tonumber(month), tonumber(day)
  if not year or not month or not day then
    return nil
  end
  local result = time({
    year = year,
    month = month,
    day = day,
    hour = endOfDay and 23 or 0,
    min = endOfDay and 59 or 0,
    sec = endOfDay and 59 or 0,
  })
  if date("%Y-%m-%d", result) ~= ("%04d-%02d-%02d"):format(year, month, day) then
    return nil
  end
  return result
end

getGuildPriceEffectiveTimestamp = function()
  local pricing = db and db.profile.guildPricing
  local effectiveDate = pricing and pricing.priceEffectiveDate or DEFAULT_GUILD_PRICE_EFFECTIVE_DATE
  return parseDateInput(effectiveDate, false) or
    parseDateInput(DEFAULT_GUILD_PRICE_EFFECTIVE_DATE, false)
end

updateRangeControls = function()
  if not rangeFromEdit then
    return
  end
  local minimumTime, maximumTime = getHistoryTimeBounds()
  if not minimumTime then
    if not rangeFromEdit:HasFocus() then
      rangeFromEdit:SetText("")
    end
    if not rangeToEdit:HasFocus() then
      rangeToEdit:SetText("")
    end
    return
  end
  local start = db.profile.rangeStart > 0 and
    math.max(minimumTime, math.min(db.profile.rangeStart, maximumTime)) or minimumTime
  local finish = db.profile.rangeEnd > 0 and
    math.max(minimumTime, math.min(db.profile.rangeEnd, maximumTime)) or maximumTime
  if db.profile.rangeStart > 0 then
    db.profile.rangeStart = start
  end
  if db.profile.rangeEnd > 0 then
    db.profile.rangeEnd = finish
  end
  if (db.profile.rangeStart > 0 or db.profile.rangeEnd > 0) and finish <= start then
    db.profile.rangeStart, db.profile.rangeEnd = 0, 0
    start, finish = minimumTime, maximumTime
  end
  if not rangeFromEdit:HasFocus() then
    rangeFromEdit:SetText(formatDateInput(start))
  end
  if not rangeToEdit:HasFocus() then
    rangeToEdit:SetText(formatDateInput(finish))
  end
end

updateRangeBar = function()
  if not rangeBar or not graphDomainStart or not graphDomainEnd then
    return
  end
  local padding = math.max(0, tonumber(db.profile.rangePadding) or 0)
  local domainStart = graphDomainStart - padding
  local domainEnd = graphDomainEnd + padding
  local domain = math.max(domainEnd - domainStart, 1)
  local start = db.profile.rangeStart > 0 and db.profile.rangeStart or graphDomainStart
  local finish = db.profile.rangeEnd > 0 and db.profile.rangeEnd or graphDomainEnd
  local leftFraction = math.max(0, math.min(1, (start - domainStart) / domain))
  local rightFraction = math.max(leftFraction, math.min(1, (finish - domainStart) / domain))
  local width = rangeBar:GetWidth()
  local thumbWidth = math.max(12, width * (rightFraction - leftFraction))
  local thumbLeft = math.min(width - thumbWidth, width * leftFraction)
  rangeThumb:ClearAllPoints()
  rangeThumb:SetPoint("LEFT", rangeBar, "LEFT", math.max(0, thumbLeft), 0)
  rangeThumb:SetWidth(thumbWidth)
  rangeThumb:Show()
end

function setVisibleRange(start, finish, padding)
  local minimumTime, maximumTime = getHistoryTimeBounds()
  if start and finish and minimumTime and maximumTime then
    local rangePadding = math.max(0, tonumber(padding) or 0)
    local duration = math.max(1, math.min(maximumTime - minimumTime + rangePadding * 2, finish - start))
    start = math.max(minimumTime - rangePadding,
      math.min(start, maximumTime + rangePadding - duration))
    db.profile.rangeStart = start
    db.profile.rangeEnd = start + duration
    db.profile.rangePadding = rangePadding
  else
    db.profile.rangeStart, db.profile.rangeEnd = 0, 0
    db.profile.rangePadding = 0
  end
  updateRangeControls()
  updateRangeBar()
  drawChart()
  if drawDropLineChart then
    drawDropLineChart()
  end
  if efficiencyPanel and efficiencyPanel:IsShown() then
    renderEfficiency()
  end
  if itemPanel and itemPanel:IsShown() then
    renderItemAnalysis()
  end
end

function applyDateRange()
  local minimumTime, maximumTime = getHistoryTimeBounds()
  if not minimumTime then
    setStatus("Нет данных, для которых можно задать период.")
    return
  end
  local fromValue = rangeFromEdit:GetText()
  local toValue = rangeToEdit:GetText()
  if fromValue == "" and toValue == "" then
    setVisibleRange(nil, nil)
    return
  end
  local start = fromValue == "" and minimumTime or parseDateInput(fromValue, false)
  local finish = toValue == "" and maximumTime or parseDateInput(toValue, true)
  if not start or not finish or finish <= start then
    setStatus("Введите даты в формате ГГГГ-ММ-ДД; дата «по» должна быть позже даты «с».")
    return
  end
  start = math.max(minimumTime, math.min(start, maximumTime))
  finish = math.max(minimumTime, math.min(finish, maximumTime))
  if finish <= start then
    setStatus("Выбранный период не пересекается с датами журнала.")
    return
  end
  setVisibleRange(start, finish)
end

function setQuickRange(days)
  local minimumTime, maximumTime = getHistoryTimeBounds()
  if not minimumTime or not maximumTime then
    return
  end
  if not days then
    setVisibleRange(nil, nil)
  else
    setVisibleRange(math.max(minimumTime, maximumTime - days * 24 * 60 * 60), maximumTime)
  end
end

function startRangeDrag()
  if not graphDomainStart or not graphDomainEnd then
    return
  end
  local padding = math.max(0, tonumber(db.profile.rangePadding) or 0)
  rangeDrag = {
    cursorX = GetCursorPosition() / UIParent:GetEffectiveScale(),
    start = db.profile.rangeStart > 0 and db.profile.rangeStart or graphDomainStart,
    finish = db.profile.rangeEnd > 0 and db.profile.rangeEnd or graphDomainEnd,
    minimumTime = graphDomainStart - padding,
    maximumTime = graphDomainEnd + padding,
    domain = graphDomainEnd - graphDomainStart + padding * 2,
    width = math.max(rangeBar:GetWidth(), 1),
    lastDelta = nil,
  }
  rangeDragElapsed = 0
  rangeBar:SetScript("OnUpdate", function(_, elapsed)
    if not rangeDrag then
      return
    end
    rangeDragElapsed = rangeDragElapsed + elapsed
    if rangeDragElapsed < 0.05 then
      return
    end
    rangeDragElapsed = 0
    local cursorX = GetCursorPosition() / UIParent:GetEffectiveScale()
    local delta = (cursorX - rangeDrag.cursorX) / rangeDrag.width * rangeDrag.domain
    if rangeDrag.lastDelta and math.abs(delta - rangeDrag.lastDelta) < 60 then
      return
    end
    rangeDrag.lastDelta = delta
    local duration = rangeDrag.finish - rangeDrag.start
    local start = math.max(rangeDrag.minimumTime,
      math.min(rangeDrag.start + delta, rangeDrag.maximumTime - duration))
    db.profile.rangeStart = start
    db.profile.rangeEnd = start + duration
    updateRangeBar()
    drawChart()
  end)
end

function stopRangeDrag()
  if rangeDrag then
    local cursorX = GetCursorPosition() / UIParent:GetEffectiveScale()
    local delta = (cursorX - rangeDrag.cursorX) / rangeDrag.width * rangeDrag.domain
    local duration = rangeDrag.finish - rangeDrag.start
    local start = math.max(rangeDrag.minimumTime,
      math.min(rangeDrag.start + delta, rangeDrag.maximumTime - duration))
    db.profile.rangeStart = start
    db.profile.rangeEnd = start + duration
    drawChart()
  end
  rangeDrag = nil
  if rangeBar then
    rangeBar:SetScript("OnUpdate", nil)
  end
  updateRangeControls()
end

function getChartCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  local chartLeft = chart:GetLeft()
  local chartBottom = chart:GetBottom()
  if not chartLeft or not chartBottom then
    return nil, nil
  end
  local cursorX, cursorY = GetCursorPosition()
  return cursorX / scale - chartLeft, cursorY / scale - chartBottom
end

function startChartPan(_, button)
  if button ~= "LeftButton" or not graphDomainStart or not graphDomainEnd then
    return
  end
  local cursorX, cursorY = getChartCursorPosition()
  if not cursorX then
    return
  end
  local start = db.profile.rangeStart > 0 and db.profile.rangeStart or graphDomainStart
  local finish = db.profile.rangeEnd > 0 and db.profile.rangeEnd or graphDomainEnd
  db.profile.valuePan = db.profile.valuePan or {}
  chartPan = {
    cursorX = cursorX,
    cursorY = cursorY,
    start = start,
    finish = finish,
    valueOffset = db.profile.valuePan[selectedMetric] or 0,
    duration = finish - start,
    plotWidth = math.max(chart:GetWidth() - 84, 1),
    plotHeight = math.max(graphPlotHeight, 1),
    valueRange = graphValueRange,
    maximumPan = graphBaseValueRange * 0.5,
  }
  chartPanElapsed = 0
  chart:SetScript("OnUpdate", function(_, elapsed)
    if not chartPan then
      return
    end
    if not IsMouseButtonDown("LeftButton") then
      chartPan = nil
      chart:SetScript("OnUpdate", nil)
      updateRangeControls()
      return
    end
    chartPanElapsed = chartPanElapsed + elapsed
    if chartPanElapsed < 0.03 then
      return
    end
    chartPanElapsed = 0
    local currentX, currentY = getChartCursorPosition()
    if not currentX then
      return
    end
    local deltaX = (currentX - chartPan.cursorX) / chartPan.plotWidth * chartPan.duration
    local padding = math.max(0, tonumber(db.profile.rangePadding) or 0)
    local start = math.max(graphDomainStart - padding, math.min(
      chartPan.start - deltaX, graphDomainEnd + padding - chartPan.duration))
    db.profile.rangeStart = start
    db.profile.rangeEnd = start + chartPan.duration

    local deltaY = currentY - chartPan.cursorY
    local verticalDirection = selectedMetric == "RANK" and 1 or -1
    db.profile.valuePan[selectedMetric] = math.max(-chartPan.maximumPan, math.min(
      chartPan.maximumPan, chartPan.valueOffset +
        verticalDirection * deltaY / chartPan.plotHeight * chartPan.valueRange))
    updateRangeControls()
    updateRangeBar()
    drawChart()
  end)
end

function stopChartPan(_, button)
  if button ~= "LeftButton" or not chartPan then
    return
  end
  chartPan = nil
  chart:SetScript("OnUpdate", nil)
  updateRangeControls()
end

function zoomTimeRangeAtCursor(frame, leftInset, rightInset, domainStart, domainEnd,
    delta, minimumDuration)
  if not domainStart or not domainEnd or domainEnd <= domainStart then
    return
  end
  local fullDuration = domainEnd - domainStart
  local minimumTime, maximumTime = getHistoryTimeBounds()
  if not minimumTime or not maximumTime then
    return
  end
  local currentStart = db.profile.rangeStart > 0 and db.profile.rangeStart or domainStart
  local currentEnd = db.profile.rangeEnd > 0 and db.profile.rangeEnd or domainEnd
  local currentDuration = currentEnd - currentStart
  local nextDuration = math.max(minimumDuration or 1,
    math.min(fullDuration, currentDuration * (delta > 0 and 0.75 or 1.33)))
  if nextDuration >= fullDuration * 0.999 then
    setVisibleRange(nil, nil)
    return
  end

  local cursorX = GetCursorPosition() / UIParent:GetEffectiveScale()
  local frameLeft = frame:GetLeft()
  if not frameLeft then
    return
  end
  local plotLeft = frameLeft + leftInset
  local plotWidth = math.max(frame:GetWidth() - leftInset - rightInset, 1)
  local fraction = math.max(0, math.min(1, (cursorX - plotLeft) / plotWidth))
  local anchor = currentStart + currentDuration * fraction
  local start = anchor - nextDuration * fraction
  local padding = nextDuration * 0.5
  start = math.max(minimumTime - padding,
    math.min(start, maximumTime + padding - nextDuration))
  setVisibleRange(start, start + nextDuration, padding)
end

handleGraphWheel = function(delta)
  if IsShiftKeyDown() then
    if not graphDomainStart or not graphDomainEnd or graphValueRange <= 0 then
      return
    end
    db.profile.valueZoom = db.profile.valueZoom or {}
    local zoom = db.profile.valueZoom[selectedMetric] or 1
    local factor = delta > 0 and 0.8 or 1.25
    local nextZoom = math.max(0.2, math.min(5, zoom * factor))
    local plotBottom = chart:GetBottom()
    if plotBottom and graphValueRange > 0 then
      local cursorY = GetCursorPosition() / UIParent:GetEffectiveScale() - plotBottom
      local plotHeight = math.max(graphPlotHeight, 1)
      local fraction = math.max(0, math.min(1, (cursorY - 42) / plotHeight))
      local direction = selectedMetric == "RANK" and -1 or 1
      local anchorValue = graphValueCenter +
        direction * (fraction - 0.5) * graphValueRange
      local nextRange = graphBaseValueRange * nextZoom
      local nextCenter = anchorValue - direction * (fraction - 0.5) * nextRange
      db.profile.valuePan = db.profile.valuePan or {}
      db.profile.valuePan[selectedMetric] = math.max(-graphBaseValueRange * 0.5,
        math.min(graphBaseValueRange * 0.5, nextCenter - graphBaseValueCenter))
    end
    db.profile.valueZoom[selectedMetric] = nextZoom
    drawChart()
    return
  end
  zoomTimeRangeAtCursor(chart, 64, 20, graphDomainStart, graphDomainEnd,
    delta, 60 * 60)
end
