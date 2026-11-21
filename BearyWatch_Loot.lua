local addon = _G.BearyWatch
if type(addon) ~= "table" or type(addon.environment) ~= "table" then
  error("BearyWatch shared environment was not initialized.")
end
setfenv(1, addon.environment)
function selectTab(tab)
  if tab == "project" then
    if not projectPanel then
      createProjectUI()
    end
  end
  if tab == "analytics" then
    if activeTab == "timeline" or activeTab == "efficiency" or activeTab == "items" then
      tab = activeTab
    elseif db and db.profile and
      (db.profile.analyticsTab == "timeline" or db.profile.analyticsTab == "efficiency" or
        db.profile.analyticsTab == "items") then
      tab = db.profile.analyticsTab
    else
      tab = "timeline"
    end
  end
  if tab ~= "roster" and tab ~= "dropLine" and tab ~= "timeline" and
    tab ~= "efficiency" and tab ~= "items" and tab ~= "settings" and tab ~= "project" then
    tab = "timeline"
  end
  if tab == "efficiency" and not efficiencyPanel then
    createEfficiencyUI()
  elseif tab == "items" and not itemPanel then
    createItemAnalysisUI()
  elseif tab == "settings" and not settingsPanel then
    createSettingsUI()
  elseif tab == "dropLine" and not dropLinePanel then
    if type(createDropLineUI) ~= "function" then
      setStatus("Не загрузился модуль дроплайна. Проверьте BearyWatch_DropLine.lua в BearyWatch.toc.")
      return
    end
    createDropLineUI()
  elseif tab == "roster" and not rosterWindow then
    createRosterUI()
  end
  if playerDropdown then
    playerDropdown:ClearAllPoints()
    if tab == "items" then
      playerDropdown:SetParent(itemPanel)
      playerDropdown:SetPoint("TOPLEFT", itemPanel, "TOPLEFT", 396, -12)
    else
      playerDropdown:SetParent(timelinePanel)
      playerDropdown:SetPoint("TOPLEFT", timelinePanel, "TOPLEFT", 66, -13)
    end
    playerDropdownMenu:ClearAllPoints()
    playerDropdownMenu:SetPoint("TOPLEFT", playerDropdown, "BOTTOMLEFT", 0, -3)
  end
  activeTab = tab
  local analyticsTab = tab == "timeline" or tab == "efficiency" or tab == "items"
  local activePrimaryTab = analyticsTab and "analytics" or tab
  for name, button in pairs(tabButtons) do
    button.isActive = name == activePrimaryTab
    button.activeColor = COLORS.EP
    if button.isActive then
      button.background:SetVertexColor(COLORS.EP[1], COLORS.EP[2], COLORS.EP[3], 0.55)
    else
      button.background:SetVertexColor(0.12, 0.15, 0.18, 1)
    end
  end
  for name, button in pairs(analyticsSubtabButtons) do
    button.isActive = name == tab
    button.activeColor = COLORS.EP
    if analyticsTab then
      button:Show()
    else
      button:Hide()
    end
    if button.isActive then
      button.background:SetVertexColor(COLORS.EP[1], COLORS.EP[2], COLORS.EP[3], 0.55)
    else
      button.background:SetVertexColor(0.12, 0.15, 0.18, 1)
    end
  end
  if db and db.profile then
    db.profile.selectedTab = tab
    if analyticsTab then
      db.profile.analyticsTab = tab
    end
  end
  if playerDropdownMenu then
    playerDropdownMenu:Hide()
  end
  if journalSourceMenu then
    journalSourceMenu:Hide()
  end
  if classFilterMenu then
    classFilterMenu:Hide()
  end
  if itemDropdownMenu then
    itemDropdownMenu:Hide()
  end
  for _, dropdown in ipairs(bossLoot.dropdowns) do
    dropdown.menu:Hide()
  end
  if playerSearch then
    playerSearch:ClearFocus()
    playerSearch:Hide()
  end
  if playerSearchHint then
    playerSearchHint:Hide()
  end
  if itemSearch then
    itemSearch:ClearFocus()
    itemSearch:Hide()
  end
  if itemSearchHint then
    itemSearchHint:Hide()
  end
  timelinePanel:Hide()
  if efficiencyPanel then
    efficiencyPanel:Hide()
  end
  if itemPanel then
    itemPanel:Hide()
  end
  if settingsPanel then
    settingsPanel:Hide()
  end
  if dropLinePanel then
    dropLinePanel:Hide()
  end
  if rosterWindow then
    rosterWindow:Hide()
  end
  if projectPanel then
    projectPanel:Hide()
  end
  if tab == "efficiency" then
    efficiencyPanel:Show()
    renderEfficiency()
  elseif tab == "items" then
    itemPanel:Show()
    bossLoot.mode = false
    bossLoot.view = "loot"
    bossLoot.updateControls()
    updateItemDropdown()
    renderItemAnalysis()
  elseif tab == "settings" then
    settingsPanel:Show()
    if updateJournalSourceDropdown then
      updateJournalSourceDropdown()
    end
    if refreshEPGPRuleSourceControls then
      refreshEPGPRuleSourceControls()
    end
  elseif tab == "dropLine" then
    dropLinePanel:Show()
    drawDropLineChart()
  elseif tab == "roster" then
    rosterWindow:Show()
    updateRosterWindow()
  elseif tab == "project" then
    projectPanel:Show()
  else
    timelinePanel:Show()
    updatePlayerDropdown()
    drawChart()
  end
