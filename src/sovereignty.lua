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
    protectee_idxs = {castle_id}
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
  board_push_temporary_pathable_from_grid(protectee.x, protectee.y, protectee.grid)
  local path, length = board_pathfind(x, y, px, py)
  board_pop_temporary_pathable()
  return path, length
end

function svy_goal_reachable()
  local path, length = svy_pathfind_to_goal(0, 0)
  return path ~= nil
end