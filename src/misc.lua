local g_opts_stack = {}

-- pushes drawing options (color, etc.)
function love.graphics.push_opts()
  table.insert(g_opts_stack, {
    color = {love.graphics.getColor()}
  })
end

-- restores drawing options (color, etc.)
function love.graphics.pop_opts()
  local opts = table.remove(g_opts_stack)
  love.graphics.setColor(unpack(opts.color))
end

-- draws healthbar centred at the given coordinates.
function draw_healthbar(x, y, width, height, hp, hpmax)

  local margin = 2

  love.graphics.push_opts()

  -- draw black rect
  love.graphics.setColor(0, 0, 0)
  love.graphics.rectangle("fill", x - width/2, y - height / 2, width, height)

  -- set color based on hp
  local p = 1
  if hpmax == 0 then
    if hp <= 0 then
      p = 0
    end
  else
    p = hp / hpmax
  end
  love.graphics.setColor(hsv_to_rgb(
    p / 3, 0.8, 0.9
  ))
  love.graphics.rectangle("fill", x - width/2 + margin, y - height / 2 + margin, (width - 2 * margin) * p, height - 2 * margin)

  love.graphics.pop_opts()
end

function get_rotation_offset_for_animation(frames, dx, dy)
  assert(frames == 8, "only 8 is supported currently")
  -- TODO!
  if dx ~= 0 or dy ~= 0 then
    local angle = math.atan2(dy, dx) / math.tau
    if angle < 0 then
      angle = angle + 1
    end
    if in_range(angle, 11/16, 13/16) then
      return 0
    elseif in_range(angle, 13/16, 15/16) then
      return 1
    elseif angle >= 15/16 or angle < 1/16 then
      return 2
    elseif in_range(angle, 1/16, 3/16) then
      return 3
    elseif in_range(angle, 3/16, 5/16) then
      return 4
    elseif in_range(angle, 5/16, 7/16) then
      return 5
    elseif in_range(angle, 7/16, 9/16) then
      return 6
    elseif in_range(angle, 9/16, 11/16) then
      return 7
    end
  end
end