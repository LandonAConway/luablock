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

          local env, t = luablock.digilines_execute_node(pos)
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
            luablock.digilines_execute_code(pos,code,env,t)
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
    local meta = player:get_meta()
    local pos = minetest.string_to_pos(meta:get_string("luablock:pos"))
    local node = minetest.registered_nodes[minetest.get_node(pos).name]
    local node_meta = minetest.get_meta(pos)
    if fields.execute then
      node_meta:set_string("channel",fields.channel)
      node_meta:set_string("code",fields.code)
    end
  end
end)

function luablock.digilines_execute_node(pos)
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
    return { result = _code() }
  end

  local meta = minetest.get_meta(pos)
  local s_code = meta:get_string("code")
  local code, errMsg = loadstring(s_code);
  local success, result = pcall(execute,pos,code)

  if type(result) == "table" then
    return result.result
  else
    meta:set_string("error", "internal error:"..result)
  end
end

function luablock.digilines_execute_code(pos,code,env,t)
  local execute = function(pos, _code)
    --environment
    setmetatable(env,t or { __index = {} })
    setfenv(_code, env)
    
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

-- function luablock.execute(pos,code,type)
--   local env = luablock.create_env(pos)
--   setfenv(code,env)
--   local result = code()
--   local code = minetest.get_meta(pos):get_string("code")
--   local error = minetest.get_meta(pos):get_string("error")
--   if type == "receptor" then
--     if result then
--       minetest.set_node(pos,{name="luablock:luablock_receptor_on"})
--       minetest.get_meta(pos):set_string("code",code)
--       minetest.get_meta(pos):set_string("error",error)
--       mesecon.receptor_on(pos,mesecon.rules.default)
--     else
--       minetest.set_node(pos,{name="luablock:luablock_receptor_off"})
--       minetest.get_meta(pos):set_string("code",code)
--       minetest.get_meta(pos):set_string("error",error)
--       mesecon.receptor_off(pos,mesecon.rules.default)
--     end
--   end
-- end

-- --create global table _luablock so it can be used in the environment
-- _luablock = {}
-- function luablock.create_env(pos)
--   local is_on = luablock.is_on(pos)
--   local env = {}
--   env.here = pos
--   env.state = {}
--   env.state.on = is_on
--   env.state.off = not is_on
--   env.print = function(message)
--     minetest.chat_send_all(message)
--   end
--   setmetatable(env,{ __index = _G })
--   return env
-- end

-- local cardreader_rules = {
-- 	{x =  1, y =  0,z =  0,},
-- 	{x =  2, y =  0,z =  0,},
-- 	{x = -1, y =  0,z =  0,},
-- 	{x = -2, y =  0,z =  0,},
-- 	{x =  0, y =  1,z =  0,},
-- 	{x =  0, y =  2,z =  0,},
-- 	{x =  0, y = -1,z =  0,},
-- 	{x =  0, y = -2,z =  0,},
-- 	{x =  0, y =  0,z =  1,},
-- 	{x =  0, y =  0,z =  2,},
-- 	{x =  0, y =  0,z = -1,},
-- 	{x =  0, y =  0,z = -2,},
-- }

-- minetest.register_craftitem("digistuff:card",{
-- 	description = "Blank Magnetic Card",
-- 	image = "digistuff_magnetic_card.png",
-- 	stack_max = 1,
-- 	on_use = function(stack,_,pointed)
-- 		local pos = pointed.under
-- 		if not pos then return end
-- 		if minetest.get_node(pos).name ~= "digistuff:card_reader" then return end
-- 		local meta = minetest.get_meta(pos)
-- 		local channel = meta:get_string("channel")
-- 		local stackmeta = stack:get_meta()
-- 		if meta:get_int("writepending") > 0 then
-- 			local data = meta:get_string("writedata")
-- 			meta:set_int("writepending",0)
-- 			meta:set_string("infotext","Ready to Read")
-- 			digiline:receptor_send(pos,cardreader_rules,channel,{event = "write",})
-- 			stackmeta:set_string("data",data)
-- 			stackmeta:set_string("description",string.format("Magnetic Card (%s)",meta:get_string("writedescription")))
-- 			return stack
-- 		else
-- 			local channel = meta:get_string("channel")
-- 			local data = stackmeta:get_string("data")
-- 			digiline:receptor_send(pos,cardreader_rules,channel,{event = "read",data = data,})
-- 		end
-- 	end,
-- })

