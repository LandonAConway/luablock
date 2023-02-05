--------------------
--Saving & Loading--
--------------------

function luablock.save_luatools()
    local luatools = {}
    for k, v in pairs(luablock.luatools) do
        luatools[k] = {
            code = v.code,
            error = v.error,
            memory = v.memory
        }
    end
    luablock.mod_storage.set_string("luatools", minetest.serialize(luatools))
end

function luablock.load_luatools()
    luablock.luatools = minetest.deserialize(luablock.mod_storage.get_string("luatools")) or {}
    for _, luatool in pairs(luablock.luatools) do
        luatool.needs_activation = true
    end
end

minetest.register_on_mods_loaded(function()
    luablock.load_luatools()
end)

function luablock.get_luatool(location)
    local luatool
    if type(location) == "userdata" then
        luatool = luablock.luatools[location:get_meta():get_string("uid")]
    elseif type(location) == "string" then
        luatool = luablock.luatools[location]
    end
    return luatool
end

function luablock.luatool_activate(location)
    local luatool = luablock.get_luatool(location)
    if luatool.needs_activation then
        luatool.callbacks = {}
        luatool.commands = {}
        luablock.luatool_execute(location)
        luatool.needs_activation = nil
    end
end

---------------------------
--Lua Tool Initialization--
---------------------------

local create_uid = function(length)
    local alphabet = {
        'a','b','c','d','e','f','g','h','i',
        'j','k','l','m','n','o','p','q','r',
        's','t','u','v','w','x','y','z'
    }
    local uid = ""
    math.randomseed(os.time())
    for i=1,length,1 do
        local _type = math.random(1,2)
        if _type == 1 then
            uid = uid..math.random(1,9)
        elseif _type == 2 then
            local case = math.random(1,2)
            local letter = alphabet[math.random(1,26)]
            if case == 2 then
                letter = string.upper(letter)
            end
            uid = uid..letter
        end
    end
    return uid
end

luablock.luatool_init = function(stack)
    local stack_uid = stack:get_meta():get_string("uid")
    if stack_uid == "" or luablock.luatools[stack_uid] == nil then
        local uid = create_uid(15)
        repeat
            uid = create_uid(15)
        until not luablock.luatools[uid]
        stack:get_meta():set_string("uid",uid)
        luablock.luatools[uid] = {
            code = "",
            error = "",
            memory = {},
            callbacks = {},
            commands = {},
        }
    end
    luablock.save_luatools()
    return stack
end

---------------------------
--Lua Tool Code Execution--
---------------------------

local set_callbacks = function(location, callbacks)
    local luatool = luablock.get_luatool(location)
    luatool.callbacks = luatool.callbacks or {}
    local callback_names = {
        "on_place",
        "on_secondary_use",
        "on_drop",
        "on_use",
        "after_use"
    }
    for _, callback_name in pairs(callback_names) do
        if type(callbacks[callback_name]) ~= "function" then
            luatool.callbacks[callback_name] = nil
        else
            luatool.callbacks[callback_name] = callbacks[callback_name]
        end
    end
end

local get_luatool_callback = function(location, name)
    local default_callback = luablock.default_luatool_callbacks[name]
    local luatool = luablock.get_luatool(location)
    if luatool then
        local callback = luatool.callbacks[name]
        if type(callback) == "function" then
            return false, callback
        end
    end
    return true, default_callback
end

local call_luatool_callback = function(player, location, name, ...)
    local is_default, callback = get_luatool_callback(location, name)
    local status, result = pcall(callback, ...)
    if not status then
        if player then
            minetest.chat_send_player(player:get_player_name(), "Lua Tool Callback Error: "..tostring(result))
        end
    else
        return is_default, result
    end
end

local set_commands = function(location, commands)
    local luatool = luablock.get_luatool(location)
    luatool.commands = commands or {}
end

local set_error = function(location, err)
    luablock.get_luatool(location).error = err
end

