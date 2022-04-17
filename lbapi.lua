luablock.lbapi = {}
luablock.lbapi.callbacks = {}
luablock.lbapi.env = {}

local function run_callbacks(callback_type, ...)
    for _, func in pairs(luablock.lbapi.callbacks["registered_"..callback_type]) do
        local status, err = pcall(func, ...)
        if not status then
            minetest.chat_send_all("[LBAPI ERROR] :: "..err)
        end
    end
end

local register_callback = function(callback_type, name, func)
    luablock.lbapi.callbacks["registered_"..callback_type][name] = func
end

local unregister_callback = function(callback_type, name)
    luablock.lbapi.callbacks["registered_"..callback_type][name] = nil
end

local callback_types = {
    "globalstep",
    "on_chat_message",
    "on_cheat",
    "on_dieplayer",
    "on_dignode",
    "on_item_eat",
    "on_joinplayer",
    "on_leaveplayer",
    "on_newplayer",
    "on_placenode",
    "on_player_receive_fields",
    "on_protection_violation",
    "on_punchnode",
    "on_respawnplayer",
    "on_shutdown"
}

for _, callback_type in pairs(callback_types) do
    --register callback maps
    luablock.lbapi.callbacks["registered_"..callback_type] = {}

    --register callback registeration function
    luablock.lbapi.env["register_"..callback_type] = function(name, func)
        register_callback(callback_type, name, func)
    end
    
    --register callback unregisteration function
    luablock.lbapi.env["unregister_"..callback_type] = function(name)
        unregister_callback(callback_type, name)
    end

    --register the actual function wich will run the callbacks
    minetest["register_"..callback_type](function(...)
        run_callbacks(callback_type, ...)
    end)
end

-- minetest.register_globalstep
-- minetest.register_on_chat_message
-- minetest.register_on_cheat
-- minetest.register_on_dieplayer
-- minetest.register_on_dignode
-- minetest.register_on_item_eat
-- minetest.register_on_joinplayer
-- minetest.register_on_leaveplayer
-- minetest.register_on_newplayer
-- minetest.register_on_placenode
-- minetest.register_on_player_receive_fields
-- minetest.register_on_protection_violation
-- minetest.register_on_punchnode
-- minetest.register_on_respawnplayer
-- minetest.register_on_shutdown
