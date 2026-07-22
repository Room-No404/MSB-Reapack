-- @description MSB_Mini Item Properties
-- @version 1.0.1
-- @author Minseok Bang
-- @requires ReaImGui (ReaPack)

-- =====================
-- Helpers
-- =====================
local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function round(x)
  if x >= 0 then return math.floor(x + 0.5) end
  return math.ceil(x - 0.5)
end

local function amp_to_db(amp)
  if amp <= 0 then return -150.0 end
  return 20.0 * (math.log(amp, 10))
end

local function db_to_amp(db)
  return 10.0 ^ (db / 20.0)
end

local function parse_pan(str)
  if not str then return nil end
  str = str:upper()
  if str == "C" then return 0.0 end
  local num = string.match(str, "%d+")
  if not num then return nil end
  num = tonumber(num)
  local has_L = string.find(str, "L") ~= nil
  local has_R = string.find(str, "R") ~= nil
  local has_neg = string.find(str, "-") ~= nil
  if has_R then
    num = math.abs(num)
  elseif has_L or has_neg then
    num = -math.abs(num)
  end
  return clamp(num, -100, 100) / 100.0
end

local function pan_to_str(pan)
  local p = round(pan * 100)
  if p < 0 then return tostring(math.abs(p)) .. "L"
  elseif p > 0 then return tostring(p) .. "R"
  else return "C" end
end

local function split_pitch(st)
  local x = st * 100
  local p100
  if x >= 0 then p100 = math.floor(x + 0.5) else p100 = math.ceil(x - 0.5) end
  local sem
  if p100 >= 0 then sem = math.floor(p100 / 100) else sem = math.ceil(p100 / 100) end
  local cent = p100 - sem * 100

  if cent >= 50 then
    cent = cent - 100
    sem  = sem + 1
  elseif cent < -50 then
    cent = cent + 100
    sem  = sem - 1
  end

  sem  = clamp(sem,  -96, 96)
  cent = clamp(cent, -50, 49)
  return sem, cent
end

local function join_pitch(sem, cent)
  cent = clamp(cent, -50, 49)
  return sem + (cent / 100.0)
end

local function begin_undo()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
end

local function end_undo(name)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock(name, -1)
end

local function get_selected_item()
  return reaper.GetSelectedMediaItem(0, 0)
end

local function for_each_selected_item(fn)
  local n = reaper.CountSelectedMediaItems(0)
  for i = 0, n - 1 do
    local it = reaper.GetSelectedMediaItem(0, i)
    if it then fn(it) end
  end
end

local function get_guid(it)
  local _, g = reaper.GetSetMediaItemInfo_String(it, 'GUID', '', false)
  return g
end

-- =====================
-- ImGui init
-- =====================
local ctx = reaper.ImGui_CreateContext('MSB_Mini Item Properties')
reaper.ImGui_SetNextWindowSize(ctx, 704, 84, reaper.ImGui_Cond_FirstUseEver())

-- Bigger font for the empty-state placeholder. On modern ReaImGui the size is
-- set at PushFont time, so CreateFont only takes the family (older builds want
-- family+size). Everything is pcall-guarded: if it fails, the default size is
-- used and nothing breaks.
local FONT_BIG_SIZE = 15
local font_big
do
  local ok, f = pcall(reaper.ImGui_CreateFont, 'sans-serif')                 -- modern (family only)
  if not (ok and f) then ok, f = pcall(reaper.ImGui_CreateFont, 'sans-serif', FONT_BIG_SIZE) end  -- legacy (family, size)
  if ok and f and pcall(reaper.ImGui_Attach, ctx, f) then font_big = f end
end
local function push_big_font()
  if not font_big then return false end
  if pcall(reaper.ImGui_PushFont, ctx, font_big, FONT_BIG_SIZE) then return true end
  if pcall(reaper.ImGui_PushFont, ctx, font_big) then return true end
  return false
end

