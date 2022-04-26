luablock.luatools = {}

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
            callbacks = {}
        }
    end
    return stack
end

---------------------------
--Lua Tool Code Execution--
---------------------------

local set_callbacks = function(stack, callbacks)
    local luatool = luablock.luatools[stack:get_meta():get_string("uid")]
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

local get_luatool_callback = function(stack, name)
    local uid = stack:get_meta():get_string("uid")
    local default_callback = luablock.default_luatool_callbacks[name]
    local luatool = luablock.luatools[uid]
    if luatool then
        local callback = luatool.callbacks[name]
        if type(callback) == "function" then
            return callback
        end
    end
    return default_callback
end

local call_luablock_callback = function(player, stack, name, ...)
    local callback = get_luatool_callback(stack, name)
    local status, result = pcall(callback, ...)
    if not status then
        if player then
            minetest.chat_send_player(player:get_player_name(), "Lua Tool Error: "..tostring(result))
        end
    else
        return result
    end
end

local set_error = function(stack, err)
    luablock.luatools[stack:get_meta():get_string("uid")].error = err
end

local luatool_execute = function(stack)
    local execute = function(_code)
        --environment
        local env = {}
        env.luatool = {
            callbacks = {}
        }
        env.print = function(msg)
            minetest.chat_send_all(msg)
        end
        --lbapi
        for k, v in pairs(luablock.lbapi.env) do
            env[k] = v
        end
        setmetatable(env,{ __index = _G })
        setfenv(_code, env)
        
        --execute code
        local result = _code()

        --set callbacks
        set_callbacks(stack, env.luatool.callbacks)
    
        return result
    end
    
    local scode = luablock.luatools[stack:get_meta():get_string("uid")].code or ""
    minetest.chat_send_all(scode)

    local code, syntaxErrMsg = loadstring(scode);
    local success, errMsg = pcall(execute,code)
    if not code then
        set_error(stack,syntaxErrMsg)
    elseif not success then
        set_error(stack,tostring(errMsg))
    else
        set_error(stack,"")
    end
end

---------------------
--Lua Tool Formspec--
---------------------

minetest.register_on_joinplayer(function(player)
    local inv = minetest.create_detached_inventory("luatools_"..player:get_player_name(),{
        on_put = function(inv, listname, index, stack, player)
            if stack:get_name() == "luablock:luatool" then
                local stack = luablock.luatool_init(stack)
                inv:set_stack("tool", 1, stack)
                luablock.show_luatool_formspec(player)
            end
        end,
        on_take = function(inv, listname, index, stack, player)
            if stack:get_name() == "luablock:luatool" then
                luablock.show_luatool_formspec(player)
            end
        end
    })
    inv:set_size("tool", 1*1)
end)

luablock.luatool_formspec = function(player)
    local inv_location = "luatools_"..player:get_player_name()
    local inv = minetest.get_inventory({type="detached",name=inv_location})
    local stack = inv:get_stack("tool",1)
    local uid = ""
    local code = ""
    local error = ""
    if stack:get_name() == "luablock:luatool" then
        uid = stack:get_meta():get_string("uid")
        code = luablock.luatools[uid].code or ""
        error = luablock.luatools[uid].error or ""
    end

    local formspec = "formspec_version[5]" ..
    "size[25,15]" ..
    "list[detached:"..inv_location..";tool;14.7,0.9;1,1;0]" ..
    "list[current_player;main;14.7,2.9;8,4;0]" ..
    "button[0.5,13.7;6.4,0.8;save;Save]" ..
    "button[7.5,13.7;6.4,0.8;run;Run]" ..
    "textarea[0.5,0.9;13.4,12.3;code;Code;"..code.."]" ..
    "textarea[14.7,8.5;9.8,4.7;error;Error;"..error.."]"

    return formspec
end

luablock.show_luatool_formspec = function(player)
    if type(player) == "string" then
        player = minetest.get_player_by_name(player)
    end
    minetest.show_formspec(player:get_player_name(), "luablock:luatool_formspec_"..player:get_player_name(),
        luablock.luatool_formspec(player))
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "luablock:luatool_formspec_"..player:get_player_name() then
        local is_approved = minetest.check_player_privs(player:get_player_name(),{server=true,luablock=true})
        if is_approved then
            local inv = minetest.get_inventory({type="detached",name="luatools_"..player:get_player_name()})
            local stack = inv:get_stack("tool", 1)
            if stack:get_name() == "luablock:luatool" then
                local luatool = luablock.luatools[stack:get_meta():get_string("uid")]
                if fields.save then
                    luatool.code = fields.code
                elseif fields.run then
                    luatool_execute(stack)
                end
            end
        end
    end
end)

minetest.register_chatcommand("luatool", {
    description = "Opens formspec to edit a Lua Tool.",
    func = function(name, text)
        luablock.show_luatool_formspec(name)
    end
})

-------------------------
--Lua Tool Registration--
-------------------------

luablock.default_luatool_callbacks = {
    on_place = function(itemstack, placer, pointed_thing) end,
    on_secondary_use = function(itemstack, user, pointed_thing) end,
    on_drop = function(itemstack, dropper, pos)
        return itemstack
    end,
    on_use = function(itemstack, user, pointed_thing) end,
    after_use = function(itemstack, user, node, digparams) end,
}

minetest.register_tool("luablock:luatool", {
    description = "Lua Tool",
    inventory_image = "luablock_luatool.png",
    groups = {not_in_creative_inventory=1},

    on_place = function(itemstack, placer, pointed_thing)
        local result = call_luablock_callback(placer, itemstack, "on_place",
            itemstack, placer, pointed_thing)
        return result
    end,
    on_secondary_use = function(itemstack, user, pointed_thing)
        local result = call_luablock_callback(user, itemstack, "on_secondary_use",
            itemstack, user, pointed_thing)
        return result
    end,
    on_drop = function(itemstack, dropper, pos)
        local result = call_luablock_callback(dropper, itemstack, "on_drop",
            itemstack, dropper, pos)
        if type(result) ~= "ItemStack" then
            return luablock.default_luatool_callbacks.on_drop(itemstack, dropper, pos)
        end
        return result
    end,
    on_use = function(itemstack, user, pointed_thing)
        local default_callback = luablock.default_luatool_callbacks.on_use
        local result = call_luablock_callback(user, itemstack, "on_use",
            itemstack, user, pointed_thing)
        return result
    end,
    after_use = function(itemstack, user, node, digparams)
        local result = call_luablock_callback(user, itemstack, "after_use",
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
