local _, Addon = ...

-- Create auto complete buttons

local autoCompleteFrame = CreateFrame("Frame", nil, UIParent, "TooltipBackdropTemplate")
autoCompleteFrame:SetPoint("CENTER")
autoCompleteFrame:EnableMouse(true)
autoCompleteFrame:SetScript("OnShow", function(self)
    self.selectedIndex = 0
end)
autoCompleteFrame.buttonMargin = 10
autoCompleteFrame.buttonNum = 5

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

local function OnTextChanged(self, userInput)
    if userInput then
        local text = self:GetText()
        local results = {}
        if text and strlen(text) >= 2 then
            local pinyin = Addon.Pinyin(text)
            if pinyin then
                for k, v in pairs(self.pinyinSource) do
                    if v:match(pinyin) then
                        tinsert(results, k)
                    end
                end
            end
        end
        sort(results, CompareResult)
        Addon.AutoCompleteFrame:Update(self, results)
    else
        Addon.AutoCompleteFrame:Hide()
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

local function OnTabPressed(self)
    if Addon.AutoCompleteFrame:IsVisible() then
        Addon.AutoCompleteFrame:ChangeSelectedItem()
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

function Addon.AttachEditBox(editbox, source)
    if editbox.Instructions then
        editbox.Instructions:SetText("支持拼音首字母")
    end
    editbox.pinyinSource = source
    editbox:HookScript("OnTextChanged", OnTextChanged)
    editbox:HookScript("OnEscapePressed", OnEscapePressed)
    editbox:HookScript("OnEnterPressed", OnEnterPressed)
    editbox:HookScript("OnTabPressed", OnTabPressed)
    editbox:HookScript("OnHide", OnHide)
end

-------------------------------------------------------
--                      PetJournal                   --
-------------------------------------------------------

local PetPinyins = {}

local function UpdatePetJournalData(self)
    local numPets = C_PetJournal.GetNumPets()
    for i = 1, numPets do
        local petID, speciesID, owned, customName, level, favorite, isRevoked, speciesName = C_PetJournal.GetPetInfoByIndex(i)
        if speciesName and not PetPinyins[speciesName] then
            local pinyin = Addon.Pinyin(speciesName)
            PetPinyins[speciesName] = pinyin
        end
    end
end

function Addon.EnablePetJournal()
    hooksecurefunc("PetJournal_UpdatePetList", UpdatePetJournalData)
    Addon.AttachEditBox(PetJournal.searchBox, PetPinyins)
end


-------------------------------------------------------
--                   MountJournal                    --
-------------------------------------------------------

local MountPinyins = {}

local function UpdateMountJournalData(self)
    local numMounts = C_MountJournal.GetNumMounts()
    for i = 1, numMounts do
        local name = C_MountJournal.GetDisplayedMountInfo(i)
        if name and not MountPinyins[name] then
            local pinyin = Addon.Pinyin(name)
            MountPinyins[name] = pinyin
        end
    end
end

function Addon.EnableMountJournal()
    hooksecurefunc("MountJournal_UpdateMountList", UpdateMountJournalData)
    Addon.AttachEditBox(MountJournal.searchBox, MountPinyins)
end

-------------------------------------------------------
--                   ToyBox                          --
-------------------------------------------------------

local ToyPinyins = {}

local function UpdateToyBoxData(self)
    local numToys = C_ToyBox.GetNumTotalDisplayedToys()
    for i = 1, numToys do
        local toyId = C_ToyBox.GetToyFromIndex(i)
        if toyId then
            local _, name = C_ToyBox.GetToyInfo(toyId)
            if name and not ToyPinyins[name] then
                local pinyin = Addon.Pinyin(name)
                ToyPinyins[name] = pinyin
            end
        end
    end
end

function Addon.EnableToyBox()
    hooksecurefunc("ToyBox_UpdatePages", UpdateToyBoxData)
    Addon.AttachEditBox(ToyBox.searchBox, ToyPinyins)
end

-------------------------------------------------------
--                   GuildBank                       --
-------------------------------------------------------

local GuildBankPinyins = {}

local function UpdateGuildBankData(self)
    local tab = GetCurrentGuildBankTab()
    if tab and tab >= 1 then
        for i=1, 98 do
            local link = GetGuildBankItemLink(tab, i)
            if link then
                local name = GetItemInfo(link)
                if name and not GuildBankPinyins[name] then
                    local pinyin = Addon.Pinyin(name)
                    GuildBankPinyins[name] = pinyin
                end
            end
        end
    end
end

function Addon.EnableGuildBank()
    hooksecurefunc(GuildBankFrame, "Update", UpdateGuildBankData)
    Addon.AttachEditBox(GuildItemSearchBox, GuildBankPinyins)
end

-------------------------------------------------------
--                   Container                       --
-------------------------------------------------------

local ContainerPinyins = {}

function Addon.UpdateBagData()
    for i = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        for j = 1, GetContainerNumSlots(i) do
            local itemId = GetContainerItemID(i, j)
            if itemId then
                local name = GetItemInfo(itemId)
                if name and not ContainerPinyins[name] then
                    local pinyin = Addon.Pinyin(name)
                    ContainerPinyins[name] = pinyin
                end
            end
        end
    end

    if BankFrame:IsVisible() then
        for i = 1, GetContainerNumSlots(BANK_CONTAINER) do
            local itemId = GetContainerItemID(BANK_CONTAINER, i)
            if itemId then
                local name = GetItemInfo(itemId)
                if name and not ContainerPinyins[name] then
                    local pinyin = Addon.Pinyin(name)
                    ContainerPinyins[name] = pinyin
                end
            end
        end

        for i = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
            for j = 1, GetContainerNumSlots(i) do
                local itemId = GetContainerItemID(i, j)
                if itemId then
                    local name = GetItemInfo(itemId)
                    if name and not ContainerPinyins[name] then
                        local pinyin = Addon.Pinyin(name)
                        ContainerPinyins[name] = pinyin
                    end
                end
            end
        end
    end
end

Addon.AttachEditBox(BagItemSearchBox, ContainerPinyins)


-------------------------------------------------------
--                   Event                           --
-------------------------------------------------------

local frame = CreateFrame("Frame")
frame:Hide()
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("BANKFRAME_OPENED")
frame:SetScript("OnEvent", function(self, event, param1)
    if event == "ADDON_LOADED" and param1 == "Blizzard_Collections" then
        Addon.EnablePetJournal()
        Addon.EnableMountJournal()
        Addon.EnableToyBox()
    elseif event == "ADDON_LOADED" and param1 == "Blizzard_GuildBankUI" then
        Addon.EnableGuildBank()
    elseif event == "BANKFRAME_OPENED" then
        Addon.UpdateBagData()
    end
end)

EventRegistry:RegisterCallback("ContainerFrame.AllBagsOpened", Addon.UpdateBagData, frame)