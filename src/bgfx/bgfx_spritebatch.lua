-- spritebatch implementation of bg rendering
-- this is being phased out and replaced with canvas tile rendering

local function bgfx_get_sprite_batch_idx(bgfx, x, y)
  local board = g_state.board
  -- max is for paranoia.
  -- unsure why adding 1 is necessary but it seems to be extremely important.
  return math.max(0, tern(bgfx.subdivided, 4, 1) * (x - board.left + (y - board.top) * board_width())) + 1
end

local function bgfx_get_sprite_batch_sprite_count(bgfx)
  return (tern(bgfx.subdivided, 4, 1) * board_width() * board_height() + 1)
end

function bgfx_add(id, opts)
  opts.sprite_batch = love.graphics.newSpriteBatch(opts.sprite.spriteSheet, bgfx_get_sprite_batch_sprite_count(opts))
  opts.indices = {}
  opts.layer = opts.layer or BGFX_LAYER.base
  g_bgfx[id] = opts
  bgfx_refresh(g_bgfx[id])
end

-- add sprite to a sprite batch
local function sprite_batch_add_sprite(sprite_batch, sprite, t, x, y, r, sx, sy)
  return draw_sprite(sprite, t, x, y, r, sx, sy,
    function(image, ...)
      assert(image == sprite_batch:getTexture())
      return sprite_batch:add(...)
    end
  )
end

local function sprite_batch_set_sprite(sprite_batch, idx, sprite, t, x, y, r, sx, sy)
  return draw_sprite(sprite, t, x, y, r, sx, sy,
    function(image, ...)
      assert(image == sprite_batch:getTexture())
      assert(sprite_batch and idx and idx >= 0)
      return sprite_batch:set(idx, ...)
    end
  )
end

local function sprite_batch_remove(sprite_batch, idx)
  sprite_batch:set(idx, 0, 0, 0, 0, 0)
end

function bgfx_refresh_tile(bgfx, x, y)
  -- (pass-by-reference idx into function to allow updating it.)
  local idx = bgfx_get_sprite_batch_idx(bgfx, x, y)

  -- remove all the ones edited (we will re-add them later).
  -- OPTIMIZE: only remove the ones that should be removed.
  -- we can thereby not change the ones which needn't be changed.
  -- Note that in the current implementation, (*) below is never
  -- performed, since we remove tiles here.
  for jdx = idx,tern(bgfx.subdivided, idx+3, idx) do
    local i = bgfx.indices[jdx]
    if i then
      sprite_batch_remove(bgfx.sprite_batch, i)
    end
  end
  local bg_tile_fn = tern(bgfx.subdivided, bgfx_draw_subdivided_at, bgfx_draw_at)

  -- "draw the tile" -- actually, we just add it to the sprite batch
  -- using the drawing callback parameter to this function.
  bg_tile_fn(x, y, bgfx.sprite_batch, bgfx.subtile_fn or wall_get_subtile,
    function(sb, subimage, px, py)
      -- the tricky thing that this function is needed for is that
      -- we don't know sprite batch indices in advance, so we have to store them
      -- and look them up; we can't just index directly into the sprite batch according to
      -- the tile's x,y coordinate. Thus, bgfx.indices[] functions as a remapping (which
      -- resolves the problem).

      if bgfx.indices[idx] == nil then
        local i = sprite_batch_add_sprite(sb, bgfx.sprite, subimage, px, py)
        if g_debug_mode then
          assert(i) -- if this assertion is bothersome, it's not actually necessary.
        end
        bgfx.indices[idx] = i
      else
        -- (*) see comment about
        sprite_batch_set_sprite(sb, bgfx.indices[idx], bgfx.sprite, subimage, px, py)
        --sprite_batch_remove(sb, bgfx.indices[idx])
      end
      idx = idx + 1
      g_refresh_count = g_refresh_count + 1 -- for debugging statistics
    end
  )
end

function bgfx_draw_feature(layer)
  if layer then
    love.graphics.draw(layer.sprite_batch)
  end
end

function bgfx_refresh(bgfx)
  bgfx.sprite_batch:clear()
  bgfx.indices = {}
  for y, x in board_iterate() do
    bgfx_refresh_tile(bgfx, x, y)
  end
end