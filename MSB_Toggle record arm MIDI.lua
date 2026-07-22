-- @description MSB_Toggle record arm MIDI
-- @version 1.0.0
-- @author Minseok Bang

local sel = reaper.GetSelectedTrack(0, 0)
if not sel then return end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

if reaper.GetMediaTrackInfo_Value(sel, "I_RECARM") == 1 then
  reaper.SetMediaTrackInfo_Value(sel, "I_RECARM", 0)
  reaper.SetMediaTrackInfo_Value(sel, "I_RECMON", 0)
else
  for i = 0, reaper.CountTracks(0) - 1 do
    local tr = reaper.GetTrack(0, i)
    reaper.SetMediaTrackInfo_Value(tr, "I_RECARM", 0)
    reaper.SetMediaTrackInfo_Value(tr, "I_RECMON", 0)
  end
  reaper.SetMediaTrackInfo_Value(sel, "I_RECARM", 1)
  reaper.SetMediaTrackInfo_Value(sel, "I_RECINPUT", 4096 + (63 << 5)) -- MIDI, all devices, all channels
  reaper.SetMediaTrackInfo_Value(sel, "I_RECMON", 1)
end

reaper.PreventUIRefresh(-1)
reaper.TrackList_AdjustWindows(false)
reaper.UpdateArrange()
reaper.Undo_EndBlock("MSB_Toggle record arm MIDI", -1)
