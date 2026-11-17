--[[
Ashwright: unit frames (player, target, target of target, focus, party).
Copyright (C) 2026 Zudryx. GPL-3.0-or-later; see Core.lua.

Fades Blizzard's frame art, gives the health and power bars a flat texture
on a dark panel with a thin border, makes health bars crimson and sets the
name fonts. Portraits, icons and click behavior are left as they are.
]]

local _, ns = ...
local M = ns.Module("unitframes")
local C = ns.C

-- Candidate names for each frame and its art, classic-style UI first, then modern.
local UNITS = {
  { key = "player", unit = "player", ornate = true,
    frame = { "PlayerFrame" },
    art = { "PlayerFrameTexture", "PlayerFrameBackground", "PlayerFrame.PlayerFrameContainer.FrameTexture",
            "PlayerFrame.PlayerFrameContainer.AlternatePowerFrameTexture",
            -- the orange glow across the top of the frame while resting or in combat
            "PlayerStatusTexture", "PlayerStatusGlow",
            "PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.StatusTexture" },
    name = { "PlayerName", "PlayerFrame.name" },
    level = { "PlayerLevelText", "PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual.LevelText" },
    health = { "PlayerFrameHealthBar", "PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer.HealthBar" },
    power = { "PlayerFrameManaBar", "PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar" } },
  { key = "target", unit = "target", ornate = true,
    frame = { "TargetFrame" },
    art = { "TargetFrameTextureFrameTexture", "TargetFrameBackground", "TargetFrameNameBackground",
            "TargetFrame.TargetFrameContainer.FrameTexture",
            "TargetFrame.TargetFrameContent.TargetFrameContentMain.ReputationColor" },
    name = { "TargetFrameTextureFrameName", "TargetFrame.TargetFrameContent.TargetFrameContentMain.Name" },
    level = { "TargetFrameTextureFrameLevelText", "TargetFrame.TargetFrameContent.TargetFrameContentMain.LevelText" },
    health = { "TargetFrameHealthBar", "TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar" },
    power = { "TargetFrameManaBar", "TargetFrame.TargetFrameContent.TargetFrameContentMain.ManaBar" } },
  { key = "focus", unit = "focus", ornate = true,
    frame = { "FocusFrame" },
    art = { "FocusFrameTextureFrameTexture", "FocusFrameBackground", "FocusFrameNameBackground",
            "FocusFrame.TargetFrameContainer.FrameTexture",
            "FocusFrame.TargetFrameContent.TargetFrameContentMain.ReputationColor" },
    name = { "FocusFrameTextureFrameName", "FocusFrame.TargetFrameContent.TargetFrameContentMain.Name" },
    level = { "FocusFrameTextureFrameLevelText", "FocusFrame.TargetFrameContent.TargetFrameContentMain.LevelText" },
    health = { "FocusFrameHealthBar", "FocusFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar" },
    power = { "FocusFrameManaBar", "FocusFrame.TargetFrameContent.TargetFrameContentMain.ManaBar" } },
  { key = "targettarget", unit = "targettarget",
    frame = { "TargetFrameToT", "TargetFrame.totFrame" },
    art = { "TargetFrameToTTextureFrameTexture", "TargetFrameToTBackground", "TargetFrame.totFrame.FrameTexture" },
    name = { "TargetFrameToTTextureFrameName", "TargetFrame.totFrame.Name" },
    health = { "TargetFrameToTHealthBar", "TargetFrame.totFrame.HealthBar" },
    power = { "TargetFrameToTManaBar", "TargetFrame.totFrame.ManaBar" } },
}
for i = 1, 4 do
  UNITS[#UNITS + 1] = {
    key = "party" .. i, unit = "party" .. i,
    frame = { "PartyMemberFrame" .. i, "PartyFrame.MemberFrame" .. i },
    art = { "PartyMemberFrame" .. i .. "Texture", "PartyMemberFrame" .. i .. "Background",
            "PartyFrame.MemberFrame" .. i .. ".Texture" },
    name = { "PartyMemberFrame" .. i .. "Name", "PartyFrame.MemberFrame" .. i .. ".Name" },
    health = { "PartyMemberFrame" .. i .. "HealthBar", "PartyFrame.MemberFrame" .. i .. ".HealthBarContainer.HealthBar",
               "PartyFrame.MemberFrame" .. i .. ".HealthBar" },
    power = { "PartyMemberFrame" .. i .. "ManaBar", "PartyFrame.MemberFrame" .. i .. ".ManaBar" },
  }
end
M.UNITS = UNITS

