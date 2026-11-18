--[[
Ashwright: what sits inside windows (item slots, panel buttons, side tabs).
Copyright (C) 2026 Zudryx. GPL-3.0-or-later; see Core.lua.

/ash dump showed these are built the same way in every window:
  item slots (gear, bags, merchant, buyback, loot, mail; bank slots carry a
    bankslot Background and slot frame instead of the plate): a 37x37 button, its icon
    rounded by a mask, a quality border (IconBorder), the square plate
    UI-Quickslot2 (file 130841) and a highlight; an empty bag slot shows the
    bags-item-slot atlas as its icon
  panel buttons: Left / Middle / Right pieces of UI-Panel-Button (file 130828)
  side tabs (character, group finder, friends): a common-sidetab Background,
    a masked icon, a SelectedTexture and a hover atlas
  insets (lists and money boxes in the auction house, mail, gossip): a thin
    UI-Frame-Inner nine-slice, replaced by a 1 px iron line
Each is replaced, not drawn over: the game's art is faded, and Ashwright's
dark slot with a thin edge takes its place. The quality color, the selected
tab and the hover move onto that edge.
]]

local _, ns = ...
local M = ns.Module("controls")
local C = ns.C

local QUICKSLOT = "130841"          -- the item slot plate
local PANEL_BUTTON = { ["130828"] = true, ["130829"] = true, ["130827"] = true }   -- up, down, disabled

local function fileOf(t)
  if not t then return nil end
  local a = ns.safe(t.GetAtlas, t)
  if type(a) == "string" and not ns.isSecret(a) then return a end
  local f = ns.safe(t.GetTexture, t)
  if f ~= nil and not ns.isSecret(f) then return tostring(f) end
end

