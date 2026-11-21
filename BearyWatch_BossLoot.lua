local addon = _G.BearyWatch
if type(addon) ~= "table" or type(addon.environment) ~= "table" then
  error("BearyWatch shared environment was not initialized.")
end
setfenv(1, addon.environment)
function bossLoot.getTierOptions()
  if type(EJ_GetNumTiers) ~= "function" or type(EJ_GetTierInfo) ~= "function" then
    setStatus("API разделов книги приключений недоступен.")
    return nil
  end
  return bossLoot.withJournalState(function()
    local count = EJ_GetNumTiers()
    local options = {}
    for index = 1, tonumber(count) or 0 do
      local name = EJ_GetTierInfo(index)
      if name then
        table.insert(options, { value = index, label = tostring(name) })
      end
    end
    return options
  end)
end

function bossLoot.getInstanceOptions()
  if not bossLoot.tier or type(EJ_SelectTier) ~= "function" or
    type(EJ_GetInstanceByIndex) ~= "function" then
    setStatus("Выберите раздел книги приключений.")
    return nil
  end
  return bossLoot.withJournalState(function()
    EJ_SelectTier(bossLoot.tier)
    local options = {}
    for index = 1, 200 do
      local instanceId, name = EJ_GetInstanceByIndex(index, bossLoot.isRaid)
      if not instanceId then
        break
      end
      table.insert(options, { value = instanceId, label = tostring(name) })
    end
    return options
  end)
end

function bossLoot.getEncounterOptions()
  if not bossLoot.instanceId or type(EJ_SelectTier) ~= "function" or
    type(EJ_SelectInstance) ~= "function" or
    type(EJ_GetEncounterInfoByIndex) ~= "function" then
    setStatus("Сначала выберите рейд или подземелье.")
    return nil
  end
  return bossLoot.withJournalState(function()
    EJ_SelectTier(bossLoot.tier)
    if type(EncounterJournal) == "table" then
      EncounterJournal.instanceID = bossLoot.instanceId
    end
    EJ_SelectInstance(bossLoot.instanceId)
    local options = {}
    for index = 1, 100 do
      local name, _, encounterId = EJ_GetEncounterInfoByIndex(index, bossLoot.instanceId)
      if not name then
        break
      end
      if encounterId then
        table.insert(options, { value = encounterId, label = tostring(name) })
      end
    end
    return options
  end)
end

function bossLoot.getDifficultyOptions()
  if not bossLoot.instanceId or type(EJ_GetDifficultyInfo) ~= "function" or
    type(EJ_SelectTier) ~= "function" or type(EJ_SelectInstance) ~= "function" then
    setStatus("API сложностей книги приключений недоступен.")
    return nil
  end
  return bossLoot.withJournalState(function()
    EJ_SelectTier(bossLoot.tier)
    if type(EncounterJournal) == "table" then
      EncounterJournal.instanceID = bossLoot.instanceId
    end
    EJ_SelectInstance(bossLoot.instanceId)
    local options = {}
    for difficultyId = 1, 10 do
      local infoOk, info, raidSize = pcall(EJ_GetDifficultyInfo, difficultyId, bossLoot.isRaid)
      if infoOk and info then
        local valid = true
        if type(EJ_IsValidInstanceDifficulty) == "function" then
          local validOk, isValid = pcall(
            EJ_IsValidInstanceDifficulty, difficultyId, bossLoot.instanceId)
          valid = validOk and isValid
        end
        if valid then
          local prefix, size, value
          if type(info) == "table" then
            prefix = info.prefix or info.name or info.difficultyName
            size = info.size
            value = info.difficultyID
          else
            prefix, size = info, raidSize
          end
          local label = tostring(prefix or info)
          if bossLoot.isRaid and size and tostring(size) ~= "" then
            label = "(" .. tostring(size) .. ") " .. label
          end
          table.insert(options, {
            value = value or difficultyId,
            label = label,
          })
        end
      end
    end
    return options
  end)
end

function bossLoot.makeRow(index)
  local row = CreateFrame("Button", nil, bossLoot.content)
  row:SetHeight(26)
  row.background = makeFlatTexture(row, "BACKGROUND", 0.12, 0.15, 0.18, 0.55)
  row.background:SetAllPoints(row)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(20, 20)
  row.icon:SetPoint("LEFT", row, "LEFT", 32, 0)
  row.name = makeText(row, "", "GameFontNormalSmall")
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.name:SetWidth(650)
  row.name:SetJustifyH("LEFT")
  row.name:SetWordWrap(false)
  row.gp = makeText(row, "", "GameFontNormalSmall")
  row.gp:SetPoint("LEFT", row, "LEFT", 790, 0)
  row.gp:SetWidth(100)
  row.gp:SetJustifyH("LEFT")
  row.toggle = makeButton(row, "×", 22, 22, function()
    local itemId = row.itemIdValue
    if bossLoot.excludedItems[itemId] then
      bossLoot.excludedItems[itemId] = nil
    else
      bossLoot.excludedItems[itemId] = true
    end
    bossLoot.saveSelection()
    bossLoot.render()
  end)
  row.toggle:SetPoint("LEFT", row, "LEFT", 3, 0)
  row:RegisterForClicks("LeftButtonUp")
  row:EnableMouse(true)
  row:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    if self.itemLink then
      GameTooltip:SetHyperlink(self.itemLink)
    else
      GameTooltip:AddLine(self.itemName or "Предмет")
      GameTooltip:AddLine("ID " .. tostring(self.itemIdValue), 0.68, 0.72, 0.75)
      GameTooltip:Show()
    end
  end)
  row:SetScript("OnLeave", GameTooltip_Hide)
  row:SetScript("OnClick", function(self)
    local itemId = self.itemIdValue
    for _, event in ipairs(history) do
      if event.kind == "GP" and event.itemId == itemId and
        event.amount > 0 and event.player ~= "GUILD_BANK" then
        selectedItemId = itemId
        itemSortColumn = "timestamp"
        itemSortDescending = true
        bossLoot.mode = false
        bossLoot.updateControls()
        updateItemDropdown()
        renderItemAnalysis()
        return
      end
    end
    setStatus(("История выдач для %s не найдена."):format(self.itemName or "предмета"))
  end)
  if index % 2 == 0 then
    row.background:SetVertexColor(0.16, 0.19, 0.22, 0.55)
  end
  return row
end

function bossLoot.normalizePlayerName(name)
  if type(name) ~= "string" then
    return nil
  end
  name = name:match("^%s*(.-)%s*$")
  return (name:match("^([^%-]+)") or name):lower()
end

