local addon = _G.BearyWatch
if type(addon) ~= "table" or type(addon.environment) ~= "table" then
  error("BearyWatch shared environment was not initialized.")
end
setfenv(1, addon.environment)
local function queueVisibleRefresh()
  local frame = addon.eventFrame
  if frame.refreshScheduled then
    return
  end
  if guildRosterRefreshAt and GetTime() < guildRosterRefreshAt then
    frame.refreshScheduled = true
    frame:SetScript("OnUpdate", function(self)
      self:SetScript("OnUpdate", nil)
      self.refreshScheduled = nil
      queueVisibleRefresh()
    end)
    return
  end
  frame.refreshScheduled = true
  frame:SetScript("OnUpdate", function(self)
    self:SetScript("OnUpdate", nil)
    self.refreshScheduled = nil
    if not window or not window:IsShown() then
      return
    end
    local rosterChanged = classRosterRefreshPending
    local rosterFinished = true
    if classRosterRefreshPending then
      rosterFinished = refreshClassRoster()
      if rosterFinished then
        classRosterRefreshPending = false
        refreshClassFilterControls()
      end
    end
    if historyRefreshPending then
      readHistory()
    end
    if settingsPanel and settingsPanel:IsShown() and refreshPricingRuleLists then
      refreshPricingRuleLists()
    end
    updateCurrentBalanceText()
    if timelinePanel and timelinePanel:IsShown() then
      updatePlayerDropdown()
      drawChart()
    end
    if itemDropdownMenu and itemDropdownMenu:IsShown() then
      updateItemDropdown()
    end
    if efficiencyPanel and efficiencyPanel:IsShown() then
      renderEfficiency()
    end
    if itemPanel and itemPanel:IsShown() then
      if rosterChanged and bossLoot.updateControls then
        bossLoot.updateControls()
      end
      renderItemAnalysis()
    end
    if dropLinePanel and dropLinePanel:IsShown() then
      drawDropLineChart()
    end
    if rosterWindow and rosterWindow:IsShown() and updateRosterWindow then
      updateRosterWindow()
    end
    if not rosterFinished then
      queueVisibleRefresh()
    end
  end)
end

function createWindowFooter()
  statusText = makeText(window, "", "GameFontNormalSmall")
  statusText:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 18, 17)
  hiddenCountText = makeText(window, "", "GameFontNormalSmall")
  hiddenCountText:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -18, 17)
  hiddenCountText:SetJustifyH("RIGHT")
  hiddenCountText:SetTextColor(0.68, 0.73, 0.76)
  statusText:SetPoint("RIGHT", hiddenCountText, "LEFT", -12, 0)
  statusText:SetJustifyH("LEFT")
  statusText:SetTextColor(0.68, 0.73, 0.76)
  setStatus(historyStatus)

  window:SetScript("OnShow", function()
    if not addon.eventFrame.guildRosterRequested and GuildRoster then
      addon.eventFrame.guildRosterRequested = true
      GuildRoster()
    end
    classRosterRefreshPending = true
    historyRefreshPending = true
    queueVisibleRefresh()
    selectTab(activeTab or db.profile.selectedTab or "timeline")
    if activeTab ~= "timeline" then
      updateCurrentBalanceText()
    end
  end)
  window:SetScript("OnHide", function()
    restoreSavedPlayerSelection = true
    playerDropdownMenu:Hide()
    if journalSourceMenu then
      journalSourceMenu:Hide()
    end
    if itemDropdownMenu then
      itemDropdownMenu:Hide()
    end
    if itemSearch then
      itemSearch:ClearFocus()
    end
    if rosterWindow then
      rosterWindow:Hide()
    end
  end)
end

function toggleWindow()
  if not window then
    createWindowBase()
    createTimelineUI()
    createWindowFooter()
  end
  if window:IsShown() then
    window:Hide()
  else
    window:Show()
  end
end

local function positionMinimapButton(angle)
  local radius = Minimap:GetWidth() * 0.5 + 6
  local radians = math.rad(angle)
  minimapButton:ClearAllPoints()
  minimapButton:SetPoint("CENTER", Minimap, "CENTER",
    math.cos(radians) * radius, math.sin(radians) * radius)
end

local function updateMinimapButtonAngle()
  local cursorX, cursorY = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  cursorX, cursorY = cursorX / scale, cursorY / scale
  local centerX, centerY = Minimap:GetCenter()
  local deltaX, deltaY = cursorX - centerX, cursorY - centerY
  if deltaX == 0 and deltaY == 0 then
    return
  end
  local angle = math.deg(math.atan2(deltaY, deltaX))
  db.profile.minimap.angle = angle
  positionMinimapButton(angle)
end

