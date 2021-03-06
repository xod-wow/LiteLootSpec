--[[----------------------------------------------------------------------------

  LiteLootSpec

  Copyright 2019-2020 Mike Battersby

  LiteLootSpec is free software: you can redistribute it and/or modify it under
  the terms of the GNU General Public License, version 2, as published by
  the Free Software Foundation.

  LiteLootSpec is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
  more details.

  The file LICENSE.txt included with LiteLootSpec contains a copy of the
  license. If the LICENSE.txt file is missing, you can find a copy at
  http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt

----------------------------------------------------------------------------]]--

LiteLootSpec = CreateFrame('Frame')
LiteLootSpec:RegisterEvent('PLAYER_LOGIN')
LiteLootSpec:SetScript('OnEvent',
    function (self, e, ...)
        if self[e] then self[e](self, ...) end
    end)

local defaults = {
    specByKey = { },
}

local function tMerge(t, ref)
    for k,v in pairs(ref) do
        if type(v) == 'table' then
            t[k] = t[k] or {}
            tMerge(t[k], v)
        elseif t[k] ~= v then
            t[k] = v
        end
    end
end

local function tStrip(t, ref)
    for k in pairs(t) do
        if t[k] == ref[k] then
            t[k] = nil
        elseif type(t[k]) == 'table' then
            if next(t[k]) == nil then
                t[k] = nil
            elseif type(ref[k]) == 'table' then
                tStrip(t[k], ref[k])
            end
        end
    end
end

function LiteLootSpec:LoadSettings()
    local dbKey = UnitGUID('player')
    LiteLootSpecDB = LiteLootSpecDB or { }
    LiteLootSpecDB[dbKey] = LiteLootSpecDB[dbKey] or {}
    self.db = LiteLootSpecDB[dbKey]
    tMerge(self.db, defaults)
    self.db.info = { UnitFullName('player') }
end

function LiteLootSpec:CleanSettings()
    tStrip(self.db, defaults)
    if next(self.db) == 'info' and next(self.db, 'info') == nil then
        local dbKey = UnitGUID('player')
        LiteLootSpecDB[dbKey] = nil
    end
end

-- EJ instances arent the same as the returns from GetInstanceInfo()
function LiteLootSpec:GetCurrentEJInstance()
    local mapID = C_Map.GetBestMapForUnit('player')
    local instance = mapID and EJ_GetInstanceForMap(mapID) or 0
    return instance
end

function LiteLootSpec:GetCurrentDifficulty()
    local difficulty = select(3, GetInstanceInfo())
    return self.difficultyTexts[difficulty] or ALL
end

function LiteLootSpec:GetBossInfoFromEJ()
    if EncounterJournal and
       EncounterJournal:IsVisible() and
       EncounterJournal.encounterID then
        local _, name = EJ_GetCreatureInfo(1)
        local mapID, _, hasDifficulty = select(7, EJ_GetInstanceInfo())
        local instance, diffID = 0, 0
        if hasDifficulty then
            instance = mapID and EJ_GetInstanceForMap(mapID) or 0
            diffID = EJ_GetDifficulty()
        end
        return name, instance, self.difficultyTexts[diffID] or ALL
    end
end

function LiteLootSpec:GetUnitNPCID(unit)
    local guid = UnitGUID(unit)
    if guid then return guid:sub(-17, -12) end
end

function LiteLootSpec:GetLootSpecText(n)
    local sex = UnitSex('player')
    local txt
    if n == 0 then
        local specIndex = GetSpecialization()
        local _, name = GetSpecializationInfo(specIndex, nil, nil, nil, sex);
        txt = format(LOOT_SPECIALIZATION_DEFAULT, name)
    elseif n == nil then
        txt = NONE
    else
        local _, name = GetSpecializationInfoByID(n, sex)
        txt = name or UNKNOWN
    end
    return YELLOW_FONT_COLOR_CODE .. txt .. FONT_COLOR_CODE_CLOSE
end

function LiteLootSpec:GetDifficultyText(n)
    if n == nil or n == 0 then return ALL end
    return self.difficultyTexts[n] or UNKNOWN
end
        
function LiteLootSpec:GetNPCText(name)
    name = name or NONE
    return YELLOW_FONT_COLOR_CODE .. name .. FONT_COLOR_CODE_CLOSE