end

function makePanel(parent)
  local panel = CreateFrame("Frame", nil, parent)
  panel:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  panel:SetBackdropColor(0.07, 0.08, 0.09, 0.96)
  panel:SetBackdropBorderColor(0.19, 0.24, 0.27, 1)
  return panel
end

bossLoot.classOptions = {
  { id = 1, name = "Воин" },
  { id = 2, name = "Паладин" },
  { id = 3, name = "Охотник" },
  { id = 4, name = "Разбойник" },
  { id = 5, name = "Жрец" },
  { id = 6, name = "Рыцарь смерти" },
  { id = 7, name = "Шаман" },
  { id = 8, name = "Маг" },
  { id = 9, name = "Чернокнижник" },
  { id = 11, name = "Друид" },
}

function bossLoot.getClassName(classId)
  for _, option in ipairs(bossLoot.classOptions) do
    if option.id == classId then
      return option.name
    end
  end
  return "Класс"
end

function bossLoot.saveSelection()
  if not db then
    return
  end
  db.char.bossLoot = {
    isRaid = bossLoot.isRaid,
    tier = bossLoot.tier,
    tierName = bossLoot.tierName,
    instanceId = bossLoot.instanceId,
    instanceName = bossLoot.instanceName,
    encounterId = bossLoot.encounterId,
    encounterName = bossLoot.encounterName,
    difficultyId = bossLoot.difficultyId,
    difficultyName = bossLoot.difficultyName,
    classId = bossLoot.classId,
    competitorScope = bossLoot.competitorScope,
    excludedItems = bossLoot.excludedItems,
  }
end

function bossLoot.getJournalState()
  local state = {}
  if type(EncounterJournal) == "table" then
    state.journalInstance = EncounterJournal.instanceID
    state.journalEncounter = EncounterJournal.encounterID
    state.journalEncounterList = EncounterJournal.encounterList
  end
  if type(EJ_GetCurrentTier) == "function" then
    local ok, value = pcall(EJ_GetCurrentTier)
    if ok then
      state.tier = value
    end
  end
  if type(EJ_GetCurrentInstance) == "function" then
    local ok, value = pcall(EJ_GetCurrentInstance)
    if ok then
      state.instance = value
    end
  end
  if state.journalInstance ~= nil then
    state.instance = state.journalInstance
  end
  if type(EJ_GetLootFilter) == "function" then
    local ok, classId, specId = pcall(EJ_GetLootFilter)
    if ok then
      state.classId, state.specId = classId, specId
    end
  end
  if type(EJ_GetDifficulty) == "function" then
    local ok, value = pcall(EJ_GetDifficulty)
    if ok then
      state.difficulty = value
    end
  end
  return state
end

