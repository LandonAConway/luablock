local rules = {
	{x = 1, y = 0, z = 0},
	{x =-1, y = 0, z = 0},
	{x = 0, y = 1, z = 0},
	{x = 0, y =-1, z = 0},
	{x = 0, y = 0, z = 1},
	{x = 0, y = 0, z =-1},
}

minetest.register_abm({
  label = "luablock_receptor",
  nodenames = {"luablock:luablock_receptor_off", "luablock:luablock_receptor_on"},
  interval = 0.1,
  chance = 1,
  action = function(pos)
    local meta = minetest.get_meta(pos)
    local s_code = meta:get_string("code")
    local code, errMsg = loadstring(s_code);
    local success, err = pcall(luablock.execute,pos,code,"receptor")
    meta:set_string("error",errMsg or err)
  end
})

minetest.register_abm({
  label = "luablock_effector",
  nodenames = {"luablock:luablock_effector_off", "luablock:luablock_effector_on"},
  interval = 0.1,
  chance = 1,
  action = function(pos)
    local node_name = minetest.get_node(pos).name
    local meta = minetest.get_meta(pos)
    local allow_execute = false
    if meta:get_string("node_name") ~= node_name then
      allow_execute = true
    end
    if meta:get_string("execute_on_globalstep") == "true" then
      allow_execute = true
    end

    if allow_execute then
      local s_code = meta:get_string("code")
      local code, errMsg = loadstring(s_code);
      local success, err = pcall(luablock.execute,pos,code,"effector")
      meta:set_string("error",errMsg or err)
      meta:set_string("node_name", node_name)
    end
  end
})

minetest.register_abm({
  label = "luablock_conductor",
  nodenames = {"luablock:luablock_conductor_off", "luablock:luablock_conductor_on"},
  interval = 0.1,
  chance = 1,
  action = function(pos)
    local node_name = minetest.get_node(pos).name
    local meta = minetest.get_meta(pos)
    local allow_execute = false
    if meta:get_string("node_name") ~= node_name then
      allow_execute = true
    end
    if meta:get_string("execute_on_globalstep") == "true" then
      allow_execute = true
    end

    if allow_execute then
      local s_code = meta:get_string("code")
      local code, errMsg = loadstring(s_code);
      local success, err = pcall(luablock.execute,pos,code,"conductor")
      meta:set_string("error",errMsg or err)
      meta:set_string("node_name", node_name)
    end
  end
})

minetest.register_node("luablock:luablock_receptor_off", {
    description = "Lua Block (Receptor)",
    tiles = {"luablock_off.png"},
    paramtype = "light",
    is_ground_content = false,
    groups = {cracky = 3, stone=2, oddly_breakable_by_hand = 3, not_in_creative_inventory = 1},
    default_execute_on_globalstep = "true",
    
    mesecons = {receptor = {
      state = mesecon.state.off,
      rules = rules
    }},
    
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
          minetest.show_formspec(clicker:get_player_name(), "luablock:luablock_formspec", luablock.formspec(pos,
            true))
        elseif can_view then
          minetest.show_formspec(clicker:get_player_name(), "luablick:luablock_view_formspec",
            luablock.formspec_view(pos))
        end
    end,
})

minetest.register_node("luablock:luablock_receptor_on", {
    description = "Lua Block (Receptor)",
    tiles = {"luablock_on.png"},
    paramtype = "light",
    light_source = 14,
    is_ground_content = false,
    drop = {
      items = { { items = {'luablock:luablock_receptor_off'} } }
    },
    groups = {cracky = 3, stone=2, oddly_breakable_by_hand = 3, not_in_creative_inventory = 1},
    default_execute_on_globalstep = "true",
    
    mesecons = {receptor = {
      state = mesecon.state.on,
      rules = rules
    }},
    
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
          minetest.show_formspec(clicker:get_player_name(), "luablock:luablock_formspec", luablock.formspec(pos,
            true))
        elseif can_view then
          minetest.show_formspec(clicker:get_player_name(), "luablick:luablock_view_formspec",
            luablock.formspec_view(pos))
        end
    end,
})

minetest.register_node("luablock:luablock_effector_off", {
    description = "Lua Block (Effector)",
    tiles = {"luablock_off.png"},
    paramtype = "light",
    is_ground_content = false,
    groups = {cracky = 3, stone=2, oddly_breakable_by_hand = 3, not_in_creative_inventory = 1},
    default_execute_on_globalstep = "false",
    
    mesecons = {effector = {
      rules = rules,
      action_on = function (pos, node)
        minetest.swap_node(pos, {name = "luablock:luablock_effector_on"})
      end,
    }},
    
    after_place_node = function(pos, placer, itemstack)
      local can_use = minetest.check_player_privs(placer:get_player_name(),{luablock=true})
      if not can_use then
        minetest.remove_node(pos)
        minetest.chat_send_player(placer:get_player_name(),"You do not have permission to place this node.")
      else
        minetest.get_meta(pos):set_string("execute_on_globalstep", "false")
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
          minetest.show_formspec(clicker:get_player_name(), "luablock:luablock_formspec", luablock.formspec(pos,
            false))
        elseif can_view then
          minetest.show_formspec(clicker:get_player_name(), "luablick:luablock_view_formspec",
            luablock.formspec_view(pos))
        end
    end,
})