-- Letter-spaced text (spaces between glyphs, wider gaps between words).
local function space_out(s)
  local words = {}
  for w in s:gmatch('%S+') do
    words[#words + 1] = (w:gsub('(.)', '%1 '):gsub(' $', ''))
  end
  return table.concat(words, '   ')
end

-- =====================
-- Theme
-- =====================
local function col(r, g, b, a)
  local cr, cg, cb, ca = r/255, g/255, b/255, (a or 255)/255
  return reaper.ImGui_ColorConvertDouble4ToU32(cr, cg, cb, ca)
end

-- Track how many colors/vars were pushed so pop_theme stays in sync
-- automatically when the theme changes (no more manual magic counts).
local pushed_colors, pushed_vars = 0, 0

local function push_theme()
  local function pc(idx, color)
    reaper.ImGui_PushStyleColor(ctx, idx, color)
    pushed_colors = pushed_colors + 1
  end
  local function pv(idx, a, b)
    if b then reaper.ImGui_PushStyleVar(ctx, idx, a, b)
    else        reaper.ImGui_PushStyleVar(ctx, idx, a) end
    pushed_vars = pushed_vars + 1
  end

  pc(reaper.ImGui_Col_WindowBg(),        col(50,50,50,255))
  pc(reaper.ImGui_Col_Border(),          col(80,80,80,255))
  pc(reaper.ImGui_Col_Text(),            col(245,245,245,255))
  pc(reaper.ImGui_Col_TextDisabled(),    col(170,170,170,255))
  pc(reaper.ImGui_Col_FrameBg(),         col(10,10,10,255))
  pc(reaper.ImGui_Col_FrameBgHovered(),  col(18,18,18,255))
  pc(reaper.ImGui_Col_FrameBgActive(),   col(24,24,24,255))
  pc(reaper.ImGui_Col_HeaderHovered(),   col(70,70,70,255))
  pc(reaper.ImGui_Col_HeaderActive(),    col(85,85,85,255))
  pc(reaper.ImGui_Col_PopupBg(),         col(30,30,30,255))

  pv(reaper.ImGui_StyleVar_WindowPadding(), 12, 10)
  pv(reaper.ImGui_StyleVar_FramePadding(),  8, 4)
  pv(reaper.ImGui_StyleVar_ItemSpacing(),   8, 4)
  pv(reaper.ImGui_StyleVar_FrameRounding(), 4)
  pv(reaper.ImGui_StyleVar_WindowRounding(),4)
  pv(reaper.ImGui_StyleVar_FrameBorderSize(),1)
end

local function pop_theme()
  reaper.ImGui_PopStyleVar(ctx, pushed_vars)
  reaper.ImGui_PopStyleColor(ctx, pushed_colors)
  pushed_vars, pushed_colors = 0, 0
end

-- =====================
-- Layout constants
-- =====================
local BOX_W            = 42
local LABEL_W          = 32
local FADE_BOX_W       = 60
local FADE_GAP         = 12
local CLEAR_BTN_W      = 20
local NAME_GAP         = 4
local LINE_GAP_Y       = 2
local LEN_LABEL_W      = 30
local LEN_BOX_W        = 64
local FADELEN_BOX_W    = 60
local FADELEN_GAP      = 6
local RATE_BOX_W       = 64
local MIN_LEN          = 0.0001  -- smallest allowed item length (seconds)
local MIN_RATE         = 0.01    -- playrate clamp (min / max)
local MAX_RATE         = 40.0
local GROUP_GAP        = 16      -- gap between control groups (gets a divider)
local INNER_GAP        = 8       -- gap between boxes inside one group
local ACCENT           = col(45, 200, 165, 255)  -- teal: hover / edit highlight
local DIV_COL          = col(120, 120, 120, 255) -- group divider line
local LABEL_COL        = col(140, 140, 140, 255) -- muted micro-label text

-- =====================
-- Settings (persisted via ExtState; edited from the gear popup)
-- =====================
local EXT_SECTION = "MSB_MiniItemProperties"
-- Wheel step per notch for each control (Length/Fade in seconds).
local CFG_DEFAULTS = {
  vol_step  = 0.1,    -- dB
  semi_step = 1,      -- semitones
  cent_step = 1,      -- cents
  pan_step  = 1,      -- pan units (/100)
  len_step  = 0.1,    -- seconds  (100 ms)
  fade_step = 0.1,    -- seconds  (100 ms)
  rate_step = 0.1,    -- playrate
}
local cfg = {}
local function cfg_load()
  for k, d in pairs(CFG_DEFAULTS) do
    cfg[k] = tonumber(reaper.GetExtState(EXT_SECTION, k)) or d
  end
end
local function cfg_save(k)
  reaper.SetExtState(EXT_SECTION, k, tostring(cfg[k]), true)
end
local function cfg_reset()
  for k, d in pairs(CFG_DEFAULTS) do cfg[k] = d; cfg_save(k) end
end
cfg_load()

-- Settings popup rows. `scale` maps stored unit -> shown unit (s -> ms),
-- `inc` is the wheel step (in shown units), `int` snaps to whole numbers.
local CFG_ROWS = {
  { key = 'vol_step',  label = 'Volume',   unit = 'dB', fmt = '%.2f', scale = 1,    inc = 0.01,  mn = 0.01,  mx = 12,   int = false },
  { key = 'semi_step', label = 'Semitone', unit = 'st', fmt = '%.0f', scale = 1,    inc = 1,     mn = 1,     mx = 12,   int = true  },
  { key = 'cent_step', label = 'Cent',     unit = '',   fmt = '%.0f', scale = 1,    inc = 1,     mn = 1,     mx = 50,   int = true  },
  { key = 'pan_step',  label = 'Pan',      unit = '',   fmt = '%.0f', scale = 1,    inc = 1,     mn = 1,     mx = 25,   int = true  },
  { key = 'len_step',  label = 'Length',   unit = 'ms', fmt = '%.0f', scale = 1000, inc = 1,     mn = 1,     mx = 1000, int = true  },
  { key = 'fade_step', label = 'Fade',     unit = 'ms', fmt = '%.0f', scale = 1000, inc = 1,     mn = 1,     mx = 500,  int = true  },
  { key = 'rate_step', label = 'Rate',     unit = '',   fmt = '%.3f', scale = 1,    inc = 0.001, mn = 0.001, mx = 1,    int = false },
}

-- =====================
-- State
-- =====================
local function get_wheel() return reaper.ImGui_GetMouseWheel(ctx) end
local consumed_wheel = false
local scrollY_before = 0.0

local edit_field = nil
local buf = { vol = "", st = "", ct = "", pan = "", len = "", fin_len = "", fout_len = "", rate = "" }

-- Per-item length captured when it entered the current selection, so a
-- double-click on the Len box can revert to the selection-time length.
local orig_len = {}
local focus_next = false

local function label_fixed(text, label_w)
  reaper.ImGui_AlignTextToFramePadding(ctx)
  local x0 = reaper.ImGui_GetCursorPosX(ctx)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), LABEL_COL)
  reaper.ImGui_Text(ctx, text:upper())
  reaper.ImGui_PopStyleColor(ctx)
  reaper.ImGui_SameLine(ctx, x0 + label_w)
