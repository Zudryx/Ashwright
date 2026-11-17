--[[
Ashwright: tooltips.
Copyright (C) 2026 Zudryx. GPL-3.0-or-later; see Core.lua.

Dark tooltip background with a thin iron border, and a flat crimson health
bar under unit tooltips.
]]

local _, ns = ...
local M = ns.Module("tooltip")
local C = ns.C

local TIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "EmbeddedItemTooltip" }

local function paint(tip)
  if tip.NineSlice then
    if tip.NineSlice.SetCenterColor then tip.NineSlice:SetCenterColor(unpack(C.panel)) end
    if tip.NineSlice.SetBorderColor then tip.NineSlice:SetBorderColor(unpack(C.border)) end
  elseif tip.SetBackdropColor then
    tip:SetBackdropColor(unpack(C.panel))
    if tip.SetBackdropBorderColor then tip:SetBackdropBorderColor(unpack(C.border)) end
  end
end

function M.Enable()
  for _, name in ipairs(TIPS) do
    local tip = ns.Find("tooltip", name, name)
    if tip and not tip.__ash then
      tip.__ash = true
      paint(tip)
      -- Blizzard resets the look each time a tooltip is shown
      tip:HookScript("OnShow", function(self) ns.Guard("tooltip", paint, self) end)
    end
  end
  if _G.SharedTooltip_SetBackdropStyle then
    hooksecurefunc("SharedTooltip_SetBackdropStyle", function(tip) ns.Guard("tooltip", paint, tip) end)
  end
  local bar = ns.Find("tooltip", "status bar", "GameTooltipStatusBar")
  if bar then
    ns.FlatFill(bar)
    bar:SetStatusBarColor(unpack(C.health))
    ns.Keep(bar, "SetStatusBarColor", function(self) self:SetStatusBarColor(unpack(C.health)) end)
  end
  local title = _G.GameTooltipTextLeft1
  if title then ns.Font(title, "title") end
end
