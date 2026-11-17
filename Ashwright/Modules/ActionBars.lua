--[[
Ashwright: action bars, bag buttons and the XP / reputation bar.
Copyright (C) 2026 Zudryx. GPL-3.0-or-later; see Core.lua.

Fades the bar art (gryphons, end caps, the stone strip), squares and crops
the button icons, gives each button a dark slot with a thin border and puts
a panel behind each bar. Buttons are never moved, rebound or changed in what
they do.

Bars that touch share one panel, sized from the buttons actually showing, so
they join cleanly in whatever layout Edit Mode gives them (stacked, side by
side, vertical). While Edit Mode is open the panels are hidden, so they never
sit over its move handles.
]]

local _, ns = ...
local M = ns.Module("actionbars")
local C = ns.C

-- Art to fade. Frames listed here only lose their own textures, so the bag
-- buttons and menu buttons that some of them hold keep working and showing.
local ART_TEXTURES = {
  "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap",
  "MainMenuBarTexture0", "MainMenuBarTexture1", "MainMenuBarTexture2", "MainMenuBarTexture3",
  "MainMenuBarArtFrameBackground.BackgroundLarge", "MainMenuBarArtFrameBackground.BackgroundSmall",
  "MainMenuBar.EndCaps.LeftEndCap", "MainMenuBar.EndCaps.RightEndCap",
  "MainActionBar.EndCaps.LeftEndCap", "MainActionBar.EndCaps.RightEndCap",
  "MainMenuBar.BorderArt", "MainActionBar.BorderArt",
  "MainMenuMaxLevelBar0", "MainMenuMaxLevelBar1", "MainMenuMaxLevelBar2", "MainMenuMaxLevelBar3",
}
local ART_FRAMES = { "MainMenuBarArtFrame", "MainMenuBarArtFrameBackground" }

local BUTTONS = {
  { prefix = "ActionButton", count = 12 },
  { prefix = "MultiBarBottomLeftButton", count = 12 },
  { prefix = "MultiBarBottomRightButton", count = 12 },
  { prefix = "MultiBarRightButton", count = 12 },
  { prefix = "MultiBarLeftButton", count = 12 },
  { prefix = "MultiBar5Button", count = 12 },
  { prefix = "MultiBar6Button", count = 12 },
  { prefix = "MultiBar7Button", count = 12 },
  { prefix = "PetActionButton", count = 10 },
  { prefix = "StanceButton", count = 10 },
}

-- The bar frames Edit Mode moves (modern UI). Each gets its own panel.
local BAR_FRAMES = {
  { label = "main", names = { "MainActionBar", "MainMenuBar" } },
  { label = "bottom left", names = { "MultiBarBottomLeft" } },
  { label = "bottom right", names = { "MultiBarBottomRight" } },
  { label = "right", names = { "MultiBarRight" } },
  { label = "left", names = { "MultiBarLeft" } },
  { label = "bar 5", names = { "MultiBar5" } },
  { label = "bar 6", names = { "MultiBar6" } },
  { label = "bar 7", names = { "MultiBar7" } },
}

local BAGS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot",
               "CharacterBag3Slot", "CharacterReagentBag0Slot" }

local function hideNormal(button)
  local nt = button.GetNormalTexture and button:GetNormalTexture()
  if nt then nt:SetAlpha(0) end
end

local function styleButton(button, name)
  if button.__ash then return end
  button.__ash = true

  local icon = button.icon or button.Icon or _G[name .. "Icon"] or _G[name .. "IconTexture"]
  if icon then
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- the modern UI rounds icons (and the backpack) with masks
    ns.Each(function(mask)
      if icon.RemoveMaskTexture then ns.safe(icon.RemoveMaskTexture, icon, mask) end
    end, button.IconMask, button.CircleMask)
  end

  hideNormal(button)
  ns.Keep(button, "SetNormalTexture", hideNormal)
  ns.Keep(button, "SetNormalAtlas", hideNormal)
  ns.Each(ns.Kill, button.SlotArt, button.SlotBackground, button.FloatingBG, _G[name .. "FloatingBG"])

  ns.Panel(button, { pad = 0, bg = C.slot, border = C.slotBorder })

  local hotkey = button.HotKey or _G[name .. "HotKey"]
  if hotkey then
    ns.Font(hotkey, "body", 10, "OUTLINE")
    hotkey:SetTextColor(unpack(C.muted))
  end
  local count = button.Count or _G[name .. "Count"]
  if count then ns.Font(count, "body", nil, "OUTLINE") end
  local macro = button.Name or _G[name .. "Name"]
  if macro then ns.Font(macro, "body", 9, "OUTLINE") end
end

---------------------------------------------------------------------------
-- bar panels
---------------------------------------------------------------------------

