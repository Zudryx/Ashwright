--[[
Ashwright: startup, settings and slash commands.
Copyright (C) 2026 Zudryx. GPL-3.0-or-later; see Core.lua.
]]

local ADDON, ns = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

local function copyDefaults(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      copyDefaults(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

local function enableModules()
  for _, name in ipairs(ns.order) do
    local m = ns.modules[name]
    if ns.db.modules[name] and m.Enable and not m.enabled then
      m.enabled = true
      ns.Run("enable " .. name, m.Enable)
    end
  end
end

frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 ~= ADDON then return end
    AshwrightDB = AshwrightDB or {}
    copyDefaults(AshwrightDB, ns.DEFAULTS)
    ns.db = AshwrightDB
    ns.db.errors = ns.db.errors or {}
    -- errors from an older version are history: start each version clean
    if ns.db.errorsVersion ~= ns.VERSION then ns.db.errors = {}; ns.db.errorsVersion = ns.VERSION end
  elseif event == "PLAYER_LOGIN" then
    enableModules()
  elseif event == "PLAYER_REGEN_ENABLED" then
    ns.FlushQueue()
  end
end)

local HELP = {
  "/ash - status",
  "/ash scan - check which frames this client has, saved for troubleshooting",
  "/ash module <name> on | off - unitframes, actionbars, castbars, minimap, chat, nameplates, tooltip (needs /reload)",
  "/ash ornate on | off - double iron border on the player frame, action bars and minimap (needs /reload)",
  "/ash nameoffset <px> - how far unit frame names sit above the bars (default 4, needs /reload)",
  "/ash inspect target | xp - record what is drawn on the target health bar or XP bar, for troubleshooting",
  "/ash chatpanel on | off - dark panel behind chat windows (needs /reload)",
  "/ash aligntarget on | off - line the target's bars up with yours when side by side",
  "/ash accent <hex> - accent color, e.g. /ash accent c9a75c (needs /reload)",
  "/ash errors - show logged errors",
  "/ash reset - back to defaults (needs /reload)",
}

SLASH_ASHWRIGHT1 = "/ash"
SLASH_ASHWRIGHT2 = "/ashwright"
SlashCmdList.ASHWRIGHT = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = (cmd or ""):lower()
  rest = rest or ""
  if cmd == "" or cmd == "status" then
    ns.Say("version " .. ns.VERSION .. (ns.db.ornate and ", ornate borders" or ", plain borders") ..
           ", accent #" .. ns.db.accent)
    local on, off = {}, {}
    for _, name in ipairs(ns.order) do
      if ns.db.modules[name] then on[#on + 1] = name else off[#off + 1] = name end
    end
    ns.Say("on: " .. (#on > 0 and table.concat(on, ", ") or "none"))
    if #off > 0 then ns.Say("off: " .. table.concat(off, ", ")) end
    if #ns.db.errors > 0 then ns.Say(#ns.db.errors .. " errors logged (/ash errors)") end
  elseif cmd == "help" then
    for _, l in ipairs(HELP) do ns.Say(l) end
  elseif cmd == "scan" then
    ns.Scan()
  elseif cmd == "module" then
    local name, state = rest:lower():match("^(%S+)%s+(%S+)$")
    if not name or not ns.modules[name] or (state ~= "on" and state ~= "off") then
      ns.Say("usage: /ash module <" .. table.concat(ns.order, "|") .. "> on|off") return
    end
    ns.db.modules[name] = state == "on"
    ns.Say(name .. " " .. state .. ". /reload to apply.")
  elseif cmd == "ornate" then
    if rest ~= "on" and rest ~= "off" then ns.Say("usage: /ash ornate on|off") return end
    ns.db.ornate = rest == "on"
    ns.Say("ornate borders " .. rest .. ". /reload to apply.")
  elseif cmd == "nameoffset" then
    local n = tonumber(rest)
    if not n or n < -10 or n > 20 then ns.Say("usage: /ash nameoffset <pixels, -10 to 20> (default 4)") return end
    ns.db.nameOffset = n
    ns.Say("unit frame names lifted " .. n .. " px. /reload to apply.")
  elseif cmd == "inspect" then
    -- guarded: a problem in the record goes to /ash errors, not a game error
    if not ns.Guard("inspect", ns.Inspect, rest ~= "" and rest:lower() or "target") then
      ns.Say("inspect hit a problem; /ash errors shows it.")
    end
  elseif cmd == "chatpanel" then
    if rest ~= "on" and rest ~= "off" then ns.Say("usage: /ash chatpanel on|off") return end
    ns.db.chatPanel = rest == "on"
    ns.Say("chat panel " .. rest .. ". /reload to apply.")
  elseif cmd == "aligntarget" then
    if rest ~= "on" and rest ~= "off" then ns.Say("usage: /ash aligntarget on|off") return end
    ns.db.alignTarget = rest == "on"
    local uf = ns.modules.unitframes
    if uf and uf.AlignTarget then
      if ns.db.alignTarget then ns.Run("align target", uf.AlignTarget)
      else ns.Say("target alignment off. /reload to put the bars back.") return end
    end
    ns.Say("target alignment " .. rest .. ".")
  elseif cmd == "accent" then
    local hex = rest:gsub("^#", ""):lower()
    if not hex:match("^%x%x%x%x%x%x$") then ns.Say("usage: /ash accent c9a75c") return end
    ns.db.accent = hex
    ns.Say("accent #" .. hex .. ". /reload to apply everywhere.")
  elseif cmd == "errors" then
    if #ns.db.errors == 0 then ns.Say("no errors.") return end
    for _, e in ipairs(ns.db.errors) do ns.Say(e) end
  elseif cmd == "reset" then
    AshwrightDB = {}
    ns.Say("settings reset. /reload to apply.")
  else
    ns.Say("unknown command. /ash help")
  end
end