-- minetest.register_node("digistuff:card_reader",{
-- 	description = "Digilines Magnetic Card Reader/Writer",
-- 	groups = {cracky = 3,digiline_receiver = 1,},
-- 	on_construct = function(pos)
-- 		local meta = minetest.get_meta(pos)
-- 		meta:set_string("formspec","field[channel;Channel;${channel}")
-- 		meta:set_int("writepending",0)
-- 		meta:set_string("infotext","Ready to Read")
-- 	end,
-- 	on_receive_fields = function(pos, formname, fields, sender)
-- 		local name = sender:get_player_name()
-- 		if minetest.is_protected(pos,name) and not minetest.check_player_privs(name,{protection_bypass=true}) then
-- 			minetest.record_protection_violation(pos,name)
-- 			return
-- 		end
-- 		local meta = minetest.get_meta(pos)
-- 		if fields.channel then meta:set_string("channel",fields.channel) end
-- 	end,
-- 	_digistuff_channelcopier_fieldname = "channel",
-- 	paramtype = "light",
-- 	paramtype2 = "facedir",
-- 	tiles = {
-- 		"digistuff_cardreader_sides.png",
-- 		"digistuff_cardreader_sides.png",
-- 		"digistuff_cardreader_sides.png",
-- 		"digistuff_cardreader_sides.png",
-- 		"digistuff_cardreader_sides.png",
-- 		"digistuff_cardreader_top.png",
-- 	},
-- 	drawtype = "nodebox",
-- 	node_box = {
-- 		type = "fixed",
-- 		fixed = {
-- 			{-0.08,-0.12,0.4,0.08,0.12,0.5},
-- 		}
-- 	},
	-- digiline = {
	-- 	receptor = {},
	-- 	wire = {
	-- 		rules = cardreader_rules,
	-- 	},
	-- 	effector = {
	-- 		action = function(pos,node,channel,msg)
	-- 			local setchannel = minetest.get_meta(pos):get_string("channel")
	-- 			if channel ~= setchannel or type(msg) ~= "table" then return end
	-- 			if msg.command == "write" and (type(msg.data) == "string" or type(msg.data) == "number") then
	-- 				local meta = minetest.get_meta(pos)
	-- 				meta:set_string("infotext","Ready to Write")
	-- 				meta:set_int("writepending",1)
	-- 				if type(msg.data) ~= "string" then msg.data = tostring(msg.data) end
	-- 				meta:set_string("writedata",string.sub(msg.data,1,256))
	-- 				if type(msg.description) == "string" then
	-- 					meta:set_string("writedescription",string.sub(msg.description,1,64))
	-- 				else
	-- 					meta:set_string("writedescription","no name")
	-- 				end
	-- 			end
	-- 		end,
	-- 	},
	-- },
-- })

-- minetest.register_craft({
-- 	output = "digistuff:card",
-- 	recipe = {
-- 		{"basic_materials:plastic_sheet",},
-- 		{"default:iron_lump",},
-- 	}
-- })

-- minetest.register_craft({
-- 	output = "digistuff:card_reader",
-- 	recipe = {
-- 		{"basic_materials:plastic_sheet","basic_materials:plastic_sheet","digilines:wire_std_00000000",},
-- 		{"basic_materials:plastic_sheet","basic_materials:copper_wire","mesecons_luacontroller:luacontroller0000",},
-- 		{"basic_materials:plastic_sheet","basic_materials:plastic_sheet","",},
-- 	}
-- })
