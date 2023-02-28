--This luatool code fills up a shop's stock from the [currency] mod.
--Add something to the 'owner wants' inventory of a 'currency:shop' or 'currency:shop_empty' node.
--Left click the node with Lua Tool in your hand and the shop's stock will be filled to the maximum

local function fill_shop(pos)
    local node = minetest.get_node(pos)
    if node.name == "currency:shop"
    or node.name == "currency:shop_empty"
    or node.name == "online_shop:shop_server" then
        local inv = minetest.get_inventory({type="node", pos=pos})
        local stock = {}
        local size = inv:get_size("stock")
        local c = 1
        for i=1, size do
            for _, stack in pairs(inv:get_list("owner_gives")) do
                if c <= size then
                    if stack:get_name() ~= "" then
                        stack:set_count(stack:get_stack_max())
                        table.insert(stock, stack)
                        c = c + 1
                    end
                end
            end
        end
        
        inv:set_list("stock", stock)
        if node.name == "currency:shop_empty" then
            node.name = "currency:shop"
            minetest.swap_node(pos, node)
            local meta = minetest.get_meta(pos)
            local owner = meta:get_string("owner")
            meta:set_string("infotext", "Exchange shop (owned by "..owner..")")
        end
    end
end

luatool.callbacks.on_use = function(itemstack, user, pointed_thing)
    local pos = pointed_thing.under
    fill_shop(pos)
end