-- @description MSB_Select track of selected item
-- @version 1.0.0
-- @author Minseok Bang

reaper.set_action_options(1)
local _, _, sec, cmd = reaper.get_action_context()
reaper.SetToggleCommandState(sec, cmd, 1)
reaper.RefreshToolbar2(sec, cmd)
reaper.atexit(function()
  reaper.SetToggleCommandState(sec, cmd, 0)
  reaper.RefreshToolbar2(sec, cmd)
end)

local last_sig = ""

local function main()
  local count = reaper.CountSelectedMediaItems(0)
  if count == 0 then
    last_sig = ""
    return reaper.defer(main)
  end

  local items, tracks = {}, {}
  for i = 0, count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    items[i + 1] = tostring(item)
    tracks[reaper.GetMediaItemTrack(item)] = true
  end
  table.sort(items)
  local sig = table.concat(items, "|")

  if sig ~= last_sig then
    reaper.PreventUIRefresh(1)
    reaper.Main_OnCommand(40297, 0) -- Track: Unselect all tracks
    for tr in pairs(tracks) do reaper.SetTrackSelected(tr, true) end
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    last_sig = sig
  end

  reaper.defer(main)
end

main()
