luablock = {}

luablock.mod_storage = {}
local mod_storage = minetest.get_mod_storage()
function luablock.mod_storage.set_string(key, value)
    mod_storage:set_string(key, value)
end
function luablock.mod_storage.get_string(key)
    return mod_storage:get_string(key)
end

minetest.register_privilege("luablock", { 
    description = "Allows player to place, dig, view, and edit Lua Blocks.",
    give_to_singleplayer = false
})

minetest.register_privilege("luablock_view", { 
    description = "Allows player to view Lua Blocks.",
    give_to_singleplayer = false
})

--Storing Code Of Lua Blocks--
------------------------------
local save_luablocks_code = function()
    luablock.mod_storage.set_string("luablocks_code", minetest.serialize(luablock.code))
    luablock.mod_storage.set_string("luablocks_itemstacks_code", minetest.serialize(luablock.itemstacks_code))
end

local load_luablocks_code = function()
    luablock.code = minetest.deserialize(luablock.mod_storage.get_string("luablocks_code")) or {}
    luablock.itemstacks_code = minetest.deserialize(luablock.mod_storage.get_string("luablocks_itemstacks_code")) or {}
end

luablock.save_code = save_luablocks_code

minetest.register_on_mods_loaded(function()
    load_luablocks_code()
end)

minetest.register_on_shutdown(function()
    save_luablocks_code()
end)

dofile(minetest.get_modpath("luablock") .. "/lbapi.lua")
dofile(minetest.get_modpath("luablock") .. "/luablock.lua")
dofile(minetest.get_modpath("luablock") .. "/luablock_digiline.lua")
dofile(minetest.get_modpath("luablock") .. "/luatool.lua")