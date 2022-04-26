--Digiline Rules--
------------------
--This is a global variable and is used in the section below, so it must be created on top.
local rules = {
	{x = 1, y = 0, z = 0},
	{x =-1, y = 0, z = 0},
	{x = 0, y = 1, z = 0},
	{x = 0, y =-1, z = 0},
	{x = 0, y = 0, z = 1},
	{x = 0, y = 0, z =-1},
}

--Luablock Code--
-----------------
local luablock_messages = {}

local luablock_send = function(pos, channel, msg)
  local random = 0
  repeat
    random = math.random(1, 1000000)
  until not luablock_messages["uid"..random]

  local uid = "uid"..random
  luablock_messages[uid] = msg

  digiline:receptor_send(pos,rules,channel,{ type="luablock_msg", uid=uid })
end

local luablock_recieve = function(uid)
  local msg = luablock_messages[uid]
  if msg then
    luablock_messages[uid] = nil
    return msg
  end
end

--expose luablock_send
luablock.luablock_send = luablock_send

local load_memory = function(pos)
  local meta = minetest.get_meta(pos)
  return minetest.deserialize(meta:get_string("memory")) or {}
end

local save_memory = function(pos, memory)
  local meta = minetest.get_meta(pos)
  meta:set_string("memory", minetest.serialize(memory))
end

--This code handles the callbacks for the node's inventory and timer
luablock.callbacks = {}

local register_luablock_callback = function(pos, name, func)
  local _pos = minetest.pos_to_string(pos)
  luablock.callbacks[_pos] = luablock.callbacks[_pos] or {}
  if type(func) ~= "function" then
    func = nil
  end
  luablock.callbacks[_pos][name] = func
end

local call_luablock_callback = function(pos, name, ...)
  local callback = luablock.callbacks[minetest.pos_to_string(pos)][name]
  if type(callback) == "function" then
    local status, err = pcall(callback, ...)
      if not status then
        minetest.get_meta(pos):set_string("error", "luablock callback error:"..tostring(err))
      else
        return err
      end
  end
end

--This code is responsible for executing the code that belongs to an individual Lua Block
local luablock_digilines_execute_internal = function(pos, event)
  local execute = function(pos, _code)
    --environment
    local env = {}
    env.luablock = {
      memory = load_memory(pos),
      event = event,
      callbacks = {}
    }
    env.here = pos
    env.luablock_send = function(channel, msg)
      luablock_send(pos, channel, msg)
    end
    env.print = function(message)
      minetest.chat_send_all(message)
    end
    env.digiline_send = function(channel, msg)
      digiline:receptor_send(pos,rules,channel,msg)
    end
    env.load_memory = function(_pos)
      if not _pos then _pos = pos end
      return load_memory(_pos)
    end
    env.save_memory = function(arg1, arg2)
      local _pos
      local memory
      if arg1 and arg2 then
        _pos = arg1
        memory = arg2
      elseif arg1 and not arg2 then
        _pos = pos
        memory = arg1
      elseif not arg1 and not arg2 then
        _pos = pos
        memory = env.luablock.memory or {}
      end
      save_memory(_pos, memory or {})
    end
    --lbapi
    for k, v in pairs(luablock.lbapi.env) do
      env[k] = v
    end
    setmetatable(env,{ __index = _G })
    setfenv(_code, env)
    
    --execute code
    local result = _code()

    --register callbacks
    local callback_names = {
      "on_timer",
      "on_receive_fields",
      "allow_metadata_inventory_move",
      "allow_metadata_inventory_put",
      "allow_metadata_inventory_take",
      "on_metadata_inventory_move",
      "on_metadata_inventory_put",
      "on_metadata_inventory_take"
    }

    for _, callback_name in pairs(callback_names) do
      register_luablock_callback(pos, callback_name, env.luablock.callbacks[callback_name])
    end

    --save memory
    save_memory(pos, env.luablock.memory or {})

    --return result
    if type(result) ~= "table" then
      return {}
    end

    return result
  end

  local meta = minetest.get_meta(pos)
  local s_code = luablock.code[minetest.pos_to_string(pos)] or ""
  local code, errMsg = loadstring(s_code);
  local success, result = pcall(execute,pos,code)

  if type(result) == "table" then
    return result
  elseif type(result) == "string" then
    meta:set_string("error", "internal error:"..result)
  elseif type(result) ~= "nil" then
    meta:set_string("error", "internal error: \""..type(result).."\" is not a valid return type.")
  end
  return {}