-- a dark slot with a 1 px edge, as textures on the frame itself (nothing of
-- ours over the icon); returns the edge textures
local function slot(f, around, out)
  local px = ns.Pixel(f)
  out = out or px
  local bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  bg:SetTexture(ns.WHITE)
  bg:SetVertexColor(unpack(C.slot))
  bg:SetPoint("TOPLEFT", around, "TOPLEFT", -out, out)
  bg:SetPoint("BOTTOMRIGHT", around, "BOTTOMRIGHT", out, -out)
  local edges = {}
  local function edge(p1, p2, horizontal)
    local t = f:CreateTexture(nil, "OVERLAY", nil, 7)
    t:SetTexture(ns.WHITE)
    t:SetPoint(p1, bg, p1)
    t:SetPoint(p2, bg, p2)
    if horizontal then t:SetHeight(px) else t:SetWidth(px) end
    edges[#edges + 1] = t
  end
  edge("TOPLEFT", "TOPRIGHT", true)
  edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
  edge("TOPLEFT", "BOTTOMLEFT", false)
  edge("TOPRIGHT", "BOTTOMRIGHT", false)
  return edges, bg
end

local function paint(edges, c)
  for _, t in ipairs(edges) do t:SetVertexColor(c[1], c[2], c[3], 1) end
end

local function unmask(icon, mask)
  if icon and mask and icon.RemoveMaskTexture then ns.safe(icon.RemoveMaskTexture, icon, mask) end
end

---------------------------------------------------------------- item slots

local function iconOf(b)
  local n = b.GetName and b:GetName()
  return b.icon or b.Icon or (n and _G[n .. "IconTexture"])
end

-- bank slots have no plate: an empty-slot Background (bags-item-bankslot64)
-- and a bank-frame-bag-slotframe texture instead (/ash dump)
local function bankArt(b)
  local bg = rawget(b, "Background")
  local a = bg and fileOf(bg)
  return a ~= nil and a:find("^bags%-item%-") ~= nil
end

function M.IsItemSlot(b)
  if iconOf(b) == nil then return false end
  local nt = b.GetNormalTexture and ns.safe(b.GetNormalTexture, b)
  if nt ~= nil and fileOf(nt) == QUICKSLOT then return true end
  return rawget(b, "IconBorder") ~= nil and bankArt(b)
end

-- the game's art on a slot: plate, quality border, bank backing and frame.
-- Faded again on every look, since some windows (loot) bring it back.
local function fadeSlotArt(b)
  local nt = b.GetNormalTexture and ns.safe(b.GetNormalTexture, b)
  if nt and fileOf(nt) == QUICKSLOT then ns.Kill(nt) end
  if b.IconBorder then ns.Kill(b.IconBorder) end
  if bankArt(b) then ns.Kill(b.Background) end
  for _, r in ipairs({ b:GetRegions() }) do
    if r.GetObjectType and r:GetObjectType() == "Texture" and fileOf(r) == "bank-frame-bag-slotframe" then ns.Kill(r) end
  end
end

-- the edge shows the item's quality, as the game's quality border did
local function slotColor(b)
  local qb = b.IconBorder
  if qb and ns.safe(qb.IsShown, qb) == true then
    local r, g, bl = ns.safe(qb.GetVertexColor, qb)
    if type(r) == "number" and not ns.isSecret(r) and not ns.isSecret(g) and not ns.isSecret(bl) then
      paint(b.__ashEdges, { r, g, bl }); return
    end
  end
  paint(b.__ashEdges, C.slotBorder)
end

-- an empty bag slot shows the game's empty-slot art as its icon: our slot is
-- the empty look, so that art is hidden while it is the icon
local function emptyArt(icon)
  local a = fileOf(icon)
  icon:SetAlpha((a and a:find("^bags%-item%-slot")) and 0 or 1)
end

function M.StyleItemSlot(b)
  if b.__ashSlot then fadeSlotArt(b); slotColor(b); return end
  b.__ashSlot = true
  local icon = iconOf(b)
  fadeSlotArt(b)
  unmask(icon, b.Mask)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.__ashEdges = slot(b, icon)
  local qb = b.IconBorder
  if qb then
    -- faded (above), not hidden: whether it is shown still says the quality
    ns.Each(function(m) ns.Keep(qb, m, function() slotColor(b) end) end,
            "SetVertexColor", "Show", "Hide", "SetShown")
  end
  ns.Each(function(m) ns.Keep(icon, m, function(self) emptyArt(self) end) end, "SetAtlas", "SetTexture")
  emptyArt(icon)
  slotColor(b)
end

---------------------------------------------------------------- panel buttons

function M.IsPanelButton(b)
  local left = rawget(b, "Left")
  return type(left) == "table" and PANEL_BUTTON[fileOf(left) or ""] == true
         and rawget(b, "Middle") ~= nil and rawget(b, "Right") ~= nil
end

function M.StylePanelButton(b)
  if b.__ashButton then return end
  b.__ashButton = true
  ns.Each(function(t) ns.Kill(t) end, b.Left, b.Middle, b.Right)
  local hl = b.GetHighlightTexture and b:GetHighlightTexture()
  if hl then ns.Kill(hl) end
  -- textures on the button itself, under its text
  local edges = slot(b, b, 0)
  paint(edges, C.border)
  b.__ashEdges = edges
  b:HookScript("OnEnter", function() paint(edges, C.ornate) end)
  b:HookScript("OnLeave", function() paint(edges, C.border) end)
  local fs = b.GetFontString and b:GetFontString()
  if fs then ns.Font(fs, "body") end
end

---------------------------------------------------------------- side tabs

function M.IsSideTab(t)
  local bg = rawget(t, "Background")
  return type(bg) == "table" and fileOf(bg) == "common-sidetab" and rawget(t, "Icon") ~= nil
end

local function tabColor(t)
  local sel = t.SelectedTexture
  local on = sel and ns.safe(sel.IsShown, sel) == true
  if t.__ashHover then paint(t.__ashEdges, C.title)
  elseif on then paint(t.__ashEdges, C.ornate)
  else paint(t.__ashEdges, C.slotBorder) end
  -- the chosen tab reads brighter than the rest
  t.Icon:SetVertexColor(on and 1 or 0.6, on and 1 or 0.6, on and 1 or 0.6)
end

function M.StyleSideTab(t)
  if t.__ashTab then return end
  t.__ashTab = true
  ns.Kill(t.Background)
  ns.Kill(t.HighlightTexture)
  ns.Kill(t.TabGlow)
  unmask(t.Icon, t.Mask)
  t.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  t.__ashEdges = slot(t, t.Icon, -3)
  local sel = t.SelectedTexture
  if sel then
    ns.Kill(sel)
    ns.Each(function(m) ns.Keep(sel, m, function() tabColor(t) end) end, "Show", "Hide", "SetShown")
  end
  if t.HookScript then
    t:HookScript("OnEnter", function() t.__ashHover = true; tabColor(t) end)
    t:HookScript("OnLeave", function() t.__ashHover = nil; tabColor(t) end)
  end
  tabColor(t)
end

---------------------------------------------------------------- insets

-- the thin inner frame around lists and money boxes (UI-Frame-Inner* nine-slice)
function M.IsInset(f)
  local nine = rawget(f, "NineSlice")
  local c = type(nine) == "table" and rawget(nine, "TopLeftCorner") or nil
  return c ~= nil and fileOf(c) == "UI-Frame-InnerTopLeft"
end

function M.StyleInset(f)
  if f.__ashInset then return end
  f.__ashInset = true
  local nine = f.NineSlice
  ns.KillTextures(nine)
  local line = ns.Box(nine, ns.Pixel(f), false)
  line:SetAllPoints(nine)
  line:SetBackdropBorderColor(unpack(C.border))
  nine.__ashLine = line
end

---------------------------------------------------------------- sweep

function M.Sweep()
  if not EnumerateFrames then return end
  local f = EnumerateFrames()
  while f do
    local ok, kind = pcall(function()
      if f:IsForbidden() then return nil end
      if rawget(f, "Left") and M.IsPanelButton(f) then return "button" end
      if rawget(f, "Background") and M.IsSideTab(f) then return "tab" end
      if rawget(f, "NineSlice") and M.IsInset(f) then return "inset" end
      if f.GetNormalTexture and f:GetObjectType() == "Button" and M.IsItemSlot(f) then return "slot" end
    end)
    if ok and kind == "slot" then ns.Guard("controls slot", M.StyleItemSlot, f)
    elseif ok and kind == "button" then ns.Guard("controls button", M.StylePanelButton, f)
    elseif ok and kind == "tab" then ns.Guard("controls tab", M.StyleSideTab, f)
    elseif ok and kind == "inset" then ns.Guard("controls inset", M.StyleInset, f) end
    f = EnumerateFrames(f)
  end
end

-- windows fill their slots as they open (bags, merchant pages): sweep then
local pending = false
function M.SweepSoon()
  if pending then return end
  pending = true
  local function go() pending = false; ns.Guard("controls", M.Sweep) end
  if C_Timer and C_Timer.After then C_Timer.After(0, go) else go() end
end

function M.Enable()
  ns.Guard("controls", M.Sweep)
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("ADDON_LOADED")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:RegisterEvent("BAG_UPDATE_DELAYED")
  ev:RegisterEvent("MERCHANT_UPDATE")
  -- windows that fill their slots as they open
  for _, e in ipairs({ "LOOT_OPENED", "LOOT_SLOT_CHANGED", "BANKFRAME_OPENED", "PLAYERBANKSLOTS_CHANGED",
                       "MAIL_SHOW", "MAIL_INBOX_UPDATE", "AUCTION_HOUSE_SHOW", "TRADE_SHOW" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  ev:SetScript("OnEvent", M.SweepSoon)
end
