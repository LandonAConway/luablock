local rules = {
	{x = 1, y = 0, z = 0},
	{x =-1, y = 0, z = 0},
	{x = 0, y = 1, z = 0},
	{x = 0, y =-1, z = 0},
	{x = 0, y = 0, z = 1},
	{x = 0, y = 0, z =-1},
}

minetest.register_node("luablock:luablock_digilines", {
    description = "Digilines Lua Block",
    tiles = {"luablock_digilines.png"},
    paramtype = "light",
    is_ground_content = false,
    groups = {cracky = 3, stone=2, oddly_breakable_by_hand = 3, not_in_creative_inventory = 1},
    
    digiline = {
      receptor = {},
      wire = {
        rules = rules,
      },
      effector = {
        action = function(pos,node,channel,msg)
          local meta = minetest.get_meta(pos)
          local setchannel = meta:get_string("channel")
          if channel ~= setchannel then return end
          if type(msg) ~= "string" and type(msg) ~= "table" then return end

          meta:set_string("error", "")

          --executes the code with the full environment. This can only be edited
          --by people with the 'luablock' priv.
          local env, t = luablock.digilines_execute_internal(pos)
          env = env or {}
          local code = ""
          if type(msg) == "string" then
            code = msg or ""
          else
            local _env = {}

            if type(msg.code) == "string" then code = msg.code
            elseif type(msg.func) == "string" then code = msg.func
            elseif type(msg[1]) == "string" then code = msg[1]
            elseif type(msg[2]) == "string" then code = msg[2] end

            if type(msg.environment) == "table" then _env = msg.environment
            elseif type(msg.env) == "table" then _env = msg.env
            elseif type(msg[1]) == "table" then _env = msg[1]
            elseif type(msg[2]) == "table" then _env = msg[2] end

            for k, v in pairs(_env) do
              env[k] = v
            end
          end
          if type(env) == "table" then
            --executes the code sent by digiline_send(...) with the environment returned by
            --luablock.digilines_execute_internal(...)
            luablock.digilines_execute_external(pos,code,env,t)
          end
        end,
      },
    },
    
    after_place_node = function(pos, placer, itemstack)
      local can_use = minetest.check_player_privs(placer:get_player_name(),{luablock=true})
      if not can_use then
        minetest.remove_node(pos)
        minetest.chat_send_player(placer:get_player_name(),"You do not have permission to place this node.")
      end
    end,

    can_dig = function(pos, player)
      local can_use = minetest.check_player_privs(player:get_player_name(),{luablock=true})
      if not can_use then
        minetest.chat_send_player(player:get_player_name(),"You do not have permission to dig this node.")
      end
      return can_use
    end,
    
    on_rightclick = function(pos, node, clicker, itemstack)
      local can_use = minetest.check_player_privs(clicker:get_player_name(),{luablock=true})
      local can_view = minetest.check_player_privs(clicker:get_player_name(),{luablock_view=true})
      if can_use then
        clicker:get_meta():set_string("luablock:pos",minetest.pos_to_string(pos))
        minetest.show_formspec(clicker:get_player_name(), "luablock:luablock_digilines_formspec", 
          luablock.digilines_formspec(pos))
      elseif can_view then
        minetest.show_formspec(clicker:get_player_name(), "luablick:luablock_view_formspec",
          luablock.formspec_view(pos))
      end
    end
})

function luablock.digilines_formspec(pos)
  local meta = minetest.get_meta(pos)
  local code = meta:get_string("code")
  local error = meta:get_string("error")
  local channel = meta:get_string("channel")

  local formspec = "formspec_version[5]"..
  "size[14,16]" ..
  "textarea[0.9,2.3;12,9.9;code;Code;"..minetest.formspec_escape(code).."]"..
  "button_exit[5,14.7;4,0.8;execute;Execute]"..
  "textarea[0.9,12.9;12,1.5;error;Error;"..minetest.formspec_escape(error).."]"..
  "textarea[0.9,0.9;12,0.7;channel;Channel;"..minetest.formspec_escape(channel).."]"

  return formspec
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
  if formname == "luablock:luablock_digilines_formspec" then
    local is_approved = minetest.check_player_privs(player:get_player_name(),{luablock=true})
    if is_approved then
      local meta = player:get_meta()
      local pos = minetest.string_to_pos(meta:get_string("luablock:pos"))
      local node = minetest.registered_nodes[minetest.get_node(pos).name]
      local node_meta = minetest.get_meta(pos)
      if fields.execute then
        node_meta:set_string("channel",fields.channel)
        node_meta:set_string("code",fields.code)
      end
    end
  end
end)

function luablock.digilines_execute_internal(pos)
  local execute = function(pos, _code)
    --environment
    local env = {}
    env.here = pos
    env.print = function(message)
      minetest.chat_send_all(message)
    end
    env.digiline_send = function(channel, msg)
      digiline:receptor_send(pos,rules,channel,msg)
    end
    setmetatable(env,{ __index = _G })
    setfenv(_code, env)
    
    --execute code
    return { environment = _code() }
  end

  local meta = minetest.get_meta(pos)
  local s_code = meta:get_string("code")
  local code, errMsg = loadstring(s_code);
  local success, result = pcall(execute,pos,code)

  if type(result) == "table" then
    return result.environment
  else
    meta:set_string("error", "internal error:"..result)
  end
end

--env1 is the environment that is given by the luablock. Comes from a full environment.
--env2 is the environment that is given by the player who uses digiline_send(...). Comes from a limited environment.
function luablock.digilines_execute_external(pos,code,env1,env2)
  local execute = function(pos, _code)
    --environment
    setmetatable(env1,env2 or {})
    setfenv(_code, env1)
    
    --execute code
    return { result = _code() }
  end

  local func, errMsg = loadstring(code);
  local success, result = pcall(execute,pos,func)

  if type(result) == "table" then
    return result.result
  else
    local meta = minetest.get_meta(pos)
    meta:set_string("error", "external error:"..result)
  end
end