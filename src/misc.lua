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
function draw_healthbar(x, y, width, height, hp, hpmax, hpdrain)

  local margin = 2

  love.graphics.push_opts()

  -- draw black rect
  love.graphics.setColor(0, 0, 0)
  love.graphics.rectangle("fill", x - width/2, y - height / 2, width, height)

  -- set color based on hp
  local p = {0, 1, 1, 1}
  if hpmax == 0 then
    p = {0, ibool(hp > 0), ibool(hpdrain > 0)}
  else
    p = {0, hp / hpmax, hpdrain / hpmax}
  end

  for i = 1,2 do
    if i == 1 then
      -- blendy color for hp
      love.graphics.setColor(hsv_to_rgb(
        p[2] / 3, 0.8, 0.9
      ))
    else
      -- hp drain red
      love.graphics.setColor(0.5, 0.1, 0.08)
    end

    love.graphics.rectangle(
      "fill",
      x - width/2 + margin + (width - 2 * margin) * p[i], y - height / 2 + margin - 1 + i,
      (width - 2 * margin) * math.max(0, p[i + 1] - p[i]), height - 2 * margin + 1 - i)
  end
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

function draw_concentric_circles(x, y, r1, r2, interval, offset, fade)
  local pr, pg, pb, pa = love.graphics.getColor()
  for r = (r1 + (offset % interval)),r2,interval do
    -- set alpha
    local p = (r - r1) / (r2 - r1)
    -- border fading
    local p_border = math.clamp((p - p * p) * 28, 0, 1)

    -- interior fading
    local p_interior = 1 - math.clamp((p - p * p) * 5, 0, 0.8)

    if fade then
      love.graphics.setColor(pr, pg, pb, pa * p_border * p_interior)
    end
    love.graphics.circle("line", x, y, r)
  end
  love.graphics.setColor(pr, pg, pb, pa)
end

function dpi()
  return love.graphics.getDPIScale()
end

local g_text_cache = {}
local g_text_cache_size = 0

function get_cached_text(font, string)

  -- brutal cache eviction policy
  -- TODO: improve
  if g_text_cache_size >= 1000 then
    g_text_cache_size = 0
    g_text_cache = {}
  end

  local fontkey = tostring(font)
  if not g_text_cache[fontkey] then
    g_text_cache[fontkey] = {}
  end
  if not g_text_cache[fontkey][string] then
    g_text_cache_size = g_text_cache_size + 1
    g_text_cache[fontkey][string] = love.graphics.newText(font, string)
  end
  return g_text_cache[fontkey][string]
end