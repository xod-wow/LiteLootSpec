--[[----------------------------------------------------------------------------
  LiteLootSpecSwap
----------------------------------------------------------------------------]]--

local me = CreateFrame('frame')
me:RegisterEvent('PLAYER_LOGIN')
me:SetScript('OnEvent', function (self, e, ...) if self[e] then self[e](self, e, ...) end end)

local defaults = {
    specByNPC = { },
}

local function GetUnitNPCID(unit)
    local guid = UnitGUID(unit)
    if guid then return guid:sub(-17, -12) end
end

function me:PLAYER_LOGIN()
    LiteLootSpecDB = LiteLootSpecDB or CopyTable(defaults)
    self.db = LiteLootSpecDB

    self:RegisterEvent('PLAYER_TARGET_CHANGED')
end

function me:PLAYER_TARGET_CHANGED()
    if UnitIsDead('target') or not UnitExists('target') then return end

    local npcid = GetUnitNPCID('target')

    local newSpec = self.db.specByNPC[npcid]
    if newSpec then
        local newSpecID = GetSpecializationInfo(newSpec) or 0
        local curSpecID = GetLootSpecialization() or 0
        if newSpecID ~= curSpecID then
            SetLootSpecialization(newSpecID)
            print('LiteLootSpec: CHANGED LOOT SPEC TO ' .. tostring(newSpec))
        end
    end
end

function me:SlashCommandHandler(argstr)
    local cmd, arg1, arg2 = strsplit(' ', strlower(argstr))
    if cmd == 'list' then
        for npc, spec in pairs(self.db.specByNPC) do
            print(format('LiteLootSpec: %s -> %d', npc, spec))
        end
    elseif cmd == 'target' then
        local npc = GetUnitNPCID('target')
        print(format('LiteLootSpec: target npc = %s', npc))
    elseif cmd == 'clear' then
        local npc = arg1 or GetUnitNPCID('target')
        if npc then
            self.db.specByNPC[npc] = nil
        end
    elseif cmd == 'set' then
        local npc, spec
        if arg2 then
            npc = arg1
            spec = tonumber(arg2)
        else
            npc = GetUnitNPCID('target')
            spec = tonumber(arg1)
        end
        if npc and spec then
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

SlashCmdList['LiteLootSpec'] = function (arg) me:SlashCommandHandler(arg) end
SLASH_LiteLootSpec1 = '/ls'
