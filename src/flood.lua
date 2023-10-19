-- Flood is an object which detects whether a
-- particular protectee has been sealed in.

require("src.bool_field")

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
  -- TODO: multiple protectees
  local protectee = static_get(g_state.svy.protectee_idxs[1])
  self.sealed = not svy_goal_reachable()
  
  self.flood_map = BoolField.new()
  if self.sealed then
    board_push_temporary_change_from_grid(protectee.x, protectee.y, protectee.grid, K_IMPATHABLE, 0)
    local x, y = svy_get_any_goal_coordinates()
    self.flood_tiles = board_floodfill(x, y, K_IMPATHABLE)
    board_pop_temporary_change()
    for i, tile in ipairs(self.flood_tiles) do
      self.flood_map:set(tile.x, tile.y, true)
    end
  end
end

function Flood:warning_draw()
  if self.sealed then
    
    --[[
    -- warning symbols
    for i, tile in ipairs(self.flood_tiles) do
      draw_image_on_grid(
        g_images.warning,
        tile.x, tile.y, 1, 1
      )
    end
    ]]
    
    camera_begin_temporary_canvas()
  
    -- warning stripes
    for i, tile in ipairs(self.flood_tiles) do
      local ntype = self.flood_map:getNeighbourhood5Type(tile.x, tile.y)
      draw_sprite_on_grid(
        g_images.warnstripes,
        (g_state.real_time * K_WARN_STRIPE_SPEED) % 4,
        tile.x, tile.y, 1, 1
      )
      if ntype < 15 then
        draw_sprite_on_grid(
            g_images.warnborder,
            ntype,
            tile.x, tile.y, 1, 1
        )
      end
    end
    
    local alpha = math.sin(math.tau / K_WARNING_BLINK_INTERVAL * g_state.real_time) * 0.5 + 0.5
    love.graphics.setColor(1, 1, 1, alpha)
    camera_commit_temporary_canvas()
    love.graphics.setColor(1, 1, 1, 1)
  end
end