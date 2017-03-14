-- require("foo")
-- print(pcall(require, "error"))
-- syntax error

local function trace3()
  -- local e = {}
  -- setmetatable(e, {__tostring = function() return "runtime error" end})
  error(e or "runtime error")
end

local function trace2()
  trace3()
end

local function trace1()
  trace2()
end

trace1()
