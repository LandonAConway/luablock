luablock = {}

minetest.register_privilege("luablock", { 
    description = "Allows player to place, dig, view, and edit Lua Blocks.",
    give_to_singleplayer = false
})

minetest.register_privilege("luablock_view", { 
    description = "Allows player to view Lua Blocks.",
    give_to_singleplayer = false
})

dofile(minetest.get_modpath("luablock") .. "/luablock.lua")
dofile(minetest.get_modpath("luablock") .. "/luablock_digiline.lua")