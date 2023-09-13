-- Flood is an object which detects whether a
-- particular protectee has been sealed in.

-- Create a Flood metatable
Flood = {}
Flood.__index = Flood

-- Constructor for Flood
function Flood.new()
  local f = setmetatable({
    sealed=false,
    flood_tiles={},
  }, Flood)
  board_observe(function(event)
    f:update()
  end)
  return f
end

-- Method to handle board updates
function Flood:update()
  -- TODO: use svy, protectee
  --local protectee = static_get(self.svy.protectee_idxs[self.svy.protectee_idxs])
  self.sealed = not svy_goal_reachable()
  if self.sealed then
    local x, y = svy_get_any_goal_coordinates()
    self.flood_tiles = board_floodfill(x, y, K_IMPATHABLE)
    print(#self.flood_tiles)
  end
end

function Flood:warning_draw()
    if self.sealed then
        for i, tile in ipairs(self.flood_tiles) do
            draw_image_on_grid(
                g_images.warning,
                tile.x, tile.y, 1, 1
            )
        end
    end
end