end

-- =====================
-- Fade graphics
-- =====================
local function ease_shape(shape, t)
  if shape == 0 then return t end
  if shape == 1 then return 1 - (1 - t) ^ 2 end
  if shape == 2 then return t ^ 2 end
  if shape == 3 then return 1 - (1 - t) ^ 3 end
  if shape == 4 then return t ^ 3 end
  if shape == 5 then return t * t * (3 - 2 * t) end
  if shape == 6 then
    -- sharper S-curve: flatter ends, steeper middle (distinct from shape 5)
    local a = t ^ 4
    return a / (a + (1 - t) ^ 4)
  end
  return t
end

local function draw_fade_icon_at(x, y, w, h, shape, highlighted, mirror)
  local dl = reaper.ImGui_GetWindowDrawList(ctx)
  local col_bg = reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_FrameBg())
  local col_bd = reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_Border())
  local col_ln = reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_Text())
  local col_hi = reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_FrameBgHovered())

  reaper.ImGui_DrawList_AddRectFilled(dl, x, y, x + w, y + h, (highlighted and col_hi or col_bg), 4.0)
  reaper.ImGui_DrawList_AddRect(dl, x, y, x + w, y + h, col_bd, 4.0)

  local pad = 2
  local x0, y0 = x + pad, y + h - pad
  local x1, y1 = x + w - pad, y + pad

  local last_px, last_py
  local steps = 18
  for i = 0, steps do
    local tt = i / steps
    local v = ease_shape(shape, tt)
    local ttx = mirror and (1.0 - tt) or tt
    local px = x0 + (x1 - x0) * ttx
    local py = y0 - (y0 - y1) * v
    if last_px then
      reaper.ImGui_DrawList_AddLine(dl, last_px, last_py, px, py, col_ln, 1.4)
    end
    last_px, last_py = px, py
  end
end

local NUM_SHAPES = 7

local function shape_picker(idbase, current_shape, on_change, mirror, w, h)
  local popup_id = idbase .. "_popup"
  local x, y = reaper.ImGui_GetCursorScreenPos(ctx)

  if reaper.ImGui_InvisibleButton(ctx, idbase .. "_btn", w, h) then
    reaper.ImGui_OpenPopup(ctx, popup_id)
  end
  local hovered = reaper.ImGui_IsItemHovered(ctx)

  if hovered then
    local wheel = get_wheel()
    if wheel ~= 0.0 then
      consumed_wheel = true
      local idx = current_shape
      if wheel > 0 then idx = idx - 1 else idx = idx + 1 end
      idx = clamp(idx, 0, NUM_SHAPES - 1)
      on_change(idx)
    end
  end

  draw_fade_icon_at(x, y, w, h, current_shape, hovered, mirror)

  if reaper.ImGui_BeginPopup(ctx, popup_id) then
    for sid = 0, NUM_SHAPES - 1 do
      local px, py = reaper.ImGui_GetCursorScreenPos(ctx)
      if reaper.ImGui_InvisibleButton(ctx, idbase .. "_pick_" .. sid, w, h) then
        on_change(sid)
        reaper.ImGui_CloseCurrentPopup(ctx)
      end
      local hov = reaper.ImGui_IsItemHovered(ctx)
      draw_fade_icon_at(px, py, w, h, sid, (hov or sid == current_shape), mirror)
      reaper.ImGui_Spacing(ctx)
    end
    reaper.ImGui_EndPopup(ctx)
  end
end

-- =====================
-- Centered box & inline input
-- =====================
local function draw_centered_box(id, text, w, h, custom_bg, custom_hi)
  local dl = reaper.ImGui_GetWindowDrawList(ctx)
  local x, y = reaper.ImGui_GetCursorScreenPos(ctx)

  local clicked = false
  if reaper.ImGui_InvisibleButton(ctx, id, w, h) then clicked = true end

  local hovered = reaper.ImGui_IsItemHovered(ctx)
  local dclicked = hovered and reaper.ImGui_IsMouseDoubleClicked(ctx, 0)
  if dclicked then clicked = false end

  local col_bg = custom_bg or reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_FrameBg())
  local col_hi = custom_hi or reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_FrameBgHovered())
  local col_bd = reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_Border())
  local col_tx = reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_Text())

  reaper.ImGui_DrawList_AddRectFilled(dl, x, y, x + w, y + h, hovered and col_hi or col_bg, 4.0)
  reaper.ImGui_DrawList_AddRect(dl, x, y, x + w, y + h, hovered and ACCENT or col_bd, 4.0)

  local tw, th = reaper.ImGui_CalcTextSize(ctx, text)
  reaper.ImGui_DrawList_AddText(dl, x + (w - tw) * 0.5, y + (h - th) * 0.5, col_tx, text)

  return clicked, hovered, dclicked
end

