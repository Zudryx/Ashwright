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

-- The power bar hangs directly under the health bar at the same width. The
-- game's own layout lets them overlap by a couple of pixels (player) or makes
-- the power bar wider (target), which shows once both bars are flat.
local function alignPower(health, power)
  if not (health and power and power.ClearAllPoints) or power.__ashAligned then return end
  power.__ashAligned = true
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
M.ALIGN_POWER = { player = true, target = true, focus = true }

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
  if M.ALIGN_POWER[u.key] then alignPower(health, power) end

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

-- Gives the target's bars the same size as yours and, when the two frames
-- sit side by side (bars within a few pixels of each other), lines them up
-- with yours. The game draws the target's bars 2 px wider and taller and a
-- couple of pixels off, which shows once both frames have panels. Only the
-- bars move, inside the target frame, keeping their right edge next to the
-- portrait; the frame itself stays where Edit Mode put it.
local ALIGN_RANGE = 8

local function unitDef(key)
  for _, u in ipairs(UNITS) do if u.key == key then return u end end
end

local function barsOf(key)
  local u = unitDef(key)
  local frame = u and (ns.Path(u.frame[1]) or (u.frame[2] and ns.Path(u.frame[2])))
  if not frame then return end
  return frame, bar(u, frame, u.frame[1], "health"), bar(u, frame, u.frame[1], "power")
end

local function num(...)
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if type(v) ~= "number" or ns.isSecret(v) then return false end
  end
  return true
end

function M.AlignTarget()
  if not ns.db.alignTarget then return end
  local _, ph, pp = barsOf("player")
  local tf, th, tp = barsOf("target")
  if not (ph and th and tf and th.ClearAllPoints) then return end
  local pw, phh, pt = ph:GetWidth(), ph:GetHeight(), ph:GetTop()
  local tr, tt, fr, ft = th:GetRight(), th:GetTop(), tf:GetRight(), tf:GetTop()
  if not num(pw, phh, pt, tr, tt, fr, ft) or pw <= 0 or phh <= 0 then return end

  if not th.__ashHome then
    -- where the game put the bar, relative to the frame's top right
    th.__ashHome = { tr - fr, tt - ft }
    ns.Keep(th, "SetPoint", function(self)
      if self.__ashPlacing then return end
      self.__ashHome = nil   -- the game re-laid the frame out: start over from there
      ns.Run("unitframes align target", M.AlignTarget)
    end)
  end
  local home = th.__ashHome
  local shift = pt - (ft + home[2])
  if math.abs(shift) > ALIGN_RANGE then shift = 0 end
  shift = math.floor(shift + 0.5)

  th.__ashPlacing = true
  th:ClearAllPoints()
  th:SetPoint("TOPRIGHT", tf, "TOPRIGHT", home[1], home[2] + shift)
  th:SetSize(pw, phh)
  th.__ashPlacing = nil
  if pp and tp and tp.SetHeight then
    local h = pp:GetHeight()
    if num(h) and h > 0 then tp:SetHeight(h) end
  end
end

-- Buffs and debuffs under the target and focus frames start right below the
-- game's frame art, which sits higher than the panel's bottom edge. The first
-- aura of each group is anchored to the frame; moving it moves its row and
-- the rows under it, which hang from it.
local AURA_GAP = 2

local function auraFrames(frame)
  local list = {}
  if frame.auraPools and frame.auraPools.EnumerateActive then
    for a in frame.auraPools:EnumerateActive() do list[#list + 1] = a end
  end
  local name = frame.GetName and frame:GetName()
  if #list == 0 and name then
    for _, kind in ipairs({ "Buff", "Debuff" }) do
      for i = 1, 40 do
        local a = _G[name .. kind .. i]
        if not a then break end
        list[#list + 1] = a
      end
    end
  end
  return list
end

local function anchorY(rel, rp)
  if not (rel and rel.GetTop) then return end
  if rp:find("BOTTOM") then return rel:GetBottom() end
  if rp:find("TOP") then return rel:GetTop() end
  local t, b = rel:GetTop(), rel:GetBottom()
  return t and b and (t + b) / 2
end

function M.NudgeAuras(frame)
  local panel = frame and frame.__ashPanel
  if not panel then return end
  local edge = (panel.outer or panel):GetBottom()
  if not num(edge) then return end
  local auras = auraFrames(frame)
  local isAura = {}
  for _, a in ipairs(auras) do isAura[a] = true end
  for _, a in ipairs(auras) do
    if a.GetNumPoints and a:GetNumPoints() == 1 then
      local p, rel, rp, x, y = a:GetPoint(1)
      if p and p:find("TOP") and rel and not isAura[rel] then
        local ay = anchorY(rel, rp or p)
        if num(ay, y) then
          local want = edge - AURA_GAP - ay   -- the y that puts its top under the panel
          if y > want then
            a:ClearAllPoints()
            a:SetPoint(p, rel, rp, x, math.floor(want))
          end
        end
      end
    end
  end
end

local function hookAuras(frame)
  if not frame or frame.__ashAuras then return end
  frame.__ashAuras = true
  local function nudge() ns.Guard("unitframes auras", M.NudgeAuras, frame) end
  ns.Each(function(m) if frame[m] then hooksecurefunc(frame, m, nudge) end end,
          "UpdateAuras", "UpdateAuraPositions")
  nudge()
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
  hookAuras(_G.TargetFrame)
  hookAuras(_G.FocusFrame)
  if _G.TargetFrame_UpdateAuras then
    hooksecurefunc("TargetFrame_UpdateAuras", function(f) ns.Guard("unitframes auras", M.NudgeAuras, f) end)
  end
end