local luatool_execute = function(location)
    local luatool = luablock.get_luatool(location)
    local execute = function(_code)
        --environment
        local env = {}
        env.luatool = {
            callbacks = {},
            commands = {},
            memory = luatool.memory,
        }
        env.print = function(...)
            local params = {...}
            if params[2] and type(params[1]) == "string" then
                if minetest.get_player_by_name(params[1]) then
                    minetest.chat_send_player(params[1], tostring(params[2]))
                end
            else
                minetest.chat_send_all(tostring(params[1]))
            end
        end
        --lbapi
        for k, v in pairs(luablock.lbapi.env) do
            env[k] = v
        end
        setmetatable(env,{ __index = _G })
        setfenv(_code, env)
        
        --execute code
        local result = _code()

        set_callbacks(location, env.luatool.callbacks)
        set_commands(location, env.luatool.commands)
        luablock.save_luatools()
    
        return result
    end
    
    local scode = luatool.code or ""

    local code, syntaxErrMsg = loadstring(scode);
    local success, errMsg = pcall(execute,code)
    if not code then
        set_error(location,syntaxErrMsg)
    elseif not success then
        set_error(location,tostring(errMsg))
    else
        set_error(location,"")
    end
end

luablock.luatool_execute = luatool_execute

---------------------------------
--Lua Tool Inventory & Formspec--
---------------------------------

local serialize_lists = function(lists)
    local _t = {}
    for name, list in pairs(lists) do
        _t[name] = {}
        for _, stack in pairs(list) do
            table.insert(_t[name],{
                stack = stack:to_table(),
                metadata = stack:get_meta():to_table()
            })
        end
    end
    return minetest.serialize(_t)
end

local deserialize_lists = function(str)
    local _t = minetest.deserialize(str) or {}
    local lists = {}
    for name, list in pairs(_t) do
        lists[name] = {}
        for _, stack in pairs(list) do
            local _stack = ItemStack(stack.stack)
            _stack:get_meta():from_table(stack.metadata or {})
            table.insert(lists[name],_stack)
        end
    end
    return lists
end

local save_inventory = function(player, inv)
    luablock.mod_storage.set_string("luatool_inv_"..player:get_player_name(), serialize_lists(inv:get_lists()))
end

local load_inventory = function(player, inv)
    inv:set_lists(deserialize_lists(luablock.mod_storage.get_string("luatool_inv_"..player:get_player_name())))
end

minetest.register_on_joinplayer(function(player)
    local inv = minetest.create_detached_inventory("luatools_"..player:get_player_name(),{
        on_put = function(inv, listname, index, stack, player)
            if luablock.valid_luatools[stack:get_name()] and listname == "tool" then
                local _stack = luablock.luatool_init(stack)
                inv:set_stack("tool", 1, _stack)
                luablock.show_luatool_formspec(player)
            end
            save_inventory(player, inv)
        end,
        on_take = function(inv, listname, index, stack, player)
            if luablock.valid_luatools[stack:get_name()] and listname == "tool" then
                luablock.show_luatool_formspec(player)
            end
            save_inventory(player, inv)
        end,
        on_move = function(inv, from_list, from_index, to_list, to_index, count, player)
            local stack = inv:get_stack(to_list, to_index)
            if luablock.valid_luatools[stack:get_name()] then
                if to_list == "tool" then
                    local _stack = luablock.luatool_init(stack)
                    inv:set_stack("tool", 1, _stack)
                    luablock.show_luatool_formspec(player)
                else
                    luablock.show_luatool_formspec(player)
                end
            end
            save_inventory(player, inv)
        end
    })
    load_inventory(player, inv)
    inv:set_size("tool", 1*1)
    inv:set_size("main", 8*8)
end)

local luatool_types = {
    "luablock:luatool",
    "luablock:luatool_apple",
    "luablock:luatool_skeleton_key",
    "luablock:luatool_key",
    "luablock:luatool_magentic_card",
    "luablock:luatool_sim_card",
    "luablock:luatool_sd_card"
}

local get_luatool_types_descriptions = function()
    local descriptions = {}
    for _, name in pairs(luatool_types) do
        local def = minetest.registered_items[name]
        table.insert(descriptions, minetest.formspec_escape(def.description))
    end
    return descriptions
end

-- "formspec_version[6]" ..
-- "size[25,19.7]" ..
-- "list[detached:;tool;0.5,0.9;1,1;0]" ..
-- "field[2,1.2;8.3,0.7;description;Description;]" ..
-- "button[5.5,2.1;4.8,0.5;create;Create Lua Tool]" ..
-- "button[0.5,2.8;9.8,0.5;wielded_item;Wielded Item]" ..
-- "list[detached:;main;0.5,4;8,8;0]" ..
-- "list[current_player;main;0.5,14.5;8,4;0]" ..
-- "textarea[11.1,0.9;13.4,13.6;code;Code;]" ..
-- "textarea[11.1,15.4;13.4,2.5;error;Error;]" ..
-- "button[11.1,18.4;6.4,0.8;save;Save]" ..
-- "button[18.1,18.4;6.4,0.8;run;Run]" ..
-- "dropdown[0.5,2.1;4.8,0.5;luatool_type;Lua Tool,Lua Tool (Apple),Lua Tool (Magnetic Card);1;true]"