local function inline_input(id, key, w)
  reaper.ImGui_PushItemWidth(ctx, w)
  if focus_next then
    reaper.ImGui_SetKeyboardFocusHere(ctx)
    focus_next = false
  end
  local flags = reaper.ImGui_InputTextFlags_EnterReturnsTrue() | reaper.ImGui_InputTextFlags_AutoSelectAll()
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), ACCENT)
  local enter, out = reaper.ImGui_InputText(ctx, id, buf[key], flags)
  reaper.ImGui_PopStyleColor(ctx)
  if type(out) == "string" then buf[key] = out end

  local deact_edit = reaper.ImGui_IsItemDeactivatedAfterEdit(ctx)
  local deact_any  = reaper.ImGui_IsItemDeactivated(ctx)
  local hovered    = reaper.ImGui_IsItemHovered(ctx)
  local active     = reaper.ImGui_IsItemActive(ctx)
  local dclicked   = hovered and reaper.ImGui_IsMouseDoubleClicked(ctx, 0)

  reaper.ImGui_PopItemWidth(ctx)
  return enter, deact_edit, deact_any, hovered, active, dclicked
end

-- =====================
-- Settings gear + popup
-- =====================
local function gear_button(id, size)
  local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
  local clicked = reaper.ImGui_InvisibleButton(ctx, id, size, size)
  local hov = reaper.ImGui_IsItemHovered(ctx)
  local dl = reaper.ImGui_GetWindowDrawList(ctx)
  local cx, cy = x + size * 0.5, y + size * 0.5
  local c  = hov and ACCENT or reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_TextDisabled())
  local bg = reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_WindowBg())

  -- Adjustments/sliders icon: three tracks, each with a knob at a different
  -- spot. Cleaner than a hand-drawn cog and fits a "tweak values" popup.
  local pad = size * 0.22
  local x1, x2 = x + pad, x + size - pad
  local gap = size * 0.17
  local ys = { cy - gap, cy, cy + gap }
  local kx = { 0.62, 0.34, 0.70 }
  local kr = size * 0.10
  for i = 1, 3 do
    local yy = ys[i]
    reaper.ImGui_DrawList_AddLine(dl, x1, yy, x2, yy, c, 1.6)
    local kcx = x1 + (x2 - x1) * kx[i]
    reaper.ImGui_DrawList_AddCircleFilled(dl, kcx, yy, kr * 1.7, bg, 16)  -- clearance
    reaper.ImGui_DrawList_AddCircleFilled(dl, kcx, yy, kr, c, 16)
  end
  return clicked
end

-- =====================
-- Generic spinner box
--   opts: {
--     display     = string,
--     enabled     = bool,
--     on_wheel    = function(direction:int),  -- direction is +1 or -1
--     on_typed    = function(buf_string),
--     on_reset    = function(),
--   }
-- =====================
local function spinner_box(id, key, opts)
  local box_h = reaper.ImGui_GetFrameHeight(ctx)
  local w = opts.w or BOX_W

  if not opts.enabled then
    draw_centered_box(id .. "_na", "-", w, box_h)
    return
  end

  if edit_field == key then
    local enter, deact_edit, deact_any, hov, active, dclicked = inline_input(id .. "_in", key, w)
    if dclicked then
      opts.on_reset()
      edit_field = nil
    elseif hov and (not active) then
      local w = get_wheel()
      if w ~= 0.0 then
        consumed_wheel = true
        opts.on_wheel(w > 0 and 1 or -1)
      end
    elseif enter or deact_edit then
      opts.on_typed(buf[key])
      edit_field = nil
    elseif deact_any then
      edit_field = nil
    end
  else
    buf[key] = opts.display
    local clicked, hov, dclicked = draw_centered_box(id .. "_box", opts.display, w, box_h)
    if dclicked then
      opts.on_reset()
    else
      if hov then
        local w = get_wheel()
        if w ~= 0.0 then
          consumed_wheel = true
          opts.on_wheel(w > 0 and 1 or -1)
        end
      end
      if clicked then edit_field = key; focus_next = true end
    end
  end
end

-- =====================
-- Settings popup (reuses the spinner box: wheel to nudge, click to type,
-- double-click to reset that one row)
-- =====================
local CFG_LABEL_W = 74
local CFG_BOX_W   = 60

local function cfg_apply(r, disp)
  disp = clamp(disp, r.mn, r.mx)
  if r.int then disp = math.floor(disp + 0.5) end
  cfg[r.key] = disp / r.scale
  cfg_save(r.key)
end

local function cfg_muted_text(text)
  reaper.ImGui_AlignTextToFramePadding(ctx)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), LABEL_COL)
  reaper.ImGui_Text(ctx, text)
  reaper.ImGui_PopStyleColor(ctx)
end

