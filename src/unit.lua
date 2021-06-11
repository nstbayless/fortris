K_ANIMATION_STAND = 0
K_ANIMATION_WALK = {}
K_ANIMATION_WALK[0] = 5
K_ANIMATION_WALK[1] = 10
K_ANIMATION_WALK[2] = 15
K_ANIMATION_WALK[3] = 20

-- dx, dy indicate facing.
function draw_unit_sprite(sprite, animation_name, dx, dy, timer, x, y, sx, sy)
  assert(sprite)
  local animation_base = 1
  if animation_name == "idle" then
    animation_base = K_ANIMATION_STAND
  end
  if animation_name == "walk" then
    animation_base = K_ANIMATION_WALK[math.floor(timer) % 4]
  end

  animation_angle_offset = 0
  animation_sx = 1
  if dx == 0 and dy == -1 then
    animation_angle_offset = 0
  elseif dx == 1 and dy == -1 then
    animation_angle_offset = 1
  elseif dx == 1 and dy == 0 then
    animation_angle_offset = 2
  elseif dx == 1 and dy == 1 then
    animation_angle_offset = 3
  elseif dx == 0 and dy == 1 then
    animation_angle_offset = 4
  elseif dx == -1 and dy == 1 then
    animation_angle_offset = 3
    animation_sx = -1
  elseif dx == -1 and dy == 0 then
    animation_angle_offset = 2
    animation_sx = -1
  elseif dx == -1 and dy == -1 then
    animation_angle_offset = -1
    animation_sx = -1
  end

  draw_sprite(sprite, animation_base + animation_angle_offset, x, y, 0, (sx or 1) * animation_sx, sy or 1)
end