--[[
Ashwright: the micro menu (character, spellbook, quest log ... game menu).
Copyright (C) 2026 Zudryx. GPL-3.0-or-later; see Core.lua.

Replaces the menu's look instead of drawing over it: the bar's border and
background art go, one panel with the double iron border sits behind the
whole menu, and each button's red plate becomes a dark slot with a thin iron
edge. The buttons' own icons, mouseover art, notification badges and the
performance bar stay. The bags bar's border art goes with the menu's.
]]

local _, ns = ...
local M = ns.Module("micromenu")
local C = ns.C

-- buttons sit 27 px apart but are 32 wide (from /ash dump): the slot is
-- inset so neighbours never overlap and leave a 1 px gap
local INSET_X, INSET_Y = 3, 4

local function isMicroButton(b)
  return type(b) == "table" and b.Background ~= nil and b.GetObjectType ~= nil
         and b:GetObjectType() == "Button"
end

local function slot(b)
  if b.__ashSlot then return end
  local px = ns.Pixel(b)
  local bg = b:CreateTexture(nil, "BACKGROUND", nil, -8)
  bg:SetTexture(ns.WHITE)
  bg:SetVertexColor(unpack(C.slot))
  bg:SetPoint("TOPLEFT", b, "TOPLEFT", INSET_X, -INSET_Y)
  bg:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -INSET_X, INSET_Y)
  b.__ashSlot = bg
  local edges = {}
  local function edge(p1, p2, horizontal)
    local t = b:CreateTexture(nil, "BACKGROUND", nil, -7)
    t:SetTexture(ns.WHITE)
    t:SetVertexColor(unpack(C.slotBorder))
    t:SetPoint(p1, bg, p1)
    t:SetPoint(p2, bg, p2)
    if horizontal then t:SetHeight(px) else t:SetWidth(px) end
    edges[#edges + 1] = t
  end
  edge("TOPLEFT", "TOPRIGHT", true)
  edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
  edge("TOPLEFT", "BOTTOMLEFT", false)
  edge("TOPRIGHT", "BOTTOMRIGHT", false)
  b.__ashEdges = edges
end

function M.StyleButton(b)
  if not isMicroButton(b) then return end
  -- the red plate (the game swaps its atlas on press; it stays faded)
  ns.Kill(b.Background)
  ns.Kill(b.Shadow)          -- the character button's portrait shadow
  slot(b)
end

function M.Sweep()
  local menu = ns.Find("micromenu", "menu", "MicroMenu")
  if not menu then return end
  ns.Kill(menu.BorderArt)
  ns.Kill(menu.BackgroundArt)
  local bags = ns.Path("BagsBar")
  if bags then ns.Kill(bags.BorderArt) end
  if menu.GetChildren then
    for _, b in ipairs({ menu:GetChildren() }) do M.StyleButton(b) end
  end
  if not menu.__ashPanel then
    menu.__ashPanel = ns.Panel(menu, { ornate = true, pad = 1 })
  end
end

function M.Enable()
  ns.Guard("micromenu", M.Sweep)
  -- the game re-lays the menu (buttons added or moved); style what is new
  local menu = _G.MicroMenu
  if menu then
    ns.Each(function(m)
      if menu[m] then hooksecurefunc(menu, m, function() ns.Run("micromenu", M.Sweep) end) end
    end, "Layout", "AddButton")
  end
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:SetScript("OnEvent", function() ns.Run("micromenu", M.Sweep) end)
end
