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

-- God dammit Blizzard
local function UnitDisplayName(unit)
    local n, r = UnitFullName(unit)
    r = r or select(2, UnitFullName("player"))
    return format('%s-%s', n, r)
end

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
    elseif n == nil then
        return NONE
    else
        local _, name = GetSpecializationInfoByID(n, sex)
        return name or UNKNOWN
    end
end

function LiteLootSpec:Print(...)
    local cur = DEFAULT_CHAT_FRAME
    for i = 1,NUM_CHAT_WINDOWS do
        local f = _G["ChatFrame"..i]
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
    self:Message('Changing loot spec to ' .. GetLootSpecText(wantedLootSpec))
end

function LiteLootSpec:PLAYER_LOGIN()
    local key = format('%s-%s', UnitFullName('player'))
    LiteLootSpecDB = LiteLootSpecDB or { }
    LiteLootSpecDB[key] = LiteLootSpecDB[key] or  CopyTable(defaults)

    self.db = LiteLootSpecDB[key]

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

    local npcID = GetUnitNPCID('target')
    if not npcID then
        return
    end

    if self.db.specByNPC[npcID] then
        self.wantedLootSpec = self.db.specByNPC[npcID]
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

function LiteLootSpec:SlashCommandHandler(argstr)
    local cmd, arg1, arg2 = strsplit(' ', strlower(argstr))
    if cmd == 'list' then
        for npc, spec in pairs(self.db.specByNPC) do
            self:Print('%s -> %d (%s)', npc, spec, GetLootSpecText(spec))
        end
    elseif cmd == 'target' then
        local npc = GetUnitNPCID('target')
        self:Print('LiteLootSpec: target npc = %s', tostring(npc))
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
        if npc then
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
