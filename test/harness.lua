-- Mock client for Ashwright. texlua test/harness.lua <addon dir> <classic|modern> <combat-at-login: 0|1>
local DIR, LAYOUT, COMBAT_AT_LOGIN = arg[1], arg[2], arg[3] == "1"
local unpack = table.unpack
-- WoW's Lua is 5.1: unpack is a global there (texlua happens to have it too;
-- plain lua5.3 doesn't)
_G.unpack = _G.unpack or table.unpack

---------------------------------------------------------------- mock objects
local methods = {}
local function new(kind, name)
  local o = { __type = kind or "Frame", __log = {}, __regions = {}, __level = 2, __hooks = {}, __name = name }
  setmetatable(o, { __index = function(t, k)
    if methods[k] then return methods[k] end
    -- only method-style names get a recorder; plain fields (HealthBar, IconMask...) stay nil like in the game
    if type(k) == "string" and k:match("^[A-Z]") and (k:match("^Set") or k:match("^Get") or k:match("^Enable")
       or k:match("^Hook") or k:match("^Register") or k:match("^Create") or k:match("^Clear") or k:match("^Show$")
       or k:match("^Hide$") or k:match("^Remove") or k:match("^Highlight") or k:match("^Is") or k:match("^Start")
       or k:match("^Stop")) then
      return function(self, ...) local e = { k, ... }; self.__log[#self.__log + 1] = e end
    end
    return nil
  end })
  if name then _G[name] = o end
  return o
end
methods.GetObjectType = function(s) return s.__type end
methods.GetRegions = function(s) return unpack(s.__regions) end
methods.GetNormalTexture = function(s) return s.__normal end
methods.GetStatusBarTexture = function(s) s.__bartex = s.__bartex or new("Texture"); return s.__bartex end
methods.GetFont = function(s) if s.__font then return unpack(s.__font) end return "Fonts\\FRIZQT__.TTF", 12, "" end
methods.SetFont = function(s, path, size, flags)
  if path:find("AddOns\\Ashwright\\Media", 1, true) then return false end   -- font files not installed
  s.__font = { path, size, flags }; return true
end
methods.GetFrameLevel = function(s) return s.__level end
methods.SetFrameLevel = function(s, l) s.__level = l end
methods.GetEffectiveScale = function() return 1 end
methods.IsShown = function(s) return s.__shown ~= false end
methods.IsForbidden = function() return false end
methods.GetFrameStrata = function() return "MEDIUM" end
methods.GetZoom = function(s) return s.__zoom or 0 end
methods.GetZoomLevels = function() return 5 end
methods.SetZoom = function(s, z) s.__zoom = z end
methods.CreateTexture = function(s) local t = new("Texture"); s.__regions[#s.__regions + 1] = t; return t end
methods.CreateFontString = function(s) local t = new("FontString"); s.__regions[#s.__regions + 1] = t; return t end
methods.SetAlpha = function(s, a) s.__alpha = a end
methods.SetStatusBarColor = function(s, r, g, b) s.__color = { r, g, b } end
methods.SetStatusBarTexture = function(s, t) s.__tex = t end
methods.SetBackdropBorderColor = function(s, r, g, b) s.__borderColor = { r, g, b } end
methods.SetMaskTexture = function(s, t) s.__mask = t end
methods.HookScript = function(s, script, fn) s.__hooks[script] = s.__hooks[script] or {}; table.insert(s.__hooks[script], fn) end
methods.SetScript = function(s, script, fn) s.__scripts = s.__scripts or {}; s.__scripts[script] = fn end
methods.RegisterEvent = function(s, e) s.__events = s.__events or {}; s.__events[e] = true end
methods.GetFontString = function(s) return s.__text end
methods.GetParent = function(s) return s.__parent end
methods.GetChildren = function(s) return unpack(s.__children or {}) end
methods.SetPoint = function(s, p, rel, rp, x, y)
  s.__log[#s.__log + 1] = { "SetPoint", p, rel, rp, x, y }
  s.__points = s.__points or {}
  for i, pt in ipairs(s.__points) do if pt[1] == p then s.__points[i] = { p, rel, rp, x, y }; return end end
  s.__points[#s.__points + 1] = { p, rel, rp, x, y }
end
methods.ClearAllPoints = function(s) s.__points = {} end
methods.GetLeft = function(s) return s.__rect and s.__rect[1] end
methods.GetBottom = function(s) return s.__rect and s.__rect[2] end
methods.GetRight = function(s) return s.__rect and s.__rect[1] + s.__rect[3] end
methods.GetTop = function(s) return s.__rect and s.__rect[2] + s.__rect[4] end
methods.SetSize = function(s, w, h) s.__size = { w, h } end
methods.SetVertexColor = function(s, r, g, b, a) s.__vc = { r, g, b, a } end
methods.SetShown = function(s, v) s.__shown = v and true or false end
methods.GetWidth = function(s) return (s.__size and s.__size[1]) or (s.__rect and s.__rect[3]) or 0 end
methods.GetHeight = function(s) return (s.__size and s.__size[2]) or (s.__rect and s.__rect[4]) or 0 end
methods.GetName = function(s) return s.__name end
methods.GetNumPoints = function(s) return #(s.__points or {}) end
methods.GetPoint = function(s, i) local pt = (s.__points or {})[i or 1]; if pt then return unpack(pt) end end
methods.IsVisible = function(s) return s.__shown ~= false end
methods.GetAtlas = function(s) return s.__atlas end
methods.SetTexture = function(s, f) s.__file = f end
methods.GetTexture = function(s) return s.__file end
methods.GetStatusBarColor = function(s) if s.__color then return unpack(s.__color) end return 1, 1, 1, 1 end
methods.Show = function(s) s.__shown = true end
methods.Hide = function(s) s.__shown = false end

local frames = {}
-- a stand-in for the game's secret values: indexing a table with one errors
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
function issecretvalue(v) return v == SECRET end
-- timers run at once unless a test queues them to play the game's frame order
local timerQueue
C_Timer = { After = function(_, fn) if timerQueue then timerQueue[#timerQueue + 1] = fn else fn() end end }
local function flushTimers() local q = timerQueue or {}; timerQueue = nil; for _, fn in ipairs(q) do fn() end end
function CreateFrame(kind, name, parent, template)
  local f = new(kind or "Frame", name)
  f.__parent = parent
  f.__template = template
  frames[#frames + 1] = f
  return f
end
function hooksecurefunc(a, b, c)
  local obj, method, fn
  if type(a) == "string" then obj, method, fn = _G, a, b else obj, method, fn = a, b, c end
  local orig = obj[method]
  obj[method] = function(...) local r = { orig(...) }; fn(...); return unpack(r) end
end
local function fire(e, ...)
  for _, f in ipairs(frames) do
    if f.__events and f.__events[e] and f.__scripts and f.__scripts.OnEvent then f.__scripts.OnEvent(f, e, ...) end
  end
end

local inCombat = false
function InCombatLockdown() return inCombat end
function GetBuildInfo() return "1.60.1", "70338", "Nov 1 2026", 16001 end
function GetServerTime() return 1795000000 end
function GetPhysicalScreenSize() return 1920, 1080 end
function UnitIsUnit(a, b) return a == "nameplate1" and b == "target" end
function UnitPowerType(u) if u == "player" then return 1, "RAGE" end return 0, "MANA" end
PowerBarColor = { MANA = { r = 0, g = 0, b = 1 }, RAGE = { r = 1, g = 0, b = 0 } }
BackdropTemplateMixin = {}
NUM_CHAT_WINDOWS = 3
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) print((m:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))) end }
SlashCmdList = {}
UIParent = new("Frame", "UIParent")

---------------------------------------------------------------- build a client layout
local function bar() local b = new("StatusBar"); b.TextString = new("FontString"); return b end
local function tex(name) return new("Texture", name) end
local function button(name)
  local b = new("CheckButton", name)
  b.icon = new("Texture"); b.HotKey = new("FontString"); b.Count = new("FontString"); b.Name = new("FontString")
  b.__normal = new("Texture")
  return b
end

if LAYOUT == "classic" then
  for _, u in ipairs({ "Player", "Target", "Focus" }) do
    local f = new("Button", u .. "Frame")
    f.healthbar = bar(); f.manabar = bar(); f.manabar.unit = u:lower()
  end
  new("StatusBar", "MainMenuExpBar")
  tex("PlayerFrameTexture"); tex("PlayerFrameBackground")
  new("FontString", "PlayerName"); new("FontString", "PlayerLevelText")
  tex("TargetFrameTextureFrameTexture"); new("FontString", "TargetFrameTextureFrameName")
  local tot = new("Button", "TargetFrameToT"); tot.healthbar = bar(); tot.manabar = bar()
  new("StatusBar", "CastingBarFrame"); tex("CastingBarFrameBorder"); tex("CastingBarFrameFlash")
  new("FontString", "CastingBarFrameText"); tex("CastingBarFrameIcon")
  tex("TargetFrameToTTextureFrameTexture")
  for i = 1, 4 do
    local p = new("Button", "PartyMemberFrame" .. i); p.healthbar = bar(); p.manabar = bar()
    tex("PartyMemberFrame" .. i .. "Texture"); new("FontString", "PartyMemberFrame" .. i .. "Name")
  end
  local art = new("Frame", "MainMenuBarArtFrame")
  art.__regions = { new("Texture"), new("Texture"), new("FontString") }
  tex("MainMenuBarLeftEndCap"); tex("MainMenuBarRightEndCap"); tex("MainMenuBarTexture0")
  tex("MinimapBorder"); tex("MinimapBorderTop"); new("Button", "MinimapZoomIn"); new("FontString", "MinimapZoneText")
  local tip = new("GameTooltip", "GameTooltip")
else
  local pf = new("Button", "PlayerFrame")
  pf.__pm = true
  pf.PlayerFrameContainer = { FrameTexture = new("Texture") }
  local hbc = { HealthBar = bar(), HealthBarMask = new("MaskTexture") }
  hbc.HealthBar.__parent = hbc
  pf.PlayerFrameContent = { PlayerFrameContentMain = { HealthBarsContainer = hbc,
                            ManaBarArea = { ManaBar = bar() } } }
  pf.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar.unit = "player"
  -- modern frames without the healthbar field, to exercise the name lookups
  new("Frame", "EditModeManagerFrame")
  local main = new("Frame", "MainActionBar"); main.__level = 1
  local xpm = new("Frame", "MainStatusTrackingBarManager")
  local cont = new("Frame"); cont.BarFrameTexture = new("Texture"); cont.StatusBar = bar(); xpm.__children = { cont }
  local divf = new("Frame"); divf.BarDividerTexture = new("Texture"); divf.BarDividerTexture.__atlas = "UI-HUD-ExperienceBar-Divider"
  divf.__regions = { divf.BarDividerTexture }
  cont.Selection = new("Frame"); cont.Selection.Center = new("Texture"); cont.Selection.__regions = { cont.Selection.Center }
  local xpf = new("Frame"); xpf.StatusBar = bar(); xpf.StatusBar.Background = new("Texture"); xpf.ExhaustionLevelFillBar = new("Texture")
  -- the rounded end caps and the rested band are regions of the bar frame;
  -- the fill is a region of the status bar
  xpf.LeftCap, xpf.RightCap = new("Texture"), new("Texture")
  xpf.__regions = { xpf.LeftCap, xpf.ExhaustionLevelFillBar, xpf.RightCap }
  xpf.__children = { xpf.StatusBar }
  xpf.StatusBar.__regions = { xpf.StatusBar:GetStatusBarTexture(), xpf.StatusBar.Background }
  cont.__children = { cont.Selection, divf, xpf }
  local tf = new("Button", "TargetFrame")
  tf.TargetFrameContainer = { FrameTexture = new("Texture") }
  local thb = bar(); thb.__level = 0; thb.__size = { 126, 20 }
  local tmb = bar(); tmb.__size = { 134, 10 }
  local thc = new("Frame"); thc.HealthBar = thb; thb.__parent = thc
  thc:SetPoint("TOPLEFT", tf, "TOPLEFT", 10, -20)
  -- side by side, the target's bars 3 px higher than the player's
  -- player bars 124x18 (top 498); target bars 126x20, top 503, frame top-right at 482,540
  hbc.HealthBar.__rect = { 100, 480, 124, 18 }; thb.__rect = { 300, 483, 126, 20 }
  tf.__rect = { 250, 440, 232, 100 }
  pf.__rect = { 40, 440, 232, 100 }                       -- player frame, same height as the target's
  pf.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar.__size = { 124, 10 }
  tf.__shown = false   -- no target at login: the bars' spot isn't learned yet
  -- auras: the first hangs from the frame, the second from the first
  local a1, a2 = new("Button"), new("Button")
  a1:SetPoint("TOPLEFT", tf, "BOTTOMLEFT", 5, 32); a2:SetPoint("TOPLEFT", a1, "TOPRIGHT", 2, 0)
  tf.auraPools = { EnumerateActive = function() local l, i = { a1, a2 }, 0; return function() i = i + 1; return l[i] end end }
  tf.UpdateAuras = function() end
  tf.__auras = { a1, a2 }
  local pcb = new("StatusBar", "PlayerCastingBarFrame"); pcb.barType = "channel"; pcb.__iconHidden = true
  pcb.Border = new("Texture"); pcb.TextBorder = new("Texture"); pcb.Background = new("Texture")
  pcb.Text = new("FontString"); pcb.Icon = new("Texture"); pcb.Icon.__shown = false; pcb.Spark = new("Texture")
  tf.spellbar = new("StatusBar", "TargetFrameSpellBar"); tf.spellbar.barType = "standard"
  tf.spellbar.Border = new("Texture"); tf.spellbar.Icon = new("Texture"); tf.spellbar.Text = new("FontString")
  tf.TargetFrameContent = { TargetFrameContentMain = { HealthBarsContainer = thc, ManaBar = tmb,
                            Name = new("FontString"), ReputationColor = new("Texture") } }
  tf.totFrame = new("Button"); tf.totFrame.HealthBar = bar(); tf.totFrame.FrameTexture = new("Texture")
  local party = new("Frame", "PartyFrame")
  for i = 1, 4 do
    local m = new("Button"); m.Texture = new("Texture"); m.Name = new("FontString")
    m.HealthBarContainer = { HealthBar = bar() }; m.ManaBar = bar()
    party["MemberFrame" .. i] = m
  end
  local mmb = new("Frame", "MainMenuBar")
  mmb.EndCaps = { LeftEndCap = new("Texture"), RightEndCap = new("Texture") }
  mmb.BorderArt = new("Texture")
  new("Texture", "MinimapCompassTexture")
  local cluster = new("Frame", "MinimapCluster"); cluster.BorderTop = new("Texture")
  cluster.ZoneTextButton = { ZoneText = new("FontString") }
  local tip = new("GameTooltip", "GameTooltip"); tip.NineSlice = new("Frame")
end

for i = 1, 12 do
  local b = button("ActionButton" .. i)
  if LAYOUT == "classic" then b.FloatingBG = new("Texture") end
  if LAYOUT == "modern" then b.IconMask = new("MaskTexture"); b.SlotArt = new("Texture"); b.SlotBackground = new("Texture") end
  button("MultiBarBottomLeftButton" .. i)
end
local mbbl = new("Frame", "MultiBarBottomLeft")
mbbl.actionButtons = {}
for i = 1, 12 do mbbl.actionButtons[i] = _G["MultiBarBottomLeftButton" .. i]; _G["MultiBarBottomLeftButton" .. i].__parent = mbbl end
for i = 1, 12 do ActionButton1.__parent = ActionButton1.__parent end
local backpack = button("MainMenuBarBackpackButton"); backpack.icon = nil; new("Texture", "MainMenuBarBackpackButtonIconTexture")
if LAYOUT == "classic" then
  new("Frame", "MiniMapTracking"); new("Frame", "MiniMapMailFrame"); new("Button", "GameTimeFrame")
  new("Button", "TimeManagerClockButton"); new("Button", "MiniMapBattlefieldFrame")
else
  MinimapCluster.Tracking = new("Frame"); MinimapCluster.IndicatorFrame = { MailFrame = new("Frame") }
  new("Button", "QueueStatusMinimapButton"); new("Button", "TimeManagerClockButton")
end
local refreshed = {}
local dbicon = { GetButtonList = function() return { "SomeAddonButton", "OtherAddonButton" } end,
                 Refresh = function(_, name) refreshed[#refreshed + 1] = name end }
LibStub = function(name, silent) if name == "LibDBIcon-1.0" then return dbicon end end
new("Frame", "Minimap")
new("StatusBar", "GameTooltipStatusBar")
new("FontString", "GameTooltipTextLeft1")
for i = 1, 3 do
  local cf = new("ScrollingMessageFrame", "ChatFrame" .. i); cf.__font = { "Fonts\\ARIALN.TTF", 14, "" }
  cf.__name = "ChatFrame" .. i
  local tab = new("Button", "ChatFrame" .. i .. "Tab"); tab.__regions = { new("Texture"), new("Texture") }; tab.Text = new("FontString")
  local eb = new("EditBox", "ChatFrame" .. i .. "EditBox"); eb.__regions = { new("Texture"), new("Texture") }
  -- window 1: scroll bar to the right, input box shown under it
  -- window 2: input box hidden (no position), anchored under the window
  cf.__rect = { 24, 100, 380, 168 }
  cf.ScrollBar = new("Frame"); cf.ScrollBar.__rect = { 404, 100, 10, 168 }
  if i == 1 then eb.__rect = { 20, 68, 390, 30 }
  else eb:SetPoint("TOPLEFT", cf, "BOTTOMLEFT", -4, -2); eb.__size = { 390, 30 } end
end

-- nameplates
local plates = {}
local function makePlate(token)
  local p = new("Frame"); p.namePlateUnitToken = token
  local uf = new("Button"); p.UnitFrame = uf
  local hb = bar(); hb.border = new("Texture")
  -- the rounded border is a frame of edge pieces; a gloss sits on the bar;
  -- the heal prediction bar is a frame inside the bar and must stay
  hb.Frame = new("Frame"); hb.Frame.Left = new("Texture"); hb.Frame.Right = new("Texture")
  hb.Frame.__regions = { hb.Frame.Left, hb.Frame.Right }
  hb.Gloss = new("Texture"); hb.__regions = { hb:GetStatusBarTexture(), hb.Gloss }
  hb.myHealPrediction = new("Frame"); hb.myHealPrediction.Fill = new("Texture")
  hb.myHealPrediction.__regions = { hb.myHealPrediction.Fill }
  hb.__children = { hb.Frame, hb.myHealPrediction }
  if LAYOUT == "modern" then
    uf.HealthBarsContainer = { healthBar = hb }
    -- the modern plate keeps its cast bar in a container and has a level badge
    local cb = bar(); cb.Background = new("Texture"); cb.Border = new("Texture"); cb.barType = "channel"
    uf.CastBarsContainer = { castBar = cb }
    local lv = new("Frame"); lv.__level = 52
    lv.playerLevelDiffIcon = new("Texture"); lv.selectedBorder = new("Texture"); lv.playerLevelDiffText = new("FontString")
    lv.highLevelTexture = new("Texture")
    uf.PlayerLevelDiffFrame = lv
  else
    uf.healthBar = hb; uf.castBar = bar()
  end
  uf.name = new("FontString")
  plates[token] = p
  return p
end
C_NamePlate = {
  GetNamePlateForUnit = function(u) return plates[u] end,
  GetNamePlates = function() local t = {}; for _, p in pairs(plates) do t[#t + 1] = p end; return t end,
}

if not PlayerName then new("FontString", "PlayerName") end
PlayerName:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", 10, -5)
PlayerName:SetPoint("TOPRIGHT", PlayerFrame, "TOPRIGHT", -10, -5)
-- Edit Mode dividers on the bottom-left bar (modern)
local divs = { new("Texture"), new("Texture") }
MultiBarBottomLeft.UpdateDividers = function() end
MultiBarBottomLeft.DividersPool = { EnumerateActive = function() local i = 0; return function() i = i + 1; return divs[i] end end }
if LAYOUT == "modern" then
  Minimap.ZoomIn = new("Button")
  MainActionBar.__rect = { 300, 20, 600, 60 }        -- extra room around the buttons
  local mdiv = new("Texture"); mdiv.__atlas = "UI-HUD-ActionBar-Frame-Divider-Top"; MainActionBar.__regions = { mdiv }
  MainActionBar.UpdateGridLayout = function() end
  for i = 1, 2 do local rb = button("MultiBarRightButton" .. i); rb.__rect = { 1200, 300 + (i - 1) * 44, 40, 40 } end
  for i = 1, 12 do _G["ActionButton" .. i].__rect = { 320 + (i - 1) * 44, 30, 40, 40 } end
  MultiBarBottomLeft.__rect = { 320, 74, 524, 40 }
  for i = 1, 12 do _G["MultiBarBottomLeftButton" .. i].__rect = { 320 + (i - 1) * 44, 74, 40, 40 } end
  _G["MultiBarBottomLeftButton12"].__shown = false     -- a hidden button is left out
end

---------------------------------------------------------------- load and run
local ns = {}
for _, file in ipairs({ "Core.lua", "Scan.lua", "Inspect.lua", "Modules/UnitFrames.lua", "Modules/ActionBars.lua",
                        "Modules/Minimap.lua", "Modules/Chat.lua", "Modules/Nameplates.lua",
                        "Modules/Tooltip.lua", "Modules/CastBars.lua", "Init.lua" }) do
  assert(loadfile(DIR .. "/" .. file))("Ashwright", ns)
end

-- the shape must be answered as soon as the files load, before any login code
assert(GetMinimapShape and GetMinimapShape() == "SQUARE", "minimap shape not set at load")
fire("ADDON_LOADED", "Ashwright")
inCombat = COMBAT_AT_LOGIN
fire("PLAYER_LOGIN")

local function checkStyled()
  local pf = PlayerFrame
  if LAYOUT == "classic" then return PlayerFrameTexture.__alpha == 0 end
  return pf.PlayerFrameContainer.FrameTexture.__alpha == 0
end

if COMBAT_AT_LOGIN then
  assert(not checkStyled(), "touched Blizzard frames during combat")
  inCombat = false
  fire("PLAYER_REGEN_ENABLED")
end
assert(checkStyled(), "player frame art not faded")

-- health bars: Blizzard recolors green, Ashwright puts crimson back
local hb = LAYOUT == "classic" and PlayerFrame.healthbar
  or PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer.HealthBar
hb:SetStatusBarColor(0, 1, 0)
assert(math.abs(hb.__color[1] - ns.C.health[1]) < 1e-6 and math.abs(hb.__color[2] - ns.C.health[2]) < 1e-6, "health color not kept")
hb:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
assert(hb.__tex == ns.WHITE, "flat texture not kept")
if LAYOUT == "modern" then
  local removed = false
  for _, e in ipairs(hb.__bartex.__log) do if e[1] == "RemoveMaskTexture" then removed = true end end
  assert(removed, "health bar mask not removed")
end

-- action buttons
local b1 = ActionButton1
assert(b1.__normal.__alpha == 0, "button border not hidden")
b1.__normal.__alpha = 1; b1:SetNormalAtlas("UI-HUD-ActionBar-IconFrame")
assert(b1.__normal.__alpha == 0, "button border came back")
local cropped = false
for _, e in ipairs(b1.icon.__log) do if e[1] == "SetTexCoord" then cropped = true end end
assert(cropped, "icon not cropped")

if LAYOUT == "classic" then assert(b1.FloatingBG.__alpha == 0, "floating background not hidden") end

-- minimap
assert(Minimap.__mask == ns.WHITE and GetMinimapShape() == "SQUARE", "minimap not square")

-- Blizzard buttons sit on the square, and stay there when the game re-anchors them
local function lastPoint(o)
  for i = #o.__log, 1, -1 do if o.__log[i][1] == "SetPoint" then return o.__log[i] end end
end
local mail = LAYOUT == "classic" and MiniMapMailFrame or MinimapCluster.IndicatorFrame.MailFrame
local track = LAYOUT == "classic" and MiniMapTracking or MinimapCluster.Tracking
local queueBtn = LAYOUT == "classic" and MiniMapBattlefieldFrame or QueueStatusMinimapButton
assert(lastPoint(mail)[2] == "TOPRIGHT" and lastPoint(track)[2] == "TOPLEFT" and lastPoint(queueBtn)[2] == "BOTTOMLEFT", "buttons not on the square")
mail:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", 30, 50)   -- the game's round-border spot
local lp = lastPoint(mail)
assert(lp[2] == "TOPRIGHT" and lp[5] == -2 and lp[6] == -2, "mail button not put back on the square")
assert(lastPoint(TimeManagerClockButton)[2] == "BOTTOM", "clock not moved")
assert(#refreshed == 2, "addon buttons not refreshed")

-- power bar: Blizzard paints it white (atlas color), Ashwright gives it the rage color
local pbar = LAYOUT == "classic" and PlayerFrame.manabar or PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar
pbar:SetStatusBarColor(1, 1, 1)
assert(math.abs(pbar.__color[1] - 0.710) < 1e-3 and math.abs(pbar.__color[2] - 0.329) < 1e-3, "rage color not applied")

-- the target frame gets the player's ornate panel, and bars get a dark trough
assert(pbar.__ashTrough, "power bar has no trough")
do
  local tpb = LAYOUT == "classic" and TargetFrame.manabar or TargetFrame.TargetFrameContent.TargetFrameContentMain.ManaBar
  assert(tpb and tpb.__ashTrough, "target power bar has no trough")
end
-- panels are plain textures, never the backdrop template: its size math
-- breaks on the secret sizes the game gives unit frames in a group
for _, f in ipairs(frames) do
  assert(not (f.__template and tostring(f.__template):find("Backdrop")), "a frame still uses the backdrop template")
end
do
  local panel = (LAYOUT == "classic" and PlayerFrame or PlayerFrame).__ashPanel
  assert(panel.bg and #panel.edges == 4 and panel.outer and #panel.outer.edges == 4, "player panel not built from textures")
  -- a size the game makes secret: nothing in the panel may read it
  for _, fr in ipairs({ panel, panel.outer }) do
    fr.GetWidth = function() error("panel read its width") end
    fr.GetHeight = function() error("panel read its height") end
    fr.GetSize = function() error("panel read its size") end
  end
  panel:SetBackdropBorderColor(1, 0, 0); panel:SetBackdropColor(0, 0, 0, 0.5)
end

-- cast bars: art faded, flat fill, state colors (modern), panel
do
  local cb = LAYOUT == "classic" and CastingBarFrame or PlayerCastingBarFrame
  assert(cb.__ashPanel and cb.__ashTrough, "player cast bar not styled")
  if LAYOUT == "classic" then
    assert(CastingBarFrameBorder.__alpha == 0, "classic cast bar border not faded")
    CastingBarFrame:SetStatusBarColor(1, 0.7, 0)   -- the game's own cast color stays
    assert(CastingBarFrame.__color[2] == 0.7, "classic cast color overridden")
  else
    assert(cb.Border.__alpha == 0 and cb.TextBorder.__alpha == 0, "cast bar border not faded")
    cb:SetStatusBarColor(1, 1, 1)
    local g = ns.modules.castbars.TYPE_COLOR.channel
    assert(math.abs(cb.__color[2] - g[2]) < 1e-3, "channel color not applied")
    -- in a group the target's cast state is secret: plain cast color, no error
    local errs = #ns.db.errors
    TargetFrame.spellbar.barType = SECRET; TargetFrame.spellbar:SetStatusBarTexture("x")
    assert(#ns.db.errors == errs, "secret cast state errored: " .. tostring(ns.db.errors[#ns.db.errors]))
    local amber = ns.modules.castbars.TYPE_COLOR.standard
    assert(math.abs(TargetFrame.spellbar.__color[1] - amber[1]) < 1e-3, "secret cast state not shown as a cast")
    TargetFrame.spellbar.barType = "interrupted"; TargetFrame.spellbar:SetStatusBarTexture("x")
    local r = ns.modules.castbars.TYPE_COLOR.interrupted
    assert(math.abs(TargetFrame.spellbar.__color[1] - r[1]) < 1e-3, "interrupted color not applied")
    -- nothing moved before a target is shown
    assert(TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar:GetNumPoints() == 0,
           "target bars moved before the frame was laid out")
    TargetFrame.__shown = true
    ns.modules.unitframes.AlignTarget()
    -- target health bar: player's size, right edge kept, top on the player's line
    local thb = TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar
    local function at() local p, rel, rp, x, y = thb:GetPoint(1); return p, rel, rp, x, y end
    local p, rel, rp, x, y = at()
    assert(p == "TOPRIGHT" and rel == TargetFrame and rp == "TOPRIGHT" and x == -56 and y == -42,
           ("target bars not aligned: %s %s %s"):format(tostring(p), tostring(x), tostring(y)))
    assert(thb.__size[1] == 124 and thb.__size[2] == 18, "target bars not sized like the player's")
    -- the game now reports the moved bar; aligning again must not drift
    thb.__rect = { 302, 480, 124, 18 }
    ns.modules.unitframes.AlignTarget()
    p, rel, rp, x, y = at()
    assert(x == -56 and y == -42, "target alignment drifted: " .. tostring(x) .. " " .. tostring(y))
    -- stray outline: the icon slot hides with the hidden player cast bar icon
    assert(PlayerCastingBarFrame.Icon.__ashSlot.__shown == false, "icon slot shown for a hidden icon")
    -- auras slide under the panel: panel edge 470, frame bottom 440 -> y 28
    TargetFrame.__ashPanel.outer.__rect = { 240, 470, 250, 80 }
    TargetFrame:UpdateAuras()
    local a1, a2 = TargetFrame.__auras[1], TargetFrame.__auras[2]
    local _, _, _, ax, ay = a1:GetPoint(1)
    assert(ax == 5 and ay == 28, ("target auras not moved under the panel: %s %s"):format(tostring(ax), tostring(ay)))
    local _, r2, _, _, y2 = a2:GetPoint(1)
    assert(r2 == a1 and y2 == 0, "second aura should still hang from the first")
    TargetFrame:UpdateAuras()
    _, _, _, ax, ay = a1:GetPoint(1)
    assert(ay == 28, "auras moved twice: " .. tostring(ay))
    -- positions secret (in a group): auras move down a fixed 8 from the game's spot
    local outer = TargetFrame.__ashPanel.outer
    local savedBottom = outer.GetBottom
    outer.GetBottom = function() return nil end
    a1:ClearAllPoints(); a1:SetPoint("TOPLEFT", TargetFrame, "BOTTOMLEFT", 5, 32)   -- the game re-lays the auras
    TargetFrame:UpdateAuras()
    _, _, _, ax, ay = a1:GetPoint(1)
    assert(ay == 24, "auras not moved with secret positions: " .. tostring(ay))
    TargetFrame:UpdateAuras()
    _, _, _, ax, ay = a1:GetPoint(1)
    assert(ay == 24, "auras moved twice with secret positions: " .. tostring(ay))
    outer.GetBottom = savedBottom
    -- the game re-lays out the target bars in several steps; Ashwright waits
    -- until it's done, then leaves exactly one anchor (two clashing ones
    -- made the bars vanish on every other target)
    timerQueue = {}
    thb:ClearAllPoints()
    thb:SetPoint("TOPLEFT", TargetFrame, "TOPLEFT", 20, -30)
    assert(thb:GetNumPoints() == 1 and thb:GetPoint(1) == "TOPLEFT", "stepped in mid-layout")
    thb:SetPoint("BOTTOMRIGHT", TargetFrame, "TOPRIGHT", -56, -50)
    assert(thb:GetNumPoints() == 2, "stepped in mid-layout")
    thb.__rect = { 270, 490, 156, 20 }   -- where that layout puts it
    flushTimers()
    assert(thb:GetNumPoints() == 1, "target bar left with clashing anchors: " .. thb:GetNumPoints())
    p, rel, rp, x, y = at()
    assert(p == "TOPRIGHT" and rel == TargetFrame, "target bar not re-placed after the game's layout")
  end
end

if LAYOUT == "modern" then
  -- power bars sit right under the health bars at the same width, pinned to the
  -- unit frame itself, never to the health bar (the game positions some of
  -- its containers off the power bar: hanging one from the other made a loop)
  local main = TargetFrame.TargetFrameContent.TargetFrameContentMain
  local function check(bar, frame, point, x, y, w, h, what)
    assert(bar:GetNumPoints() == 1, what .. " has " .. bar:GetNumPoints() .. " anchors")
    local p, rel, rp, bx, by = bar:GetPoint(1)
    assert(p == point and rel == frame and rp == point and bx == x and by == y,
           ("%s misplaced: %s %s %s %s"):format(what, tostring(p), tostring(rel == frame), tostring(bx), tostring(by)))
    assert(bar.__size[1] == w and bar.__size[2] == h, what .. " wrong size")
  end
  local _, _, _, _, thy = main.HealthBarsContainer.HealthBar:GetPoint(1)
  check(main.ManaBar, TargetFrame, "TOPRIGHT", -56, thy - 18, 124, 10, "target mana bar")
  local pmain = PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
  check(pmain.HealthBarsContainer.HealthBar, PlayerFrame, "TOPLEFT", 60, -42, 124, 18, "player health bar")
  check(pmain.ManaBarArea.ManaBar, PlayerFrame, "TOPLEFT", 60, -60, 124, 10, "player mana bar")
end
for _, u in ipairs(ns.modules.unitframes.UNITS) do
  if u.key == "target" or u.key == "focus" then assert(u.ornate, u.key .. " not ornate") end
end

-- a health bar at the lowest frame level must still draw above its panel
if LAYOUT == "modern" then
  local thb2 = TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar
  local panel = TargetFrame.__ashPanel
  assert(panel and thb2.__level > panel.__level, ("target health under its panel: bar %d, panel %d"):format(thb2.__level, panel.__level))
  -- touching bars share one panel; a bar far away gets its own
  local ab = ns.modules.actionbars
  assert(ab.groups == 2, "expected 2 bar groups, got " .. tostring(ab.groups))
  local g1 = ab.holders[1]
  local _, _, _, gx, gy = g1:GetPoint(1)
  assert(gx == 320 and gy == 30 and g1.__size[1] == 524 and g1.__size[2] == 84,
         ("main + bottom-left group not fitted: %s %s %s %s"):format(tostring(gx), tostring(gy), tostring(g1.__size[1]), tostring(g1.__size[2])))
  assert(MainActionBar.__regions[1].__alpha == 0, "main bar divider not faded")
  -- panels sit on the BACKGROUND strata, below every button
  local strata
  for _, e in ipairs(g1.__log) do if e[1] == "SetFrameStrata" then strata = e[2] end end
  assert(strata == "BACKGROUND", "group panel not on BACKGROUND strata")
  -- hidden while Edit Mode is open, back after
  EditModeManagerFrame.__shown = true
  for _, fn in ipairs(EditModeManagerFrame.__hooks.OnShow) do fn() end
  assert(g1.__shown == false, "panel not hidden in Edit Mode")
  EditModeManagerFrame.__shown = false
  for _, fn in ipairs(EditModeManagerFrame.__hooks.OnHide) do fn() end
  assert(g1.__shown == true, "panel not back after Edit Mode")
  -- the target re-applies its health art straight onto the fill texture
  local tfill = TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar:GetStatusBarTexture()
  tfill:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health")
  assert(tfill.__file == ns.WHITE, "target health art came back")
  -- the name band is hidden for good
  local band = TargetFrame.TargetFrameContent.TargetFrameContentMain.ReputationColor
  band:Show()
  assert(band.__shown == false, "target name band came back")
  -- XP: ticks, background gone; rested band kept but flat
  local xc = MainStatusTrackingBarManager.__children[1]
  assert(xc.__children[2].BarDividerTexture.__alpha == 0, "xp tick not faded")
  assert(xc.__children[3].StatusBar.Background.__alpha == 0, "xp background not faded")
  local rb = xc.__children[3].ExhaustionLevelFillBar
  assert(rb.__file == ns.WHITE and rb.__alpha ~= 0, "rested band not flat or was hidden")
  -- the game makes the stripe solid; it goes back to dim
  rb:SetVertexColor(0.33, 0.36, 0.60, 1)
  assert(rb.__vc[4] == 0.55, "rested stripe left solid: " .. tostring(rb.__vc[4]))
  local xpf = xc.__children[3]
  assert(xpf.LeftCap.__alpha == 0 and xpf.RightCap.__alpha == 0, "xp end caps not faded")
  assert(xpf.StatusBar:GetStatusBarTexture().__alpha ~= 0, "xp fill was faded")
  -- hidden, not just faded: the game fades its art back in with animations
  assert(xpf.LeftCap.__shown == false and xc.BarFrameTexture.__shown == false, "xp art only faded, not hidden")
  xc.BarFrameTexture:SetShown(true)
  assert(xc.BarFrameTexture.__shown == false, "xp frame art came back through SetShown")
  -- a divider the game adds later (after a level-up) is swept too
  local late = new("Frame"); late.BarDividerTexture = new("Texture"); late.__regions = { late.BarDividerTexture }
  xc.__children[#xc.__children + 1] = late
  fire("PLAYER_LEVEL_UP")
  assert(late.BarDividerTexture.__shown == false, "a divider added later was not hidden")
  -- Edit Mode's selection highlight is left alone
  assert(xc.Selection.Center.__shown ~= false, "edit mode highlight hidden")
  assert(MainStatusTrackingBarManager.__children[1].StatusBar.__tex == ns.WHITE, "xp bar not flat")
  assert(MainStatusTrackingBarManager.__children[1].BarFrameTexture.__alpha == 0, "xp bar art not faded")
else
  assert(MainMenuExpBar.__tex == ns.WHITE, "classic xp bar not flat")
end
assert(MainMenuBarBackpackButton.__ash, "backpack not styled")

-- names lifted 4 px on every anchor point, and not twice when the game re-anchors one
local function pointY(fs, p) for i = 1, fs:GetNumPoints() do local pp, _, _, _, y = fs:GetPoint(i); if pp == p then return y end end end
assert(pointY(PlayerName, "TOPLEFT") == -1 and pointY(PlayerName, "TOPRIGHT") == -1, "name not lifted on both points")
PlayerName:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", 10, -8)
assert(pointY(PlayerName, "TOPLEFT") == -4 and pointY(PlayerName, "TOPRIGHT") == -1, "name offset stacked or lost: " ..
       tostring(pointY(PlayerName, "TOPLEFT")) .. " " .. tostring(pointY(PlayerName, "TOPRIGHT")))

-- XP bar: white (atlas-colored) becomes the accent; a real color stays
if LAYOUT == "modern" then
  local xsb = MainStatusTrackingBarManager.__children[1].StatusBar
  xsb:SetStatusBarColor(1, 1, 1)
  assert(math.abs(xsb.__color[1] - 0.788) < 0.01, "xp bar still white")
  xsb:SetStatusBarColor(0, 0.6, 0)
  assert(xsb.__color[2] == 0.6, "real bar color overwritten")
  -- dividers faded, also after the bar rebuilds them
  MultiBarBottomLeft:UpdateDividers()
  assert(divs[1].__alpha == 0 and divs[2].__alpha == 0, "dividers not faded")
end

-- fades stick when the game fades art back in (zoom buttons on hover)
local zoom = LAYOUT == "modern" and Minimap.ZoomIn or MinimapZoomIn
zoom:SetAlpha(1)
assert(zoom.__alpha == 0, "zoom button came back")

-- a text whose whole anchor is secret (the target's health text in a group)
local secretText = new("FontString")
secretText.__points = { { SECRET, SECRET, SECRET, SECRET, SECRET } }
local xpRoot = _G.MainStatusTrackingBarManager or _G.MainMenuExpBar
xpRoot.__regions = xpRoot.__regions or {}
table.insert(xpRoot.__regions, secretText)
SlashCmdList.ASHWRIGHT("inspect target"); SlashCmdList.ASHWRIGHT("inspect xp"); SlashCmdList.ASHWRIGHT("inspect nope")
for _, e in ipairs(AshwrightDB.inspect.xp.entries) do
  for k, v in pairs(e) do
    assert(not tostring(v):find("<secret>", 1, true), "inspect let a secret through in " .. k .. ": " .. tostring(v))
  end
end
SlashCmdList.ASHWRIGHT("nameoffset 6"); SlashCmdList.ASHWRIGHT("nameoffset 99")
assert(AshwrightDB.inspect and AshwrightDB.inspect.target and #AshwrightDB.inspect.target.entries > 0, "inspect target not saved")
assert(ChatFrame1.__ashPanel, "chat panel missing")
-- the chat panel covers the scroll bar and the input box
do
  local function br(panel)
    for i = 1, panel:GetNumPoints() do local p, _, _, x, y = panel:GetPoint(i); if p == "BOTTOMRIGHT" then return x, y end end
  end
  local x1, y1 = br(ChatFrame1.__ashPanel)
  assert(x1 == 14 and y1 == -36, ("chat 1 panel not over scroll bar and input box: %s %s"):format(tostring(x1), tostring(y1)))
  local x2, y2 = br(ChatFrame2.__ashPanel)
  assert(x2 == 14 and y2 == -36, ("chat 2 panel not over the hidden input box: %s %s"):format(tostring(x2), tostring(y2)))
end

-- fonts fall back to the game's when the optional files are missing
assert(ChatFrame1.__font[1] == "Fonts\\FRIZQT__.TTF" and ChatFrame1.__font[2] == 14, "chat font fallback or size")

-- nameplates: new plate styled, target gets the accent border
local p1 = makePlate("nameplate1"); makePlate("nameplate2")
inCombat = true   -- plates arrive in combat all the time
fire("NAME_PLATE_UNIT_ADDED", "nameplate1"); fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
fire("PLAYER_TARGET_CHANGED")
inCombat = false
local phb = LAYOUT == "modern" and p1.UnitFrame.HealthBarsContainer.healthBar or p1.UnitFrame.healthBar
assert(phb.__tex == ns.WHITE, "nameplate bar not flat")
assert(phb.border.__alpha == 0, "nameplate border not hidden")
assert(phb.Frame.Left.__shown == false and phb.Frame.Right.__shown == false, "nameplate rounded border still drawn")
assert(phb.Gloss.__shown == false, "nameplate gloss still drawn")
assert(phb:GetStatusBarTexture().__shown ~= false, "nameplate fill was hidden")
assert(phb.myHealPrediction.Fill.__shown ~= false, "heal prediction was hidden")
if LAYOUT == "modern" then
  local uf = p1.UnitFrame
  local lv = uf.PlayerLevelDiffFrame
  assert(lv.playerLevelDiffIcon.__shown == false and lv.selectedBorder.__shown == false, "level badge art still drawn")
  assert(lv.highLevelTexture.__shown ~= false, "skull icon hidden")
  assert(lv.__ashBox and lv.__ashBox.__level < lv.__level, "level box missing or drawn over the number")
  local cb = uf.CastBarsContainer.castBar
  assert(cb.__tex == ns.WHITE, "plate cast bar not flat")
  assert(cb.Background.__shown == false and cb.Border.__shown == false, "plate cast bar art still drawn")
  local g = ns.modules.castbars.TYPE_COLOR.channel
  assert(cb.__color and math.abs(cb.__color[2] - g[2]) < 1e-3, "plate cast bar not in the cast colors")
  -- a secret "shown" from the game never errors and never brings art back
  local errs = #ns.db.errors
  lv.selectedBorder:SetShown(SECRET)
  assert(#ns.db.errors == errs and lv.selectedBorder.__shown == false, "secret SetShown broke the hide")
end

-- slash commands and scan
SlashCmdList.ASHWRIGHT("module minimap off")
assert(GetMinimapShape() == "ROUND", "shape should follow the minimap module setting")
SlashCmdList.ASHWRIGHT("module minimap on")
for _, c in ipairs({ "", "help", "module chat off", "module nope on", "ornate off", "accent #b5541e", "accent zz", "errors", "scan" }) do
  SlashCmdList.ASHWRIGHT(c)
end
assert(AshwrightDB.scan and AshwrightDB.scan.modules.unitframes, "scan not saved")
assert(#AshwrightDB.errors == 0, "errors: " .. table.concat(AshwrightDB.errors, " | "))
print(("%s layout, combat at login %s: ok. unitframes %s, actionbars %s, minimap %s, nameplates %s, tooltip %s"):format(
  LAYOUT, tostring(COMBAT_AT_LOGIN),
  AshwrightDB.scan.modules.unitframes.summary, AshwrightDB.scan.modules.actionbars.summary,
  AshwrightDB.scan.modules.minimap.summary, AshwrightDB.scan.modules.nameplates.summary,
  AshwrightDB.scan.modules.tooltip.summary))
