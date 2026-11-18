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
  -- the bags spell it in lower case: ui-frame-portraitmetal-cornertopleftsmall
  return a ~= nil and a:lower():find("frame%-.*metal") ~= nil
end

-- a dialog on the game's diamond-metal frame (the game menu): a Border frame
-- holding the corners, edges and a Bg texture, and a Header plate on top
function M.IsDialog(f)
  local border = type(f) == "table" and rawget(f, "Border") or nil
  if type(border) ~= "table" then return false end
  local a = atlasOf(rawget(border, "TopLeftCorner"))
  return a ~= nil and a:lower():find("diamondmetal") ~= nil
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
  for _, m in ipairs({ "SetTexture", "SetAtlas", "SetColorTexture", "SetVertexColor" }) do
    ns.Keep(t, m, function(self) if not self.__ashPainting then paint(self) end end)
  end
end

-- a background that is a frame of its own (bags, settings: a small nine-slice
-- of dark textures): its art goes and one flat texture fills it
local function flattenFrame(bg)
  if not bg or bg.__ashFlat then return end
  bg.__ashFlat = true
  ns.KillTextures(bg)
  local t = bg:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetAllPoints(bg)
  t:SetTexture(ns.WHITE)
  t:SetVertexColor(unpack(C.panelSolid))
  bg.__ashFill = t
end

local function background(bg)
  if not bg then return end
  if bg.GetObjectType and bg:GetObjectType() == "Texture" then flatten(bg) else flattenFrame(bg) end
end

local function titleFont(fs)
  if not fs then return end
  ns.Font(fs, "title")
  fs:SetTextColor(C.title[1], C.title[2], C.title[3])
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
  background(f.Bg or named(f, "Bg"))
  ns.Kill(f.TopTileStreaks)
  local pc = f.PortraitContainer
  ns.Each(function(t) ns.Kill(t) end,
          f.portrait, pc and pc.portrait, named(f, "Portrait"))
  -- the title: in the title bar, or (settings) on the nine-slice itself
  titleFont((f.TitleContainer and f.TitleContainer.TitleText) or named(f, "TitleText") or rawget(nine, "Text"))
  -- settings keeps its x as ClosePanelButton; its CloseButton is a text button
  M.CloseButton(f.ClosePanelButton or f.CloseButton or named(f, "CloseButton"))
end

function M.StyleDialog(f)
  if f.__ashWindow or not M.IsDialog(f) then return end
  f.__ashWindow = true
  local border = f.Border
  local keep = {}
  if border.Bg then flatten(border.Bg); keep[border.Bg] = true end
  ns.KillTextures(border, keep)
  local px = ns.Pixel(f)
  local outline = ns.Box(border, px, false)
  outline:SetAllPoints(f)
  outline:SetBackdropBorderColor(unpack(C.ornate))
  local band = ns.Box(border, 3 * px, false)
  band:SetPoint("TOPLEFT", f, "TOPLEFT", -3 * px, 3 * px)
  band:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 3 * px, -3 * px)
  band:SetBackdropBorderColor(unpack(C.outer))
  local line = ns.Box(border, px, false)
  line:SetPoint("TOPLEFT", f, "TOPLEFT", -4 * px, 4 * px)
  line:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 4 * px, -4 * px)
  line:SetBackdropBorderColor(unpack(C.outerLine))
  border.__ashBorder = { outline, band, line }
  -- the header plate becomes a small iron-edged plate behind the title; it
  -- hangs from the menu (below the header), so the title text stays on top
  local header = f.Header
  if header then
    ns.KillTextures(header)
    local plate = ns.Box(f, px)
    plate:SetPoint("TOPLEFT", header, "TOPLEFT", 6, -6)
    plate:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -6, 8)
    plate:SetBackdropColor(unpack(C.panelSolid))
    plate:SetBackdropBorderColor(unpack(C.ornate))
    header.__ashPlate = plate
    titleFont(header.Text)
  end
end

-- every frame the game has made: style the windows not done yet
function M.Sweep()
  if not EnumerateFrames then return end
  local f = EnumerateFrames()
  while f do
    -- a cheap look first (raw fields only); the guarded work is for windows
    if not rawget(f, "__ashWindow") and (rawget(f, "NineSlice") or rawget(f, "Border")) then
      local ok, forbidden = pcall(f.IsForbidden, f)
      if ok and not forbidden then
        if M.IsWindow(f) then ns.Guard("windows style", M.Style, f)
        elseif M.IsDialog(f) then ns.Guard("windows dialog", M.StyleDialog, f) end
      end
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
