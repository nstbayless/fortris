g_test = {
  mode = "random",
  time = 0,
}

-- called on new game
function test_init()
  
end

function test_update(dt)
  g_state.svy.hp = 10
  svy_gain_bounty(poisson(1, dt))
end

function test_get_key_down(key)
  if g_test.mode == "random" then
    if key == "up" or key == "down" or key == "left" or key == "right" then
      -- move faster when not placable in order to return to placable region more quickly
      if not g_state.placement_cache.placable then
        if g_state.placement_cache.implacable_reason == K_PLACEMENT_REASON_SHROUD then
          if (key == "down" and g_state.placement.y < g_state.spawny) or
            (key == "up" and g_state.placement.y > g_state.spawny) or
            (key == "right" and g_state.placement.x < g_state.spawnx) or
            (key == "left" and g_state.placement.x > g_state.spawnx) then
            return math.random() > 0.7
          end
        end
        return math.random() > 0.85
      end
    end
    return math.random() > 0.94
  end
end