local function draw_settings_popup()
  -- NoMove: ImGui windows drag from their body by default; keep the popup put.
  if not reaper.ImGui_BeginPopup(ctx, 'settings', reaper.ImGui_WindowFlags_NoMove()) then return end
  local h = reaper.ImGui_GetFrameHeight(ctx)
  local avail_w = reaper.ImGui_GetContentRegionAvail(ctx)

  -- Heading (centered, bright, underline separator so it reads as the title).
  local title = "Wheel step per notch"
  local title_w = reaper.ImGui_CalcTextSize(ctx, title)
  reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetCursorPosX(ctx) + math.max(0, (avail_w - title_w) * 0.5))
  reaper.ImGui_Text(ctx, title)
  reaper.ImGui_Separator(ctx)
  reaper.ImGui_Dummy(ctx, 0, 3)

  for _, r in ipairs(CFG_ROWS) do
    local x0 = reaper.ImGui_GetCursorPosX(ctx)
    cfg_muted_text(r.label)
    reaper.ImGui_SameLine(ctx, x0 + CFG_LABEL_W)
    local disp = cfg[r.key] * r.scale
    reaper.ImGui_PushItemWidth(ctx, CFG_BOX_W)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), ACCENT)
    local changed, nv = reaper.ImGui_InputDouble(ctx, "##cfg_" .. r.key, disp, 0, 0, r.fmt)
    reaper.ImGui_PopStyleColor(ctx)
    reaper.ImGui_PopItemWidth(ctx)
    if changed then cfg_apply(r, nv) end
    if reaper.ImGui_IsItemHovered(ctx) and not reaper.ImGui_IsItemActive(ctx) then
      local wh = reaper.ImGui_GetMouseWheel(ctx)
      if wh ~= 0 then cfg_apply(r, disp + (wh > 0 and 1 or -1) * r.inc) end
    end
    if r.unit ~= '' then
      reaper.ImGui_SameLine(ctx, nil, 6)
      cfg_muted_text(r.unit)
    end
  end

  reaper.ImGui_Dummy(ctx, 0, 4)
  reaper.ImGui_Separator(ctx)
  reaper.ImGui_Dummy(ctx, 0, 4)
  reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetCursorPosX(ctx) + math.max(0, (avail_w - 132) * 0.5))
  if draw_centered_box("##cfg_reset", "Reset to defaults", 132, h) then cfg_reset() end

  reaper.ImGui_EndPopup(ctx)
end

-- =====================
-- Item edit operations (frame-independent — defined once, not per frame).
-- All apply to every selected item inside one undo block.
-- =====================
local function fmt_time(sec) return reaper.format_timestr(sec, "") end

-- Playback rate = varispeed stretch (no pitch preservation): changing the rate
-- also rescales each item's length so the same source audio is kept
-- (length * rate constant), matching the alt-drag edge-stretch feel.
local function stretch_rate(it, new_rate)
  local tk = reaper.GetActiveTake(it)
  if not tk then return end
  local old_rate = reaper.GetMediaItemTakeInfo_Value(tk, 'D_PLAYRATE')
  new_rate = clamp(new_rate, MIN_RATE, MAX_RATE)
  if old_rate <= 0 or new_rate <= 0 then return end
  local old_len = reaper.GetMediaItemInfo_Value(it, 'D_LENGTH')
  reaper.SetMediaItemTakeInfo_Value(tk, 'B_PPITCH', 0)  -- follow pitch (no correction)
  reaper.SetMediaItemTakeInfo_Value(tk, 'D_PLAYRATE', new_rate)
  reaper.SetMediaItemInfo_Value(it, 'D_LENGTH', math.max(old_len * old_rate / new_rate, MIN_LEN))
end
local function shift_rate(delta)  -- wheel: nudge each item's own rate
  if delta == 0 then return end
  begin_undo()
  for_each_selected_item(function(it)
    local tk = reaper.GetActiveTake(it)
    if tk then stretch_rate(it, reaper.GetMediaItemTakeInfo_Value(tk, 'D_PLAYRATE') + delta) end
  end)
  end_undo("Set playback rate")
end
local function set_rate_all(new_rate)  -- typed / reset: all items to same rate
  begin_undo()
  for_each_selected_item(function(it) stretch_rate(it, new_rate) end)
  end_undo("Set playback rate")
end

-- Item length: wheel = relative delta per item; typed = same absolute length.
local function shift_len(delta)
  if delta == 0 then return end
  begin_undo()
  for_each_selected_item(function(it)
    local cur = reaper.GetMediaItemInfo_Value(it, 'D_LENGTH')
    reaper.SetMediaItemInfo_Value(it, 'D_LENGTH', math.max(cur + delta, MIN_LEN))
  end)
  end_undo("Set item length")
end
local function set_len_all(v)
  v = math.max(v, MIN_LEN)
  begin_undo()
  for_each_selected_item(function(it) reaper.SetMediaItemInfo_Value(it, 'D_LENGTH', v) end)
  end_undo("Set item length")
end

-- Fade length (fade-in or fade-out): same wheel/typed model, min 0.
local function shift_fade(prop, delta)
  if delta == 0 then return end
  begin_undo()
  for_each_selected_item(function(it)
    local cur = reaper.GetMediaItemInfo_Value(it, prop)
    reaper.SetMediaItemInfo_Value(it, prop, math.max(cur + delta, 0.0))
  end)
  end_undo("Set fade length")
end
local function set_fade_all(prop, v)
  v = math.max(v, 0.0)
  begin_undo()
  for_each_selected_item(function(it) reaper.SetMediaItemInfo_Value(it, prop, v) end)
  end_undo("Set fade length")
end