end

local timeout = function()
  debug.sethook()
  error("Timed out.")
end

local luablock_digilines_execute_external = function(pos,code,env,metatable,hook)
  local execute = function(pos, _code)
    --environment
    setmetatable(env,metatable or {})
    setfenv(_code, env)

    --debug.set_hook
    if hook then
      debug.sethook(timeout,"",hook)
    end
    
    --execute code
    return { result = _code() }
  end

  local func, errMsg = loadstring(code);
  local success, result = pcall(execute,pos,func)
  debug.sethook()

  if type(result) == "table" then
    return result.result
  else
    local meta = minetest.get_meta(pos)
    meta:set_string("error", "external error:"..result)
  end
end


--Node--
--------

local preserve_metadata = function(pos, oldnode, oldmeta, drops)
  local key = minetest.pos_to_string(pos)
  if type(luablock.code[key]) == "string" and luablock.code[key] ~= "" then
    luablock.itemstacks_code[key] = luablock.code[key]
    drops[1]:get_meta():set_string("channel", oldmeta.channel)
    drops[1]:get_meta():set_string("memory", oldmeta.memory)
    drops[1]:get_meta():set_string("old_pos", minetest.pos_to_string(pos))
  end
end

local restore_code = function(pos, itemstack)
  local key = itemstack:get_meta():get_string("old_pos")
  local meta = minetest.get_meta(pos)
  if luablock.itemstacks_code[key] then
    luablock.code[minetest.pos_to_string(pos)] = luablock.itemstacks_code[key]
    meta:set_string("channel", itemstack:get_meta():get_string("channel"))
    meta:set_string("memory", itemstack:get_meta():get_string("memory"))
  end
end

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
        luablock.handle_digilines_action(pos,node,channel,msg)
      end,
    },
  },
  
  preserve_metadata = preserve_metadata,

  after_place_node = function(pos, placer, itemstack)
    local can_use = minetest.check_player_privs(placer:get_player_name(),{server=true,luablock=true})
    if not can_use then
      minetest.remove_node(pos)
      minetest.chat_send_player(placer:get_player_name(),"You do not have permission to place this node.")
    else
      restore_code(pos, itemstack)
    end
  end,

  can_dig = function(pos, player)
    local can_use = minetest.check_player_privs(player:get_player_name(),{server=true,luablock=true})
    if not can_use then
      minetest.chat_send_player(player:get_player_name(),"You do not have permission to dig this node.")
    end
    return can_use
  end,
  
  on_rightclick = function(pos, node, clicker, itemstack)
    local can_use = minetest.check_player_privs(clicker:get_player_name(),{server=true,luablock=true})
    local can_view = minetest.check_player_privs(clicker:get_player_name(),{luablock_view=true})
    if can_use then
      clicker:get_meta():set_string("luablock:pos",minetest.pos_to_string(pos))
      minetest.show_formspec(clicker:get_player_name(), "luablock:luablock_digilines_formspec", 
        luablock.digilines_formspec(pos))
    elseif can_view then
      minetest.show_formspec(clicker:get_player_name(), "luablock:luablock_view_formspec",
        luablock.formspec_view(pos))
    end
  end,

  after_destruct = function(pos, oldnode)
    luablock.code[minetest.pos_to_string(pos)] = nil
    luablock.callbacks[minetest.pos_to_string(pos)] = nil
  end,

  --registerable callbacks in luablock code
  on_timer = function(pos, ...)
    local result call_luablock_callback(pos, "on_timer", pos, ...)
    if type(result) ~= "boolean" and type(result) ~= "nil" then
      return nil
    end
    return result
  end,
  on_receive_fields = function(pos, ...)
    return call_luablock_callback(pos, "on_receive_fields", pos, ...)
  end,
  allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
    local result = call_luablock_callback(pos, "allow_metadata_inventory_move", pos, from_list, from_index, to_list, to_index, count, player)
    if type(result) ~= "number" then
      return count
    end
    return result
  end,
  allow_metadata_inventory_put = function(pos, listname, index, stack, player)
    local result = call_luablock_callback(pos, "allow_metadata_inventory_put", pos, listname, index, stack, player)
    if type(result) ~= "number" then
      return stack:get_count()
    end
    return result
  end,
  allow_metadata_inventory_take = function(pos, listname, index, stack, player)
    local result = call_luablock_callback(pos, "allow_metadata_inventory_take", pos, listname, index, stack, player)
    if type(result) ~= "number" then
      return stack:get_count()
    end
    return result
  end,
  on_metadata_inventory_move = function(pos, ...)
    return call_luablock_callback(pos, "on_metadata_inventory_move", pos, ...)
  end,
  on_metadata_inventory_put = function(pos, ...)
    return call_luablock_callback(pos, "on_metadata_inventory_put", pos, ...)
  end,
  on_metadata_inventory_take = function(pos, ...)
    return call_luablock_callback(pos, "on_metadata_inventory_take", pos, ...)
  end,

  -- on_timer = function(pos, elapsed),
  --   -- default: nil
  --   -- called by NodeTimers, see minetest.get_node_timer and NodeTimerRef.
  --   -- elapsed is the total time passed since the timer was started.
  --   -- return true to run the timer for another cycle with the same timeout
  --   -- value.

  --   on_receive_fields = function(pos, formname, fields, sender),
  --   -- fields = {name1 = value1, name2 = value2, ...}
  --   -- Called when an UI form (e.g. sign text input) returns data.
  --   -- See minetest.register_on_player_receive_fields for more info.
  --   -- default: nil

  --   allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player),
  --   -- Called when a player wants to move items inside the inventory.
  --   -- Return value: number of items allowed to move.

  --   allow_metadata_inventory_put = function(pos, listname, index, stack, player),
  --   -- Called when a player wants to put something into the inventory.
  --   -- Return value: number of items allowed to put.
  --   -- Return value -1: Allow and don't modify item count in inventory.

  --   allow_metadata_inventory_take = function(pos, listname, index, stack, player),
  --   -- Called when a player wants to take something out of the inventory.
  --   -- Return value: number of items allowed to take.
  --   -- Return value -1: Allow and don't modify item count in inventory.

  --   on_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player),
  --   on_metadata_inventory_put = function(pos, listname, index, stack, player),
  --   on_metadata_inventory_take = function(pos, listname, index, stack, player),
  --   -- Called after the actual action has happened, according to what was
  --   -- allowed.
  --   -- No return value.
})

