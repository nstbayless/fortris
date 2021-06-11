K_WALL_MASK = 0xff
K_WALL_MASK_OBSTRUCTION = 0x7f
K_STATIC = 0x100
K_STATIC_OBSTRUCTION = 0x200
K_STATIC_ALL = bit.bor(K_STATIC, K_STATIC_OBSTRUCTION)
K_OBSTRUCTION = bit.bor(K_WALL_MASK_OBSTRUCTION, K_STATIC_OBSTRUCTION)

function board_init()
  g_state.board = {
    left = 0;
    right = 0;
    top = 0;
    bottom = 0;
    grid = {},
    force_pathable = {}, -- list of {{x, y, pathable}...}; allow/forbid pathfinding through these tiles even if they are nonpathable.
    path_dirty = false
  }

  board_update_bounds(0, 32, 0, 16)
end

-- sets new bounds for the board, adding or removing tiles as needed.
-- refreshes pathing as well.
function board_update_bounds(left, right, top, bottom)
  local board = g_state.board

  -- previous values
  local pleft = board.left
  local pright = board.right
  local ptop = board.top
  local pbottom = board.bottom

  -- adjust grid

  for y = math.min(ptop,top),math.max(pbottom, bottom) - 1 do
    if not in_range(y, top, bottom) and in_range(y, ptop, pbottom) then
      -- remove row
      board:remove(y)
    elseif in_range(y, top, bottom) then
      if not in_range(y, ptop, pbottom) then
        -- add row
        board.grid[y] = {}
        for x = left,right - 1 do
          board.grid[y][x] = 0
        end
      else
        for x = math.min(left,pleft),math.max(right, pright) - 1 do
          if in_range(x, left, right) and not in_range(x, pleft, pright) then
            -- new tile
            board.grid[y][x] = 0
          elseif not in_range(x, left, right) and in_range(x, pleft, pright) then
            board.grid[y]:remove(x)
          end
        end
      end
    end
  end

   -- update bounds
   board.left = left
   board.right = right
   board.top = top
   board.bottom = bottom

   pf_reset(right - left, bottom - top)
   board_refresh_pathing()
end

function board_iterate(board)
  return function(state)
    local board = state.board
    if state.y >= board.bottom then
      return nil, nil, nil
    end
    local y = state.y
    local x = state.x
    local v = board.grid[state.y][state.x]
    state.x = state.x + 1
    if state.x >= board.right then
      state.x = board.left
      state.y = state.y + 1
    end
    return y, x, v
  end, {board=board, x=board.left, y=board.top}, 0
end

-- draws terrain features / walls
function board_draw()
  for y, x, v in board_iterate(g_state.board) do
    if v ~= 0 and bit.band(v, bit.bnot(K_WALL_MASK)) == 0 then
      local image = g_images.blocks[bit.band(v, K_WALL_MASK)]
      local w = image:getWidth()
      local h = image:getHeight()
      local sx = k_dim_x / w
      local sy = k_dim_y / h
      love.graphics.draw(image, x * k_dim_x, y * k_dim_y, 0, sx, sy)
    end
  end
end