-- The modern UI rounds bar corners with mask textures; flat bars need them gone.
local function removeMasks(bar)
  local tex = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
  if not tex or not tex.RemoveMaskTexture then return end
  local parent = bar.GetParent and bar:GetParent()
  -- a plain list with gaps: ipairs would stop at the first missing mask
  local masks = { bar.HealthBarMask, bar.ManaBarMask, bar.Mask,
                  parent and parent.HealthBarMask or nil, parent and parent.ManaBarMask or nil }
  for i = 1, 5 do
    if masks[i] then ns.safe(tex.RemoveMaskTexture, tex, masks[i]) end
  end
end

-- Bars may come from a field (frame.healthbar) or by name.
local function bar(u, frame, framePath, kind)
  local field = kind == "health" and "healthbar" or "manabar"
  if frame[field] then
    ns.Note("unitframes", u.key .. "." .. kind, framePath .. "." .. field)
    return frame[field]
  end
  return ns.Find("unitframes", u.key .. "." .. kind, unpack(u[kind]))
end

-- Power colors in the Ash & Iron palette; anything else uses the game's own color.
local POWER = {
  MANA = { 0.184, 0.310, 0.561 }, RAGE = { 0.710, 0.329, 0.118 },
  ENERGY = { 0.710, 0.604, 0.165 }, FOCUS = { 0.710, 0.451, 0.200 },
}

-- The modern UI colors power bars through their atlas texture and leaves the
-- bar's own color white, so a flat texture needs the color set explicitly.
local function powerColor(b, unit)
  unit = b.unit or unit
  if not unit then return nil end
  local ptype, token = ns.safe(UnitPowerType, unit)
  if ns.isSecret(ptype) or ns.isSecret(token) then return b.__ashLastPower end
  local c = token and POWER[token]
  if not c and _G.PowerBarColor then
    local pc = PowerBarColor[token] or PowerBarColor[ptype]
    if pc and pc.r then c = { pc.r, pc.g, pc.b } end
  end
  if c then b.__ashLastPower = c end
  return c
end

local function styleBar(b, kind, unit)
  if not b or b.__ash then return end
  b.__ash = true
  local function recolor(self)
    if kind == "health" then
      self:SetStatusBarColor(unpack(C.health))
    else
      local c = powerColor(self, unit)
      if c then self:SetStatusBarColor(unpack(c)) end
    end
  end
  ns.FlatFill(b, recolor)
  ns.Keep(b, "SetStatusBarColor", recolor)
  removeMasks(b)
  recolor(b)
  -- a dark trough behind the fill, so an empty bar (no rage yet, missing
  -- health) still reads as a bar instead of a hole in the panel
  if b.CreateTexture and not b.__ashTrough then
    local t = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    t:SetAllPoints(b)
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    t:SetVertexColor(unpack(kind == "health" and C.healthBg or C.slot))
    b.__ashTrough = t
  end
  -- the text on the bar (e.g. "412 / 528")
  ns.Each(function(fs) ns.Font(fs, "body") end, b.TextString, b.LeftText, b.RightText)
end

-- Some frames' power bar is wider than the health bar (the target frame's
-- sticks out past both ends). Hang it under the health bar at the same width
-- so the two read as one block, and keep it there if the game re-anchors it.
local function alignPower(health, power)
  if not (health and power and power.ClearAllPoints and health.GetWidth) then return end
  local hw, pw = health:GetWidth(), power:GetWidth()
  if not (hw and pw) or hw <= 0 or math.abs(hw - pw) < 1 then return end
  local function place(bar)
    if bar.__ashPlacing then return end
    bar.__ashPlacing = true
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", health, "BOTTOMRIGHT", 0, 0)
    bar.__ashPlacing = nil
  end
  ns.Run("unitframes align power", place, power)
  ns.Keep(power, "SetPoint", function(bar)
    if not bar.__ashPlacing then ns.Run("unitframes align power", place, bar) end
  end)
end

