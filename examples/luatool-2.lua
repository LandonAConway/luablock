--This tool will drop all items from a chest or any node with inventory

luatool.callbacks.on_use = function(itemstack, user, pointed_thing)
    if pointed_thing.type == "node" then
        local pos = pointed_thing.under
        local droppos = user:get_pos()
        local inv = minetest.get_inventory({type="node", pos=pos})
        for listname, list in pairs(inv:get_lists()) do
            for _, stack in pairs(list) do
                inv:remove_item(listname, stack)
                minetest.item_drop(stack, user, droppos)
            end
        end
    end
end