function bossLoot.restoreJournalState(state)
  local hasSelectedJournalInstance = state.journalInstance ~= nil and state.journalInstance > 0
  if type(EncounterJournal) == "table" then
    EncounterJournal.instanceID = state.journalInstance
    EncounterJournal.encounterID = state.journalEncounter
    EncounterJournal.encounterList = state.journalEncounterList
  end
  if hasSelectedJournalInstance and state.tier ~= nil and type(EJ_SelectTier) == "function" then
    local ok, err = pcall(EJ_SelectTier, state.tier)
    if not ok then
      setStatus("Не удалось восстановить раздел книги приключений: " .. tostring(err))
    end
  end
  if hasSelectedJournalInstance and type(EJ_SelectInstance) == "function" then
    if type(EncounterJournal) == "table" then
      EncounterJournal.instanceID = state.instance
    end
    local ok, err = pcall(EJ_SelectInstance, state.instance)
    if not ok then
      setStatus("Не удалось восстановить рейд книги приключений: " .. tostring(err))
    end
  end
  if hasSelectedJournalInstance and state.difficulty ~= nil and
    type(EJ_SetDifficulty) == "function" then
    local ok, err = pcall(EJ_SetDifficulty, state.difficulty)
    if not ok then
      setStatus("Не удалось восстановить сложность книги приключений: " .. tostring(err))
    end
  end
  if type(EncounterJournal) == "table" then
    EncounterJournal.instanceID = state.journalInstance
    EncounterJournal.encounterID = state.journalEncounter
    EncounterJournal.encounterList = state.journalEncounterList
  end
  if state.classId ~= nil and state.specId ~= nil and type(EJ_SetLootFilter) == "function" then
    local ok, err = pcall(EJ_SetLootFilter, state.classId, state.specId)
    if not ok then
      setStatus("Не удалось восстановить фильтр книги приключений: " .. tostring(err))
    end
  end
end

function bossLoot.withJournalState(callback)
  local state = bossLoot.getJournalState()
  local results = { pcall(callback) }
  bossLoot.restoreJournalState(state)
  if not results[1] then
    setStatus("Ошибка чтения книги приключений: " .. tostring(results[2]))
    return nil
  end
  return unpack(results, 2)
end

function bossLoot.createDropdown(parent, title, width, optionsProvider, onSelect)
  local button = makeButton(parent, title, width, 24)
  local menu = makePanel(window)
  menu:SetFrameStrata("DIALOG")
  menu:SetFrameLevel(window:GetFrameLevel() + 20)
  menu:SetSize(width + 16, 230)
  menu:Hide()

  local scroll = CreateFrame("ScrollFrame", nil, menu, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -6)
  scroll:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -26, 6)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetWidth(width - 18)
  content:SetHeight(1)
  scroll:SetScrollChild(content)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local maximum = math.max(content:GetHeight() - self:GetHeight(), 0)
    self:SetVerticalScroll(math.max(0, math.min(maximum, self:GetVerticalScroll() - delta * 24)))
  end)

  local dropdown = { button = button, menu = menu, rows = {}, optionsProvider = optionsProvider }
  button:SetScript("OnClick", function()
    if menu:IsShown() then
      menu:Hide()
      return
    end
    for _, other in ipairs(bossLoot.dropdowns) do
      other.menu:Hide()
    end
    local options = optionsProvider()
    if not options then
      return
    end
    if #options == 0 then
      setStatus("В книге приключений нет подходящих вариантов для выбранных параметров.")
      return
    end
    for index, option in ipairs(options) do
      local row = dropdown.rows[index]
      if not row then
        row = makeButton(content, "", width - 18, 24, function(self)
          menu:Hide()
          onSelect(self.option.value, self.option.label)
        end)
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
        row.label:SetJustifyH("LEFT")
        dropdown.rows[index] = row
      end
      row.option = option
      row.label:SetText(option.label)
      row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(index - 1) * 24)
      row:Show()
    end
    for index = #options + 1, #dropdown.rows do
      dropdown.rows[index]:Hide()
    end
    content:SetHeight(math.max(#options * 24, 1))
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -3)
    menu:Show()
  end)
  table.insert(bossLoot.dropdowns, dropdown)
  return button
end

function makeDateEditBox(parent)
  local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  edit:SetSize(94, 24)
  edit:SetAutoFocus(false)
  edit:SetMaxLetters(10)
  edit:SetFontObject(GameFontHighlightSmall)
  edit:SetJustifyH("CENTER")
  edit:SetTextInsets(4, 4, 0, 0)
  return edit
end

function makeSmallEditBox(parent, width, maxLetters)
  local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  edit:SetSize(width, 22)
  edit:SetAutoFocus(false)
  edit:SetNumeric(maxLetters ~= false)
  edit:SetMaxLetters(maxLetters or 8)
  edit:SetFontObject(GameFontHighlightSmall)
  edit:SetJustifyH("CENTER")
  edit:SetTextInsets(4, 4, 0, 0)
  return edit
