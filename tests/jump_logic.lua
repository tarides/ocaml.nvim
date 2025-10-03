local pure = {}

-- state = {
--   cursor = <number>,             current line of the cursor
--   holes  = { <number>, ... },    sorted list of lines containing holes
--   cap    = <number>,             total number of lines in the buffer
-- }

function pure.jump(state, dir)
  local holes = state.holes
  local cursor = state.cursor

  if #holes == 0 then
    return state
  end

  if dir == "next" then
    for i = 1, #holes do
      if holes[i] > cursor then
        return { cursor = holes[i], holes = state.holes, cap = state.cap }
      end
    end
    return { cursor = holes[1], holes = state.holes, cap = state.cap }
  elseif dir == "prev" then
    for i = #holes, 1, -1 do
      if holes[i] < cursor then
        return { cursor = holes[i], holes = state.holes, cap = state.cap }
      end
    end
    return { cursor = holes[#holes], holes = state.holes, cap = state.cap }
  end
end

function mem(list, element)
  for _, e in ipairs(list) do
    if element == e then
      return true
    end
  end
  return false
end

function remove_element(list, element)
  for i, e in ipairs(list) do
    if element == e then
      return table.remove(list, i)
    end
  end
  return list
end

function pure.construct(state, input)
  local holes = state.holes
  local cursor = state.cursor
  if mem(holes, cursor) then
    if input == 1 then
      remove_element(holes, cursor)
      return {
        cursor = state.cursor,
        holes = holes,
        cap = state.cap,
      }
    end
  end
  return state
end

return pure
