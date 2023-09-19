function new_sprite(image, width, height, offx, offy)
  if type(image) == "string" then
    image = love.graphics.newImage(image)
  end
  local animation = {}
  animation.height = height
  animation.width = width
  animation.spriteSheet = image;
  animation.subimages = 0
  animation.quads = {};

  for y = 0, image:getHeight() - height, height do
      for x = 0, image:getWidth() - width, width do
          table.insert(animation.quads, love.graphics.newQuad(x, y, width, height, image:getDimensions()))
          animation.subimages = animation.subimages + 1
      end
  end

  animation.offx = offx or 0
  animation.offy = offy or 0

  return animation
end

-- draws sprite at given frame.
-- if fn is set, draw using the given function instead.
function draw_sprite(sprite, t, x, y, r, sx, sy, fn)
  if sprite == nil then
    return
  end
  if t >= #sprite.quads then
    return
  end
  local spriteNum = (math.floor(t)) + 1
  sx = sx or 1
  sy = sy or 1
  r = r or 0
  fn = fn or love.graphics.draw
  -- TODO: use ox, oy (origin offset)
  return fn(sprite.spriteSheet, sprite.quads[spriteNum], x - sx * sprite.offx, y - sy * sprite.offy, r, sx, sy)
end

function draw_sprite_on_grid(sprite, t, gx, gy, gw, gh, fn)
  if sprite == nil or t >= #sprite.quads then
    return
  end
  
  gw = gw or 1
  gh = gh or 1
  
  local spriteNum = (math.floor(t)) + 1
  local quad = sprite.quads[spriteNum]
  local _, _, w, h = quad:getViewport()
  
  local sx = gw * k_dim_x / w
  local sy = gh * k_dim_y / h
  
  local x = gx * k_dim_x
  local y = gy * k_dim_y
  local r = 0
  
  fn = fn or love.graphics.draw
  love.graphics.draw(sprite.spriteSheet, quad, x - sx * sprite.offx, y - sy * sprite.offy, r, sx, sy)
end
