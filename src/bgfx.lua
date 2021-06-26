-- board graphics
-- manages drawing board tiles (like walls or fog of war)

require("src.bgfx.bgfx_wall")
require("src.bgfx.bgfx_rock")
require("src.bgfx.bgfx_tree")

g_bgfx = {}

BGFX_LAYER = enum {
  "base",
  "border",
  "fog"
}

local K_UNDERAPPROX_BORDERS = false

function bgfx_init()
  -- list of cfg graphics
  g_bgfx = {}
  board_observe(bgfx_on_board_update)

  bgfx_add("rock", {
    sprite = g_images.rock,
    mask = K_ROCK,
    subtile_fn = function(x, y)
      assert(x and y)
      return rock_get_subtile(x, y, K_ROCK, true, K_ROCK_IDX, 2)
    end
  })
  bgfx_add("tree", {
    sprite = g_images.tree,
    mask = K_TREE,
    subtile_fn = function(x, y)
      assert(x and y)
      return rock_get_subtile(x, y, K_TREE, true, K_TREE_IDX, 3)
    end
  })
  bgfx_add("wall", {
    sprite = g_images.wall,
    mask = bit.bor(K_WALL, K_STATIC),
    subdivided = true, -- use 2x2 per tile instead of 1
    subtile_fn = function(x, y, dx, dy)
      assert(x and y and dx and dy)
      return wall_get_subtile(x, y, dx, dy, K_WALL, false, true, K_STATIC)
    end
  })
  bgfx_add("rubble", {
    sprite = g_images.wall,
    mask = K_DECAL,
    subdivided = true,
    subtile_fn = function(x, y, dx, dy)
      if bit.band(board_get_value(x, y, 0), K_FEATURE_MASK) == K_DECAL then
        return 14 + ibool(dx == 1) + 4 * ibool(dy == 1)
      end
    end
  })
  bgfx_add("border", {
    sprite = g_images.border,
    mask = K_ROCK,
    layer = BGFX_LAYER.border,
    color = {1, 1, 0.7, 0.668},
    subdivided = true,
    subtile_fn = function(x, y, dx, dy)
      local board = g_state.board
      if K_UNDERAPPROX_BORDERS then
        if board_tile_is_border(x, y) then
          return
        end
        local facing_x = ibool(x == board.right - 2 and dx == 1) - ibool(x == board.left + 1 and dx == -1)
        local facing_y = ibool(y == board.bottom - 2 and dy == 1) - ibool(y == board.top + 1 and dy == -1)
        if facing_x == 0 and facing_y == 0 then
          return
        else
          return 4 * (1 + facing_y) + 1 + facing_x
        end
      else
        local facing_x = ibool(x == board.right - 1 and dx == -1) - ibool(x == board.left and dx == 1)
        local facing_y = ibool(y == board.bottom - 1 and dy == -1) - ibool(y == board.top and dy == 1)
        if facing_x == 0 and facing_y == 0 then
          return
        elseif facing_x == 0 or facing_y == 0 then
          return 4 * (1 - facing_y) + (1 - facing_x)
        else
          return ibool(dx == -1) + 4 * ibool(dy == -1) + 4 * 3
        end
      end
    end
  })
  bgfx_add("fog", {
    sprite = g_images.fog_of_war,
    mask = K_FOG_OF_WAR,
    layer = BGFX_LAYER.fog,
    subdivided = true, -- use 2x2 per tile instead of 1
    subtile_fn = function(x, y, dx, dy)
      assert(x and y and dx and dy)
      return wall_get_subtile(x, y, dx, dy, K_FOG_OF_WAR, true, false)
    end
  })
end

if k_tile_canvas then
  require("src.bgfx.bgfx_canvas")
else
  require("src.bgfx.bgfx_spritebatch")
end

-- for debugging / profiling only
g_refresh_count = 0

function bgfx_on_board_update(event)
  for key, bgfx in pairs(g_bgfx) do

    -- for debugging
    if g_debug_mode then
      g_refresh_count = 0
    end

    -- if only one tile changed, refresh only the given tiles and their neighbours
    if event.etype == K_BOARD_EVENT_SET and not event.during_board_resize then
      if bit.band(event.mask, bgfx.mask) ~= 0 then
        -- TODO / DEBUG: unclear why this "sparse update" logic fails.
        for yo, xo, v in array_2d_iterate(array_2d_grow(event.grid), -1) do
          if v ~= 0 then
            local x = xo + event.x
            local y = yo + event.y
            if board_tile_in_bounds(x, y) then
              bgfx_refresh_tile(bgfx, x, y)
            end
          end
        end
      end
    end

    -- full refresh when board is resized (required since sprite batch indexes are updated.).
    -- note that the initial board resize does not invoke this, because
    -- we don't begin observing until after the board is already initialized.
    -- (bgfx_refresh called in bgfx_init to make up for this.)
    if event.etype == K_BOARD_EVENT_RESIZE_END then
      bgfx_refresh(bgfx)
    end
  end
end

function bgfx_draw_at(x, y, sprite, tile_fn, draw_fn)
  draw_fn = draw_fn or draw_sprite
  local subtile = tile_fn(x, y)
  if subtile then
    draw_fn(sprite or g_images.rock,
      subtile,
      x * k_dim_x,
      y * k_dim_y
    )
  end
end

-- as above, but a 2x2 square of half-tiles
function bgfx_draw_subdivided_at(x, y, sprite, subtile_fn, draw_fn)
  draw_fn = draw_fn or draw_sprite
  for dy = -1,1 do
    for dx = -1,1 do
      if dx ~= 0 and dy ~= 0 then
        local wall_subtile = subtile_fn(x, y, dx, dy)
        if wall_subtile then
          draw_fn(sprite or g_images.wall, wall_subtile,
            (x + 0.25 + 0.25 * dx) * k_dim_x,
            (y + 0.25 + 0.25 * dy) * k_dim_y
          )
        end
      end
    end
  end
end

-- draws all terrain features on the given layer
function bgfx_draw(layer)
  layer = layer or BGFX_LAYER.base
  for id, bgfx in pairs(g_bgfx) do
    assert(type(bgfx) == "table")
    if bgfx.layer == layer then
      love.graphics.push_opts()
      if bgfx.color then
        love.graphics.setColor(unpack(bgfx.color))
      end
      bgfx_draw_feature(bgfx)
      love.graphics.pop_opts()
    end
  end
end