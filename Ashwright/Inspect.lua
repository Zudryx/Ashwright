--[[
Ashwright: /ash inspect, a record of what is drawn on one part of the UI.
Copyright (C) 2026 Zudryx. GPL-3.0-or-later; see Core.lua.

When a skin looks wrong in the game, this lists every texture and frame on
that part (name, type, frame level, draw layer, shown, alpha, size, texture
or atlas, color) and saves it to AshwrightDB.inspect, so the fix comes from
what the client actually draws rather than from a guess.
]]

local _, ns = ...

local function clean(v)
  if v == nil then return nil end
  if ns.isSecret(v) then return "secret" end
  if type(v) == "number" then return math.floor(v * 100 + 0.5) / 100 end
  if type(v) == "boolean" then return v end
  return tostring(v)
end

local function describe(o, path)
  local t = { path = path }
  t.type = clean(ns.safe(o.GetObjectType, o))
  t.name = clean(ns.safe(o.GetDebugName, o) or ns.safe(o.GetName, o))
  t.shown = clean(ns.safe(o.IsShown, o))
  t.visible = clean(ns.safe(o.IsVisible, o))
  t.alpha = clean(ns.safe(o.GetAlpha, o))
  t.level = o.GetFrameLevel and clean(ns.safe(o.GetFrameLevel, o)) or nil
  if o.GetDrawLayer then
    local layer, sub = ns.safe(o.GetDrawLayer, o)
    if layer then t.layer = tostring(layer) .. ":" .. tostring(sub or 0) end
  end
  t.w, t.h = clean(ns.safe(o.GetWidth, o)), clean(ns.safe(o.GetHeight, o))
  t.top, t.bottom = clean(ns.safe(o.GetTop, o)), clean(ns.safe(o.GetBottom, o))
  -- where it hangs from: point, the frame it hangs from, that frame's point, offsets
  local n = o.GetNumPoints and ns.safe(o.GetNumPoints, o)
  if type(n) == "number" and not ns.isSecret(n) and n > 0 then
    local pts = {}
    for i = 1, n do
      local p, rel, rp, x, y = ns.safe(o.GetPoint, o, i)
      local relName = rel and (ns.safe(rel.GetDebugName, rel) or ns.safe(rel.GetName, rel)) or "?"
      pts[#pts + 1] = ("%s %s %s %s %s"):format(tostring(p), tostring(clean(relName)), tostring(rp),
                                               tostring(clean(x)), tostring(clean(y)))
    end
    t.points = table.concat(pts, " | ")
  end
  if t.type == "Texture" or t.type == "MaskTexture" then
    t.atlas = clean(ns.safe(o.GetAtlas, o))
    t.texture = clean(ns.safe(o.GetTexture, o))
    local r, g, b, a = ns.safe(o.GetVertexColor, o)
    if r then t.color = ("%s %s %s %s"):format(tostring(clean(r)), tostring(clean(g)), tostring(clean(b)), tostring(clean(a))) end
  elseif t.type == "StatusBar" then
    local mn, mx = ns.safe(o.GetMinMaxValues, o)
    t.value, t.min, t.max = clean(ns.safe(o.GetValue, o)), clean(mn), clean(mx)
    local r, g, b, a = ns.safe(o.GetStatusBarColor, o)
    if r then t.color = ("%s %s %s %s"):format(tostring(clean(r)), tostring(clean(g)), tostring(clean(b)), tostring(clean(a))) end
    local tex = ns.safe(o.GetStatusBarTexture, o)
    if tex then t.fill = clean(ns.safe(tex.GetTexture, tex)) or clean(ns.safe(tex.GetAtlas, tex)) end
  elseif t.type == "FontString" then
    t.text = clean(ns.safe(o.GetText, o))
  end
  return t
end

-- Every region and child frame under `root`, down to `depth` levels.
local function walk(root, rootPath, depth, out)
  out[#out + 1] = describe(root, rootPath)
  if root.GetRegions then
    for i, r in ipairs({ root:GetRegions() }) do out[#out + 1] = describe(r, rootPath .. ".r" .. i) end
  end
  if depth > 0 and root.GetChildren then
    for i, c in ipairs({ root:GetChildren() }) do walk(c, rootPath .. ".c" .. i, depth - 1, out) end
  end
end

local TARGETS = {
  target = function()
    local tf = _G.TargetFrame
    local bar = (tf and tf.healthbar)
      or ns.Path("TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar")
      or _G.TargetFrameHealthBar
    if not bar then return nil, "no target health bar" end
    -- the whole frame body (name band, bars, level), not just the bar
    local main = ns.Path("TargetFrame.TargetFrameContent.TargetFrameContentMain")
    if main then return main, "target frame", 3, tf.__ashPanel end
    local container = bar.GetParent and bar:GetParent()
    return container or bar, "health bar container", 2, tf.__ashPanel
  end,
  xp = function()
    local m = _G.MainStatusTrackingBarManager or _G.StatusTrackingBarManager or _G.MainMenuExpBar
    if not m then return nil, "no XP bar" end
    return m, "XP bar", 3
  end,
}

function ns.Inspect(kind)
  local get = TARGETS[kind]
  if not get then ns.Say("usage: /ash inspect target | xp") return end
  local root, label, depth, ours = get()
  if not root then ns.Say(label) return end
  local out = {}
  walk(root, kind, depth, out)
  if ours then
    out[#out + 1] = describe(ours, "ashwright panel")
    if ours.outer then out[#out + 1] = describe(ours.outer, "ashwright panel outer") end
  end
  -- the buffs and debuffs under the target frame
  if kind == "target" and _G.TargetFrame then
    local tf, i = _G.TargetFrame, 0
    if tf.auraPools and tf.auraPools.EnumerateActive then
      for a in tf.auraPools:EnumerateActive() do i = i + 1; out[#out + 1] = describe(a, "aura" .. i) end
    end
    if i == 0 and tf.GetChildren then
      for _, c in ipairs({ tf:GetChildren() }) do
        if c.Icon then i = i + 1; out[#out + 1] = describe(c, "aura?" .. i) end
      end
    end
  end
  ns.db.inspect = ns.db.inspect or {}
  ns.db.inspect[kind] = { at = ns.safe(GetServerTime), addon = ns.VERSION, entries = out }

  ns.Say(("%s: %d parts recorded. Visible ones:"):format(label, #out))
  local shown = 0
  for _, e in ipairs(out) do
    if e.visible == true and (e.alpha or 0) > 0 and shown < 14 then
      shown = shown + 1
      ns.Say(("  %s %s lvl %s %s %s"):format(e.type or "?", e.name or e.path, tostring(e.level or "-"),
             e.layer or "", e.atlas or e.texture or e.fill or e.text or ""))
    end
  end
  ns.Say("Saved. /reload, then send WTF/.../SavedVariables/Ashwright.lua.")
end