-- "formspec_version[5]" ..
-- "size[25,19]" ..
-- "list[detached:;tool;0.5,0.9;1,1;0]" ..
-- "field[2,1.2;8.3,0.7;description;Description;]" ..
-- "button[5.5,2.1;4.8,0.5;create;Create Lua Tool]" ..
-- "list[detached:;main;0.5,3.3;8,8;0]" ..
-- "list[current_player;main;0.5,13.8;8,4;0]" ..
-- "textarea[11.1,0.9;13.4,12.9;code;Code;]" ..
-- "textarea[11.1,14.7;13.4,2.5;error;Error;]" ..
-- "button[11.1,17.7;6.4,0.8;save;Save]" ..
-- "button[18.1,17.7;6.4,0.8;run;Run]" ..
-- "dropdown[0.5,2.1;4.8,0.5;luatool_type;Lua Tool,Lua Tool (Apple),Lua Tool (Magnetic Card);1;true]"

luablock.luatool_formspec = function(player)
    local inv_location = "luatools_"..player:get_player_name()
    local inv = minetest.get_inventory({type="detached",name=inv_location})
    local stack = inv:get_stack("tool",1)
    local luatool = luablock.get_luatool(stack)
    local code = ""
    local error = ""
    local description = ""
    if luablock.valid_luatools[stack:get_name()] then
        code = luatool.code or ""
        error = luatool.error or ""
        description = stack:get_meta():get_string("description")
    end

    local formspec = "formspec_version[6]" ..
    "size[25,19.7]" ..
    "list[detached:"..inv_location..";tool;0.5,0.9;1,1;0]" ..
    "field[2,1.2;8.3,0.7;description;;"..minetest.formspec_escape(description).."]" ..
    "dropdown[0.5,2.1;4.8,0.5;luatool_type;"..table.concat(get_luatool_types_descriptions(), ",")..";1;true]" ..
    "button[5.5,2.1;4.8,0.5;create;Create Lua Tool]" ..
    "button[0.5,2.8;9.8,0.5;wielded_item;Wielded Item]" ..
    "list[detached:"..inv_location..";main;0.5,4;8,8;0]" ..
    "list[current_player;main;0.5,14.5;8,4;0]" ..
    "textarea[11.1,0.9;13.4,13.6;code;Code;"..minetest.formspec_escape(code).."]" ..
    "textarea[11.1,15.4;13.4,2.5;error;Error;"..minetest.formspec_escape(error).."]" ..
    "button[11.1,18.4;6.4,0.8;save;Save]" ..
    "button[18.1,18.4;6.4,0.8;run;Run]"

    return formspec
end

luablock.show_luatool_formspec = function(player)
    if type(player) == "string" then
        player = minetest.get_player_by_name(player)
    end
    minetest.show_formspec(player:get_player_name(), "luablock:luatool_formspec_"..player:get_player_name(),
        luablock.luatool_formspec(player))
end

