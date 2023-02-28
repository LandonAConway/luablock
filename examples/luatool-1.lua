luatool.commands["set_value"] = {
    privs = { server = true },
    description = "Sets the value that will be displayed when left clicking the item.",
    func = function(name, text, stack)
        local mem = get_local_memory(stack)
        mem.value = text
    end
}

luatool.callbacks.on_use = function(itemstack, user, pointed_thing)
    local mem = get_local_memory(itemstack)
    minetest.chat_send_player(user:get_player_name(), "Value: "..mem.value)
end