-- Volume: apply a dB delta to each selected item (item volume only).
local function shift_vol_db(delta_db)
  if delta_db == 0 then return end
  begin_undo()
  for_each_selected_item(function(it)
    local new_db = clamp(amp_to_db(reaper.GetMediaItemInfo_Value(it, 'D_VOL')) + delta_db, -150.0, 24.0)
    reaper.SetMediaItemInfo_Value(it, 'D_VOL', db_to_amp(new_db))
  end)
  end_undo("Set item volume")
end

local function shift_pitch_st(delta_st)
  if delta_st == 0 then return end
  begin_undo()
  for_each_selected_item(function(it)
    local tk = reaper.GetActiveTake(it)
    if tk then
      local s, c = split_pitch(reaper.GetMediaItemTakeInfo_Value(tk, 'D_PITCH'))
      reaper.SetMediaItemTakeInfo_Value(tk, 'D_PITCH', join_pitch(clamp(s + delta_st, -96, 96), c))
    end
  end)
  end_undo("Set semitone")
end

-- Cent delta, wrapping into semitones as needed.
local function shift_pitch_cent(delta_cent)
  if delta_cent == 0 then return end
  begin_undo()
  for_each_selected_item(function(it)
    local tk = reaper.GetActiveTake(it)
    if tk then
      local s, c = split_pitch(reaper.GetMediaItemTakeInfo_Value(tk, 'D_PITCH'))
      -- floor((total+50)/100) already yields nc within [-50, 49]; no extra carry.
      local total = s * 100 + c + delta_cent
      local ns = math.floor((total + 50) / 100)
      reaper.SetMediaItemTakeInfo_Value(tk, 'D_PITCH', join_pitch(clamp(ns, -96, 96), total - ns * 100))
    end
  end)
  end_undo("Set cent")
end

local function shift_pan(delta_p100)
  if delta_p100 == 0 then return end
  begin_undo()
  for_each_selected_item(function(it)
    local tk = reaper.GetActiveTake(it)
    if tk then
      local p100 = clamp(round(reaper.GetMediaItemTakeInfo_Value(tk, 'D_PAN') * 100) + delta_p100, -100, 100)
      reaper.SetMediaItemTakeInfo_Value(tk, 'D_PAN', p100 / 100.0)
    end
  end)
  end_undo("Set pan")
end

-- =====================
-- Main loop
-- =====================
local WIN_FLAGS = reaper.ImGui_WindowFlags_NoScrollbar() | reaper.ImGui_WindowFlags_NoScrollWithMouse()

