-- allows lutro compatability
function love.graphics.getDPIScale() end

function love.graphics.getDimensions()
  return love.graphics.getWidth(), love.graphics.getHeight()
end