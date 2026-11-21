local addon = _G.BearyWatch
if type(addon) ~= "table" or type(addon.environment) ~= "table" then
  error("BearyWatch shared environment was not initialized.")
end
setfenv(1, addon.environment)
DEFAULT_GUILD_PRICE_EFFECTIVE_DATE = "2026-11-06"

DEFAULT_LOOT_RULES = type(BearyWatchLootRules) == "table" and BearyWatchLootRules or {
  useGuildRules = true,
  priceEffectiveDate = DEFAULT_GUILD_PRICE_EFFECTIVE_DATE,
  ilvlRules = {
    [290] = { default = 300, twoHand = 300 },
    [297] = { default = 500, twoHand = 700 },
    [303] = { default = 700, twoHand = 1000 },
    [310] = { default = 1000, twoHand = 1500 },
  },
  itemPrices = {
    [280009] = 300,
    [31092] = 500,
    [31097] = 500,
    [31101] = 500,
    [31098] = 1000,
    [31089] = 1000,
    [156268] = 1500,
    [156223] = 1000,
    [151378] = 700,
    [139048] = 700,
    [139049] = 700,
    [139050] = 700,
    [156176] = 1000,
    [156196] = 1000,
    [156212] = 1000,
    [156178] = 1500,
  },
  categoryMultipliers = {
    main = 1,
    minor = 0.5,
    offTwin = 0.25,
    roll = 0,
  },
  categoryNames = {
    main = "Main",
    minor = "Minor",
    offTwin = "Off Twin",
    roll = "Roll / Trans",
  },
}

DEFAULTS = {
  profile = {
    selectedTab = "timeline",
    analyticsTab = "timeline",
    settingsSection = "basics",
    epgpRulesSource = "guild",
    grouping = "main",
    useAddonLootFilter = true,
    timelinePlayers = {},
    hideInactivePlayers = false,
    inactiveAfterMonths = 3,
    attendancePeriodDays = 7,
    anomalyThreshold = 20,
    minGPSlice = 1000,
    rangeStart = 0,
    rangeEnd = 0,
    rangePadding = 0,
    dropLineValuePan = 0,
    dropLineValueZoom = 1,
    valuePan = {
      EP = 0,
      GP = 0,
      PR = 0,
      RANK = 0,
    },
    valueZoom = {
      EP = 1,
      GP = 1,
      PR = 1,
      RANK = 1,
    },
    classFilters = {
      WARRIOR = true,
      PALADIN = true,
      HUNTER = true,
      ROGUE = true,
      PRIEST = true,
      DEATHKNIGHT = true,
      SHAMAN = true,
      MAGE = true,
      WARLOCK = true,
      DRUID = true,
    },
    guildPricing = {
      useGuildRules = DEFAULT_LOOT_RULES.useGuildRules,
      priceEffectiveDate = DEFAULT_LOOT_RULES.priceEffectiveDate or DEFAULT_GUILD_PRICE_EFFECTIVE_DATE,
      ilvlRules = DEFAULT_LOOT_RULES.ilvlRules,
      itemPrices = DEFAULT_LOOT_RULES.itemPrices,
      categoryMultipliers = DEFAULT_LOOT_RULES.categoryMultipliers,
      categoryNames = DEFAULT_LOOT_RULES.categoryNames,
    },
    minimap = {
      hide = false,
      angle = 45,
    },
  },
  char = {
    bossLoot = {
      excludedItems = {},
    },
  },
}

db = nil
activeTab = nil
history = {}
historyStatus = ""
historyRefreshPending = true
classRosterRefreshPending = true
groupedPlayers = {}
playerLastUpdate = {}
historyByPlayer = {}
selectedPlayer = nil
selectedPlayers = {}
restoreSavedPlayerSelection = false
rangeBar = nil
rangeThumb = nil
rangeFromEdit = nil
rangeToEdit = nil
playerSearch = nil
rangeDrag = nil
rangeDragElapsed = 0
chartPan = nil
chartPanElapsed = 0
graphValueRange = 1
graphValueCenter = 0
graphBaseValueCenter = 0
graphValueMinimum = 0
graphValueMaximum = 1
graphPlotHeight = 1
drawChart = nil
updateRangeControls = nil
updateRangeBar = nil
selectedMetric = "EP"
sortColumn = "efficiency"
sortDescending = false
window = nil
timelinePanel = nil
rankListPanel = nil
rankListTitle = nil
rankListDate = nil
rankListContent = nil
rankListRows = {}
efficiencyPanel = nil
itemPanel = nil
settingsPanel = nil
attendancePeriodButtons = {}
attendanceSourceText = nil
efficiencyHeaderButtons = {}
journalSourceDropdown = nil
journalSourceMenu = nil
journalSourceScroll = nil
journalSourceContent = nil
journalSourceRows = {}
updateJournalSourceDropdown = nil
refreshPricingRuleLists = nil
refreshEPGPRuleSourceControls = nil
statusText = nil
hiddenCountText = nil
currentBalanceText = nil
chart = nil
graphScaleText = nil
playerDropdown = nil
playerDropdownMenu = nil
playerDropdownScroll = nil
playerDropdownContent = nil
playerDropdownRows = {}
playerSearchHint = nil
efficiencyContent = nil
efficiencyScroll = nil
minimapButton = nil
graphLines = {}
graphNodes = {}
graphNodeCount = 0
graphLineCount = 0
graphDomainStart = nil
graphDomainEnd = nil
graphBaseValueRange = 1
gridLines = {}
verticalGridLines = {}
yLabels = {}
xLabels = {}
metricButtons = {}
tabButtons = {}
analyticsSubtabButtons = {}
classFilterButton = nil
classFilterMenu = nil
classFilterRows = {}
efficiencyRows = {}
efficiencyData = {}
itemSortColumn = "timestamp"
itemSortDescending = true
itemDropdown = nil
itemDropdownMenu = nil
itemDropdownScroll = nil
itemDropdownContent = nil
itemDropdownRows = {}
itemSearch = nil
itemSearchHint = nil
itemMedianText = nil
itemListingScroll = nil
itemListingContent = nil
itemListingRows = {}
selectedItemId = nil
bossLoot = {
  mode = false,
  isRaid = true,
  tier = 1,
  dropdowns = {},
  rows = {},
  scroll = nil,
  content = nil,
  competitorScroll = nil,
  competitorContent = nil,
  headerButtons = {},
  excludedItems = {},
  view = "loot",
  inspections = {},
  inspectQueue = {},
  expandedCompetitorGroups = {},
  competitorScope = "auto",
  classLootCache = nil,
  classLootCacheKey = nil,
  classIdByToken = {
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
    DEATHKNIGHT = 6, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11,
  },
  officerNotes = {},
  rosterNames = {},
  guildMembers = {},
}
function bossLoot.parseOfficerNote(note)
  if type(note) ~= "string" then
    return nil
  end
  local ep, epExtra, gp, gpExtra =
    note:match("^%s*(%d+)([^,]*)%s*,%s*(%d+)(.*)$")
  if not ep then
    return nil
  end
  local extra = (epExtra .. gpExtra):match("^%s*(.-)%s*$")
  return {
    ep = tonumber(ep),
    gp = tonumber(gp),
    status = extra ~= "" and "Фриз" or nil,
  }
