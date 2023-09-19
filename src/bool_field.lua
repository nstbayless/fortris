BoolField = {}
BoolField.__index = BoolField

-- constructor
function BoolField.new()
  local self = setmetatable({}, BoolField)
  self.data = {}
  return self
end

-- set method
function BoolField:set(x, y, value)
  if not self.data[x] then
    self.data[x] = {}
  end
  self.data[x][y] = value
end

-- get method
function BoolField:get(x, y)
  return self.data[x] and self.data[x][y] or false
end

function BoolField:getNeighbourhood9Type(x, y)
  local function b2i(b)
    return b and 1 or 0;
  end
  return b2i(self:get(x-1, y-1))
    + 2*b2i(self:get(x, y-1))
    + 4*b2i(self:get(x+1, y-1))
    + 8*b2i(self:get(x-1, y))
    + 16*b2i(self:get(x+1, y))
    + 32*b2i(self:get(x-1, y+1))
    + 64*b2i(self:get(x, y+1))
    + 128*b2i(self:get(x+1, y+1))
    + 256*b2i(not self:get(x, y))
end

function BoolField:getNeighbourhood5Type(x, y)
  local function b2i(b)
    return b and 1 or 0;
  end
  return b2i(self:get(x, y-1))
    + 2*b2i(self:get(x-1, y))
    + 4*b2i(self:get(x+1, y))
    + 8*b2i(self:get(x, y+1))
    + 16*b2i(not self:get(x, y))
end