minetest.register_node("luablock:luablock_effector_on", {
    description = "Lua Block (Effector)",
    tiles = {"luablock_on.png"},
    paramtype = "light",
    light_source = 14,
    is_ground_content = false,
    drop = {
      items = { { items = {'luablock:luablock_effector_off'} } }
    },
    groups = {cracky = 3, stone=2, oddly_breakable_by_hand = 3, not_in_creative_inventory = 1},
    default_execute_on_globalstep = "false",
    
    mesecons = {effector = {
      rules = rules,
      action_off = function (pos, node)
        minetest.swap_node(pos, {name = "luablock:luablock_effector_off"})
      end,
    }},
    
    after_place_node = function(pos, placer, itemstack)
      local can_use = minetest.check_player_privs(placer:get_player_name(),{server=true})
      if not can_use then
        minetest.remove_node(pos)
        minetest.chat_send_player(placer:get_player_name(),"You do not have permission to place this node.")
      else
        minetest.get_meta(pos):set_string("execute_on_globalstep", "false")
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
        local can_use = minetest.check_player_privs(clicker:get_player_name(),{server=true})
        local can_view = minetest.check_player_privs(clicker:get_player_name(),{luablock_view=true})
        if can_use then
          clicker:get_meta():set_string("luablock:pos",minetest.pos_to_string(pos))
          minetest.show_formspec(clicker:get_player_name(), "luablock:luablock_formspec", luablock.formspec(pos,
            false))
        elseif can_view then
          minetest.show_formspec(clicker:get_player_name(), "luablick:luablock_view_formspec",
            luablock.formspec_view(pos))
        end
    end,
})

minetest.register_node("luablock:luablock_conductor_off", {
    description = "Lua Block (Conductor)",
    tiles = {"luablock_off.png"},
    paramtype = "light",
    is_ground_content = false,
    groups = {cracky = 3, stone=2, oddly_breakable_by_hand = 3, not_in_creative_inventory = 1},
    default_execute_on_globalstep = "false",
    
    mesecons = {conductor = {
      state = mesecon.state.off,
      onstate = "luablock:luablock_conductor_on",
      offstate = "luablock:luablock_conductor_off",
      rules = rules
    }},
    
    after_place_node = function(pos, placer, itemstack)
      local can_use = minetest.check_player_privs(placer:get_player_name(),{server=true})
      if not can_use then
        minetest.remove_node(pos)
        minetest.chat_send_player(placer:get_player_name(),"You do not have permission to place this node.")
      else
        minetest.get_meta(pos):set_string("execute_on_globalstep", "false")
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
        local can_use = minetest.check_player_privs(clicker:get_player_name(),{server=true})
        local can_view = minetest.check_player_privs(clicker:get_player_name(),{luablock_view=true})
        if can_use then
          clicker:get_meta():set_string("luablock:pos",minetest.pos_to_string(pos))
          minetest.show_formspec(clicker:get_player_name(), "luablock:luablock_formspec", luablock.formspec(pos,
            false))
        elseif can_view then
          minetest.show_formspec(clicker:get_player_name(), "luablick:luablock_view_formspec",
            luablock.formspec_view(pos))
        end
    end,
})

minetest.register_node("luablock:luablock_conductor_on", {
    description = "Lua Block (Conductor)",
    tiles = {"luablock_on.png"},
    paramtype = "light",
    light_source = 14,
    is_ground_content = false,
    drop = {
      items = { { items = {'luablock:luablock_conductor_off'} } }
    },
    groups = {cracky = 3, stone=2, oddly_breakable_by_hand = 3, not_in_creative_inventory = 1},
    default_execute_on_globalstep = "false",
    
    mesecons = {conductor = {
      state = mesecon.state.on,
      onstate = "luablock:luablock_conductor_on",
      offstate = "luablock:luablock_conductor_off",
      rules = rules
    }},
    
    after_place_node = function(pos, placer, itemstack)
      local can_use = minetest.check_player_privs(placer:get_player_name(),{server=true})
      if not can_use then
        minetest.remove_node(pos)
        minetest.chat_send_player(placer:get_player_name(),"You do not have permission to place this node.")
      else
        minetest.get_meta(pos):set_string("execute_on_globalstep", "false")
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
        local can_use = minetest.check_player_privs(clicker:get_player_name(),{server=true})
        local can_view = minetest.check_player_privs(clicker:get_player_name(),{luablock_view=true})
        if can_use then
          clicker:get_meta():set_string("luablock:pos",minetest.pos_to_string(pos))
          minetest.show_formspec(clicker:get_player_name(), "luablock:luablock_formspec", luablock.formspec(pos,
            false))
        elseif can_view then
          minetest.show_formspec(clicker:get_player_name(), "luablick:luablock_view_formspec",
            luablock.formspec_view(pos))
        end
    end,
})

