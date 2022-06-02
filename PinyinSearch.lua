local _, Addon = ...

-- Create auto complete buttons

local autoCompleteFrame = CreateFrame("Frame", nil, UIParent, "TooltipBackdropTemplate")
autoCompleteFrame:SetPoint("CENTER")
autoCompleteFrame:EnableMouse(true)
autoCompleteFrame:SetClampedToScreen(true)
autoCompleteFrame:SetScript("OnShow", function(self)
    self.selectedIndex = 0
end)
autoCompleteFrame.buttonMargin = 10
autoCompleteFrame.buttonNum = 10

autoCompleteFrame.Title = autoCompleteFrame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
autoCompleteFrame.Title:SetPoint("TOPLEFT", 15, -autoCompleteFrame.buttonMargin)
autoCompleteFrame.Title:SetText(PRESS_TAB)

local function OnAutoCompleteButtonClick(self)
    local point, relativeTo = Addon.AutoCompleteFrame:GetPoint(1)
    if relativeTo and relativeTo:IsObjectType("EditBox") then
        relativeTo:SetText(self:GetText())
    end
end

for i = 1, autoCompleteFrame.buttonNum do
    local button = CreateFrame("Button", nil, autoCompleteFrame, "AutoCompleteButtonTemplate")
    button:SetScript("OnClick", OnAutoCompleteButtonClick)
    if i == 1 then
        button:SetPoint("TOP", autoCompleteFrame.Title, "BOTTOM", 0, -autoCompleteFrame.buttonMargin)
        button:SetPoint("LEFT", autoCompleteFrame, "LEFT", 0, 0)
    else
        button:SetPoint("TOPLEFT", autoCompleteFrame["Button" .. (i-1)], "BOTTOMLEFT", 0, -autoCompleteFrame.buttonMargin)
    end
    autoCompleteFrame["Button" .. i] = button
end

function autoCompleteFrame:UpdateSize()
    local buttonHeight = self.Title:GetHeight() +  self.buttonMargin * 2
    local buttonWidth = 120
    for i =1, self.buttonNum do
        local button = self["Button" .. i]
        if button:IsShown() then
            buttonHeight = buttonHeight + button:GetHeight() + self.buttonMargin
            buttonWidth = math.max(buttonWidth, button:GetFontString():GetWidth() + 30)
        else
            break
        end
    end

    self:SetSize(buttonWidth, buttonHeight)
end

function autoCompleteFrame:Display(editbox)
    self:UpdateSize()
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", editbox, "BOTTOMLEFT", 0, -5)
    self:SetFrameStrata("DIALOG")
    self:SetToplevel(true)
    self:Show()
end

function autoCompleteFrame:Update(editbox, results)
    if results and #results > 0 then
        for i = 1, self.buttonNum do
            local result = results[i]
            local button = self["Button" .. i]
            if result then
                button:SetText(result)
                button:UnlockHighlight()
                button:Show()
            else
                button:Hide()
            end
        end
        self:Display(editbox)
    else
        self:Hide()
    end
end

function autoCompleteFrame:GetSelectedValue()
    if self.selectedIndex then
        local button = self["Button" .. self.selectedIndex]
        if button then
            return button:GetText()
        end
    end
end

function autoCompleteFrame:GetAutoCompleteSize()
    local count = 0
    for i = 1, self.buttonNum do
        local button = self["Button" .. i]
        if button:IsVisible() then
            count = count + 1
        end
    end
    return count
end

function autoCompleteFrame:ChangeSelectedItem()
    self.selectedIndex = (self.selectedIndex or 0) % self:GetAutoCompleteSize() + 1
    for i = 1, self.buttonNum do
        local button = self["Button" .. i]
        if i == self.selectedIndex then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
    end
end

Addon.AutoCompleteFrame = autoCompleteFrame

local function CompareResult(a, b)
    return strlen(a) < strlen(b)
end

local task = {}

function task:Cancel()
    self.EditBox = nil

    if self.Future then
        self.Future:Cancel()
        self.Future = nil
    end
end

function task:Start(editbox, func)
    if not editbox then return end
    self.EditBox = editbox

    self.Future = C_Timer.NewTimer(0.33, func)
end

Addon.Task = task

local function GetRegexPinyin(pinyin)
    return ".*" .. string.gsub(pinyin, ".", function(key) return key .. ".*" end)
end

