-- Lua Block Code--
------------------
-- The following code is responsible for storing and running the code stored in the Lua Blocks
-- 'luablock.code' is a global table that contains values that are keyed by a position string produced by 'minetest.pos_to_string'
local load_memory = function(pos)
    local meta = minetest.get_meta(pos)
    return minetest.deserialize(meta:get_string("memory")) or {}
end

local save_memory = function(pos, memory)
    local meta = minetest.get_meta(pos)
    meta:set_string("memory", minetest.serialize(memory))
end

local function luablock_create_env(pos)
    local is_on = luablock.is_on(pos)
    local env = {}
    env.here = pos
    env.state = {}
    env.state.on = is_on
    env.state.off = not is_on
    env.memory = load_memory(pos)
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
    env.luablock_network_send = function(network, channel, msg)
        luablock.network_send(pos, network, minetest.get_node(pos), channel, msg)
    end

    -- lbapi
    for k, v in pairs(luablock.lbapi.env) do
        env[k] = v
    end

    setmetatable(env, {
        __index = _G
    })
    return env
end

local luablock_execute = function(pos, code, type)
    local env = luablock_create_env(pos)
    setfenv(code, env)
    local result = code()
    save_memory(pos, env.memory)
    local code = luablock.code[minetest.pos_to_string(pos)]
    local error = minetest.get_meta(pos):get_string("error")
    if type == "receptor" then
        if result then
            minetest.set_node(pos, {
                name = "luablock:luablock_receptor_on"
            })
            luablock.code[minetest.pos_to_string(pos)] = code
            minetest.get_meta(pos):set_string("error", error)
            mesecon.receptor_on(pos, mesecon.rules.default)
        else
            minetest.set_node(pos, {
                name = "luablock:luablock_receptor_off"
            })
            luablock.code[minetest.pos_to_string(pos)] = code
            minetest.get_meta(pos):set_string("error", error)
            mesecon.receptor_off(pos, mesecon.rules.default)
        end
    end
    save_memory(pos, env.memory)
end

-- Nodes & Formspecs--
---------------------
-- Registeration of nodes, formspec data, and receive fields

local rules = {{
    x = 1,
    y = 0,
    z = 0
}, {
    x = -1,
    y = 0,
    z = 0
}, {
    x = 0,
    y = 1,
    z = 0
}, {
    x = 0,
    y = -1,
    z = 0
}, {
    x = 0,
    y = 0,
    z = 1
}, {
    x = 0,
    y = 0,
    z = -1
}}

local get_execute_on_globalstep = function(pos)
    local meta = minetest.get_meta(pos)
    local execute_on_globalstep = meta:get_string("execute_on_globalstep")
    if execute_on_globalstep ~= "true" then
        execute_on_globalstep = "false"
    end
    return execute_on_globalstep
end

minetest.register_abm({
    label = "luablock_receptor",
    nodenames = {"luablock:luablock_receptor_off", "luablock:luablock_receptor_on"},
    interval = 0.1,
    chance = 1,
    action = function(pos)
        local meta = minetest.get_meta(pos)
        local s_code = luablock.code[minetest.pos_to_string(pos)] or ""
        local code, errMsg = loadstring(s_code);
        local success, err = pcall(luablock_execute, pos, code, "receptor")
        meta:set_string("error", errMsg or err)
    end
})

minetest.register_abm({
    label = "luablock_effector",
    nodenames = {"luablock:luablock_effector_off", "luablock:luablock_effector_on"},
    interval = 0.1,
    chance = 1,
    action = function(pos)
        local node_name = minetest.get_node(pos).name
        local meta = minetest.get_meta(pos)
        local allow_execute = false
        if meta:get_string("node_name") ~= node_name then
            allow_execute = true
        end
        if get_execute_on_globalstep(pos) == "true" then
            allow_execute = true
        end

        if allow_execute then
            local s_code = luablock.code[minetest.pos_to_string(pos)] or ""
            local code, errMsg = loadstring(s_code);
            local success, err = pcall(luablock_execute, pos, code, "effector")
            meta:set_string("error", errMsg or err)
            meta:set_string("node_name", node_name)
        end
    end
})