function luablock.execute(pos,code,type)
  local env = luablock.create_env(pos)
  setfenv(code,env)
  local result = code()
  local code = minetest.get_meta(pos):get_string("code")
  local error = minetest.get_meta(pos):get_string("error")
  if type == "receptor" then
    if result then
      minetest.set_node(pos,{name="luablock:luablock_receptor_on"})
      minetest.get_meta(pos):set_string("code",code)
      minetest.get_meta(pos):set_string("error",error)
      mesecon.receptor_on(pos,mesecon.rules.default)
    else
      minetest.set_node(pos,{name="luablock:luablock_receptor_off"})
      minetest.get_meta(pos):set_string("code",code)
      minetest.get_meta(pos):set_string("error",error)
      mesecon.receptor_off(pos,mesecon.rules.default)
    end
  end
end

--create global table _luablock so it can be used in the environment
_luablock = {}
function luablock.create_env(pos)
  local is_on = luablock.is_on(pos)
  local env = {}
  env.here = pos
  env.state = {}
  env.state.on = is_on
  env.state.off = not is_on
  env.print = function(message)
    minetest.chat_send_all(message)
  end
  setmetatable(env,{ __index = _G })
  return env
end

function luablock.is_on(pos)
  local node = minetest.get_node(pos)
  if node.name == "luablock:luablock_receptor_on" or node.name == "luablock:luablock_effector_on" or node.name == "luablock:luablock_conductor_on" then
    return true
  end
  return false
end

-- formspec_version[4]
-- size[14,16]
-- textarea[0.9,0.9;12,11.3;code;Code;]
-- button_exit[5,14.7;4,0.8;execute;Execute]
-- textarea[0.9,12.9;12,1.5;error;Error;]

-- formspec_version[4]
-- size[14,16]
-- textarea[0.9,1.6;12,10.6;code;Code;]
-- button_exit[5,14.7;4,0.8;execute;Execute]
-- textarea[0.9,12.9;12,1.5;error;Error;]
-- checkbox[0.9,0.7;execute_on_globalstep;Execute on Globalstep;false]

function luablock.formspec(pos, globalstep_only)
  local meta = minetest.get_meta(pos)
  local code = meta:get_string("code")
  local error = meta:get_string("error")
  local execute_on_globalstep = meta:get_string("execute_on_globalstep")
  if execute_on_globalstep == "" then
    execute_on_globalstep = minetest.registered_nodes[minetest.get_node(pos).name].default_execute_on_globalstep
  end

  local formspec_globalstep_only = "formspec_version[4]"..
    "size[14,16]"..
    "textarea[0.9,0.9;12,11.3;code;Code;"..minetest.formspec_escape(code).."]"..
    "button_exit[5,14.7;4,0.8;execute;Execute]"..
    "textarea[0.9,12.9;12,1.5;error;Error;"..minetest.formspec_escape(error).."]"
    
  local formspec = "formspec_version[4]"..
  "size[14,16]"..
  "textarea[0.9,1.6;12,10.6;code;Code;"..minetest.formspec_escape(code).."]"..
  "button_exit[5,14.7;4,0.8;execute;Execute]"..
  "textarea[0.9,12.9;12,1.5;error;Error;"..minetest.formspec_escape(error).."]"..
  "checkbox[0.9,0.7;execute_on_globalstep;Execute on Globalstep;"..
    execute_on_globalstep.."]"
    
  if globalstep_only then
    return formspec_globalstep_only
  end
  return formspec
end

function luablock.formspec_view(pos)
  local meta = minetest.get_meta(pos)
  local code = meta:get_string("code")
  local formspec = "formspec_version[5]" ..
  "size[14,16]" ..
  "textarea[0.9,0.9;12,14.6;code;Code;"..minetest.formspec_escape(code).."]"
  return formspec
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
  if formname == "luablock:luablock_formspec" then
    local is_approved = minetest.check_player_privs(player:get_player_name(),{luablock=true})
    if is_approved then
      local meta = player:get_meta()
      local pos = minetest.string_to_pos(meta:get_string("luablock:pos"))
      local node = minetest.registered_nodes[minetest.get_node(pos).name]
      local node_meta = minetest.get_meta(pos)
      if fields.execute then
        node_meta:set_string("code",fields.code)
      elseif fields.execute_on_globalstep then
        node_meta:set_string("execute_on_globalstep",fields.execute_on_globalstep)
      end
    end
  end
end)