function svy_init()
  -- add castle.
  local castle_id = static_emplace({
    x = 12,
    y = 8,
    w = 2,
    h = 2,
    image = g_images.castle,
  })

  -- initialize sovereignty
  g_state.svy = {
    color = "purple",
    building_idxs = {castle_id},
    protectee_idxs = {castle_id},
    money = 70,
    hp = 20,
  }
end

-- for now, goal is just the first castle.
function svy_pathfind_to_goal(x, y)
  local svy = g_state.svy
  if #svy.protectee_idxs == 0 then
    return nil, nil
  end
  local protectee = static_get(svy.protectee_idxs[1])
  local px, py = protectee.x, protectee.y
  -- temporarily consider the goal to be pathable.
  board_push_temporary_change_from_grid(protectee.x, protectee.y, protectee.grid, K_OBSTRUCTION, 0)
  local path, length = board_pathfind(x, y, px, py)
  board_pop_temporary_change()
  return path, length
end

function svy_position_is_at_goal(x, y)
  for goal_idx in entries(g_state.svy.protectee_idxs) do
    local goal = static_get(goal_idx)
    if goal then
      for xo, yo in array_2d_iterate(goal.grid) do
        if x == xo + goal.x - 1 and y == yo + goal.y - 1 then
          return true
        end
      end
    end
  end

  return false
end

function svy_goal_reachable()
  local path, length = svy_pathfind_to_goal(0, 0)
  return path ~= nil
end

function svy_draw_overlay()
  love.graphics.setColor(1, 1, 0.5)
  local text = love.graphics.newText(g_font, "$" .. tostring(g_state.svy.money) .. "   HP:" .. tostring(g_state.svy.hp))
  love.graphics.draw(text, 0, 0)
  love.graphics.setColor(1, 1, 1)
end