local set_luatool_stack = function(player, stack)
    local inv = minetest.get_inventory({type="detached",name="luatools_"..player:get_player_name()})
    inv:set_stack("tool",1,stack)
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "luablock:luatool_formspec_"..player:get_player_name() then
        local is_approved = minetest.check_player_privs(player:get_player_name(),{server=true,luablock=true})
        if is_approved then
            local inv = minetest.get_inventory({type="detached",name="luatools_"..player:get_player_name()})
            local stack = inv:get_stack("tool", 1)
            if luablock.valid_luatools[stack:get_name()] then
                local luatool = luablock.get_luatool(stack)
                if fields.save then
                    stack:get_meta():set_string("description", fields.description)
                    set_luatool_stack(player, stack)
                    luatool.code = fields.code
                    luablock.save_luatools()
                elseif fields.run then
                    stack:get_meta():set_string("description", fields.description)
                    set_luatool_stack(player, stack)
                    luatool.code = fields.code
                    luablock.save_luatools()
                    luatool_execute(stack)
                end
            end
            if fields.wielded_item then
                local wielded_item = player:get_wielded_item()
                if luablock.valid_luatools[stack:get_name()] then
                    local allow_swap = wielded_item:get_count() == 0
                    if allow_swap then
                        local _swap = inv:remove_item("tool", stack)
                        player:set_wielded_item(_swap)
                        luablock.show_luatool_formspec(player)
                    end
                elseif stack:get_count() == 0 then
                    if luablock.valid_luatools[wielded_item:get_name()] then
                        local _stack = luablock.luatool_init(wielded_item)
                        inv:set_stack("tool", 1, _stack)
                        player:set_wielded_item(ItemStack(""))
                        luablock.show_luatool_formspec(player)
                    end
                end
                luablock.save_luatools()
            end
            if fields.create then
                local luatool_type_index = tonumber(fields.luatool_type)
                local luatool_type = "luablock:luatool"
                if luatool_type_index then
                    luatool_type = luatool_types[luatool_type_index]
                end
                local oldstack = inv:remove_item("tool", stack)
                if inv:room_for_item("main", oldstack) then
                    inv:add_item("main", oldstack)
                else
                    minetest.item_drop(oldstack, player, player:get_pos())
                end
                
                local newstack = luablock.luatool_init(ItemStack(luatool_type))
                newstack:get_meta():set_string("description", fields.description)
                inv:set_stack("tool", 1, newstack)
                local newluatool = luablock.get_luatool(newstack)
                newluatool.code = fields.code
                luablock.save_luatools()
            end
        end
    end
end)

minetest.register_chatcommand("luatool_editor", {
    description = "Opens formspec to edit a Lua Tool.",
    privs = { server=true, luablock=true },
    func = function(name, text)
        luablock.show_luatool_formspec(name)
    end
})

---------------------
--Lua Tool Commands--
---------------------

local get_missing_privs = function(name, needed_privs)
    local result, missing_privs = minetest.check_player_privs(name, needed_privs)
    local _missing_privs = {}
    if not result and type(missing_privs) == "table" then
        for _, priv in pairs(missing_privs) do
            table.insert(_missing_privs, priv)
        end
    end
    return result, _missing_privs
end

local execute_luatool_command = function(location, command, name, text)
    local luatool = luablock.get_luatool(location)
    if not luatool then
        luablock.luatool_init(location)
    end
    luablock.luatool_activate(location)
    local commanddef = luatool.commands[command]
    if type(commanddef) == "table" then
        local player = minetest.get_player_by_name(name)
        local result, missing_privs = get_missing_privs(name, commanddef.privs or {})
        if result then
            if type(commanddef.func) == "function" then
                local status, result, message = pcall(commanddef.func, name, text)
                if not status then
                    return false, "Lua Tool Command Error: "..tostring(result)
                end
                return result, message
            end
        end
        return false, "You don't have permission to run this command (Missing Privileges: "..table.concat(missing_privs, ", ")..")"
    end
    return false, "The command '"..command.."' does not exist for the current Lua Tool."
end

minetest.register_chatcommand("luatool", {
    description = "Executes a Lua Tool command.",
    func = function(name, params)
        local player = minetest.get_player_by_name(name)
        local wielded_item = player:get_wielded_item()
        if luablock.valid_luatools[wielded_item:get_name()] then
            local _params = string.split(params, " ")
            local command = _params[1]
            if command then
                table.remove(_params, 1)
                local text = table.concat(_params, " ")
                return execute_luatool_command(wielded_item, command, name, text)
            end
            return false, "Please type a command."
        end
        return false, "The wielded item is not a Lua Tool."
    end
})

-------------------------
--Lua Tool Registration--
-------------------------

luablock.valid_luatools = {
    ["luablock:luatool"] = true,
    ["luablock:luatool_apple"] = true,
    ["luablock:luatool_book"] = true,
    ["luablock:luatool_skeleton_key"] = true,
    ["luablock:luatool_key"] = true,
    ["luablock:luatool_magentic_card"] = true,
    ["luablock:luatool_sim_card"] = true,
    ["luablock:luatool_sd_card"] = true,
    ["luablock:luatool_blaster"] = true,
    ["luablock:luatool_sword_steel"] = true,
    ["luablock:luatool_sword_diamond"] = true,
    ["luablock:luatool_paper"] = true
}

