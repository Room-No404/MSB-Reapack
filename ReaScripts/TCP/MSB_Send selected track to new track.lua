-- @description MSB_Send selected track to new track
-- @version 1.0.0
-- @author Minseok Bang

reaper.Undo_BeginBlock()

local function shade(native, dl)
  if native == 0 then return native end
  local r, g, b = reaper.ColorFromNative(native)
  r, g, b = r/255, g/255, b/255
  local mx, mn = math.max(r, g, b), math.min(r, g, b)
  local h, s, l = 0, 0, (mx + mn)/2
  if mx ~= mn then
    local d = mx - mn
    s = l > 0.5 and d/(2 - mx - mn) or d/(mx + mn)
    if mx == r then h = (g - b)/d + (g < b and 6 or 0)
    elseif mx == g then h = (b - r)/d + 2
    else h = (r - g)/d + 4 end
    h = h/6
  end
  l = math.max(0, math.min(1, l + dl))
  local function h2(p, q, t)
    if t < 0 then t = t + 1 elseif t > 1 then t = t - 1 end
    if t < 1/6 then return p + (q - p)*6*t end
    if t < 1/2 then return q end
    if t < 2/3 then return p + (q - p)*(2/3 - t)*6 end
    return p
  end
  local nr, ng, nb
  if s == 0 then nr, ng, nb = l, l, l
  else
    local q = l < 0.5 and l*(1 + s) or l + s - l*s
    local p = 2*l - q
    nr, ng, nb = h2(p, q, h + 1/3), h2(p, q, h), h2(p, q, h - 1/3)
  end
  return reaper.ColorToNative(math.floor(nr*255 + 0.5), math.floor(ng*255 + 0.5), math.floor(nb*255 + 0.5))
end

local sel = reaper.GetSelectedTrack(0, 0)
if sel then
  local _, name = reaper.GetSetMediaTrackInfo_String(sel, "P_NAME", "", false)
  local color   = reaper.GetTrackColor(sel)
  local idx     = reaper.GetMediaTrackInfo_Value(sel, "IP_TRACKNUMBER")

  reaper.InsertTrackAtIndex(idx, true)
  local dst = reaper.GetTrack(0, idx)

  reaper.GetSetMediaTrackInfo_String(dst, "P_NAME", ">>" .. name, true)

  local shaded = shade(color, 0.1)
  if shaded ~= 0 then reaper.SetTrackColor(dst, shaded) end

  local send = reaper.CreateTrackSend(sel, dst)
  reaper.SetTrackSendInfo_Value(sel, 0, send, "D_VOL", 10^(-12/20))
  reaper.SetTrackSendInfo_Value(sel, 0, send, "I_SENDMODE", 0)
  reaper.SetTrackSendInfo_Value(sel, 0, send, "I_SRCCHAN", 0)
  reaper.SetTrackSendInfo_Value(sel, 0, send, "I_DSTCHAN", 0)

  reaper.SetOnlyTrackSelected(dst)
end

reaper.Undo_EndBlock("MSB_Send selected track to new track", -1)
reaper.TrackList_AdjustWindows(false)
