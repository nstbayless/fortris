local Grid = require ("jumper.grid") -- The grid class
local Pathfinder = require ("jumper.pathfinder") -- The pathfinder lass

-- not properly init'd until "pf_reset" and "pf_update_from_grid" is called at least once.
function pf_init()
  g_state.pathing = {
    grid = nil,
    jgrid = nil,
    finder = nil,
  }
end

function pf_is_init()
  return g_state.pathing and g_state.pathing.jgrid and g_state.pathing.finder and true
end

function pf_assert_init()
  assert(pf_is_init(), "pathfinding libary not yet init'd")
end

-- clears grid and sets dimensions
function pf_reset(w, h)
  g_state.pathing.grid = make_2d_array(w, h, 0)
end

-- retrieves a reference to the grid, which can be modified -- but call 'pf_update_from_grid' after!
function pf_get_grid_reference()
  return g_state.pathing.grid
end

function pf_update_from_grid()
  local pathing = g_state.pathing
  pathing.jgrid = Grid(pathing.grid)
  pathing.finder = Pathfinder(pathing.jgrid, 'JPS', 0)
end

function pf_pathfind(x1, y1, x2, y2)
  local pathing = g_state.pathing
  return pathing.finder:getPath(x1, y1, x2, y2)
end