end

function createCategoryNameControls(parent, anchor, updateCategoryHint)
  local title = makeText(parent, "Названия категорий лута", "GameFontNormal")
  title:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)
  title:SetTextColor(0.78, 0.88, 0.92)
  db.profile.guildPricing.categoryNames = db.profile.guildPricing.categoryNames or {}
  local fields = {}
  local function addField(key, labelText, column, row)
    local label = makeText(parent, labelText, "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", title, "BOTTOMLEFT",
      column == 1 and 0 or 238, -8 - (row - 1) * 34)
    local edit = makeSmallEditBox(parent, 126, false)
    edit:SetNumeric(false)
    edit:SetMaxLetters(24)
    edit:SetJustifyH("LEFT")
    edit:SetText(db.profile.guildPricing.categoryNames[key] or labelText)
    edit:SetPoint("LEFT", label, "RIGHT", 8, 0)
    fields[key] = edit
  end
  addField("main", "Main", 1, 1)
  addField("minor", "Minor", 2, 1)
  addField("offTwin", "Off Twin", 1, 2)
  addField("roll", "Roll / Trans", 2, 2)
  local save = makeButton(parent, "Сохранить названия", 154, 24, function()
    local values = {}
    for key, edit in pairs(fields) do
      local value = edit:GetText():match("^%s*(.-)%s*$")
      if value == "" or value:find("[\t\r\n]") then
        setStatus("Название категории не может быть пустым и не должно содержать переносы строк.")
        return
      end
      values[key] = value
    end
    local categoryNames = db.profile.guildPricing.categoryNames
    for key, value in pairs(values) do
      categoryNames[key] = value
      local edit = fields[key]
      edit:SetText(value)
    end
    updateCategoryHint()
    refreshViews()
  end)
  save:SetPoint("LEFT", fields.roll, "RIGHT", 12, 0)
  local function refreshCategoryNameControls()
    local categoryNames = db.profile.guildPricing.categoryNames or {}
    local defaultNames = { main = "Main", minor = "Minor", offTwin = "Off Twin", roll = "Roll / Trans" }
    for key, edit in pairs(fields) do
      edit:SetText(categoryNames[key] or defaultNames[key])
    end
  end
  return title, refreshCategoryNameControls
end

LOOT_CATEGORY_KEYS = { main = true, minor = true, offTwin = true, roll = true }
LOOT_RULES_HEADER = "BEARYWATCH_LOOT_RULES_V1"

function serializeLootRules(rules)
  local lines = {
    LOOT_RULES_HEADER,
    "USE\t" .. (rules.useGuildRules and "1" or "0"),
    "PRICE_DATE\t" .. (rules.priceEffectiveDate or DEFAULT_GUILD_PRICE_EFFECTIVE_DATE),
  }
  local categoryKeys = { "main", "minor", "offTwin", "roll" }
  local categoryMultipliers = rules.categoryMultipliers or {}
  local categoryNames = rules.categoryNames or {}
  local defaultMultipliers = { main = 1, minor = 0.5, offTwin = 0.25, roll = 0 }
  local defaultNames = { main = "Main", minor = "Minor", offTwin = "Off Twin", roll = "Roll / Trans" }
  for _, key in ipairs(categoryKeys) do
    table.insert(lines, ("CATEGORY\t%s\t%.6f\t%s"):format(
      key, categoryMultipliers[key] or defaultMultipliers[key],
      categoryNames[key] or defaultNames[key]))
  end
  local ilvls = {}
  for ilvl in pairs(rules.ilvlRules or {}) do
    table.insert(ilvls, ilvl)
  end
  table.sort(ilvls)
  for _, ilvl in ipairs(ilvls) do
    local rule = rules.ilvlRules[ilvl]
    table.insert(lines, ("ILVL\t%d\t%d\t%d"):format(
      ilvl, rule.default, rule.twoHand or rule.default))
  end
  local itemIds = {}
  for itemId in pairs(rules.itemPrices or {}) do
    table.insert(itemIds, itemId)
  end
  table.sort(itemIds)
  for _, itemId in ipairs(itemIds) do
    local price = rules.itemPrices[itemId]
    table.insert(lines, price == false and ("ITEM\t%d\tSKIP"):format(itemId) or
      ("ITEM\t%d\t%d"):format(itemId, price))
  end
  return table.concat(lines, "\n")