luablock.default_luatool_callbacks = {
    on_place = function(itemstack, placer, pointed_thing) end,
    on_secondary_use = function(itemstack, user, pointed_thing) end,
    on_drop = function(itemstack, dropper, pos)
        return minetest.item_drop(itemstack, dropper, pos)
    end,
    on_use = function(itemstack, user, pointed_thing) end,
    after_use = function(itemstack, user, node, digparams) end,
}

luablock.luatool = { callbacks = {
    default = {

    }
} }

--------------------------
--Builtin Registerations--
--------------------------

minetest.register_tool("luablock:luatool", {
    description = "Lua Tool",
    inventory_image = "luablock_luatool.png",
    groups = {not_in_creative_inventory=1},

    on_place = function(itemstack, placer, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(placer, itemstack, "on_place",
            itemstack, placer, pointed_thing)
        return result
    end,
    on_secondary_use = function(itemstack, user, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "on_secondary_use",
            itemstack, user, pointed_thing)
        return result
    end,
    on_drop = function(itemstack, dropper, pos)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(dropper, itemstack, "on_drop",
            itemstack, dropper, pos)
        return result
    end,
    on_use = function(itemstack, user, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "on_use",
            itemstack, user, pointed_thing)
        return result
    end,
    after_use = function(itemstack, user, node, digparams)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "after_use",
            itemstack, user, node, digparams)
        return result
    end,
})

minetest.register_tool("luablock:luatool_apple", {
    description = "Lua Tool (Apple)",
    inventory_image = "default_apple.png",
    groups = {not_in_creative_inventory=1},

    on_place = function(itemstack, placer, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(placer, itemstack, "on_place",
            itemstack, placer, pointed_thing)
        return result
    end,
    on_secondary_use = function(itemstack, user, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "on_secondary_use",
            itemstack, user, pointed_thing)
        return result
    end,
    on_drop = function(itemstack, dropper, pos)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(dropper, itemstack, "on_drop",
            itemstack, dropper, pos)
        return result
    end,
    on_use = function(itemstack, user, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "on_use",
            itemstack, user, pointed_thing)
        return result
    end,
    after_use = function(itemstack, user, node, digparams)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "after_use",
            itemstack, user, node, digparams)
        return result
    end,
})

minetest.register_tool("luablock:luatool_book", {
    description = "Lua Tool (Book)",
    inventory_image = "default_book.png",
    groups = {not_in_creative_inventory=1},

    on_place = function(itemstack, placer, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(placer, itemstack, "on_place",
            itemstack, placer, pointed_thing)
        return result
    end,
    on_secondary_use = function(itemstack, user, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "on_secondary_use",
            itemstack, user, pointed_thing)
        return result
    end,
    on_drop = function(itemstack, dropper, pos)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(dropper, itemstack, "on_drop",
            itemstack, dropper, pos)
        return result
    end,
    on_use = function(itemstack, user, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "on_use",
            itemstack, user, pointed_thing)
        return result
    end,
    after_use = function(itemstack, user, node, digparams)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "after_use",
            itemstack, user, node, digparams)
        return result
    end,
})

minetest.register_tool("luablock:luatool_skeleton_key", {
    description = "Lua Tool (Key)",
    inventory_image = "default_key.png",
    groups = {not_in_creative_inventory=1},

    on_place = function(itemstack, placer, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(placer, itemstack, "on_place",
            itemstack, placer, pointed_thing)
        return result
    end,
    on_secondary_use = function(itemstack, user, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "on_secondary_use",
            itemstack, user, pointed_thing)
        return result
    end,
    on_drop = function(itemstack, dropper, pos)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(dropper, itemstack, "on_drop",
            itemstack, dropper, pos)
        return result
    end,
    on_use = function(itemstack, user, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "on_use",
            itemstack, user, pointed_thing)
        return result
    end,
    after_use = function(itemstack, user, node, digparams)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "after_use",
            itemstack, user, node, digparams)
        return result
    end,
})

