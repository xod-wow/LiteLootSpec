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

local function GetUnitNPCID(unit)
    local guid = UnitGUID(unit)
    if guid then return guid:sub(-17, -12) end
end

local function GetLootSpecText(n)
    local sex = UnitSex("player");
    if n == 0 then
        local specIndex = GetSpecialization()
        local _, name = GetSpecializationInfo(specIndex, nil, nil, nil, sex);
        return format(LOOT_SPECIALIZATION_DEFAULT, name);
    else
        local _, name = GetSpecializationInfoByID(n, nil, nil, nil, sex)
        return name
    end
end

function LiteLootSpec:Print(...)
    local txt = format(...)
    print('|cff00ff00LiteLootSpec:|r ' .. txt)
end

function LiteLootSpec:ApplyWantedSpec()
    if InCombatLockdown() or GetNumSpecializations() == 0 then
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
    self:Print('Changing loot spec to ' .. GetLootSpecText(wantedLootSpec))
end

function LiteLootSpec:PLAYER_LOGIN()
    LiteLootSpecDB = LiteLootSpecDB or CopyTable(defaults)
    self.db = LiteLootSpecDB
    self.wantedLootSpec = nil
    -- Is this necessary? PLAYER_LOOT_SPEC_UPDATED is probably fired early
    self.userSetLootSpec = GetLootSpecialization()
    self:RegisterEvent('PLAYER_TARGET_CHANGED')
    self:RegisterEvent('PLAYER_LOOT_SPEC_UPDATED')
    self:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED')
end

function LiteLootSpec:PLAYER_TARGET_CHANGED()
    local npcID = GetUnitNPCID('target')

    -- Really want to check that the target is meaningful here

    if not npcID or not self.db.specByNPC[npcID] then return end

    if UnitIsDead('target') then
        self.wantedLootSpec = nil
    else
        self.wantedLootSpec = self.db.specByNPC[npcID]
        self:ApplyWantedSpec()
    end
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
        local spec = GetSpecializationInfo(n)
        return spec
    end

    local pattern = '^' .. arg:lower()
    for i = 1, GetNumSpecializations() do
        local spec, specName = GetSpecializationInfo(i)
        if specName:lower():match(pattern) then
            return spec
        end
    end
end

function LiteLootSpec:SlashCommandHandler(argstr)
    local cmd, arg1, arg2 = strsplit(' ', strlower(argstr))
    if cmd == 'list' then
        for npc, spec in pairs(self.db.specByNPC) do
            self:Print('%s -> %d (%s)', npc, spec, GetLootSpecText(spec))
        end
    elseif cmd == 'target' then
        local npc = GetUnitNPCID('target')
        self:Print('LiteLootSpec: target npc = %s', npc)
    elseif cmd == 'clear' then
        local npc = arg1 or GetUnitNPCID('target')
        if npc then
            self.db.specByNPC[npc] = nil
            self:Print('LiteLootSpec: clearing spec for npc %d', npc)
        end
    elseif cmd == 'set' then
        local npc, spec
        if arg2 then
            npc = arg1
            spec = ParseSpecArg(arg2)
        else
            npc = GetUnitNPCID('target')
            spec = ParseSpecArg(arg1)
        end
        if npc and spec then
            self:Print('Setting spec %s for npc %d', GetLootSpecText(spec), npc)
            self.db.specByNPC[npc] = spec
        end
    elseif cmd == 'wipe' then
        wipe(self.db.specByNPC)
    else
        self:Print('Usage:')
        self:Print('  /ls list')
        self:Print('  /ls set [<npcid>] <spec>')
        self:Print('  /ls clear [<npcid>]')
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