end

function parseLootRules(text)
  if type(text) ~= "string" then
    return nil, "Вставьте текст правил."
  end
  local rules = {
    priceEffectiveDate = DEFAULT_GUILD_PRICE_EFFECTIVE_DATE,
    ilvlRules = {},
    itemPrices = {},
    categoryMultipliers = {},
    categoryNames = {},
  }
  local seenCategories = {}
  local useSeen = false
  local priceDateSeen = false
  local headerSeen = false
  for rawLine in text:gmatch("[^\n]+") do
    local line = rawLine:gsub("\r$", "")
    if not headerSeen then
      if line ~= LOOT_RULES_HEADER then
        return nil, "Неверная версия или заголовок файла правил."
      end
      headerSeen = true
    elseif line == "" or line:match("^#") then
    else
      local useValue = line:match("^USE\t([01])$")
      local priceDate = line:match("^PRICE_DATE\t([^\t]+)$")
      local category, multiplier, name = line:match("^CATEGORY\t([%w]+)\t([%d%.]+)\t([^\t]+)$")
      local ilvl, normalPrice, twoHandPrice = line:match("^ILVL\t(%d+)\t(%d+)\t(%d+)$")
      local itemId, itemPrice = line:match("^ITEM\t(%d+)\t(%d+)$")
      local skippedItemId = line:match("^ITEM\t(%d+)\tSKIP$")
      if useValue then
        if useSeen then
          return nil, "В правилах повторяется настройка USE."
        end
        rules.useGuildRules = useValue == "1"
        useSeen = true
      elseif priceDate then
        if priceDateSeen or not parseDateInput(priceDate, false) then
          return nil, "Некорректная или повторяющаяся дата PRICE_DATE. Используйте ГГГГ-ММ-ДД."
        end
        rules.priceEffectiveDate = date("%Y-%m-%d", parseDateInput(priceDate, false))
        priceDateSeen = true
      elseif category then
        local numericMultiplier = tonumber(multiplier)
        if not LOOT_CATEGORY_KEYS[category] or seenCategories[category] or
          not numericMultiplier or numericMultiplier < 0 or numericMultiplier > 10 or
          name:match("^%s*$") then
          return nil, "Некорректная или повторяющаяся настройка CATEGORY."
        end
        rules.categoryMultipliers[category] = numericMultiplier
        rules.categoryNames[category] = name
        seenCategories[category] = true
      elseif ilvl then
        local level, normal, twoHand = tonumber(ilvl), tonumber(normalPrice), tonumber(twoHandPrice)
        if level < 1 or normal > 99999 or twoHand > 99999 or rules.ilvlRules[level] then
          return nil, "Некорректное или повторяющееся правило ILVL."
        end
        rules.ilvlRules[level] = { default = normal, twoHand = twoHand }
      elseif itemId or skippedItemId then
        local id = tonumber(itemId or skippedItemId)
        local price = itemPrice and tonumber(itemPrice) or false
        if id < 1 or (price and price > 99999) or rules.itemPrices[id] ~= nil then
          return nil, "Некорректное или повторяющееся правило ITEM."
        end
        rules.itemPrices[id] = price
      else
        return nil, "Не удалось разобрать строку правил: " .. line
      end
    end
  end
  if not headerSeen or not useSeen then
    return nil, "В тексте не хватает заголовка или настройки USE."
  end
  for key in pairs(LOOT_CATEGORY_KEYS) do
    if not seenCategories[key] then
      return nil, "Не задано название и значение категории " .. key .. "."
    end
  end
  return rules
end

function applyLootRules(target, source)
  target.useGuildRules = source.useGuildRules
  target.priceEffectiveDate = source.priceEffectiveDate or DEFAULT_GUILD_PRICE_EFFECTIVE_DATE
  target.ilvlRules = {}
  target.itemPrices = {}
  target.categoryMultipliers = {}
  target.categoryNames = {}
  for key, rule in pairs(source.ilvlRules) do
    target.ilvlRules[key] = { default = rule.default, twoHand = rule.twoHand }
  end
  for key, price in pairs(source.itemPrices) do
    target.itemPrices[key] = price
  end
  for key, value in pairs(source.categoryMultipliers) do
    target.categoryMultipliers[key] = value
  end
  for key, value in pairs(source.categoryNames) do
    target.categoryNames[key] = value
  end
end

