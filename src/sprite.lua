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

function draw_sprite(animation, t, x, y, r, sx, sy)
  if animation == nil then
    return
  end
  local spriteNum = (math.floor(t) % #animation.quads) + 1
  sx = sx or 1
  sy = sy or 1
  r = r or 0
  love.graphics.draw(animation.spriteSheet, animation.quads[spriteNum], x - sx * animation.offx, y - sy * animation.offy, r, sx, sy)
end