-- Panels are drawn per GROUP of touching bars, not per bar: bars that sit
-- next to each other (stacked or side by side) share one panel, so they always
-- join cleanly with no border cutting between them. Panels live on the
-- BACKGROUND strata, under every button, and are sized from the buttons
-- actually showing, so they fit any Edit Mode layout.
local SETS = {
  { "ActionButton", 12 }, { "MultiBarBottomLeftButton", 12 }, { "MultiBarBottomRightButton", 12 },
  { "MultiBarRightButton", 12 }, { "MultiBarLeftButton", 12 }, { "MultiBar5Button", 12 },
  { "MultiBar6Button", 12 }, { "MultiBar7Button", 12 }, { "PetActionButton", 10 }, { "StanceButton", 10 },
}
local GAP = 12        -- bars closer than this (UI units) count as touching
local holders = {}    -- reusable panel frames
M.holders = holders
local editing = false

-- Outer edges of a set's visible buttons, in UIParent units, or nil.
local function setRect(prefix, count)
  local ui = UIParent:GetEffectiveScale()
  local l, b, r, t
  for i = 1, count do
    local btn = _G[prefix .. i]
    if btn and btn:IsVisible() then
      local bl, br, bt, bb = btn:GetLeft(), btn:GetRight(), btn:GetTop(), btn:GetBottom()
      if bl and br and bt and bb then
        local k = btn:GetEffectiveScale() / ui
        bl, br, bt, bb = bl * k, br * k, bt * k, bb * k
        l = l and math.min(l, bl) or bl
        r = r and math.max(r, br) or br
        t = t and math.max(t, bt) or bt
        b = b and math.min(b, bb) or bb
      end
    end
  end
  if l then return { l = l, b = b, r = r, t = t } end
end

local function touching(a, c)
  return a.l - GAP <= c.r and c.l - GAP <= a.r and a.b - GAP <= c.t and c.b - GAP <= a.t
end

-- Merge rectangles that touch until no two do.
local function groups(rects)
  local merged = true
  while merged do
    merged = false
    for i = 1, #rects do
      for j = i + 1, #rects do
        local a, c = rects[i], rects[j]
        if touching(a, c) then
          a.l, a.b = math.min(a.l, c.l), math.min(a.b, c.b)
          a.r, a.t = math.max(a.r, c.r), math.max(a.t, c.t)
          table.remove(rects, j)
          merged = true
          break
        end
      end
      if merged then break end
    end
  end
  return rects
end

local function holder(i)
  local h = holders[i]
  if not h then
    h = CreateFrame("Frame", nil, UIParent)
    h:SetFrameStrata("BACKGROUND")
    h:SetFrameLevel(2)
    h.panel = ns.Panel(h, { pad = 4, parent = h, ornate = true, bg = C.panel, border = C.border })
    holders[i] = h
  end
  return h
end