local function FoundResult()
    local editbox = Addon.Task.EditBox
    if not editbox then return end

    local text = editbox:GetText()
    local results = {}
    if text and strlen(text) >= 2 and not Addon.IsAllChinese(text) then
        local complePinyins, firstLetterPinyins = Addon.Pinyin(text)

        if #complePinyins > 0 then
            local source = editbox.pinyinSource
            -- 兼容幻化
            if source.GetSrc then
                source = source:GetSrc()
                if not source then
                    Addon.AutoCompleteFrame:Hide()
                    return
                end
            end

            local count, maxCount = 0, Addon.AutoCompleteFrame.buttonNum

            -- 检查首字母，完全匹配
            for _, pinyin in ipairs(firstLetterPinyins) do
                if count >= maxCount then break end

                local foundResults = source.FirstLetterPinyins[pinyin]
                if foundResults then
                    for result, _ in pairs(foundResults) do
                        tinsert(results, result)
                        results[result] = true
                        count = count + 1
                    end
                end
            end
            sort(results, CompareResult)

            -- 非完全匹配为低优先级，需要进行排序
            local lowPriorityResults = {}

            -- 检查首字母，模糊匹配
            for _, pinyin in ipairs(firstLetterPinyins) do
                if count >= maxCount then break end
                
                for firstLetterPinyin, foundResults in pairs(source.FirstLetterPinyins) do
                    if firstLetterPinyin ~= pinyin and firstLetterPinyin:match(pinyin) then
                        for result, _ in pairs(foundResults) do
                            if not results[result] and not lowPriorityResults[result] then
                                lowPriorityResults[result] = true
                                tinsert(lowPriorityResults, result)
                                count = count + 1
                            end
                        end
                    end
                end
            end

            -- 检查所有拼音，通配
            for _, pinyin in ipairs(complePinyins) do
                if count >= maxCount then break end

                local regex = GetRegexPinyin(pinyin)
                for completePinyin, foundResults in pairs(source.CompletePinyins) do
                    if completePinyin:match(regex) then
                        for result, _ in pairs(foundResults) do
                            if not results[result] and not lowPriorityResults[result] then
                                lowPriorityResults[result] = true
                                tinsert(lowPriorityResults, result)
                                count = count + 1
                            end
                        end
                    end
                end
            end

            sort(lowPriorityResults, CompareResult)
            
            -- 将低优先级结果填充到结果集
            for _, result in ipairs(lowPriorityResults) do
                tinsert(results, result)
            end
        end
    end
    Addon.AutoCompleteFrame:Update(editbox, results)
end

local function OnTextChanged(self, userInput)
    Addon.Task:Cancel()

    if userInput then
        Addon.Task:Start(self, FoundResult)
    else
        if not self.displayTextOnTabPressed then
            Addon.AutoCompleteFrame:Hide()
        end
    end
end

local function OnEscapePressed(self)
    if Addon.AutoCompleteFrame:IsVisible() then
        Addon.AutoCompleteFrame:Hide()
    end
end

local function OnHide(self)
    if Addon.AutoCompleteFrame:IsVisible() then
        Addon.AutoCompleteFrame:Hide()
    end
end

local function OnEnterPressed(self)
    if Addon.AutoCompleteFrame:IsVisible() then
        local value = Addon.AutoCompleteFrame:GetSelectedValue()
        if value then
            self:SetText(value)
        end
    end
end

local function OnTabPressed(self)
    if Addon.AutoCompleteFrame:IsVisible() then
        Addon.AutoCompleteFrame:ChangeSelectedItem()
    end
    if self.displayTextOnTabPressed then
        OnEnterPressed(self)
    end
end

-- @displayTextOnTabPressed 当tab切换时，将选中结果显示在editbox
function Addon.AttachEditBox(editbox, source,  displayTextOnTabPressed)
    if editbox.pinyinAttach then return end

    editbox.pinyinAttach = true
    if editbox.Instructions then
        editbox.Instructions:SetText("支持拼音搜索")
    end
    editbox.displayTextOnTabPressed = displayTextOnTabPressed
    editbox.pinyinSource = source
    editbox:HookScript("OnTextChanged", OnTextChanged)
    editbox:HookScript("OnEscapePressed", OnEscapePressed)
    editbox:HookScript("OnEnterPressed", OnEnterPressed)
    editbox:HookScript("OnTabPressed", OnTabPressed)
    editbox:HookScript("OnHide", OnHide)
end