local function styleUnit(u)
  local frame, framePath = ns.Find("unitframes", u.key, unpack(u.frame))
  if not frame then return end

  for i, p in ipairs(u.art) do
    local art = ns.Path(p)
    ns.Note("unitframes", u.key .. ".art" .. i, art and p or nil)
    ns.Kill(art, true)   -- hidden for good: the game re-shows some of this art
  end

  local health = bar(u, frame, framePath, "health")
  local power = bar(u, frame, framePath, "power")
  styleBar(health, "health", u.unit)
  styleBar(power, "power", u.unit)
  alignPower(health, power)

  -- one panel behind both bars, like the mockup's frame body
  if health and not frame.__ashPanel then
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetPoint("TOPLEFT", health, "TOPLEFT")
    holder:SetPoint("BOTTOMRIGHT", power or health, "BOTTOMRIGHT")
    holder:SetFrameLevel(math.max(health:GetFrameLevel() - 1, 0))
    frame.__ashPanel = ns.Panel(holder, { pad = 3, parent = frame, ornate = u.ornate,
                                          bg = C.panelSolid, border = C.border })
    -- the bars must draw above the panel, or the panel hides their fill
    ns.Above(frame.__ashPanel, health, power)
  end

  local name = ns.Find("unitframes", u.key .. ".name", unpack(u.name))
  if name then
    ns.Font(name, "title", 13)
    name:SetTextColor(unpack(C.title))
    -- a dark shadow so the name reads against anything behind it
    if name.SetShadowOffset then name:SetShadowOffset(1, -1); name:SetShadowColor(0, 0, 0, 1) end
    -- lift the name clear of the panel's top edge, and again whenever the
    -- game re-anchors it
    -- Names often hang from two anchor points (left and right edge), so every
    -- point is shifted. Points we already shifted are recognized by the y we
    -- set, so a re-anchor by the game never stacks the offset twice.
    local function nudge(fs)
      local off = ns.db.nameOffset or 0
      local shifted = fs.__ashSet or {}
      local pts = {}
      for i = 1, (fs.GetNumPoints and fs:GetNumPoints() or 1) do
        local p, rel, rp, x, y = fs:GetPoint(i)
        if p then
          y = y or 0
          local base = (shifted[p] ~= nil and shifted[p] == y) and (y - off) or y
          pts[#pts + 1] = { p, rel, rp, x or 0, base }
        end
      end
      if #pts == 0 then return end
      fs:ClearAllPoints()
      fs.__ashSet = {}
      for _, pt in ipairs(pts) do
        fs:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5] + off)
        fs.__ashSet[pt[1]] = pt[5] + off
      end
    end
    nudge(name)
    ns.Keep(name, "SetPoint", nudge)
  end
  if u.level then
    local level = ns.Find("unitframes", u.key .. ".level", unpack(u.level))
    if level then ns.Font(level, "body") end
  end
end

-- Lines the target's bars up with the player's when the two frames sit side
-- by side (their bars within a few pixels of each other). The game places the
-- two frames a couple of pixels apart, which shows once both have panels.
-- Only the bars move, inside the target frame; the frame itself stays where
-- Edit Mode put it. Frames placed further apart are left alone.
local ALIGN_RANGE = 8

local function healthOf(key)
  for _, u in ipairs(UNITS) do
    if u.key == key then
      local frame, path = ns.Path(u.frame[1]) or ns.Path(u.frame[2] or ""), u.frame[1]
      if frame then return bar(u, frame, path, "health") end
    end
  end
end

-- the frame to move: the modern UI keeps the health bar in a container with
-- its text, so the container moves; otherwise the bar itself
local function moverOf(hb)
  local parent = hb.GetParent and hb:GetParent()
  if parent and parent.HealthBar == hb and parent ~= _G.TargetFrame then return parent end
  return hb
end

local function applyShift(mover, shift)
  if not mover.__ashOrig then return end
  mover.__ashPlacing = true
  mover:ClearAllPoints()
  for _, pt in ipairs(mover.__ashOrig) do
    mover:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5] + shift)
  end
  mover.__ashPlacing = nil
  mover.__ashShift = shift
end

local function capture(mover)
  local pts = {}
  for i = 1, (mover.GetNumPoints and mover:GetNumPoints() or 0) do
    local p, rel, rp, x, y = mover:GetPoint(i)
    if p then pts[#pts + 1] = { p, rel, rp, x or 0, y or 0 } end
  end
  if #pts > 0 then mover.__ashOrig = pts end
end

function M.AlignTarget()
  if not ns.db.alignTarget then return end
  local ph, th = healthOf("player"), healthOf("target")
  if not (ph and th) then return end
  local mover = moverOf(th)
  if not mover.__ashOrig then
    capture(mover)
    mover.__ashShift = 0
    -- the game re-anchoring the bars resets them; take the new spot as home
    ns.Keep(mover, "SetPoint", function(self)
      if self.__ashPlacing then return end
      capture(self); self.__ashShift = 0
      ns.Run("unitframes align target", M.AlignTarget)
    end)
  end
  local pt, tt = ph:GetTop(), th:GetTop()
  if not (pt and tt) or ns.isSecret(pt) or ns.isSecret(tt) then return end
  local home = tt - (mover.__ashShift or 0)
  local shift = pt - home
  if math.abs(shift) > ALIGN_RANGE then shift = 0 end
  shift = math.floor(shift + 0.5)
  if shift ~= mover.__ashShift then applyShift(mover, shift) end
end

local function realign() ns.Run("unitframes align target", M.AlignTarget) end

function M.Enable()
  for _, u in ipairs(UNITS) do
    ns.Guard("unitframes " .. u.key, styleUnit, u)
  end
  -- positions are only known once frames are laid out and shown
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:RegisterEvent("PLAYER_TARGET_CHANGED")
  ev:SetScript("OnEvent", realign)
  local em = _G.EditModeManagerFrame
  if em and em.HookScript then em:HookScript("OnHide", realign) end
  realign()
end
