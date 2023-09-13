-- board tile bits
K_WALL = 0x01
K_ROCK = 0x02
K_TREE = 0x04
K_DECAL = 0x10
K_STATIC = 0x100 -- "statics" (buildings, generally)
K_STATIC_OBSTRUCTION = 0x200
K_FOG_OF_WAR = 0x400
K_VARIANT = 0x800 -- for display randomness.
K_VARIANT2 = 0x1000 -- for extra display randomness.

-- combination masks
K_TILE_EMPTY = 0
K_FEATURE_MASK = 0xff
K_FEATURE_MASK_OBSTRUCTION = bit.bor(K_WALL, K_ROCK)
K_STATIC_ALL = bit.bor(K_STATIC, K_STATIC_OBSTRUCTION)
K_OBSTRUCTION = bit.bor(K_FEATURE_MASK_OBSTRUCTION, K_STATIC_OBSTRUCTION)
K_IMPATHABLE = bit.bor(K_OBSTRUCTION, K_TREE)
K_VARIANTS = bit.bor(K_VARIANT, K_VARIANT2)
K_REMOVE_IF_DESTROYED = bit.bor(K_STATIC, bit.bor(K_OBSTRUCTION, K_IMPATHABLE))

-- board event types
K_BOARD_EVENT_SET = 0 -- occurs when tile changes
K_BOARD_EVENT_RESIZE_BEGIN = 1
K_BOARD_EVENT_RESIZE_END = 2

local g_board_observers = {}

require("src.board_generate")

function board_init()
  g_state.board = {
    left = 0;
    right = 0;
    top = 0;
    bottom = 0;
    grid = {},
    temporary_edits = {}, -- list of {{x, y, mask, value}, ...} sets; temporarily modify these values of the board. (sparse.)
    path_dirty = true
  }

  g_state.rubble_decay_timer = 0

  g_board_observers = {}

  board_generate_init()

  board_update_bounds(0, g_state.initial_board_width, 0, g_state.initial_board_height)
end

function board_emit_event(opts)
  for _, observer in pairs(g_board_observers) do
    observer(opts)
  end
end

function board_tile_is_border(x, y)
  local board = g_state.board
  return x == board.left or x + 1 == board.right or y == board.top or y + 1 == board.bottom
end

