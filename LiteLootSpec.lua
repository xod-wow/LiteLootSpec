--[[----------------------------------------------------------------------------
  LiteLootSpec
----------------------------------------------------------------------------]]--

LiteLootSpec = CreateFrame('Frame')
LiteLootSpec:RegisterEvent('PLAYER_LOGIN')
LiteLootSpec:SetScript('OnEvent', function (self, e, ...) if self[e] then self[e](self, e, ...) end end)

local defaults = {
    specByNPC = { },
}

local function GetUnitNPCID(unit)
    local guid = UnitGUID(unit)
    if guid then return guid:sub(-17, -12) end
end

local function GetLootSpecText(i)
    local sex = UnitSex("player");
    if i == 0 then
        local specIndex = GetSpecialization()
        local _, name = GetSpecializationInfo(specIndex, nil, nil, nil, sex);
        return format(LOOT_SPECIALIZATION_DEFAULT, name);
    else
        local _, name = GetSpecializationInfo(i, nil, nil, nil, sex)
        return name
    end
end

function LiteLootSpec:ApplySpec()
    if InCombatLockdown() then return end

    local wantedLootSpec = self.wantedLootSpec or self.userSetLootSpec or 0
    local newLootSpecID = GetSpecializationInfo(wantedLootSpec) or 0
    local curLootSpecID = GetLootSpecialization() or 0

    if newLootSpecID == curLootSpecID then
        return
    end

    if wantedLootSpec == GetSpecialization() and curLootSpecID == 0 then
        return
    end

    SetLootSpecialization(newLootSpecID)
    print('LiteLootSpec: Changing loot spec to ' .. GetLootSpecText(wantedLootSpec))
end

function LiteLootSpec:PLAYER_LOGIN()
    LiteLootSpecDB = LiteLootSpecDB or CopyTable(defaults)
    self.db = LiteLootSpecDB
    self.wantedLootSpec = nil
    self.userSetLootSpec = GetLootSpecialization()
    self:RegisterEvent('PLAYER_TARGET_CHANGED')
    self:RegisterEvent('PLAYER_LOOT_SPEC_UPDATED')
    self:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED')
    self:RegisterEvent('PLAYER_REGEN_ENABLED')
end

function LiteLootSpec:PLAYER_TARGET_CHANGED()
    local npcid = GetUnitNPCID('target')

    if not npcid then return end

    if self.db.specByNPC[npcid] then
        self.wantedLootSpec = self.db.specByNPC[npcid]
        if not UnitIsDead('target') then
            self:ApplySpec()
        else
            self.wantedUnitDied = true
        end
    end
end

function LiteLootSpec:PLAYER_SPECIALIZATION_CHANGED()
    self:ApplySpec()
end

function LiteLootSpec:PLAYER_REGEN_ENABLED()
    self:ApplySpec()
end

function LiteLootSpec:PLAYER_LOOT_SPEC_UPDATED()
    self.userSetLootSpec = GetLootSpecialization()
end

local function ParseSpecArg(arg)
    local n = tonumber(arg)

    if n then return n end

    local pattern = '^' .. arg:lower()
    for i = 1, GetNumSpecializations() do
        local _, specName = GetSpecializationInfo(i)
        if specName:lower():match(pattern) then
            return i
        end
    end
end

function LiteLootSpec:SlashCommandHandler(argstr)
    local cmd, arg1, arg2 = strsplit(' ', strlower(argstr))
    if cmd == 'list' then
        for npc, spec in pairs(self.db.specByNPC) do
            print(format('LiteLootSpec: %s -> %d (%s)', npc, spec, GetLootSpecText(spec)))
        end
    elseif cmd == 'target' then
        local npc = GetUnitNPCID('target')
        print(format('LiteLootSpec: target npc = %s', npc))
    elseif cmd == 'clear' then
        local npc = arg1 or GetUnitNPCID('target')
        if npc then
            self.db.specByNPC[npc] = nil
            print(format('LiteLootSpec: clearing spec for npc %d', npc))
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
            print(format('LiteLootSpec: saving spec %s for npc %d', GetLootSpecText(spec), npc))
            self.db.specByNPC[npc] = spec
        end
    elseif cmd == 'wipe' then
        wipe(self.db.specByNPC)
    else
        print('LiteLootSpec: Usage:')
        print('  /ls list')
        print('  /ls set [<npcid>] <spec>')
        print('  /ls clear [<npcid>]')
        print('  /ls wipe')
        print('  /ls target')
    end
    return true
end

SlashCmdList['LiteLootSpec'] =
    function (arg)
        LiteLootSpec:SlashCommandHandler(arg)
    end
SLASH_LiteLootSpec1 = '/ls'
