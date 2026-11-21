local addon = _G.BearyWatch
if type(addon) ~= "table" or type(addon.environment) ~= "table" then
  error("BearyWatch shared environment was not initialized.")
end
setfenv(1, addon.environment)
function createWindowBase()
  window = CreateFrame("Frame", "BearyWatchMainFrame", UIParent)
  window:SetSize(1200, 650)
  window:SetPoint("CENTER")
  window:SetFrameStrata("DIALOG")
  window:SetMovable(true)
  window:EnableMouse(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", window.StopMovingOrSizing)
  window:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  window:SetBackdropColor(0.045, 0.055, 0.065, 0.98)
  window:SetBackdropBorderColor(0.22, 0.30, 0.34, 1)
  window:Hide()

  local title = makeText(window, "BearyWatch | Аналитика EPGP", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", window, "TOPLEFT", 18, -16)
  title:SetTextColor(0.78, 0.88, 0.92)

  currentBalanceText = makeText(window, "", "GameFontNormalSmall")
  currentBalanceText:SetPoint("TOPLEFT", window, "TOPLEFT", 310, -20)
  currentBalanceText:SetPoint("TOPRIGHT", window, "TOPRIGHT", -52, -20)
  currentBalanceText:SetJustifyH("LEFT")
  currentBalanceText:SetTextColor(0.78, 0.84, 0.87)

  local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function() window:Hide() end)

  local rosterButton = makeButton(window, "Персонажи", 94, 26, function() selectTab("roster") end)
  rosterButton:SetPoint("TOPLEFT", window, "TOPLEFT", 18, -48)
  local dropLineTab = makeButton(window, "Дроп-лайн", 96, 26, function() selectTab("dropLine") end)
  dropLineTab:SetPoint("LEFT", rosterButton, "RIGHT", 6, 0)
  local analyticsTab = makeButton(window, "Аналитика", 100, 26, function() selectTab("analytics") end)
  analyticsTab:SetPoint("LEFT", dropLineTab, "RIGHT", 6, 0)
  local settingsTab = makeButton(window, "Настройки", 100, 26, function() selectTab("settings") end)
  settingsTab:SetPoint("LEFT", analyticsTab, "RIGHT", 6, 0)
  local projectTab = makeButton(window, "О проекте", 94, 26, function() selectTab("project") end)
  projectTab:SetPoint("LEFT", settingsTab, "RIGHT", 6, 0)

  local timelineTab = makeButton(window, "Динамика", 110, 24, function() selectTab("timeline") end)
  local efficiencyTab = makeButton(window, "Эффективность", 130, 24, function() selectTab("efficiency") end)
  efficiencyTab:SetPoint("TOPLEFT", analyticsTab, "BOTTOMLEFT", 0, -6)
  local itemTab = makeButton(window, "Лут", 84, 24, function() selectTab("items") end)
  timelineTab:SetPoint("LEFT", efficiencyTab, "RIGHT", 6, 0)
  itemTab:SetPoint("LEFT", timelineTab, "RIGHT", 6, 0)
  analyticsSubtabButtons = {
    timeline = timelineTab,
    efficiency = efficiencyTab,
    items = itemTab,
  }
  for _, button in ipairs({ rosterButton, dropLineTab, analyticsTab, settingsTab,
    projectTab, timelineTab, efficiencyTab, itemTab }) do
    button:EnableMouse(true)
    button:SetFrameLevel(window:GetFrameLevel() + 5)
  end
  timelineTab:Hide()
  efficiencyTab:Hide()
  itemTab:Hide()
  tabButtons = {
    roster = rosterButton,
    dropLine = dropLineTab,
    analytics = analyticsTab,
    settings = settingsTab,
    project = projectTab,
  }

  local rangeFromLabel = makeText(window, "Период с ", "GameFontNormalSmall")
  rangeFromEdit = makeDateEditBox(window)
  rangeFromEdit:SetWidth(78)
  local rangeToLabel = makeText(window, " по ", "GameFontNormalSmall")
  rangeToEdit = makeDateEditBox(window)
  rangeToEdit:SetWidth(78)
  local applyRangeButton = makeButton(window, "Показать", 64, 24, applyDateRange)

  rangeFromEdit:SetScript("OnEnterPressed", function(self)
    applyDateRange()
    self:ClearFocus()
  end)
  rangeToEdit:SetScript("OnEnterPressed", function(self)
    applyDateRange()
    self:ClearFocus()
  end)
  rangeFromEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  rangeToEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

  local presets = {
    { label = "3 мес.", days = 90 },
    { label = "6 мес.", days = 180 },
    { label = "12 мес.", days = 365 },
    { label = "Всё", days = nil },
  }
  local previousPresetButton
  for index = #presets, 1, -1 do
    local preset = presets[index]
    local days = preset.days
    local button = makeButton(window, preset.label, 46, 24, function()
      setQuickRange(days)
    end)
    if not previousPresetButton then
      button:SetPoint("TOPRIGHT", window, "TOPRIGHT", -18, -48)
    else
      button:SetPoint("RIGHT", previousPresetButton, "LEFT", -4, 0)
    end
    previousPresetButton = button
  end
  applyRangeButton:ClearAllPoints()
  applyRangeButton:SetPoint("RIGHT", previousPresetButton, "LEFT", -8, 0)
  rangeToEdit:SetPoint("RIGHT", applyRangeButton, "LEFT", -6, 0)
  rangeToLabel:SetPoint("RIGHT", rangeToEdit, "LEFT", -6, 0)
  rangeFromEdit:SetPoint("RIGHT", rangeToLabel, "LEFT", -4, 0)
  rangeFromLabel:SetPoint("RIGHT", rangeFromEdit, "LEFT", -4, 0)
end

function createTimelineUI()
  timelinePanel = makePanel(window)
  timelinePanel:SetPoint("TOPLEFT", window, "TOPLEFT", 16, -112)
  timelinePanel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -16, 48)
  local rangeHint = makeText(timelinePanel,
    "Быстрые кнопки задают диапазон; «Показать» применяет введённые даты.",
    "GameFontDisableSmall")
  rangeHint:SetPoint("TOPRIGHT", timelinePanel, "TOPRIGHT", -18, -8)
  rangeHint:SetTextColor(0.58, 0.64, 0.67)

  local playerLabel = makeText(timelinePanel, "Игроки:", "GameFontNormalSmall")
  playerLabel:SetPoint("TOPLEFT", timelinePanel, "TOPLEFT", 18, -18)

  playerDropdown = makeButton(timelinePanel, "Выбрать игроков", 220, 26, togglePlayerDropdown)
  playerDropdown:SetPoint("TOPLEFT", playerLabel, "TOPLEFT", 48, 5)

  playerDropdownMenu = makePanel(window)
  playerDropdownMenu:SetFrameStrata("DIALOG")
  playerDropdownMenu:SetFrameLevel(window:GetFrameLevel() + 20)
  playerDropdownMenu:SetWidth(232)
  playerDropdownMenu:SetPoint("TOPLEFT", playerDropdown, "BOTTOMLEFT", 0, -3)
  playerDropdownMenu:Hide()

  local clearPlayerSelection = makeButton(playerDropdownMenu, "Снять выбор", 88, 22, function()
    selectedPlayers = {}
    selectedPlayer = nil
    db.profile.timelinePlayers = selectedPlayers
    rankSnapshotsDirty = true
    updatePlayerDropdown()
    if activeTab == "items" then
      bossLoot.mode = false
      bossLoot.view = "loot"
      bossLoot.updateControls()
      updateItemDropdown()
      renderItemAnalysis()
    elseif drawChart then
      drawChart()
    end
  end)
  clearPlayerSelection:SetPoint("TOPRIGHT", playerDropdownMenu, "TOPRIGHT", -8, -8)

  local finishPlayerSelection = makeButton(playerDropdownMenu, "Готово", 56, 22, function()
    playerDropdownMenu:Hide()
  end)
  finishPlayerSelection:SetPoint("RIGHT", clearPlayerSelection, "LEFT", -4, 0)

  playerSearch = CreateFrame("EditBox", nil, playerDropdownMenu, "InputBoxTemplate")
  playerSearch:SetSize(108, 24)
  playerSearch:SetPoint("TOPLEFT", playerDropdownMenu, "TOPLEFT", 10, -8)
  playerSearch:SetAutoFocus(false)
  playerSearch:SetMaxLetters(48)
  playerSearch:SetFontObject(GameFontHighlightSmall)
  playerSearch:SetTextInsets(6, 6, 0, 0)
  playerSearchHint = playerDropdownMenu:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  playerSearchHint:SetPoint("LEFT", playerSearch, "LEFT", 8, 0)
  playerSearchHint:SetText("Поиск...")
  playerSearchHint:SetTextColor(0.55, 0.58, 0.61)
  playerSearchHint:Show()
  playerSearch:SetScript("OnTextChanged", function()
    if playerSearch:GetText() == "" and not playerSearch:HasFocus() then
      playerSearchHint:Show()
    else
      playerSearchHint:Hide()
    end
    updatePlayerDropdown()
  end)
  playerSearch:SetScript("OnEditFocusGained", function()
    playerSearchHint:Hide()
  end)
  playerSearch:SetScript("OnEditFocusLost", function()
    if playerSearch:GetText() == "" then
      playerSearchHint:Show()
    else
      playerSearchHint:Hide()
    end
  end)
  playerSearch:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    playerDropdownMenu:Hide()
  end)

  playerDropdownScroll = CreateFrame("ScrollFrame", nil, playerDropdownMenu)
  playerDropdownScroll:SetPoint("TOPLEFT", playerDropdownMenu, "TOPLEFT", 4, -36)
  playerDropdownScroll:SetPoint("BOTTOMRIGHT", playerDropdownMenu, "BOTTOMRIGHT", -4, 4)
  playerDropdownScroll:EnableMouseWheel(true)
  playerDropdownScroll:SetScript("OnMouseWheel", function(self, delta)
    local maximum = math.max(playerDropdownContent:GetHeight() - self:GetHeight(), 0)
    local current = self:GetVerticalScroll()
    self:SetVerticalScroll(math.max(0, math.min(maximum, current - delta * 48)))
  end)
  playerDropdownContent = CreateFrame("Frame", nil, playerDropdownScroll)
  playerDropdownContent:SetWidth(220)
  playerDropdownContent:SetHeight(1)
  playerDropdownScroll:SetScrollChild(playerDropdownContent)

  for i, metric in ipairs({ "EP", "GP", "PR", "RANK" }) do
    local metricName = metric
    local buttonLabel = metricName == "RANK" and "Место" or metricName
    local button = makeButton(timelinePanel, buttonLabel, 55, 24, function()
      selectMetric(metricName)
    end)
    button:SetPoint("TOPLEFT", timelinePanel, "TOPLEFT", 340 + (i - 1) * 61, -18)
    metricButtons[metricName] = button
  end
  selectMetric(selectedMetric)

  classFilterButton = makeButton(timelinePanel, "Классы места 10/10", 122, 24, function()
    if classFilterMenu:IsShown() then
      classFilterMenu:Hide()
    else
      refreshClassFilterControls()
      classFilterMenu:Show()
    end
  end)
  classFilterButton:SetPoint("LEFT", metricButtons.RANK, "RIGHT", 8, 0)
  classFilterMenu = makePanel(timelinePanel)
  classFilterMenu:SetSize(218, 164)
  classFilterMenu:SetFrameStrata("DIALOG")
  classFilterMenu:SetFrameLevel(window:GetFrameLevel() + 20)
  classFilterMenu:SetPoint("TOPLEFT", classFilterButton, "BOTTOMLEFT", 0, -4)
  classFilterMenu:Hide()
  local classFilterTitle = makeText(classFilterMenu, "Фильтр классов графика «Место»", "GameFontNormalSmall")
  classFilterTitle:SetPoint("TOPLEFT", classFilterMenu, "TOPLEFT", 8, -8)
  classFilterTitle:SetTextColor(0.78, 0.84, 0.87)
  for index, option in ipairs(CLASS_OPTIONS) do
    local classOption = option
    local column = math.floor((index - 1) / 5)
    local rowIndex = (index - 1) % 5
    local row = makeButton(classFilterMenu, "", 102, 22, function()
      db.profile.classFilters[classOption.token] = db.profile.classFilters[classOption.token] == false
      rankSnapshotsDirty = true
      refreshClassFilterControls()
      drawChart()
    end)
    row:SetPoint("TOPLEFT", classFilterMenu, "TOPLEFT", 6 + column * 106, -28 - rowIndex * 22)
    classFilterRows[classOption.token] = row
  end
  local unknownClassHint = makeText(classFilterMenu,
    "Игроки с неизвестным классом всегда учитываются.", "GameFontDisableSmall")
  unknownClassHint:SetPoint("BOTTOMLEFT", classFilterMenu, "BOTTOMLEFT", 8, 7)
  refreshClassFilterControls()

  local legend = makeText(timelinePanel,
    "Перетаскивание — сдвиг; колесико — масштаб времени, Shift + колесико — вертикальный масштаб.",
    "GameFontNormalSmall")
  legend:SetPoint("TOPRIGHT", timelinePanel, "TOPRIGHT", -18, -42)
  legend:SetTextColor(0.58, 0.64, 0.67)

  rankListPanel = makePanel(timelinePanel)
  rankListPanel:SetWidth(220)
  rankListPanel:SetPoint("TOPLEFT", timelinePanel, "TOPLEFT", 12, -56)
  rankListPanel:SetPoint("BOTTOMLEFT", timelinePanel, "BOTTOMLEFT", 12, 30)
  rankListPanel:Hide()
  rankListTitle = makeText(rankListPanel, "Текущий рейтинг", "GameFontNormalSmall")
  rankListTitle:SetPoint("TOPLEFT", rankListPanel, "TOPLEFT", 8, -8)
  rankListTitle:SetTextColor(COLORS.RANK[1], COLORS.RANK[2], COLORS.RANK[3])
  rankListDate = makeText(rankListPanel, "", "GameFontDisableSmall")
  rankListDate:SetPoint("TOPRIGHT", rankListPanel, "TOPRIGHT", -8, -8)

  local rankNumberHeader = makeText(rankListPanel, "№", "GameFontNormalSmall")
  rankNumberHeader:SetPoint("TOPLEFT", rankListPanel, "TOPLEFT", 8, -34)
  local rankPlayerHeader = makeText(rankListPanel, "Персонаж", "GameFontNormalSmall")
  rankPlayerHeader:SetPoint("LEFT", rankNumberHeader, "LEFT", 28, 0)
  local rankPRHeader = makeText(rankListPanel, "PR", "GameFontNormalSmall")
  rankPRHeader:SetPoint("TOPRIGHT", rankListPanel, "TOPRIGHT", -8, -34)
  rankNumberHeader:SetTextColor(0.68, 0.73, 0.76)
  rankPlayerHeader:SetTextColor(0.68, 0.73, 0.76)
  rankPRHeader:SetTextColor(0.68, 0.73, 0.76)

  local rankListScroll = CreateFrame("ScrollFrame", nil, rankListPanel)
  rankListScroll:SetPoint("TOPLEFT", rankListPanel, "TOPLEFT", 6, -48)
  rankListScroll:SetPoint("BOTTOMRIGHT", rankListPanel, "BOTTOMRIGHT", -6, 6)
  rankListScroll:EnableMouseWheel(true)
  rankListContent = CreateFrame("Frame", nil, rankListScroll)
  rankListContent:SetWidth(206)
  rankListContent:SetHeight(1)
  rankListScroll:SetScrollChild(rankListContent)
  rankListScroll:SetScript("OnMouseWheel", function(self, delta)
    local maximum = math.max(rankListContent:GetHeight() - self:GetHeight(), 0)
    self:SetVerticalScroll(math.max(0, math.min(maximum, self:GetVerticalScroll() - delta * 36)))
  end)

  chart = CreateFrame("Frame", nil, timelinePanel)
  chart:ClearAllPoints()
  chart:SetPoint("TOPLEFT", timelinePanel, "TOPLEFT", 12, -88)
  chart:SetPoint("BOTTOMRIGHT", timelinePanel, "BOTTOMRIGHT", -12, -30)
  chart:EnableMouseWheel(true)
  chart:SetScript("OnMouseWheel", function(_, delta)
    if handleGraphWheel then
      handleGraphWheel(delta)
    end
  end)
  chart:EnableMouse(true)
  chart:SetScript("OnMouseDown", startChartPan)
  chart:SetScript("OnMouseUp", stopChartPan)
  chart:SetScript("OnSizeChanged", drawChart)
  local resetVerticalPanButton = makeButton(chart, "Автомасштаб", 92, 24, function()
    db.profile.valuePan[selectedMetric] = 0
    db.profile.valueZoom = db.profile.valueZoom or {}
    db.profile.valueZoom[selectedMetric] = 1
    drawChart()
  end)
  resetVerticalPanButton:SetPoint("TOPRIGHT", chart, "TOPRIGHT", -8, -8)
  resetVerticalPanButton:SetFrameLevel(chart:GetFrameLevel() + 10)
  graphScaleText = makeText(chart, "", "GameFontNormalSmall")
  graphScaleText:SetPoint("TOP", resetVerticalPanButton, "BOTTOM", 0, -3)
  graphScaleText:SetTextColor(0.82, 0.86, 0.88)

  rangeBar = CreateFrame("Frame", nil, timelinePanel)
  rangeBar:SetHeight(14)
  rangeBar:SetPoint("BOTTOMLEFT", timelinePanel, "BOTTOMLEFT", 18, 8)
  rangeBar:SetPoint("BOTTOMRIGHT", timelinePanel, "BOTTOMRIGHT", -18, 8)
  rangeBar:EnableMouse(true)
  rangeBar:EnableMouseWheel(true)
  rangeBar:SetMovable(true)
  rangeBar:RegisterForDrag("LeftButton")
  rangeBar.track = makeFlatTexture(rangeBar, "BACKGROUND", 0.19, 0.23, 0.27, 1)
  rangeBar.track:SetPoint("LEFT", rangeBar, "LEFT", 0, 0)
  rangeBar.track:SetPoint("RIGHT", rangeBar, "RIGHT", 0, 0)
  rangeBar.track:SetHeight(4)
  rangeBar.track:SetPoint("CENTER", rangeBar, "CENTER", 0, 0)
  rangeThumb = rangeBar:CreateTexture(nil, "ARTWORK")
  rangeThumb:SetTexture("Interface\\Buttons\\WHITE8X8")
  rangeThumb:SetVertexColor(0.30, 0.72, 1.00, 0.8)
  rangeThumb:SetHeight(12)
  rangeBar:SetScript("OnDragStart", startRangeDrag)
  rangeBar:SetScript("OnDragStop", stopRangeDrag)
  rangeBar:SetScript("OnMouseWheel", function(_, delta)
    if handleGraphWheel then
      handleGraphWheel(delta)
    end
  end)

  local rangeScaleHint = makeText(timelinePanel,
    "Нижняя шкала: перетаскивание — период; колесико — масштаб времени; Shift + колесико — вертикальный масштаб.",
    "GameFontNormalSmall")
  rangeScaleHint:SetPoint("BOTTOMLEFT", rangeBar, "TOPLEFT", 0, 5)
  rangeScaleHint:SetTextColor(0.58, 0.64, 0.67)
  local decayLegend = makeText(timelinePanel, "Decay / срез EP", "GameFontNormalSmall")
  decayLegend:SetPoint("BOTTOMRIGHT", rangeBar, "TOPRIGHT", 0, 5)
  decayLegend:SetTextColor(COLORS.DECAY[1], COLORS.DECAY[2], COLORS.DECAY[3])
  local anomalyLegend = makeText(timelinePanel, "Аномалия", "GameFontNormalSmall")
  anomalyLegend:SetPoint("RIGHT", decayLegend, "LEFT", -10, 0)
  anomalyLegend:SetTextColor(COLORS.ANOMALY[1], COLORS.ANOMALY[2], COLORS.ANOMALY[3])

  updateRankLayout = function()
    if not chart or not rangeBar then
      return
    end
    chart:ClearAllPoints()
    rangeBar:ClearAllPoints()
    if selectedMetric == "RANK" then
      rankListPanel:Show()
      legend:Hide()
      decayLegend:Hide()
      anomalyLegend:Hide()
      chart:SetPoint("TOPLEFT", timelinePanel, "TOPLEFT", 246, -64)
      chart:SetPoint("BOTTOMRIGHT", timelinePanel, "BOTTOMRIGHT", -12, -30)
      rangeBar:SetPoint("BOTTOMLEFT", timelinePanel, "BOTTOMLEFT", 252, 8)
      rangeBar:SetPoint("BOTTOMRIGHT", timelinePanel, "BOTTOMRIGHT", -18, 8)
    else
      rankListPanel:Hide()
      legend:Show()
      decayLegend:Show()
      anomalyLegend:Show()
      chart:SetPoint("TOPLEFT", timelinePanel, "TOPLEFT", 12, -64)
      chart:SetPoint("BOTTOMRIGHT", timelinePanel, "BOTTOMRIGHT", -12, -30)
      rangeBar:SetPoint("BOTTOMLEFT", timelinePanel, "BOTTOMLEFT", 18, 8)
      rangeBar:SetPoint("BOTTOMRIGHT", timelinePanel, "BOTTOMRIGHT", -18, 8)
    end
  end
  updateRankLayout()