end

function bossLoot.isNumericOfficerNote(note)
  local trimmed = type(note) == "string" and note:match("^%s*(.-)%s*$")
  return type(trimmed) == "string" and
    (bossLoot.parseOfficerNote(trimmed) ~= nil or trimmed:match("^%d+$") ~= nil)
end

medianGPByItem = {}
cachedItems = {}
cachedItemIcons = {}
requestedItemIcons = {}
getTooltipItemIcon = nil
getTooltipItemLabel = nil
classTokenByPlayer = {}
itemLoaderTooltip = nil
getStandardGP = nil
getGuildGP = nil
getGuildPriceEffectiveTimestamp = nil
inferLootCategory = nil
getGuildPriceAnomaly = nil
renderEfficiency = nil
playerClassColor = nil
rankClassIsIncluded = nil
updateRankLayout = nil
makeText = nil
refreshViews = nil
createEfficiencyUI = nil
createItemAnalysisUI = nil
createSettingsUI = nil
renderItemAnalysis = nil
updateItemDropdown = nil
rankSnapshots = {}
rankBalancesComplete = false
rankPlayerIndexes = {}
currentRankEntries = nil
getRankSnapshotAt = nil
ensureRankSnapshots = nil
rankSnapshotsDirty = true
dropLinePanel = nil
dropLineChart = nil
dropLineNodes = {}
dropLineStems = {}
dropLineZeroLine = nil
dropLineResetLines = {}
dropLineGridLines = {}
dropLineVerticalGridLines = {}
dropLineYLabels = {}
dropLineXLabels = {}
dropLineDateLabels = {}
dropLineSideScroll = nil
dropLineSideContent = nil
dropLineSideRows = {}
dropLineSideDivider = nil
dropLineDomainStart = nil
dropLineDomainEnd = nil
dropLineMaxValue = 1
dropLinePan = nil
dropLinePanElapsed = 0
guildMainByName = {}
rosterWindow = nil
rosterSearch = nil
rosterSortColumn = "pr"
rosterSortDescending = true
rosterContent = nil
rosterScroll = nil
rosterRows = {}
rosterTitle = nil
rosterGuildName = nil
drawDropLineChart = nil
updateRosterWindow = nil

COLORS = {
  EP = { 0.30, 0.72, 1.00 },
  GP = { 1.00, 0.65, 0.24 },
  PR = { 0.48, 0.86, 0.57 },
  RANK = { 0.95, 0.82, 0.36 },
  DECAY = { 1.00, 0.36, 0.72 },
  ANOMALY = { 1.00, 0.20, 0.18 },
  OVERPRICE = { 1.00, 0.88, 0.18 },
}
UNKNOWN_CLASS_COLOR = { r = 0.65, g = 0.65, b = 0.65 }
CLASS_OPTIONS = {
  { token = "WARRIOR", label = "Воин" },
  { token = "PALADIN", label = "Паладин" },
  { token = "HUNTER", label = "Охотник" },
  { token = "ROGUE", label = "Разбойник" },
  { token = "PRIEST", label = "Жрец" },
  { token = "DEATHKNIGHT", label = "Рыцарь смерти" },
  { token = "SHAMAN", label = "Шаман" },
  { token = "MAGE", label = "Маг" },
  { token = "WARLOCK", label = "Чернокнижник" },
  { token = "DRUID", label = "Друид" },
}