minetest.register_abm({
    label = "luablock_conductor",
    nodenames = {"luablock:luablock_conductor_off", "luablock:luablock_conductor_on"},
    interval = 0.1,
    chance = 1,
    action = function(pos)
        local node_name = minetest.get_node(pos).name
        local meta = minetest.get_meta(pos)
        local allow_execute = false
        if meta:get_string("node_name") ~= node_name then
            allow_execute = true
        end
        if get_execute_on_globalstep(pos) == "true" then
            allow_execute = true
        end

        if allow_execute then
            local s_code = luablock.code[minetest.pos_to_string(pos)] or ""
            local code, errMsg = loadstring(s_code);
            local success, err = pcall(luablock_execute, pos, code, "conductor")
            meta:set_string("error", errMsg or err)
            meta:set_string("node_name", node_name)
        end
    end
})

local preserve_metadata = function(pos, oldnode, oldmeta, drops)
    local key = minetest.pos_to_string(pos)
    if type(luablock.code[key]) == "string" and luablock.code[key] ~= "" then
        local description = minetest.registered_nodes[drops[1]:get_name()].description or ""
        luablock.itemstacks_code[key] = luablock.code[key]
        drops[1]:get_meta():set_string("old_pos", minetest.pos_to_string(pos))
        drops[1]:get_meta():set_string("description", description.." (With Code)")
    end
end

local restore_code = function(itemstack)
    local key = itemstack:get_meta():get_string("old_pos")
    if luablock.itemstacks_code[key] then
        luablock.code[key] = luablock.itemstacks_code[key]
    end
end

minetest.register_node("luablock:luablock_receptor_off", {
    description = "Lua Block (Receptor)",
    tiles = {"luablock_off.png"},
    paramtype = "light",
    is_ground_content = false,
    groups = {
        cracky = 3,
        stone = 2,
        oddly_breakable_by_hand = 3,
        not_in_creative_inventory = 1
    },
    default_execute_on_globalstep = "true",

    mesecons = {
        receptor = {
            state = mesecon.state.off,
            rules = rules
        }
    },

    is_luablock = true,

    preserve_metadata = preserve_metadata,

    after_place_node = function(pos, placer, itemstack)
        local can_use = minetest.check_player_privs(placer:get_player_name(), {
            server = true,
            luablock = true
        })
        if not can_use then
            minetest.remove_node(pos)
            minetest.chat_send_player(placer:get_player_name(), "You do not have permission to place this node.")
        else
            restore_code(itemstack)
        end
    end,

    can_dig = function(pos, player)
        local can_use = minetest.check_player_privs(player:get_player_name(), {
            server = true,
            luablock = true
        })
        if not can_use then
            minetest.chat_send_player(player:get_player_name(), "You do not have permission to dig this node.")
        end
        return can_use
    end,

    on_rightclick = function(pos, node, clicker, itemstack)
        local can_use = minetest.check_player_privs(clicker:get_player_name(), {
            server = true,
            luablock = true
        })
        local can_view = minetest.check_player_privs(clicker:get_player_name(), {
            luablock_view = true
        })
        if can_use then
            clicker:get_meta():set_string("luablock:pos", minetest.pos_to_string(pos))
            minetest.show_formspec(clicker:get_player_name(), "luablock:luablock_formspec", luablock.formspec(pos, true))
        elseif can_view then
            minetest.show_formspec(clicker:get_player_name(), "luablock:luablock_view_formspec",
                luablock.formspec_view(pos))
        end
    end
})

minetest.register_node("luablock:luablock_receptor_on", {
    description = "Lua Block (Receptor)",
    tiles = {"luablock_on.png"},
    paramtype = "light",
    light_source = 14,
    is_ground_content = false,
    drop = {
        items = {{
            items = {'luablock:luablock_receptor_off'}
        }}
    },
    groups = {
        cracky = 3,
        stone = 2,
        oddly_breakable_by_hand = 3,
        not_in_creative_inventory = 1
    },
    default_execute_on_globalstep = "true",

    mesecons = {
        receptor = {
            state = mesecon.state.on,
            rules = rules
        }
    },

    is_luablock = true,

    preserve_metadata = preserve_metadata,

    after_place_node = function(pos, placer, itemstack)
        local can_use = minetest.check_player_privs(placer:get_player_name(), {
            server = true,
            luablock = true
        })
        if not can_use then
            minetest.remove_node(pos)
            minetest.chat_send_player(placer:get_player_name(), "You do not have permission to place this node.")
        else
            restore_code(itemstack)
        end
    end,

    can_dig = function(pos, player)
        local can_use = minetest.check_player_privs(player:get_player_name(), {
            server = true,
            luablock = true
        })
        if not can_use then
            minetest.chat_send_player(player:get_player_name(), "You do not have permission to dig this node.")
        end
        return can_use
    end,

    on_rightclick = function(pos, node, clicker, itemstack)
        local can_use = minetest.check_player_privs(clicker:get_player_name(), {
            server = true,
            luablock = true
        })
        local can_view = minetest.check_player_privs(clicker:get_player_name(), {
            luablock_view = true
        })
        if can_use then
            clicker:get_meta():set_string("luablock:pos", minetest.pos_to_string(pos))
            minetest.show_formspec(clicker:get_player_name(), "luablock:luablock_formspec", luablock.formspec(pos, true))
        elseif can_view then
            minetest.show_formspec(clicker:get_player_name(), "luablock:luablock_view_formspec",
                luablock.formspec_view(pos))
        end
    end,

    after_destruct = function(pos, oldnode)
        luablock.code[minetest.pos_to_string(pos)] = nil
    end
})