minetest.register_tool("luablock:luatool_key", {
    description = "Lua Tool (Skeleton Key)",
    inventory_image = "default_key_skeleton.png",
    groups = {not_in_creative_inventory=1},

    on_place = function(itemstack, placer, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(placer, itemstack, "on_place",
            itemstack, placer, pointed_thing)
        return result
    end,
    on_secondary_use = function(itemstack, user, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "on_secondary_use",
            itemstack, user, pointed_thing)
        return result
    end,
    on_drop = function(itemstack, dropper, pos)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(dropper, itemstack, "on_drop",
            itemstack, dropper, pos)
        return result
    end,
    on_use = function(itemstack, user, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "on_use",
            itemstack, user, pointed_thing)
        return result
    end,
    after_use = function(itemstack, user, node, digparams)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "after_use",
            itemstack, user, node, digparams)
        return result
    end,
})

minetest.register_tool("luablock:luatool_magentic_card", {
    description = "Lua Tool (Magnetic Card)",
    inventory_image = "luablock_luatool_magnetic_card.png",
    groups = {not_in_creative_inventory=1},

    on_place = function(itemstack, placer, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(placer, itemstack, "on_place",
            itemstack, placer, pointed_thing)
        return result
    end,
    on_secondary_use = function(itemstack, user, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "on_secondary_use",
            itemstack, user, pointed_thing)
        return result
    end,
    on_drop = function(itemstack, dropper, pos)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(dropper, itemstack, "on_drop",
            itemstack, dropper, pos)
        return result
    end,
    on_use = function(itemstack, user, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "on_use",
            itemstack, user, pointed_thing)
        return result
    end,
    after_use = function(itemstack, user, node, digparams)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "after_use",
            itemstack, user, node, digparams)
        return result
    end,
})

minetest.register_tool("luablock:luatool_sim_card", {
    description = "Lua Tool (Sim Card)",
    inventory_image = "luablock_luatool_sim_card.png",
    groups = {not_in_creative_inventory=1},

    on_place = function(itemstack, placer, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(placer, itemstack, "on_place",
            itemstack, placer, pointed_thing)
        return result
    end,
    on_secondary_use = function(itemstack, user, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "on_secondary_use",
            itemstack, user, pointed_thing)
        return result
    end,
    on_drop = function(itemstack, dropper, pos)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(dropper, itemstack, "on_drop",
            itemstack, dropper, pos)
        return result
    end,
    on_use = function(itemstack, user, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "on_use",
            itemstack, user, pointed_thing)
        return result
    end,
    after_use = function(itemstack, user, node, digparams)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "after_use",
            itemstack, user, node, digparams)
        return result
    end,
})

minetest.register_tool("luablock:luatool_sd_card", {
    description = "Lua Tool (SD Card)",
    inventory_image = "luablock_luatool_sd_card.png",
    groups = {not_in_creative_inventory=1},

    on_place = function(itemstack, placer, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(placer, itemstack, "on_place",
            itemstack, placer, pointed_thing)
        return result
    end,
    on_secondary_use = function(itemstack, user, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "on_secondary_use",
            itemstack, user, pointed_thing)
        return result
    end,
    on_drop = function(itemstack, dropper, pos)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(dropper, itemstack, "on_drop",
            itemstack, dropper, pos)
        return result
    end,
    on_use = function(itemstack, user, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "on_use",
            itemstack, user, pointed_thing)
        return result
    end,
    after_use = function(itemstack, user, node, digparams)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "after_use",
            itemstack, user, node, digparams)
        return result
    end,
})

minetest.register_tool("luablock:luatool_blaster", {
    description = "Lua Tool (Blaster)",
    inventory_image = "luablock_luatool_blaster.png",
    groups = {not_in_creative_inventory=1},

    on_place = function(itemstack, placer, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(placer, itemstack, "on_place",
            itemstack, placer, pointed_thing)
        return result
    end,
    on_secondary_use = function(itemstack, user, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "on_secondary_use",
            itemstack, user, pointed_thing)
        return result
    end,
    on_drop = function(itemstack, dropper, pos)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(dropper, itemstack, "on_drop",
            itemstack, dropper, pos)
        return result
    end,
    on_use = function(itemstack, user, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "on_use",
            itemstack, user, pointed_thing)
        return result
    end,
    after_use = function(itemstack, user, node, digparams)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "after_use",
            itemstack, user, node, digparams)
        return result
    end,
})

