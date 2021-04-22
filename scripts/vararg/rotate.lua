-- dont edit this file, it was generated

local tbl = require('plenary/tbl')

{% for n in range(2, amount) %}
  local function rotate{{n}}({% for n in range(n) %} A{{n}} {{ ", " if not loop.last else "" }} {% endfor %})
    return {% for n in range(1, n) %} A{{n}}, {% endfor %} A0
  end
{% endfor %}

local function rotate_n(first, ...)
  local args = tbl.pack(...)
  args[#args+1] = first
  return tbl.unpack(args)
end

local function rotate(...)
  local nargs = select('#', ...)

  if nargs == 1 then
    return ...
  end

  {% for n in range(2, amount) %}
    if nargs == {{n}} then
      return rotate{{n}}(...)
    end
  {% endfor %}

  return rotate_n(...)
end

return rotate