function board_tile_in_bounds(x, y)
  local board = g_state.board
  return x < board.right and x >= board.left and y < board.bottom and y >= board.top
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

  -- notify observers
  board_emit_event({
    etype = K_BOARD_EVENT_RESIZE_BEGIN,
    left = left, right = right, top = top, bottom = bottom,
    pleft = pleft, pright = pright, ptop = ptop, pbottom = pbottom
  })

  -- adjust grid
  local updates = {}
  for y = math.min(ptop,top),math.max(pbottom, bottom) - 1 do
    if not in_range(y, top, bottom) and in_range(y, ptop, pbottom) then
      -- remove row
      board:remove(y)
    elseif in_range(y, top, bottom) then
      if not in_range(y, ptop, pbottom) then
        -- add row
        board.grid[y] = {}
        for x = left,right - 1 do
          local value = board_generate_tile(x, y)
          board.grid[y][x] = value
          table.insert(updates, {x, y, value})
        end
      else
        for x = math.min(left,pleft),math.max(right, pright) - 1 do
          if in_range(x, left, right) and not in_range(x, pleft, pright) then
            -- new tile
            local value = board_generate_tile(x, y)
            board.grid[y][x] = value
            table.insert(updates, {x, y, value})
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

  -- notify observers of new tiles
  for _, update in ipairs(updates) do
    -- TODO: combine updates into a single grid...
    board_emit_event({
      etype = K_BOARD_EVENT_SET,
      during_board_resize = true,
      x = update[1], y = update[2], grid = {{1}}, mask = bit.bnot(0), value = update[3],
    })
  end

  -- notify observers (that we're done now.)
  board_emit_event({
    etype = K_BOARD_EVENT_RESIZE_END,
    left = left, right = right, top = top, bottom = bottom,
    pleft = pleft, pright = pright, ptop = ptop, pbottom = pbottom
  })

  -- assert board perimeter still works
  if g_debug_mode then
    for i = 0,board_perimeter() - 1 do
      local x, y = board_perimeter_location(i)
      assert(board_location_perimeter(x, y) == i)
    end
  end

  board_refresh_pathing()
end

function board_iterate(board)
  board = board or g_state.board
  return function(state)
    local board = state.board
    if state.y >= board.bottom then
      return nil, nil, nil
    end
    local y = state.y
    local x = state.x
    local v = board_get_value(state.x, state.y)
    state.x = state.x + 1
    if state.x >= board.right then
      state.x = board.left
      state.y = state.y + 1
    end
    return y, x, v
  end, {board=board, x=board.left, y=board.top}, 0
end

function board_width()
  return g_state.board.right - g_state.board.left
end

function board_height()
  return g_state.board.bottom - g_state.board.top
end

function board_perimeter()
  return 2 * board_width() + 2 * board_height() - 4
end

-- returns x, y location of perimeter location
function board_perimeter_location(i)
  i = i % board_perimeter()
  local board = g_state.board
  if i < board_width() then
    return i, board.top
  end
  i = i - board_width() + 1
  if i < board_height() then
    return board.right - 1, board.top + i
  end
  i = i - board_height() + 1
  if i < board_width() then
    return board.right - i - 1, board.bottom - 1
  end
  i = i - board_width() + 1
  if i < board_height() then
    return board.left, board.bottom - i - 1
  end

  if g_debug_mode then
    assert(false)
  end

  -- paranoia
  return board.left, board.top
end

-- returns perimeter index of x, y location
function board_location_perimeter(x, y)
  local board = g_state.board
  assert(board_tile_is_border(x, y))
  if y == board.top then
    return x
  end
  if x == board.right - 1 then
    return board_width() + y - 1
  end
  if y == board.bottom - 1 then
    return board_width() + board_height() + (board_width() - x - 1) - 2
  end
  if x == board.left then
    return 2 * board_width() + board_height() + (board_height() - y - 1) - 3
  end

  if g_debug_mode then
    assert(false)
  end

  -- paranoia
  return 0
end

-- randomly remove rubble
function board_rubble_decay(dt)
  g_state.rubble_decay_timer = g_state.rubble_decay_timer + dt * 5
  while g_state.rubble_decay_timer > 0 do
    g_state.rubble_decay_timer = g_state.rubble_decay_timer - 1
    local x = math.random(g_state.board.left, g_state.board.right - 1)
    local y = math.random(g_state.board.top, g_state.board.bottom - 1)
    if bit.band(board_get_value(x, y, 0), K_FEATURE_MASK) == K_DECAL then
      board_emplace({
        x = x,
        y = y,
        force = true,
        mask = K_FEATURE_MASK,
        value = 0
      })
    end
  end
end

-- checks if the given position is surrounded on all sides by fog of war
-- r=1 distance to check for fog
-- mask=K_FOG_OF_WAR
function board_position_concealed(_x, _y, r, mask)
  r = r or 1
  mask = mask or K_FOG_OF_WAR
  for x = -r,r do
    for y = -r,r do
      if bit.band(board_get_value(_x + x, _y + y, mask), mask) == 0 then
        return false
      end
    end
  end

  return true
end

function board_draw_letterbox()
  -- draw black squares to crop map.
  -- draw 5 times with increasing thickness and transparency
  local m = 10000
  local board = g_state.board
  local num_borders = 10
  if g_is_lutro then
    num_borders = 3
  end
  for i = 0,num_borders-1 do
    local p = i/num_borders
    local px = k_dim_x * (p + 0.5/num_borders) * 0.8
    local py = k_dim_y * (p + 0.5/num_borders) * 0.8
    love.graphics.setColor(0, 0, 0, math.pow(1-p, 1.37))
    -- top
    love.graphics.rectangle("fill", board.left * k_dim_x - m, board.top * k_dim_y -m, m * 2 + board_width() * k_dim_x, m + py)
    -- left
    love.graphics.rectangle("fill", board.left * k_dim_x -m, board.top * k_dim_y, m + px, board_height() * k_dim_y)
    -- right
    love.graphics.rectangle("fill", board.right * k_dim_x - px, board.top * k_dim_y, m, board_height() * k_dim_y)
    -- bottom
    love.graphics.rectangle("fill", board.left * k_dim_x -m, board.bottom * k_dim_y - py, m * 2 + board_width() * k_dim_x, m)
    love.graphics.setColor(1, 1, 1)
  end
end

function board_get_value(x, y, default)
  local board = g_state.board
  if not board.grid[y] then
    return default
  end
  local v = board.grid[y][x]
  if v == nil then
    return default
  end

  -- check temporary edits
  for idx, edits in ipairs(board.temporary_edits) do
    for _, e in ipairs(edits) do
      local ex, ey, mask, value = unpack(e)
      if ex == x and ey == y then
        return bit.bor(bit.band(v, bit.bnot(mask)), bit.band(mask, value))
      end
    end
  end

  return v
end

-- writes values to the board, if they don't collide with another value.
-- returns true if successful, false if fails (a collision)
-- if 'all' is set, also returns number of obstructions
-- x, y: the top-left coordinate to write to the board at.
-- grid={{1}}: a 2d array of values. Every non-zero value will be written.
-- mask: required if both cmask and wmask are not provided. cmask and wmask are set to this.
-- cmask: if not nil, then only check and overwrite the masked bits of the board.
-- wmask: if not nil, then overwrite only these bits (rather than mask).
-- value: if not nil, then write this value instead of whatever is in the grid. Must be a subset of wmask. (Allows grid to be simple 0/1)
-- cvalue: if set, the existing value (masked by cmask) must equal this.
-- bounds: if set, then treat regions outside of the board as though they have this value. (default: cannot place outside board)
-- all: if set, only fail if all possible locations collide.
-- force: apply without checking
-- test: (private use) only compare, do not write.
function board_emplace(opts, test)
  local base_x = opts.x
  local base_y = opts.y
  local grid = opts.grid or make_2d_array(opts.w or 1, opts.h or 1, 1)
  local all = not not opts.all
  local any_free = false
  local n_obstructions = 0
  local cmask = d(opts.cmask, opts.mask, 0xffffffff) -- "compare mask"
  local wmask = tern(test, 0, d(opts.wmask, opts.mask)) -- "write mask"
  assert(wmask ~= nil, "wmask not set.")
  local value = opts.value or opts.wmask
  local cvalue = opts.cvalue or 0
  assert(test or value ~= nil, "value must be supplied")
  local bounds = opts.bounds
  if value ~= nil and not test then
    assert(bit.band(value, bit.bnot(wmask)) == 0, "wmask (" .. HEX(wmask) .. ") must be a superset of value (" .. HEX(value) .. ")")
  end
  local change_occurred = false
  grid = grid or {{1}}
  bounds = d(bounds, cmask)
  local board = g_state.board

  if not test and #board.temporary_edits > 0 then
    assert(false, "cannot place value on board if temporary board edits are in effect.")
  end

  -- do two passes:
  -- first pass is the "test" run. Check for collisions. (skip if opts.force)
  -- second pass is the "emplace" run. Write values. (skip if test)
  for pass = tern(opts.force ~= nil, 1, 0),tern(test == true, 0, 1) do
    for yo, xo, grid_value in array_2d_iterate(grid, 0) do
      local x = xo + base_x
      local y = yo + base_y
      local board_value = bounds
      on_board = false
      if x >= board.left and x < board.right and y >= board.top and y < board.bottom then
        on_board = true
        board_value = board_get_value(x, y)
      end

      local obstruction = bit.band(board_value, cmask) ~= cvalue and grid_value ~= 0

      if (pass == 0 or opts.force) and obstruction then
        if all then
          n_obstructions = n_obstructions + 1
        else
          n_obstructions = 1
        end
      end

      if pass == 0 then
        -- first pass: check for collisions
        if obstruction then
          if not all then
            return false, n_obstructions
          end
        elseif grid_value ~= 0 then
          any_free = true
        end
      elseif grid_value ~= 0 and on_board then
        -- second pass: write values
        if bit.band(value, K_OBSTRUCTION) then
          -- have to update pathfinder.
          board.path_dirty = true
        end
        local prev = board.grid[y][x]
        board.grid[y][x] = bit.bor(bit.band(board.grid[y][x], bit.bnot(wmask)), value)
        if prev ~= board.grid[y][x] then
          change_occurred = true
        end
      end
    end -- iterate board
    if all and pass == 0 and not any_free then
      -- fail.
      return false, n_obstructions
    end
  end -- iterate pass

  -- notify board observers of update
  if change_occurred then
    board_emit_event({
      etype = K_BOARD_EVENT_SET,
      during_board_resize = false,
      x = base_x, y = base_y, grid = grid, mask = wmask, value = value,
    })
  end

  -- success.
  return true, n_obstructions
end

-- checks if region would be free
function board_test_free(opts)
  return board_emplace(opts, true)
end

-- checks if region would be obstructed
function board_test_collides(opts)
  local free, amount = board_test_free(opts)
  return (not free), amount
end

function board_push_temporary_change_from_grid(x, y, grid, mask, value)
  assert(x and y and grid and mask)
  local a = {}
  for yo, xo, v in array_2d_iterate(grid, 0) do
    if v ~= 0 then
      table.insert(a, {x + xo, y + yo, mask, value or mask})
    end
  end
  board_push_temporary_change(a)
end

-- push array of {x, y, mask, value}
function board_push_temporary_change(tiles)
  -- edge case / early out
  if #tiles == 0 then
    return
  end

  g_state.board.path_dirty = true

  -- validate input
  for idx, change in ipairs(tiles) do
    local x, y, mask, value = unpack(change)
    assert(x and y and mask and value)
    assert(bit.band(bit.bnot(mask), value) == 0, "value must be subset of mask")
  end

  if type(tiles[1]) == "number" then
    tiles = {tiles}
  end

  table.insert(g_state.board.temporary_edits, tiles)
end

function board_pop_temporary_change()
  table.remove(g_state.board.temporary_edits, #g_state.board.temporary_edits)
end

function board_refresh_pathing()
  local board = g_state.board
  local grid = pf_get_grid_reference()
  assert(grid ~= nil)
  for y, x, v in board_iterate(board) do
    if bit.band(v, K_IMPATHABLE) ~= 0 then
      grid[y - board.top + 1][x - board.left + 1] = 1
    else
      grid[y - board.top + 1][x - board.left + 1] = 0
    end
  end

  board.path_dirty = false

  pf_update_from_grid()
end

function board_observe(fn)
  table.insert(g_board_observers, fn)
end

function board_pathfind(x, y, px, py)
  local board = g_state.board
  if board.path_dirty then
    board_refresh_pathing()
  end

  local path, length = pf_pathfind(x - board.left + 1, y - board.top + 1, px - board.left + 1, py - board.top + 1)
  -- convert path coordinates
  if path ~= nil then
    for idx, node in ipairs(path) do
      node.x = node.x + board.left - 1
      node.y = node.y + board.top - 1
    end
  end
  return path, length
end

-- Returns a list of points which are reachable from the given (x, y) coordinate
function board_floodfill(x, y, obstruction_mask)
  local visited = {}  -- Table to store visited coordinates
  local queue = {}    -- Queue for BFS
  local reachable = {}  -- Table to store reachable points

  -- Initialize
  table.insert(queue, {x = x, y = y})

  while #queue > 0 do
      local point = table.remove(queue, 1)
      local x, y = point.x, point.y
      
      if not visited[x] then
          visited[x] = {}
      end

      -- Check if the coordinate has already been visited
      if not visited[x][y] then
          -- Mark as visited
          visited[x][y] = true

          -- Check if the current cell is pathable
          if bit.band(board_get_value(x, y), 0xFF) == 0 then
              -- Add to reachable list
              reachable[#reachable+1] = {x=x, y=y}

              -- Check and enqueue neighboring cells
              for dx = -1, 1 do
                  for dy = -1, 1 do
                      if dx * dy == 0 and dx + dy ~= 0 then
                          local new_x, new_y = x + dx, y + dy

                          if not visited[new_x] then
                              visited[new_x] = {}
                          end

                          if not visited[new_x][new_y] then
                              table.insert(queue, {x = new_x, y = new_y})
                          end
                      end
                  end
              end
          end
      end
  end
  
  return reachable
end
