--[[
Ashwright: the buff and debuff bars by the minimap.
Copyright (C) 2026 Zudryx. GPL-3.0-or-later; see Core.lua.

Each aura button is rebuilt in Ashwright's look instead of drawn over: the
icon is cropped square and sits in a dark slot with a 1px iron edge. The
game's debuff border and weapon-enchant border are faded out, and the color
they carry (debuff type, enchant) moves onto that edge. Time left and stack
count use the addon's fonts. The game still owns which auras show and where.
]]

local _, ns = ...
local M = ns.Module("buffs")
local C = ns.C

-- where Forever keeps the player's aura buttons (from /ash dump)
local CONTAINERS = { "BuffFrame.AuraContainer", "DebuffFrame.AuraContainer" }
local ENCHANT = { 0.541, 0.380, 0.678 }   -- weapon enchant: violet, like empowered casts

local function isAuraButton(b)
  return type(b) == "table" and b.Icon ~= nil and b.Icon.SetTexCoord ~= nil
end

local function setEdge(b, r, g, bl)
  for _, t in ipairs(b.__ashEdges) do t:SetVertexColor(r, g, bl, 1) end
end

-- the edge shows what the game's borders would have: debuff type, enchant, or iron
local function recolor(b)
  local deb, ench = b.DebuffBorder, b.TempEnchantBorder
  if ench and ench.IsShown and ns.safe(ench.IsShown, ench) == true then
    setEdge(b, ENCHANT[1], ENCHANT[2], ENCHANT[3]); return
  end
  if deb and deb.IsShown and ns.safe(deb.IsShown, deb) == true then
    local r, g, bl = ns.safe(deb.GetVertexColor, deb)
    if type(r) == "number" and not ns.isSecret(r) and not ns.isSecret(g) and not ns.isSecret(bl) then
      setEdge(b, r, g, bl); return
    end
  end
  setEdge(b, C.slotBorder[1], C.slotBorder[2], C.slotBorder[3])
end

function M.Style(b)
  if not isAuraButton(b) then return end
  local icon = b.Icon
  if not b.__ash then
    b.__ash = true
    local px = ns.Pixel(b)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- slot behind the icon, edge just outside it: our own textures on the
    -- button, so nothing of ours sits over the icon
    local bg = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetTexture(ns.WHITE)
    bg:SetVertexColor(unpack(C.slot))
    bg:SetPoint("TOPLEFT", icon, "TOPLEFT", -px, px)
    bg:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", px, -px)
    b.__ashSlot = bg
    local edges = {}
    local function edge(p1, p2, horizontal)
      local t = b:CreateTexture(nil, "OVERLAY", nil, 7)
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
    b.__ashEdges = edges
    -- the game recolors the debuff border per aura; follow it
    if b.DebuffBorder and b.DebuffBorder.SetVertexColor then
      ns.Keep(b.DebuffBorder, "SetVertexColor", function() recolor(b) end)
    end
    for _, k in ipairs({ "DebuffBorder", "TempEnchantBorder" }) do
      local t = b[k]
      if t then
        ns.Keep(t, "Show", function() recolor(b) end)
        ns.Keep(t, "Hide", function() recolor(b) end)
        ns.Keep(t, "SetShown", function() recolor(b) end)
      end
    end
    if b.Duration then
      ns.Font(b.Duration, "body", nil, "OUTLINE")
      b.Duration:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    end
    if b.Count then ns.Font(b.Count, "body", nil, "OUTLINE") end
  end
  -- faded, not hidden: whether they are shown still says what the edge shows
  ns.Kill(b.DebuffBorder)
  ns.Kill(b.TempEnchantBorder)
  recolor(b)
end

function M.Sweep()
  for _, path in ipairs(CONTAINERS) do
    local c = ns.Find("buffs", path, path)
    if c and c.GetChildren then
      for _, b in ipairs({ c:GetChildren() }) do M.Style(b) end
    end
  end
  local arrow = ns.Path("BuffFrame.CollapseAndExpandButton")
  if arrow then
    for _, k in ipairs({ "NormalTexture", "PushedTexture" }) do
      local t = arrow[k] or (arrow["Get" .. k] and arrow["Get" .. k](arrow))
      if t and t.SetVertexColor then
        -- the arrow art is gold; greyed, then tinted, it reads as iron
        if t.SetDesaturated then t:SetDesaturated(true) end
        t:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
      end
    end
  end
end

-- new buttons come from a pool as auras appear: sweep after the game's own update
local pending = false
local function sweepSoon()
  if pending then return end
  pending = true
  local function go() pending = false; ns.Guard("buffs", M.Sweep) end
  if C_Timer and C_Timer.After then C_Timer.After(0, go) else go() end
end
M.SweepSoon = sweepSoon

function M.Enable()
  ns.Guard("buffs", M.Sweep)
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:RegisterEvent("UNIT_AURA")
  ev:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_AURA" and unit ~= "player" then return end
    sweepSoon()
  end)
  -- the frames' own update methods, where this client has them
  for _, name in ipairs({ "BuffFrame", "DebuffFrame" }) do
    local f = _G[name]
    if f then
      ns.Each(function(m) if f[m] then hooksecurefunc(f, m, sweepSoon) end end,
              "Update", "UpdateAuraButtons", "UpdateGridLayout", "RefreshAuras")
    end
  end
end