minetest.register_node("luablock:luablock_effector_off", {
    description = "Lua Block (Effector)",
    tiles = {"luablock_off.png"},
    paramtype = "light",
    is_ground_content = false,
    groups = {
        cracky = 3,
        stone = 2,
        oddly_breakable_by_hand = 3,
        not_in_creative_inventory = 1
    },
    default_execute_on_globalstep = "false",

    mesecons = {
        effector = {
            rules = rules,
            action_on = function(pos, node)
                minetest.swap_node(pos, {
                    name = "luablock:luablock_effector_on"
                })
            end
        }
    },

    is_luablock = true,

    preserve_metadata = preserve_metadata,

    after_place_node = function(pos, placer, itemstack)
        local can_use = minetest.check_player_privs(placer:get_player_name(), {
            server = true,
            luablock = true
        })
        if not can_use then
            minetest.remove_node(pos)
            minetest.chat_send_player(placer:get_player_name(), "You do not have permission to place this node.")
        else
            minetest.get_meta(pos):set_string("execute_on_globalstep", "false")
            restore_code(itemstack)
        end
    end,

    can_dig = function(pos, player)
        local can_use = minetest.check_player_privs(player:get_player_name(), {
            server = true,
            luablock = true
        })
        if not can_use then
            minetest.chat_send_player(player:get_player_name(), "You do not have permission to dig this node.")
        end
        return can_use
    end,

    on_rightclick = function(pos, node, clicker, itemstack)
        local can_use = minetest.check_player_privs(clicker:get_player_name(), {
            server = true,
            luablock = true
        })
        local can_view = minetest.check_player_privs(clicker:get_player_name(), {
            luablock_view = true
        })
        if can_use then
            clicker:get_meta():set_string("luablock:pos", minetest.pos_to_string(pos))
            minetest.show_formspec(clicker:get_player_name(), "luablock:luablock_formspec",
                luablock.formspec(pos, false))
        elseif can_view then
            minetest.show_formspec(clicker:get_player_name(), "luablock:luablock_view_formspec",
                luablock.formspec_view(pos))
        end
    end,

    after_destruct = function(pos, oldnode)
        luablock.code[minetest.pos_to_string(pos)] = nil
    end
})

minetest.register_node("luablock:luablock_effector_on", {
    description = "Lua Block (Effector)",
    tiles = {"luablock_on.png"},
    paramtype = "light",
    light_source = 14,
    is_ground_content = false,
    drop = {
        items = {{
            items = {'luablock:luablock_effector_off'}
        }}
    },
    groups = {
        cracky = 3,
        stone = 2,
        oddly_breakable_by_hand = 3,
        not_in_creative_inventory = 1
    },
    default_execute_on_globalstep = "false",

    mesecons = {
        effector = {
            rules = rules,
            action_off = function(pos, node)
                minetest.swap_node(pos, {
                    name = "luablock:luablock_effector_off"
                })
            end
        }
    },

    is_luablock = true,

    preserve_metadata = preserve_metadata,

    after_place_node = function(pos, placer, itemstack)
        local can_use = minetest.check_player_privs(placer:get_player_name(), {
            server = true,
            luablock = true
        })
        if not can_use then
            minetest.remove_node(pos)
            minetest.chat_send_player(placer:get_player_name(), "You do not have permission to place this node.")
        else
            minetest.get_meta(pos):set_string("execute_on_globalstep", "false")
            restore_code(itemstack)
        end
    end,

    can_dig = function(pos, player)
        local can_use = minetest.check_player_privs(player:get_player_name(), {
            server = true,
            luablock = true
        })
        if not can_use then
            minetest.chat_send_player(player:get_player_name(), "You do not have permission to dig this node.")
        end
        return can_use
    end,

    on_rightclick = function(pos, node, clicker, itemstack)
        local can_use = minetest.check_player_privs(clicker:get_player_name(), {
            server = true,
            luablock = true
        })
        local can_view = minetest.check_player_privs(clicker:get_player_name(), {
            luablock_view = true
        })
        if can_use then
            clicker:get_meta():set_string("luablock:pos", minetest.pos_to_string(pos))
            minetest.show_formspec(clicker:get_player_name(), "luablock:luablock_formspec",
                luablock.formspec(pos, false))
        elseif can_view then
            minetest.show_formspec(clicker:get_player_name(), "luablock:luablock_view_formspec",
                luablock.formspec_view(pos))
        end
    end,

    after_destruct = function(pos, oldnode)
        luablock.code[minetest.pos_to_string(pos)] = nil
    end
})