SETTINGS_HEADER = "BEARYWATCH_SETTINGS_V1"

function serializeAddonSettings(profile, journalProfile)
  local lines = {
    SETTINGS_HEADER,
    "GROUPING\t" .. (profile.grouping == "toon" and "toon" or "main"),
    "ADDON_LOOT_FILTER\t" .. (profile.useAddonLootFilter ~= false and "1" or "0"),
    "HIDE_INACTIVE\t" .. (profile.hideInactivePlayers and "1" or "0"),
    "INACTIVE_MONTHS\t" .. tostring(profile.inactiveAfterMonths or 3),
    "ANOMALY_THRESHOLD\t" .. tostring(profile.anomalyThreshold or 20),
    "MIN_GP_SLICE\t" .. tostring(profile.minGPSlice or 1000),
    "EPGP_RULES_SOURCE\t" .. (profile.epgpRulesSource == "local" and "local" or "guild"),
    "MINIMAP_HIDDEN\t" .. (profile.minimap and profile.minimap.hide and "1" or "0"),
    "JOURNAL_PROFILE\t" .. (journalProfile or ""),
    "RULES_BEGIN",
  }
  local lootRules = serializeLootRules(profile.guildPricing)
  for line in lootRules:gmatch("[^\n]+") do
    table.insert(lines, line)
  end
  return table.concat(lines, "\n")
end

function parseAddonSettings(text)
  if type(text) ~= "string" then
    return nil, "Вставьте текст настроек."
  end
  local values = {}
  local lootRuleLines = {}
  local headerSeen = false
  local rulesStarted = false
  for rawLine in (text .. "\n"):gmatch("(.-)\n") do
    local line = rawLine:gsub("\r$", "")
    if not headerSeen then
      if line ~= SETTINGS_HEADER then
        return nil, "Неверная версия или заголовок настроек."
      end
      headerSeen = true
    elseif rulesStarted then
      table.insert(lootRuleLines, line)
    elseif line == "RULES_BEGIN" then
      rulesStarted = true
    else
      local key, value = line:match("^([A-Z_]+)\t([^\t]*)$")
      if not key or values[key] ~= nil then
        return nil, "Некорректная или повторяющаяся настройка: " .. line
      end
      values[key] = value
    end
  end
  local knownSettings = {
    GROUPING = true,
    ADDON_LOOT_FILTER = true,
    HIDE_INACTIVE = true,
    INACTIVE_MONTHS = true,
    ANOMALY_THRESHOLD = true,
    MIN_GP_SLICE = true,
    EPGP_RULES_SOURCE = true,
    MINIMAP_HIDDEN = true,
    JOURNAL_PROFILE = true,
  }
  for key in pairs(values) do
    if not knownSettings[key] then
      return nil, "Неизвестная настройка: " .. key
    end
  end
  local months = tonumber(values.INACTIVE_MONTHS)
  local anomalyThreshold = tonumber(values.ANOMALY_THRESHOLD)
  local minGPSlice = tonumber(values.MIN_GP_SLICE)
  if not headerSeen or not rulesStarted or values.GROUPING ~= "main" and values.GROUPING ~= "toon" or
    (values.ADDON_LOOT_FILTER ~= nil and values.ADDON_LOOT_FILTER ~= "0" and
      values.ADDON_LOOT_FILTER ~= "1") or
    (values.HIDE_INACTIVE ~= "0" and values.HIDE_INACTIVE ~= "1") or
    not months or months < 1 or months > 24 or months ~= math.floor(months) or
    not anomalyThreshold or anomalyThreshold < 1 or anomalyThreshold > 99 or
    anomalyThreshold ~= math.floor(anomalyThreshold) or not minGPSlice or minGPSlice < 0 or
    minGPSlice > 99999999 or minGPSlice ~= math.floor(minGPSlice) or
    (values.EPGP_RULES_SOURCE ~= nil and values.EPGP_RULES_SOURCE ~= "guild" and
      values.EPGP_RULES_SOURCE ~= "local") or
    (values.MINIMAP_HIDDEN ~= "0" and values.MINIMAP_HIDDEN ~= "1") or
    values.JOURNAL_PROFILE == nil or values.JOURNAL_PROFILE:find("[\t\r\n]") then
    return nil, "Настройки содержат некорректные или отсутствующие значения."
  end
  local lootRules, err = parseLootRules(table.concat(lootRuleLines, "\n"))
  if not lootRules then
    return nil, err
  end
  return {
    grouping = values.GROUPING,
    useAddonLootFilter = values.ADDON_LOOT_FILTER ~= "0",
    hideInactivePlayers = values.HIDE_INACTIVE == "1",
    inactiveAfterMonths = months,
    anomalyThreshold = anomalyThreshold,
    minGPSlice = minGPSlice,
    epgpRulesSource = values.EPGP_RULES_SOURCE or "guild",
    minimapHidden = values.MINIMAP_HIDDEN == "1",
    journalProfile = values.JOURNAL_PROFILE,
    guildPricing = lootRules,
  }
