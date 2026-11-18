--[[
Ashwright: windows (character, spellbook and talents, professions, world map,
guild and communities, group finder ... every window on the game's metal frame).
Copyright (C) 2026 Zudryx. GPL-3.0-or-later; see Core.lua.

/ash dump showed they share one frame: a metal nine-slice drawn over the
content, a stone background texture, top tile streaks, a round portrait in
the corner, a title bar and a red close button. That frame is replaced, not
drawn over:
  - the metal is faded and the double iron border is drawn in its place, on
    the same frame the metal used (already above the content, so no frame
    levels change: the world map is easily tainted)
  - the stone background texture itself becomes the flat panel color
  - streaks and portrait go, the title takes the title font
  - the close button's red art goes; an iron x on a dark slot replaces it
Windows are found by their frame (a nine-slice whose corner is the metal
atlas), so ones that load later (professions, talents) are found too.
]]

local _, ns = ...
local M = ns.Module("windows")
local C = ns.C

local function atlasOf(t)
  local a = t and t.GetAtlas and ns.safe(t.GetAtlas, t)
  return type(a) == "string" and not ns.isSecret(a) and a or nil
end

-- a window on the game's metal frame
function M.IsWindow(f)
  local nine = type(f) == "table" and rawget(f, "NineSlice") or nil
  if type(nine) ~= "table" then return false end
  local a = atlasOf(rawget(nine, "TopLeftCorner"))
  return a ~= nil and a:find("Frame%-.*Metal") ~= nil
end

local function named(f, suffix)
  local n = f.GetName and f:GetName()
  return n and _G[n .. suffix] or nil
end

-- the double iron border, as outlines on the nine-slice frame: an iron line
-- on the window's edge, a dark 3 px band outside it, a thin line around that
local function border(nine, win)
  local px = ns.Pixel(win)
  local inner = ns.Box(nine, px, false)
  inner:SetAllPoints(win)
  inner:SetBackdropBorderColor(unpack(C.ornate))
  local band = ns.Box(nine, 3 * px, false)
  band:SetPoint("TOPLEFT", win, "TOPLEFT", -3 * px, 3 * px)
  band:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 3 * px, -3 * px)
  band:SetBackdropBorderColor(unpack(C.outer))
  local line = ns.Box(nine, px, false)
  line:SetPoint("TOPLEFT", win, "TOPLEFT", -4 * px, 4 * px)
  line:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 4 * px, -4 * px)
  line:SetBackdropBorderColor(unpack(C.outerLine))
  nine.__ashBorder = { inner, band, line }
end

-- the stone background becomes the flat panel color, and stays that way
local function flatten(t)
  if not t or not t.SetTexture or t.__ashFlat then return end
  t.__ashFlat = true
  local function paint(self)
    self.__ashPainting = true
    self:SetTexture(ns.WHITE)
    self:SetVertexColor(unpack(C.panelSolid))
    self.__ashPainting = nil
  end
  paint(t)
  for _, m in ipairs({ "SetTexture", "SetAtlas" }) do
    ns.Keep(t, m, function(self) if not self.__ashPainting then paint(self) end end)
  end
end

-- the close button: red art faded, a dark slot with an iron x in its place
function M.CloseButton(b)
  if not b or b.__ashClose then return end
  b.__ashClose = true
  for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
    local t = b[getter] and b[getter](b)
    if t then ns.Kill(t) end
  end
  for _, r in ipairs({ b:GetRegions() }) do
    if r.GetObjectType and r:GetObjectType() == "Texture" then ns.Kill(r) end
  end
  local px = ns.Pixel(b)
  local slot = ns.Box(b, px)
  slot:SetPoint("CENTER", b, "CENTER", 0, 0)
  slot:SetSize(16, 16)
  slot:SetBackdropColor(unpack(C.slot))
  slot:SetBackdropBorderColor(unpack(C.border))
  local strokes = {}
  for _, angle in ipairs({ 45, -45 }) do
    local s = slot:CreateTexture(nil, "OVERLAY")
    s:SetTexture(ns.WHITE)
    s:SetSize(11, 2 * px)
    s:SetPoint("CENTER", slot, "CENTER", 0, 0)
    if s.SetRotation then s:SetRotation(math.rad(angle)) end
    s:SetVertexColor(unpack(C.muted))
    strokes[#strokes + 1] = s
  end
  b.__ashX = strokes
  local function tint(c) for _, s in ipairs(strokes) do s:SetVertexColor(c[1], c[2], c[3]) end end
  b:HookScript("OnEnter", function() tint(C.title) end)
  b:HookScript("OnLeave", function() tint(C.muted) end)
end

function M.Style(f)
  if f.__ashWindow or not M.IsWindow(f) then return end
  f.__ashWindow = true
  local nine = f.NineSlice
  ns.KillTextures(nine)
  border(nine, f)
  flatten(f.Bg or named(f, "Bg"))
  ns.Kill(f.TopTileStreaks)
  local pc = f.PortraitContainer
  ns.Each(function(t) ns.Kill(t) end,
          f.portrait, pc and pc.portrait, named(f, "Portrait"))
  local title = (f.TitleContainer and f.TitleContainer.TitleText) or named(f, "TitleText")
  if title then
    ns.Font(title, "title")
    title:SetTextColor(C.title[1], C.title[2], C.title[3])
  end
  M.CloseButton(f.CloseButton or named(f, "CloseButton"))
end

-- every frame the game has made: style the windows not done yet
function M.Sweep()
  if not EnumerateFrames then return end
  local f = EnumerateFrames()
  while f do
    -- a cheap look first (raw fields only); the guarded work is for windows
    if not rawget(f, "__ashWindow") and rawget(f, "NineSlice") then
      local ok, forbidden = pcall(f.IsForbidden, f)
      if ok and not forbidden and M.IsWindow(f) then ns.Guard("windows style", M.Style, f) end
    end
    f = EnumerateFrames(f)
  end
end

-- windows of load-on-demand parts appear when those load; coalesce bursts
local pending = false
function M.SweepSoon()
  if pending then return end
  pending = true
  local function go() pending = false; ns.Guard("windows", M.Sweep) end
  if C_Timer and C_Timer.After then C_Timer.After(0.5, go) else go() end
end

function M.Enable()
  ns.Guard("windows", M.Sweep)
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("ADDON_LOADED")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:SetScript("OnEvent", M.SweepSoon)
end
