--[[
Ashwright: a dark, minimal reskin of the default UI.
Copyright (C) 2026 Zudryx

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

How it stays safe
  * It only changes how Blizzard's frames LOOK: textures, colors, fonts and
    borders. It never replaces Blizzard functions, never moves secure frames
    and never changes what a button does.
  * Anything that touches a Blizzard frame runs out of combat; work that
    arrives in combat waits for combat to end.
  * Every frame is looked up by several known names (classic-style and
    modern UI code). Missing frames are skipped and listed by /ash scan.
]]

local ADDON, ns = ...
ns.VERSION = "0.1.9"
_G.Ashwright = ns

local WHITE = "Interface\\Buttons\\WHITE8X8"
ns.WHITE = WHITE

-- Palette from the "Ash & Iron" mockup (r, g, b, a in 0-1).
ns.C = {
  panel      = { 0.043, 0.039, 0.031, 0.90 },
  panelSolid = { 0.043, 0.039, 0.031, 1 },
  border     = { 0.290, 0.251, 0.200, 1 },   -- #4a4033
  slot       = { 0.114, 0.102, 0.082, 1 },   -- #1d1a15
  slotBorder = { 0.247, 0.212, 0.169, 1 },   -- #3f362b
  outer      = { 0.039, 0.031, 0.024, 1 },   -- #0a0806, the dark band of an ornate border
  outerLine  = { 0.180, 0.149, 0.106, 1 },   -- #2e261b
  ornate     = { 0.357, 0.290, 0.196, 1 },   -- #5b4a32
  text       = { 0.839, 0.788, 0.678 },      -- #d6c9ad
  title      = { 0.894, 0.839, 0.722 },      -- #e4d6b8
  muted      = { 0.663, 0.616, 0.522 },      -- #a99d85
  health     = { 0.608, 0.165, 0.149 },      -- #9b2a26
  healthBg   = { 0.165, 0.078, 0.078, 1 },   -- #2a1414
  barBorder  = { 0.227, 0.173, 0.133, 1 },   -- #3a2c22
}

local DEFAULTS = {
  accent = "c9a75c",
  ornate = true,       -- double iron border on things that appear once
  chatPanel = true,    -- dark panel behind chat windows
  nameOffset = 4,      -- pixels unit frame names are lifted above the panel edge
  modules = { unitframes = true, actionbars = true, minimap = true, chat = true,
              nameplates = true, tooltip = true, castbars = true },
  alignTarget = true,
  -- Optional font files. Drop TTFs at these paths to use them; the
  -- game's own fonts are used when they are missing.
  titleFont = "Interface\\AddOns\\Ashwright\\Media\\Title.ttf",
  bodyFont = "Interface\\AddOns\\Ashwright\\Media\\Body.ttf",
}
ns.DEFAULTS = DEFAULTS

local FALLBACK_TITLE = "Fonts\\MORPHEUS.TTF"
local FALLBACK_BODY = "Fonts\\FRIZQT__.TTF"

---------------------------------------------------------------------------
-- small helpers
---------------------------------------------------------------------------

local function passOk(ok, ...) if ok then return ... end end
function ns.safe(f, ...)
  if not f then return nil end
  return passOk(pcall(f, ...))
end

-- Midnight-engine clients can hide some combat values from addons.
function ns.isSecret(v)
  return issecretvalue ~= nil and v ~= nil and issecretvalue(v) or false
end

