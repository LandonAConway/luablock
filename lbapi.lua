luablock.lbapi = {}
luablock.lbapi.callbacks = {}
luablock.lbapi.env = {}

local function show_error(error)
    for _, plr in pairs(minetest.get_connected_players()) do
        if minetest.check_player_privs(plr, {server=true}) then
            minetest.chat_send_player(plr:get_player_name(), "[LBAPI ERROR] :: "..error)
        end
    end
end

local function run_callbacks(callback_type, ...)
    for _, func in pairs(luablock.lbapi.callbacks["registered_"..callback_type]) do
        local status, err = pcall(func, ...)
        if not status then
            show_error(err)
        else
            if type(err) == "table" then
                return unpack(err)
            end
        end
    end
end

local register_callback = function(callback_type, name, func)
    luablock.lbapi.callbacks["registered_"..callback_type][name] = func
end

local unregister_callback = function(callback_type, name)
    luablock.lbapi.callbacks["registered_"..callback_type][name] = nil
end

luablock.lbapi.register_callback = register_callback
luablock.lbapi.unregister_callback = unregister_callback

local callback_types = {
    "globalstep",
    "on_priv_grant",
    "on_priv_revoke",
    "on_modchannel_message",
    "on_chat_message",
    "on_chatcommand",
    "on_cheat",
    "on_dieplayer",
    "on_dignode",
    "on_item_eat",
    "on_rightclickplayer",
    "on_craft",
    "on_prejoinplayer",
    "on_joinplayer",
    "on_leaveplayer",
    "on_newplayer",
    "on_placenode",
    "allow_player_inventory_action",
    "on_player_inventory_action",
    "on_player_receive_fields",
    "on_protection_violation",
    "on_punchnode",
    "on_respawnplayer",
    "on_shutdown",
    "on_authplayer"
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
    if not minetest["register_"..callback_type] then
        error("'minetest.register_"..callback_type.."' does not exist.")
    end
    minetest["register_"..callback_type](function(...)
        run_callbacks(callback_type, ...)
    end)
end


--other functions that cannot be registered by the above code will be registered here

function luablock.lbapi.env.mtafter(t, f)
    if type(t) ~= "number" then return end
    if type(f) ~= "function" then return end
    minetest.after(t, function()
        local result, error = pcall(f)
        if not result then
            show_error(error)
        end
    end)
end


------------------------------------
--Lua Controller Block Environment--
------------------------------------

if minetest.get_modpath("mesecons_luacontroller_block") then

    local registered_lcb_modify_environments = {}

    function luablock.lbapi.env.register_lcb_modify_environment(name, func)
        registered_lcb_modify_environments[name] = func
    end

    function luablock.lbapi.env.unregister_lcb_modify_environment(name)
        registered_lcb_modify_environments[name] = nil
    end

    mesecon.register_luacontroller_block_modify_environment(function(pos, env)
        env.luablock = {}
        for _, func in pairs(registered_lcb_modify_environments) do
            func(pos, env)
        end
    end)

end