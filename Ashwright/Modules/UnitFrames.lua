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

-- Bar layout for the player, target and focus frames.
--
-- The power bar sits right under the health bar at the same width (the game
-- lets them overlap by 2 px on the player frame and makes the target's power
-- bar wider). The target's bars take the player's size and, when the two
-- frames sit side by side, line up with the player's bars.
--
-- Both bars are pinned to the unit frame itself, never to each other: the
-- game positions some of its own bar containers off the power bar, so a power
-- bar hung under the health bar made a loop (a "C stack overflow", and a
-- target frame that vanished on every other target). Where the game puts the
-- bars is measured once the frame is shown and laid out, and measured again
-- whenever the game moves a bar itself.
local ALIGN_RANGE = 8
local LAYOUT_KEYS = { "player", "target", "focus" }
M.LAYOUT_KEYS = LAYOUT_KEYS

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

local function measure(frame, hb, pb)
  local fl, fr, ft = frame:GetLeft(), frame:GetRight(), frame:GetTop()
  local hl, hr, ht, hbot = hb:GetLeft(), hb:GetRight(), hb:GetTop(), hb:GetBottom()
  if not num(fl, fr, ft, hl, hr, ht, hbot) or hr - hl <= 0 or ht - hbot <= 0 then return end
  local ph = pb and pb.GetHeight and pb:GetHeight()
  return { left = hl - fl, right = hr - fr, top = ht - ft, w = hr - hl, h = ht - hbot,
           ph = (num(ph) and ph > 0) and ph or nil }
end

local relayoutSoon   -- set below

local function watch(bar, hb)
  if not bar or bar.__ashWatched then return end
  bar.__ashWatched = true
  ns.Keep(bar, "SetPoint", function(self)
    if self.__ashPlacing then return end
    -- The game moved the bar: measure its new spot once its layout is done.
    -- (It sets several points in a row; stepping in after the first one
    -- would leave clashing points.)
    hb.__ashLayout = nil
    relayoutSoon()
  end)
end

local function place(bar, frame, point, x, y, w, h)
  bar.__ashPlacing = true
  bar:ClearAllPoints()
  bar:SetPoint(point, frame, point, x, y)
  bar:SetSize(w, h)
  bar.__ashPlacing = nil
end

function M.LayoutBars(key)
  local frame, hb, pb = barsOf(key)
  if not (frame and hb and hb.ClearAllPoints and frame.GetTop) then return end
  -- before a unit is shown the game hasn't laid its frame out yet
  if not (frame.IsVisible and frame:IsVisible()) then return end
  watch(hb, hb); watch(pb, hb)
  local L = hb.__ashLayout
  if not L then
    L = measure(frame, hb, pb)
    if not L then return end
    hb.__ashLayout = L
  end

  local w, h, top, ph = L.w, L.h, L.top, L.ph
  if key == "target" and ns.db.alignTarget then
    local pf, phb = barsOf("player")
    local P = phb and phb.__ashLayout
    local pft, ft = pf and pf:GetTop(), frame:GetTop()
    if P then
      w, h, ph = P.w, P.h, P.ph or ph
      if num(pft, ft) then
        local shift = (pft + P.top) - (ft + top)
        if math.abs(shift) <= ALIGN_RANGE then top = top + math.floor(shift + 0.5) end
      end
    end
  end

  -- the target and focus portraits are on the right: keep the bars' right edge
  local point, x = "TOPLEFT", L.left
  if key ~= "player" then point, x = "TOPRIGHT", L.right end
  place(hb, frame, point, x, top, w, h)
  if pb and pb.ClearAllPoints then place(pb, frame, point, x, top - h, w, ph or 10) end
end

-- kept for /ash aligntarget
function M.AlignTarget() M.LayoutBars("player"); M.LayoutBars("target") end

-- Buffs and debuffs under the target and focus frames start right below the
-- game's frame art, which sits higher than the panel's bottom edge. The first
-- aura of each group is anchored to the frame; moving it moves its row and
-- the rows under it, which hang from it. When positions can be read, the
-- auras start just under the panel; when the game keeps them secret (often
-- in a group), they move down by a fixed amount instead.
local AURA_GAP = 2
local AURA_FALLBACK = 8

