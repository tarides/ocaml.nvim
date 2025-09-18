local jump_test = {}

  local ocaml = require("ocaml")
  local logic = require("jump_logic")
  local assert = require("luassert")

  function get_line()
    return vim.api.nvim_win_get_cursor(0)[1]
  end

  local stats = { 0, 0, 0 }
  function pp_stats()
    print("\nCommand execution counts :")
    print("\tJumpPrevHole count : " .. stats[1])
    print("\tJumpNextHole count : " .. stats[2])
    print("\tConstruct count : " .. stats[3])
  end

  local pull = {
    function(state, _)
      local ns = logic.jump(state, "prev")
      ocaml.jump_to_hole("prev")
      stats[1] = stats[1] + 1
      return ns
    end,
    function(state, _)
      local ns = logic.jump(state, "next")
      ocaml.jump_to_hole("next")
      stats[2] = stats[2] + 1
      return ns
    end,
    function(state, input)
      local ns = logic.construct(state, input)
      ocaml.construct(input)
      stats[3] = stats[3] + 1
      return ns
    end,
  }

  function run(state, seed, steps)
    math.randomseed(seed)
    function iter(s, n)
      if n == steps then return end
      local r = math.random(#pull)
      local input = math.random(2)
      local ns = pull[r](s, input)
      local pl_cursor = get_line()
      assert.are.equal(pl_cursor, ns.cursor)
      iter(ns, n + 1)
    end
    iter(state, 0)
  end

  function jump_test.runtest(bufnr, seed, steps)
    local initial_state = {
      cursor = 1,
      holes = {5, 6, 7, 11, 12, 13},
      cap = vim.api.nvim_buf_line_count(bufnr)
    }
    run(initial_state, seed, steps)
    pp_stats()
  end

return jump_test