minetest.register_tool("luablock:luatool_sword_steel", {
    description = "Lua Tool (Steel Sword)",
    inventory_image = "default_tool_steelsword.png",
    groups = {not_in_creative_inventory=1},

    on_place = function(itemstack, placer, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(placer, itemstack, "on_place",
            itemstack, placer, pointed_thing)
        return result
    end,
    on_secondary_use = function(itemstack, user, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "on_secondary_use",
            itemstack, user, pointed_thing)
        return result
    end,
    on_drop = function(itemstack, dropper, pos)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(dropper, itemstack, "on_drop",
            itemstack, dropper, pos)
        return result
    end,
    on_use = function(itemstack, user, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "on_use",
            itemstack, user, pointed_thing)
        return result
    end,
    after_use = function(itemstack, user, node, digparams)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "after_use",
            itemstack, user, node, digparams)
        return result
    end,
})

minetest.register_tool("luablock:luatool_sword_diamond", {
    description = "Lua Tool (Diamond)",
    inventory_image = "default_tool_diamondword.png",
    groups = {not_in_creative_inventory=1},

    on_place = function(itemstack, placer, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(placer, itemstack, "on_place",
            itemstack, placer, pointed_thing)
        return result
    end,
    on_secondary_use = function(itemstack, user, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "on_secondary_use",
            itemstack, user, pointed_thing)
        return result
    end,
    on_drop = function(itemstack, dropper, pos)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(dropper, itemstack, "on_drop",
            itemstack, dropper, pos)
        return result
    end,
    on_use = function(itemstack, user, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "on_use",
            itemstack, user, pointed_thing)
        return result
    end,
    after_use = function(itemstack, user, node, digparams)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "after_use",
            itemstack, user, node, digparams)
        return result
    end,
})

minetest.register_tool("luablock:luatool_paper", {
    description = "Lua Tool (Paper)",
    inventory_image = "default_paper.png",
    groups = {not_in_creative_inventory=1},

    on_place = function(itemstack, placer, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(placer, itemstack, "on_place",
            itemstack, placer, pointed_thing)
        return result
    end,
    on_secondary_use = function(itemstack, user, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "on_secondary_use",
            itemstack, user, pointed_thing)
        return result
    end,
    on_drop = function(itemstack, dropper, pos)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(dropper, itemstack, "on_drop",
            itemstack, dropper, pos)
        return result
    end,
    on_use = function(itemstack, user, pointed_thing)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "on_use",
            itemstack, user, pointed_thing)
        return result
    end,
    after_use = function(itemstack, user, node, digparams)
        luablock.luatool_activate(itemstack)
        local used_default, result = call_luatool_callback(user, itemstack, "after_use",
            itemstack, user, node, digparams)
        return result
    end,
})


-- {
--     "on_place",
--     "on_secondary_use",
--     "on_drop",
--     "on_use",
--     "after_use"
-- }
    -- on_place = function(itemstack, placer, pointed_thing),
    -- When the 'place' key was pressed with the item in hand
    -- and a node was pointed at.
    -- Shall place item and return the leftover itemstack
    -- or nil to not modify the inventory.
    -- The placer may be any ObjectRef or nil.
    -- default: minetest.item_place

    -- on_secondary_use = function(itemstack, user, pointed_thing),
    -- Same as on_place but called when not pointing at a node.
    -- Function must return either nil if inventory shall not be modified,
    -- or an itemstack to replace the original itemstack.
    -- The user may be any ObjectRef or nil.
    -- default: nil

    -- on_drop = function(itemstack, dropper, pos),
    -- Shall drop item and return the leftover itemstack.
    -- The dropper may be any ObjectRef or nil.
    -- default: minetest.item_drop

    -- on_use = function(itemstack, user, pointed_thing),
    -- default: nil
    -- When user pressed the 'punch/mine' key with the item in hand.
    -- Function must return either nil if inventory shall not be modified,
    -- or an itemstack to replace the original itemstack.
    -- e.g. itemstack:take_item(); return itemstack
    -- Otherwise, the function is free to do what it wants.
    -- The user may be any ObjectRef or nil.
    -- The default functions handle regular use cases.

    -- after_use = function(itemstack, user, node, digparams),
    -- default: nil
    -- If defined, should return an itemstack and will be called instead of
    -- wearing out the item (if tool). If returns nil, does nothing.
    -- If after_use doesn't exist, it is the same as:
    --   function(itemstack, user, node, digparams)
    --     itemstack:add_wear(digparams.wear)
    --     return itemstack
    --   end
    -- The user may be any ObjectRef or nil.
