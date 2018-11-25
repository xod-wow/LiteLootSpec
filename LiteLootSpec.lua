--[[----------------------------------------------------------------------------
  LiteLootSpec
----------------------------------------------------------------------------]]--

LiteLootSpec = CreateFrame('Frame')
LiteLootSpec:RegisterEvent('PLAYER_LOGIN')
LiteLootSpec:SetScript('OnEvent',
    function (self, e, ...)
        if self[e] then self[e](self, e, ...) end
    end)

local defaults = {
    specByKey = { },
}

function LiteLootSpec:MergeDefaults()
    for k,v in pairs(defaults) do
        if not self.db[k] then
            if type(v) == 'table' then
                self.db[k] = CopyTable(v)
            else
                self.db[k] = v
            end
        end
    end
end

function LiteLootSpec:GetBossInfoFromEJ()
    if EncounterJournal and
       EncounterJournal:IsVisible() and
       EncounterJournal.encounterID then
        local _, name = EJ_GetCreatureInfo(1)
        local hasDifficulty = select(9, EJ_GetInstanceInfo())
        local instance, difficulty = 0, 0
        if hasDifficulty then
            instance = select(6, EJ_GetEncounterInfo(EncounterJournal.encounterID))
            difficulty = EJ_GetDifficulty()
        end
        return name, instance, difficulty
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
    local cur = DEFAULT_CHAT_FRAME
    for i = 1,NUM_CHAT_WINDOWS do
        local f = _G['ChatFrame'..i]
        if f and f:IsVisible() then
            cur = f
            break
        end
    end

    cur:AddMessage('|cff00ff00LiteLootSpec:|r ' .. format(...))
end

function LiteLootSpec:Message(...)
    self:Print(...)
    local txt = format(...)
    UIErrorsFrame:AddMessage(txt, 0.1, 1.0, 0.1)
end

function LiteLootSpec:ApplyWantedSpec()
    if GetNumSpecializations() == 0 then
        return
    end

    local curSpec = GetSpecializationInfo(GetSpecialization())
    local curLootSpec = GetLootSpecialization() or 0

    local wantedLootSpec = self.wantedLootSpec or self.userSetLootSpec or 0

    if wantedLootSpec == curLootSpec then
        return
    end

    if curLootSpec == 0 and wantedLootSpec == curSpec then
        return
    end

    SetLootSpecialization(wantedLootSpec)
    self:Message('Changing loot spec to ' .. self:GetLootSpecText(wantedLootSpec))
end

function LiteLootSpec:PLAYER_LOGIN()
    local key = UnitGUID('player')

    LiteLootSpecDB = LiteLootSpecDB or { }
    LiteLootSpecDB[key] = LiteLootSpecDB[key] or {}
    self.db = LiteLootSpecDB[key]
    self:MergeDefaults()

    self.db.info = { UnitFullName('player') }

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
                    self.difficultyTexts[info.difficultyID] = format('%s %s', info.text, RAID)
                end
            end
        end
    end

    self.wantedLootSpec = nil
    -- Is this necessary? PLAYER_LOOT_SPEC_UPDATED is probably fired early
    self.userSetLootSpec = GetLootSpecialization()
    self:RegisterEvent('PLAYER_TARGET_CHANGED')
    self:RegisterEvent('PLAYER_LOOT_SPEC_UPDATED')
    self:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED')
end

function LiteLootSpec:Key(npcName, instance, difficulty)
    return format('%s-%s-%s', npcName, instance, tostring(difficulty))
end

function LiteLootSpec:Clear(npcName, instance, difficulty)
    local key = self:Key(npcName, instance, difficulty)
    self:Print('Clearing spec for %s (%s)',
            self:GetNPCText(npcName),
            self:GetDifficultyText(difficulty)
        )
    self.db.specByKey[key] = nil
end

function LiteLootSpec:Set(npcName, instance, difficulty, spec)
    local key = self:Key(npcName, instance, difficulty)
    self:Print('Setting spec %s (%d) for %s (%s)',
            self:GetLootSpecText(spec),
            spec,
            self:GetNPCText(npcName),
            self:GetDifficultyText(difficulty)
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
    local i = 0
    return function ()
            i = i + 1
            return keys[i], self.db.specByKey[keys[i]]
        end
end

function LiteLootSpec:Get(npcName, instance, difficulty)
    local key 

    -- First look for an ALL difficulties key
    for d in pairs({ nil, difficulty }) do
        key = self:Key(npcName, instance, d)
        if self.db.specByKey[key] then
            return self.db.specByKey[npcName].spec
        end
    end
    return nil
end

function LiteLootSpec:Wipe()
        wipe(self.db.specByKey)
end

function LiteLootSpec:PLAYER_TARGET_CHANGED()
    if not UnitExists('target') then
        return
    end

    -- Really want to check that the target is meaningful here
    if UnitIsDead('target') or UnitEffectiveLevel('target') > 0 then
        return
    end

    local npcName = UnitName('target')

    local difficulty = select(3, GetInstanceInfo())
    local mapID = C_Map.GetBestMapForUnit("player")
    local instance = mapID and EJ_GetInstanceForMap(mapID) or 0

    self.wantedLootSpec = self:Get(npcName, instance, difficulty)
    self:ApplyWantedSpec()
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
        if n == 0 then
            return nil
        else
            return n
        end
    end
    
    local pattern = '^' .. arg:lower()
    for k,v in pairs(self.difficultyTexts) do
        if v:lower():match(pattern) then
            return k
        end
    end
end

function LiteLootSpec:GetBossInfo()
    local npc, instance, difficulty = self:GetBossInfoFromEJ()
    if not npc then
        npc = UnitName('target')
        difficulty,_,_,_,_,_,instance = select(3, GetInstanceInfo())
    end
    return npc, instance, difficulty
end

function LiteLootSpec:SlashCommandHandler(argstr)
    local cmd, arg1 = strsplit(' ', strlower(argstr))
    if cmd == 'list' then
        self:Print('Current settings:')
        for key, info in self:Iterate() do
            self:Print('  %s (%s) -> %s',
                   self:GetNPCText(info.npcName),
                   self:GetDifficultyText(info.difficulty),
                   self:GetLootSpecText(info.spec)
                )
        end
    elseif cmd == 'target' then
        local npc, instance, difficulty = self:GetBossInfo()
        self:Print('Target npc = %s (%s)',
                self:GetNPCText(npc),
                self:GetDifficultyText(difficulty)
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