ALL_PLAYERS = "Все игроки"
PLAYER_COLORS = {
  { 0.30, 0.72, 1.00 },
  { 1.00, 0.65, 0.24 },
  { 0.48, 0.86, 0.57 },
  { 0.90, 0.43, 0.55 },
  { 0.72, 0.54, 0.92 },
  { 0.28, 0.82, 0.78 },
  { 0.93, 0.80, 0.36 },
  { 0.92, 0.58, 0.82 },
  { 0.62, 0.78, 0.37 },
  { 0.55, 0.65, 0.94 },
  { 0.93, 0.48, 0.34 },
  { 0.48, 0.77, 0.91 },
}
NAMED_GUILD_PRICES = {
  ["Лезвие Акамы"] = 1000,
  ["Боевой клинок Аззинота"] = 1500,
  ["Вечно-горячий уголь Скверны"] = 1500,
  ["Небесная вспышка"] = 700,
  ["Часы ускоренного времени"] = 700,
  ["Компас вневременных путей"] = 700,
  ["Решимость неумирающего"] = 700,
  ["Талисман бесконечной кузни клинков"] = 1000,
  ["Талисман нарастающей волны"] = 1000,
  ["Осколок потустороннего инфернала"] = 1000,
  ["лезвие акамы"] = 1000,
  ["боевой клинок аззинота"] = 1500,
  ["вечно-горячий уголь скверны"] = 1500,
  ["небесная вспышка"] = 700,
  ["часы ускоренного времени"] = 700,
  ["компас вневременных путей"] = 700,
  ["решимость неумирающего"] = 700,
  ["талисман бесконечной кузни клинков"] = 1000,
  ["талисман нарастающей волны"] = 1000,
  ["осколок потустороннего инфернала"] = 1000,
}

function setStatus(text)
  historyStatus = text or ""
  if statusText then
    statusText:SetText(historyStatus)
  end
  if hiddenCountText then
    local count = 0
    if db and db.profile.hideInactivePlayers then
      local inactiveBefore = time() - db.profile.inactiveAfterMonths * 30 * 24 * 60 * 60
      for _, name in ipairs(groupedPlayers) do
        if (playerLastUpdate[name] or 0) < inactiveBefore then
          count = count + 1
        end
      end
    end
    hiddenCountText:SetText(("Скрыто фильтром: %d персонажей"):format(count))
  end
end

function isLogTable(value)
  return type(value) == "table" and (next(value) == nil or type(value[1]) == "table")
end

function logCount(value)
  if not isLogTable(value) then
    return 0
  end
  return #value
end