function createMinimapButton()
  if not Minimap then
    return
  end
  minimapButton = CreateFrame("Button", "BearyWatchMinimapButton", Minimap)
  minimapButton:SetSize(31, 31)
  minimapButton:RegisterForClicks("LeftButtonUp")
  minimapButton:RegisterForDrag("LeftButton")
  minimapButton:SetMovable(true)
  minimapButton:SetFrameStrata("MEDIUM")
  minimapButton:SetFrameLevel(Minimap:GetFrameLevel() + 2)
  minimapButton:SetToplevel(true)
  minimapButton:EnableMouse(true)
  positionMinimapButton(tonumber(db.profile.minimap.angle) or 45)
  minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture("Interface\\AddOns\\BearyWatch\\Media\\BearyWatchMinimap.tga")
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER")

  local border = minimapButton:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 0, 0)

  minimapButton:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
      self.dragStartX, self.dragStartY = GetCursorPosition()
    end
  end)
  minimapButton:SetScript("OnDragStart", function(self)
    self.isDragging = true
    self:SetScript("OnUpdate", function()
      updateMinimapButtonAngle()
    end)
  end)
  minimapButton:SetScript("OnDragStop", function(self)
    if self.isDragging then
      updateMinimapButtonAngle()
      self.isDragging = nil
      self:SetScript("OnUpdate", nil)
    end
  end)
  minimapButton:SetScript("OnClick", function(self, button)
    if button ~= "LeftButton" then
      return
    end
    if self.dragStartX and self.dragStartY then
      local cursorX, cursorY = GetCursorPosition()
      local deltaX = cursorX - self.dragStartX
      local deltaY = cursorY - self.dragStartY
      self.dragStartX, self.dragStartY = nil, nil
      if deltaX * deltaX + deltaY * deltaY > 25 then
        return
      end
    end
    toggleWindow()
  end)
  minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("BearyWatch")
    GameTooltip:AddLine("Аналитика EPGP", 0.75, 0.78, 0.80)
    GameTooltip:Show()
  end)
  minimapButton:SetScript("OnLeave", GameTooltip_Hide)
  if db.profile.minimap.hide then
    minimapButton:Hide()
  end
end

addon.eventFrame = CreateFrame("Frame")
addon.eventFrame:RegisterEvent("PLAYER_LOGIN")
addon.eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
addon.eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
addon.eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
addon.eventFrame:RegisterEvent("INSPECT_READY")
addon.eventFrame:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_LOGIN" then
    db = LibStub("AceDB-3.0"):New("BearyWatchDB", DEFAULTS, true)
    local savedLoot = db.char.bossLoot
    if type(savedLoot) == "table" then
      if type(savedLoot.isRaid) == "boolean" then
        bossLoot.isRaid = savedLoot.isRaid
      end
      bossLoot.tier = savedLoot.tier or bossLoot.tier
      bossLoot.tierName = savedLoot.tierName
      bossLoot.instanceId = savedLoot.instanceId
      bossLoot.instanceName = savedLoot.instanceName
      bossLoot.encounterId = savedLoot.encounterId
      bossLoot.encounterName = savedLoot.encounterName
      bossLoot.difficultyId = savedLoot.difficultyId
      bossLoot.difficultyName = savedLoot.difficultyName
      bossLoot.classId = savedLoot.classId
      if savedLoot.competitorScope == "auto" or savedLoot.competitorScope == "raid" or
        savedLoot.competitorScope == "guild" then
        bossLoot.competitorScope = savedLoot.competitorScope
      end
      if type(savedLoot.excludedItems) == "table" then
        bossLoot.excludedItems = savedLoot.excludedItems
      end
    end
    itemLoaderTooltip = CreateFrame("GameTooltip", "BearyWatchItemLoaderTooltip", UIParent, "GameTooltipTemplate")
    createMinimapButton()
    local logModule = EPGP and EPGP.GetModule and EPGP:GetModule("log", true)
    if logModule and logModule.RegisterCallback then
      logModule:RegisterCallback("LogChanged", function()
        historyRefreshPending = true
        if not window or not window:IsShown() then
          return
        end
        queueVisibleRefresh()
      end)
    else
      setStatus("Не удалось подписаться на обновления журнала EPGP.")
    end
    local journalPollFrame = CreateFrame("Frame")
    addon.journalPollFrame = journalPollFrame
    local journalPollElapsed = 0
    local journalPollSignature
    journalPollFrame:SetScript("OnUpdate", function(_, elapsed)
      journalPollElapsed = journalPollElapsed + elapsed
      if journalPollElapsed < 5 then
        return
      end
      journalPollElapsed = 0
      if not window or not window:IsShown() or not dropLinePanel or not dropLinePanel:IsShown() then
        return
      end
      local log, journalSource = getSavedLog()
      local count = type(log) == "table" and #log or 0
      local latest = count > 0 and log[count] or nil
      local latestTimestamp = type(latest) == "table" and latest[1] or nil
      local signature = tostring(journalSource and journalSource.key or "") .. ":" ..
        tostring(count) .. ":" .. tostring(latestTimestamp)
      if journalPollSignature and journalPollSignature ~= signature then
        historyRefreshPending = true
        readHistory()
        drawDropLineChart()
      end
      journalPollSignature = signature
    end)
    _G.SLASH_BEARYWATCH1 = "/bw"
    _G.SLASH_BEARYWATCH2 = "/bearywatch"
    SlashCmdList.BEARYWATCH = toggleWindow
  elseif event == "INSPECT_READY" then
    bossLoot.handleInspectReady(...)
  elseif event == "RAID_ROSTER_UPDATE" then
    if itemPanel and itemPanel:IsShown() and bossLoot.mode and
      bossLoot.view == "competitors" then
      bossLoot.updateControls()
      renderItemAnalysis()
    end
  elseif event == "GUILD_ROSTER_UPDATE" then
    classRosterRefreshPending = true
    rankSnapshotsDirty = true
    guildRosterRefreshAt = GetTime() + 1
    if window and window:IsShown() then
      queueVisibleRefresh()
    end
  elseif event == "GET_ITEM_INFO_RECEIVED" then
    local itemId = ...
    if itemId and requestedItemIcons[itemId] then
      requestedItemIcons[itemId] = nil
      if window and window:IsShown() then
        queueVisibleRefresh()
      end
    end
  end
end)