local function layout()
  local rects = {}
  for _, set in ipairs(SETS) do
    local r = setRect(set[1], set[2])
    if r then rects[#rects + 1] = r end
  end
  local gs = groups(rects)
  for i, g in ipairs(gs) do
    local h = holder(i)
    h:ClearAllPoints()
    h:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", g.l, g.b)
    h:SetSize(g.r - g.l, g.t - g.b)
    if editing then h:Hide() else h:Show() end
  end
  for i = #gs + 1, #holders do holders[i]:Hide() end
  M.groups = #gs
end

-- Many things can move bars at once (Edit Mode, settings, logging in), so
-- requests are coalesced into one layout pass shortly after.
local pending = false
local function relayout()
  if pending then return end
  pending = true
  local function run() pending = false; ns.Guard("bar panels", layout) end
  if C_Timer then C_Timer.After(0.1, run) else run() end
end
M.Relayout = relayout

local function setPanelsShown(shown)
  editing = not shown
  if shown then relayout() else for _, h in ipairs(holders) do h:Hide() end end
end

-- Edit Mode and the bars draw thin dividers between buttons; they are found
-- by their art name (anything with "divider" in it) and faded.
local function hideDividers(frame, depth)
  if not frame then return end
  if frame.GetRegions then
    for _, r in ipairs({ frame:GetRegions() }) do
      local atlas = r.GetAtlas and ns.safe(r.GetAtlas, r)
      if type(atlas) == "string" and atlas:lower():find("divider", 1, true) then ns.Kill(r) end
    end
  end
  local pool = frame.DividersPool or frame.dividersPool
  if pool and pool.EnumerateActive then
    for d in pool:EnumerateActive() do ns.Kill(d) end
  end
  if (depth or 0) > 0 and frame.GetChildren then
    for _, c in ipairs({ frame:GetChildren() }) do
      -- buttons have no dividers; skip them to keep this cheap
      if not (c.GetObjectType and c:GetObjectType() == "CheckButton") then hideDividers(c, depth - 1) end
    end
  end
end

---------------------------------------------------------------------------
-- XP / reputation bar
---------------------------------------------------------------------------

-- The modern UI colors these bars through their atlas texture and leaves the
-- bar color white, so with a flat texture a white bar gets the accent color.
-- Real colors the game sets (e.g. reputation standing) are kept.
local function fixWhite(sb)
  local r, g, b = sb:GetStatusBarColor()
  if r and not ns.isSecret(r) and r > 0.95 and g > 0.95 and b > 0.95 then
    sb:SetStatusBarColor(ns.Accent())
  end
end

-- The rested-XP band (how far rested XP reaches) is useful, so it stays, as a
-- flat dim stripe instead of the glossy art.
local REST = { 0.33, 0.36, 0.60, 0.55 }
local function restedBand(t)
  if not t or t.__ash or not t.SetTexture then return end
  t.__ash = true
  local function flat(self) self:SetTexture(ns.WHITE); self:SetVertexColor(unpack(REST)) end
  flat(t)
  ns.Keep(t, "SetAtlas", flat)
  ns.Keep(t, "SetTexture", function(self, file) if file ~= ns.WHITE then flat(self) end end)
  -- the game sets the band's color itself (fully opaque); keep it dim
  ns.Keep(t, "SetVertexColor", function(self, r, g, b, a)
    if a ~= REST[4] or r ~= REST[1] then self:SetVertexColor(unpack(REST)) end
  end)
end

local function styleStatus(sb)
  if not sb or sb.__ash or not sb.SetStatusBarTexture then return false end
  sb.__ash = true
  ns.Kill(sb.Background)
  ns.FlatFill(sb, fixWhite)
  ns.Keep(sb, "SetStatusBarColor", fixWhite)
  fixWhite(sb)
  ns.Panel(sb, { pad = 0, bg = C.panelSolid, border = C.slotBorder })
  return true
end

-- Everything the game draws in a bar container except the fill and the rested
-- band: frame art with its rounded end caps, the dividers, the rested tick.
-- Walks nested frames, skipping Ashwright's own panels and Edit Mode's
-- selection highlight. The art is hidden, not just faded: the game fades it
-- back in with animations, which a fade can't hold off.
local function sweepArt(frame, depth, parent)
  if type(frame) ~= "table" or not frame.GetRegions or frame.__ashBox or depth > 4 then return end
  if parent and parent.Selection == frame then return end
  local keep = {}
  if frame.GetStatusBarTexture then
    local fill = frame:GetStatusBarTexture()
    if fill then keep[fill] = true end
  end
  if frame.ExhaustionLevelFillBar then keep[frame.ExhaustionLevelFillBar] = true end
  if frame.__ashTrough then keep[frame.__ashTrough] = true end
  for _, r in ipairs({ frame:GetRegions() }) do
    -- fills (flattened) and the rested band (marked __ash) stay
    if r.GetObjectType and r:GetObjectType() == "Texture" and not keep[r] and not r.__ashFlat and not r.__ash then
      ns.Kill(r, true)
    end
  end
  if frame.GetChildren then
    for _, c in ipairs({ frame:GetChildren() }) do sweepArt(c, depth + 1, frame) end
  end
end
M.SweepArt = sweepArt

-- Managers hold one or more bar containers; each container has a StatusBar
-- and its own frame art (the segmented border), which is faded.
local function styleTrackingManager(manager)
  local n = 0
  local containers = {}
  if type(manager.bars) == "table" then
    for _, c in pairs(manager.bars) do containers[#containers + 1] = c end
  end
  if manager.GetChildren then
    for _, c in ipairs({ manager:GetChildren() }) do containers[#containers + 1] = c end
  end
  for _, c in ipairs(containers) do
    if type(c) == "table" then
      -- the segmented frame art and the tick dividers (the game re-shows both)
      ns.Kill(c.BarFrameTexture, true)
      hideDividers(c, 1)
      local sb = c.StatusBar or (c.GetObjectType and c:GetObjectType() == "StatusBar" and c)
      if sb and styleStatus(sb) then n = n + 1 end
      -- bars nested one level deeper (bar container -> bar frame -> StatusBar)
      if c.GetChildren then
        for _, cc in ipairs({ c:GetChildren() }) do
          if type(cc) == "table" and cc.StatusBar then
            if styleStatus(cc.StatusBar) then n = n + 1 end
            restedBand(cc.ExhaustionLevelFillBar)
          end
        end
      end
      -- after styling, so the fills and the rested band are known keepers
      sweepArt(c, 1)
    end
  end
  return n
end

local function styleXP()
  local styled = 0
  for _, name in ipairs({ "MainStatusTrackingBarManager", "SecondaryStatusTrackingBarManager",
                          "StatusTrackingBarManager" }) do
    local m = _G[name]
    if m then styled = styled + styleTrackingManager(m) end
  end
  for _, path in ipairs({ "MainMenuExpBar", "ReputationWatchBar.StatusBar" }) do
    local sb = ns.Path(path)
    if sb and styleStatus(sb) then styled = styled + 1 end
  end
  ns.Each(ns.Kill, _G.MainMenuXPBarTexture0, _G.MainMenuXPBarTexture1, _G.MainMenuXPBarTexture2,
          _G.MainMenuXPBarTexture3, _G.ExhaustionTick and _G.ExhaustionTick.GetNormalTexture and _G.ExhaustionTick:GetNormalTexture())
  ns.Note("actionbars", "xp / reputation bars", styled > 0 and (styled .. " styled") or nil)
end

-- The game builds new dividers and bars as you level or track a reputation,
-- so the sweep runs again after those changes (once per frame at most).
local xpPending = false
local function restyleXP()
  if xpPending then return end
  xpPending = true
  local run = function() xpPending = false; ns.Guard("actionbars xp", styleXP) end
  if C_Timer and C_Timer.After then C_Timer.After(0, run) else run() end
end
M.RestyleXP = restyleXP

local function watchXP()
  local ev = CreateFrame("Frame")
  ns.Each(function(e) ev:RegisterEvent(e) end, "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE",
          "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "UPDATE_FACTION", "PLAYER_UPDATE_RESTING")
  ev:SetScript("OnEvent", restyleXP)
  for _, name in ipairs({ "StatusTrackingBarManager", "MainStatusTrackingBarManager",
                          "SecondaryStatusTrackingBarManager" }) do
    local m = _G[name]
    if m then
      ns.Each(function(meth) if m[meth] then hooksecurefunc(m, meth, restyleXP) end end,
              "UpdateBarsShown", "LayoutBars", "UpdateBarTicks")
      if m.GetChildren then
        for _, c in ipairs({ m:GetChildren() }) do
          ns.Each(function(meth) if type(c) == "table" and c[meth] then hooksecurefunc(c, meth, restyleXP) end end,
                  "UpdateBarTicks", "SetBarsShown", "UpdateShownState")
        end
      end
    end
  end
end

---------------------------------------------------------------------------

function M.Enable()
  for _, p in ipairs(ART_TEXTURES) do
    local t = ns.Path(p)
    ns.Note("actionbars", "art " .. p, t and p or nil)
    ns.Kill(t)
  end
  for _, p in ipairs(ART_FRAMES) do
    local f = ns.Path(p)
    ns.Note("actionbars", "art " .. p, f and p or nil)
    if f then ns.KillTextures(f) end
  end

  for _, bar in ipairs(BUTTONS) do
    local found = 0
    for i = 1, bar.count do
      local name = bar.prefix .. i
      local b = _G[name]
      if b then
        found = found + 1
        ns.Guard("button " .. name, styleButton, b, name)
      end
    end
    ns.Note("actionbars", bar.prefix .. " (" .. bar.count .. ")", found > 0 and (bar.prefix .. "1-" .. found) or nil)
  end

  local bags = 0
  for _, name in ipairs(BAGS) do
    local b = _G[name]
    if b then bags = bags + 1; ns.Guard("bag " .. name, styleButton, b, name) end
  end
  ns.Note("actionbars", "bag buttons", bags > 0 and (bags .. " styled") or nil)

  -- shared panels behind groups of touching bars
  for _, spec in ipairs(BAR_FRAMES) do
    local bar = ns.Find("actionbars", "bar " .. spec.label, unpack(spec.names))
    if bar then
      hideDividers(bar, 2)
      ns.Keep(bar, "UpdateDividers", function(self) hideDividers(self, 2) end)
      ns.Keep(bar, "UpdateGridLayout", function(self) hideDividers(self, 2); relayout() end)
      if bar.HookScript then
        bar:HookScript("OnShow", relayout)
        bar:HookScript("OnHide", relayout)
        bar:HookScript("OnSizeChanged", relayout)
      end
    end
  end
  local em = _G.EditModeManagerFrame
  if em and em.HookScript then
    em:HookScript("OnShow", function() setPanelsShown(false) end)
    em:HookScript("OnHide", function() setPanelsShown(true) end)
    ns.Note("actionbars", "edit mode", "EditModeManagerFrame")
  end
  relayout()

  ns.Guard("xp bar", styleXP)
  ns.Guard("xp bar watch", watchXP)

  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:RegisterEvent("PLAYER_REGEN_ENABLED")
  ev:SetScript("OnEvent", function()
    relayout()
    for _, spec in ipairs(BAR_FRAMES) do
      local bar = ns.Path(spec.names[1]) or (spec.names[2] and ns.Path(spec.names[2]))
      if bar then hideDividers(bar, 2) end
    end
  end)
end