minetest.register_node("luablock:luablock_conductor_off", {
    description = "Lua Block (Conductor)",
    tiles = {"luablock_off.png"},
    paramtype = "light",
    is_ground_content = false,
    groups = {
        cracky = 3,
        stone = 2,
        oddly_breakable_by_hand = 3,
        not_in_creative_inventory = 1
    },
    default_execute_on_globalstep = "false",

    mesecons = {
        conductor = {
            state = mesecon.state.off,
            onstate = "luablock:luablock_conductor_on",
            offstate = "luablock:luablock_conductor_off",
            rules = rules
        }
    },

    is_luablock = true,

    preserve_metadata = preserve_metadata,

    after_place_node = function(pos, placer, itemstack)
        local can_use = minetest.check_player_privs(placer:get_player_name(), {
            server = true,
            luablock = true
        })
        if not can_use then
            minetest.remove_node(pos)
            minetest.chat_send_player(placer:get_player_name(), "You do not have permission to place this node.")
        else
            minetest.get_meta(pos):set_string("execute_on_globalstep", "false")
            restore_code(itemstack)
        end
    end,

    can_dig = function(pos, player)
        local can_use = minetest.check_player_privs(player:get_player_name(), {
            server = true,
            luablock = true
        })
        if not can_use then
            minetest.chat_send_player(player:get_player_name(), "You do not have permission to dig this node.")
        end
        return can_use
    end,

    on_rightclick = function(pos, node, clicker, itemstack)
        local can_use = minetest.check_player_privs(clicker:get_player_name(), {
            server = true,
            luablock = true
        })
        local can_view = minetest.check_player_privs(clicker:get_player_name(), {
            luablock_view = true
        })
        if can_use then
            clicker:get_meta():set_string("luablock:pos", minetest.pos_to_string(pos))
            minetest.show_formspec(clicker:get_player_name(), "luablock:luablock_formspec",
                luablock.formspec(pos, false))
        elseif can_view then
            minetest.show_formspec(clicker:get_player_name(), "luablock:luablock_view_formspec",
                luablock.formspec_view(pos))
        end
    end,

    after_destruct = function(pos, oldnode)
        luablock.code[minetest.pos_to_string(pos)] = nil
    end
})

minetest.register_node("luablock:luablock_conductor_on", {
    description = "Lua Block (Conductor)",
    tiles = {"luablock_on.png"},
    paramtype = "light",
    light_source = 14,
    is_ground_content = false,
    drop = {
        items = {{
            items = {'luablock:luablock_conductor_off'}
        }}
    },
    groups = {
        cracky = 3,
        stone = 2,
        oddly_breakable_by_hand = 3,
        not_in_creative_inventory = 1
    },
    default_execute_on_globalstep = "false",

    mesecons = {
        conductor = {
            state = mesecon.state.on,
            onstate = "luablock:luablock_conductor_on",
            offstate = "luablock:luablock_conductor_off",
            rules = rules
        }
    },

    is_luablock = true,

    preserve_metadata = preserve_metadata,

    after_place_node = function(pos, placer, itemstack)
        local can_use = minetest.check_player_privs(placer:get_player_name(), {
            server = true,
            luablock = true
        })
        if not can_use then
            minetest.remove_node(pos)
            minetest.chat_send_player(placer:get_player_name(), "You do not have permission to place this node.")
        else
            minetest.get_meta(pos):set_string("execute_on_globalstep", "false")
            restore_code(itemstack)
        end
    end,

    can_dig = function(pos, player)
        local can_use = minetest.check_player_privs(player:get_player_name(), {
            server = true,
            luablock = true
        })
        if not can_use then
            minetest.chat_send_player(player:get_player_name(), "You do not have permission to dig this node.")
        end
        return can_use
    end,

    on_rightclick = function(pos, node, clicker, itemstack)
        local can_use = minetest.check_player_privs(clicker:get_player_name(), {
            server = true,
            luablock = true
        })
        local can_view = minetest.check_player_privs(clicker:get_player_name(), {
            luablock_view = true
        })
        if can_use then
            clicker:get_meta():set_string("luablock:pos", minetest.pos_to_string(pos))
            minetest.show_formspec(clicker:get_player_name(), "luablock:luablock_formspec",
                luablock.formspec(pos, false))
        elseif can_view then
            minetest.show_formspec(clicker:get_player_name(), "luablock:luablock_view_formspec",
                luablock.formspec_view(pos))
        end
    end,

    after_destruct = function(pos, oldnode)
        luablock.code[minetest.pos_to_string(pos)] = nil
    end
})

