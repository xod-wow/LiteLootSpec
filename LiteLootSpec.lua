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
    specByNPC = { },
}

local function GetBossInfoFromEJ()
    if EncounterJournal and
       EncounterJournal:IsVisible() and
       EncounterJournal.encounterID then
        local _, name = EJ_GetCreatureInfo(1)
        local instance = select(6, EJ_GetEncounterInfo(EncounterJournal.encounterID))
        return name, instance
    end
end

local function GetUnitNPCID(unit)
    local guid = UnitGUID(unit)
    if guid then return guid:sub(-17, -12) end
end

local function GetLootSpecText(n)
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

local function GetNPCText(name)
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
    self:Message('Changing loot spec to ' .. GetLootSpecText(wantedLootSpec))
end

function LiteLootSpec:PLAYER_LOGIN()
    local key = UnitGUID('player')

    LiteLootSpecDB = LiteLootSpecDB or { }
    LiteLootSpecDB[key] = LiteLootSpecDB[key] or CopyTable(defaults)

    self.db = LiteLootSpecDB[key]

    self.db.info = { UnitFullName('player') }

    self.wantedLootSpec = nil
    -- Is this necessary? PLAYER_LOOT_SPEC_UPDATED is probably fired early
    self.userSetLootSpec = GetLootSpecialization()
    self:RegisterEvent('PLAYER_TARGET_CHANGED')
    self:RegisterEvent('PLAYER_LOOT_SPEC_UPDATED')
    self:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED')
end

function LiteLootSpec:PLAYER_TARGET_CHANGED()
    -- Really want to check that the target is meaningful here
    if UnitIsDead('target') or UnitEffectiveLevel('target') > 0 then
        return
    end

    local npcName = UnitName('target')
    local instance = select(8, GetInstanceInfo())

    if self.db.specByNPC[npcName] and
       self.db.specByNPC[npcName].instance == instance then
        self.wantedLootSpec = self.db.specByNPC[npcName].spec
    else
        self.wantedLootSpec = nil
    end
    self:ApplyWantedSpec()
end

function LiteLootSpec:PLAYER_SPECIALIZATION_CHANGED()
    self:ApplyWantedSpec()
end

function LiteLootSpec:PLAYER_LOOT_SPEC_UPDATED()
    self.userSetLootSpec = GetLootSpecialization()
end

local function ParseSpecArg(arg)
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

local function GetBossInfo()
    local npc, instance = GetBossInfoFromEJ()
    if not npc then
        npc = UnitName('target')
        instance = select(8, GetInstanceInfo())
    end
    return npc, instance
end

function LiteLootSpec:SlashCommandHandler(argstr)
    local cmd, arg1 = strsplit(' ', strlower(argstr))
    if cmd == 'list' then
        for npc, info in pairs(self.db.specByNPC) do
            self:Print('%s (instance %d) -> %d (%s)',
                   GetNPCText(npc),
                   info.instance,
                   info.spec,
                   GetLootSpecText(info.spec)
                )
        end
    elseif cmd == 'target' then
        local npc, instance = GetBossInfo()
        self:Print('Target npc = %s (instance %s)',
                GetNPCText(npc),
                tostring(instance)
            )
    elseif cmd == 'clear' then
        local npc
        if arg1 then
            npc = argstr:match('^'..cmd..'%s+(.*)')
        else
            npc = GetBossInfo()
        end
        if npc then
            self.db.specByNPC[npc] = nil
            self:Print('Clearing spec for npc %s', GetNPCText(npc))
        end
    elseif cmd == 'set' and arg1 then
        local npc, instance = GetBossInfo()
        local spec = ParseSpecArg(arg1)
        if npc and spec then
            self:Print('Setting spec %d (%s) for npc %s',
                    spec,
                    GetLootSpecText(spec),
                    GetNPCText(npc)
                )
            self.db.specByNPC[npc] = { instance = instance, spec = spec }
        else
            self:Print('Target a boss or have it open in the Encounter Journal.')
        end
    elseif cmd == 'wipe' then
        wipe(self.db.specByNPC)
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
