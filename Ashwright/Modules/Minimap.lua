--[[
Ashwright: minimap.
Copyright (C) 2026 Zudryx. GPL-3.0-or-later; see Core.lua.

Makes the minimap square with a thin iron frame, fades the round border and
zoom buttons, and zooms with the mouse wheel instead.

Keeping icons on the square, not the old circle:
  * Other addons' minimap buttons and map pins ask GetMinimapShape() where
    the edge is. Ashwright answers "SQUARE" from the moment it loads, then
    refreshes buttons that were placed before that.
  * Blizzard's own buttons (tracking, mail, clock, calendar, queue,
    difficulty) sit at fixed spots around the round border. Each is moved to
    a corner or edge of the square, and moved back if the game re-anchors it.
]]

local _, ns = ...
local M = ns.Module("minimap")
local C = ns.C

local ART = {
  "MinimapBorder", "MinimapBorderTop", "MinimapCompassTexture", "MinimapBackdrop.MinimapCompassTexture",
  "MinimapCluster.BorderTop", "MinimapCluster.MinimapContainer.BorderTop", "MiniMapWorldMapButton",
  "MinimapZoomIn", "MinimapZoomOut", "Minimap.ZoomIn", "Minimap.ZoomOut",
  "MinimapNorthTag",
}

-- Blizzard buttons: candidate names, then where they go on the square
-- (point on the button and the minimap, x, y).
local BUTTONS = {
  { label = "tracking", names = { "MiniMapTracking", "MiniMapTrackingFrame", "MinimapCluster.Tracking",
                                  "MinimapCluster.TrackingFrame" },
    point = "TOPLEFT", x = 2, y = -2 },
  { label = "difficulty", names = { "MiniMapInstanceDifficulty", "MinimapCluster.InstanceDifficulty" },
    point = "TOPLEFT", x = 2, y = -30 },
  { label = "mail", names = { "MiniMapMailFrame", "MinimapCluster.MailFrame",
                              "MinimapCluster.IndicatorFrame.MailFrame" },
    point = "TOPRIGHT", x = -2, y = -2 },
  { label = "calendar", names = { "GameTimeFrame" },
    point = "TOPRIGHT", x = -2, y = -30 },
  { label = "queue", names = { "MiniMapBattlefieldFrame", "QueueStatusMinimapButton", "MiniMapLFGFrame" },
    point = "BOTTOMLEFT", x = 2, y = 2 },
  { label = "clock", names = { "TimeManagerClockButton" },
    point = "BOTTOM", x = 0, y = 2 },
}

-- From the moment Ashwright loads, so buttons and pins created by addons that
-- load later are placed on the square straight away. Another addon that
-- already answered keeps its answer.
local function ourShape()
  local db = _G.AshwrightDB
  if db and db.modules and db.modules.minimap == false then return "ROUND" end
  return "SQUARE"
end
if not _G.GetMinimapShape then _G.GetMinimapShape = ourShape end

local function place(button, spec, map)
  button:ClearAllPoints()
  button:SetPoint(spec.point, map, spec.point, spec.x, spec.y)
end

local function moveBlizzardButtons(map)
  for _, spec in ipairs(BUTTONS) do
    local button = ns.Find("minimap", "button " .. spec.label, unpack(spec.names))
    if button and button.SetPoint and not button.__ash then
      button.__ash = true
      place(button, spec, map)
      -- the game re-anchors some of these on layout updates; put them back
      ns.Keep(button, "SetPoint", function(self) place(self, spec, map) end)
    end
  end
end

-- Addon minimap buttons placed before we loaded: ask the common button
-- library to place them again now that the shape is square.
local function refreshAddonButtons()
  local LibStub = _G.LibStub
  local icon = LibStub and LibStub("LibDBIcon-1.0", true)
  if not icon then
    ns.Note("minimap", "addon buttons (LibDBIcon)", nil)
    return
  end
  local list = icon.GetButtonList and icon:GetButtonList() or {}
  for _, name in ipairs(list) do
    ns.safe(icon.Refresh, icon, name)
  end
  ns.Note("minimap", "addon buttons (LibDBIcon)", ("%d refreshed"):format(#list))
end

function M.Enable()
  local map = ns.Find("minimap", "minimap", "Minimap")
  if not map then return end

  map:SetMaskTexture(ns.WHITE)
  ns.Note("minimap", "shape answer", _G.GetMinimapShape == ourShape and "Ashwright" or "another addon")

  for _, p in ipairs(ART) do
    local a = ns.Path(p)
    ns.Note("minimap", "art " .. p, a and p or nil)
    ns.Kill(a)
  end

  ns.Panel(map, { pad = 2, ornate = true, bg = C.panelSolid, border = C.border })

  map:EnableMouseWheel(true)
  map:HookScript("OnMouseWheel", function(self, delta)
    local z = self:GetZoom() + (delta > 0 and 1 or -1)
    if z >= 0 and z <= self:GetZoomLevels() - 1 then self:SetZoom(z) end
  end)

  local zone = ns.Find("minimap", "zone text", "MinimapZoneText", "MinimapCluster.ZoneTextButton.ZoneText",
                       "MinimapCluster.ZoneTextButton.Text")
  if zone then ns.Font(zone, "title", 13) end

  moveBlizzardButtons(map)
  refreshAddonButtons()
end
