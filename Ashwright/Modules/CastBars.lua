--[[
Ashwright: cast bars (player, target, focus).
Copyright (C) 2026 Zudryx. GPL-3.0-or-later; see Core.lua.

Fades the cast bar art and gives the bar the same flat fill and dark panel as
the unit frames. The fill is colored by what the bar shows: a cast, a
channel, a cast that can't be interrupted, or an interrupted cast. The spell
icon is cropped square. Where the spell name sits under the bar, the panel
reaches down to cover it.
]]

local _, ns = ...
local M = ns.Module("castbars")
local C = ns.C

-- player bar is ornate, like the player frame; target and focus match theirs
local BARS = {
  { key = "player", ornate = true, paths = { "PlayerCastingBarFrame", "CastingBarFrame" } },
  { key = "target", ornate = true, paths = { "TargetFrame.spellbar", "TargetFrameSpellBar" } },
  { key = "focus",  ornate = true, paths = { "FocusFrame.spellbar", "FocusFrameSpellBar" } },
}

-- the modern UI names its state in barType and paints it with the atlas;
-- the older UI sets the bar color itself, which the flat fill keeps
local TYPE_COLOR = {
  standard        = { 0.788, 0.612, 0.255 },   -- cast: amber
  channel         = { 0.341, 0.557, 0.271 },   -- channel: green
  uninterruptable = { 0.451, 0.443, 0.420 },   -- can't be interrupted: grey
  interrupted     = { 0.608, 0.165, 0.149 },   -- interrupted or failed: crimson
  empowered       = { 0.541, 0.380, 0.678 },   -- empowered: violet
}
M.TYPE_COLOR = TYPE_COLOR

-- art that the modern and older cast bars draw around the fill
local ART = { "Border", "TextBorder", "Background", "Flash", "BorderShield", "Shine",
              "InterruptGlow", "ChargeFlash", "StandardGlow", "CraftGlow", "EnergyGlow",
              "ChargeGlow", "BaseGlow" }
local NAMED_ART = { "Border", "Flash", "BorderShield" }

local function recolor(bar)
  local c = bar.barType and TYPE_COLOR[bar.barType]
  if c then bar:SetStatusBarColor(c[1], c[2], c[3]) end
end

local function styleBar(b)
  local bar = ns.Find("castbars", b.key, unpack(b.paths))
  if not bar or bar.__ash then return end
  bar.__ash = true
  local name = bar.GetName and bar:GetName() or ""

  for _, k in ipairs(ART) do ns.Kill(bar[k], true) end
  for _, k in ipairs(NAMED_ART) do ns.Kill(_G[name .. k], true) end

  ns.FlatFill(bar, recolor)
  ns.Keep(bar, "SetStatusBarColor", recolor)
  recolor(bar)

  -- dark trough, so the unfilled part reads as part of the bar
  if bar.CreateTexture and not bar.__ashTrough then
    local t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
    t:SetAllPoints(bar)
    t:SetTexture(ns.WHITE)
    t:SetVertexColor(unpack(C.slot))
    bar.__ashTrough = t
  end

  local text = bar.Text or _G[name .. "Text"]
  if text then ns.Font(text, "body") end

  -- one panel behind the bar, reaching down over the spell name when the
  -- name sits under the bar (the modern player bar)
  if not bar.__ashPanel then
    local holder = CreateFrame("Frame", nil, bar)
    holder:SetPoint("TOPLEFT", bar, "TOPLEFT")
    holder:SetPoint("RIGHT", bar, "RIGHT")
    if bar.TextBorder and text then
      holder:SetPoint("BOTTOM", text, "BOTTOM", 0, -1)
    else
      holder:SetPoint("BOTTOM", bar, "BOTTOM")
    end
    holder:SetFrameLevel(math.max(bar:GetFrameLevel() - 1, 0))
    bar.__ashPanel = ns.Panel(holder, { pad = 3, parent = bar, ornate = b.ornate and ns.db.ornate,
                                        bg = C.panelSolid, border = C.border })
    ns.Above(bar.__ashPanel, bar)
  end

  -- square icon in a thin slot
  local icon = bar.Icon or _G[name .. "Icon"]
  if icon and icon.SetTexCoord then
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if not icon.__ashSlot then
      -- the slot follows the icon: the player bar hides its icon, and an
      -- empty slot would draw a stray outline beside the bar
      local slot = CreateFrame("Frame", nil, bar, "BackdropTemplate")
      slot:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
      slot:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
      slot:SetFrameLevel(math.max(bar:GetFrameLevel() - 1, 0))
      if slot.SetBackdrop then
        slot:SetBackdrop({ edgeFile = ns.WHITE, edgeSize = 1 })
        slot:SetBackdropBorderColor(unpack(C.slotBorder))
      end
      icon.__ashSlot = slot
      local function follow() slot:SetShown(icon:IsShown() and true or false) end
      follow()
      ns.Keep(icon, "Show", follow); ns.Keep(icon, "Hide", follow); ns.Keep(icon, "SetShown", follow)
    end
  end
end

function M.Enable()
  for _, b in ipairs(BARS) do
    ns.Guard("castbars " .. b.key, styleBar, b)
  end
end