function bossLoot.getRaidPlayers()
  local players = {}
  if GetNumRaidMembers and GetNumRaidMembers() > 0 and GetRaidRosterInfo then
    for index = 1, GetNumRaidMembers() do
      local name = GetRaidRosterInfo(index)
      local unit = bossLoot.normalizePlayerName(name) ==
        bossLoot.normalizePlayerName(UnitName("player")) and "player" or ("raid" .. index)
      if name and UnitIsConnected and UnitIsConnected(unit) then
        local _, classToken = UnitClass(unit)
        players[#players + 1] = {
          name = name:match("^([^%-]+)") or name,
          unit = unit,
          classToken = classToken,
        }
      end
    end
  elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then
    local _, playerClassToken = UnitClass("player")
    players[#players + 1] = {
      name = UnitName("player"), unit = "player", classToken = playerClassToken,
    }
    for index = 1, GetNumPartyMembers() do
      local unit = "party" .. index
      local name = UnitName(unit)
      if name then
        local _, classToken = UnitClass(unit)
        players[#players + 1] = { name = name, unit = unit, classToken = classToken }
      end
    end
  elseif UnitName then
    local _, classToken = UnitClass("player")
    players[#players + 1] = {
      name = UnitName("player"), unit = "player", classToken = classToken,
    }
  end
  return players
end

function bossLoot.getEffectiveScope()
  local inRaid = GetNumRaidMembers and GetNumRaidMembers() > 0
  if bossLoot.competitorScope == "guild" then
    return "guild"
  end
  if bossLoot.competitorScope == "raid" then
    return "raid"
  end
  return inRaid and "raid" or "guild"
end

function bossLoot.getPlayerClassId(member)
  local classToken = member.classToken or classTokenByPlayer[member.name]
  if not classToken and EPGP and EPGP.GetClass then
    classToken = EPGP:GetClass(member.name)
  end
  return bossLoot.classIdByToken[classToken]
end

function bossLoot.getPlayerMain(playerName)
  local note = bossLoot.officerNotes[bossLoot.normalizePlayerName(playerName)]
  if note then
    note = note:match("^%s*(.-)%s*$")
    if note ~= "" and not bossLoot.isNumericOfficerNote(note) then
      local main = note:match("^([^%-]+)") or note
      return bossLoot.rosterNames[bossLoot.normalizePlayerName(main)] or main
    end
  end
  if EPGP and EPGP.GetMain then
    local main = EPGP:GetMain(playerName)
    if type(main) ~= "string" or main == "" then
      main = EPGP:GetMain(playerName:match("^([^%-]+)") or playerName)
    end
    if type(main) == "string" and main ~= "" then
      local shortMain = main:match("^([^%-]+)") or main
      return bossLoot.rosterNames[bossLoot.normalizePlayerName(shortMain)] or shortMain
    end
  end
  local shortName = playerName:match("^([^%-]+)") or playerName
  local rosterMain = guildMainByName and
    (guildMainByName[playerName:lower()] or guildMainByName[shortName:lower()])
  return rosterMain or playerName
end

function bossLoot.getCompetitors()
  if not selectedPlayer or selectedPlayer == ALL_PLAYERS or
    db.profile.grouping == "toon" or not EPGP or not EPGP.GetEPGP then
    return nil, "Выберите персонажа в режиме «Мейн», чтобы сравнить приоритеты."
  end
  local selectedMain = bossLoot.getPlayerMain(selectedPlayer)
  local playerEP, playerGP = EPGP:GetEPGP(selectedMain)
  if type(playerEP) ~= "number" or type(playerGP) ~= "number" or playerGP <= 0 then
    return nil, "Не удалось получить текущий PR выбранной основы."
  end
  local playerPR = playerEP / playerGP
  local candidates, seen = {}, {}
  local inRaid = GetNumRaidMembers and GetNumRaidMembers() > 0
  local scope = bossLoot.getEffectiveScope()
  local pool
  if scope == "raid" and inRaid then
    pool = bossLoot.getRaidPlayers()
  elseif scope == "raid" then
    return nil, "Состав рейда недоступен. Выберите состав гильдии для анализа вне рейда."
  else
    pool = bossLoot.guildMembers
    if #pool == 0 then
      return nil, "Не удалось получить ростер гильдии. Обновите список игроков гильдии."
    end
  end
  for _, member in ipairs(pool or {}) do
    local key = bossLoot.normalizePlayerName(member.name)
    if key and not seen[key] then
      seen[key] = true
      member.main = bossLoot.getPlayerMain(member.name)
      local mainKey = bossLoot.normalizePlayerName(member.main)
      member.classId = bossLoot.getPlayerClassId(member)
      local ep, gp = EPGP:GetEPGP(member.main)
      if (type(ep) ~= "number" or type(gp) ~= "number") and member.main ~= member.name then
        ep, gp = EPGP:GetEPGP(member.name)
      end
      if type(ep) == "number" and type(gp) == "number" and gp > 0 then
        member.pr = ep / gp
        member.ep = ep
        member.gp = gp
        if member.pr > playerPR and mainKey ~= bossLoot.normalizePlayerName(selectedMain) then
          member.wornItems = scope == "raid" and bossLoot.inspections[key] or nil
          candidates[#candidates + 1] = member
        end
      end
    end
  end
  table.sort(candidates, function(a, b)
    if a.pr == b.pr then
      return a.name:lower() < b.name:lower()
    end
    return a.pr > b.pr
  end)
  return candidates, nil, playerPR, scope == "raid"
end

function bossLoot.getClassLootMap()
  local cacheKey = table.concat({
    tostring(bossLoot.tier), tostring(bossLoot.instanceId),
    tostring(bossLoot.encounterId), tostring(bossLoot.difficultyId),
  }, ":")
  if bossLoot.classLootCacheKey == cacheKey and bossLoot.classLootCache then
    return bossLoot.classLootCache
  end
  if not bossLoot.encounterId or type(EJ_SetLootFilter) ~= "function" or
    type(EJ_GetNumLoot) ~= "function" or type(EJ_GetLootInfoByIndex) ~= "function" then
    return nil, "Не удалось получить списки добычи по классам из книги приключений."
  end

  local classLoot = bossLoot.withJournalState(function()
    EJ_SelectTier(bossLoot.tier)
    if type(EncounterJournal) == "table" then
      EncounterJournal.instanceID = bossLoot.instanceId
    end
    EJ_SelectInstance(bossLoot.instanceId)
    if type(EncounterJournal) == "table" then
      EncounterJournal.instanceID = bossLoot.instanceId
      EncounterJournal.encounterID = bossLoot.encounterId
    end
    if bossLoot.difficultyId and type(EJ_SetDifficulty) == "function" then
      local ok, err = pcall(EJ_SetDifficulty, bossLoot.difficultyId)
      if not ok then
        error("Не удалось применить сложность: " .. tostring(err))
      end
    end
    EJ_SelectEncounter(bossLoot.encounterId)
    local result = {}
    for _, classOption in ipairs(bossLoot.classOptions) do
      EJ_SetLootFilter(classOption.id, 0)
      local itemSet = {}
      for index = 1, tonumber(EJ_GetNumLoot()) or 0 do
        local itemId = EJ_GetLootInfoByIndex(index)
        itemId = tonumber(itemId)
        if itemId then
          itemSet[itemId] = true
        end
      end
      result[classOption.id] = itemSet
    end
    return result
  end)
  if not classLoot then
    return nil, "Не удалось загрузить добычу для всех классов."
  end
  bossLoot.classLootCacheKey = cacheKey
  bossLoot.classLootCache = classLoot
  return classLoot
end

function bossLoot.getItemDemandStats(item)
  bossLoot.itemDemandStats = bossLoot.itemDemandStats or {}
  local cached = bossLoot.itemDemandStats[item.id]
  if cached then
    return cached
  end

  local stats = {
    spellPower = false,
    strength = false,
    agility = false,
    intellect = false,
    spirit = false,
    manaRegen = false,
    spellPenetration = false,
    spellHit = false,
    spellCrit = false,
    spellHaste = false,
  }
  local cacheStats = false
  if type(GetItemStats) == "function" then
    local ok, itemStats = pcall(GetItemStats, item.link or item.id)
    if ok and type(itemStats) == "table" then
      cacheStats = true
      for key, value in pairs(itemStats) do
        if type(value) == "number" and value ~= 0 then
          local stat = tostring(key):upper()
          if stat:find("SPELL_POWER", 1, true) or stat:find("SPELL_DAMAGE", 1, true) or
            stat:find("SPELL_HEALING", 1, true) then
            stats.spellPower = true
          elseif stat:find("STRENGTH", 1, true) then
            stats.strength = true
          elseif stat:find("AGILITY", 1, true) then
            stats.agility = true
          end
          if stat:find("INTELLECT", 1, true) then
            stats.intellect = true
          elseif stat:find("SPIRIT", 1, true) then
            stats.spirit = true
          end
          if stat:find("MANA_REGENERATION", 1, true) or stat:find("MP5", 1, true) then
            stats.manaRegen = true
          end
          if stat:find("SPELL_PENETRATION", 1, true) then
            stats.spellPenetration = true
          end
          if stat:find("SPELL_HIT", 1, true) then
            stats.spellHit = true
          end
          if stat:find("SPELL_CRIT", 1, true) then
            stats.spellCrit = true
          end
          if stat:find("SPELL_HASTE", 1, true) then
            stats.spellHaste = true
          end
        end
      end
    end
  end

  if itemLoaderTooltip and item.link then
    itemLoaderTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    itemLoaderTooltip:SetHyperlink(item.link)
    local tooltipName = itemLoaderTooltip:GetName()
    local tooltipLineCount = itemLoaderTooltip:NumLines()
    if tooltipLineCount > 0 then
      cacheStats = true
    end
    for index = 1, tooltipLineCount do
      local text = _G[tooltipName .. "TextLeft" .. index]
      local line = text and text:GetText()
      if line then
        line = line:lower()
        local isSpellPowerLine = line:find("spell power", 1, true) or
          line:find("spell damage", 1, true) or
          line:find("spell healing", 1, true) or
          line:find("healing spells", 1, true) or
          line:find("сил заклинан") or
          line:find("сила заклинан") or
          line:find("силу заклинан") or
          line:find("силе заклинан") or
          line:find("силы заклинан") or
          line:find("исцеления заклинан") or
          line:find("исцелению заклинан")
        if isSpellPowerLine then
          stats.spellPower = true
        end
        if line:find("intellect", 1, true) or line:find("интеллект") then
          stats.intellect = true
        end
        if line:find("spirit", 1, true) or line:find("дух") then
          stats.spirit = true
        end
        if line:find("mana regeneration", 1, true) or
          line:find("mana every 5", 1, true) or line:find("мана раз в 5 сек") or
          line:find("маны раз в 5 сек") or line:find("восполняет ману") then
          stats.manaRegen = true
        end
        if line:find("spell penetration", 1, true) or
          line:find("проникающ") and line:find("заклинан") then
          stats.spellPenetration = true
        end
        if line:find("spell hit", 1, true) or
          line:find("меткост") and line:find("заклинан") then
          stats.spellHit = true
        end
        if line:find("spell critical", 1, true) or
          line:find("крит") and line:find("заклинан") then
          stats.spellCrit = true
        end
        if line:find("spell haste", 1, true) or
          line:find("скорост") and line:find("заклинан") then
          stats.spellHaste = true
        end
        if not isSpellPowerLine then
          if line:find("strength", 1, true) or line:find("к силе") or
            line:find("силу на") or line:find("силы", 1, true) or
            line:find("^сила%s*[%+%-:]?%s*%d") then
            stats.strength = true
          end
          if line:find("agility", 1, true) or line:find("ловк") then
            stats.agility = true
          end
        end
      end
    end
    itemLoaderTooltip:Hide()
  end

  stats.available = cacheStats
  if cacheStats then
    bossLoot.itemDemandStats[item.id] = stats
  end
  return stats
end

local mailClasses = { [1] = true, [2] = true, [3] = true, [6] = true, [7] = true }
local plateClasses = { [1] = true, [2] = true, [6] = true }
local physicalClasses = { [1] = true, [3] = true, [4] = true, [6] = true }

function bossLoot.isItemClearlyUnsuitable(item, classId)
  if db.profile.useAddonLootFilter == false then
    return false
  end

  local subClass = tostring(item.subClass or ""):lower()
  local isMail = subClass:find("mail", 1, true) or subClass:find("кольч", 1, true)
  local isPlate = subClass:find("plate", 1, true) or subClass:find("лат", 1, true)
  if isMail and not mailClasses[classId] then
    return true
  end
  if isPlate and not plateClasses[classId] then
    return true
  end

  local stats = bossLoot.getItemDemandStats(item)
  local isCasterClass = classId == 8 or classId == 9
  if stats.available and isCasterClass and not (
    stats.spellPower or stats.intellect or stats.spirit or stats.manaRegen or
    stats.spellPenetration or stats.spellHit or stats.spellCrit or stats.spellHaste
  ) then
    return true
  end
  if stats.available and (classId == 1 or classId == 2 or classId == 6) and
    not stats.strength then
    return true
  end
  if stats.spellPower then
    local hasRelevantPhysicalStat =
      (classId == 1 or classId == 6) and stats.strength or
      (classId == 3 or classId == 4) and stats.agility
    if physicalClasses[classId] and not hasRelevantPhysicalStat then
      return true
    end
  end
  return false
end

function bossLoot.makeCompetitorRow(index)
  local row = CreateFrame("Frame", nil, bossLoot.competitorContent)
  row:SetWidth(920)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(20, 20)
  row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  row.name = makeText(row, "", "GameFontNormalSmall")
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.name:SetWidth(250)
  row.name:SetJustifyH("LEFT")
  row.name:SetWordWrap(true)
  row.gp = makeText(row, "", "GameFontNormalSmall")
  row.gp:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
  row.gp:SetWidth(260)
  row.gp:SetJustifyH("LEFT")
  row.candidateCount = makeText(row, "", "GameFontNormalSmall")
  row.candidateCount:SetPoint("TOPLEFT", row, "TOPLEFT", 300, 0)
  row.candidateCount:SetTextColor(0.65, 0.65, 0.65)
  row.candidateButtons = {}
  row.candidateNotes = makeText(row, "", "GameFontHighlightSmall")
  row.candidateNotes:SetWidth(610)
  row.candidateNotes:SetJustifyH("LEFT")
  row.candidateNotes:SetWordWrap(true)
  row.candidateNotes:SetTextColor(0.65, 0.65, 0.65)
  row:EnableMouse(true)
  row:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    if self.itemLink then
      GameTooltip:SetHyperlink(self.itemLink)
    else
      GameTooltip:AddLine(self.itemName or "Предмет")
      GameTooltip:AddLine("ID " .. tostring(self.itemId), 0.68, 0.72, 0.75)
      GameTooltip:Show()
    end
  end)
  row:SetScript("OnLeave", GameTooltip_Hide)
  bossLoot.competitorRows[index] = row
  return row
end

local function formatCount(count, one, few, many)
  local lastTwo = count % 100
  local last = count % 10
  if lastTwo >= 11 and lastTwo <= 14 then
    return tostring(count) .. " " .. many
  elseif last == 1 then
    return tostring(count) .. " " .. one
  elseif last >= 2 and last <= 4 then
    return tostring(count) .. " " .. few
  end
  return tostring(count) .. " " .. many
end

function bossLoot.renderCompetitors(activeLoot)
  for _, row in ipairs(bossLoot.rows) do
    row:Hide()
  end
  bossLoot.competitorRows = bossLoot.competitorRows or {}
  for _, row in ipairs(bossLoot.competitorRows) do
    row:Hide()
  end
  if not bossLoot.competitorStatus then
    bossLoot.competitorStatus = makeText(bossLoot.competitorContent, "", "GameFontNormalSmall")
    bossLoot.competitorStatus:SetPoint("TOPLEFT", bossLoot.competitorContent, "TOPLEFT", 8, -4)
    bossLoot.competitorStatus:SetWidth(900)
    bossLoot.competitorStatus:SetJustifyH("LEFT")
    bossLoot.competitorStatus:SetWordWrap(true)
  end
  bossLoot.competitorStatus:Show()
  local candidates, message, playerPR, inRaid = bossLoot.getCompetitors()
  if not candidates then
    bossLoot.competitorStatus:SetText(message)
    bossLoot.competitorStatus:SetTextColor(0.90, 0.75, 0.45)
    bossLoot.competitorStatus:SetHeight(32)
    bossLoot.competitorContent:SetHeight(40)
    return
  end
  local classLoot, classLootError = bossLoot.getClassLootMap()
  if not classLoot then
    bossLoot.competitorStatus:SetText(classLootError)
    bossLoot.competitorStatus:SetTextColor(0.90, 0.75, 0.45)
    bossLoot.competitorStatus:SetHeight(32)
    bossLoot.competitorContent:SetHeight(40)
    return
  end

  local lines = {}
  if inRaid then
    lines[#lines + 1] = ("В рейде выше вашего PR %.3f: %s."):format(
      playerPR, formatCount(#candidates, "персонаж", "персонажа", "персонажей"))
  else
    lines[#lines + 1] = ("В гильдии выше вашего PR %.3f: %s (включая офлайн)."):format(
      playerPR, formatCount(#candidates, "персонаж", "персонажа", "персонажей"))
  end
  lines[#lines + 1] = "Учтены доступность по книге, тип брони и явные конфликты характеристик."
  if inRaid then
    local inspectedCount = 0
    for _, candidate in ipairs(candidates) do
      if candidate.wornItems then
        inspectedCount = inspectedCount + 1
      end
    end
    lines[#lines + 1] = ("Экипировка проверена: %d из %d. Недоступные для осмотра не исключены."):format(
      inspectedCount, #candidates)
  end
  if bossLoot.inspectFrame and bossLoot.inspectFrame:IsShown() and bossLoot.inspectStats then
    local stats = bossLoot.inspectStats
    local completed = stats.checked + stats.unavailable + stats.timedOut
    local currentName = bossLoot.inspectCurrent and bossLoot.inspectCurrent.name
    local currentStatus = currentName and
      (" Осматривается: %s."):format(currentName) or ""
    lines[#lines + 1] = ("Сканирование: %d из %d; в очереди %d.%s"):format(
      completed, stats.total, #bossLoot.inspectQueue, currentStatus)
  end

  local selectedMain = bossLoot.getPlayerMain(selectedPlayer)
  local ownItems
  if UnitName and bossLoot.normalizePlayerName(selectedMain) ==
    bossLoot.normalizePlayerName(UnitName("player")) then
    ownItems = bossLoot.readWornItems("player")
    bossLoot.ownWornItems = ownItems
  end
  local statusText = table.concat(lines, "\n")
  bossLoot.competitorStatus:SetText(statusText)
  bossLoot.competitorStatus:SetTextColor(0.65, 0.65, 0.65)
  local y = math.max(bossLoot.competitorStatus:GetStringHeight() + 12, #lines * 18 + 12)
  if not bossLoot.competitorItemHeader then
    bossLoot.competitorItemHeader = makeText(bossLoot.competitorContent, "Предмет", "GameFontNormalSmall")
    bossLoot.competitorCandidatesHeader = makeText(
      bossLoot.competitorContent, "Группы по основе", "GameFontNormalSmall")
    bossLoot.competitorItemHeader:SetTextColor(0.65, 0.65, 0.65)
    bossLoot.competitorCandidatesHeader:SetTextColor(0.65, 0.65, 0.65)
  end
  bossLoot.competitorItemHeader:ClearAllPoints()
  bossLoot.competitorItemHeader:SetPoint("TOPLEFT", bossLoot.competitorContent, "TOPLEFT", 8, -y)
  bossLoot.competitorCandidatesHeader:ClearAllPoints()
  bossLoot.competitorCandidatesHeader:SetPoint(
    "TOPLEFT", bossLoot.competitorContent, "TOPLEFT", 308, -y)
  bossLoot.competitorItemHeader:Show()
  bossLoot.competitorCandidatesHeader:Show()
  y = y + 22
  local multipliers = db.profile.guildPricing.categoryMultipliers or {}
  local mainMultiplier = multipliers.main or 1
  local minorMultiplier = multipliers.minor or 0.5
  local offTwinMultiplier = multipliers.offTwin or 0.25
  for itemIndex, item in ipairs(activeLoot) do
    local itemCandidates, equippedCount, unknownClassCount, classFilteredCount = {}, 0, 0, 0
    local unsuitableCount = 0
    for _, candidate in ipairs(candidates) do
      local classItems = candidate.classId and classLoot[candidate.classId]
      if not candidate.classId then
        unknownClassCount = unknownClassCount + 1
      elseif classItems and classItems[item.id] then
        if bossLoot.isItemClearlyUnsuitable(item, candidate.classId) then
          unsuitableCount = unsuitableCount + 1
        elseif inRaid and candidate.wornItems and candidate.wornItems[item.id] then
          equippedCount = equippedCount + 1
        else
          itemCandidates[#itemCandidates + 1] = candidate
        end
      else
        classFilteredCount = classFilteredCount + 1
      end
    end

    local candidateGroups, groupsByMain = {}, {}
    for _, candidate in ipairs(itemCandidates) do
      local mainName = candidate.main or candidate.name
      local mainKey = bossLoot.normalizePlayerName(mainName) or
        bossLoot.normalizePlayerName(candidate.name)
      local group = groupsByMain[mainKey]
      if not group then
        group = {
          mainName = mainName,
          mainKey = mainKey,
          members = {},
          twinks = {},
          hasMain = false,
        }
        groupsByMain[mainKey] = group
        candidateGroups[#candidateGroups + 1] = group
      end
      group.members[#group.members + 1] = candidate
      if bossLoot.normalizePlayerName(candidate.name) == mainKey then
        group.hasMain = true
      else
        group.twinks[#group.twinks + 1] = candidate
      end
    end

    local row = bossLoot.competitorRows[itemIndex]
    if not row then
      row = bossLoot.makeCompetitorRow(itemIndex)
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", bossLoot.competitorContent, "TOPLEFT", 8, -y)
    row:SetPoint("TOPRIGHT", bossLoot.competitorContent, "TOPRIGHT", -8, -y)
    row.itemId = item.id
    row.itemName = item.name
    row.itemLink = item.link
    row.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    row.name:SetText(item.name .. (ownItems and ownItems[item.id] and " (у вас надет)" or ""))
    if item.quality and GetItemQualityColor then
      local red, green, blue = GetItemQualityColor(item.quality)
      row.name:SetTextColor(red or 0.88, green or 0.91, blue or 0.94)
    else
      row.name:SetTextColor(0.88, 0.91, 0.94)
    end
    row.gp:SetText(item.gp and ("GP Main / Minor / Off: %.0f / %.0f / %.0f"):format(
      item.gp * mainMultiplier, item.gp * minorMultiplier,
      item.gp * offTwinMultiplier) or "Цена GP: —")
    row.gp:SetHeight(16)

    local candidateLines = {}
    if #itemCandidates == 0 then
      candidateLines[#candidateLines + 1] = "Нет подходящих персонажей."
    end
    if classFilteredCount > 0 then
      candidateLines[#candidateLines + 1] = ("Исключены по списку классов: %d."):format(classFilteredCount)
    end
    if unsuitableCount > 0 then
      candidateLines[#candidateLines + 1] = ("Исключены как неподходящие по типу брони или характеристикам: %d."):format(
        unsuitableCount)
    end
    if equippedCount > 0 then
      candidateLines[#candidateLines + 1] = ("Уже имеют этот предмет: %d."):format(equippedCount)
    end
    if unknownClassCount > 0 then
      candidateLines[#candidateLines + 1] = ("Класс не определён, персонажи не включены: %d."):format(
        unknownClassCount)
    end
    row.candidateCount:SetText(("Претенденты: %s (%s)"):format(
      formatCount(#candidateGroups, "группа по основе", "группы по основе", "групп по основе"),
      formatCount(#itemCandidates, "персонаж", "персонажа", "персонажей")))
    row.candidateCount:ClearAllPoints()
    row.candidateCount:SetPoint("TOPLEFT", row, "TOPLEFT", 300, 0)
    bossLoot.expandedCompetitorGroups = bossLoot.expandedCompetitorGroups or {}
    local expandedGroups = bossLoot.expandedCompetitorGroups[item.id]
    if not expandedGroups then
      expandedGroups = {}
      bossLoot.expandedCompetitorGroups[item.id] = expandedGroups
    end
    local candidateLine, candidateX = 0, 0
    local candidateAreaTop = 18
    local candidateListBottom = candidateAreaTop
    local function placeCandidateButton(button, text, indent)
      button.label:SetText(text)
      local buttonWidth = math.ceil(button.label:GetStringWidth()) + 6
      if candidateX > indent and candidateX + buttonWidth > 610 then
        candidateLine = candidateLine + 1
        candidateX = indent
      end
      button:ClearAllPoints()
      button:SetSize(buttonWidth, 16)
      button:SetPoint("TOPLEFT", row, "TOPLEFT",
        300 + candidateX, -(candidateAreaTop + candidateLine * 16))
      button:Show()
      candidateX = candidateX + buttonWidth
      candidateListBottom = math.max(candidateListBottom,
        candidateAreaTop + (candidateLine + 1) * 16)
    end

    local tokenIndex = 0
    local function getCandidateButton()
      tokenIndex = tokenIndex + 1
      if not row.candidateButtons[tokenIndex] then
        local button = CreateFrame("Button", nil, row)
        button.label = makeText(button, "", "GameFontHighlightSmall")
        button.label:SetAllPoints(button)
        button.label:SetJustifyH("LEFT")
        button.label:SetWordWrap(false)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnClick", function(self, mouseButton)
          if mouseButton == "RightButton" then
            if self.characterName then
              addon.ShowArmoryContextMenu(self.characterName)
            end
          elseif self.groupKey and self.itemId then
            bossLoot.expandedCompetitorGroups = bossLoot.expandedCompetitorGroups or {}
            local itemGroups = bossLoot.expandedCompetitorGroups[self.itemId] or {}
            bossLoot.expandedCompetitorGroups[self.itemId] = itemGroups
            itemGroups[self.groupKey] = not itemGroups[self.groupKey]
            bossLoot.render()
          end
        end)
        row.candidateButtons[tokenIndex] = button
      end
      return row.candidateButtons[tokenIndex]
    end

    for groupIndex, group in ipairs(candidateGroups) do
      local mainColor = playerClassColor(group.mainName)
      local hasExpandableMembers = #group.twinks > 0
      local isExpanded = hasExpandableMembers and expandedGroups[group.mainKey]
      local groupPrefix = isExpanded and "[-] " or (hasExpandableMembers and "[+] " or "")
      local mainMarker = group.hasMain and " (осн.)" or " (осн. не претендует)"
      local twinkCount = #group.twinks
      local twinkMarker = twinkCount > 0 and (" [твинков: %d]"):format(twinkCount) or ""
      local comma = groupIndex < #candidateGroups and not isExpanded and "," or ""
      local groupButton = getCandidateButton()
      groupButton.groupKey = hasExpandableMembers and group.mainKey or nil
      groupButton.itemId = item.id
      groupButton.characterName = group.mainName
      groupButton.label:SetText(("|cff999999%s%d. |r|cff%02x%02x%02x%s|r|cff999999%s%s%s|r"):format(
        groupPrefix, groupIndex, math.floor(mainColor.r * 255),
        math.floor(mainColor.g * 255), math.floor(mainColor.b * 255),
        group.mainName, mainMarker, twinkMarker, comma))
      placeCandidateButton(groupButton, groupButton.label:GetText(), 0)

      if isExpanded then
        candidateLine = candidateLine + 1
        candidateX = 12
        for twinkIndex, candidate in ipairs(group.twinks) do
          local color = playerClassColor(candidate.name)
          local memberButton = getCandidateButton()
          memberButton.groupKey = nil
          memberButton.itemId = nil
          memberButton.characterName = candidate.name
          local memberComma = (twinkIndex < #group.twinks or
            groupIndex < #candidateGroups) and "," or ""
          memberButton.label:SetText(("  |cff%02x%02x%02x%s|r|cff999999%s|r"):format(
            math.floor(color.r * 255), math.floor(color.g * 255),
            math.floor(color.b * 255), candidate.name, memberComma))
          placeCandidateButton(memberButton, memberButton.label:GetText(), 12)
        end
        candidateLine = candidateLine + 1
        candidateX = 0
      end
    end
    for buttonIndex = tokenIndex + 1, #row.candidateButtons do
      row.candidateButtons[buttonIndex]:Hide()
    end
    if #candidateGroups == 0 then
      candidateLine = 0
      candidateX = 0
    end
    local candidateListHeight = candidateListBottom - candidateAreaTop + 16
    row.candidateNotes:ClearAllPoints()
    row.candidateNotes:SetPoint("TOPLEFT", row, "TOPLEFT", 300, -candidateListHeight - 2)
    row.candidateNotes:SetText(table.concat(candidateLines, "\n"))
    local notesHeight = #candidateLines > 0 and
      math.max(row.candidateNotes:GetStringHeight(), 16) or 0
    local itemHeight = row.name:GetStringHeight() + 20
    row:SetHeight(math.max(42, candidateListHeight + notesHeight + 8, itemHeight))
    row:Show()
    y = y + row:GetHeight() + 5
  end

  for index = #activeLoot + 1, #bossLoot.competitorRows do
    bossLoot.competitorRows[index]:Hide()
  end
  bossLoot.competitorContent:SetHeight(math.max(y + 8, 1))
end

function bossLoot.readWornItems(unit)
  local items = {}
  for slot = 1, 19 do
    local link = GetInventoryItemLink and GetInventoryItemLink(unit, slot)
    local itemId = link and tonumber(link:match("item:(%d+)"))
    if itemId then
      items[itemId] = true
    end
  end
  return items
end

function bossLoot.cancelInspection()
  if bossLoot.inspectFrame then
    bossLoot.inspectFrame:Hide()
  end
  if bossLoot.inspectCurrent and ClearInspectPlayer then
    ClearInspectPlayer()
  end
  bossLoot.inspectQueue = {}
  bossLoot.inspectCurrent = nil
end

function bossLoot.updateInspectionStatus()
  local stats = bossLoot.inspectStats
  if not stats then
    return
  end
  local completed = stats.checked + stats.unavailable + stats.timedOut
  local currentName = bossLoot.inspectCurrent and bossLoot.inspectCurrent.name
  local currentStatus = currentName and
    (" Осматривается: %s."):format(currentName) or ""
  setStatus(("Сканирование экипировки: %d из %d; в очереди %d.%s"):format(
    completed, stats.total, #bossLoot.inspectQueue, currentStatus))
end

function bossLoot.startInspection()
  if bossLoot.getEffectiveScope() ~= "raid" or
    not GetNumRaidMembers or GetNumRaidMembers() == 0 then
    setStatus("Сканирование экипировки доступно только для текущего рейда. Выберите состав гильдии для анализа вне рейда.")
    return
  end
  if type(CreateFrame) ~= "function" or type(CanInspect) ~= "function" or
    type(NotifyInspect) ~= "function" or type(UnitGUID) ~= "function" or
    type(GetInventoryItemLink) ~= "function" then
    setStatus("Сканирование недоступно: API осмотра экипировки не полностью загружен.")
    return
  end
  local candidates, message = bossLoot.getCompetitors()
  if not candidates then
    setStatus(message)
    return
  end
  bossLoot.cancelInspection()
  bossLoot.inspections = {}
  bossLoot.inspectQueue = {}
  bossLoot.inspectStats = { total = #candidates, checked = 0, unavailable = 0, timedOut = 0 }
  for _, candidate in ipairs(candidates) do
    bossLoot.inspectQueue[#bossLoot.inspectQueue + 1] = candidate
  end
  bossLoot.inspectCurrent = nil
  bossLoot.inspectCooldown = 0
  if not bossLoot.inspectFrame then
    bossLoot.inspectFrame = CreateFrame("Frame")
    bossLoot.inspectFrame:SetScript("OnUpdate", function(_, elapsed)
      if bossLoot.inspectCurrent then
        bossLoot.inspectTimeout = (bossLoot.inspectTimeout or 0) + elapsed
        if bossLoot.inspectTimeout >= 6 then
          if ClearInspectPlayer then
            ClearInspectPlayer()
          end
          bossLoot.inspectStats.timedOut = bossLoot.inspectStats.timedOut + 1
          bossLoot.inspectCurrent = nil
          bossLoot.inspectCooldown = 1
          bossLoot.updateInspectionStatus()
          bossLoot.render()
        end
        return
      end
      bossLoot.inspectCooldown = math.max(0, (bossLoot.inspectCooldown or 0) - elapsed)
      if bossLoot.inspectCooldown > 0 or #bossLoot.inspectQueue == 0 then
        if #bossLoot.inspectQueue == 0 then
          bossLoot.inspectFrame:Hide()
          local stats = bossLoot.inspectStats
          setStatus(("Сканирование завершено: %d проверено, %d недоступны, %d тайм-аут."):format(
            stats.checked, stats.unavailable, stats.timedOut))
          bossLoot.render()
        end
        return
      end
      local candidate = table.remove(bossLoot.inspectQueue, 1)
      if candidate.unit == "player" then
        bossLoot.inspections[bossLoot.normalizePlayerName(candidate.name)] =
          bossLoot.readWornItems("player")
        bossLoot.inspectStats.checked = bossLoot.inspectStats.checked + 1
        bossLoot.inspectCooldown = 0.2
      elseif CanInspect and CanInspect(candidate.unit) and NotifyInspect then
        bossLoot.inspectCurrent = candidate
        bossLoot.inspectTimeout = 0
        local ok, err = pcall(NotifyInspect, candidate.unit)
        if not ok then
          bossLoot.inspectCurrent = nil
          bossLoot.inspectStats.unavailable = bossLoot.inspectStats.unavailable + 1
          bossLoot.inspectCooldown = 0.2
          setStatus(("Не удалось осмотреть %s: %s"):format(candidate.name, tostring(err)))
          bossLoot.render()
        else
          bossLoot.updateInspectionStatus()
        end
      else
        bossLoot.inspectStats.unavailable = bossLoot.inspectStats.unavailable + 1
        bossLoot.inspectCooldown = 0.2
        bossLoot.updateInspectionStatus()
        bossLoot.render()
      end
    end)
  end
  bossLoot.updateInspectionStatus()
  bossLoot.inspectFrame:Show()
  bossLoot.render()
end

function bossLoot.handleInspectReady(guid)
  local candidate = bossLoot.inspectCurrent
  if not candidate or not guid or not UnitGUID or UnitGUID(candidate.unit) ~= guid then
    return
  end
  bossLoot.inspections[bossLoot.normalizePlayerName(candidate.name)] =
    bossLoot.readWornItems(candidate.unit)
  bossLoot.inspectStats.checked = bossLoot.inspectStats.checked + 1
  if ClearInspectPlayer then
    ClearInspectPlayer()
  end
  bossLoot.inspectCurrent = nil
  bossLoot.inspectTimeout = 0
  bossLoot.inspectCooldown = 1.5
  bossLoot.updateInspectionStatus()
  bossLoot.render()
end

bossLoot.render = function()
  if not bossLoot.mode or not itemPanel or not itemPanel:IsShown() then
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
  bossLoot.content:SetHeight(1)
  bossLoot.competitorContent:SetHeight(1)
  if not bossLoot.encounterId then
    itemMedianText:SetText("Выберите тип, раздел, рейд и босса, чтобы увидеть добычу.")
    bossLoot.content:SetHeight(1)
    for _, row in ipairs(bossLoot.rows) do
      row:Hide()
    end
    return
  end
  if type(EJ_SelectTier) ~= "function" or type(EJ_SelectInstance) ~= "function" or
    type(EJ_SelectEncounter) ~= "function" or type(EJ_SetLootFilter) ~= "function" or
    type(EJ_GetNumLoot) ~= "function" or type(EJ_GetLootInfoByIndex) ~= "function" then
    itemMedianText:SetText("API добычи книги приключений недоступен.")
    bossLoot.content:SetHeight(1)
    return
  end

  rebuildItemGPMedians()
  local loot = bossLoot.withJournalState(function()
    EJ_SelectTier(bossLoot.tier)
    if type(EncounterJournal) == "table" then
      EncounterJournal.instanceID = bossLoot.instanceId
    end
    EJ_SelectInstance(bossLoot.instanceId)
    if type(EncounterJournal) == "table" then
      EncounterJournal.instanceID = bossLoot.instanceId
      EncounterJournal.encounterID = bossLoot.encounterId
    end
    if bossLoot.difficultyId and type(EJ_SetDifficulty) == "function" then
      local difficultyOk, difficultyError = pcall(EJ_SetDifficulty, bossLoot.difficultyId)
      if not difficultyOk then
        error("Не удалось применить сложность: " .. tostring(difficultyError))
      end
    end
    EJ_SelectEncounter(bossLoot.encounterId)
    EJ_SetLootFilter(bossLoot.classId, 0)
    local count = EJ_GetNumLoot()
    local items = {}
    for index = 1, tonumber(count) or 0 do
      local itemId, _, itemName = EJ_GetLootInfoByIndex(index)
      if itemId then
        local cachedName, itemLink, quality, itemSubClass
        if GetItemInfo then
          local itemLevel, requiredLevel, itemClass, maxStack
          cachedName, itemLink, quality, itemLevel, requiredLevel, itemClass,
            itemSubClass, maxStack = GetItemInfo(itemId)
        end
        local icon = getTooltipItemIcon(itemId)
        table.insert(items, {
          id = itemId,
          name = cachedName or itemName or ("Предмет " .. tostring(itemId)),
          link = itemLink,
          quality = quality,
          icon = icon,
          subClass = itemSubClass,
          gp = getStandardGP(itemId),
        })
      end
    end
    return items
  end)
  if not loot then
    itemMedianText:SetText("Не удалось получить добычу. Подробности — в сообщении аддона.")
    bossLoot.content:SetHeight(1)
    return
  end

  truncateTextToWidth(itemMedianText, ("%s | %s | %s | предметов: %d"):format(
    bossLoot.encounterName or "Добыча босса",
    bossLoot.difficultyName or "текущая сложность",
    bossLoot.getClassName(bossLoot.classId),
    #loot), itemMedianText:GetWidth())
  local includedItems, excludedItems = {}, {}
  for _, item in ipairs(loot) do
    if bossLoot.excludedItems[item.id] then
      excludedItems[#excludedItems + 1] = item
    else
      includedItems[#includedItems + 1] = item
    end
  end
  bossLoot.activeLoot = includedItems
  if bossLoot.view == "competitors" then
    if bossLoot.sectionLabel then
      bossLoot.sectionLabel:Hide()
    end
    bossLoot.renderCompetitors(includedItems)
    return
  end
  if bossLoot.competitorStatus then
    bossLoot.competitorStatus:Hide()
  end
  local rowIndex = 0
  for _, item in ipairs(includedItems) do
    rowIndex = rowIndex + 1
    local row = bossLoot.rows[rowIndex]
    if not row then
      row = bossLoot.makeRow(rowIndex)
      bossLoot.rows[rowIndex] = row
    end
    row:SetPoint("TOPLEFT", bossLoot.content, "TOPLEFT", 0, -(rowIndex - 1) * 26)
    row:SetPoint("TOPRIGHT", bossLoot.content, "TOPRIGHT", 0, -(rowIndex - 1) * 26)
    row.name:SetText(item.name)
    row.itemName = item.name
    row.itemLink = item.link
    row.itemIdValue = item.id
    row.gp:SetText(item.gp and ("%.0f GP"):format(item.gp) or "—")
    row.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    if item.quality and GetItemQualityColor then
      local red, green, blue = GetItemQualityColor(item.quality)
      if red and green and blue then
        row.name:SetTextColor(red, green, blue)
      else
        row.name:SetTextColor(0.88, 0.91, 0.94)
      end
    else
      row.name:SetTextColor(0.88, 0.91, 0.94)
    end
    row.name:SetAlpha(1)
    row.gp:SetTextColor(0.88, 0.91, 0.94)
    row.gp:SetAlpha(1)
    row.icon:SetAlpha(1)
    row.toggle.label:SetText("×")
    row:Show()
  end
  if #excludedItems > 0 then
    if not bossLoot.sectionLabel then
      bossLoot.sectionLabel = bossLoot.content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    end
    bossLoot.sectionLabel:ClearAllPoints()
    bossLoot.sectionLabel:SetPoint("TOPLEFT", bossLoot.content, "TOPLEFT", 8, -rowIndex * 26 - 3)
    bossLoot.sectionLabel:SetText(("Исключённые предметы (%d)"):format(#excludedItems))
    bossLoot.sectionLabel:Show()
    rowIndex = rowIndex + 1
    for _, item in ipairs(excludedItems) do
      rowIndex = rowIndex + 1
      local row = bossLoot.rows[rowIndex]
      if not row then
        row = bossLoot.makeRow(rowIndex)
        bossLoot.rows[rowIndex] = row
      end
      row:SetPoint("TOPLEFT", bossLoot.content, "TOPLEFT", 0, -(rowIndex - 1) * 26)
      row:SetPoint("TOPRIGHT", bossLoot.content, "TOPRIGHT", 0, -(rowIndex - 1) * 26)
      row.name:SetText(item.name)
      row.itemName = item.name
      row.itemLink = item.link
      row.itemIdValue = item.id
      row.gp:SetText(item.gp and ("%.0f GP"):format(item.gp) or "—")
      row.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
      row.name:SetTextColor(0.55, 0.58, 0.61)
      row.name:SetAlpha(0.65)
      row.gp:SetTextColor(0.55, 0.58, 0.61)
      row.gp:SetAlpha(0.65)
      row.icon:SetAlpha(0.45)
      row.toggle.label:SetText("✓")
      row:Show()
    end
  elseif bossLoot.sectionLabel then
    bossLoot.sectionLabel:Hide()
  end
  for index = rowIndex + 1, #bossLoot.rows do
    bossLoot.rows[index]:Hide()
  end
  bossLoot.content:SetHeight(math.max(rowIndex * 26, 1))
end

bossLoot.updateControls = function()
  if not bossLoot.modeButton then
    return
  end
  bossLoot.modeButton.label:SetText(bossLoot.mode and "История предмета" or "Лут с босса")
  bossLoot.typeButton.label:SetText(bossLoot.isRaid and "Рейды" or "Подземелья")
  bossLoot.tierButton.label:SetText(bossLoot.tierName or "Дополнение")
  bossLoot.instanceButton.label:SetText(bossLoot.instanceName or "Рейд / подземелье")
  bossLoot.encounterButton.label:SetText(bossLoot.encounterName or "Босс")
  bossLoot.classButton.label:SetText(bossLoot.getClassName(bossLoot.classId))
  bossLoot.difficultyButton.label:SetText(bossLoot.difficultyName or "Сложность")
  if bossLoot.scopeButton then
    local effectiveScope = bossLoot.getEffectiveScope()
    local scopeLabels = {
      auto = effectiveScope == "raid" and "Авто: рейд" or "Авто: гильдия",
      raid = "Состав: Рейд",
      guild = "Состав: Гильдия",
    }
    bossLoot.scopeButton.label:SetText(
      scopeLabels[bossLoot.competitorScope or "auto"] or scopeLabels.auto)
    if bossLoot.mode and bossLoot.view == "competitors" then
      bossLoot.scopeButton:Show()
    else
      bossLoot.scopeButton:Hide()
    end
  end
  for _, button in ipairs({
    bossLoot.typeButton, bossLoot.tierButton, bossLoot.instanceButton,
    bossLoot.encounterButton, bossLoot.classButton, bossLoot.difficultyButton,
  }) do
    if bossLoot.mode then
      button:Show()
    else
      button:Hide()
    end
  end
  for _, header in ipairs(bossLoot.headerButtons) do
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", itemPanel, "TOPLEFT", header.itemX, bossLoot.mode and -76 or -44)
    if bossLoot.mode then
      header:Hide()
    else
      header:Show()
    end
  end
  if bossLoot.gpHeader then
    if bossLoot.mode then
      bossLoot.gpHeader:Show()
    else
      bossLoot.gpHeader:Hide()
    end
  end
  if bossLoot.viewButton then
    bossLoot.viewButton.label:SetText(
      bossLoot.view == "loot" and "Прогноз по рейду" or "Назад к луту")
    if bossLoot.mode then
      bossLoot.viewButton:Show()
    else
      bossLoot.viewButton:Hide()
    end
  end
  if bossLoot.inspectButton then
    if bossLoot.mode and bossLoot.view == "competitors" and
      bossLoot.getEffectiveScope() == "raid" and
      GetNumRaidMembers and GetNumRaidMembers() > 0 then
      bossLoot.inspectButton:Show()
    else
      bossLoot.inspectButton:Hide()
    end
  end
  itemListingScroll:ClearAllPoints()
  itemListingScroll:SetPoint("TOPLEFT", itemPanel, "TOPLEFT", 12, -68)
  itemListingScroll:SetPoint("BOTTOMRIGHT", itemPanel, "BOTTOMRIGHT", -32, 12)
  bossLoot.scroll:ClearAllPoints()
  bossLoot.scroll:SetPoint("TOPLEFT", itemPanel, "TOPLEFT", 12, -104)
  bossLoot.scroll:SetPoint("BOTTOMRIGHT", itemPanel, "BOTTOMRIGHT", -32, 12)
  bossLoot.competitorScroll:ClearAllPoints()
  bossLoot.competitorScroll:SetPoint("TOPLEFT", itemPanel, "TOPLEFT", 12, -104)
  bossLoot.competitorScroll:SetPoint("BOTTOMRIGHT", itemPanel, "BOTTOMRIGHT", -32, 12)
  if bossLoot.mode and bossLoot.view == "loot" then
    itemListingScroll:Hide()
    bossLoot.scroll:Show()
    bossLoot.competitorScroll:Hide()
  elseif bossLoot.mode then
    itemListingScroll:Hide()
    bossLoot.scroll:Hide()
    bossLoot.competitorScroll:Show()
  else
    itemListingScroll:Show()
    bossLoot.scroll:Hide()
    bossLoot.competitorScroll:Hide()
  end
  updateLootControlHighlights()
end

createItemAnalysisUI = function()
  itemPanel = makePanel(window)
  itemPanel:SetPoint("TOPLEFT", window, "TOPLEFT", 16, -112)
  itemPanel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -16, 48)
  itemPanel:Hide()

  itemDropdown = makeButton(itemPanel, "Выбрать предмет", 230, 26, toggleItemDropdown)
  itemDropdown:SetPoint("TOPLEFT", itemPanel, "TOPLEFT", 18, -12)
  bossLoot.modeButton = makeButton(itemPanel, "Лут с босса", 132, 26, function()
    bossLoot.cancelInspection()
    bossLoot.mode = not bossLoot.mode
    if itemDropdownMenu then
      itemDropdownMenu:Hide()
      itemSearch:ClearFocus()
    end
    for _, dropdown in ipairs(bossLoot.dropdowns) do
      dropdown.menu:Hide()
    end
    bossLoot.updateControls()
    renderItemAnalysis()
  end)
  bossLoot.modeButton:SetPoint("LEFT", itemDropdown, "RIGHT", 8, 0)
  itemMedianText = makeText(itemPanel, "", "GameFontNormalSmall")
  itemMedianText:SetPoint("LEFT", bossLoot.modeButton, "RIGHT", 12, 0)
  itemMedianText:SetPoint("RIGHT", itemPanel, "RIGHT", -14, 0)
  itemMedianText:SetJustifyH("LEFT")
  itemMedianText:SetWordWrap(false)
  itemMedianText:SetTextColor(0.78, 0.84, 0.87)

  local _, playerClassToken = UnitClass("player")
  local classIdByToken = {
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
    DEATHKNIGHT = 6, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11,
  }
  bossLoot.classId = bossLoot.classId or classIdByToken[playerClassToken] or 3

  bossLoot.typeButton = bossLoot.createDropdown(itemPanel, "Рейды", 110,
    function()
      return {
        { value = true, label = "Рейды" },
        { value = false, label = "Подземелья" },
      }
    end,
    function(value)
      bossLoot.isRaid = value
      bossLoot.instanceId, bossLoot.instanceName = nil, nil
      bossLoot.encounterId, bossLoot.encounterName = nil, nil
      bossLoot.difficultyId, bossLoot.difficultyName = nil, nil
      bossLoot.saveSelection()
      bossLoot.updateControls()
      renderItemAnalysis()
    end)
  bossLoot.typeButton:SetPoint("TOPLEFT", itemPanel, "TOPLEFT", 18, -44)

  bossLoot.tierButton = bossLoot.createDropdown(itemPanel, "Дополнение", 165,
    bossLoot.getTierOptions,
    function(value, label)
      bossLoot.tier, bossLoot.tierName = value, label
      bossLoot.instanceId, bossLoot.instanceName = nil, nil
      bossLoot.encounterId, bossLoot.encounterName = nil, nil
      bossLoot.difficultyId, bossLoot.difficultyName = nil, nil
      bossLoot.saveSelection()
      bossLoot.updateControls()
      renderItemAnalysis()
    end)
  bossLoot.tierButton:SetPoint("LEFT", bossLoot.typeButton, "RIGHT", 8, 0)

  bossLoot.instanceButton = bossLoot.createDropdown(itemPanel, "Рейд / подземелье", 190,
    bossLoot.getInstanceOptions,
    function(value, label)
      bossLoot.instanceId, bossLoot.instanceName = value, label
      bossLoot.encounterId, bossLoot.encounterName = nil, nil
      bossLoot.difficultyId, bossLoot.difficultyName = nil, nil
      local difficulties = bossLoot.getDifficultyOptions() or {}
      local currentDifficulty
      if type(EJ_GetDifficulty) == "function" then
        local currentOk, currentValue = pcall(EJ_GetDifficulty)
        if currentOk then
          currentDifficulty = currentValue
        end
      end
      for _, option in ipairs(difficulties) do
        if option.value == currentDifficulty then
          bossLoot.difficultyId, bossLoot.difficultyName = option.value, option.label
          break
        end
      end
      if not bossLoot.difficultyId and difficulties[1] then
        bossLoot.difficultyId, bossLoot.difficultyName = difficulties[1].value, difficulties[1].label
      end
      bossLoot.saveSelection()
      bossLoot.updateControls()
      renderItemAnalysis()
    end)
  bossLoot.instanceButton:SetPoint("LEFT", bossLoot.tierButton, "RIGHT", 8, 0)

  bossLoot.encounterButton = bossLoot.createDropdown(itemPanel, "Босс", 165,
    bossLoot.getEncounterOptions,
    function(value, label)
      bossLoot.encounterId, bossLoot.encounterName = value, label
      bossLoot.saveSelection()
      bossLoot.updateControls()
      renderItemAnalysis()
    end)
  bossLoot.encounterButton:SetPoint("LEFT", bossLoot.instanceButton, "RIGHT", 8, 0)

  local classOptions = {}
  for _, option in ipairs(bossLoot.classOptions) do
    table.insert(classOptions, { value = option.id, label = option.name })
  end
  bossLoot.classButton = bossLoot.createDropdown(itemPanel, "Класс", 105,
    function()
      return classOptions
    end,
    function(value)
      bossLoot.classId = value
      bossLoot.saveSelection()
      bossLoot.updateControls()
      renderItemAnalysis()
    end)
  bossLoot.classButton:SetPoint("LEFT", bossLoot.encounterButton, "RIGHT", 8, 0)

  bossLoot.difficultyButton = bossLoot.createDropdown(itemPanel, "Сложность", 120,
    bossLoot.getDifficultyOptions,
    function(value, label)
      bossLoot.difficultyId, bossLoot.difficultyName = value, label
      bossLoot.saveSelection()
      bossLoot.updateControls()
      renderItemAnalysis()
    end)
  bossLoot.difficultyButton:SetPoint("LEFT", bossLoot.classButton, "RIGHT", 8, 0)

  bossLoot.viewButton = makeButton(itemPanel, "Прогноз по рейду", 130, 24, function()
    bossLoot.cancelInspection()
    bossLoot.view = bossLoot.view == "loot" and "competitors" or "loot"
    bossLoot.updateControls()
    renderItemAnalysis()
  end)
  bossLoot.viewButton:SetPoint("TOPLEFT", itemPanel, "TOPLEFT", 18, -72)
  bossLoot.inspectButton = makeButton(itemPanel, "Сканировать экипировку", 170, 24, function()
    bossLoot.startInspection()
  end)
  bossLoot.inspectButton:SetPoint("LEFT", bossLoot.viewButton, "RIGHT", 8, 0)
  bossLoot.scopeButton = bossLoot.createDropdown(itemPanel, "Состав: Авто", 160,
    function()
      return {
        { value = "auto", label = "Авто: рейд / гильдия" },
        { value = "raid", label = "Только текущий рейд" },
        { value = "guild", label = "Вся гильдия" },
      }
    end,
    function(value)
      bossLoot.cancelInspection()
      bossLoot.competitorScope = value
      bossLoot.inspections = {}
      bossLoot.saveSelection()
      bossLoot.updateControls()
      renderItemAnalysis()
    end)
  bossLoot.scopeButton:SetPoint("LEFT", bossLoot.inspectButton, "RIGHT", 8, 0)

  for _, dropdown in ipairs(bossLoot.dropdowns) do
    dropdown.button:Hide()
  end

  itemDropdownMenu = makePanel(window)
  itemDropdownMenu:SetFrameStrata("DIALOG")
  itemDropdownMenu:SetFrameLevel(window:GetFrameLevel() + 20)
  itemDropdownMenu:SetSize(250, 244)
  itemDropdownMenu:SetPoint("TOPLEFT", itemDropdown, "BOTTOMLEFT", 0, -3)
  itemDropdownMenu:Hide()

  itemSearch = CreateFrame("EditBox", nil, itemDropdownMenu, "InputBoxTemplate")
  itemSearch:SetSize(226, 24)
  itemSearch:SetPoint("TOPLEFT", itemDropdownMenu, "TOPLEFT", 10, -8)
  itemSearch:SetAutoFocus(false)
  itemSearch:SetMaxLetters(48)
  itemSearch:SetFontObject(GameFontHighlightSmall)
  itemSearch:SetTextInsets(6, 6, 0, 0)
  itemSearchHint = makeText(itemDropdownMenu, "Поиск предмета...", "GameFontDisableSmall")
  itemSearchHint:SetPoint("LEFT", itemSearch, "LEFT", 8, 0)
  itemSearchHint:SetTextColor(0.55, 0.58, 0.61)
  itemSearchHint:Show()
  itemSearch:SetScript("OnTextChanged", function()
    updateItemDropdown()
  end)
  itemSearch:SetScript("OnEditFocusGained", function()
    itemSearchHint:Hide()
  end)
  itemSearch:SetScript("OnEditFocusLost", function()
    if itemSearch:GetText() == "" then
      itemSearchHint:Show()
    end
  end)
  itemSearch:SetScript("OnEscapePressed", function()
    itemDropdownMenu:Hide()
    itemSearch:ClearFocus()
  end)
  itemDropdownScroll = CreateFrame("ScrollFrame", nil, itemDropdownMenu, "UIPanelScrollFrameTemplate")
  itemDropdownScroll:SetPoint("TOPLEFT", itemDropdownMenu, "TOPLEFT", 8, -36)
  itemDropdownScroll:SetPoint("BOTTOMRIGHT", itemDropdownMenu, "BOTTOMRIGHT", -28, 8)
  itemDropdownContent = CreateFrame("Frame", nil, itemDropdownScroll)
  itemDropdownContent:SetWidth(212)
  itemDropdownContent:SetHeight(1)
  itemDropdownScroll:SetScrollChild(itemDropdownContent)
  itemDropdownScroll:SetScript("OnMouseWheel", function(self, delta)
    local maximum = math.max(itemDropdownContent:GetHeight() - self:GetHeight(), 0)
    self:SetVerticalScroll(math.max(0, math.min(maximum, self:GetVerticalScroll() - delta * 24)))
  end)

  local headers = {
    { key = "timestamp", text = "Дата выдачи", x = 10, width = 100 },
    { key = "player", text = "Игрок", x = 115, width = 115 },
    { key = "role", text = "Роль", x = 235, width = 70 },
    { key = "amount", text = "GP", x = 310, width = 70 },
    { key = "guildPrice", text = "Цена GP", x = 385, width = 80 },
    { key = "difference", text = "Отклонение %", x = 470, width = 80 },
    { key = "officer", text = "Офицер", x = 555, width = 85 },
    { key = "category", text = "Категория", x = 645, width = 95 },
    { key = "reason", text = "Причина", x = 750, width = 270 },
  }
  bossLoot.gpHeader = makeText(itemPanel, "Цена GP", "GameFontNormalSmall")
  bossLoot.gpHeader:SetPoint("TOPLEFT", itemPanel, "TOPLEFT", 802, -90)
  bossLoot.gpHeader:SetTextColor(0.78, 0.84, 0.87)
  bossLoot.headerButtons = {}
  for _, header in ipairs(headers) do
    local headerKey = header.key
    local button = makeButton(itemPanel, header.text, header.width, 22, function()
      if itemSortColumn == headerKey then
        itemSortDescending = not itemSortDescending
      else
        itemSortColumn = headerKey
        itemSortDescending = headerKey == "timestamp"
      end
      renderItemAnalysis()
    end)
    button.itemX = header.x
    button.itemHeaderKey = header.key
    button.itemHeaderText = header.text
    bossLoot.headerButtons[#bossLoot.headerButtons + 1] = button
    button:SetPoint("TOPLEFT", itemPanel, "TOPLEFT", header.x, -44)
  end

  itemListingScroll = CreateFrame("ScrollFrame", "BearyWatchItemListingScroll", itemPanel, "UIPanelScrollFrameTemplate")
  itemListingScroll:SetPoint("TOPLEFT", itemPanel, "TOPLEFT", 12, -68)
  itemListingScroll:SetPoint("BOTTOMRIGHT", itemPanel, "BOTTOMRIGHT", -32, 12)
  itemListingContent = CreateFrame("Frame", nil, itemListingScroll)
  itemListingContent:SetWidth(1020)
  itemListingContent:SetHeight(1)
  itemListingScroll:SetScrollChild(itemListingContent)
  bossLoot.scroll = CreateFrame("ScrollFrame", nil, itemPanel, "UIPanelScrollFrameTemplate")
  bossLoot.scroll:SetPoint("TOPLEFT", itemPanel, "TOPLEFT", 12, -104)
  bossLoot.scroll:SetPoint("BOTTOMRIGHT", itemPanel, "BOTTOMRIGHT", -32, 12)
  bossLoot.content = CreateFrame("Frame", nil, bossLoot.scroll)
  bossLoot.content:SetWidth(1020)
  bossLoot.content:SetHeight(1)
  bossLoot.scroll:SetScrollChild(bossLoot.content)
  bossLoot.scroll:Hide()
  bossLoot.competitorScroll = CreateFrame("ScrollFrame", nil, itemPanel, "UIPanelScrollFrameTemplate")
  bossLoot.competitorScroll:SetPoint("TOPLEFT", itemPanel, "TOPLEFT", 12, -104)
  bossLoot.competitorScroll:SetPoint("BOTTOMRIGHT", itemPanel, "BOTTOMRIGHT", -32, 12)
  bossLoot.competitorContent = CreateFrame("Frame", nil, bossLoot.competitorScroll)
  bossLoot.competitorContent:SetWidth(1020)
  bossLoot.competitorContent:SetHeight(1)
  bossLoot.competitorScroll:SetScrollChild(bossLoot.competitorContent)
  bossLoot.competitorScroll:Hide()
  bossLoot.updateControls()
end

createSettingsUI = function()
  settingsPanel = makePanel(window)
  settingsPanel:SetPoint("TOPLEFT", window, "TOPLEFT", 16, -84)
  settingsPanel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -16, 12)
  settingsPanel:Hide()

  local settingsPages = {}
  local settingsPageButtons = {}
  local function selectSettingsPage(pageKey)
    db.profile.settingsSection = pageKey
    for key, frame in pairs(settingsPages) do
      if key == pageKey then frame:Show() else frame:Hide() end
    end
    for key, pageButton in pairs(settingsPageButtons) do
      local selected = key == pageKey
      pageButton.isActive = selected
      pageButton.activeColor = COLORS.EP
      pageButton.background:SetVertexColor(selected and COLORS.EP[1] or 0.12,
        selected and COLORS.EP[2] or 0.15,
        selected and COLORS.EP[3] or 0.18, selected and 0.55 or 1)
    end
  end
  local settingsPageNames = {
    { key = "basics", label = "Основные", width = 112 },
    { key = "epgp", label = "Правила EPGP", width = 128 },
    { key = "guild", label = "Правила GP гильдии", width = 174 },
    { key = "exchange", label = "Импорт / экспорт", width = 150 },
  }
  for index, page in ipairs(settingsPageNames) do
    local pageKey = page.key
    local button = makeButton(settingsPanel, page.label, page.width, 26, function()
      if journalSourceMenu then
        journalSourceMenu:Hide()
      end
      selectSettingsPage(pageKey)
    end)
    if index == 1 then
      button:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 16, -10)
    else
      button:SetPoint("LEFT", settingsPageButtons[settingsPageNames[index - 1].key], "RIGHT", 6, 0)
    end
    settingsPageButtons[pageKey] = button
    local pageFrame = makePanel(settingsPanel)
    pageFrame:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 8, -44)
    pageFrame:SetPoint("BOTTOMRIGHT", settingsPanel, "BOTTOMRIGHT", -8, 8)
    settingsPages[pageKey] = pageFrame
  end
  local selectedSettingsPage = db.profile.settingsSection
  if not settingsPages[selectedSettingsPage] then
    selectedSettingsPage = "basics"
    db.profile.settingsSection = selectedSettingsPage
  end
  selectSettingsPage(selectedSettingsPage)
  local basicsPage = settingsPages.basics
  local epgpPage = settingsPages.epgp
  local guildPage = settingsPages.guild
  local exchangePage = settingsPages.exchange

  local journalSourceTitle = makeText(basicsPage, "Источник журнала EPGP", "GameFontNormal")
  journalSourceTitle:SetPoint("TOPLEFT", basicsPage, "TOPLEFT", 22, -16)
  journalSourceTitle:SetTextColor(0.78, 0.88, 0.92)
  local journalSourceDescription = makeText(basicsPage,
    "Выберите один профиль. Журналы разных профилей не объединяются.", "GameFontNormalSmall")
  journalSourceDescription:SetPoint("TOPLEFT", journalSourceTitle, "BOTTOMLEFT", 0, -6)
  journalSourceDescription:SetTextColor(0.62, 0.67, 0.70)

  journalSourceDropdown = makeButton(basicsPage, "", 360, 28, function()
    if journalSourceMenu:IsShown() then
      journalSourceMenu:Hide()
    else
      updateJournalSourceDropdown()
      journalSourceMenu:Show()
    end
  end)
  journalSourceDropdown:SetPoint("TOPLEFT", journalSourceDescription, "BOTTOMLEFT", 0, -8)

  local addonLootFilterToggle
  local function updateAddonLootFilterToggle()
    addonLootFilterToggle.label:SetText(db.profile.useAddonLootFilter ~= false and
      "Фильтрация лута аддоном: включена" or
      "Фильтрация лута аддоном: выключена")
  end
  addonLootFilterToggle = makeButton(basicsPage, "", 350, 28, function()
    db.profile.useAddonLootFilter = not (db.profile.useAddonLootFilter ~= false)
    bossLoot.cancelInspection()
    bossLoot.inspections = {}
    bossLoot.inspectStats = nil
    bossLoot.view = "loot"
    if bossLoot.competitorContent then
      bossLoot.competitorContent:SetHeight(1)
    end
    if bossLoot.competitorScroll then
      bossLoot.competitorScroll:SetVerticalScroll(0)
    end
    bossLoot.updateControls()
    updateAddonLootFilterToggle()
    refreshViews()
  end)
  addonLootFilterToggle:SetPoint("LEFT", journalSourceDropdown, "RIGHT", 12, 0)
  updateAddonLootFilterToggle()
  local addonLootFilterDescription = makeText(basicsPage,
    "Дополнительно к фильтру Путеводителя по приключениям.", "GameFontNormalSmall")
  addonLootFilterDescription:SetPoint("TOPLEFT", addonLootFilterToggle, "BOTTOMLEFT", 0, -6)
  addonLootFilterDescription:SetTextColor(0.62, 0.67, 0.70)

  journalSourceMenu = makePanel(window)
  journalSourceMenu:SetFrameStrata("DIALOG")
  journalSourceMenu:SetFrameLevel(window:GetFrameLevel() + 25)
  journalSourceMenu:SetSize(370, 210)
  journalSourceMenu:SetPoint("TOPLEFT", journalSourceDropdown, "BOTTOMLEFT", 0, -3)
  journalSourceMenu:Hide()

  journalSourceScroll = CreateFrame("ScrollFrame", nil, journalSourceMenu)
  journalSourceScroll:SetPoint("TOPLEFT", journalSourceMenu, "TOPLEFT", 4, -4)
  journalSourceScroll:SetPoint("BOTTOMRIGHT", journalSourceMenu, "BOTTOMRIGHT", -4, 4)
  journalSourceScroll:EnableMouseWheel(true)
  journalSourceContent = CreateFrame("Frame", nil, journalSourceScroll)
  journalSourceContent:SetWidth(354)
  journalSourceContent:SetHeight(1)
  journalSourceScroll:SetScrollChild(journalSourceContent)
  journalSourceScroll:SetScript("OnMouseWheel", function(self, delta)
    local maximum = math.max(journalSourceContent:GetHeight() - self:GetHeight(), 0)
    self:SetVerticalScroll(math.max(0, math.min(maximum, self:GetVerticalScroll() - delta * 30)))
  end)

  updateJournalSourceDropdown = function()
    local sources = getJournalSources()
    local selectedProfile = db.char.epgpJournalProfile
    local selectedSource
    for _, source in ipairs(sources) do
      if source.key == selectedProfile then
        selectedSource = source
        break
      end
    end
    if selectedSource then
      journalSourceDropdown.label:SetText(("%s — %d записей"):format(
        selectedSource.label, selectedSource.count))
    else
      journalSourceDropdown.label:SetText("Журнал EPGP не найден")
    end
    journalSourceContent:SetHeight(math.max(#sources * 28, 1))
    for index, source in ipairs(sources) do
      if not journalSourceRows[index] then
        journalSourceRows[index] = makeButton(journalSourceContent, "", 344, 26, function(self)
          db.char.epgpJournalProfile = self.sourceKey
          db.profile.rangeStart, db.profile.rangeEnd = 0, 0
          db.profile.timelinePlayers = {}
          selectedPlayers = {}
          selectedPlayer = nil
          restoreSavedPlayerSelection = false
          journalSourceMenu:Hide()
          updateJournalSourceDropdown()
          refreshViews()
        end)
        journalSourceRows[index]:SetPoint("TOPLEFT", journalSourceContent,
          "TOPLEFT", 0, -(index - 1) * 28)
        journalSourceRows[index]:SetPoint("TOPRIGHT", journalSourceContent,
          "TOPRIGHT", 0, -(index - 1) * 28)
      end
      local row = journalSourceRows[index]
      row.sourceKey = source.key
      row.label:SetText(("%s%s — %d записей"):format(
        source.key == selectedProfile and "[выбрано] " or "",
        source.label, source.count))
      row:Show()
    end
    for index = #sources + 1, #journalSourceRows do
      journalSourceRows[index]:Hide()
    end
    if #sources == 0 then
      journalSourceContent:SetHeight(28)
      if not journalSourceRows[1] then
        journalSourceRows[1] = makeButton(journalSourceContent,
          "Журналы EPGP не найдены", 344, 26)
        journalSourceRows[1]:SetPoint("TOPLEFT", journalSourceContent, "TOPLEFT", 0, 0)
        journalSourceRows[1]:SetPoint("TOPRIGHT", journalSourceContent, "TOPRIGHT", 0, 0)
      end
      journalSourceRows[1]:Show()
    end
  end
  updateJournalSourceDropdown()

  local groupingLabel = makeText(basicsPage, "Группировка истории", "GameFontNormal")
  groupingLabel:SetPoint("TOPLEFT", basicsPage, "TOPLEFT", 22, -112)
  groupingLabel:SetTextColor(0.78, 0.88, 0.92)
  local groupingDescription = makeText(basicsPage, "В режиме «Мейн» события альтов объединяются через связи, известные EPGP сейчас.", "GameFontNormalSmall")
  groupingDescription:SetPoint("TOPLEFT", groupingLabel, "BOTTOMLEFT", 0, -8)
  groupingDescription:SetTextColor(0.62, 0.67, 0.70)

  local mainGrouping = makeButton(basicsPage, "Объединять по мейну", 180, 28, function()
    db.profile.grouping = "main"
    rankSnapshotsDirty = true
    db.profile.rangeStart, db.profile.rangeEnd = 0, 0
    refreshViews()
  end)
  mainGrouping:SetPoint("TOPLEFT", groupingDescription, "BOTTOMLEFT", 0, -14)
  local toonGrouping = makeButton(basicsPage, "Каждый персонаж отдельно", 200, 28, function()
    db.profile.grouping = "toon"
    rankSnapshotsDirty = true
    db.profile.rangeStart, db.profile.rangeEnd = 0, 0
    refreshViews()
  end)
  toonGrouping:SetPoint("LEFT", mainGrouping, "RIGHT", 8, 0)

  local minimapToggle
  minimapToggle = makeButton(basicsPage, "", 230, 28, function()
    db.profile.minimap.hide = not db.profile.minimap.hide
    if minimapButton then
      if db.profile.minimap.hide then minimapButton:Hide() else minimapButton:Show() end
    end
    minimapToggle.label:SetText(db.profile.minimap.hide and "Показывать кнопку миникарты: нет" or "Показывать кнопку миникарты: да")
  end)
  minimapToggle:SetPoint("TOPLEFT", mainGrouping, "BOTTOMLEFT", 0, -20)
  minimapToggle.label:SetText(db.profile.minimap.hide and "Показывать кнопку миникарты: нет" or "Показывать кнопку миникарты: да")

  local inactiveToggle
  inactiveToggle = makeButton(basicsPage, "", 270, 28, function()
    db.profile.hideInactivePlayers = not db.profile.hideInactivePlayers
    inactiveToggle.label:SetText(db.profile.hideInactivePlayers and "Скрывать неактивных: да" or "Скрывать неактивных: нет")
    refreshViews()
  end)
  inactiveToggle:SetPoint("TOPLEFT", minimapToggle, "BOTTOMLEFT", 0, -20)
  inactiveToggle.label:SetText(db.profile.hideInactivePlayers and "Скрывать неактивных: да" or "Скрывать неактивных: нет")

  local inactiveMonthsLabel = makeText(basicsPage, "", "GameFontNormalSmall")
  inactiveMonthsLabel:SetPoint("TOPLEFT", inactiveToggle, "BOTTOMLEFT", 0, -14)
  local function updateInactiveMonthsLabel()
    inactiveMonthsLabel:SetText(("Скрывать, если нет событий более %d мес."):format(db.profile.inactiveAfterMonths))
  end
  updateInactiveMonthsLabel()

  local monthsDecrease = makeButton(basicsPage, "−", 28, 26, function()
    db.profile.inactiveAfterMonths = math.max(1, db.profile.inactiveAfterMonths - 1)
    updateInactiveMonthsLabel()
    refreshViews()
  end)
  monthsDecrease:SetPoint("LEFT", inactiveMonthsLabel, "RIGHT", 12, 0)
  local monthsIncrease = makeButton(basicsPage, "+", 28, 26, function()
    db.profile.inactiveAfterMonths = math.min(24, db.profile.inactiveAfterMonths + 1)
    updateInactiveMonthsLabel()
    refreshViews()
  end)
  monthsIncrease:SetPoint("LEFT", monthsDecrease, "RIGHT", 4, 0)

  local epgpRulesSourceLabel = makeText(epgpPage, "Источник правил:", "GameFontNormal")
  epgpRulesSourceLabel:SetPoint("TOPLEFT", epgpPage, "TOPLEFT", 22, -18)
  epgpRulesSourceLabel:SetTextColor(0.78, 0.88, 0.92)
  local guildRulesSourceButton = makeButton(epgpPage, "Описание гильдии", 154, 26, function()
    db.profile.epgpRulesSource = "guild"
    refreshEPGPRuleSourceControls()
    refreshViews()
  end)
  guildRulesSourceButton:SetPoint("LEFT", epgpRulesSourceLabel, "RIGHT", 10, 0)
  local localRulesSourceButton = makeButton(epgpPage, "Настройки ниже", 142, 26, function()
    db.profile.epgpRulesSource = "local"
    refreshEPGPRuleSourceControls()
    refreshViews()
  end)
  localRulesSourceButton:SetPoint("LEFT", guildRulesSourceButton, "RIGHT", 6, 0)
  local epgpRulesSourceHint = makeText(epgpPage, "", "GameFontDisableSmall")
  epgpRulesSourceHint:SetPoint("LEFT", localRulesSourceButton, "RIGHT", 12, 0)
  epgpRulesSourceHint:SetPoint("RIGHT", epgpPage, "RIGHT", -16, 0)
  epgpRulesSourceHint:SetJustifyH("LEFT")

  local anomalyThresholdLabel = makeText(epgpPage, "Процент среза EP/GP, %", "GameFontNormalSmall")
  anomalyThresholdLabel:SetPoint("TOPLEFT", epgpPage, "TOPLEFT", 22, -82)
  local anomalyThresholdEdit = makeSmallEditBox(epgpPage, 48, 3)
  anomalyThresholdEdit:SetPoint("LEFT", anomalyThresholdLabel, "RIGHT", 8, 0)
  anomalyThresholdEdit:SetText(tostring(math.max(1, math.min(99, tonumber(db.profile.anomalyThreshold) or 20))))
  local anomalyThresholdHint = makeText(epgpPage, "Порог аномального среза +1%", "GameFontDisableSmall")
  anomalyThresholdHint:SetPoint("TOPLEFT", anomalyThresholdLabel, "BOTTOMLEFT", 0, -6)
  local function saveAnomalyThreshold()
    if db.profile.epgpRulesSource ~= "local" then
      return
    end
    local threshold = tonumber(anomalyThresholdEdit:GetText())
    if not threshold or threshold < 1 or threshold > 99 then
      setStatus("Процент среза должен быть от 1 до 99%.")
      return
    end
    db.profile.anomalyThreshold = math.floor(threshold)
    anomalyThresholdEdit:SetText(tostring(db.profile.anomalyThreshold))
    refreshViews()
  end
  local applyAnomalyThreshold = makeButton(epgpPage, "Применить", 92, 24, saveAnomalyThreshold)
  applyAnomalyThreshold:SetPoint("LEFT", anomalyThresholdEdit, "RIGHT", 8, 0)
  anomalyThresholdEdit:SetScript("OnEnterPressed", function(self)
    saveAnomalyThreshold()
    self:ClearFocus()
  end)
  anomalyThresholdEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

  local minGPSliceLabel = makeText(epgpPage, "Минимум GP для EP-среза", "GameFontNormalSmall")
  minGPSliceLabel:SetPoint("TOPLEFT", anomalyThresholdHint, "BOTTOMLEFT", 0, -10)
  local minGPSliceEdit = makeSmallEditBox(epgpPage, 64, 10)
  minGPSliceEdit:SetPoint("LEFT", minGPSliceLabel, "RIGHT", 8, 0)
  minGPSliceEdit:SetText(tostring(math.max(0, tonumber(db.profile.minGPSlice) or 1000)))
  local minGPSliceHint = makeText(epgpPage,
    "Розовая метка: падение EP в пределах ±0,5 п.п. от порога при указанном GP.", "GameFontDisableSmall")
  minGPSliceHint:SetPoint("TOPLEFT", minGPSliceLabel, "BOTTOMLEFT", 0, -6)
  local function saveMinGPSlice()
    if db.profile.epgpRulesSource ~= "local" then
      return
    end
    local minimumGP = tonumber(minGPSliceEdit:GetText())
    if not minimumGP or minimumGP < 0 then
      setStatus("Минимум GP для EP-среза должен быть неотрицательным числом.")
      return
    end
    db.profile.minGPSlice = math.floor(minimumGP)
    minGPSliceEdit:SetText(tostring(db.profile.minGPSlice))
    refreshViews()
  end
  local applyMinGPSlice = makeButton(epgpPage, "Применить", 92, 24, saveMinGPSlice)
  applyMinGPSlice:SetPoint("LEFT", minGPSliceEdit, "RIGHT", 8, 0)
  minGPSliceEdit:SetScript("OnEnterPressed", function(self)
    saveMinGPSlice()
    self:ClearFocus()
  end)
  minGPSliceEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  refreshEPGPRuleSourceControls = function()
    local useGuildDescription = db.profile.epgpRulesSource ~= "local"
    if useGuildDescription then
      db.profile.epgpRulesSource = "guild"
    end
    local guildRules, guildRulesError = getGuildEPGPRuleSettings()
    if useGuildDescription and guildRules then
      anomalyThresholdEdit:SetText(tostring(guildRules.anomalyThreshold))
      minGPSliceEdit:SetText(tostring(guildRules.minGPSlice))
      epgpRulesSourceHint:SetText(
        "Из описания: @DECAY_P — процент среза, @BASE_GP — минимум GP. Названия категорий лута задаются ниже отдельно.")
      epgpRulesSourceHint:SetTextColor(0.62, 0.67, 0.70)
    elseif useGuildDescription then
      anomalyThresholdEdit:SetText(tostring(db.profile.anomalyThreshold))
      minGPSliceEdit:SetText(tostring(db.profile.minGPSlice))
      epgpRulesSourceHint:SetText((guildRulesError or "Описание гильдии недоступно.") ..
        " Пока используются локальные значения из настроек ниже.")
      epgpRulesSourceHint:SetTextColor(1, 0.55, 0.45)
    else
      anomalyThresholdEdit:SetText(tostring(db.profile.anomalyThreshold))
      minGPSliceEdit:SetText(tostring(db.profile.minGPSlice))
      epgpRulesSourceHint:SetText(
        "Используются значения ниже. Названия категорий лута также хранятся в настройках BearyWatch.")
      epgpRulesSourceHint:SetTextColor(0.62, 0.67, 0.70)
    end
    for _, edit in ipairs({ anomalyThresholdEdit, minGPSliceEdit }) do
      edit:EnableMouse(not useGuildDescription)
      edit:SetAlpha(useGuildDescription and 0.65 or 1)
      if useGuildDescription then
        edit:ClearFocus()
      end
    end
    for _, button in ipairs({ applyAnomalyThreshold, applyMinGPSlice }) do
      if useGuildDescription then button:Disable() else button:Enable() end
    end
    local guildSelected = useGuildDescription
    guildRulesSourceButton.background:SetVertexColor(
      guildSelected and COLORS.EP[1] or 0.12,
      guildSelected and COLORS.EP[2] or 0.15,
      guildSelected and COLORS.EP[3] or 0.18,
      guildSelected and 0.55 or 1)
    guildRulesSourceButton.isActive = guildSelected
    guildRulesSourceButton.activeColor = COLORS.EP
    local localSelected = not guildSelected
    localRulesSourceButton.background:SetVertexColor(
      localSelected and COLORS.EP[1] or 0.12,
      localSelected and COLORS.EP[2] or 0.15,
      localSelected and COLORS.EP[3] or 0.18,
      localSelected and 0.55 or 1)
    localRulesSourceButton.isActive = localSelected
    localRulesSourceButton.activeColor = COLORS.EP
  end
  refreshEPGPRuleSourceControls()

  local sourceLabel = makeText(guildPage, "Источник GP:", "GameFontNormal")
  sourceLabel:SetPoint("TOPLEFT", guildPage, "TOPLEFT", 22, -18)
  sourceLabel:SetTextColor(0.78, 0.88, 0.92)
  local guildRulesToggle
  guildRulesToggle = makeButton(guildPage, "", 132, 24, function()
    db.profile.guildPricing.useGuildRules = not db.profile.guildPricing.useGuildRules
    guildRulesToggle.label:SetText(db.profile.guildPricing.useGuildRules and
      "Гильдия" or "EPGP")
    refreshViews()
  end)
  guildRulesToggle:SetPoint("LEFT", sourceLabel, "RIGHT", 8, 0)
  guildRulesToggle.label:SetText(db.profile.guildPricing.useGuildRules and
    "Гильдия" or "EPGP")
  local priceDateLabel = makeText(guildPage, "Цены гильдии действуют с:", "GameFontNormalSmall")
  priceDateLabel:SetPoint("TOPLEFT", guildPage, "TOPLEFT", 22, -54)
  local priceDateEdit = makeDateEditBox(guildPage)
  priceDateEdit:SetWidth(82)
  priceDateEdit:SetPoint("LEFT", priceDateLabel, "RIGHT", 8, 0)
  priceDateEdit:SetText(db.profile.guildPricing.priceEffectiveDate or DEFAULT_GUILD_PRICE_EFFECTIVE_DATE)
  local function saveGuildPriceEffectiveDate()
    local value = priceDateEdit:GetText()
    local timestamp = parseDateInput(value, false)
    if not timestamp then
      setStatus("Укажите дату начала действия цен в формате ГГГГ-ММ-ДД.")
      return
    end
    value = date("%Y-%m-%d", timestamp)
    priceDateEdit:SetText(value)
    db.profile.guildPricing.priceEffectiveDate = value
    refreshViews()
    setStatus(("Дата начала действия текущих цен: %s."):format(value))
  end
  local applyPriceDate = makeButton(guildPage, "Применить", 80, 24, saveGuildPriceEffectiveDate)
  applyPriceDate:SetPoint("LEFT", priceDateEdit, "RIGHT", 4, 0)
  priceDateEdit:SetScript("OnEnterPressed", function(self)
    saveGuildPriceEffectiveDate()
    self:ClearFocus()
  end)
  priceDateEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  local categoryHint = makeText(guildPage, "", "GameFontNormalSmall")
  categoryHint:SetPoint("TOPLEFT", guildPage, "TOPLEFT", 22, -86)
  categoryHint:SetTextColor(0.68, 0.73, 0.76)
  local function updateCategoryHint()
    local names = db.profile.guildPricing.categoryNames or {}
    local multipliers = db.profile.guildPricing.categoryMultipliers or {}
    categoryHint:SetText(("Оценка: %s %.0f%% | %s %.0f%% | %s %.0f%% | %s %.0f%%."):format(
      names.main or "Main", (multipliers.main or 1) * 100,
      names.minor or "Minor", (multipliers.minor or 0.5) * 100,
      names.offTwin or "Off Twin", (multipliers.offTwin or 0.25) * 100,
      names.roll or "Roll / Trans", (multipliers.roll or 0) * 100))
  end
  updateCategoryHint()

  local settingsDivider = makeFlatTexture(guildPage, "ARTWORK", 0.19, 0.24, 0.27, 1)
  settingsDivider:SetWidth(1)
  settingsDivider:SetPoint("TOPLEFT", guildPage, "TOPLEFT", 550, -10)
  settingsDivider:SetPoint("BOTTOMLEFT", guildPage, "BOTTOMLEFT", 550, 10)

  local ilvlSectionTitle = makeText(guildPage, "Цены по уровню предмета", "GameFontNormal")
  ilvlSectionTitle:SetPoint("TOPLEFT", guildPage, "TOPLEFT", 22, -112)
  ilvlSectionTitle:SetTextColor(0.78, 0.88, 0.92)
  local ilvlLabel = makeText(guildPage, "", "GameFontNormalSmall")
  ilvlLabel:SetPoint("TOPLEFT", guildPage, "TOPLEFT", 22, -136)
  ilvlLabel:SetWidth(52)
  ilvlLabel:SetJustifyH("CENTER")
  ilvlLabel:SetText("Уровень")
  local defaultPriceLabel = makeText(guildPage, "", "GameFontNormalSmall")
  defaultPriceLabel:SetPoint("TOPLEFT", guildPage, "TOPLEFT", 94, -136)
  defaultPriceLabel:SetWidth(64)
  defaultPriceLabel:SetJustifyH("CENTER")
  defaultPriceLabel:SetText("Обычное GP")
  local twoHandPriceLabel = makeText(guildPage, "", "GameFontNormalSmall")
  twoHandPriceLabel:SetPoint("TOPLEFT", guildPage, "TOPLEFT", 176, -136)
  twoHandPriceLabel:SetWidth(78)
  twoHandPriceLabel:SetJustifyH("CENTER")
  twoHandPriceLabel:SetText("2 Hand GP")

  local _, refreshCategoryNameControls = createCategoryNameControls(
    epgpPage, minGPSliceHint, updateCategoryHint)

  local ilvlEdit = makeSmallEditBox(guildPage, 52, 4)
  ilvlEdit:SetPoint("TOPLEFT", guildPage, "TOPLEFT", 22, -154)
  local normalPriceEdit = makeSmallEditBox(guildPage, 64, 8)
  normalPriceEdit:SetPoint("TOPLEFT", guildPage, "TOPLEFT", 94, -154)
  local twoHandPriceEdit = makeSmallEditBox(guildPage, 78, 8)
  twoHandPriceEdit:SetPoint("TOPLEFT", guildPage, "TOPLEFT", 176, -154)
  local saveIlvlRule = makeButton(guildPage, "Сохранить ilvl", 112, 24, function()
    local level = tonumber(ilvlEdit:GetText())
    local normalPrice = tonumber(normalPriceEdit:GetText())
    local twoHandPrice = tonumber(twoHandPriceEdit:GetText())
    if not level or level < 1 or not normalPrice or not twoHandPrice then
      setStatus("Укажите ilvl и обе цены GP для правила.")
      return
    end
    db.profile.guildPricing.ilvlRules[level] = {
      default = normalPrice,
      twoHand = twoHandPrice,
    }
    refreshPricingRuleLists()
    refreshViews()
  end)
  saveIlvlRule:SetPoint("LEFT", twoHandPriceEdit, "RIGHT", 8, 0)

  local ilvlRuleScroll = CreateFrame("ScrollFrame", nil, guildPage)
  ilvlRuleScroll:SetPoint("TOPLEFT", guildPage, "TOPLEFT", 20, -190)
  ilvlRuleScroll:SetSize(500, 250)
  ilvlRuleScroll:EnableMouseWheel(true)
  local ilvlRuleContent = CreateFrame("Frame", nil, ilvlRuleScroll)
  ilvlRuleContent:SetSize(500, 1)
  ilvlRuleScroll:SetScrollChild(ilvlRuleContent)
  local ilvlRuleRows = {}
  ilvlRuleScroll:SetScript("OnMouseWheel", function(self, delta)
    local maximum = math.max(ilvlRuleContent:GetHeight() - self:GetHeight(), 0)
    self:SetVerticalScroll(math.max(0, math.min(maximum, self:GetVerticalScroll() - delta * 30)))
  end)

  local itemRuleTitle = makeText(guildPage, "Исключения и цены по ID предмета", "GameFontNormal")
  itemRuleTitle:SetPoint("TOPLEFT", guildPage, "TOPLEFT", 574, -18)
  itemRuleTitle:SetTextColor(0.78, 0.88, 0.92)
  local itemRuleHint = makeText(guildPage, "Выберите строку для редактирования.", "GameFontNormalSmall")
  itemRuleHint:SetPoint("TOPLEFT", itemRuleTitle, "BOTTOMLEFT", 0, -5)
  itemRuleHint:SetTextColor(0.62, 0.67, 0.70)
  local itemIdLabel = makeText(guildPage, "ID предмета", "GameFontNormalSmall")
  itemIdLabel:SetPoint("TOPLEFT", guildPage, "TOPLEFT", 574, -57)
  itemIdLabel:SetWidth(88)
  itemIdLabel:SetJustifyH("CENTER")
  local itemPriceLabel = makeText(guildPage, "Цена GP", "GameFontNormalSmall")
  itemPriceLabel:SetPoint("TOPLEFT", guildPage, "TOPLEFT", 670, -57)
  itemPriceLabel:SetWidth(80)
  itemPriceLabel:SetJustifyH("CENTER")
  local itemIdEdit = makeSmallEditBox(guildPage, 88, 10)
  itemIdEdit:SetPoint("TOPLEFT", guildPage, "TOPLEFT", 574, -75)
  local itemPriceEdit = makeSmallEditBox(guildPage, 80, 8)
  itemPriceEdit:SetPoint("TOPLEFT", guildPage, "TOPLEFT", 670, -75)
  local saveItemRule = makeButton(guildPage, "Добавить / изменить", 132, 24, function()
    local itemId = tonumber(itemIdEdit:GetText())
    local price = tonumber(itemPriceEdit:GetText())
    if not itemId or itemId < 1 or price == nil then
      setStatus("Укажите корректные ID предмета и цену GP (можно 0).")
      return
    end
    db.profile.guildPricing.itemPrices[itemId] = price
    refreshPricingRuleLists()
    refreshViews()
  end)
  saveItemRule:SetPoint("LEFT", itemPriceEdit, "RIGHT", 8, 0)
  local removeItemRule = makeButton(guildPage, "Удалить", 72, 24, function()
    local itemId = tonumber(itemIdEdit:GetText())
    if not itemId or db.profile.guildPricing.itemPrices[itemId] == nil then
      setStatus("Выберите правило по ID для удаления.")
      return
    end
    db.profile.guildPricing.itemPrices[itemId] = false
    itemPriceEdit:SetText("")
    refreshPricingRuleLists()
    refreshViews()
  end)
  removeItemRule:SetPoint("LEFT", saveItemRule, "RIGHT", 4, 0)

  local itemRuleScroll = CreateFrame("ScrollFrame", nil, guildPage)
  itemRuleScroll:SetPoint("TOPLEFT", guildPage, "TOPLEFT", 572, -110)
  itemRuleScroll:SetPoint("BOTTOMRIGHT", guildPage, "BOTTOMRIGHT", -12, 12)
  itemRuleScroll:EnableMouseWheel(true)
  local itemRuleContent = CreateFrame("Frame", nil, itemRuleScroll)
  itemRuleContent:SetSize(520, 1)
  itemRuleScroll:SetScrollChild(itemRuleContent)
  local itemRuleRows = {}
  itemRuleScroll:SetScript("OnMouseWheel", function(self, delta)
    local maximum = math.max(itemRuleContent:GetHeight() - self:GetHeight(), 0)
    self:SetVerticalScroll(math.max(0, math.min(maximum, self:GetVerticalScroll() - delta * 30)))
  end)

  refreshPricingRuleLists = function()
    local levels = {}
    for level, rule in pairs(db.profile.guildPricing.ilvlRules) do
      if type(level) == "number" and type(rule) == "table" then
        table.insert(levels, level)
      end
    end
    table.sort(levels)
    ilvlRuleContent:SetHeight(math.max(#levels * 22, 1))
    for index, level in ipairs(levels) do
      if not ilvlRuleRows[index] then
        ilvlRuleRows[index] = makeButton(ilvlRuleContent, "", 410, 22, function(self)
          local rule = db.profile.guildPricing.ilvlRules[self.itemLevel]
          ilvlEdit:SetText(tostring(self.itemLevel))
          normalPriceEdit:SetText(tostring(rule.default or 0))
          twoHandPriceEdit:SetText(tostring(rule.twoHand or rule.default or 0))
        end)
        ilvlRuleRows[index]:SetPoint("TOPLEFT", ilvlRuleContent, "TOPLEFT", 0, -(index - 1) * 22)
        ilvlRuleRows[index]:SetPoint("TOPRIGHT", ilvlRuleContent, "TOPRIGHT", 0, -(index - 1) * 22)
      end
      local row, rule = ilvlRuleRows[index], db.profile.guildPricing.ilvlRules[level]
      row.itemLevel = level
      row.label:SetText(("ilvl %d | обычное %d GP | 2H %d GP"):format(
        level, rule.default or 0, rule.twoHand or rule.default or 0))
      row:Show()
    end
    for index = #levels + 1, #ilvlRuleRows do
      ilvlRuleRows[index]:Hide()
    end

    local itemIds = {}
    for itemId, price in pairs(db.profile.guildPricing.itemPrices) do
      if type(itemId) == "number" and type(price) == "number" then
        table.insert(itemIds, itemId)
      end
    end
    table.sort(itemIds)
    itemRuleContent:SetHeight(math.max(#itemIds * 30, 1))
    for index, itemId in ipairs(itemIds) do
      if not itemRuleRows[index] then
        itemRuleRows[index] = makeButton(itemRuleContent, "", 410, 22, function(self)
          itemIdEdit:SetText(tostring(self.itemId))
          itemPriceEdit:SetText(tostring(db.profile.guildPricing.itemPrices[self.itemId] or 0))
        end)
        itemRuleRows[index]:SetHeight(30)
        itemRuleRows[index]:SetPoint("TOPLEFT", itemRuleContent, "TOPLEFT", 0, -(index - 1) * 30)
        itemRuleRows[index]:SetPoint("TOPRIGHT", itemRuleContent, "TOPRIGHT", 0, -(index - 1) * 30)
        itemRuleRows[index].icon = itemRuleRows[index]:CreateTexture(nil, "ARTWORK")
        itemRuleRows[index].icon:SetSize(24, 24)
        itemRuleRows[index].icon:SetPoint("LEFT", itemRuleRows[index], "LEFT", 3, 0)
        itemRuleRows[index].label:ClearAllPoints()
        itemRuleRows[index].label:SetPoint("LEFT", itemRuleRows[index].icon, "RIGHT", 6, 0)
        itemRuleRows[index].label:SetPoint("RIGHT", itemRuleRows[index], "RIGHT", -4, 0)
        itemRuleRows[index].label:SetJustifyH("LEFT")
        itemRuleRows[index]:SetScript("OnEnter", function(self)
          self.background:SetVertexColor(0.20, 0.29, 0.35, 1)
          GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
          if self.itemLoaded then
            GameTooltip:SetHyperlink(self.itemLink or ("item:" .. self.itemId))
          else
            GameTooltip:AddLine(self.itemName or "Предмет")
            GameTooltip:AddLine("ID " .. tostring(self.itemId), 0.68, 0.72, 0.75)
            GameTooltip:Show()
            requestItemInfo(self.itemId)
          end
        end)
        itemRuleRows[index]:SetScript("OnLeave", function(self)
          GameTooltip_Hide()
          self.background:SetVertexColor(0.12, 0.15, 0.18, 1)
        end)
      end
      local row = itemRuleRows[index]
      row.itemId = itemId
      local itemName, itemLink, quality, _, _, _, _, _, _, itemIcon
      if GetItemInfo then
        itemName, itemLink, quality, _, _, _, _, _, _, itemIcon = GetItemInfo(itemId)
      end
      if not itemName then
        requestItemInfo(itemId)
      end
      row.itemLoaded = itemName ~= nil
      row.itemName = itemName or ("Предмет " .. itemId)
      row.itemLink = itemLink or ("item:" .. itemId)
      row.icon:SetTexture(itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
      row.label:SetText(("%s (ID %d) — %d GP"):format(
        row.itemName, itemId, db.profile.guildPricing.itemPrices[itemId]))
      if quality and GetItemQualityColor then
        local red, green, blue = GetItemQualityColor(quality)
        row.label:SetTextColor(red or 0.88, green or 0.91, blue or 0.94)
      else
        row.label:SetTextColor(0.88, 0.91, 0.94)
      end
      row:Show()
    end
    for index = #itemIds + 1, #itemRuleRows do
      itemRuleRows[index]:Hide()
    end
  end
  refreshPricingRuleLists()
  local exchangeTitle = makeText(exchangePage, "Настройки аддона", "GameFontNormal")
  exchangeTitle:SetPoint("TOPLEFT", exchangePage, "TOPLEFT", 18, -16)
  exchangeTitle:SetTextColor(0.78, 0.88, 0.92)
  local exchangeHint = makeText(exchangePage,
    "Экспортируйте настройки в текст, чтобы сохранить их или перенести на другого персонажа.",
    "GameFontNormalSmall")
  exchangeHint:SetPoint("TOPLEFT", exchangeTitle, "BOTTOMLEFT", 0, -6)
  exchangeHint:SetTextColor(0.62, 0.67, 0.70)
  local settingsEdit = CreateFrame("EditBox", nil, exchangePage)
  settingsEdit:SetMultiLine(true)
  settingsEdit:SetAutoFocus(false)
  settingsEdit:SetMaxLetters(30000)
  settingsEdit:SetFontObject(ChatFontNormal)
  settingsEdit:SetTextInsets(4, 4, 4, 4)
  settingsEdit:SetTextColor(0.82, 0.90, 0.96)
  settingsEdit:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  settingsEdit:SetBackdropColor(0.035, 0.07, 0.10, 1)
  settingsEdit:SetBackdropBorderColor(0.18, 0.34, 0.42, 1)
  settingsEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  local settingsScroll = CreateFrame("ScrollFrame", nil, exchangePage)
  settingsScroll:SetPoint("TOPLEFT", exchangeHint, "BOTTOMLEFT", 0, -8)
  settingsScroll:SetPoint("RIGHT", exchangePage, "RIGHT", -14, 0)
  settingsScroll:SetHeight(142)
  settingsScroll:EnableMouseWheel(true)
  settingsEdit:SetPoint("TOPLEFT", settingsScroll, "TOPLEFT")
  settingsEdit:SetWidth(1000)
  settingsEdit:SetHeight(360)
  settingsScroll:SetScrollChild(settingsEdit)
  settingsScroll:SetScript("OnMouseWheel", function(self, delta)
    local maximum = math.max(settingsEdit:GetHeight() - self:GetHeight(), 0)
    self:SetVerticalScroll(math.max(0, math.min(maximum, self:GetVerticalScroll() - delta * 24)))
  end)
  local exportSettings = makeButton(exchangePage, "Экспорт настроек", 148, 24, function()
    settingsEdit:SetText(serializeAddonSettings(db.profile, db.char.epgpJournalProfile))
    settingsEdit:SetCursorPosition(0)
    settingsEdit:SetFocus()
    setStatus("Настройки подготовлены к экспорту.")
  end)
  exportSettings:SetPoint("TOPLEFT", settingsScroll, "BOTTOMLEFT", 0, -8)
  local importSettings = makeButton(exchangePage, "Импорт настроек", 148, 24, function()
    local imported, err = parseAddonSettings(settingsEdit:GetText())
    if not imported then
      setStatus(err)
      return
    end
    applyAddonSettings(db.profile, db.char, imported)
    if minimapButton then
      if db.profile.minimap.hide then minimapButton:Hide() else minimapButton:Show() end
    end
    updateAddonLootFilterToggle()
    minimapToggle.label:SetText(db.profile.minimap.hide and
      "Показывать кнопку миникарты: нет" or "Показывать кнопку миникарты: да")
    inactiveToggle.label:SetText(db.profile.hideInactivePlayers and
      "Скрывать неактивных: да" or "Скрывать неактивных: нет")
    updateInactiveMonthsLabel()
    refreshEPGPRuleSourceControls()
    priceDateEdit:SetText(db.profile.guildPricing.priceEffectiveDate or DEFAULT_GUILD_PRICE_EFFECTIVE_DATE)
    guildRulesToggle.label:SetText(db.profile.guildPricing.useGuildRules and
      "Источник GP: гильдия" or "Источник GP: EPGP")
    refreshCategoryNameControls()
    updateCategoryHint()
    refreshPricingRuleLists()
    updateJournalSourceDropdown()
    refreshViews()
    setStatus("Настройки импортированы.")
  end)
  importSettings:SetPoint("LEFT", exportSettings, "RIGHT", 6, 0)
  local rulesExchangeTitle = makeText(exchangePage, "Импорт и экспорт только правил GP", "GameFontNormal")
  rulesExchangeTitle:SetPoint("TOPLEFT", exportSettings, "BOTTOMLEFT", 0, -28)
  rulesExchangeTitle:SetTextColor(0.78, 0.88, 0.92)

  createLootRulesExchangeControls(exchangePage, rulesExchangeTitle, function()
    priceDateEdit:SetText(db.profile.guildPricing.priceEffectiveDate or DEFAULT_GUILD_PRICE_EFFECTIVE_DATE)
    guildRulesToggle.label:SetText(db.profile.guildPricing.useGuildRules and
      "Источник GP: гильдия" or "Источник GP: EPGP")
    refreshCategoryNameControls()
    updateCategoryHint()
    refreshPricingRuleLists()
    refreshViews()
  end)
  if EPGP and EPGP.RegisterCallback then
    local epgpRulesListener = {}
    function epgpRulesListener:OnGuildRulesChanged()
      invalidateGuildEPGPRuleSettingsCache()
      if refreshEPGPRuleSourceControls then
        refreshEPGPRuleSourceControls()
      end
      if db.profile.epgpRulesSource == "guild" then
        refreshViews()
      end
    end
    EPGP.RegisterCallback(epgpRulesListener, "DecayPercentChanged", "OnGuildRulesChanged")
    EPGP.RegisterCallback(epgpRulesListener, "BaseGPChanged", "OnGuildRulesChanged")
  end
end
