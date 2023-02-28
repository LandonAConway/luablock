--This lua tool creates an explosion at the pos the user right clicks.
--Use '/luatool set_radius' to set the radius of the explosion

luatool.commands.set_radius = {
    func = function(name, text, stack)
        local radius = tonumber(text)
        if type(radius) == "number" then
            local mem = luatool.get_local_memory(stack)
            mem.radius = radius
        end
    end
}

luatool.callbacks.on_place = function(itemstack, placer, pointed_thing)
    if pointed_thing.type == "node" then
        local mem = luatool.get_local_memory(itemstack)
        local pos = pointed_thing.under
        tnt.boom(pos, {
            radius = mem.radius or 1
        })
    end
end