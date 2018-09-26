--[[----------------------------------------------------------------------------
  LiteLootSpecSwap
----------------------------------------------------------------------------]]--

local me = CreateFrame("frame")
me:RegisterEvent('PLAYER_LOGIN')
me:SetScript('OnEvent', function (self, e, ...) if self[e] then self[e](self, e, ...) end end)

local defaults = {
    specByNPC = { },
}

function me:PLAYER_LOGIN()
    AutoLootSpecSwapDB = AutoLootSpecSwapDB or CopyTable(defaults)
    self.db = AutoLootSpecSwapDB

    self:RegisterEvent("PLAYER_TARGET_CHANGED")
end

function me:PLAYER_TARGET_CHANGED()
    if UnitIsDead("target") or not UnitExists("target") then return end

    local guid = UnitGUID("target")
    local npcid = tonumber(guid:sub(-12, -9), 16)

    local newSpec = self.db.specByNPC[npcid]
    if newSpec then
        SetLootSpecialization(newSpec)
        print("AutoLootSpecSwap: CHANGED LOOT SPEC TO " .. tostring(newSpec))
    end
end

function me:SlashCommandHandler(cmd)
    print("AutoLootSpecSwap: Usage:\n/llss")
    return true
end

SlashCmdList["AUTOLOOTSPECSWAP"] = function (arg) me:SlashCommandHandler(arg) end
SLASH_AUTOLOOTSPECSWAP1 = "/llss"
