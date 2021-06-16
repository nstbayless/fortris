function svy_init()
  -- add castle.
  local castle_id = static_emplace({
    x = g_state.spawnx,
    y = g_state.spawny,
    w = 2,
    h = 2,
    image = g_images.castle,
    fog_clear_radius = 4,
  })

  -- initialize sovereignty
  g_state.svy = {
    color = "purple",
    building_idxs = {castle_id},
    protectee_idxs = {castle_id},
    money = 36,
    hp = 10,
  }
end

function svy_gain_bounty(amount)
  if amount > 0 then
    g_state.svy.money = g_state.svy.money + amount

    -- TODO -- make this by observer.
    -- (placement cache depends on whether or not there are enough funds for the blocks)
    g_state.placement_cache.dirty = true
  end
end

function svy_lose_hp(amount)
  amount = amount or 1
  g_state.svy.hp = g_state.svy.hp - amount
  camera_apply_shake(0.2, 2, 3)
  if g_state.svy.hp <= 0 then
    g_state.game_over = true
  end
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
      for yo, xo in array_2d_iterate(goal.grid, 0) do
        if x == xo + goal.x and y == yo + goal.y then
          return true
        end
      end
    end
  end

  return false
end

function svy_goal_reachable()
  local x, y = board_get_source()
  local path, length = svy_pathfind_to_goal(x, y)
  return path ~= nil
end

function svy_draw_overlay()
  love.graphics.setColor(1, 1, 0.5)
  local s = "$" .. tostring(g_state.svy.money) .. "   HP:" .. tostring(g_state.svy.hp)
  if g_state.spawn_timer <= 5 then
    s = s .. "\nControls:\n  Arrow keys -> move\n  A and S -> rotate\n  Space -> place"
  end
  if g_state.game_over then
    s = "Game Over. Press Space to restart."
  end
  local text = love.graphics.newText(g_font, s)
  love.graphics.draw(text, 0, 0)
  love.graphics.setColor(1, 1, 1)
end