function Addon:EnableFeature(type)
    local feature = self[type]

    local funcName, table = feature:GetHookFuncName()
    if funcName then
        hooksecurefunc(table or _G, funcName, function(...)
            feature:Update(...)
        end)
    end
    self.AttachEditBox(feature:GetEditBox(), feature)
end

-- 预处理
local function Update(self, ...)
    if not Addon.LibLoaded then return end

    local interval = self:GetUpdateInterval()
    if interval and GetTime() - (self.UpdateTime or 0) < interval then
        return
    end

    self.UpdateTime = GetTime()
    self:UpdateData(...)
end

local function GetUpdateInterval(self)
    return 6
end

local function createFeature(type)
    local feature = Addon[type]
    if not feature then
        feature = {}
        feature.CompletePinyins = {}
        feature.FirstLetterPinyins = {}
        feature.Update = Update
        feature.GetUpdateInterval = GetUpdateInterval
        Addon[type] = feature
    end
    return feature
end

local function saveData(src, name)
    local completePinyins, firstLetterPinyins = Addon.Pinyin(name)
    if #completePinyins > 0 then
        src[name] = true
        for _, letter in ipairs(completePinyins) do
            src.CompletePinyins[letter] = src.CompletePinyins[letter] or {}
            src.CompletePinyins[letter][name] = true
        end
        for _, letter in ipairs(firstLetterPinyins) do
            src.FirstLetterPinyins[letter] = src.FirstLetterPinyins[letter] or {}
            src.FirstLetterPinyins[letter][name] = true
        end
    end
end

-------------------------------------------------------
--                      PetJournal                   --
-------------------------------------------------------

local Pet = createFeature("Pet")

function Pet:UpdateData()
    local numPets = C_PetJournal.GetNumPets()
    for i = 1, numPets do
        local petID, speciesID, owned, customName, level, favorite, isRevoked, speciesName = C_PetJournal.GetPetInfoByIndex(i)
        if speciesName and not self[speciesName] then
            saveData(self, speciesName)
        end
    end
end

function Pet:GetEditBox()
    return PetJournal.searchBox
end

function Pet:GetHookFuncName()
    return "PetJournal_UpdatePetList"
end

-------------------------------------------------------
--                   MountJournal                    --
-------------------------------------------------------

local Mount = createFeature("Mount")

function Mount:UpdateData()
    local numMounts = C_MountJournal.GetNumMounts()
    for i = 1, numMounts do
        local name = C_MountJournal.GetDisplayedMountInfo(i)
        if name and not self[name] then
            saveData(self, name)
        end
    end
end

function Mount:GetEditBox()
    return MountJournal.searchBox
end

function Mount:GetHookFuncName()
    return "MountJournal_UpdateMountList"
end

-------------------------------------------------------
--                   ToyBox                          --
-------------------------------------------------------

local Toy = createFeature("Toy")

function Toy:UpdateData()
    local numToys = C_ToyBox.GetNumTotalDisplayedToys()
    for i = 1, numToys do
        local toyId = C_ToyBox.GetToyFromIndex(i)
        if toyId then
            local _, name = C_ToyBox.GetToyInfo(toyId)
            if name and not self[name] then
                saveData(self, name)
            end
        end
    end
end

function Toy:GetEditBox()
    return ToyBox.searchBox
end

function Toy:GetHookFuncName()
    return "ToyBox_UpdatePages"
end

-------------------------------------------------------
--                  Appearance                       --
-------------------------------------------------------

local Appearance = createFeature("Appearance")