-- writes values to the board, if they don't collide with another value.
-- returns true if successful, false if fails (a collision)
-- base_x, base_y: the top-left coordinate to write to the board at.
-- grid={{1}}: a 2d array of values. Every non-zero value will be written.
-- mask: required if both cmask and wmask are not provided. cmask and wmask are set to this.
-- cmask: if not nil, then only check and overwrite the masked bits of the board.
-- wmask: if not nil, then overwrite only these bits (rather than mask).
-- value: if not nil, then write this value instead of whatever is in the grid. Must be a subset of wmask. (Allows grid to be simple 0/1)
-- bounds: if set, then treat regions outside of the board as though they have this value. (default: cannot place outside board)
-- test: (private use) only compare, do not write.
function board_emplace(opts, test)
  local base_x = opts.x
  local base_y = opts.y
  local grid = opts.grid
  local cmask = d(opts.cmask, opts.mask, 0xffffffff) -- "compare mask"
  local wmask = tern(test, 0, d(opts.wmask, opts.mask)) -- "write mask"
  assert(wmask ~= nil, "wmask not set.")
  local value = opts.value
  local bounds = opts.bounds
  if value ~= nil and not test then
    assert(bit.band(value, bit.bnot(wmask)) == 0, "wmask (" .. HEX(wmask) .. ") must be a superset of value (" .. HEX(value) .. ")")
  end
  grid = grid or {{1}}
  bounds = d(bounds, cmask)
  local board = g_state.board
  -- do two passes:
  -- first pass is the "test" run. Check for collisions. (skip if opts.force)
  -- second pass is the "emplace" run. Write values. (skip if test)
  for pass = tern(opts.force ~= nil, 1, 0),tern(test == true, 0, 1) do
    for yo, row in ipairs(grid) do
      for xo, grid_value in ipairs(row) do
        local x = xo + base_x - 1
        local y = yo + base_y - 1
        local board_value = bounds
        on_board = false
        if x >= board.left and x < board.right and y >= board.top and y < board.bottom then
          on_board = true
          board_value = board.grid[y][x]
        end

        local obstruction = bit.band(board_value, cmask) ~= 0 and grid_value ~= 0

        if pass == 0 then
          -- first pass: check for collisions
          if obstruction then
            return false
          end
        elseif grid_value ~= 0 and on_board then
          -- second pass: write values
          local write_value = tern(value == nil, grid_value, value)
          if value == nil then
            assert(bit.band(value, bit.bnot(wmask)) == 0, "mask (" .. HEX(wmask) .. ") must be a superset of grid value (" .. HEX(write_value) .. ") -- note that 'value' arg is nil.")
          end
          if bit.band(write_value, K_OBSTRUCTION) then
            -- have to update pathfinder.
            board.path_dirty = true
          end
          board.grid[y][x] = bit.bor(bit.band(board.grid[y][x], bit.bnot(wmask)), write_value)
        end
      end
    end
  end

  return true
end

function board_test(opts)
  return board_emplace(opts, true)
end

function board_push_temporary_pathable_from_grid(x, y, grid, impathable)
  assert(grid ~= nil)
  local a = {}
  for yo, xo, v in array_2d_iterate(grid) do
    if v ~= 0 then
      table.insert(a, {x + xo - 1, y + yo - 1, impathable or 0})
    end
  end
  board_push_temporary_pathable(a)
end

function board_push_temporary_pathable(tiles)
  g_state.board.path_dirty = true
  if type(tiles[1]) == "number" then
    table.insert(g_state.board.force_pathable, {tiles})
  elseif type(tiles[1]) == "table" then
    table.insert(g_state.board.force_pathable, tiles)
  else
    assert(false)
  end
end

function board_pop_temporary_pathable()
  table.remove(g_state.board.force_pathable, #g_state.board.force_pathable)
end

function board_refresh_pathing()
  local board = g_state.board
  local grid = pf_get_grid_reference()
  assert(grid ~= nil)
  for y, x, v in board_iterate(board) do
    if bit.band(v, K_OBSTRUCTION) ~= 0 then
      grid[y - board.top + 1][x - board.left + 1] = 1
    else
      grid[y - board.top + 1][x - board.left + 1] = 0
    end
  end

  -- temporary pathfinding permit
  for _, b in ipairs(board.force_pathable) do
    for _, tile in ipairs(b) do
      grid[tile[2] - board.top + 1][tile[1] - board.left + 1] = tile[3] or 0
    end
  end

  board.path_dirty = false

  pf_update_from_grid()
end

function board_pathfind(x, y, px, py)
  local board = g_state.board
  if board.path_dirty then
    board_refresh_pathing()
  end

  return pf_pathfind(x - board.left + 1, y - board.top + 1, px - board.left + 1, py - board.top + 1)
end