function luablock.is_on(pos)
    local node = minetest.get_node(pos)
    if node.name == "luablock:luablock_receptor_on" or node.name == "luablock:luablock_effector_on" or node.name ==
        "luablock:luablock_conductor_on" then
        return true
    end
    return false
end

-- formspec_version[4]
-- size[14,16]
-- textarea[0.9,0.9;12,11.3;code;Code;]
-- button[5,14.7;4,0.8;execute;Execute]
-- textarea[0.9,12.9;12,1.5;error;Error;]

-- formspec_version[4]
-- size[14,16]
-- textarea[0.9,1.6;12,10.6;code;Code;]
-- button[5,14.7;4,0.8;execute;Execute]
-- textarea[0.9,12.9;12,1.5;error;Error;]
-- checkbox[0.9,0.7;execute_on_globalstep;Execute on Globalstep;false]

function luablock.formspec(pos, globalstep_only)
    local meta = minetest.get_meta(pos)
    local code = luablock.code[minetest.pos_to_string(pos)] or ""
    local error = meta:get_string("error")
    local execute_on_globalstep = meta:get_string("execute_on_globalstep")
    if execute_on_globalstep == "" then
        execute_on_globalstep = minetest.registered_nodes[minetest.get_node(pos).name].default_execute_on_globalstep
    end

    local formspec_globalstep_only = "formspec_version[4]" .. "size[14,16]" .. "textarea[0.9,0.9;12,11.3;code;Code;" ..
                                         minetest.formspec_escape(code) .. "]" .. "button[5,14.7;4,0.8;execute;Execute]" ..
                                         "textarea[0.9,12.9;12,1.5;error;Error;" .. minetest.formspec_escape(error) ..
                                         "]"

    local formspec = "formspec_version[4]" .. "size[14,16]" .. "textarea[0.9,1.6;12,10.6;code;Code;" ..
                         minetest.formspec_escape(code) .. "]" .. "button[5,14.7;4,0.8;execute;Execute]" ..
                         "textarea[0.9,12.9;12,1.5;error;Error;" .. minetest.formspec_escape(error) .. "]" ..
                         "checkbox[0.9,0.7;execute_on_globalstep;Execute on Globalstep;" .. execute_on_globalstep .. "]"

    if globalstep_only then
        return formspec_globalstep_only
    end
    return formspec
end

function luablock.formspec_view(pos)
    local meta = minetest.get_meta(pos)
    local code = luablock.code[minetest.pos_to_string(pos)] or ""
    local formspec = "formspec_version[5]" .. "size[14,16]" .. "textarea[0.9,0.9;12,14.6;code;Code;" ..
                         minetest.formspec_escape(code) .. "]"
    return formspec
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "luablock:luablock_formspec" then
        local is_approved = minetest.check_player_privs(player:get_player_name(), {
            server = true,
            luablock = true
        })
        if is_approved then
            local meta = player:get_meta()
            local pos = minetest.string_to_pos(meta:get_string("luablock:pos"))
            local node = minetest.registered_nodes[minetest.get_node(pos).name]
            local node_meta = minetest.get_meta(pos)
            if fields.execute then
                luablock.code[minetest.pos_to_string(pos)] = fields.code
                luablock.save_code()
            elseif fields.execute_on_globalstep then
                node_meta:set_string("execute_on_globalstep", fields.execute_on_globalstep)
            end
        end
    end
end)
