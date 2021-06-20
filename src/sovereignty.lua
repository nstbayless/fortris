function svy_init()
  -- add castle.
  local castle_id = static_emplace({
    x = g_state.spawnx,
    y = g_state.spawny,
    w = 2,
    h = 2,
    image = g_images.castle,
    destroyable = false,
    fog_clear_radius = 3,
  })

  -- initialize sovereignty
  g_state.svy = {
    color = "purple",
    building_idxs = {castle_id},
    protectee_idxs = {castle_id},
    money = tern(g_debug_mode, 300, 36),
    moneycap = 100,
    hp = 10,
  }
end

function svy_gain_bounty(amount)
  if amount > 0 and g_state.svy.money < g_state.svy.moneycap then
    g_state.svy.money = g_state.svy.money + amount

    -- clamp
    g_state.svy.money = math.min(g_state.svy.money, g_state.svy.moneycap)

    -- TODO -- make this by observer.
    -- (placement cache depends on whether or not there are enough funds for the blocks)
    placement_set_dirty()
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

function svy_pathfind_to_goal(x, y, deterministic)
  deterministic = deterministic or false
  local svy = g_state.svy
  if #svy.protectee_idxs == 0 then
    return nil, nil
  end
  local protectee = static_get(svy.protectee_idxs[tern(deterministic, 1, math.random(#svy.protectee_idxs))])
  
  -- temporarily consider the goal to be pathable.
  board_push_temporary_change_from_grid(protectee.x, protectee.y, protectee.grid, K_IMPATHABLE, 0)

  -- path to a random location on it.
  local px, py = protectee.x + tern(deterministic, 0, math.random(0, protectee.w - 1)), protectee.y + tern(deterministic, 0, math.random(0, protectee.h - 1))
  local path, length = board_pathfind(x, y, px, py)
  board_pop_temporary_change()
  return path, length
end

-- returns coordinates of a random goal
function svy_get_any_goal_coordinates()
  for goal_idx in entries(shuffle(g_state.svy.protectee_idxs)) do
    local goal = static_get(goal_idx)
    if goal then
      return goal.x + math.random(0, goal.w - 1), goal.y + math.random(0, goal.h - 1)
    end
  end
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

-- checks if position is reachable
-- this function can change the 'preferred' source location,
-- which is only intended as a cached value anyway (for comparison in this function only).
function svy_goal_reachable()
  local svy = g_state.svy

  local x, y = board_get_source()
  local init_x, init_y = x, y
  assert(x and y)
  local source_changed = false

  -- this will fail if map expansion becomes enabled.
  -- think very carefully about how to ensure a reachable border tile when expanding the map.
  assert(board_tile_is_border(x, y))

  -- if the first position we try fails, scan additional positions.
  -- TODO: optimize. Check only particular regions...
  local scan_order = shuffle(iota(0, board_perimeter() - 1))
  do
    local perimeter_idx = board_location_perimeter(x, y)
    local startidx = indexof(scan_order, perimeter_idx)
    if perimeter_idx and startidx ~= nil then -- realistically, we should assert these. But crash-paranoia...
      table.swap(scan_order, 1, startidx) -- ensure we first check the expected location.

      -- validate that perimeter-location matches location-perimeter
      if g_debug_mode then
        local _x, _y = board_perimeter_location(perimeter_idx)
        assert(_x == x and _y == y)
      end
    elseif g_debug_mode then
      assert(false)
    end
  end

  local checked = {}

  -- find path
  local path, length = nil, nil
  for _, i in ipairs(scan_order) do
    if not checked[i] then
      x, y = board_perimeter_location(i)
      if bit.band(board_get_value(x, y, 0), K_IMPATHABLE) == 0 then
        path, length = svy_pathfind_to_goal(x, y)
      end
      if path then
        break
      else
        source_changed = true

        -- mark off as many values as we can as impathable.
        for d = -1,1 do
          if d ~=0 then
            for j = 0, 100 do
              local _x, _y = board_perimeter_location(i + j * d)
              if g_debug_mode and j == 0 then
                assert(_x == x and _y == y)
              end
              if bit.band(board_get_value(_x, _y, 0), K_IMPATHABLE) == 0 then
                -- technically we don't need to recompute location-perimeter, we could just use arithmetic.
                -- this is paranoia.
                checked[board_location_perimeter(_x, _y)] = true
              else
                break
              end
            end
          end
        end

      end
    end
  end

  -- update source
  if path ~= nil and source_changed then
    print("source updated. ", init_x, init_y, "->", x, y)
    board_set_source(x, y)
  end
  return path ~= nil
end

function svy_draw_spiel()
  assert(g_state.spiel_x and g_state.spiel_y)

  if g_debug_mode then
    return
  end

  love.graphics.setColor(1, 1, 0.5)
  local s = ""
  if g_state.spawn_timer <= 10 or (g_state.placement_rotation_count < 4 and g_state.spawn_timer <= 92) then
    s = s .. "Defend your Fortress!\n"
  end
  if g_state.spawn_timer <= 5 then
    s = s .. "Controls:\n  Arrow Keys -> Move\n  A, S -> Rotate\n  Space -> Place\n"
  elseif g_state.spawn_timer <= 90 and g_state.placement_rotation_count < 4 then
    s = s .. "Controls:\n  A and S -> Rotate\n"
  end
  if g_state.game_over then
    s = ""
  end
  if s ~= "" then
    local text = get_cached_text(g_font, s:trim())

    -- shift spiel if needed
    -- TODO: move this to update.
    local shift = false
    local r = 3
    for x = -r,r,r do
      for y = -r,r,r do
        if bit.band(board_get_value(math.round(g_state.spiel_x + x), math.round(g_state.spiel_y + y), K_FOG_OF_WAR), K_FOG_OF_WAR) == 0 then
          shift = true
          break
        end
      end
    end

    if shift then
      g_state.spiel_x = g_state.spiel_x + g_state.spiel_shift_dir * 0.25
    end

    if g_state.spiel_x <= g_state.board.left + 3 or g_state.spiel_x >= g_state.board.right - 3 then
       return
    end

    love.graphics.draw(text, k_dim_x * g_state.spiel_x - text:getWidth() / 2, k_dim_y * g_state.spiel_y - 50)
  end
end

function svy_draw_overlay()
  love.graphics.setColor(1, 1, 0.5)

  -- hp and $
  if g_state.game_over then
    local s = "Game Over. Press Space to restart.\n"

    local timer = g_state.spawn_timer - tern(g_state.game_over_timer < K_GAME_OVER_STOP_TIME + 1, 1, 0)
    s = s .. tostring(g_state.kills) .. tern(g_state.kills == 1, " invader", " invaders")
    s = s .. " thwarted in " .. disp_time(math.floor(g_state.spawn_timer))

    local text = get_cached_text(g_font, s)
    
    love.graphics.draw(text, 4, 4)
  else
    local s = "Treasury:$" .. tostring(g_state.svy.money) .. tern(g_state.svy.money < g_state.svy.moneycap, "", " [Limit!]")
    local text = get_cached_text(g_font, s)
    love.graphics.draw(text, 4, 4)
    text = get_cached_text(g_font, "Fortress:" .. tostring(g_state.svy.hp))
    love.graphics.draw(text, 4, 30)
    s = s .. "Fortress:" .. tostring(g_state.svy.hp)
  end

  if g_state.spawn_timer <= 2 or g_state.game_over_timer >= 14.5 then
    love.graphics.printf(k_version, g_font, 0, 0, love.graphics.getWidth() - 4, "right")
  end

  love.graphics.setColor(1, 1, 1)
end