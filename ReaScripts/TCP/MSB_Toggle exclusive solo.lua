-- @description MSB_Toggle exclusive solo
-- @version 1.0.0
-- @author Minseok Bang

reaper.Undo_BeginBlock()

local count = reaper.CountSelectedTracks(0)
if count > 0 then
  local sel_soloed = false
  for i = 0, count - 1 do
    if reaper.GetMediaTrackInfo_Value(reaper.GetSelectedTrack(0, i), "I_SOLO") > 0 then
      sel_soloed = true
      break
    end
  end

  reaper.Main_OnCommand(40340, 0)     -- Track: Unsolo all tracks
  if not sel_soloed then
    reaper.Main_OnCommand(7, 0)       -- Track: Solo/unsolo tracks
  end
end

reaper.Undo_EndBlock("MSB_Toggle exclusive solo", -1)
