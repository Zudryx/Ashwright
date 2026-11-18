--[[
Ashwright: /ash dump, a record of everything on screen.
Copyright (C) 2026 Zudryx. GPL-3.0-or-later; see Core.lua.

Walks every frame the game has (not just the ones Ashwright knows about) and
saves each visible one, with its shown textures and text, to
AshwrightDB.dump: name, type, parent, frame level and strata, position and
size, what it hangs from, and each texture's atlas or file and color. One
dump answers "what is that, and where does it come from" for anything on
screen, so a fix never has to guess. Values the game keeps secret are
written as "secret".
]]

local _, ns = ...

local MAX_LINES = 30000

local function clean(v)
  if v == nil then return "-" end
  if ns.isSecret(v) then return "secret" end
  if type(v) == "number" then return tostring(math.floor(v * 10 + 0.5) / 10) end
  return tostring(v)
end

local function nameOf(o)
  if not o then return "-" end
  local n = ns.safe(o.GetDebugName, o) or ns.safe(o.GetName, o)
  if n == nil then return "?" end
  return clean(n)
end

local function rect(o)
  local l, b, w, h = ns.safe(o.GetLeft, o), ns.safe(o.GetBottom, o), ns.safe(o.GetWidth, o), ns.safe(o.GetHeight, o)
  return clean(l) .. "," .. clean(b) .. " " .. clean(w) .. "x" .. clean(h)
end

