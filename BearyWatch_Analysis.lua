local addon = _G.BearyWatch
if type(addon) ~= "table" or type(addon.environment) ~= "table" then
  error("BearyWatch shared environment was not initialized.")
end
setfenv(1, addon.environment)
function selectMetric(metric)
  if metric ~= selectedMetric then
    rankSnapshotsDirty = true
  end
  selectedMetric = metric
  for name, button in pairs(metricButtons) do
    button.isActive = name == metric
    local color = COLORS[name]
    button.activeColor = color
    if button.isActive then
      button.background:SetVertexColor(color[1], color[2], color[3], 0.55)
    else
      button.background:SetVertexColor(0.12, 0.15, 0.18, 1)
    end
  end
  if updateRankLayout then
    updateRankLayout()
  end
  drawChart()
end

function updateLootControlHighlights()
  local function setActive(button, active)
    if not button then
      return
    end
    button.isActive = active
    button.activeColor = active and COLORS.EP or nil
    if active then
      button.background:SetVertexColor(
        COLORS.EP[1], COLORS.EP[2], COLORS.EP[3], 0.55)
    else
      button.background:SetVertexColor(0.12, 0.15, 0.18, 1)
    end
  end

  local selectedNames = visiblePlayerNames()
  local playerActive = #selectedNames > 0 and
    (activeTab == "timeline" or
      (activeTab == "items" and not bossLoot.mode and not selectedItemId))
  local itemActive = activeTab == "items" and
    not bossLoot.mode and selectedItemId ~= nil
  local bossLootActive = activeTab == "items" and bossLoot.mode
  setActive(playerDropdown, playerActive)
  setActive(itemDropdown, itemActive)
  setActive(bossLoot.modeButton, bossLootActive)
end

function refreshClassFilterControls()
  if not db then
    return
  end
  db.profile.classFilters = db.profile.classFilters or {}
  local enabledCount = 0
  for _, option in ipairs(CLASS_OPTIONS) do
    local enabled = db.profile.classFilters[option.token] ~= false
    if enabled then
      enabledCount = enabledCount + 1
    end
    local row = classFilterRows[option.token]
    if row then
      row.isActive = enabled
      row.activeColor = { 0.18, 0.34, 0.24 }
      row.label:SetText((enabled and "[x] " or "[ ] ") .. option.label)
      local colors = RAID_CLASS_COLORS
      local color = colors and colors[option.token]
      if color then
        row.label:SetTextColor(color.r, color.g, color.b)
      else
        row.label:SetTextColor(0.88, 0.91, 0.94)
      end
      row.background:SetVertexColor(enabled and 0.18 or 0.12, enabled and 0.28 or 0.15,
        enabled and 0.20 or 0.18, 1)
    end
  end
  if classFilterButton then
    classFilterButton.label:SetText(("Классы места %d/10"):format(enabledCount))
  end
end