function Appearance:UpdateData()
    if not WardrobeCollectionFrame or not WardrobeCollectionFrame:IsVisible() then return end

    -- 外观：物品
    if WardrobeCollectionFrame.activeFrame == WardrobeCollectionFrame.ItemsCollectionFrame then
        local category = category or WardrobeCollectionFrame.ItemsCollectionFrame.activeCategory
        local transmogLocation = WardrobeCollectionFrame.ItemsCollectionFrame.transmogLocation
        if not category or not transmogLocation then return end
        
        local src = self[category]
        if not src then
            src = {}
            src.CompletePinyins = {}
            src.FirstLetterPinyins = {}
            self[category] = src
        end

        local visualsList = C_TransmogCollection.GetCategoryAppearances(category, transmogLocation)
        for _, visualInfo in ipairs(visualsList) do
            if visualInfo.visualID then
                local sources = C_TransmogCollection.GetAppearanceSources(visualInfo.visualID, category, transmogLocation)
                for _, source in ipairs(sources) do
                    if source.name and not src[source.name] then
                        saveData(src, source.name)
                    end
                end
            end
        end
    -- 外观：套装
    else
        local category = "set"
        local src = self[category]
        if not src then
            src = {}
            src.CompletePinyins = {}
            src.FirstLetterPinyins = {}
            self[category] = src
        end
        
        local sets = C_TransmogSets.GetBaseSets()
        for _, setInfo in ipairs(sets) do
            if setInfo.name and not src[setInfo.name] then
                saveData(src, setInfo.name)
            end
            if setInfo.label and not src[setInfo.label] then
                saveData(src, setInfo.label)
            end

            local variantSets = C_TransmogSets.GetVariantSets(setInfo.setID)
            if variantSets then
                for _, variantSetInfo in ipairs(variantSets) do
                    if variantSetInfo.name and not src[variantSetInfo.name] then
                        saveData(src, variantSetInfo.name)
                    end
                    if variantSetInfo.label and not src[variantSetInfo.label] then
                        saveData(src, variantSetInfo.label)
                    end
                end
            end
        end
    end
end

function Appearance:GetEditBox()
    return WardrobeCollectionFrame.SearchBox
end

function Appearance:GetHookFuncName()
    return nil
end

function Appearance:GetSrc()
    local category
    if WardrobeCollectionFrame.activeFrame == WardrobeCollectionFrame.ItemsCollectionFrame then
        category = WardrobeCollectionFrame.ItemsCollectionFrame.activeCategory
    else
        category = "set"
    end
    return self[category]
end

function Appearance:GetUpdateInterval() end

-------------------------------------------------------
--                  TradeSkill                       --
-------------------------------------------------------

local TradeSkill = createFeature("TradeSkill")

function TradeSkill:UpdateData()
    local _, _, _, _, _, baseSkillLineID = C_TradeSkillUI.GetTradeSkillLine()
    if not baseSkillLineID then return end

    local recipes = C_TradeSkillUI.GetAllRecipeIDs()
    if not recipes then return end

    local src = self[baseSkillLineID]
    if not src then
        src = {}
        src.CompletePinyins = {}
        src.FirstLetterPinyins = {}
        self[baseSkillLineID] = src
    end

    for _, recipeId in ipairs(recipes) do
        local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeId)
        if recipeInfo then
            if recipeInfo and not src[recipeInfo.name] then
                saveData(src, recipeInfo.name)
            end

            for i = 1, C_TradeSkillUI.GetRecipeNumReagents(recipeId) do
                local name = C_TradeSkillUI.GetRecipeReagentInfo(recipeId, i)
                if name and not src[name] then
                    saveData(src, name)
                end
            end
        end
    end
end

function TradeSkill:GetEditBox()
    return TradeSkillFrame.SearchBox
end

function TradeSkill:GetHookFuncName()
    return "OnDataSourceChanged", TradeSkillFrame
end

function TradeSkill:GetUpdateInterval()
    return 0.1
end

function TradeSkill:GetSrc()
    local _, _, _, _, _, baseSkillLineID = C_TradeSkillUI.GetTradeSkillLine()
    return self[baseSkillLineID]
end

-------------------------------------------------------
--                   GuildBank                       --
-------------------------------------------------------

local GuildBank = createFeature("GuildBank")

function GuildBank:UpdateData()
    local tab = GetCurrentGuildBankTab()
    if tab and tab >= 1 then
        for i=1, 98 do
            local link = GetGuildBankItemLink(tab, i)
            if link then
                local name = GetItemInfo(link)
                if name and not self[name] then
                    saveData(self, name)
                end
            end
        end
    end
end

function GuildBank:GetEditBox()
    return GuildItemSearchBox
end

function GuildBank:GetHookFuncName() end

function GuildBank:GetUpdateInterval() end

-------------------------------------------------------
--                   Container                       --
-------------------------------------------------------

local Container = createFeature("Container")

function Container:UpdateData()
    for i = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        for j = 1, GetContainerNumSlots(i) do
            local itemId = GetContainerItemID(i, j)
            if itemId then
                local name = GetItemInfo(itemId)
                if name and not self[name] then
                    saveData(self, name)
                end
            end
        end
    end

    if BankFrame:IsVisible() then
        for i = 1, GetContainerNumSlots(BANK_CONTAINER) do
            local itemId = GetContainerItemID(BANK_CONTAINER, i)
            if itemId then
                local name = GetItemInfo(itemId)
                if name and not self[name] then
                    saveData(self, name)
                end
            end
        end

        for i = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
            for j = 1, GetContainerNumSlots(i) do
                local itemId = GetContainerItemID(i, j)
                if itemId then
                    local name = GetItemInfo(itemId)
                    if name and not self[name] then
                        saveData(self, name)
                    end
                end
            end
        end
    end