local function isAuraButton(f)
  if type(f) ~= "table" then return false end
  local icon = f.Icon or f.icon
  return icon and (f.Cooldown or f.cooldown or f.Count or f.count) and true or false
end

-- Forever keeps the target's buffs in a container of their own that is not
-- inside the target frame, only anchored to it. Find frames anchored to the
-- unit frame (or anything in it) that are not part of it and hold aura
-- icons. Searching every frame is slow, so the answer is kept, and an empty
-- answer is retried at most every few seconds.
local function isInside(f, root)
  local p, n = f, 0
  while p and n < 15 do
    if p == root then return true end
    p = p.GetParent and p:GetParent(); n = n + 1
  end
  return false
end

local function holdsIcons(f)
  if isAuraButton(f) then return true end
  if not f.GetChildren then return false end
  for _, c in ipairs({ f:GetChildren() }) do
    if isAuraButton(c) or (type(c) == "table" and (c.Icon or c.icon) and c.GetObjectType and c:GetObjectType() ~= "StatusBar") then
      return true
    end
  end
  return false
end

local containers, lastSearch = {}, {}
function M.AuraContainers(frame, force)
  if not frame then return {} end
  local found = containers[frame]
  if found and #found > 0 and not force then return found end
  local now = GetTime and GetTime() or 0
  if not force and lastSearch[frame] and now - lastSearch[frame] < 3 then return found or {} end
  lastSearch[frame] = now
  found = {}
  if EnumerateFrames then
    local f = EnumerateFrames()
    while f do
      if not f.__ashBox and not (f.IsForbidden and f:IsForbidden()) and not isInside(f, frame) then
        local ok, _, rel = pcall(f.GetPoint, f, 1)
        if ok and type(rel) == "table" and isInside(rel, frame) and holdsIcons(f) then
          found[#found + 1] = f
        end
      end
      f = EnumerateFrames(f)
    end
  end
  containers[frame] = found
  return found
end

local function auraFrames(frame)
  local list, seen = {}, {}
  local function add(a) if a and not seen[a] then seen[a] = true; list[#list + 1] = a end end
  for _, c in ipairs(M.AuraContainers(frame)) do add(c) end
  -- Forever keeps a unit frame's auras in Content.Contextual.Auras (the dump
  -- found it on the focus and boss frames; the game does not list the target's).
  -- Move the holder when it has an anchor, otherwise its buttons.
  local ctx = frame.TargetFrameContent and frame.TargetFrameContent.TargetFrameContentContextual
  local holder = ctx and ctx.Auras
  if holder then
    local n = holder.GetNumPoints and holder:GetNumPoints() or 0
    if type(n) == "number" and n > 0 then
      add(holder)
    elseif holder.GetChildren then
      for _, c in ipairs({ holder:GetChildren() }) do
        if isAuraButton(c) then add(c) end
      end
    end
  end
  if frame.auraPools and frame.auraPools.EnumerateActive then
    for a in frame.auraPools:EnumerateActive() do add(a) end
  end
  local name = frame.GetName and frame:GetName()
  if name then
    for _, kind in ipairs({ "Buff", "Debuff" }) do
      for i = 1, 40 do
        local a = _G[name .. kind .. i]
        if not a then break end
        add(a)
      end
    end
  end
  if #list == 0 and frame.GetChildren then
    for _, c in ipairs({ frame:GetChildren() }) do
      if isAuraButton(c) then add(c) end
    end
  end
  return list
end

local function anchorY(rel, rp)
  if not (rel and rel.GetTop) then return end
  if rp:find("BOTTOM") then return rel:GetBottom() end
  if rp:find("TOP") then return rel:GetTop() end
  local t, b = rel:GetTop(), rel:GetBottom()
  return num(t, b) and (t + b) / 2 or nil
end

function M.NudgeAuras(frame)
  local panel = frame and frame.__ashPanel
  if not panel then return end
  local edge = (panel.outer or panel):GetBottom()
  local auras = auraFrames(frame)
  local isAura = {}
  for _, a in ipairs(auras) do isAura[a] = true end
  for _, a in ipairs(auras) do
    local n = a.GetNumPoints and a:GetNumPoints() or 0
    local p, rel, rp, x, y
    if n >= 1 then p, rel, rp, x, y = a:GetPoint(1) end
    if p and p:find("TOP") and rel and not isAura[rel] and num(x, y) then
      -- the y the game chose: ours stays ours until the game sets a new one
      if a.__ashSetY ~= y then a.__ashGameY = y end
      local base = a.__ashGameY
      local want
      local ay = anchorY(rel, rp or p)
      if num(edge, ay) then
        want = math.min(base, math.floor(edge - AURA_GAP - ay))
      else
        want = base - AURA_FALLBACK
      end
      if want ~= y then
        -- every point moves by the same amount (a container can hang from two)
        local pts, delta = {}, want - y
        for i = 1, n do
          local pp, r, rpp, px, py = a:GetPoint(i)
          if not num(px, py) then pts = nil break end
          pts[#pts + 1] = { pp, r, rpp, px, py + delta }
        end
        if pts then
          a.__ashPlacing = true
          a:ClearAllPoints()
          for _, pt in ipairs(pts) do a:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5]) end
          a.__ashPlacing = nil
        end
      end
      a.__ashSetY = want
      -- the game re-placing it brings it back up; put it down again
      if not a.__ashNudgeHook then
        a.__ashNudgeHook = true
        ns.Keep(a, "SetPoint", function(self) if not self.__ashPlacing and M.RealignSoon then M.RealignSoon() end end)
      end
    end
  end
end

local function hookAuras(frame)
  if not frame or frame.__ashAuras then return end
  frame.__ashAuras = true
  local function nudge() ns.Guard("unitframes auras", M.NudgeAuras, frame) end
  ns.Each(function(m) if frame[m] then hooksecurefunc(frame, m, nudge) end end,
          "UpdateAuras", "UpdateAuraFrames", "UpdateAuraPositions")
  nudge()
end

-- after the game's own handlers have laid the frame out for the new target
local function soon(fn)
  if C_Timer and C_Timer.After then C_Timer.After(0, fn) else fn() end
end
local pending = false
local function realign()
  if pending then return end
  pending = true
  soon(function()
    pending = false
    for _, key in ipairs(LAYOUT_KEYS) do ns.Run("unitframes layout " .. key, M.LayoutBars, key) end
    ns.Guard("unitframes auras", M.NudgeAuras, _G.TargetFrame)
    ns.Guard("unitframes auras", M.NudgeAuras, _G.FocusFrame)
  end)
end
M.RealignSoon = realign
relayoutSoon = realign

function M.Enable()
  for _, u in ipairs(UNITS) do
    ns.Guard("unitframes " .. u.key, styleUnit, u)
  end
  -- positions are only known once frames are laid out and shown
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:RegisterEvent("PLAYER_TARGET_CHANGED")
  ev:RegisterEvent("PLAYER_FOCUS_CHANGED")
  ev:RegisterEvent("UNIT_AURA")
  ev:RegisterEvent("UNIT_DISPLAYPOWER")
  ev:SetScript("OnEvent", function(_, event, unit)
    if (event == "UNIT_AURA" or event == "UNIT_DISPLAYPOWER")
       and unit ~= "target" and unit ~= "focus" and unit ~= "player" then return end
    realign()
  end)
  local em = _G.EditModeManagerFrame
  if em and em.HookScript then em:HookScript("OnHide", realign) end
  realign()
  hookAuras(_G.TargetFrame)
  hookAuras(_G.FocusFrame)
  ns.Each(function(fn)
    if _G[fn] then hooksecurefunc(fn, function(f) ns.Guard("unitframes auras", M.NudgeAuras, f) end) end
  end, "TargetFrame_UpdateAuras", "TargetFrame_UpdateAuraPositions")
end
