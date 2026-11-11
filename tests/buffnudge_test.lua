-- Runs BuffNudge against a mocked WoW API.
-- Usage: lua5.1 tests/buffnudge_test.lua BuffNudge/BuffNudge.lua
-- Mock WoW API
local sent, printed = {}, {}
local roster = {
  raid1={name="Me",class="MAGE",player=true},
  raid2={name="Pria",realm="Stormrage",class="PRIEST"},
  raid3={name="Warr",class="WARRIOR"},
  raid4={name="Offline",class="DRUID",offline=true},
  raid5={name="Evo",class="EVOKER"},
  raid6={name="Pri2",class="PRIEST"},
}
roster.player = roster.raid1
local names = {[1459]="Arcane Intellect",[21562]="Power Word: Fortitude",[6673]="Battle Shout",[1126]="Mark of the Wild",[462854]="Skyfury",[364342]="Blessing of the Bronze"}
local auras = {["Battle Shout"]=true}
local now, combat = 100, false
print = function(m) printed[#printed+1]=m end
C_Spell={GetSpellName=function(id) return names[id] end}
C_UnitAuras={GetPlayerAuraBySpellID=function() return nil end,
  GetAuraDataBySpellName=function(u,n) return auras[n] and {} or nil end}
C_ChatInfo={SendChatMessage=function(t,c,_,tg) sent[#sent+1]={t,c,tg} end}
UnitFullName=function(u) return roster[u].name, roster[u].realm end
UnitName=function(u) return roster[u].name end
UnitClass=function(u) return roster[u].class, roster[u].class end
UnitExists=function(u) return roster[u]~=nil end
UnitIsUnit=function(u) return roster[u].player==true end
UnitIsConnected=function(u) return not roster[u].offline end
IsInRaid=function() return true end
IsInGroup=function(c) return c==nil end
GetNumGroupMembers=function() return 6 end
GetTime=function() return now end
InCombatLockdown=function() return combat end
Ambiguate=function(n) return (n:gsub("%-.*","")) end
SlashCmdList={}; LE_PARTY_CATEGORY_INSTANCE=2
local handler
CreateFrame=function() return {RegisterEvent=function() end, SetScript=function(_,_,f) handler=f end} end

local ns={}
assert(loadfile(arg[1]))("BuffNudge", ns)
handler(nil,"ADDON_LOADED","BuffNudge")
local function reset() sent,printed={},{} end
local function dump(t) for _,s in ipairs(t) do io.write("  ",tostring(s[1])," | ",tostring(s[2])," | ",tostring(s[3]),"\n") end end

handler(nil,"READY_CHECK","Warr")
io.write("whisper mode:\n"); dump(sent); for _,p in ipairs(printed) do io.write("  P ",p,"\n") end
assert(#sent==3, #sent) -- 2 priests + evoker; warrior buff present, druid offline, own mage buff printed
assert(sent[1][3]=="Pria-Stormrage")

reset(); handler(nil,"READY_CHECK","Warr"); assert(#sent==0,"throttle")
now=200; reset(); handler(nil,"READY_CHECK","Warr"); assert(#sent==3,"after throttle")

now=300; reset(); SlashCmdList.BUFFNUDGE("group"); handler(nil,"READY_CHECK","Warr")
io.write("group mode:\n"); dump(sent); assert(#sent==1 and sent[1][2]=="RAID")

reset(); SlashCmdList.BUFFNUDGE("mine"); handler(nil,"READY_CHECK","Warr"); assert(#sent==0,"onlyMine")
handler(nil,"READY_CHECK","Me-Realm"); assert(#sent==1,"mine fires")

reset(); combat=true; handler(nil,"READY_CHECK","Me"); assert(#sent==0,"combat"); combat=false
reset(); SlashCmdList.BUFFNUDGE("test"); assert(#sent==0)
io.write("test cmd:\n"); for _,p in ipairs(printed) do io.write("  P ",p,"\n") end
reset(); SlashCmdList.BUFFNUDGE("off"); handler(nil,"READY_CHECK","Me"); assert(#sent==0,"off")
auras={["Battle Shout"]=true,["Arcane Intellect"]=true,["Power Word: Fortitude"]=true,["Blessing of the Bronze"]=true}
SlashCmdList.BUFFNUDGE("on"); reset(); handler(nil,"READY_CHECK","Me"); assert(#sent==0 and #printed==0,"all buffed")
io.write("ALL PASS\n")
