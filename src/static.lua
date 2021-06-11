-- static objects on board, such as buildings.

local g_next_static_id = 0

function static_init()
  g_state.statics = {
  }
end

function static_draw(static)
  draw_image_on_grid(static.image, static.x, static.y, static.w, static.h)
end

function static_draw_all()
  for _, static in pairs(g_state.statics) do
    static_draw(static)
  end
end

-- tests if a static can be placed and would not touch *any other static*
-- (set mask to K_OBSTRUCTION to check if it would collide with anything that obstructs.)
function static_test_emplace(opt, mask)
  local grid = make_2d_array(opt.w, opt.h, 1)
  return board_test({
    x=opt.x,
    y=opt.y,
    grid=grid,
    mask=d(mask,K_STATIC_ALL)
  })
end

-- inserts static, and returns id.
function static_emplace(opt)
  assert(opt ~= nil)
  local id = g_next_static_id

  local grid = d(opt.grid, make_2d_array(opt.w, opt.h, 1))

  local success = board_emplace({
    x=opt.x,
    y=opt.y,
    grid=grid,
    value=opt.collision_flags or K_STATIC_ALL,
    mask=K_STATIC_ALL
  })
  assert(success, "failed to emplace static -- did you check static_test_emplace first?")

  g_state.statics[id] = {
    x = opt.x,
    y = opt.y,
    w = opt.w,
    h = opt.h,
    image = g_images.castle,
    grid = grid,
    collision_flags = opt.collision_flags or K_STATIC_ALL,
    id = g_next_static_id
  }

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