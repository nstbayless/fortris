-- manages drawing board tiles which are dependent on their surroundings (like walls or fog of war)

require("src.bgfx.bgfx_wall")
require("src.bgfx.bgfx_rock")
require("src.bgfx.bgfx_tree")

local g_bgfx = {}

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
    mask = K_WALL,
    subdivided = true, -- use 2x2 per tile instead of 1
    subtile_fn = function(x, y, dx, dy)
      assert(x and y and dx and dy)
      return wall_get_subtile(x, y, dx, dy, K_WALL, false, true)
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
  bgfx_add("fog", {
    sprite = g_images.fog_of_war,
    mask = K_FOG_OF_WAR,
    subdivided = true, -- use 2x2 per tile instead of 1
    subtile_fn = function(x, y, dx, dy)
      assert(x and y and dx and dy)
      return wall_get_subtile(x, y, dx, dy, K_FOG_OF_WAR, true, false)
    end
  })
end

function bgfx_add(id, opts)
  opts.sprite_batch = love.graphics.newSpriteBatch(opts.sprite.spriteSheet, bgfx_get_sprite_batch_sprite_count(opts))
  opts.indices = {}
  g_bgfx[id] = opts
  bgfx_refresh(g_bgfx[id])
end

function bgfx_get_sprite_batch_idx(bgfx, x, y)
  local board = g_state.board
  -- max is for paranoia.
  -- unsure why adding 1 is necessary but it seems to be extremely important.
  return math.max(0, tern(bgfx.subdivided, 4, 1) * (x - board.left + (y - board.top) * board_width())) + 1
end

function bgfx_get_sprite_batch_sprite_count(bgfx)
  return tern(bgfx.subdivided, 4, 1) * board_width() * board_height() + 1
end

function bgfx_refresh_tile(bgfx, x, y)
  -- (pass-by-reference idx into function to allow updating it.)
  local idx = bgfx_get_sprite_batch_idx(bgfx, x, y)
  for i = idx,tern(bgfx.subdivided, idx+3, idx) do
    sprite_batch_remove(bgfx.sprite_batch, i)
  end
  local draw_fn = tern(bgfx.subdivided, bgfx_draw_subdivided_at, bgfx_draw_at)
  draw_fn(x, y, bgfx.sprite_batch, bgfx.subtile_fn or wall_get_subtile,
    function(sb, ...)
      local t = {...}
      if bgfx.indices[idx] == nil then
        --print("add new at", idx)
        local i = sprite_batch_add_sprite(sb, bgfx.sprite, unpack(t))
        assert(i) -- if this assertion is bothersome, it's not actually necessary.
        bgfx.indices[idx] = i
      else
        --print("replace")
        sprite_batch_set_sprite(sb, bgfx.indices[idx], bgfx.sprite, unpack(t))
        --sprite_batch_remove(sb, bgfx.indices[idx])
      end
      idx = idx + 1
    end
  )
end

function bgfx_refresh(bgfx)
  bgfx.sprite_batch:clear()
  bgfx.indices = {}
  for y, x in board_iterate() do
    bgfx_refresh_tile(bgfx, x, y)
  end
end

function bgfx_on_board_update(event)
  for key, bgfx in pairs(g_bgfx) do
    -- if only one tile changed, refresh only the given tiles and their neighbours
    if event.etype == K_BOARD_EVENT_SET and not event.during_board_resize then
      if bit.band(event.mask, bgfx.mask) ~= 0 then
        -- TODO / DEBUG: unclear why this "sparse update" logic fails.
        for yo, xo, v in array_2d_iterate(array_2d_grow(event.grid), -1) do
          if v ~= 0 then
            local x = xo + event.x
            local y = yo + event.y
            bgfx_refresh_tile(bgfx, x, y)
          end
        end

        -- bgfx_refresh(bgfx)
      end
    end

    -- full refresh
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

-- draws terrain features / walls
function board_draw()
  love.graphics.draw(g_bgfx.wall.sprite_batch)
  love.graphics.draw(g_bgfx.rubble.sprite_batch)
  if g_bgfx.rock then 
    love.graphics.draw(g_bgfx.rock.sprite_batch)
  end
  if g_bgfx.tree then 
    love.graphics.draw(g_bgfx.tree.sprite_batch)
  end
end

function board_draw_fog()
  love.graphics.push_opts()
  if g_debug_mode then
    love.graphics.setColor(1, 1, 1, 0.5)
  end
  love.graphics.draw(g_bgfx["fog"].sprite_batch)
  love.graphics.pop_opts()
end