end

function LiteLootSpec:Print(...)
    local f = SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
    f:AddMessage('|cff00ff00LiteLootSpec:|r ' .. format(...))
end

function LiteLootSpec:Message(...)
    self:Print(...)
    local txt = format(...)
    UIErrorsFrame:AddMessage('LiteLootSpec\n'..txt, 0.1, 1.0, 0.1)
end

function LiteLootSpec:ApplyWantedSpec()
    if GetNumSpecializations() == 0 then
        return
    end

    local curSpec = GetSpecializationInfo(GetSpecialization())
    local curLootSpec = GetLootSpecialization() or 0

    local wantedLootSpec = self.wantedLootSpec or self.userSetLootSpec or 0
    local wantedText = self:GetLootSpecText(wantedLootSpec)

    if wantedLootSpec == curLootSpec then
        return
    end

    if curLootSpec == 0 and wantedLootSpec == curSpec then
        local curText = self:GetLootSpecText(0)
        return
    end

    SetLootSpecialization(wantedLootSpec)
    self:Message('Loot spec set to ' ..wantedText)
end

function LiteLootSpec:PLAYER_LOGIN()
    self:LoadSettings()

    -- Putting this as a dependency makes it fail as it tries to load
    -- before GetSpecialization returns anything.
    LoadAddOn("Blizzard_EncounterJournal")

    self.difficultyTexts = { }
    for k,v in pairs(_G) do
        if type(v) == 'string' then
            if k:match('^DUNGEON_DIFFICULTY[0-9]') then
                local info = UnitPopupButtons[k]
                if info then self.difficultyTexts[info.difficultyID] = info.text
                end
            elseif k:match('^RAID_DIFFICULTY[0-9]') then
                local info = UnitPopupButtons[k]
                if info then
                    self.difficultyTexts[info.difficultyID] = info.text
                end
            end
        end
    end

    self.wantedLootSpec = nil
    self:PLAYER_LOOT_SPEC_UPDATED()

    self:RegisterEvent('PLAYER_TARGET_CHANGED')
    self:RegisterEvent('UPDATE_MOUSEOVER_UNIT')
    self:RegisterEvent('PLAYER_LOOT_SPEC_UPDATED')
    self:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED')
    self:RegisterEvent('INSTANCE_ENCOUNTER_ENGAGE_UNIT')

    -- Remove the defaults from what we save
    self:RegisterEvent('PLAYER_LOGOUT')
end

function LiteLootSpec:PLAYER_LOGOUT()
    self:CleanSettings()
end

function LiteLootSpec:Key(npcName, instance, difficulty)
    return format('%s-%s-%s', npcName, instance, difficulty or ALL)
end

function LiteLootSpec:Clear(npcName, instance, difficulty)
    local key = self:Key(npcName, instance, difficulty)
    self:Print('Clearing spec for %s (%s)',
            self:GetNPCText(npcName),
            difficulty
        )
    self.db.specByKey[key] = nil
end

function LiteLootSpec:Set(npcName, instance, difficulty, spec)
    local key = self:Key(npcName, instance, difficulty)
    self:Print('Setting spec %s (%d) for %s (%s)',
            self:GetLootSpecText(spec),
            spec,
            self:GetNPCText(npcName),
            difficulty
        )
    self.db.specByKey[key] = {
            npcName = npcName,
            instance = instance,
            difficulty = difficulty,
            spec = spec
        }
end

function LiteLootSpec:Iterate()
    local keys = {}
    for k,v in pairs(self.db.specByKey) do table.insert(keys, k) end
    table.sort(keys)
    local i = 0
    return function ()
            i = i + 1
            if keys[i] then
                return i, self.db.specByKey[keys[i]]
            end
        end
end

function LiteLootSpec:Get(npcName, instance, difficulty)
    local key 

    -- First look for an ALL difficulties key
    for _,d in ipairs({ ALL, difficulty }) do
        key = self:Key(npcName, instance, d)
        if self.db.specByKey[key] then
            return self.db.specByKey[key].spec
        end
    end
    return nil
end

function LiteLootSpec:Wipe()
    wipe(self.db.specByKey)
end