function updatePlayerDropdown()
  if not playerDropdown then
    return
  end
  local allNames = sortedPlayerNames()
  local previousSelection = selectedPlayer
  local selectedNames = visiblePlayerNames()
  selectedPlayer = selectedNames[1]
  if selectedPlayer ~= previousSelection then
    rankSnapshotsDirty = true
  end
  local selectedName = #selectedNames == 0 and "Выбрать игроков" or
    #selectedNames == 1 and selectedNames[1] or
    ("Игроков: %d"):format(#selectedNames)
  playerDropdown.label:SetText(selectedName)
  if #selectedNames == 1 then
    local selectedClassColor = playerClassColor(selectedNames[1])
    playerDropdown.label:SetTextColor(selectedClassColor.r, selectedClassColor.g, selectedClassColor.b)
  else
    playerDropdown.label:SetTextColor(0.88, 0.91, 0.94)
  end
  updateLootControlHighlights()
  local entries = {}
  local query = playerSearch and playerSearch:GetText():lower() or ""
  local filtered = {}
  for _, name in ipairs(allNames) do
    local alts = getGuildAltsForMain and getGuildAltsForMain(name) or {}
    local matched = query == "" or name:lower():find(query, 1, true)
    if not matched then
      for _, alt in ipairs(alts) do
        if alt:lower():find(query, 1, true) then
          matched = true
          break
        end
      end
    end
    if matched then
      local mainColor = playerClassColor(name)
      local mainName = ("|cff%02x%02x%02x%s|r"):format(
        math.floor(mainColor.r * 255), math.floor(mainColor.g * 255), math.floor(mainColor.b * 255), name)
      local altLines = {}
      for _, alt in ipairs(alts) do
        local altColor = playerClassColor(alt)
        table.insert(altLines, ("|cff%02x%02x%02x%s|r"):format(
          math.floor(altColor.r * 255), math.floor(altColor.g * 255),
          math.floor(altColor.b * 255), alt))
      end
      table.insert(filtered, {
        label = (selectedPlayers[name] and "[x] " or "[ ] ") .. mainName ..
          (#altLines > 0 and ("\n" .. table.concat(altLines, "\n")) or ""),
        value = name,
        height = #altLines > 0 and (23 + #altLines * 15) or 24,
      })
    end
  end
  for _, entry in ipairs(filtered) do
    table.insert(entries, entry)
  end
  local contentHeight = 0
  for _, entry in ipairs(entries) do
    contentHeight = contentHeight + (entry.height or 24)
  end
  playerDropdownContent:SetHeight(math.max(contentHeight, 1))
  local menuHeight = math.max(80, math.min(contentHeight + 40, 244))
  playerDropdownMenu:SetHeight(menuHeight)
  playerDropdownScroll:SetVerticalScroll(0)

  local contentOffset = 0
  for index, entry in ipairs(entries) do
    if not playerDropdownRows[index] then
      playerDropdownRows[index] = makeButton(playerDropdownContent, "", 220, 24, function(self)
        if selectedPlayers[self.playerValue] then
          selectedPlayers[self.playerValue] = nil
        else
          selectedPlayers[self.playerValue] = true
        end
        db.profile.timelinePlayers = selectedPlayers
        local selected = visiblePlayerNames()
        selectedPlayer = selected[1]
        if selectedPlayer then
          db.profile.lastSelectedPlayer = selectedPlayer
        end
        rankSnapshotsDirty = true
        updatePlayerDropdown()
        if activeTab == "items" then
          selectedItemId = nil
          itemSortColumn = "timestamp"
          itemSortDescending = true
          bossLoot.mode = false
          bossLoot.view = "loot"
          if bossLoot and bossLoot.updateControls then
            bossLoot.updateControls()
          end
          updateItemDropdown()
          renderItemAnalysis()
        elseif drawChart then
          drawChart()
        end
      end)
      playerDropdownRows[index].label:ClearAllPoints()
      playerDropdownRows[index].label:SetPoint("TOPLEFT", playerDropdownRows[index], "TOPLEFT", 8, -4)
      playerDropdownRows[index].label:SetPoint("TOPRIGHT", playerDropdownRows[index], "TOPRIGHT", -6, -4)
      playerDropdownRows[index].label:SetJustifyH("LEFT")
      playerDropdownRows[index].label:SetJustifyV("TOP")
      playerDropdownRows[index].label:SetWordWrap(true)
    end
    local row = playerDropdownRows[index]
    local rowHeight = entry.height or 24
    row:ClearAllPoints()
    row:SetHeight(rowHeight)
    row:SetPoint("TOPLEFT", playerDropdownContent, "TOPLEFT", 0, -contentOffset)
    row:SetPoint("TOPRIGHT", playerDropdownContent, "TOPRIGHT", 0, -contentOffset)
    contentOffset = contentOffset + rowHeight
    row.playerValue = entry.value
    row.label:SetText(entry.label)
    row.label:SetTextColor(0.88, 0.91, 0.94)
    local isSelected = selectedPlayers[entry.value]
    row.background:SetVertexColor(isSelected and 0.20 or 0.12,
      isSelected and 0.30 or 0.15, isSelected and 0.35 or 0.18, 1)
    row:Show()
  end
  for index = #entries + 1, #playerDropdownRows do
    playerDropdownRows[index]:Hide()
  end
end

function togglePlayerDropdown()
  if playerDropdownMenu:IsShown() then
    playerDropdownMenu:Hide()
  else
    updatePlayerDropdown()
    playerSearch:Show()
    playerDropdownMenu:Show()
  end
end

getGuildGP = function(itemId)
  local pricing = db.profile.guildPricing
  if not pricing.useGuildRules then
    return nil
  end
  local itemPrices = pricing.itemPrices or {}
  local exactPrice = itemPrices[itemId]
  if type(exactPrice) == "number" then
    return exactPrice, "гильдейское правило по ID"
  end
  local skipNamedPrice = exactPrice == false

  local itemName, itemLevel, equipSlot
  if GetItemInfo then
    local link, quality, foundItemLevel, requiredLevel, itemClass, itemSubClass, stackSize
    local foundEquipSlot
    itemName, link, quality, foundItemLevel, requiredLevel, itemClass, itemSubClass, stackSize, foundEquipSlot =
      GetItemInfo(itemId)
    itemLevel, equipSlot = foundItemLevel, foundEquipSlot
  end
  if not itemName then
    requestItemInfo(itemId)
  end
  if itemName and not skipNamedPrice then
    local normalizedName = itemName:lower()
    local namedPrice = NAMED_GUILD_PRICES[itemName] or NAMED_GUILD_PRICES[normalizedName]
    if namedPrice then
      return namedPrice, "гильдейское правило по названию"
    end
  end
  if not itemLevel then
    return nil
  end

  local ilvlRule = (pricing.ilvlRules or {})[itemLevel]
  if not ilvlRule then
    return nil
  end
  local isTwoHand = equipSlot == "INVTYPE_2HWEAPON" or
    equipSlot == "INVTYPE_POLEARM" or
    equipSlot == "INVTYPE_STAFF" or
    equipSlot == "INVTYPE_RANGED" or
    equipSlot == "INVTYPE_RANGEDRIGHT"
  local price = isTwoHand and ilvlRule.twoHand or ilvlRule.default
  if type(price) == "number" then
    return price, ("гильдейское правило ilvl %d"):format(itemLevel)
  end
  return nil
end

getStandardGP = function(itemId, eventTimestamp)
  local guildPrice, guildSource
  if not eventTimestamp or eventTimestamp >= getGuildPriceEffectiveTimestamp() then
    guildPrice, guildSource = getGuildGP(itemId)
  end
  if guildPrice ~= nil then
    return guildPrice, guildSource
  end
  local itemMedian = medianGPByItem[itemId]
  if itemMedian then
    return itemMedian, "медиана GP этого предмета за период"
  end
  if cachedItems[itemId] ~= nil then
    if cachedItems[itemId] == false then
      return nil
    end
    return cachedItems[itemId], "LibGearPoints"
  end
  local library = LibStub and LibStub("LibGearPoints-1.0", true)
  if not library or not library.GetValue then
    cachedItems[itemId] = false
    return nil
  end
  local highPrice = library:GetValue(itemId)
  if type(highPrice) == "number" and highPrice > 0 then
    cachedItems[itemId] = highPrice
    return highPrice, "LibGearPoints"
  end
  cachedItems[itemId] = false
  return nil
end

inferLootCategory = function(actualGP, mainGP)
  if not mainGP or mainGP <= 0 or actualGP < 0 then
    return nil
  end
  local pricing = db.profile.guildPricing
  local multipliers = pricing.categoryMultipliers or {}
  local names = pricing.categoryNames or {}
  local categories = {
    { key = "main", label = names.main or "Main", multiplier = multipliers.main or 1 },
    { key = "minor", label = names.minor or "Minor", multiplier = multipliers.minor or 0.5 },
    { key = "offTwin", label = names.offTwin or "Off Twin", multiplier = multipliers.offTwin or 0.25 },
    { key = "roll", label = names.roll or "Roll / Trans", multiplier = multipliers.roll or 0 },
  }
  local ratio = actualGP / mainGP
  local closest, closestDistance
  for _, category in ipairs(categories) do
    local distance = math.abs(ratio - category.multiplier)
    if not closestDistance or distance < closestDistance then
      closest, closestDistance = category, distance
    end
  end
  if closestDistance > 0.12 then
    return nil
  end
  return closest, ratio
end

getGuildPriceAnomaly = function(actualGP, guildPrice)
  if not guildPrice or guildPrice <= 0 or actualGP <= 0 or actualGP >= guildPrice then
    return 0
  end
  local pricing = db.profile.guildPricing
  local multipliers = pricing.categoryMultipliers or {}
  local names = pricing.categoryNames or {}
  local mainMultiplier = multipliers.main or 1
  local categories = {
    { key = "main", multiplier = mainMultiplier },
    { key = "minor", multiplier = multipliers.minor or 0.5 },
    { key = "offTwin", multiplier = multipliers.offTwin or 0.25 },
    { key = "roll", multiplier = multipliers.roll or 0 },
  }
  local closest, closestDistance
  for _, category in ipairs(categories) do
    if category.multiplier >= 0 and category.multiplier <= mainMultiplier then
      local expectedGP = guildPrice * category.multiplier
      local distance = math.abs(actualGP - expectedGP)
      if not closestDistance or distance < closestDistance then
        closest = {
          key = category.key,
          expectedGP = expectedGP,
        }
        closestDistance = distance
      end
    end
  end
  if closest and closest.key ~= "main" and actualGP > closest.expectedGP then
    return actualGP - closest.expectedGP, names[closest.key] or closest.key
  end
  return 0
end

function buildEfficiencyRows()
  local acquisitions = {}
  rebuildItemGPMedians()

  for _, event in ipairs(history) do
    if event.kind == "GP" and event.itemId and event.player ~= "GUILD_BANK" and
      eventInSelectedPeriod(event) then
      local player = addon:GetGroupedName(event.player)
      local key = player .. "\031" .. tostring(event.itemId)
      local stack = acquisitions[key]
      if not stack then
        stack = {}
        acquisitions[key] = stack
      end

      if event.amount > 0 then
        local standardGP, standardSource = getStandardGP(event.itemId, event.timestamp)
        local itemMedian = medianGPByItem[event.itemId]
        local referenceGP = standardGP or event.amount
        local referenceSource = standardSource or "начисленная GP"
        table.insert(stack, {
          player = player,
          character = event.player,
          itemId = event.itemId,
          timestamp = event.timestamp,
          amount = event.amount,
          chargedGP = event.amount,
          medianGP = itemMedian,
          standardGP = standardGP,
          referenceSource = referenceSource,
          base = referenceGP,
          isMainReference = standardGP ~= nil,
          active = true,
        })
      elseif event.amount < 0 then
        local remaining = -event.amount
        for i = #stack, 1, -1 do
          local acquisition = stack[i]
          if acquisition.active then
            local reduction = math.min(acquisition.amount, remaining)
            acquisition.amount = acquisition.amount - reduction
            remaining = remaining - reduction
            if acquisition.amount <= 0 then
              acquisition.active = false
            end
            if remaining <= 0 then
              break
            end
          end
        end
      end
    end
  end

  local byPlayer = {}
  for _, stack in pairs(acquisitions) do
    for _, acquisition in ipairs(stack) do
      if acquisition.active then
        local row = byPlayer[acquisition.player]
        if not row then
          row = {
            player = acquisition.player,
            items = 0,
            actualGP = 0,
            baseGP = 0,
            estimatedItems = 0,
            itemDetails = {},
          }
          byPlayer[acquisition.player] = row
        end
        row.items = row.items + 1
        row.actualGP = row.actualGP + acquisition.amount
        row.baseGP = row.baseGP + acquisition.base
        if not acquisition.standardGP then
          row.estimatedItems = row.estimatedItems + 1
        end
        local itemName = GetItemInfo and GetItemInfo(acquisition.itemId)
        table.insert(row.itemDetails, {
          itemId = acquisition.itemId,
          name = itemName or ("Предмет " .. acquisition.itemId),
          player = acquisition.character,
          timestamp = acquisition.timestamp,
          amount = acquisition.amount,
          chargedGP = acquisition.chargedGP,
          medianGP = acquisition.medianGP,
          standardGP = acquisition.standardGP,
          referenceGP = acquisition.base,
          referenceSource = acquisition.referenceSource,
          isMainReference = acquisition.isMainReference,
        })
      end
    end
  end

  local rows = {}
  for _, row in pairs(byPlayer) do
    table.sort(row.itemDetails, function(a, b)
      if a.timestamp == b.timestamp then
        return a.itemId < b.itemId
      end
      return a.timestamp < b.timestamp
    end)
    if row.baseGP > 0 then
      row.efficiency = row.actualGP / row.baseGP * 100
    else
      row.efficiency = 100
    end
    table.insert(rows, row)
  end
  return rows
end

function showEfficiencyItemsTooltip(button)
  local row = button.row
  local data = row and row.data
  if not data or not data.itemDetails then
    return
  end
  GameTooltip:SetOwner(button, "ANCHOR_CURSOR")
  local classColor = playerClassColor(data.player)
  GameTooltip:AddLine(data.player .. " — предметы за выбранный период",
    classColor.r, classColor.g, classColor.b)
  local function getItemTooltipLines(item)
    local itemPlayer = item.player or data.player
    local itemPlayerColor = playerClassColor(itemPlayer)
    local itemPlayerHex = ("|cff%02x%02x%02x"):format(
      math.floor(itemPlayerColor.r * 255),
      math.floor(itemPlayerColor.g * 255),
      math.floor(itemPlayerColor.b * 255))
    local itemLine = getTooltipItemLabel(item.itemId, item.name) ..
      (" |cffffa640+%.0f GP|r"):format(item.chargedGP)
    local detailsLine = ("%s%s|r - %s"):format(
      itemPlayerHex, itemPlayer, date("%d.%m.%Y", item.timestamp))
    local guildPrice = getGuildGP(item.itemId)
    local priceLine = guildPrice and ("Цена гильдии: %.0f GP"):format(guildPrice) or
      "Цена гильдии: не задана"
    local historicalPrice = item.timestamp < getGuildPriceEffectiveTimestamp()
    local warningLine = historicalPrice and
      ("Цена на дату выдачи неизвестна; текущие правила действуют с %s."):format(
        db.profile.guildPricing.priceEffectiveDate or DEFAULT_GUILD_PRICE_EFFECTIVE_DATE) or ""
    local estimateText
    if guildPrice and guildPrice > 0 then
      local category, ratio = inferLootCategory(item.chargedGP, guildPrice)
      if category then
        estimateText = ("Предположение по текущей цене: %s (%.0f%% от Main)"):format(
          category.label, ratio * 100)
      elseif historicalPrice then
        estimateText = "Предположение по текущей цене неоднозначно"
      else
        estimateText = "Предположение о категории неоднозначно"
      end
    else
      estimateText = "Нет цены Main для предположения о категории"
    end
    return itemLine, detailsLine, priceLine, warningLine, estimateText
  end

  local maxTooltipItems = 24
  local shownItemCount = math.min(#data.itemDetails, maxTooltipItems)
  for index = 1, shownItemCount, 2 do
    local leftItem, rightItem = data.itemDetails[index], data.itemDetails[index + 1]
    local leftItemLine, leftDetailsLine, leftPriceLine, leftWarningLine, leftEstimateLine =
      getItemTooltipLines(leftItem)
    local rightItemLine, rightDetailsLine, rightPriceLine, rightWarningLine, rightEstimateLine =
      "", "", "", "", ""
    if rightItem then
      rightItemLine, rightDetailsLine, rightPriceLine, rightWarningLine, rightEstimateLine =
        getItemTooltipLines(rightItem)
    end
    GameTooltip:AddDoubleLine(leftItemLine, rightItemLine, 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(leftDetailsLine, rightDetailsLine,
      0.68, 0.72, 0.75, 0.68, 0.72, 0.75)
    GameTooltip:AddDoubleLine(leftPriceLine, rightPriceLine,
      0.68, 0.72, 0.75, 0.68, 0.72, 0.75)
    if leftWarningLine ~= "" or rightWarningLine ~= "" then
      GameTooltip:AddDoubleLine(leftWarningLine, rightWarningLine,
        1.00, 0.82, 0.42, 1.00, 0.82, 0.42)
    end
    GameTooltip:AddDoubleLine(leftEstimateLine, rightEstimateLine,
      0.90, 0.82, 0.55, 0.90, 0.82, 0.55)
  end
  if #data.itemDetails > shownItemCount then
    GameTooltip:AddLine(("Показано %d из %d предметов. Сузьте период для полного списка."):format(
      shownItemCount, #data.itemDetails), 0.68, 0.72, 0.75, true)
  end
  GameTooltip:Show()
end

function sortEfficiencyRows(rows)
  table.sort(rows, function(a, b)
    if (sortColumn == "efficiency" or sortColumn == "attendance") and
      (a[sortColumn] == nil) ~= (b[sortColumn] == nil) then
      return a[sortColumn] ~= nil
    end
    local av, bv = a[sortColumn], b[sortColumn]
    if sortColumn == "efficiency" then
      av, bv = a.efficiency, b.efficiency
    elseif sortColumn == "player" then
      av, bv = a.player:lower(), b.player:lower()
    elseif sortColumn == "alts" then
      av, bv = a.altCount, b.altCount
    elseif sortColumn == "lootShare" then
      av, bv = a.lootShare, b.lootShare
    end
    if av == bv then
      return a.player < b.player
    end
    if sortDescending then
      return av > bv
    end
    return av < bv
  end)
end

function buildAttendanceStats(days)
  local tracker = _G.EPGPAttendance
  local trackerDB = tracker and tracker.db
  local guildName = GetGuildInfo and GetGuildInfo("player")
  local guildData = trackerDB and trackerDB.realm and trackerDB.realm.tblGuilds and
    guildName and trackerDB.realm.tblGuilds[guildName]
  if type(guildData) ~= "table" or type(guildData.tblChanges) ~= "table" or
    type(tracker.IGetMassEPAward) ~= "function" or
    type(tracker.TmGetRaidDay) ~= "function" or
    type(tracker.IGetRaidDayOfWeek) ~= "function" then
    return nil, false
  end

  local profile = tracker.db.profile or {}
  local columnOptions
  for _, candidate in ipairs(profile.tblColumns or {}) do
    if type(candidate) == "table" and tonumber(candidate.iAttendanceSpanDays) == days then
      columnOptions = candidate
      break
    end
  end
  columnOptions = columnOptions or {}

  local startTime = tracker:TmGetRaidDay() - days * 24 * 60 * 60
  local events = {}
  local weightsPerDay = {}
  for changeTime, change in pairs(guildData.tblChanges) do
    changeTime = tonumber(changeTime)
    if changeTime and changeTime >= startTime and type(change) == "table" then
      local massEPAward = tracker:IGetMassEPAward(change)
      if type(massEPAward) == "number" and massEPAward > 0 then
        local dayOfWeek, raidDay = tracker:IGetRaidDayOfWeek(changeTime)
        if type(dayOfWeek) == "number" and type(raidDay) == "number" then
          local ignored = columnOptions["fIgnoreDoW" .. dayOfWeek]
          local weight = 0
          if columnOptions.fNormalizeWeightByDay then
            weightsPerDay[raidDay] = (weightsPerDay[raidDay] or 0) + 1
          end
          if not ignored then
            weight = columnOptions.fWeightByEP == false and 1 or massEPAward
          end
          events[#events + 1] = {
            change = change,
            massEPAward = massEPAward,
            raidDay = raidDay,
            weight = weight,
          }
        end
      end
    end
  end

  local numerators = {}
  local denominator = 0
  for _, event in ipairs(events) do
    local weight = event.weight
    if weight > 0 then
      if columnOptions.fNormalizeWeightByDay then
        weight = weight / weightsPerDay[event.raidDay]
      end
      denominator = denominator + weight
      local presentGroups = {}
      for player, epDelta in pairs(event.change) do
        if type(player) == "string" and type(epDelta) == "number" and
          epDelta >= event.massEPAward and
          not (tracker.FIsSpecialPlayerName and tracker:FIsSpecialPlayerName(player)) then
          local groupedName = db.profile.grouping == "toon" and player or addon:GetGroupedName(player)
          local groupKey = (groupedName:match("^([^%-]+)") or groupedName):lower()
          presentGroups[groupKey] = true
        end
      end
      for groupKey in pairs(presentGroups) do
        numerators[groupKey] = (numerators[groupKey] or 0) + weight
      end
    end
  end

  local percentages = {}
  for groupKey, numerator in pairs(numerators) do
    percentages[groupKey] = denominator > 0 and
      math.floor(numerator * 100 / denominator + 0.5) or 0
  end
  return percentages, true,
    tonumber(profile.iHighAttendancePercent) or 80,
    tonumber(profile.iMedAttendancePercent) or 50
end

function buildLootShareStats()
  local statsByPlayer = {}
  local totals = { items = 0, categories = {} }
  for _, event in ipairs(history) do
    if event.kind == "GP" and event.itemId and event.amount > 0 and
      event.player ~= "GUILD_BANK" and eventInSelectedPeriod(event) then
      local player = addon:GetGroupedName(event.player)
      local stats = statsByPlayer[player]
      if not stats then
        stats = { items = 0, categories = {} }
        statsByPlayer[player] = stats
      end
      stats.items = stats.items + 1
      totals.items = totals.items + 1
      local guildPrice = getGuildGP(event.itemId)
      local category = guildPrice and guildPrice > 0 and
        inferLootCategory(event.amount, guildPrice) or nil
      local categoryKey = category and category.key or "unknown"
      stats.categories[categoryKey] = (stats.categories[categoryKey] or 0) + 1
      totals.categories[categoryKey] = (totals.categories[categoryKey] or 0) + 1
    end
  end
  return statsByPlayer, totals
end

function showLootShareTooltip(button)
  local row = button.row
  local data = row and row.data
  if not data or not data.lootStats or not data.lootTotals then
    return
  end
  local stats, totals = data.lootStats, data.lootTotals
  GameTooltip:SetOwner(button, "ANCHOR_CURSOR")
  GameTooltip:AddLine(("Доля добычи: %d из %d предметов (%.1f%%)"):format(
    stats.items, totals.items, data.lootShare), 0.90, 0.92, 0.94)
  GameTooltip:AddLine("Категории предположены по текущим ценам гильдии:",
    0.68, 0.72, 0.75, true)
  local pricing = db.profile.guildPricing
  local multipliers = pricing.categoryMultipliers or {}
  local names = pricing.categoryNames or {}
  local categories = {
    { key = "main", label = names.main or "Main", multiplier = multipliers.main or 1 },
    { key = "minor", label = names.minor or "Minor", multiplier = multipliers.minor or 0.5 },
    { key = "offTwin", label = names.offTwin or "Off Twin", multiplier = multipliers.offTwin or 0.25 },
    { key = "roll", label = names.roll or "Roll / Trans", multiplier = multipliers.roll or 0 },
  }
  for _, category in ipairs(categories) do
    local playerCount = stats.categories[category.key] or 0
    local categoryTotal = totals.categories[category.key] or 0
    local shareOfPlayerLoot = stats.items > 0 and playerCount / stats.items * 100 or 0
    local shareOfCategory = categoryTotal > 0 and playerCount / categoryTotal * 100 or 0
    GameTooltip:AddLine(("%s (%.0f%%): %d предметов (%.1f%% его добычи); %d из %d выдач этой категории (%.1f%%)"):format(
      category.label, category.multiplier * 100, playerCount, shareOfPlayerLoot,
      playerCount, categoryTotal, shareOfCategory), 0.78, 0.84, 0.87, true)
  end
  local unknownCount = stats.categories.unknown or 0
  GameTooltip:AddLine(("Не определено: %d предметов (%.1f%% его добычи)"):format(
    unknownCount, stats.items > 0 and unknownCount / stats.items * 100 or 0),
    0.68, 0.72, 0.75, true)
  GameTooltip:Show()
end

function makeEfficiencyRow(index)
  local row = CreateFrame("Frame", nil, efficiencyContent)
  row:SetHeight(24)
  row.background = makeFlatTexture(row, "BACKGROUND", 0.12, 0.15, 0.18, 0.55)
  row.background:SetAllPoints(row)
  row.player = makeText(row, "", "GameFontNormalSmall")
  row.altCount = makeText(row, "", "GameFontNormalSmall")
  row.items = makeText(row, "", "GameFontNormalSmall")
  row.actual = makeText(row, "", "GameFontNormalSmall")
  row.base = makeText(row, "", "GameFontNormalSmall")
  row.efficiency = makeText(row, "", "GameFontNormalSmall")
  row.lootShare = makeText(row, "", "GameFontNormalSmall")
  row.attendance = makeText(row, "", "GameFontNormalSmall")
  row.player:SetPoint("LEFT", row, "LEFT", 10, 0)
  row.player:SetWidth(250)
  row.altCount:SetPoint("LEFT", row, "LEFT", 270, 0)
  row.altCount:SetWidth(60)
  row.altCount:SetJustifyH("CENTER")
  row.items:SetPoint("LEFT", row, "LEFT", 350, 0)
  row.itemsHitbox = CreateFrame("Frame", nil, row)
  row.itemsHitbox:SetSize(90, 24)
  row.itemsHitbox:SetPoint("LEFT", row, "LEFT", 345, 0)
  row.itemsHitbox:EnableMouse(true)
  row.itemsHitbox:SetScript("OnEnter", showEfficiencyItemsTooltip)
  row.itemsHitbox:SetScript("OnLeave", GameTooltip_Hide)
  row.actual:SetPoint("LEFT", row, "LEFT", 445, 0)
  row.base:SetPoint("LEFT", row, "LEFT", 575, 0)
  row.efficiency:SetPoint("LEFT", row, "LEFT", 730, 0)
  row.lootShare:SetPoint("LEFT", row, "LEFT", 900, 0)
  row.attendance:SetPoint("LEFT", row, "LEFT", 1045, 0)
  row.attendance:SetWidth(55)
  row.attendance:SetJustifyH("CENTER")
  row.lootShareHitbox = CreateFrame("Frame", nil, row)
  row.lootShareHitbox:SetSize(130, 24)
  row.lootShareHitbox:SetPoint("LEFT", row, "LEFT", 895, 0)
  row.lootShareHitbox:EnableMouse(true)
  row.lootShareHitbox:SetScript("OnEnter", showLootShareTooltip)
  row.lootShareHitbox:SetScript("OnLeave", GameTooltip_Hide)
  if index % 2 == 0 then
    row.background:SetVertexColor(0.16, 0.19, 0.22, 0.55)
  end
  return row
end

renderEfficiency = function()
  if not efficiencyPanel or not efficiencyPanel:IsShown() then
    return
  end
  efficiencyData = buildEfficiencyRows()
  local attendanceDays = tonumber(db.profile.attendancePeriodDays) or 7
  local attendanceByPlayer, attendanceAvailable, attendanceHigh, attendanceMed =
    buildAttendanceStats(attendanceDays)
  if attendanceSourceText then
    if not attendanceAvailable then
      attendanceSourceText:SetText("Нет данных EPGP Attendance")
      attendanceSourceText:SetTextColor(1.00, 0.78, 0.42)
    else
      attendanceSourceText:SetText("")
    end
  end
  for _, button in ipairs(attendancePeriodButtons or {}) do
    button.isActive = button.periodDays == attendanceDays
    if button.isActive then
      button.activeColor = { 0.20, 0.38, 0.42 }
      button.background:SetVertexColor(0.20, 0.38, 0.42, 0.55)
    else
      button.background:SetVertexColor(0.12, 0.15, 0.18, 1)
    end
  end
  for column, button in pairs(efficiencyHeaderButtons or {}) do
    button.isActive = column == sortColumn
    button.activeColor = button.isActive and { 0.20, 0.38, 0.42 } or nil
    if button.isActive then
      button.background:SetVertexColor(0.20, 0.38, 0.42, 0.55)
    else
      button.background:SetVertexColor(0.12, 0.15, 0.18, 1)
    end
  end
  local lootStatsByPlayer, lootTotals = buildLootShareStats()
  local altCountsByMain = {}
  if type(getGuildCharacterGroups) == "function" then
    for _, group in ipairs(getGuildCharacterGroups()) do
      altCountsByMain[group.main:lower()] = group.altCount
    end
  end
  for _, rowData in ipairs(efficiencyData) do
    local lootStats = lootStatsByPlayer[rowData.player] or { items = 0, categories = {} }
    rowData.lootStats = lootStats
    rowData.lootTotals = lootTotals
    rowData.lootShare = lootTotals.items > 0 and
      lootStats.items / lootTotals.items * 100 or 0
    local mainName = addon:GetGuildMainName(rowData.player)
    rowData.altCount = altCountsByMain[mainName:lower()] or 0
    if attendanceAvailable then
      local attendanceName = db.profile.grouping == "toon" and rowData.player or
        addon:GetGroupedName(rowData.player)
      local attendanceKey = (attendanceName:match("^([^%-]+)") or attendanceName):lower()
      rowData.attendance = attendanceByPlayer[attendanceKey] or 0
    else
      rowData.attendance = nil
    end
  end
  sortEfficiencyRows(efficiencyData)

  for i, rowData in ipairs(efficiencyData) do
    if not efficiencyRows[i] then
      efficiencyRows[i] = makeEfficiencyRow(i)
    end
    local row = efficiencyRows[i]
    row:SetPoint("TOPLEFT", efficiencyContent, "TOPLEFT", 0, -(i - 1) * 24)
    row:SetPoint("TOPRIGHT", efficiencyContent, "TOPRIGHT", 0, -(i - 1) * 24)
    row.player:SetText(rowData.player)
    local classColor = playerClassColor(rowData.player)
    row.player:SetTextColor(classColor.r, classColor.g, classColor.b)
    row.altCount:SetText(tostring(rowData.altCount))
    row.items:SetText(tostring(rowData.items))
    row.data = rowData
    row.itemsHitbox.row = row
    row.lootShare:SetText(("%.1f%%"):format(rowData.lootShare))
    row.lootShareHitbox.row = row
    row.attendance:SetText(rowData.attendance and (tostring(rowData.attendance) .. "%") or "—")
    if rowData.attendance then
      row.attendance:SetTextColor(rowData.attendance >= attendanceHigh and 0.55 or
        rowData.attendance >= attendanceMed and 0.92 or 1.00,
        rowData.attendance >= attendanceHigh and 0.90 or rowData.attendance >= attendanceMed and 0.82 or 0.68,
        rowData.attendance >= attendanceHigh and 0.62 or rowData.attendance >= attendanceMed and 0.42 or 0.38)
    else
      row.attendance:SetTextColor(0.68, 0.73, 0.76)
    end
    row.actual:SetText(("%.0f"):format(rowData.actualGP))
    row.base:SetText(rowData.estimatedItems > 0 and
      (("%.0f"):format(rowData.baseGP) .. (" (%d оценка)"):format(rowData.estimatedItems)) or
      ("%.0f"):format(rowData.baseGP))
    row.efficiency:SetText(("%.1f%%"):format(rowData.efficiency))
    row.efficiency:SetTextColor(0.70, 0.90, 0.72)
    row:Show()
  end
  for i = #efficiencyData + 1, #efficiencyRows do
    efficiencyRows[i]:Hide()
  end

  efficiencyContent:SetHeight(math.max(#efficiencyData * 24, 1))
  if #efficiencyData == 0 then
    setStatus("В выбранном периоде нет положительных GP-событий с распознаваемой ссылкой на предмет.")
  elseif #history > 0 then
    setStatus(historyStatus)
  end
end

updateItemDropdown = function()
  if not itemDropdown then
    return
  end

  local itemIds = {}
  local seenItems = {}
  for _, event in ipairs(history) do
    if event.kind == "GP" and event.itemId and event.amount > 0 and
      event.player ~= "GUILD_BANK" and not seenItems[event.itemId] then
      seenItems[event.itemId] = true
      table.insert(itemIds, event.itemId)
    end
  end

  local itemEntries = {}
  for _, itemId in ipairs(itemIds) do
    local itemName = GetItemInfo and GetItemInfo(itemId)
    if not itemName and itemDropdownMenu and itemDropdownMenu:IsShown() then
      requestItemInfo(itemId)
    end
    table.insert(itemEntries, {
      itemId = itemId,
      name = itemName or ("Предмет " .. itemId),
    })
  end
  table.sort(itemEntries, function(a, b)
    if a.name:lower() == b.name:lower() then
      return a.itemId < b.itemId
    end
    return a.name:lower() < b.name:lower()
  end)

  if selectedItemId and not seenItems[selectedItemId] then
    selectedItemId = nil
  end
  local selectedName = selectedItemId and
    (GetItemInfo and GetItemInfo(selectedItemId)) or nil
  itemDropdown.label:SetText(selectedName or
    (selectedItemId and ("Предмет " .. selectedItemId) or "Выбрать предмет"))

  local query = itemSearch and itemSearch:GetText():lower() or ""
  local filtered = {}
  for _, entry in ipairs(itemEntries) do
    if query == "" or entry.name:lower():find(query, 1, true) or
      tostring(entry.itemId):find(query, 1, true) then
      table.insert(filtered, entry)
    end
  end

  itemDropdownContent:SetHeight(math.max(#filtered * 24, 1))
  itemDropdownMenu:SetHeight(math.max(80, math.min(#filtered * 24 + 40, 244)))
  itemDropdownScroll:SetVerticalScroll(0)
  for index, entry in ipairs(filtered) do
    if not itemDropdownRows[index] then
      itemDropdownRows[index] = makeButton(itemDropdownContent, "", 220, 24, function(self)
        selectedItemId = self.itemId
        itemSortColumn = "timestamp"
        itemSortDescending = true
        bossLoot.mode = false
        itemDropdownMenu:Hide()
        itemSearch:ClearFocus()
        bossLoot.updateControls()
        updateItemDropdown()
        renderItemAnalysis()
      end)
      itemDropdownRows[index]:SetPoint("TOPLEFT", itemDropdownContent, "TOPLEFT", 0, -(index - 1) * 24)
      itemDropdownRows[index]:SetPoint("TOPRIGHT", itemDropdownContent, "TOPRIGHT", 0, -(index - 1) * 24)
    end
    local row = itemDropdownRows[index]
    row.itemId = entry.itemId
    row.label:SetText(entry.name)
    row.label:SetTextColor(0.88, 0.91, 0.94)
    row.background:SetVertexColor(entry.itemId == selectedItemId and
      0.20 or 0.12, entry.itemId == selectedItemId and 0.30 or 0.15,
      entry.itemId == selectedItemId and 0.35 or 0.18, 1)
    row:Show()
  end
  for index = #filtered + 1, #itemDropdownRows do
    itemDropdownRows[index]:Hide()
  end
  if itemSearchHint then
    if query == "" and not itemSearch:HasFocus() then
      itemSearchHint:Show()
    else
      itemSearchHint:Hide()
    end
  end
  updateLootControlHighlights()
end

function toggleItemDropdown()
  if itemDropdownMenu:IsShown() then
    itemDropdownMenu:Hide()
    itemSearch:ClearFocus()
  else
    for _, dropdown in ipairs(bossLoot.dropdowns) do
      dropdown.menu:Hide()
    end
    itemSearch:SetText("")
    itemSearch:Show()
    itemDropdownMenu:Show()
    updateItemDropdown()
  end
end

function truncateTextToWidth(fontString, text, maxWidth)
  local visibleText = text
  fontString:SetText(visibleText)
  while visibleText ~= "" and fontString:GetStringWidth() > maxWidth do
    local index = #visibleText
    while index > 0 do
      local byte = visibleText:byte(index)
      if byte < 128 or byte >= 192 then
        break
      end
      index = index - 1
    end
    visibleText = visibleText:sub(1, math.max(index - 1, 0))
    fontString:SetText(visibleText .. "...")
  end
end

function getItemEventReason(event)
  local reason = normalizeReason(event.reason):gsub("item:%d+", "")
  return reason:gsub("^%s*[:%-]?%s*", ""):gsub("%s+$", "")
end

function itemPriceDeviationPercent(amount, guildPrice)
  if not guildPrice or guildPrice <= 0 then
    return nil
  end
  return amount / guildPrice * 100
end

function itemPriceChangePercent(amount, guildPrice)
  local deviation = itemPriceDeviationPercent(amount, guildPrice)
  if deviation == nil then
    return nil
  end
  return deviation - 100
end

function formatItemPriceDeviation(amount, guildPrice)
  local deviation = itemPriceDeviationPercent(amount, guildPrice)
  if deviation == nil then
    return "—"
  end
  return ("%.2f%%"):format(deviation)
end

function inferClosestLootCategory(actualGP, mainGP)
  if not mainGP or mainGP <= 0 or actualGP < 0 then
    return nil
  end
  local pricing = db.profile.guildPricing
  local multipliers = pricing.categoryMultipliers or {}
  local names = pricing.categoryNames or {}
  local categories = {
    { key = "main", label = names.main or "Main", multiplier = multipliers.main or 1 },
    { key = "minor", label = names.minor or "Minor", multiplier = multipliers.minor or 0.5 },
    { key = "offTwin", label = names.offTwin or "Off Twin", multiplier = multipliers.offTwin or 0.25 },
    { key = "roll", label = names.roll or "Roll / Trans", multiplier = multipliers.roll or 0 },
  }
  local ratio = actualGP / mainGP
  local closest, closestDistance
  for _, category in ipairs(categories) do
    local distance = math.abs(ratio - category.multiplier)
    if not closestDistance or distance < closestDistance then
      closest, closestDistance = category, distance
    end
  end
  return closest, ratio
end

function showItemReasonTooltip(button)
  local event = button.event
  if not event then
    return
  end
  local guildPrice = button.guildPrice
  local reason = getItemEventReason(event)
  GameTooltip:SetOwner(button, "ANCHOR_CURSOR")
  GameTooltip:AddLine("Детали выдачи", 0.90, 0.92, 0.94)
  GameTooltip:AddLine(date("%d.%m.%Y %H:%M", event.timestamp), 0.72, 0.78, 0.81)
  local player = addon:GetGroupedName(event.player)
  local classColor = playerClassColor(player)
  GameTooltip:AddLine(("Игрок: %s"):format(player), classColor.r, classColor.g, classColor.b)
  GameTooltip:AddLine(("Начислено: %.0f GP"):format(event.amount), COLORS.GP[1], COLORS.GP[2], COLORS.GP[3])
  if guildPrice then
    GameTooltip:AddLine(("Текущая цена гильдии: %.0f GP"):format(guildPrice), 0.78, 0.84, 0.87)
  else
    GameTooltip:AddLine("Цена гильдии: не задана", 0.78, 0.84, 0.87)
  end
  local category, ratio = inferClosestLootCategory(event.amount, guildPrice)
  if category then
    GameTooltip:AddLine(("Предположение по GP: %s (%.2f%% от Main; ближайший ориентир %.0f%%)"):format(
      category.label, ratio * 100, category.multiplier * 100),
      0.90, 0.82, 0.55)
    if event.timestamp < getGuildPriceEffectiveTimestamp() then
      GameTooltip:AddLine("Категория сопоставлена с текущей ценой; прежний прайс мог отличаться.",
        1.00, 0.82, 0.42, true)
    end
  elseif not guildPrice then
    GameTooltip:AddLine("Категория не определена: нет цены Main для сравнения.",
      0.68, 0.72, 0.75, true)
  end
  if event.timestamp < getGuildPriceEffectiveTimestamp() then
    GameTooltip:AddLine(("Предмет выдан до изменения цен (%s)."):format(
      db.profile.guildPricing.priceEffectiveDate or DEFAULT_GUILD_PRICE_EFFECTIVE_DATE),
      1.00, 0.82, 0.42, true)
    local changePercent = guildPrice and itemPriceChangePercent(event.amount, guildPrice)
    if changePercent and changePercent ~= 0 then
      GameTooltip:AddLine(("Возможная прежняя цена: %+.2f%% к текущей цене (%+.0f GP)."):format(
        changePercent, event.amount - guildPrice), 1.00, 0.82, 0.42, true)
    else
      GameTooltip:AddLine("Сравнение с текущей ценой для этого события не подтверждает историческую цену.",
        1.00, 0.82, 0.42, true)
    end
  else
    local changePercent = guildPrice and itemPriceChangePercent(event.amount, guildPrice)
    if changePercent then
      GameTooltip:AddLine(("Отклонение от текущей цены: %+.2f%%."):format(changePercent),
        0.78, 0.84, 0.87)
    end
  end
  GameTooltip:AddLine(("Офицер: %s"):format(event.officer ~= "Unknown" and event.officer or "—"),
    0.78, 0.84, 0.87)
  if reason ~= "" then
    GameTooltip:AddLine(("Причина: %s"):format(reason), 0.90, 0.90, 0.90, true)
  else
    GameTooltip:AddLine("Причина не указана.", 0.68, 0.72, 0.75, true)
  end
  GameTooltip:Show()
end

function makeItemListingRow(index)
  local row = CreateFrame("Frame", nil, itemListingContent)
  row:SetHeight(24)
  row.background = makeFlatTexture(row, "BACKGROUND", 0.12, 0.15, 0.18, 0.55)
  row.background:SetAllPoints(row)
  row.date = makeText(row, "", "GameFontNormalSmall")
  row.player = makeText(row, "", "GameFontNormalSmall")
  row.role = makeText(row, "", "GameFontNormalSmall")
  row.amount = makeText(row, "", "GameFontNormalSmall")
  row.guildPrice = makeText(row, "", "GameFontNormalSmall")
  row.discount = makeText(row, "", "GameFontNormalSmall")
  row.officer = makeText(row, "", "GameFontNormalSmall")
  row.category = makeText(row, "", "GameFontNormalSmall")
  row.reason = makeText(row, "", "GameFontNormalSmall")
  row.date:SetPoint("LEFT", row, "LEFT", 10, 0)
  row.player:SetPoint("LEFT", row, "LEFT", 115, 0)
  row.player:SetJustifyH("LEFT")
  row.role:SetPoint("LEFT", row, "LEFT", 235, 0)
  row.amount:SetPoint("LEFT", row, "LEFT", 310, 0)
  row.guildPrice:SetPoint("LEFT", row, "LEFT", 385, 0)
  row.discount:SetPoint("LEFT", row, "LEFT", 470, 0)
  row.officer:SetPoint("LEFT", row, "LEFT", 555, 0)
  row.category:SetPoint("LEFT", row, "LEFT", 645, 0)
  row.reason:SetPoint("LEFT", row, "LEFT", 750, 0)
  row.date:SetWidth(100)
  row.player:SetWidth(115)
  row.role:SetWidth(70)
  row.amount:SetWidth(70)
  row.guildPrice:SetWidth(80)
  row.discount:SetWidth(80)
  row.officer:SetWidth(85)
  row.category:SetWidth(95)
  row.reason:SetWidth(270)
  row.reason:SetWordWrap(false)
  row.reason:SetFontObject(GameFontNormalSmall)
  row.date:SetWordWrap(false)
  row.player:SetWordWrap(false)
  row.amount:SetWordWrap(false)
  row.guildPrice:SetWordWrap(false)
  row.discount:SetWordWrap(false)
  row.officer:SetWordWrap(false)
  row.category:SetWordWrap(false)
  row.role:SetWordWrap(false)
  row.reason:SetWordWrap(false)
  row.playerHitbox = CreateFrame("Button", nil, row)
  row.playerHitbox:SetSize(115, 24)
  row.playerHitbox:SetPoint("LEFT", row, "LEFT", 115, 0)
  row.playerHitbox:EnableMouse(true)
  row.playerHitbox:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row.playerHitbox:SetScript("OnEnter", function(self)
    if self.characterName then
      local classColor = playerClassColor(self.characterName)
      self:GetParent().player:SetTextColor(classColor.r, classColor.g, classColor.b)
    end
  end)
  row.playerHitbox:SetScript("OnLeave", function(self)
    GameTooltip_Hide()
    if self.characterName then
      local classColor = playerClassColor(self.characterName)
      self:GetParent().player:SetTextColor(classColor.r, classColor.g, classColor.b)
    end
  end)
  row.playerHitbox:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
      if self.characterName then
        addon.ShowArmoryContextMenu(self.characterName)
      end
      return
    end
    if button ~= "LeftButton" then
      return
    end
    if not self.playerName then
      return
    end
    selectedPlayers = {}
    selectedPlayers[self.playerName] = true
    selectedPlayer = self.playerName
    db.profile.timelinePlayers = selectedPlayers
    db.profile.lastSelectedPlayer = self.playerName
    rankSnapshotsDirty = true
    selectedItemId = nil
    itemSortColumn = "timestamp"
    itemSortDescending = true
    bossLoot.mode = false
    bossLoot.view = "loot"
    updatePlayerDropdown()
    if bossLoot and bossLoot.updateControls then
      bossLoot.updateControls()
    end
    updateItemDropdown()
    renderItemAnalysis()
  end)
  row.reasonHitbox = CreateFrame("Button", nil, row)
  row.reasonHitbox:SetSize(270, 24)
  row.reasonHitbox:SetPoint("LEFT", row, "LEFT", 750, 0)
  row.reasonHitbox:EnableMouse(true)
  row.reasonHitbox:RegisterForClicks("LeftButtonUp")
  row.reasonHitbox:SetScript("OnEnter", showItemReasonTooltip)
  row.reasonHitbox:SetScript("OnLeave", GameTooltip_Hide)
  row.reasonHitbox:SetScript("OnClick", function(self)
    if not self.itemId then
      return
    end
    selectedItemId = self.itemId
    itemSortColumn = "timestamp"
    itemSortDescending = true
    bossLoot.mode = false
    bossLoot.view = "loot"
    bossLoot.updateControls()
    updateItemDropdown()
    renderItemAnalysis()
  end)
  row.deviationHitbox = CreateFrame("Frame", nil, row)
  row.deviationHitbox:SetSize(80, 24)
  row.deviationHitbox:SetPoint("LEFT", row, "LEFT", 470, 0)
  row.deviationHitbox:EnableMouse(true)
  row.deviationHitbox:SetScript("OnEnter", showItemReasonTooltip)
  row.deviationHitbox:SetScript("OnLeave", GameTooltip_Hide)
  if index % 2 == 0 then
    row.background:SetVertexColor(0.16, 0.19, 0.22, 0.55)
  end
  return row
end

function lootEventMatchesSelectedPlayer(event, selectedNames)
  if not event or not event.player or #selectedNames == 0 then
    return #selectedNames == 0
  end
  local function groupKey(name)
    if type(name) ~= "string" or name == "" then
      return nil
    end
    local mainName = addon:GetGuildMainName(name)
    local shortName = (mainName ~= "" and mainName or name):match("^([^%-]+)") or name
    return shortName:lower()
  end
  local eventGroup = groupKey(event.player)
  for _, selectedName in ipairs(selectedNames) do
    if eventGroup and eventGroup == groupKey(selectedName) then
      return true
    end
  end
  return false
end

function lootEventMatchesCurrentSelection(event, selectedNames)
  if #selectedNames == 0 then
    return true
  end
  return lootEventMatchesSelectedPlayer(event, selectedNames)
end

function getLootCharacterRole(name)
  local characterName = name:match("^([^%-]+)") or name
  local mainName = addon:GetGuildMainName(name)
  return characterName:lower() == mainName:lower() and "основа" or "твинк"
end

renderItemAnalysis = function()
  if not itemPanel or not itemPanel:IsShown() then
    return
  end
  updateItemDropdown()
  for _, button in ipairs(bossLoot.headerButtons or {}) do
    if button.itemHeaderKey == "reason" then
      button.label:SetText(selectedItemId and button.itemHeaderText or "Предмет")
    end
  end

  if bossLoot.mode then
    bossLoot.render()
    return
  end

  for _, row in ipairs(bossLoot.rows) do
    row:Hide()
  end
  for _, row in ipairs(bossLoot.competitorRows or {}) do
    row:Hide()
  end
  if bossLoot.sectionLabel then
    bossLoot.sectionLabel:Hide()
  end
  if bossLoot.competitorItemHeader then
    bossLoot.competitorItemHeader:Hide()
    bossLoot.competitorCandidatesHeader:Hide()
  end
  if bossLoot.competitorStatus then
    bossLoot.competitorStatus:Hide()
  end

  rebuildItemGPMedians()
  local itemName
  if selectedItemId then
    itemName = (GetItemInfo and GetItemInfo(selectedItemId)) or
      ("Предмет " .. selectedItemId)
  end
  local guildPrice = selectedItemId and getGuildGP(selectedItemId) or nil
  local itemMedian = selectedItemId and medianGPByItem[selectedItemId] or nil
  local acquisitions = {}
  local selectedNames = visiblePlayerNames()
  if selectedItemId then
    for _, event in ipairs(history) do
      if event.kind == "GP" and event.itemId == selectedItemId and
        event.player ~= "GUILD_BANK" and eventInSelectedPeriod(event) then
        table.insert(acquisitions, {
          event = event,
          player = event.player,
          groupedPlayer = addon:GetGroupedName(event.player),
          role = getLootCharacterRole(event.player),
          itemName = itemName,
          amount = event.amount,
          guildPrice = guildPrice,
          difference = itemPriceDeviationPercent(event.amount, guildPrice),
          officer = event.officer ~= "Unknown" and event.officer or "",
          reason = getItemEventReason(event),
          category = (inferClosestLootCategory(event.amount, guildPrice) or {}).label or "",
        })
      end
    end
  else
    for _, event in ipairs(history) do
      if event.kind == "GP" and event.itemId and event.amount > 0 and
        event.player ~= "GUILD_BANK" and eventInSelectedPeriod(event) and
        lootEventMatchesCurrentSelection(event, selectedNames) then
        local groupedPlayer = addon:GetGroupedName(event.player)
        local eventItemName = (GetItemInfo and GetItemInfo(event.itemId)) or
          ("Предмет " .. event.itemId)
        local eventGuildPrice = getGuildGP(event.itemId)
        table.insert(acquisitions, {
          event = event,
          player = event.player,
          groupedPlayer = groupedPlayer,
          role = getLootCharacterRole(event.player),
          itemName = eventItemName,
          amount = event.amount,
          guildPrice = eventGuildPrice,
          difference = itemPriceDeviationPercent(event.amount, eventGuildPrice),
          officer = event.officer ~= "Unknown" and event.officer or "",
          reason = getItemEventReason(event),
          category = (inferClosestLootCategory(event.amount, eventGuildPrice) or {}).label or "",
        })
      end
    end
  end
  table.sort(acquisitions, function(a, b)
    local eventA, eventB = a.event, b.event
    local valueA, valueB
    if itemSortColumn == "timestamp" then
      valueA, valueB = eventA.timestamp, eventB.timestamp
    else
      valueA, valueB = a[itemSortColumn], b[itemSortColumn]
      if itemSortColumn == "player" or itemSortColumn == "role" or itemSortColumn == "officer" or
        itemSortColumn == "reason" or itemSortColumn == "category" then
        valueA, valueB = valueA:lower(), valueB:lower()
      end
    end
    if valueA == valueB then
      if eventA.timestamp == eventB.timestamp then
        return eventA.sequence > eventB.sequence
      end
      return eventA.timestamp > eventB.timestamp
    end
    if valueA == nil or valueB == nil then
      return valueA ~= nil
    end
    if itemSortDescending then
      return valueA > valueB
    end
    return valueA < valueB
  end)

  if selectedItemId then
    truncateTextToWidth(itemMedianText, ("%s | медиана: %s | цена гильдии: %s | выдач за период: %d"):format(
      itemName,
      itemMedian and ("%.0f GP"):format(itemMedian) or "нет данных",
      guildPrice and ("%.0f GP"):format(guildPrice) or "нет данных",
      #acquisitions), itemMedianText:GetWidth())
  else
    local selectedNames = visiblePlayerNames()
    local title
    if #selectedNames == 1 then
      title = ("Лут игрока %s"):format(selectedNames[1])
    elseif #selectedNames > 1 then
      title = ("Лут игроков: %d"):format(#selectedNames)
    else
      title = "Лут за период"
    end
    truncateTextToWidth(itemMedianText, ("%s | выдач за период: %d"):format(
      title, #acquisitions), itemMedianText:GetWidth())
  end
  for index, event in ipairs(acquisitions) do
    if not itemListingRows[index] then
      itemListingRows[index] = makeItemListingRow(index)
    end
    local row = itemListingRows[index]
    row:SetPoint("TOPLEFT", itemListingContent, "TOPLEFT", 0, -(index - 1) * 24)
    row:SetPoint("TOPRIGHT", itemListingContent, "TOPRIGHT", 0, -(index - 1) * 24)
    local acquisition = event
    event = acquisition.event
    truncateTextToWidth(row.date, date("%d.%m.%Y %H:%M", event.timestamp), row.date:GetWidth())
    local player = acquisition.player
    truncateTextToWidth(row.player, player, row.player:GetWidth())
    truncateTextToWidth(row.role, acquisition.role, row.role:GetWidth())
    row.playerHitbox.playerName = acquisition.groupedPlayer
    row.playerHitbox.characterName = event.player
    row.playerHitbox:Show()
    local classColor = playerClassColor(player)
    row.player:SetTextColor(classColor.r, classColor.g, classColor.b)
    truncateTextToWidth(row.amount, ("%.0f GP"):format(acquisition.amount), row.amount:GetWidth())
    truncateTextToWidth(row.guildPrice,
      acquisition.guildPrice and ("%.0f GP"):format(acquisition.guildPrice) or "—",
      row.guildPrice:GetWidth())
    truncateTextToWidth(row.discount,
      formatItemPriceDeviation(acquisition.amount, acquisition.guildPrice), row.discount:GetWidth())
    row.discount:SetTextColor(0.78, 0.84, 0.87)
    truncateTextToWidth(row.officer,
      event.officer ~= "Unknown" and event.officer or "—", row.officer:GetWidth())
    local reason
    if selectedItemId then
      reason = acquisition.reason ~= "" and acquisition.reason or "—"
    else
      reason = acquisition.itemName
    end
    if selectedItemId then
      row.reason:SetFontObject(GameFontDisableSmall)
      truncateTextToWidth(row.reason, reason, row.reason:GetWidth())
    else
      row.reason:SetFontObject(GameFontNormalSmall)
      row.reason:SetText(getTooltipItemLabel(event.itemId, acquisition.itemName))
    end
    truncateTextToWidth(row.category,
      acquisition.category ~= "" and acquisition.category or "—", row.category:GetWidth())
    row.reasonHitbox.event = event
    row.reasonHitbox.guildPrice = acquisition.guildPrice
    row.reasonHitbox.itemId = nil
    if not selectedItemId then
      row.reasonHitbox.itemId = event.itemId
    end
    row.deviationHitbox.event = event
    row.deviationHitbox.guildPrice = acquisition.guildPrice
    row:Show()
  end
  for index = #acquisitions + 1, #itemListingRows do
    itemListingRows[index]:Hide()
  end
  itemListingContent:SetHeight(math.max(#acquisitions * 24, 1))
end

refreshViews = function()
  readHistory()
  updatePlayerDropdown()
  updateItemDropdown()
  drawChart()
  renderEfficiency()
  renderItemAnalysis()
end
