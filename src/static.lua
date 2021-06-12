-- static objects on board, such as buildings.

local g_next_static_id = 0

function static_init()
  g_state.statics = {
  }
end

function static_draw(static)
  if static.image then
    draw_image_on_grid(static.image, static.x, static.y, static.w, static.h)
  elseif static.sprite_data then
    for idx, sprite_data in ipairs(static.sprite_data) do
      local data = sprite_data
      draw_sprite(
        data.sprite, data.sprite_subimage,
        static.x * k_dim_x + data.sprite_offx,
        static.y * k_dim_y + data.sprite_offy,
        0,
        data.sprite_sx, data.sprite_sy
      )
    end
  elseif static.rectangle then
    local r = static.rectangle
    love.graphics.rectangle(r.mode, r.x, r.y, r.w, r.h)
  end
end

function static_draw_all()
  for _, static in pairs(g_state.statics) do
    static_draw(static)
  end
end

-- tests if a static can be placed and would not touch *any other static*
-- (set mask to K_OBSTRUCTION to check if it would collide with anything that obstructs.)
function static_test_emplace(opt, mask)
  local grid = opt.grid or make_2d_array(opt.w, opt.h, 1)
  return board_test_free({
    x=opt.x,
    y=opt.y,
    grid=grid,
    mask=bit.bor(d(mask,0), K_STATIC)
  })
end

-- inserts static, and returns id.
function static_emplace(opt)
  assert(opt ~= nil)
  assert(opt.x and opt.y and opt.w and opt.h)
  local id = g_next_static_id

  local grid = d(opt.grid, make_2d_array(opt.w, opt.h, 1))

  local success = board_emplace({
    x=opt.x,
    y=opt.y,
    grid=grid,
    value=opt.collision_flags or K_STATIC_ALL,
    cmask=K_STATIC,
    wmask=K_STATIC_ALL
  })
  assert(success, "failed to emplace static -- did you check static_test_emplace first?")

  local static =  {
    x = opt.x,
    y = opt.y,
    w = opt.w,
    h = opt.h,
    grid = grid,
    collision_flags = opt.collision_flags or K_STATIC_ALL,
    id = g_next_static_id
  }

  -- how to render this static

  if opt.image then
    static.image = opt.image
  elseif opt.sprites then
    static.sprite_data = {}
    for idx, s in ipairs(opt.sprites) do
      local data = {}
      assert(s)
      data.sprite = s.sprite
      data.sprite_offx = s.sprite_offx or 0
      data.sprite_offy = s.sprite_offy or 0
      data.sprite_sx = s.scale_x or 1
      data.sprite_sy = s.scale_y or 1
      data.sprite_subimage = s.sprite_image or 0
      table.insert(static.sprite_data, data)
    end
  else
    static.rectangle = {
      x=k_dim_x * opt.x + 4,
      y=k_dim_y * opt.y + 4,
      w=k_dim_x * (opt.w) - 8,
      h=k_dim_y * (opt.h) - 8,
      mode="line"
    }
  end

  g_state.statics[id] = static

  g_next_static_id = g_next_static_id + 1
  return id
end

function static_get(id)
  return g_state.statics[id]
end

function static_remove(id)
  local static = g_state.statics[id]
  if static ~= nil then
    -- remove static from board.
    board_emplace({
      x = static.x,
      y = static.y,
      grid = static.grid,
      mask = K_STATIC_ALL,
      value = 0
    })
    g_state.statics:remove(id)
  end
end