-- BuffNudge: on a ready check, find raid buffs the player is missing whose
-- provider class is in the group, and let those players know.

local ADDON_NAME, ns = ...

-- Raid buffs to track. `class` is the class file token of the provider and
-- `spellID` is the spell they cast. Auras are matched by the spell's name, so
-- buffs whose applied aura has a different ID (Blessing of the Bronze) work.
ns.BUFFS = {
    { class = "MAGE",    spellID = 1459   }, -- Arcane Intellect
    { class = "PRIEST",  spellID = 21562  }, -- Power Word: Fortitude
    { class = "WARRIOR", spellID = 6673   }, -- Battle Shout
    { class = "DRUID",   spellID = 1126   }, -- Mark of the Wild
    { class = "SHAMAN",  spellID = 462854 }, -- Skyfury
    { class = "EVOKER",  spellID = 364342 }, -- Blessing of the Bronze
}

local DEFAULTS = {
    enabled = true,
    mode = "WHISPER",  -- WHISPER (each provider), GROUP (one raid/party message), SELF (print only)
    onlyMine = false,  -- only react to ready checks started by the player
    throttle = 30,     -- seconds before the same player can be whispered again
}

local PREFIX = "|cff33ff99BuffNudge|r: "
local lastWhisper = {} -- [fullName] = GetTime() of last whisper

local function Print(msg)
    print(PREFIX .. msg)
end

local function SendChat(text, chatType, target)
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    send(text, chatType, nil, target)
end

local function SpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellID)
    end
    return (GetSpellInfo(spellID))
end

local function PlayerHasBuff(spellID, name)
    if C_UnitAuras.GetPlayerAuraBySpellID(spellID) then
        return true
    end
    if C_UnitAuras.GetAuraDataBySpellName then
        return C_UnitAuras.GetAuraDataBySpellName("player", name, "HELPFUL") ~= nil
    end
    return AuraUtil.FindAuraByName(name, "player", "HELPFUL") ~= nil
end

local function FullName(unit)
    local name, realm = UnitFullName(unit)
    if not name then return nil end
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

-- Returns { [classToken] = { fullName, ... } } for connected group members
-- other than the player, plus the player's own class token.
local function GroupProviders()
    local providers = {}
    local isRaid = IsInRaid()
    local count = GetNumGroupMembers()
    for i = 1, count do
        local unit = isRaid and ("raid" .. i) or ("party" .. i)
        if UnitExists(unit) and not UnitIsUnit(unit, "player") and UnitIsConnected(unit) then
            local _, class = UnitClass(unit)
            local name = FullName(unit)
            if class and name then
                providers[class] = providers[class] or {}
                table.insert(providers[class], name)
            end
        end
    end
    local _, playerClass = UnitClass("player")
    return providers, playerClass
end

-- Returns a list of { name = buffName, class = token, players = {...}, own = bool }
-- for every tracked buff the player lacks and somebody in the group can cast.
function ns.FindMissing()
    local providers, playerClass = GroupProviders()
    local missing = {}
    for _, buff in ipairs(ns.BUFFS) do
        local name = SpellName(buff.spellID)
        local players = providers[buff.class]
        local own = buff.class == playerClass
        if name and (players or own) and not PlayerHasBuff(buff.spellID, name) then
            table.insert(missing, { name = name, class = buff.class, players = players or {}, own = own })
        end
    end
    return missing
end

local function GroupChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    return "PARTY"
end

-- mode: WHISPER, GROUP or SELF. Returns the number of missing buffs found.
function ns.Notify(mode)
    local missing = ns.FindMissing()
    if #missing == 0 then
        return 0
    end

    local names = {}
    for _, m in ipairs(missing) do
        names[#names + 1] = m.name
        if m.own then
            Print("You are missing your own buff: " .. m.name)
        end
    end

    if mode == "SELF" then
        for _, m in ipairs(missing) do
            if #m.players > 0 then
                Print("Missing " .. m.name .. " (from " .. table.concat(m.players, ", ") .. ")")
            end
        end
    elseif mode == "GROUP" then
        local wanted = {}
        for _, m in ipairs(missing) do
            if #m.players > 0 then wanted[#wanted + 1] = m.name end
        end
        if #wanted > 0 then
            SendChat("BuffNudge: I'm missing " .. table.concat(wanted, ", ") .. ".", GroupChannel())
        end
    else -- WHISPER
        local now = GetTime()
        for _, m in ipairs(missing) do
            for _, player in ipairs(m.players) do
                local last = lastWhisper[player .. m.name]
                if not last or now - last >= BuffNudgeDB.throttle then
                    lastWhisper[player .. m.name] = now
                    SendChat("BuffNudge: I'm missing " .. m.name .. " - could you rebuff, please?", "WHISPER", player)
                end
            end
        end
        Print("Missing " .. table.concat(names, ", ") .. " - providers whispered.")
    end
    return #missing
end

local function OnReadyCheck(initiator)
    local db = BuffNudgeDB
    if not db.enabled or not IsInGroup() then return end
    -- Aura data is restricted in combat; ready checks there are skipped.
    if InCombatLockdown() then return end
    if db.onlyMine then
        local me = UnitName("player")
        if not initiator or Ambiguate(initiator, "short") ~= me then return end
    end
    ns.Notify(db.mode)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("READY_CHECK")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        BuffNudgeDB = BuffNudgeDB or {}
        for k, v in pairs(DEFAULTS) do
            if BuffNudgeDB[k] == nil then BuffNudgeDB[k] = v end
        end
    elseif event == "READY_CHECK" then
        OnReadyCheck(arg1)
    end
end)

local MODES = { whisper = "WHISPER", group = "GROUP", self = "SELF" }

local function Status()
    local db = BuffNudgeDB
    Print(("%s, mode: %s, ready checks: %s"):format(
        db.enabled and "enabled" or "disabled",
        db.mode:lower(),
        db.onlyMine and "only mine" or "anyone's"))
end

SLASH_BUFFNUDGE1 = "/buffnudge"
SLASH_BUFFNUDGE2 = "/bn"
SlashCmdList.BUFFNUDGE = function(msg)
    local cmd = (msg or ""):lower():match("^%s*(%S*)")
    local db = BuffNudgeDB
    if cmd == "on" or cmd == "off" then
        db.enabled = cmd == "on"
        Status()
    elseif MODES[cmd] then
        db.mode = MODES[cmd]
        Status()
    elseif cmd == "mine" then
        db.onlyMine = not db.onlyMine
        Status()
    elseif cmd == "test" then
        -- Dry run: prints what would be reported, sends nothing.
        if ns.Notify("SELF") == 0 then
            Print("No missing raid buffs.")
        end
    else
        Status()
        Print("/bn on | off - enable or disable")
        Print("/bn whisper | group | self - who gets told")
        Print("/bn mine - toggle reacting only to your own ready checks")
        Print("/bn test - show what you are missing without messaging anyone")
    end
end