end

createEfficiencyUI = function()
  efficiencyPanel = makePanel(window)
  efficiencyPanel:SetPoint("TOPLEFT", window, "TOPLEFT", 16, -112)
  efficiencyPanel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -16, 48)
  efficiencyPanel:Hide()

  local attendanceLabel = makeText(efficiencyPanel, "Посещение:", "GameFontNormalSmall")
  attendanceLabel:SetTextColor(0.78, 0.84, 0.87)
  attendancePeriodButtons = {}
  for _, days in ipairs({ 7, 14, 21, 30 }) do
    local periodDays = days
    local button = makeButton(efficiencyPanel, tostring(days), 38, 22, function()
      db.profile.attendancePeriodDays = periodDays
      renderEfficiency()
    end)
    button.periodDays = periodDays
    attendancePeriodButtons[#attendancePeriodButtons + 1] = button
  end
  attendancePeriodButtons[#attendancePeriodButtons]:SetPoint(
    "TOPRIGHT", efficiencyPanel, "TOPRIGHT", -18, -18)
  for index = #attendancePeriodButtons - 1, 1, -1 do
    attendancePeriodButtons[index]:SetPoint(
      "RIGHT", attendancePeriodButtons[index + 1], "LEFT", -4, 0)
  end
  attendanceLabel:SetPoint("RIGHT", attendancePeriodButtons[1], "LEFT", -8, 0)
  attendanceSourceText = makeText(efficiencyPanel, "", "GameFontNormalSmall")
  attendanceSourceText:SetPoint("RIGHT", attendanceLabel, "LEFT", -12, 0)
  attendanceSourceText:SetWidth(150)
  attendanceSourceText:SetJustifyH("RIGHT")
  attendanceSourceText:SetTextColor(0.68, 0.73, 0.76)

  local headers = {
    { key = "player", text = "Игрок", x = 10, width = 250 },
    { key = "alts", text = "Твинов", x = 265, width = 75 },
    { key = "items", text = "Вещей", x = 350, width = 85 },
    { key = "actualGP", text = "Факт. GP", x = 445, width = 115 },
    { key = "baseGP", text = "База GP", x = 575, width = 140 },
    { key = "efficiency", text = "Эффективность", x = 730, width = 150 },
    { key = "lootShare", text = "Доля добычи", x = 890, width = 130 },
    { key = "attendance", text = "Посещение", x = 1045, width = 80 },
  }
  efficiencyHeaderButtons = {}
  for _, header in ipairs(headers) do
    local headerKey = header.key
    local button = makeButton(efficiencyPanel, header.text, header.width, 24, function()
      if sortColumn == headerKey then
        sortDescending = not sortDescending
      else
        sortColumn = headerKey
        sortDescending = false
      end
      renderEfficiency()
    end)
    button:SetPoint("TOPLEFT", efficiencyPanel, "TOPLEFT", header.x, -42)
    efficiencyHeaderButtons[headerKey] = button
  end

  efficiencyScroll = CreateFrame("ScrollFrame", "BearyWatchEfficiencyScroll", efficiencyPanel, "UIPanelScrollFrameTemplate")
  efficiencyScroll:SetPoint("TOPLEFT", efficiencyPanel, "TOPLEFT", 12, -72)
  efficiencyScroll:SetPoint("BOTTOMRIGHT", efficiencyPanel, "BOTTOMRIGHT", -32, 12)
  efficiencyContent = CreateFrame("Frame", nil, efficiencyScroll)
  efficiencyContent:SetWidth(1120)
  efficiencyContent:SetHeight(1)
  efficiencyScroll:SetScrollChild(efficiencyContent)
end

createProjectUI = function()
  projectPanel = makePanel(window)
  projectPanel:SetPoint("TOPLEFT", window, "TOPLEFT", 16, -112)
  projectPanel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -16, 48)
  projectPanel:Hide()

  local topBanner = projectPanel:CreateTexture(nil, "ARTWORK")
  topBanner:SetTexture("Interface\\AddOns\\BearyWatch\\Media\\-1-1024.tga")
  topBanner:SetSize(1024, 128)
  topBanner:SetPoint("TOP", projectPanel, "TOP", 0, -16)

  local version = GetAddOnMetadata and GetAddOnMetadata("BearyWatch", "Version") or "1.0"
  local title = makeText(projectPanel, "BearyWatch  |  Версия " .. tostring(version), "GameFontNormalLarge")
  title:SetPoint("TOP", projectPanel, "TOP", 0, -156)
  title:SetJustifyH("CENTER")
  title:SetTextColor(0.78, 0.88, 0.92)

  local donationText = makeText(projectPanel,
    "Если вам понравился аддон, вы можете поддержать автора через внутриигровую почту или вне игры.",
    "GameFontNormal")
  donationText:SetPoint("TOP", title, "BOTTOM", 0, -12)
  donationText:SetWidth(700)
  donationText:SetJustifyH("CENTER")
  donationText:SetTextColor(0.88, 0.91, 0.94)

  local serverText = makeText(projectPanel, "Сервер x5  |  Медведж", "GameFontNormal")
  serverText:SetPoint("TOP", donationText, "BOTTOM", 0, -8)
  serverText:SetJustifyH("CENTER")
  serverText:SetTextColor(0.25, 0.72, 1.0)

  local qrTexture = projectPanel:CreateTexture(nil, "ARTWORK")
  qrTexture:SetTexture("Interface\\AddOns\\BearyWatch\\Media\\qr.tga")
  qrTexture:SetSize(128, 128)
  qrTexture:SetPoint("TOPRIGHT", projectPanel, "TOPRIGHT", -80, -166)

  local githubTexture = projectPanel:CreateTexture(nil, "ARTWORK")
  githubTexture:SetTexture("Interface\\AddOns\\BearyWatch\\Media\\github_logo_wh.tga")
  githubTexture:SetSize(128, 128)
  githubTexture:SetPoint("TOPLEFT", projectPanel, "TOPLEFT", 80, -166)

  local githubText = makeText(projectPanel, "GitHub проекта:", "GameFontNormalSmall")
  githubText:SetPoint("TOP", githubTexture, "BOTTOM", 0, -6)
  githubText:SetWidth(250)
  githubText:SetJustifyH("CENTER")
  githubText:SetTextColor(0.88, 0.91, 0.94)

  local githubLink = CreateFrame("EditBox", nil, projectPanel, "InputBoxTemplate")
  githubLink:SetSize(260, 24)
  githubLink:SetPoint("TOP", githubText, "BOTTOM", 0, -4)
  githubLink:SetText("https://github.com/bearlyfire/Bearywatch/")
  githubLink:SetAutoFocus(false)
  githubLink:SetJustifyH("CENTER")
  githubLink:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  githubLink:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

  local supportText = makeText(projectPanel,
    "Поддержать автора вне игры:",
    "GameFontNormalSmall")
  supportText:SetPoint("TOP", qrTexture, "BOTTOM", 0, -6)
  supportText:SetWidth(250)
  supportText:SetJustifyH("CENTER")
  supportText:SetTextColor(0.88, 0.91, 0.94)

  local cloudTipsLink = CreateFrame("EditBox", nil, projectPanel, "InputBoxTemplate")
  cloudTipsLink:SetSize(260, 24)
  cloudTipsLink:SetPoint("TOP", supportText, "BOTTOM", 0, -4)
  cloudTipsLink:SetText("https://pay.cloudtips.ru/p/aff01756")
  cloudTipsLink:SetAutoFocus(false)
  cloudTipsLink:SetJustifyH("CENTER")
  cloudTipsLink:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  cloudTipsLink:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

  local forumText = makeText(projectPanel,
    "Задать вопрос и оценить аддон можно в теме на форуме:",
    "GameFontNormal")
  forumText:SetPoint("TOP", projectPanel, "TOP", 0, -250)
  forumText:SetWidth(500)
  forumText:SetJustifyH("CENTER")
  forumText:SetTextColor(0.88, 0.91, 0.94)

  local forumLink = CreateFrame("EditBox", nil, projectPanel, "InputBoxTemplate")
  forumLink:SetSize(420, 24)
  forumLink:SetPoint("TOP", forumText, "BOTTOM", 0, -6)
  forumLink:SetText("https://forum.sirus.su/resources/bearywatch.652/")
  forumLink:SetAutoFocus(false)
  forumLink:SetJustifyH("CENTER")
  forumLink:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  forumLink:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

  local bottomBanner = projectPanel:CreateTexture(nil, "ARTWORK")
  bottomBanner:SetTexture("Interface\\AddOns\\BearyWatch\\Media\\-2-1024.tga")
  bottomBanner:SetSize(1024, 128)
  bottomBanner:SetPoint("BOTTOM", projectPanel, "BOTTOM", 0, 8)
end