--Digiline Code--
-----------------
function luablock.handle_digilines_action(pos,node,channel,msg)
  local meta = minetest.get_meta(pos)
  local setchannel = meta:get_string("channel")
  local receive_all_events = meta:get_string("receive_all_events")
  if receive_all_events ~= "true" then
    if channel ~= setchannel then return end
  end
  --if type(msg) ~= "table" and type(msg) ~= "string" then return end
  if type(msg) ~= "table" then
    msg = {
      type = "unspecified",
      msg = msg
    }
  elseif type(msg) == "table" and type(msg.type) ~= "string" and type(msg.code) ~= "string" then
    msg = {
      type = "unspecified",
      msg = msg
    }
  end

  msg.type = msg.type or "unspecified"

  meta:set_string("error", "")

  if msg.type == "execute_code" then
    local event = {
      type = msg.type,
      channel = channel,
      msg = msg,
      extra_data = msg.extra_data or {}
    }

    --executes the code with the full environment. This can only be edited
    --by people with the 'luablock' priv.
    local result = luablock_digilines_execute_internal(pos, event)

    --handle the environment returned by the internal, and external code
    local env = result.environment or {}
    local metatable = result.metatable or {}
    local code = ""
    --get the second environment from digiline_send
    local _env = {}

    if type(msg.code) == "string" then code = msg.code
    elseif type(msg.func) == "string" then code = msg.func
    elseif type(msg[1]) == "string" then code = msg[1]
    elseif type(msg[2]) == "string" then code = msg[2] end

    if type(msg.environment) == "table" then _env = msg.environment
    elseif type(msg.env) == "table" then _env = msg.env
    elseif type(msg[1]) == "table" then _env = msg[1]
    elseif type(msg[2]) == "table" then _env = msg[2] end

    --merge the second environment with the main one
    for k, v in pairs(_env) do
      env[k] = env[k] or v
    end

    --handle hook
    --The below code configures how debug.set_hook will be used when the local variable 'hook' is passed to
    --'luablock_digilines_execute_external'.
    --If 'hook' is set to nil when passed to 'luablock_digilines_execute_external' then debug.set_hook will not be used.
    --If 'hook' is a string and is equel to "infinite" then 'hook' will be passed as nil. Otherwise it will be passed as
    --as a number set to 25000.
    --If 'hook' is nil or is not a number, then 'hook' will be passed as a number set to 25000.

    local hook = result.hook
    if type(hook) == "string" then
      if hook == "infinite" then hook = nil 
      else hook = 25000 end
    elseif type(hook) ~= "number" then
      hook = 25000
    end

    --execute external code
    if type(env) == "table" then
      luablock_digilines_execute_external(pos,code,env,metatable,hook)
    end
  elseif msg.type == "execute_luablock" then
    local event = {
      type = msg.type,
      channel = channel,
      msg = msg
    }
    luablock_digilines_execute_internal(pos, event)
  elseif msg.type == "msg" then
    local event = {
      type = msg.type,
      channel = channel,
      msg = msg.msg,
      full_msg = msg
    }
    luablock_digilines_execute_internal(pos, event)
  elseif msg.type == "luablock_msg" and type(msg.uid) == "string" then
    local luablock_msg = luablock_recieve(msg.uid)
    local event = {
      type = msg.type,
      channel = channel,
      msg = luablock_msg
    }
    luablock_digilines_execute_internal(pos, event)
  elseif msg.type == "unspecified" then
    local event = {
      type = msg.type,
      channel = channel,
      msg = msg.msg
    }
    luablock_digilines_execute_internal(pos, event)
  end