local function loop()
  push_theme()

  local visible, open = reaper.ImGui_Begin(ctx, 'MSB_Mini Item Properties', true, WIN_FLAGS)

  if visible then
    consumed_wheel = false
    scrollY_before = reaper.ImGui_GetScrollY(ctx)

    local box_h = reaper.ImGui_GetFrameHeight(ctx)

    local item = get_selected_item()
    if not item then
      local x0 = reaper.ImGui_GetCursorPosX(ctx)
      local y0 = reaper.ImGui_GetCursorPosY(ctx)
      local cw, ch = reaper.ImGui_GetContentRegionAvail(ctx)
      reaper.ImGui_SetCursorPos(ctx, x0 + cw - box_h, y0)
      if gear_button("##gear", box_h) then reaper.ImGui_OpenPopup(ctx, 'settings') end
      draw_settings_popup()
      local pushed = push_big_font()
      local txt = space_out('No item selected')
      local tw, th = reaper.ImGui_CalcTextSize(ctx, txt)
      local cx, cy = x0 + (cw - tw) * 0.5, y0 + (ch - th) * 0.5
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), ACCENT)
      reaper.ImGui_SetCursorPos(ctx, cx, cy)
      reaper.ImGui_Text(ctx, txt)
      reaper.ImGui_PopStyleColor(ctx)
      if pushed then reaper.ImGui_PopFont(ctx) end
      reaper.ImGui_End(ctx)
      pop_theme()
      if open then reaper.defer(loop) end
      return
    end

    local take = reaper.GetActiveTake(item)

    local item_vol = reaper.GetMediaItemInfo_Value(item, 'D_VOL')
    local take_vol = take and reaper.GetMediaItemTakeInfo_Value(take, 'D_VOL') or 1.0
    local vol_db = amp_to_db(item_vol) + amp_to_db(take_vol)

    local pitch_st = 0.0
    if take then pitch_st = reaper.GetMediaItemTakeInfo_Value(take, 'D_PITCH') end
    local sem, cent = split_pitch(pitch_st)

    local pan_val = 0.0
    if take then pan_val = reaper.GetMediaItemTakeInfo_Value(take, 'D_PAN') end

    local fin_shape  = math.floor(reaper.GetMediaItemInfo_Value(item, 'C_FADEINSHAPE'))
    local fout_shape = math.floor(reaper.GetMediaItemInfo_Value(item, 'C_FADEOUTSHAPE'))

    local item_len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
    local fin_len  = reaper.GetMediaItemInfo_Value(item, 'D_FADEINLEN')
    local fout_len = reaper.GetMediaItemInfo_Value(item, 'D_FADEOUTLEN')
    local playrate = take and reaper.GetMediaItemTakeInfo_Value(take, 'D_PLAYRATE') or 1.0

    -- Refresh length baselines: record an item's length the first frame it
    -- appears in the selection, drop it once it leaves (see orig_len usage).
    do
      local seen = {}
      for_each_selected_item(function(it)
        local g = get_guid(it)
        seen[g] = true
        if orig_len[g] == nil then
          orig_len[g] = reaper.GetMediaItemInfo_Value(it, 'D_LENGTH')
        end
      end)
      for g in pairs(orig_len) do
        if not seen[g] then orig_len[g] = nil end
      end
    end

    -- ===== Line 1: Vol / Semi Cent / Pan Rate / Fade In =====
    local dl = reaper.ImGui_GetWindowDrawList(ctx)
    local row1_y = select(2, reaper.ImGui_GetCursorScreenPos(ctx))
    local function group_divider(gap, y)
      local sx = reaper.ImGui_GetCursorScreenPos(ctx)
      local dx = sx - gap * 0.5
      reaper.ImGui_DrawList_AddLine(dl, dx, y - 2, dx, y + box_h + 2, DIV_COL, 1.0)
    end

    -- Selection count in mint (bigger font, nudged right), then a
    -- divider:  "3 | Vol | ..."
    reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetCursorPosX(ctx) + 6)
    local cnt_pushed = push_big_font()
    reaper.ImGui_AlignTextToFramePadding(ctx)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), ACCENT)
    reaper.ImGui_Text(ctx, tostring(reaper.CountSelectedMediaItems(0)))
    reaper.ImGui_PopStyleColor(ctx)
    if cnt_pushed then reaper.ImGui_PopFont(ctx) end
    reaper.ImGui_SameLine(ctx, nil, GROUP_GAP)
    group_divider(GROUP_GAP, row1_y)

    label_fixed("Vol", LABEL_W)
    spinner_box("##vol", "vol", {
      display = string.format("%.1f", vol_db),
      enabled = take ~= nil,
      on_wheel = function(dir) shift_vol_db(dir * cfg.vol_step) end,
      on_typed = function(s)
        local n = tonumber(s)
        if n then
          local target = clamp(n, -150.0, 24.0)
          shift_vol_db(target - vol_db)
        end
      end,
      on_reset = function()
        begin_undo()
        for_each_selected_item(function(it)
          reaper.SetMediaItemInfo_Value(it, 'D_VOL', 1.0)
          local tk = reaper.GetActiveTake(it)
          if tk then reaper.SetMediaItemTakeInfo_Value(tk, 'D_VOL', 1.0) end
        end)
        end_undo("Reset item volume")
      end,
    })

    reaper.ImGui_SameLine(ctx, nil, GROUP_GAP)
    group_divider(GROUP_GAP, row1_y)
    label_fixed("Semi", LABEL_W)
    spinner_box("##st", "st", {
      display = tostring(sem),
      enabled = take ~= nil,
      on_wheel = function(dir) shift_pitch_st(dir * cfg.semi_step) end,
      on_typed = function(s)
        local n = tonumber(s)
        if n then
          local target = clamp(round(n), -96, 96)
          shift_pitch_st(target - sem)
        end
      end,
      on_reset = function()
        begin_undo()
        for_each_selected_item(function(it)
          local tk = reaper.GetActiveTake(it)
          if tk then
            local cur = reaper.GetMediaItemTakeInfo_Value(tk, 'D_PITCH')
            local _, c = split_pitch(cur)
            reaper.SetMediaItemTakeInfo_Value(tk, 'D_PITCH', join_pitch(0, c))
          end
        end)
        end_undo("Reset semitone")
      end,
    })

    reaper.ImGui_SameLine(ctx, nil, INNER_GAP)
    label_fixed("Cent", LABEL_W)
    spinner_box("##ct", "ct", {
      display = tostring(cent),
      enabled = take ~= nil,
      on_wheel = function(dir) shift_pitch_cent(dir * cfg.cent_step) end,
      on_typed = function(s)
        local n = tonumber(s)
        if n then
          local target = round(n)
          shift_pitch_cent(target - cent)
        end
      end,
      on_reset = function()
        begin_undo()
        for_each_selected_item(function(it)
          local tk = reaper.GetActiveTake(it)
          if tk then
            local cur = reaper.GetMediaItemTakeInfo_Value(tk, 'D_PITCH')
            local s, _ = split_pitch(cur)
            reaper.SetMediaItemTakeInfo_Value(tk, 'D_PITCH', join_pitch(s, 0))
          end
        end)
        end_undo("Reset cent")
      end,
    })

    reaper.ImGui_SameLine(ctx, nil, GROUP_GAP)
    group_divider(GROUP_GAP, row1_y)
    label_fixed("Pan", LABEL_W)
    spinner_box("##pan", "pan", {
      display = pan_to_str(pan_val),
      enabled = take ~= nil,
      on_wheel = function(dir) shift_pan(dir * cfg.pan_step) end,
      on_typed = function(s)
        local parsed = parse_pan(s)
        if parsed then
          local target = round(parsed * 100)
          local cur = round(pan_val * 100)
          shift_pan(target - cur)
        end
      end,
      on_reset = function()
        begin_undo()
        for_each_selected_item(function(it)
          local tk = reaper.GetActiveTake(it)
          if tk then reaper.SetMediaItemTakeInfo_Value(tk, 'D_PAN', 0.0) end
        end)
        end_undo("Reset pan")
      end,
    })

    reaper.ImGui_SameLine(ctx, nil, INNER_GAP)
    local rate_x = reaper.ImGui_GetCursorPosX(ctx)
    label_fixed("Rate", LABEL_W)
    spinner_box("##rate", "rate", {
      display  = string.format("%.4f", playrate),
      enabled  = take ~= nil,
      w        = RATE_BOX_W,
      on_wheel = function(dir) shift_rate(dir * cfg.rate_step) end,
      on_typed = function(s)
        local n = tonumber(s)
        if n then set_rate_all(clamp(n, MIN_RATE, MAX_RATE)) end
      end,
      on_reset = function() set_rate_all(1.0) end,  -- double-click: back to 1.0
    })

    local fade_x = rate_x + LABEL_W + RATE_BOX_W + FADE_GAP
    reaper.ImGui_SameLine(ctx, fade_x)
    group_divider(FADE_GAP, row1_y)
    shape_picker("fin", fin_shape, function(v)
      begin_undo()
      for_each_selected_item(function(it)
        reaper.SetMediaItemInfo_Value(it, 'C_FADEINSHAPE', v)
      end)
      end_undo("Set fade-in shape")
    end, false, FADE_BOX_W, box_h)

    reaper.ImGui_SameLine(ctx, nil, FADELEN_GAP)
    spinner_box("##fin_len", "fin_len", {
      display  = fmt_time(fin_len),
      enabled  = true,
      w        = FADELEN_BOX_W,
      on_wheel = function(dir) shift_fade('D_FADEINLEN', dir * cfg.fade_step) end,
      on_typed = function(s)
        local v = reaper.parse_timestr(s)
        if v then set_fade_all('D_FADEINLEN', v) end
      end,
      on_reset = function() set_fade_all('D_FADEINLEN', 0.0) end,
    })

    reaper.ImGui_SameLine(ctx, nil, GROUP_GAP)
    if gear_button("##gear", box_h) then reaper.ImGui_OpenPopup(ctx, 'settings') end
    draw_settings_popup()

    reaper.ImGui_Dummy(ctx, 0, LINE_GAP_Y)

    -- ===== Line 2: Take name / Clear / Len / Fade Out =====
    if take then
      -- Name fills the space up to the Length group; Length sits just left of
      -- the fade column so the two fade icons stay vertically aligned.
      local name_start = reaper.ImGui_GetCursorPosX(ctx)
      local row2_y = select(2, reaper.ImGui_GetCursorScreenPos(ctx))
      local len_start = fade_x - FADE_GAP - (LEN_LABEL_W + LEN_BOX_W)
      local name_w = len_start - name_start - NAME_GAP - CLEAR_BTN_W - GROUP_GAP
      if name_w < 120 then name_w = 120 end
      local _, current_name = reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', '', false)
      reaper.ImGui_PushItemWidth(ctx, name_w)
      local _, new_name = reaper.ImGui_InputText(ctx, '##take_name', current_name)
      reaper.ImGui_PopItemWidth(ctx)
      if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then
        reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', new_name, true)
        reaper.UpdateArrange()
      end

      reaper.ImGui_SameLine(ctx, nil, NAME_GAP)
      local c_clicked = draw_centered_box("##clear_name", "\xC3\x97", CLEAR_BTN_W, box_h)
      if c_clicked then
        reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', '', true)
        reaper.UpdateArrange()
      end

      reaper.ImGui_SameLine(ctx, len_start)
      group_divider(GROUP_GAP, row2_y)
      label_fixed("Len", LEN_LABEL_W)
      spinner_box("##len", "len", {
        display  = fmt_time(item_len),
        enabled  = true,
        w        = LEN_BOX_W,
        on_wheel = function(dir) shift_len(dir * cfg.len_step) end,
        on_typed = function(s)
          local v = reaper.parse_timestr(s)
          if v and v > 0 then set_len_all(v) end
        end,
        on_reset = function()  -- double-click: revert to selection-time length
          begin_undo()
          for_each_selected_item(function(it)
            local base = orig_len[get_guid(it)]
            if base then reaper.SetMediaItemInfo_Value(it, 'D_LENGTH', base) end
          end)
          end_undo("Revert item length")
        end,
      })

      reaper.ImGui_SameLine(ctx, fade_x)
      group_divider(FADE_GAP, row2_y)
      shape_picker("fout", fout_shape, function(v)
        begin_undo()
        for_each_selected_item(function(it)
          reaper.SetMediaItemInfo_Value(it, 'C_FADEOUTSHAPE', v)
        end)
        end_undo("Set fade-out shape")
      end, true, FADE_BOX_W, box_h)

      reaper.ImGui_SameLine(ctx, nil, FADELEN_GAP)
      spinner_box("##fout_len", "fout_len", {
        display  = fmt_time(fout_len),
        enabled  = true,
        w        = FADELEN_BOX_W,
        on_wheel = function(dir) shift_fade('D_FADEOUTLEN', dir * cfg.fade_step) end,
        on_typed = function(s)
          local v = reaper.parse_timestr(s)
          if v then set_fade_all('D_FADEOUTLEN', v) end
        end,
        on_reset = function() set_fade_all('D_FADEOUTLEN', 0.0) end,
      })
    end

    if consumed_wheel then
      reaper.ImGui_SetScrollY(ctx, scrollY_before)
    end

    reaper.ImGui_End(ctx)
  end

  pop_theme()

  if open then reaper.defer(loop) end
end

reaper.defer(loop)