function ns.Say(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffc9a75cAshwright|r: " .. msg)
end

function ns.Guard(what, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok and ns.db then
    ns.db.errors = ns.db.errors or {}
    if #ns.db.errors < 50 then ns.db.errors[#ns.db.errors + 1] = what .. ": " .. tostring(err) end
  end
  return ok
end

function ns.Accent()
  local hex = (ns.db and ns.db.accent) or DEFAULTS.accent
  local r, g, b = hex:match("^(%x%x)(%x%x)(%x%x)$")
  if not r then return 0.788, 0.655, 0.361, 1 end
  return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255, 1
end

-- "PlayerFrame.healthbar" -> the object, walking globals and fields.
function ns.Path(path)
  local obj
  for part in path:gmatch("[^%.]+") do
    if obj == nil then obj = _G[part] else obj = type(obj) == "table" and obj[part] or nil end
    if obj == nil then return nil end
  end
  return obj
end

-- First existing object among candidate paths; every lookup is noted for /ash scan.
function ns.Find(module, label, ...)
  for i = 1, select("#", ...) do
    local p = select(i, ...)
    local obj = ns.Path(p)
    if obj ~= nil then
      ns.Note(module, label, p)
      return obj, p
    end
  end
  ns.Note(module, label, nil)
  return nil
end

-- One physical pixel in UI units for this frame.
function ns.Pixel(frame)
  local scale = (frame and frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
  if PixelUtil and PixelUtil.GetNearestPixelSize then
    return PixelUtil.GetNearestPixelSize(1, scale, 1)
  end
  local _, h = GetPhysicalScreenSize()
  return (h and h > 0) and (768 / h / scale) or 1
end

---------------------------------------------------------------------------
-- hiding art without breaking anything
---------------------------------------------------------------------------

-- Calls fn(x) for each non-nil argument. Unlike ipairs over a literal list,
-- a missing value in the middle does not stop it.
function ns.Each(fn, ...)
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if v ~= nil then fn(v) end
  end
end

-- Fade a texture or frame away, and keep it faded: some Blizzard code fades
-- art back in (the minimap zoom buttons on hover, the target's name color),
-- so later SetAlpha calls are answered with alpha 0 again.
-- hard = also hide it, and hide it again whenever the game shows it (for art
-- the game re-shows with Show(), like the target's name color band).
function ns.Kill(region, hard)
  if not region or not region.SetAlpha then return end
  region:SetAlpha(0)
  if not region.__ashKilled then
    region.__ashKilled = true
    ns.Keep(region, "SetAlpha", function(self, a) if a and a > 0 then self:SetAlpha(0) end end)
  end
  if hard and region.Hide and not region.__ashHidden then
    region.__ashHidden = true
    region:Hide()
    ns.Keep(region, "Show", function(self) self:Hide() end)
  end
end

-- Fade every texture directly on a frame, leaving child frames, buttons and text alone.
function ns.KillTextures(frame, keep)
  if not frame or not frame.GetRegions then return end
  for _, r in ipairs({ frame:GetRegions() }) do
    if r.GetObjectType and r:GetObjectType() == "Texture" and not (keep and keep[r]) then
      ns.Kill(r)
    end
  end
end

-- Keep a status bar's fill flat. Some frames re-apply their art straight onto
-- the fill texture (SetAtlas / SetTexture on it), bypassing SetStatusBarTexture,
-- so the fill texture itself is watched too.
function ns.FlatFill(bar, after)
  bar:SetStatusBarTexture(ns.WHITE)
  ns.Keep(bar, "SetStatusBarTexture", function(self)
    self:SetStatusBarTexture(ns.WHITE)
    if after then after(self) end
  end)
  local tex = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
  if tex and not tex.__ashFlat then
    tex.__ashFlat = true
    tex:SetTexture(ns.WHITE)
    ns.Keep(tex, "SetAtlas", function(self) self:SetTexture(ns.WHITE); if after then after(bar) end end)
    ns.Keep(tex, "SetTexture", function(self, file)
      if file ~= ns.WHITE then self:SetTexture(ns.WHITE) end
      if after then after(bar) end
    end)
  end
end

-- Re-applies fn whenever Blizzard calls method on obj (guarded so our own
-- call inside fn does not loop).
function ns.Keep(obj, method, fn)
  if not obj or not obj[method] then return end
  local busy = false
  hooksecurefunc(obj, method, function(self, ...)
    if busy then return end
    busy = true
    ns.Guard("keep " .. method, fn, self, ...)
    busy = false
  end)
end

---------------------------------------------------------------------------
-- panels and borders
---------------------------------------------------------------------------

local function backdropFrame(parent)
  local f = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  return f
end

-- A flat panel with a 1px border, drawn BEHIND `target`, padded outward.
-- opts: pad (number), bg, border, ornate (bool), parent (frame to own it)
function ns.Panel(target, opts)
  opts = opts or {}
  local parent = opts.parent or target
  local px = ns.Pixel(target)
  local pad = (opts.pad or 0) * 1

  local f = backdropFrame(parent)
  f:SetPoint("TOPLEFT", target, "TOPLEFT", -pad - px, pad + px)
  f:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", pad + px, -pad - px)
  -- Draw order: [outer band] < [panel] < target. Frame levels cannot go below 0,
  -- so a target at level 0 or 1 is lifted instead of letting the panel tie
  -- with it (a tie can draw the panel over the target, hiding a bar's fill).
  local ornate = opts.ornate and ns.db and ns.db.ornate
  local lvl = (target.GetFrameLevel and target:GetFrameLevel()) or 1
  local base = math.max(lvl - (ornate and 2 or 1), 0)
  f:SetFrameLevel(ornate and base + 1 or base)
  if f.SetBackdrop then
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = px })
    f:SetBackdropColor(unpack(opts.bg or ns.C.panel))
    f:SetBackdropBorderColor(unpack(opts.border or ns.C.border))
  end

  if ornate then
    -- the B mockup's frame: a dark 3px band, then a thin iron line
    local o = backdropFrame(parent)
    o:SetPoint("TOPLEFT", f, "TOPLEFT", -4 * px, 4 * px)
    o:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 4 * px, -4 * px)
    o:SetFrameLevel(base)
    if o.SetBackdrop then
      o:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = px })
      o:SetBackdropColor(unpack(ns.C.outer))
      o:SetBackdropBorderColor(unpack(ns.C.outerLine))
    end
    if f.SetBackdropBorderColor then f:SetBackdropBorderColor(unpack(ns.C.ornate)) end
    f.outer = o
  end
  ns.Above(f, target)
  return f
end

-- Make sure each frame draws above `panel`, lifting its frame level if needed.
-- Only called out of combat for Blizzard frames (see ns.Run).
function ns.Above(panel, ...)
  local pl = panel:GetFrameLevel()
  ns.Each(function(fr)
    if fr.GetFrameLevel and fr.SetFrameLevel and fr:GetFrameLevel() <= pl then
      ns.safe(fr.SetFrameLevel, fr, pl + 1)
    end
  end, ...)
end

---------------------------------------------------------------------------
-- fonts
---------------------------------------------------------------------------

-- kind: "title" or "body". Keeps the current size unless one is given.
function ns.Font(fs, kind, size, flags)
  if not fs or not fs.SetFont then return end
  local _, curSize, curFlags = fs:GetFont()
  size = size or curSize or 12
  flags = flags or curFlags or ""
  local path = kind == "title" and ns.db.titleFont or ns.db.bodyFont
  local fallback = kind == "title" and FALLBACK_TITLE or FALLBACK_BODY
  local ok = ns.safe(fs.SetFont, fs, path, size, flags)
  if not ok or not fs:GetFont() then
    fs:SetFont(fallback, size, flags)
  end
end

---------------------------------------------------------------------------
-- combat-safe work queue
---------------------------------------------------------------------------

local queue = {}
function ns.Run(what, fn, ...)
  if InCombatLockdown() then
    queue[#queue + 1] = { what = what, fn = fn, args = { ... } }
    return false
  end
  ns.Guard(what, fn, ...)
  return true
end

function ns.FlushQueue()
  local q = queue
  queue = {}
  for _, job in ipairs(q) do ns.Guard(job.what, job.fn, unpack(job.args)) end
end

ns.modules, ns.order = {}, {}
function ns.Module(name)
  local m = { name = name }
  ns.modules[name] = m
  ns.order[#ns.order + 1] = name
  return m
end