end

--Formspecs--
-------------

--To be added
-- formspec_version[5]
-- size[14,19]
-- textarea[0.9,4.7;12,10.5;code;Code;]
-- button[5,17.7;4,0.8;execute;Execute]
-- textarea[0.9,15.9;12,1.5;error;Error;]
-- textarea[0.9,3.3;12,0.7;channel;Channel;]
-- checkbox[0.9,0.7;receive_all_events;Receive All Events;false]
-- field[0.9,1.9;12,0.7;network;Network;]

-- formspec_version[5]
-- size[14,17]
-- textarea[0.9,3.3;12,9.9;code;Code;]
-- button[5,15.7;4,0.8;execute;Execute]
-- textarea[0.9,13.9;12,1.5;error;Error;]
-- textarea[0.9,1.9;12,0.7;channel;Channel;]
-- checkbox[0.9,0.7;receive_all_events;Receive All Events;false]

function luablock.digilines_formspec(pos)
  local meta = minetest.get_meta(pos)
  local recieve_all_events = meta:get_string("receive_all_events")
  local code = luablock.code[minetest.pos_to_string(pos)] or ""
  local error = meta:get_string("error")
  local channel = meta:get_string("channel")

  if recieve_all_events ~= "true" then recieve_all_events = "false" end

  local formspec = "formspec_version[5]"..
  "size[14,17]" ..
  "textarea[0.9,3.3;12,9.9;code;Code;"..minetest.formspec_escape(code).."]"..
  "button[5,15.7;4,0.8;execute;Execute]"..
  "textarea[0.9,13.9;12,1.5;error;Error;"..minetest.formspec_escape(error).."]"..
  "textarea[0.9,1.9;12,0.7;channel;Channel;"..minetest.formspec_escape(channel).."]"..
  "checkbox[0.9,0.7;receive_all_events;Receive All Events;"..recieve_all_events.."]"

  return formspec
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
  if formname == "luablock:luablock_digilines_formspec" then
    local is_approved = minetest.check_player_privs(player:get_player_name(),{server=true,luablock=true})
    if is_approved then
      local meta = player:get_meta()
      local pos = minetest.string_to_pos(meta:get_string("luablock:pos"))
      local node = minetest.registered_nodes[minetest.get_node(pos).name]
      local node_meta = minetest.get_meta(pos)
      if fields.execute then
        node_meta:set_string("channel",fields.channel)
        luablock.code[minetest.pos_to_string(pos)] = fields.code
        luablock.save_code()
      elseif fields.receive_all_events then
        node_meta:set_string("receive_all_events", fields.receive_all_events)
      end
    end
  end
end)