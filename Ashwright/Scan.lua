--[[
Ashwright: /ash scan, a report of which frames this client has.
Copyright (C) 2026 Zudryx. GPL-3.0-or-later; see Core.lua.

Every ns.Find() call notes which candidate name it found (or that none
existed). /ash scan prints a summary and saves the full list to
AshwrightDB.scan, so one test run on the real client shows exactly which
frames the skins reached and which names need adding.
]]

local _, ns = ...

ns.found = {}   -- [module] = { [label] = path or false }

function ns.Note(module, label, path)
  ns.found[module] = ns.found[module] or {}
  -- keep the first successful path for a label that is looked up repeatedly
  if ns.found[module][label] then return end
  ns.found[module][label] = path or false
end

function ns.Scan()
  local version, build, date, toc = ns.safe(GetBuildInfo)
  local report = {
    at = ns.safe(GetServerTime),
    addon = ns.VERSION,
    client = { version = version, build = build, date = date, toc = toc },
    modules = {},
    missing = {},
  }
  for _, name in ipairs(ns.order) do
    local list = ns.found[name] or {}
    local hit, total = 0, 0
    local entry = { enabled = ns.db.modules[name] and true or false, found = {}, missing = {} }
    for label, path in pairs(list) do
      total = total + 1
      if path then
        hit = hit + 1
        entry.found[label] = path
      else
        entry.missing[#entry.missing + 1] = label
        report.missing[#report.missing + 1] = name .. ": " .. label
      end
    end
    table.sort(entry.missing)
    entry.summary = ("%d of %d"):format(hit, total)
    report.modules[name] = entry
  end
  table.sort(report.missing)
  report.errors = ns.db.errors and #ns.db.errors or 0
  ns.db.scan = report

  ns.Say(("client %s (build %s, interface %s)"):format(tostring(version), tostring(build), tostring(toc)))
  for _, name in ipairs(ns.order) do
    local e = report.modules[name]
    ns.Say(("%s: %s frames found%s"):format(name, e.summary, e.enabled and "" or " (module off)"))
  end
  if report.errors > 0 then ns.Say(("%d errors logged (/ash errors)"):format(report.errors)) end
  ns.Say("Full list saved. /reload or log out, then send WTF/.../SavedVariables/Ashwright.lua.")
end