local function points(o)
  local n = ns.safe(o.GetNumPoints, o)
  if type(n) ~= "number" or ns.isSecret(n) or n == 0 then return "" end
  local t = {}
  for i = 1, n do
    local p, rel, rp, x, y = ns.safe(o.GetPoint, o, i)
    t[#t + 1] = clean(p) .. ">" .. nameOf(rel) .. ":" .. clean(rp) .. "(" .. clean(x) .. "," .. clean(y) .. ")"
  end
  return table.concat(t, " ")
end

local function color(o)
  local r, g, b, a = ns.safe(o.GetVertexColor, o)
  if r == nil then return "" end
  return clean(r) .. "/" .. clean(g) .. "/" .. clean(b) .. "/" .. clean(a)
end

-- lines are short strings: a dump of a busy screen stays a few MB at most
local function frameLine(f)
  local strata = ns.safe(f.GetFrameStrata, f)
  return ("F %s | %s | parent %s | lvl %s %s | %s | a %s | %s"):format(
    nameOf(f), clean(ns.safe(f.GetObjectType, f)), nameOf(ns.safe(f.GetParent, f)),
    clean(ns.safe(f.GetFrameLevel, f)), clean(strata), rect(f), clean(ns.safe(f.GetAlpha, f)), points(f))
end

local function regionLine(r)
  local t = ns.safe(r.GetObjectType, r)
  if t == "FontString" then
    local text = ns.safe(r.GetText, r)
    if text ~= nil and not ns.isSecret(text) then text = tostring(text):gsub("\n", " "):sub(1, 60) end
    return ("  T %s | %s | %s"):format(nameOf(r), rect(r), clean(text))
  end
  local layer, sub = ns.safe(r.GetDrawLayer, r)
  local art = ns.safe(r.GetAtlas, r) or ns.safe(r.GetTexture, r)
  return ("  %s %s | %s:%s | %s | %s | c %s | a %s"):format(t == "MaskTexture" and "M" or "X", nameOf(r),
    clean(layer), clean(sub), clean(art), rect(r), color(r), clean(ns.safe(r.GetAlpha, r)))
end


-- does this frame belong to, or hang from, the target frame?
local function tiedToTarget(f)
  local name = clean(ns.safe(f.GetDebugName, f) or ns.safe(f.GetName, f))
  if type(name) == "string" and name:find("Target", 1, true) then return true end
  local o, depth = f, 0
  while o and depth < 12 do
    if o == TargetFrame then return true end
    local n = ns.safe(o.GetNumPoints, o) or 0
    if type(n) == "number" then
      for i = 1, n do
        local _, rel = ns.safe(o.GetPoint, o, i)
        if rel and rel == TargetFrame then return true end
      end
    end
    o = ns.safe(o.GetParent, o); depth = depth + 1
  end
  return false
end

-- a button laid out like an aura: an icon texture plus a cooldown or count
local function auraLike(f)
  local icon = f.Icon or f.icon
  local extra = f.Cooldown or f.cooldown or f.Count or f.count
  return icon ~= nil and extra ~= nil
end

-- what the game says the target is wearing right now
local function targetAuras(lines)
  if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then
    lines[#lines + 1] = "A no aura lookup on this client"
    return
  end
  for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
    for i = 1, 40 do
      local a = ns.safe(C_UnitAuras.GetAuraDataByIndex, "target", i, filter)
      if type(a) ~= "table" then break end
      lines[#lines + 1] = ("A %s %d | icon %s | %s"):format(filter, i, clean(a.icon), clean(a.name))
    end
  end
end

function ns.Dump()
  if not EnumerateFrames then ns.Say("this client can't list its frames.") return end
  local lines, frames, skipped, unsure, hidden = {}, 0, 0, 0, 0
  local function record(f, mark)
    local good = pcall(function()
      lines[#lines + 1] = mark .. frameLine(f):sub(2)
      for _, r in ipairs({ f:GetRegions() }) do
        local shown = ns.safe(r.IsShown, r)
        if shown ~= false then lines[#lines + 1] = regionLine(r) end
      end
    end)
    if good then frames = frames + 1 else skipped = skipped + 1 end
  end
  pcall(targetAuras, lines)
  local f = EnumerateFrames()
  while f and #lines < MAX_LINES do
    local forbidden = f.IsForbidden and f:IsForbidden()
    if forbidden == true then
      skipped = skipped + 1
    else
      local ok, visible = pcall(f.IsVisible, f)
      if ok and visible == true then
        record(f, "F")
      elseif ok and visible == false then
        hidden = hidden + 1
        -- hidden, but kept when it is the target's or shaped like an aura: H lines
        local keep = false
        pcall(function() keep = tiedToTarget(f) or auraLike(f) end)
        if keep then record(f, "H") end
      else
        -- the game would not say whether it is shown (secret or error): keep it, marked F?
        unsure = unsure + 1
        record(f, "F?")
      end
    end
    f = EnumerateFrames(f)
  end
  -- frames the game leaves out of its list (the target's auras): walk the unit
  -- frames' own children and keep any not seen above, marked C
  local seen, unlisted = {}, 0
  local g = EnumerateFrames()
  while g do seen[g] = true; g = EnumerateFrames(g) end
  local function walk(o, depth)
    if depth > 8 or #lines >= MAX_LINES then return end
    local kids = { pcall(function() return o:GetChildren() end) }
    for i = 2, #kids do
      local c = kids[i]
      if type(c) == "table" then
        if not seen[c] then seen[c] = true; unlisted = unlisted + 1; record(c, "C") end
        walk(c, depth + 1)
      end
    end
  end
  for _, root in ipairs({ TargetFrame, FocusFrame, PlayerFrame }) do
    if root then pcall(walk, root, 0) end
  end
  ns.db.dump = { at = ns.safe(GetServerTime), addon = ns.VERSION, frames = frames, skipped = skipped, unlisted = unlisted, unsure = unsure, hidden = hidden,
                 truncated = (#lines >= MAX_LINES) or nil, lines = lines }
  ns.Say(("dump: %d frames recorded, %d with secret visibility, %d missing from the game's list (%d lines%s). /reload or log out, then send WTF/.../SavedVariables/Ashwright.lua.")
    :format(frames, unsure, unlisted, #lines, #lines >= MAX_LINES and ", stopped at the limit" or ""))
end

function ns.ClearDump()
  ns.db.dump = nil
  ns.Say("dump cleared.")
end