function getJournalSources()
  local sourcesByKey = {}
  local logModule = EPGP and EPGP.GetModule and EPGP:GetModule("log", true)
  local moduleProfile = logModule and logModule.db and logModule.db.profile
  local savedDB = type(EPGP_DB) == "table" and EPGP_DB or nil
  local activeProfile
  if savedDB and UnitName and GetRealmName then
    local characterKey = UnitName("player") .. " - " .. GetRealmName()
    activeProfile = savedDB.profileKeys and savedDB.profileKeys[characterKey]
  end
  if not activeProfile and logModule and logModule.db and
    type(logModule.db.GetCurrentProfile) == "function" then
    activeProfile = logModule.db:GetCurrentProfile()
  end
  if type(activeProfile) ~= "string" then
    activeProfile = nil
  end

  if savedDB then
    local logNamespace = savedDB.namespaces and savedDB.namespaces.log
    for profileName, profile in pairs(logNamespace and logNamespace.profiles or {}) do
      if type(profileName) == "string" and type(profile) == "table" and
        isLogTable(profile.log) then
        sourcesByKey[profileName] = {
          key = profileName,
          label = profileName,
          log = profile.log,
        }
      end
    end
    for profileName, profile in pairs(savedDB.profiles or {}) do
      if type(profileName) == "string" and type(profile) == "table" and
        isLogTable(profile.log) and not sourcesByKey[profileName] then
        sourcesByKey[profileName] = {
          key = profileName,
          label = profileName,
          log = profile.log,
        }
      end
    end
  end

  if activeProfile and moduleProfile and isLogTable(moduleProfile.log) then
    if sourcesByKey[activeProfile] then
      sourcesByKey[activeProfile].log = moduleProfile.log
    else
      sourcesByKey[activeProfile] = {
        key = activeProfile,
        label = activeProfile,
        log = moduleProfile.log,
      }
    end
  elseif moduleProfile and isLogTable(moduleProfile.log) then
    sourcesByKey["__active__"] = {
      key = "__active__",
      label = "Текущий профиль EPGP",
      log = moduleProfile.log,
      isActive = true,
    }
  end
  if savedDB and isLogTable(savedDB.profile and savedDB.profile.log) then
    local fallbackKey = activeProfile or "__active__"
    if not sourcesByKey[fallbackKey] then
      sourcesByKey[fallbackKey] = {
        key = fallbackKey,
        label = activeProfile or "Текущий профиль EPGP",
        log = savedDB.profile.log,
        isActive = true,
      }
    end
  end

  local sources = {}
  for _, source in pairs(sourcesByKey) do
    source.count = logCount(source.log)
    source.isActive = source.isActive or source.key == activeProfile
    sources[#sources + 1] = source
  end
  table.sort(sources, function(a, b)
    if a.isActive ~= b.isActive then
      return a.isActive
    end
    return a.label:lower() < b.label:lower()
  end)
  return sources, activeProfile
end

function getSavedLog()
  local sources, activeProfile = getJournalSources()
  local selectedProfile = db and db.char and db.char.epgpJournalProfile or activeProfile
  local selectedSource
  for _, source in ipairs(sources) do
    if source.key == selectedProfile then
      selectedSource = source
      break
    end
  end
  if not selectedSource and #sources > 0 then
    for _, source in ipairs(sources) do
      if source.key == activeProfile then
        selectedSource = source
        break
      end
    end
    selectedSource = selectedSource or sources[1]
  end
  if selectedSource and db and db.char then
    db.char.epgpJournalProfile = selectedSource.key
  end
  return selectedSource and selectedSource.log or nil, selectedSource
end

function normalizeReason(reason)
  return type(reason) == "string" and reason or ""
end

function itemIdFromReason(reason)
  local id = normalizeReason(reason):match("item:(%d+)")
  return id and tonumber(id) or nil
end

function readHistory()
  historyRefreshPending = false
  local previousSelection = selectedPlayer
  local previousLatestTimestamp = history[#history] and history[#history].timestamp
  local previousRangeStart = db and db.profile.rangeStart
  local previousRangeEnd = db and db.profile.rangeEnd
  local log, journalSource = getSavedLog()
  local nextHistory = {}
  local seen = {}
  local decayCandidates = {}
  local malformed = 0
  local duplicates = 0
  cachedItems = {}

  if not log then
    history = nextHistory
    rankSnapshotsDirty = true
    groupedPlayers = {}
    playerLastUpdate = {}
    historyByPlayer = {}
    selectedPlayer = nil
    if updateRangeControls then
      updateRangeControls()
    end
    setStatus("Не найден журнал EPGP для выбранного профиля. Выберите другой источник в настройках.")
    return false
  end

  for index, record in ipairs(log) do
    if type(record) == "table" and
      type(record[1]) == "number" and
      (record[2] == "EP" or record[2] == "GP" or record[2] == "BI") and
      type(record[3]) == "string" and
      type(record[4]) == "string" and
      type(record[5]) == "number" then
      local officer = type(record[6]) == "string" and record[6] or "Unknown"
      local key = table.concat({
        tostring(record[1]),
        record[2],
        record[3],
        record[4],
        tostring(record[5]),
        officer,
      }, "\031")
      if seen[key] then
        duplicates = duplicates + 1
      else
        seen[key] = true
        table.insert(nextHistory, {
          timestamp = record[1],
          kind = record[2],
          player = record[3],
          reason = record[4],
          amount = record[5],
          officer = officer,
          sequence = index,
          decay = false,
          itemId = itemIdFromReason(record[4]),
        })
        local event = nextHistory[#nextHistory]
        if event.amount < 0 and (event.kind == "EP" or event.kind == "GP") and event.player ~= "GUILD_BANK" then
          local grouped = addon:GetGroupedName(event.player)
          local key = grouped .. "\031" .. tostring(event.timestamp)
          if not decayCandidates[key] then
            decayCandidates[key] = { EP = {}, GP = {} }
          end
          table.insert(decayCandidates[key][event.kind], event)
        end
      end
    else
      malformed = malformed + 1
    end
  end

  for _, candidates in pairs(decayCandidates) do
    local pairedCount = math.min(#candidates.EP, #candidates.GP)
    for i = 1, pairedCount do
      candidates.EP[i].decay = true
      candidates.GP[i].decay = true
    end
  end

  table.sort(nextHistory, function(a, b)
    if a.timestamp == b.timestamp then
      return a.sequence < b.sequence
    end
    return a.timestamp < b.timestamp
  end)

  local latestTimestamp = nextHistory[#nextHistory] and nextHistory[#nextHistory].timestamp
  if previousLatestTimestamp and latestTimestamp and latestTimestamp > previousLatestTimestamp and
    previousRangeEnd and previousRangeEnd > 0 and
    math.abs(previousRangeEnd - previousLatestTimestamp) <= 60 then
    local rangeShift = latestTimestamp - previousLatestTimestamp
    db.profile.rangeEnd = latestTimestamp
    if previousRangeStart and previousRangeStart > 0 then
      db.profile.rangeStart = previousRangeStart + rangeShift
    end
  end

  history = nextHistory
  if updateRangeControls then
    updateRangeControls()
  end
  rankSnapshotsDirty = true
  groupedPlayers = {}
  playerLastUpdate = {}
  historyByPlayer = {}

  for _, event in ipairs(history) do
    if event.kind == "EP" or event.kind == "GP" then
      local player = event.player
      if player ~= "" and player ~= "GUILD_BANK" then
        local grouped = addon:GetGroupedName(player)
        if not groupedPlayers[grouped] then
          groupedPlayers[grouped] = true
        end
        playerLastUpdate[grouped] = math.max(playerLastUpdate[grouped] or 0, event.timestamp)
        if not historyByPlayer[grouped] then
          historyByPlayer[grouped] = {}
        end
        table.insert(historyByPlayer[grouped], event)
      end
    end
  end

  local playerNames = {}
  for player in pairs(groupedPlayers) do
    table.insert(playerNames, player)
  end
  table.sort(playerNames)
  groupedPlayers = playerNames
  local availablePlayers = {}
  for _, player in ipairs(groupedPlayers) do
    availablePlayers[player] = true
  end
  local validSelection = {}
  if restoreSavedPlayerSelection then
    local savedSelection = db and db.profile.timelinePlayers
    if type(savedSelection) ~= "table" then
      savedSelection = {}
    end
    for player, isSelected in pairs(savedSelection) do
      if type(player) == "string" and isSelected and availablePlayers[player] then
        validSelection[player] = true
      end
    end
    if not next(validSelection) then
      local legacySelection = previousSelection or (db and db.profile.lastSelectedPlayer)
      if legacySelection and legacySelection ~= ALL_PLAYERS and availablePlayers[legacySelection] then
        validSelection[legacySelection] = true
      end
    end
  else
    for player, isSelected in pairs(selectedPlayers) do
      if isSelected and availablePlayers[player] then
        validSelection[player] = true
      end
    end
  end
  selectedPlayers = validSelection
  if db and restoreSavedPlayerSelection then
    db.profile.timelinePlayers = validSelection
  end
  local selectedNames = {}
  for _, player in ipairs(groupedPlayers) do
    if selectedPlayers[player] then
      table.insert(selectedNames, player)
    end
  end
  selectedPlayer = selectedNames[1]

  if #history == 0 then
    setStatus("Журнал EPGP найден, но в нём нет распознаваемых событий.")
  else
    local message = ("Журнал «%s»: загружено событий: %d"):format(
      journalSource and journalSource.label or "EPGP", #history)
    if duplicates > 0 then
      message = message .. ("; точных дублей пропущено: %d"):format(duplicates)
    end
    if malformed > 0 then
      message = message .. ("; некорректных записей: %d"):format(malformed)
    end
    setStatus(message)
  end
  return true
end

function addon:GetGroupedName(name)
  if type(name) ~= "string" or not db or db.profile.grouping ~= "main" then
    return name
  end
  local shortName = name:match("^([^%-]+)") or name
  shortName = shortName:match("^%s*(.-)%s*$")
  local main
  if EPGP and EPGP.GetMain then
    main = EPGP:GetMain(name)
    if type(main) ~= "string" or main == "" then
      main = EPGP:GetMain(shortName)
    end
  end
  local shortMain = type(main) == "string" and
    (main:match("^([^%-]+)") or main):match("^%s*(.-)%s*$") or nil
  local rosterMain = guildMainByName and
    (guildMainByName[name:lower()] or guildMainByName[shortName:lower()])
  local officerNote = bossLoot.officerNotes and
    (bossLoot.officerNotes[name:lower()] or bossLoot.officerNotes[shortName:lower()])
  if type(officerNote) == "string" then
    officerNote = officerNote:match("^%s*(.-)%s*$")
    if officerNote ~= "" and not bossLoot.isNumericOfficerNote(officerNote) then
      local notedMain = officerNote:match("^([^%-]+)") or officerNote
      if not shortMain or shortMain:lower() == shortName:lower() then
        shortMain = bossLoot.rosterNames and
          bossLoot.rosterNames[notedMain:lower()] or notedMain
      end
    end
  end
  if type(rosterMain) == "string" and rosterMain ~= "" and
    (not shortMain or shortMain:lower() == shortName:lower()) then
    shortMain = rosterMain
  end
  shortMain = shortMain or shortName
  local canonicalName = bossLoot.rosterNames and
    bossLoot.rosterNames[shortMain:lower()]
  return canonicalName or shortMain
end

function sortedPlayerNames()
  local names = {}
  for i, name in ipairs(groupedPlayers) do
    local lastUpdate = playerLastUpdate[name] or 0
    local inactiveSeconds = db.profile.inactiveAfterMonths * 30 * 24 * 60 * 60
    if not db.profile.hideInactivePlayers or lastUpdate >= time() - inactiveSeconds then
      table.insert(names, name)
    end
  end
  table.sort(names)
  return names
end

function visiblePlayerNames()
  local names = sortedPlayerNames()
  local selectedNames = {}
  for _, name in ipairs(names) do
    if selectedPlayers and selectedPlayers[name] then
      table.insert(selectedNames, name)
    end
  end
  return selectedNames
end

function eventRecordsForPlayer(name)
  return historyByPlayer[name] or {}
end

function currentBalances(name)
  if db.profile.grouping == "toon" or not EPGP or not EPGP.GetEPGP then
    return nil, nil
  end
  local ep, gp = EPGP:GetEPGP(name)
  if type(ep) == "number" and type(gp) == "number" then
    return ep, gp
  end
  return nil, nil
end

function refreshCurrentRankCache()
  local ranking = {}
  if not EPGP or not EPGP.GetNumMembers or not EPGP.GetMember or
    not EPGP.GetEPGP or not EPGP.GetMinEP then
    return ranking
  end

  local selectedMembers = EPGP.GetMembersInAwardList and EPGP:GetMembersInAwardList() or {}
  local minimumEP = EPGP:GetMinEP() or 0
  local count = EPGP:GetNumMembers()
  for index = 1, count do
    local name = EPGP:GetMember(index)
    if name then
      local ep, gp = EPGP:GetEPGP(name)
      if ep and gp then
        table.insert(ranking, {
          player = name,
          ep = ep,
          gp = gp,
          pr = gp > 0 and ep / gp or 0,
          qualifies = ep >= minimumEP,
          inRaid = UnitInRaid and not not UnitInRaid(name) or false,
          selected = selectedMembers[name] and true or false,
          currentOrder = index,
        })
      end
    end
  end
  table.sort(ranking, function(a, b)
    if a.inRaid ~= b.inRaid then
      return a.inRaid
    elseif a.selected ~= b.selected then
      return a.selected
    elseif a.qualifies ~= b.qualifies then
      return a.qualifies
    elseif a.pr ~= b.pr then
      return a.pr > b.pr
    end
    return a.currentOrder < b.currentOrder
  end)
  local rankByPlayer = {}
  for position, entry in ipairs(ranking) do
    rankByPlayer[entry.player] = { position = position, count = #ranking }
    local main = EPGP.GetMain and EPGP:GetMain(entry.player)
    if main and not rankByPlayer[main] then
      rankByPlayer[main] = { position = position, count = #ranking }
    end
  end
  return rankByPlayer, ranking
end

function updateCurrentRankList()
  if not rankListPanel or not rankListPanel:IsShown() then
    return
  end
  rankListDate:SetText(date("%d.%m %H:%M", time()))
  local ranking = currentRankEntries
  if not ranking then
    local _, refreshed = refreshCurrentRankCache()
    ranking = refreshed or {}
    currentRankEntries = ranking
  end
  local filtered = {}
  for _, entry in ipairs(ranking or {}) do
    if rankClassIsIncluded(entry.player) then
      table.insert(filtered, entry)
    end
  end

  local selectedMain = selectedPlayer
  if selectedPlayer and selectedPlayer ~= ALL_PLAYERS and EPGP and EPGP.GetMain then
    selectedMain = EPGP:GetMain(selectedPlayer) or selectedPlayer
  end
  local selectedPosition
  for index, entry in ipairs(filtered) do
    local entryMain = EPGP and EPGP.GetMain and EPGP:GetMain(entry.player)
    if entry.player == selectedPlayer or entry.player == selectedMain or
      entryMain == selectedPlayer or entryMain == selectedMain then
      selectedPosition = index
      break
    end
  end

  local first, last
  if selectedPosition then
    first = math.max(1, selectedPosition - 10)
    last = math.min(#filtered, selectedPosition + 10)
    rankListTitle:SetText(("Место %d/%d"):format(selectedPosition, #filtered))
  else
    first, last = 1, math.min(#filtered, 21)
    rankListTitle:SetText(selectedPlayer and selectedPlayer ~= ALL_PLAYERS and
      "Игрок вне списка" or "Текущий рейтинг")
  end
  local rowCount = last and math.max(0, last - first + 1) or 0
  rankListContent:SetHeight(math.max(rowCount * 18, 1))
  for rowIndex = 1, rowCount do
    if not rankListRows[rowIndex] then
      local row = CreateFrame("Frame", nil, rankListContent)
      row:SetHeight(18)
      row.position = makeText(row, "", "GameFontNormalSmall")
      row.player = makeText(row, "", "GameFontNormalSmall")
      row.pr = makeText(row, "", "GameFontNormalSmall")
      row.position:SetPoint("LEFT", row, "LEFT", 2, 0)
      row.player:SetPoint("LEFT", row, "LEFT", 30, 0)
      row.player:SetPoint("RIGHT", row, "RIGHT", -48, 0)
      row.pr:SetPoint("RIGHT", row, "RIGHT", -2, 0)
      rankListRows[rowIndex] = row
    end
    local entryIndex = first + rowIndex - 1
    local entry = filtered[entryIndex]
    local row = rankListRows[rowIndex]
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", rankListContent, "TOPLEFT", 0, -(rowIndex - 1) * 18)
    row:SetPoint("TOPRIGHT", rankListContent, "TOPRIGHT", 0, -(rowIndex - 1) * 18)
    row.position:SetText(("%d."):format(entryIndex))
    row.player:SetText(entry.player)
    row.pr:SetText(("%.3f"):format(entry.pr))
    local classColor = playerClassColor(entry.player)
    row.player:SetTextColor(classColor.r, classColor.g, classColor.b)
    local isSelected = entryIndex == selectedPosition
    row.position:SetTextColor(isSelected and COLORS.RANK[1] or 0.70,
      isSelected and COLORS.RANK[2] or 0.74,
      isSelected and COLORS.RANK[3] or 0.77)
    row.pr:SetTextColor(COLORS.PR[1], COLORS.PR[2], COLORS.PR[3])
    row:Show()
  end
  for index = rowCount + 1, #rankListRows do
    rankListRows[index]:Hide()
  end
  if rowCount == 0 then
    rankListTitle:SetText("Текущий рейтинг недоступен")
  end
end

function updateCurrentBalanceText()
  if not currentBalanceText then
    return
  end
  currentRankEntries = nil
  local selectedNames = visiblePlayerNames()
  selectedPlayer = selectedNames[1]
  if #selectedNames > 1 then
    currentBalanceText:SetText(("Выбрано игроков: %d"):format(#selectedNames))
    return
  end
  if not selectedPlayer then
    currentBalanceText:SetText("Выберите игрока или игроков")
    return
  end
  local ep, gp = currentBalances(selectedPlayer)
  if ep and gp then
    local currentRankCache, ranking = refreshCurrentRankCache()
    currentRankEntries = ranking or {}
    local rank = currentRankCache[selectedPlayer]
    if not rank and EPGP and EPGP.GetMain then
      rank = currentRankCache[EPGP:GetMain(selectedPlayer)]
    end
    local classColor = playerClassColor(selectedPlayer)
    local playerName = selectedPlayer
    if classColor then
      playerName = ("|cff%02x%02x%02x%s|r"):format(
        math.floor(classColor.r * 255),
        math.floor(classColor.g * 255),
        math.floor(classColor.b * 255),
        selectedPlayer)
    end
    local rankText = rank and ("%d из %d"):format(rank.position, rank.count) or "вне фильтра / нет данных"
    currentBalanceText:SetText(("Текущий EPGP — %s: EP %.0f | GP %.0f | PR %.3f | Место в рейтинге: PR: %s"):format(
      playerName, ep, gp, gp > 0 and ep / gp or 0, rankText))
  elseif db.profile.grouping == "toon" then
    currentBalanceText:SetText("Текущий EPGP недоступен в режиме группировки персонажей")
  else
    currentBalanceText:SetText(("Текущий EPGP недоступен для %s"):format(selectedPlayer))
  end
end

local cachedGuildRulesText
local cachedGuildRules
local cachedGuildRulesError

function getGuildEPGPRuleSettings()
  local guildInfo = GetGuildInfoText and GetGuildInfoText()
  if type(guildInfo) ~= "string" or guildInfo == "" then
    return nil, "Описание гильдии недоступно."
  end
  if guildInfo == cachedGuildRulesText then
    return cachedGuildRules, cachedGuildRulesError
  end
  cachedGuildRulesText = guildInfo
  cachedGuildRules = nil
  cachedGuildRulesError = nil

  local inBlock = false
  local blockClosed = false
  local values = {}
  for rawLine in (guildInfo .. "\n"):gmatch("(.-)\n") do
    local line = rawLine:gsub("\r$", "")
    if line:find("-EPGP-", 1, true) then
      if inBlock then
        blockClosed = true
        break
      end
      inBlock = true
    elseif inBlock then
      local key, value = line:match("^%s*@([A-Z_]+):(%d+)%s*$")
      if key == "DECAY_P" or key == "BASE_GP" then
        if values[key] then
          cachedGuildRulesError = ("В блоке EPGP повторяется параметр @%s."):format(key)
          return nil, cachedGuildRulesError
        end
        values[key] = tonumber(value)
      end
    end
  end

  if not blockClosed then
    cachedGuildRulesError = "В описании не найден закрытый блок -EPGP-."
  elseif values.DECAY_P == nil or values.BASE_GP == nil then
    cachedGuildRulesError = "В блоке EPGP должны быть заданы @DECAY_P и @BASE_GP."
  elseif values.DECAY_P > 100 then
    cachedGuildRulesError = "Значение @DECAY_P должно быть от 0 до 100."
  else
    cachedGuildRules = {
      anomalyThreshold = values.DECAY_P,
      minGPSlice = values.BASE_GP,
    }
  end
  return cachedGuildRules, cachedGuildRulesError
end

function getEffectiveEPGPRuleSettings()
  if db.profile.epgpRulesSource == "guild" then
    local guildRules = getGuildEPGPRuleSettings()
    if guildRules then
      return guildRules
    end
  end
  return {
    anomalyThreshold = tonumber(db.profile.anomalyThreshold) or 20,
    minGPSlice = tonumber(db.profile.minGPSlice) or 1000,
  }
end

function invalidateGuildEPGPRuleSettingsCache()
  cachedGuildRulesText = nil
end

function buildTimeline(name)
  local records = eventRecordsForPlayer(name)
  local totalEP, totalGP = 0, 0
  for _, event in ipairs(records) do
    if event.kind == "EP" then
      totalEP = totalEP + event.amount
    else
      totalGP = totalGP + event.amount
    end
  end

  local currentEP, currentGP = currentBalances(name)
  local ep = currentEP and currentEP - totalEP or 0
  local gp = currentGP and currentGP - totalGP or 0
  local epgpRules = getEffectiveEPGPRuleSettings()
  local anomalySlicePercent = math.max(1, math.min(99, tonumber(epgpRules.anomalyThreshold) or 20))
  local anomalyThreshold = anomalySlicePercent + 1
  local minGPSlice = math.max(0, tonumber(epgpRules.minGPSlice) or 1000)
  local anomalyDetectionEnabled = tonumber(epgpRules.anomalyThreshold) ~= 0
  local points = {}

  for _, event in ipairs(records) do
    local previousPR = gp > 0 and ep / gp or 0
    local previousGP = gp
    local previousValue = event.kind == "EP" and ep or gp
    local dropPercent = event.amount < 0 and previousValue > 0 and
      -event.amount / previousValue * 100 or 0
    local highGPSlice = anomalyDetectionEnabled and event.kind == "EP" and event.amount < 0 and
      gp >= minGPSlice and math.abs(dropPercent - anomalySlicePercent) <= 0.5
    if event.kind == "EP" then
      ep = ep + event.amount
    else
      gp = gp + event.amount
    end
    local currentPR = gp > 0 and ep / gp or 0
    local guildPriceOverage, discountPriceOverage = 0, 0
    local discountCategory
    local guildPrice
    if event.kind == "GP" and event.itemId and event.amount > 0 and getGuildGP and
      event.timestamp >= getGuildPriceEffectiveTimestamp() then
      guildPrice = getGuildGP(event.itemId)
      if guildPrice and event.amount > guildPrice then
        guildPriceOverage = event.amount - guildPrice
      elseif guildPrice and getGuildPriceAnomaly then
        discountPriceOverage, discountCategory =
          getGuildPriceAnomaly(event.amount, guildPrice)
      end
    end
    table.insert(points, {
      timestamp = event.timestamp,
      reason = event.reason,
      officer = event.officer,
      kind = event.kind,
      deltaEP = event.kind == "EP" and event.amount or 0,
      deltaGP = event.kind == "GP" and event.amount or 0,
      deltaPR = currentPR - previousPR,
      rankBefore = event.rankBefore,
      rankAfter = event.rankAfter,
      rankCount = event.rankCount,
      decay = event.decay,
      anomaly = anomalyDetectionEnabled and not highGPSlice and dropPercent > anomalyThreshold,
      highGPSlice = highGPSlice,
      dropPercent = dropPercent,
      itemId = event.itemId,
      previousGP = previousGP,
      previousPR = previousPR,
      guildPriceOverage = guildPriceOverage,
      discountPriceOverage = discountPriceOverage,
      discountCategory = discountCategory,
      priceAnomaly = guildPriceOverage > 0 or discountPriceOverage > 0,
      ep = ep,
      gp = gp,
      pr = currentPR,
    })
  end
  return points, currentEP ~= nil
end

rankClassIsIncluded = function(name)
  local classToken = classTokenByPlayer[name]
  return not classToken or db.profile.classFilters[classToken] ~= false
end

function buildRankSnapshots()
  local names = sortedPlayerNames()
  rankPlayerIndexes = {}
  for index, name in ipairs(names) do
    rankPlayerIndexes[name] = index
  end
  local balances = {}
  local completeBalances = true
  for _, name in ipairs(names) do
    local totalEP, totalGP = 0, 0
    for _, event in ipairs(historyByPlayer[name] or {}) do
      if event.kind == "EP" then
        totalEP = totalEP + event.amount
      else
        totalGP = totalGP + event.amount
      end
    end
    local currentEP, currentGP = currentBalances(name)
    if rankClassIsIncluded(name) and (currentEP == nil or currentGP == nil) then
      completeBalances = false
    end
    balances[name] = {
      ep = (currentEP or 0) - totalEP,
      gp = (currentGP or 0) - totalGP,
    }
  end

  local snapshots = {}
  local timestamp
  local previousSelectedRank
  local rankCount = 0
  for _, name in ipairs(names) do
    if rankClassIsIncluded(name) then
      rankCount = rankCount + 1
    end
  end
  local function positionOf(player, balance)
    if not balance or not rankClassIsIncluded(player) then
      return nil
    end
    local priority = balance.gp > 0 and balance.ep / balance.gp or 0
    local position = 1
    for _, otherPlayer in ipairs(names) do
      if otherPlayer ~= player and rankClassIsIncluded(otherPlayer) then
        local other = balances[otherPlayer]
        local otherPriority = other.gp > 0 and other.ep / other.gp or 0
        if otherPriority > priority or
          (otherPriority == priority and other.ep > balance.ep) or
          (otherPriority == priority and other.ep == balance.ep and otherPlayer < player) then
          position = position + 1
        end
      end
    end
    return position
  end
  local function saveSnapshot(snapshotTime)
    local ranking = {}
    for _, name in ipairs(names) do
      if rankClassIsIncluded(name) then
        local balance = balances[name]
        local pr = balance.gp > 0 and balance.ep / balance.gp or 0
        table.insert(ranking, {
          player = name,
          ep = balance.ep,
          gp = balance.gp,
          pr = pr,
        })
      end
    end
    table.sort(ranking, function(a, b)
      if a.pr ~= b.pr then
        return a.pr > b.pr
      elseif a.ep ~= b.ep then
        return a.ep > b.ep
      end
      return a.player < b.player
    end)

    local positions = {}
    local selectedRank, selectedPriority
    for position, entry in ipairs(ranking) do
      positions[rankPlayerIndexes[entry.player]] = position
      if entry.player == selectedPlayer then
        selectedRank, selectedPriority = position, entry.pr
      end
    end
    local rankChanged = selectedRank ~= nil and selectedRank ~= previousSelectedRank
    local snapshot = {
      timestamp = snapshotTime,
      positions = positions,
      count = #ranking,
      selectedRank = selectedRank,
      selectedPriority = selectedPriority,
      rankChanged = rankChanged,
      previousSelectedRank = previousSelectedRank,
    }
    if selectedMetric == "RANK" and rankChanged then
      snapshot.ranking = ranking
    end
    previousSelectedRank = selectedRank
    table.insert(snapshots, snapshot)
  end

  for _, event in ipairs(history) do
    if (event.kind == "EP" or event.kind == "GP") and event.player ~= "GUILD_BANK" then
      if timestamp and event.timestamp ~= timestamp then
        saveSnapshot(timestamp)
      end
      timestamp = event.timestamp
      local player = addon:GetGroupedName(event.player)
      local balance = balances[player]
      if balance then
        event.rankBefore = positionOf(player, balance)
        event.rankCount = rankCount
        if event.kind == "EP" then
          balance.ep = balance.ep + event.amount
        else
          balance.gp = balance.gp + event.amount
        end
        event.rankAfter = positionOf(player, balance)
      else
        event.rankBefore, event.rankAfter, event.rankCount = nil, nil, nil
      end
    end
  end

  if timestamp then
    saveSnapshot(timestamp)
  end
  return snapshots, completeBalances
end

getRankSnapshotAt = function(timestamp)
  ensureRankSnapshots()
  local low, high, found = 1, #rankSnapshots, nil
  while low <= high do
    local middle = math.floor((low + high) / 2)
    if rankSnapshots[middle].timestamp <= timestamp then
      found = rankSnapshots[middle]
      low = middle + 1
    else
      high = middle - 1
    end
  end
  return found
end

ensureRankSnapshots = function()
  if rankSnapshotsDirty then
    rankSnapshots, rankBalancesComplete = buildRankSnapshots()
    rankSnapshotsDirty = false
  end
end