end

function Container:GetEditBox()
    return BagItemSearchBox
end

function Container:GetHookFuncName() end

function Container:GetUpdateInterval()
    return 0.1
end

Addon:EnableFeature("Container")

-------------------------------------------------------
--                   Addons                          --
-------------------------------------------------------

local addons = {
    Blizzard_Collections                    = function()
        Addon:EnableFeature("Pet")
        Addon:EnableFeature("Mount")
        Addon:EnableFeature("Toy")
        Addon:EnableFeature("Appearance")
    end,
    Blizzard_GuildBankUI                    = function()
        Addon:EnableFeature("GuildBank")
    end,
    Blizzard_TradeSkillUI                   = function()
        Addon:EnableFeature("TradeSkill")
    end,
    Bagnon                                  = function()
        -- hook searchframe
        local oldSearchFrameNew = Bagnon.SearchFrame.New
        Bagnon.SearchFrame.New = function(self, parent)
            local searchFrame = oldSearchFrameNew(self, parent)
            local parentName = parent:GetName()
            if parentName and parentName:match("BagnonInventoryFrame") then
                Addon.AttachEditBox(searchFrame, Addon["Container"])
            end
            return searchFrame
        end

        -- hook bagframe
        local oldFrameNew = Bagnon.Frame.New
        Bagnon.Frame.New = function(self, id)
            local frame = oldFrameNew(self, id)
            local frameName = frame:GetName()
            if frameName and frameName:match("BagnonInventoryFrame") then
                frame:HookScript("OnShow", function()
                    Addon["Container"]:Update()
                end)
            end
            return frame
        end
    end,
    Combuctor                               = function()
        -- hook bagframe
        local oldFrameNew = Combuctor.Frame.New
        Combuctor.Frame.New = function(self, id)
            local frame = oldFrameNew(self, id)
            local frameName = frame:GetName()
            if frameName and frameName:match("CombuctorInventoryFrame") then
                Addon.AttachEditBox(frame.searchBox, Addon["Container"])
                frame:HookScript("OnShow", function()
                    Addon["Container"]:Update()
                end)
            end
            return frame
        end
    end,
    NDui                                    = function()
        local oldFunc =  NDui.cargBags.plugins["SearchBar"]
        NDui.cargBags.plugins["SearchBar"] = function(...)
            local searchBox = oldFunc(...)
            if searchBox == NDui_BackpackBag.Search then
                Addon.AttachEditBox(searchBox, Addon["Container"], true)
                searchBox:HookScript("OnShow", function()
                    Addon["Container"]:Update()
                end)
            end
            return searchBox
        end
    end
}

function Addon:CompactAddons(name)
    if name then
        local func = addons[name]
        if func then
            func()
        end
    else
        for addonName, func in pairs(addons) do
            if IsAddOnLoaded(addonName) then
                func()
            end
        end
    end
end

Addon:CompactAddons()

-------------------------------------------------------
--                   Event                           --
-------------------------------------------------------

local frame = CreateFrame("Frame")
frame:Hide()
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("BANKFRAME_OPENED")
frame:RegisterEvent("TRANSMOG_COLLECTION_ITEM_UPDATE")
frame:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
frame:RegisterEvent("TRANSMOG_SEARCH_UPDATED")
frame:SetScript("OnEvent", function(self, event, param1)
    if event == "ADDON_LOADED" then
        Addon:CompactAddons(param1)
    elseif event == "BANKFRAME_OPENED" then
        Addon["Container"]:Update()
    elseif event == "TRANSMOG_COLLECTION_UPDATED" or event == "TRANSMOG_COLLECTION_ITEM_UPDATE" or "TRANSMOG_SEARCH_UPDATED" then
        Addon["Appearance"]:Update()
    end
end)

EventRegistry:RegisterCallback("ContainerFrame.AllBagsOpened", function() Addon["Container"]:Update() end, frame)
EventRegistry:RegisterCallback("PinyinSearchLib.Complete", function() Addon.LibLoaded = true end, frame)