end

function applyAddonSettings(profile, characterSettings, source)
  profile.grouping = source.grouping
  profile.useAddonLootFilter = source.useAddonLootFilter ~= false
  profile.hideInactivePlayers = source.hideInactivePlayers
  profile.inactiveAfterMonths = source.inactiveAfterMonths
  profile.anomalyThreshold = source.anomalyThreshold
  profile.minGPSlice = source.minGPSlice
  profile.epgpRulesSource = source.epgpRulesSource
  profile.minimap.hide = source.minimapHidden
  characterSettings.epgpJournalProfile = source.journalProfile ~= "" and source.journalProfile or nil
  applyLootRules(profile.guildPricing, source.guildPricing)
end

function createLootRulesExchangeControls(parent, anchor, onApplied)
  local panel = makePanel(parent)
  panel:SetSize(1000, 150)
  panel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
  local lootRulesEdit

  local exportButton = makeButton(panel, "Экспорт", 82, 22, function()
    local rules = db.profile.guildPricing
    rules.categoryMultipliers = rules.categoryMultipliers or {}
    rules.categoryNames = rules.categoryNames or {}
    lootRulesEdit:SetText(serializeLootRules(rules))
    lootRulesEdit:SetCursorPosition(0)
    lootRulesEdit:SetFocus()
  end)
  exportButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -6)
  local importButton = makeButton(panel, "Импорт", 82, 22, function()
    local rules, err = parseLootRules(lootRulesEdit:GetText())
    if not rules then
      setStatus(err)
      return
    end
    applyLootRules(db.profile.guildPricing, rules)
    onApplied()
    setStatus("Правила добычи импортированы.")
  end)
  importButton:SetPoint("RIGHT", exportButton, "LEFT", -4, 0)
  local loadFileButton = makeButton(panel, "Из файла", 82, 22, function()
    if type(BearyWatchLootRules) ~= "table" then
      setStatus("Файл BearyWatch_LootRules.lua не загружен.")
      return
    end
    local fileRules = {}
    for key, value in pairs(BearyWatchLootRules) do
      fileRules[key] = value
    end
    applyLootRules(db.profile.guildPricing, fileRules)
    onApplied()
    setStatus("Правила из BearyWatch_LootRules.lua применены.")
  end)
  loadFileButton:SetPoint("RIGHT", importButton, "LEFT", -4, 0)

  local lootRulesScroll = CreateFrame("ScrollFrame", nil, panel)
  lootRulesScroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -32)
  lootRulesScroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 8)
  lootRulesScroll:EnableMouseWheel(true)
  lootRulesEdit = CreateFrame("EditBox", nil, lootRulesScroll)
  lootRulesEdit:SetMultiLine(true)
  lootRulesEdit:SetAutoFocus(false)
  lootRulesEdit:SetMaxLetters(30000)
  lootRulesEdit:SetFontObject(ChatFontNormal)
  lootRulesEdit:SetWidth(970)
  lootRulesEdit:SetHeight(300)
  lootRulesEdit:SetTextInsets(8, 8, 8, 8)
  lootRulesEdit:SetTextColor(0.94, 0.88, 0.72)
  lootRulesEdit:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  lootRulesEdit:SetBackdropColor(0.10, 0.075, 0.035, 1)
  lootRulesEdit:SetBackdropBorderColor(0.42, 0.32, 0.16, 1)
  lootRulesEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  lootRulesScroll:SetScrollChild(lootRulesEdit)
  lootRulesScroll:SetScript("OnMouseWheel", function(self, delta)
    local maximum = math.max(lootRulesEdit:GetHeight() - self:GetHeight(), 0)
    self:SetVerticalScroll(math.max(0, math.min(maximum, self:GetVerticalScroll() - delta * 24)))
  end)
end