function LiteLootSpec:CheckUnit(unit)
    if not UnitExists(unit) then
        return
    end

    -- Really want to check that the unit is meaningful here
    if UnitIsDead(unit) then
        return
    end

    local targetLevel = UnitEffectiveLevel(unit)
    local playerLevel = UnitEffectiveLevel('player')

    if targetLevel > 0 and targetLevel - playerLevel < 2 then
        return
    end

    local npcName = UnitName(unit)
    local difficulty = self:GetCurrentDifficulty()
    local instance = self:GetCurrentEJInstance()

    self.wantedLootSpec = self:Get(npcName, instance, difficulty)
    self:ApplyWantedSpec()
end

function LiteLootSpec:INSTANCE_ENCOUNTER_ENGAGE_UNIT()
    for i = 1, MAX_BOSS_FRAMES do
        self:CheckUnit("boss"..i)
    end
end

function LiteLootSpec:PLAYER_TARGET_CHANGED()
    self:CheckUnit('target')
end

function LiteLootSpec:UPDATE_MOUSEOVER_UNIT()
    self:CheckUnit('mouseover')
end

function LiteLootSpec:PLAYER_SPECIALIZATION_CHANGED()
    self:ApplyWantedSpec()
end

function LiteLootSpec:PLAYER_LOOT_SPEC_UPDATED()
    self.userSetLootSpec = GetLootSpecialization()
end

function LiteLootSpec:ParseSpecArg(arg)
    local n = tonumber(arg)

    if n then
        if n == 0 then
            return 0
        else
            local spec = GetSpecializationInfo(n)
            return spec
        end
    end

    local pattern = '^' .. arg:lower()
    for i = 1, GetNumSpecializations() do
        local spec, specName = GetSpecializationInfo(i)
        if specName:lower():match(pattern) then
            return spec
        end
    end
end

function LiteLootSpec:ParseDifficultyArg(arg)
    local n = tonumber(arg)
    if n then
        return self.difficultyTexts[n] or ALL
    end
    
    local pattern = '^' .. arg:lower()
    for k,v in pairs(self.difficultyTexts) do
        if v:lower():match(pattern) then
            return v
        end
    end
end

function LiteLootSpec:GetBossInfo()
    local npc, instance, difficulty = self:GetBossInfoFromEJ()
    if not npc then
        npc = UnitName('target')
        difficulty = self:GetCurrentDifficulty()
        instance = self:GetCurrentEJInstance()
    end
    return npc, instance, difficulty
end

function LiteLootSpec:SlashCommandHandler(argstr)
    local cmd, arg1 = strsplit(' ', strlower(argstr))
    if cmd == 'list' then
        self:Print('Current settings:')
        for i, info in self:Iterate() do
            self:Print('% 2d.  %s (%s instance %d) -> %s',
                    i,
                    self:GetNPCText(info.npcName),
                    info.difficulty,
                    info.instance,
                    self:GetLootSpecText(info.spec)
                )
        end
    elseif cmd == 'target' then
        local npcName, instance, difficulty = self:GetBossInfo()
        self:Print('Target: %s (%s instance %d)',
                self:GetNPCText(npcName),
                difficulty,
                instance
            )
    elseif cmd == 'clear' then
        local npc, instance, difficulty = self:GetBossInfo()
        if npc then
            if arg1 then
                difficulty = self:ParseDifficultyArg(arg1)
            end
            self:Clear(npc, instance, difficulty)
        end
    elseif cmd == 'set' and arg1 then
        local npc, instance, difficulty = self:GetBossInfo()
        if npc then
            local spec = self:ParseSpecArg(arg1)
            if arg2 then
                difficulty = self:ParseDifficultyArg(arg2)
            end
            self:Set(npc, instance, difficulty, spec)
        else
            self:Print('Target a boss or have it open in the Encounter Journal.')
        end
    elseif cmd == 'wipe' then
        self:Wipe()
    else
        self:Print('Usage:')
        self:Print('  /ls list')
        self:Print('  /ls set <spec>')
        self:Print('  /ls clear [<name>]')
        self:Print('  /ls wipe')
        self:Print('  /ls target')
    end
    return true
end

SLASH_LiteLootSpec1 = '/ls'
SlashCmdList['LiteLootSpec'] =
    function (arg)
        LiteLootSpec:SlashCommandHandler(arg)
    end
