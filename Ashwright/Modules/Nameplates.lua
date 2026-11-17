--[[
Ashwright: nameplates.
Copyright (C) 2026 Zudryx. GPL-3.0-or-later; see Core.lua.

Flat health and cast bars with a thin border on each nameplate; your target's
plate gets an accent-colored border. Reaction colors (red, yellow, green) are
kept because they tell you what will attack you. Plates the game marks as
forbidden (some instance plates) are never touched.
]]

local _, ns = ...
local M = ns.Module("nameplates")
local C = ns.C

local styled = setmetatable({}, { __mode = "k" })   -- plate -> its border panel

local function healthBar(uf)
  return uf.healthBar or uf.HealthBar or (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar)
end

local function castBar(uf)
  return uf.castBar or uf.CastBar or uf.CastingBarFrame
end

local function isTarget(unit)
  local ok, same = pcall(UnitIsUnit, unit, "target")
  if not ok or ns.isSecret(same) then return false end
  return same and true or false
end

local function paintTarget(plate)
  local panel = styled[plate]
  if not panel or not panel.SetBackdropBorderColor then return end
  local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
  if unit and isTarget(unit) then
    panel:SetBackdropBorderColor(ns.Accent())
  else
    panel:SetBackdropBorderColor(unpack(C.barBorder))
  end
end

local function stylePlate(plate)
  if not plate or styled[plate] or (plate.IsForbidden and plate:IsForbidden()) then return end
  local uf = plate.UnitFrame
  if not uf then return end
  local hb = healthBar(uf)
  if not hb then ns.Note("nameplates", "health bar", nil) return end
  ns.Note("nameplates", "health bar", uf.healthBar and "UnitFrame.healthBar" or uf.HealthBar and "UnitFrame.HealthBar"
          or "UnitFrame.HealthBarsContainer.healthBar")

  ns.FlatFill(hb)
  -- The game's own plate art: the rounded border (a frame of edge pieces on
  -- the bar), the background and the glossy overlays. Everything drawn on
  -- the bar except its fill goes; heal and absorb bars (frames of their own,
  -- inside the bar) are left alone.
  local function sweep(f, depth)
    if not f or f.__ashBox or depth > 2 then return end
    if f.GetRegions then
      local fill = f.GetStatusBarTexture and f:GetStatusBarTexture()
      for _, r in ipairs({ f:GetRegions() }) do
        if r ~= fill and r.GetObjectType and r:GetObjectType() == "Texture" and not r.__ashFlat then ns.Kill(r, true) end
      end
    end
    if f.GetChildren then
      for _, c in ipairs({ f:GetChildren() }) do
        local key = ""
        for k, v in pairs(f) do if v == c and type(k) == "string" then key = k:lower() break end end
        local isBar = key:find("predict") or key:find("absorb") or key:find("heal")
        if not isBar then sweep(c, depth + 1) end
      end
    end
  end
  sweep(hb, 1)
  ns.Each(function(b) if b.GetObjectType and b:GetObjectType() == "Texture" then ns.Kill(b, true) else sweep(b, 1) end end,
          hb.border, hb.Border, hb.background, hb.Background)
  styled[plate] = ns.Panel(hb, { pad = 0, bg = C.healthBg, border = C.barBorder })

  local cb = castBar(uf)
  if cb and cb.SetStatusBarTexture then
    ns.Note("nameplates", "cast bar", "found")
    ns.FlatFill(cb)
    ns.Kill(cb.Border or cb.border)
    ns.Kill(cb.Background or cb.background)
    ns.Panel(cb, { pad = 0, bg = C.panelSolid, border = C.barBorder })
  end

  local name = uf.name or uf.Name
  if name then ns.Font(name, "body", nil, "OUTLINE") end
  paintTarget(plate)
end

local function each(fn)
  if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
  for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do ns.Guard("nameplate", fn, plate) end
end

function M.Enable()
  local f = CreateFrame("Frame")
  f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
  f:RegisterEvent("PLAYER_TARGET_CHANGED")
  f:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
      local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit(unit)
      ns.Guard("nameplate", function() stylePlate(plate); paintTarget(plate) end)
    else
      each(paintTarget)
    end
  end)
  each(stylePlate)
  ns.Note("nameplates", "C_NamePlate", C_NamePlate and "C_NamePlate" or nil)
end
