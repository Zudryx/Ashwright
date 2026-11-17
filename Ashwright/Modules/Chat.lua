--[[
Ashwright: chat.
Copyright (C) 2026 Zudryx. GPL-3.0-or-later; see Core.lua.

Sets the chat font (keeping each window's size), puts a dark panel with a
thin border behind each chat window, its scroll bar and its input box
(/ash chatpanel off to remove it), fades the tab art and gives the input box
a flat panel.
]]

local _, ns = ...
local M = ns.Module("chat")
local C = ns.C

local function styleTab(tab)
  if not tab or tab.__ash then return end
  tab.__ash = true
  ns.KillTextures(tab)
  local text = tab.Text or (tab.GetFontString and tab:GetFontString())
  if text then ns.Font(text, "body", 12) end
end

-- The chat window's own box leaves out its scroll bar (to the right) and the
-- input box (usually below). The panel is stretched to cover both, measured
-- from where they actually are, and re-measured when any of them changes.
local function fitPanel(cf)
  local panel = cf.__ashPanel
  if not panel then return end
  local pad = 4
  local cl, cr, cb = cf:GetLeft(), cf:GetRight(), cf:GetBottom()
  panel:ClearAllPoints()
  panel:SetPoint("TOPLEFT", cf, "TOPLEFT", -pad, pad)
  if not (cl and cr and cb) then
    panel:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", pad, -pad)
    return
  end
  local right, bottom = cr, cb
  -- scroll bar and scroll-to-bottom button on the right
  ns.Each(function(f)
    local r = f.GetRight and f:GetRight()
    if r and r > right then right = r end
  end, cf.ScrollBar, cf.ScrollToBottomButton, _G[(cf:GetName() or "") .. "ScrollBar"])
  -- the input box, when it sits under the window (the default)
  local eb = _G[(cf:GetName() or "") .. "EditBox"]
  if eb then
    local et, ebm = eb:GetTop(), eb:GetBottom()
    if et and ebm then
      if et <= cb + 12 and ebm < bottom then bottom = ebm end
      local er = eb:GetRight()
      if er and et <= cb + 12 and er > right then right = er end
    else
      -- hidden while you're not typing: no position, so use where it is
      -- anchored (its top on the window's bottom) and its height
      local p, rel, rp, _, y = eb:GetPoint(1)
      if rel == cf and p and rp and p:find("TOP") and rp:find("BOTTOM") then
        local h = eb:GetHeight() or 0
        bottom = math.min(bottom, cb + (y or 0) - h)
      end
    end
  end
  panel:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", right - cr + pad, bottom - cb - pad)
end
ns.FitChatPanel = fitPanel

local function styleWindow(i)
  local cf = _G["ChatFrame" .. i]
  if not cf then return false end
  local _, size = cf:GetFont()
  ns.Font(cf, "body", size)
  -- the mockup's dark chat panel; the game's own chat opacity setting still
  -- applies on top of it
  local eb = _G["ChatFrame" .. i .. "EditBox"]
  if ns.db.chatPanel and not cf.__ashPanel then
    cf.__ashPanel = ns.Panel(cf, { pad = 4, bg = { 0.043, 0.039, 0.031, 0.80 }, border = C.border })
    local function refit() ns.Guard("chat panel", fitPanel, cf) end
    refit()
    cf:HookScript("OnSizeChanged", refit)
    cf:HookScript("OnShow", refit)
    ns.Each(function(f)
      if f.HookScript then
        f:HookScript("OnShow", refit)
        f:HookScript("OnHide", refit)
        f:HookScript("OnSizeChanged", refit)
      end
    end, cf.ScrollBar, eb)
  end
  styleTab(_G["ChatFrame" .. i .. "Tab"])
  if eb and not eb.__ash then
    eb.__ash = true
    ns.KillTextures(eb)
    ns.Panel(eb, { pad = -4, bg = C.panel, border = C.border })
    ns.Font(eb, "body")
  end
  return true
end

function M.Enable()
  local n = _G.NUM_CHAT_WINDOWS or 10
  local found = 0
  for i = 1, n do
    if ns.Guard("chat " .. i, styleWindow, i) and _G["ChatFrame" .. i] then found = found + 1 end
  end
  ns.Note("chat", "chat windows", found > 0 and ("ChatFrame1-" .. found) or nil)
  -- positions are only known once the world has loaded; moving or docking a
  -- window also changes them
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:SetScript("OnEvent", function()
    for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
      local cf = _G["ChatFrame" .. i]
      if cf and cf.__ashPanel then ns.Guard("chat panel", fitPanel, cf) end
    end
  end)
  if _G.FCF_DockUpdate then
    hooksecurefunc("FCF_DockUpdate", function()
      for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
        local cf = _G["ChatFrame" .. i]
        if cf and cf.__ashPanel then ns.Guard("chat panel", fitPanel, cf) end
      end
    end)
  end
  -- windows opened later (whispers, new tabs)
  if _G.FCF_OpenTemporaryWindow then
    hooksecurefunc("FCF_OpenTemporaryWindow", function()
      for i = 1, (_G.NUM_CHAT_WINDOWS or 10) + 10 do
        if _G["ChatFrame" .. i] then ns.Guard("chat " .. i, styleWindow, i) end
      end
    end)
  end
end
