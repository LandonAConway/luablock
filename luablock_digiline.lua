-- Digiline Rules--
------------------
-- This is a global variable and is used in the section below, so it must be created on top.
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

-----------------
--Mesecons Code--
-----------------

local ports = {
    a = { --3
        x = 1,
        y = 0,
        z = 0
    },
    b = { --5
        x = 0,
        y = 0,
        z = 1
    },
    c = { --4
        x = -1,
        y = 0,
        z = 0
    },
    d = { --6
        x = 0,
        y = 0,
        z = -1
    },
    e = { --2
        x = 0,
        y = -1,
        z = 0
    },
    f = { --1
        x = 0,
        y = 1,
        z = 0
    }
}

local port_names = {
    ["100"] = "a",
    ["001"] = "b",
    ["-100"] = "c",
    ["00-1"] = "d",
    ["0-10"] = "e",
    ["010"] = "f"
}

local get_node_name = function(ports)
    local _port_names = {"a","b","c","d","e","f"}
    local id = ""
    for _, port in pairs(_port_names) do
        if ports[port] == true then
            id = id.."1"
        elseif not ports[port] then
            id = id.."0"
        end
    end
    if id == "000000" then
        return "luablock:luablock_digilines"
    end
    return "luablock:luablock_digilines_"..id
end

local get_input_rules = function(node)
    return minetest.registered_nodes[node.name].mesecons.effector.rules
end

local get_output_rules = function(node)
    return minetest.registered_nodes[node.name].mesecons.receptor.rules
end

local get_ports = function(pos, reset)
    local ports = {a=false,b=false,c=false,d=false,e=false,f=false}
    if not reset then
        local output_rules = get_output_rules(minetest.get_node(pos))
        for _, rule in pairs(output_rules) do
            local port_name = port_names[rule.x..rule.y..rule.z]
            ports[port_name] = true
        end
    end
    return ports
end

local get_pins = function(pos)
    return minetest.deserialize(minetest.get_meta(pos):get_string("pins")) or {
        a = false,
        b = false,
        c = false,
        d = false,
        e = false,
        f = false
    }
end

local set_pin = function(pos, rule_name, new_state)
    local pins = get_pins(pos)
    if rule_name then
        local pin_name = port_names[rule_name.x..rule_name.y..rule_name.z]
        if new_state == "off" then
            pins[pin_name] = false
        elseif new_state == "on" then
            pins[pin_name] = true
        end
    end
    minetest.get_meta(pos):set_string("pins", minetest.serialize(pins))
end

local set_new_state = function(pos, _ports, reset)
    local old_ports = get_ports(pos, false)
    local node_name = minetest.get_node(pos).name
    local pins = get_pins(pos)
    for port_name, state in pairs(_ports) do
        if pins[port_name] == true then
            _ports[port_name] = false
        end
    end
    local new_node_name = get_node_name(_ports)
    minetest.swap_node(pos, {name=new_node_name})
    

    if reset then
        mesecon.receptor_on(pos, get_output_rules({name=new_node_name}))
        mesecon.receptor_off(pos, get_input_rules({name=new_node_name}))
    else
        local input_rules = {}
        local output_rules = {}
        local new_ports = get_ports(pos, false)
        local _port_names = {"a","b","c","d","e","f"}
        for _, port_name in pairs(_port_names) do
            --check if port changed
            if new_ports[port_name] ~= old_ports[port_name] then
                local port = new_ports[port_name]
                if port == true and pins[port_name] ~= true then
                    table.insert(output_rules, ports[port_name])
                else
                    table.insert(input_rules, ports[port_name])
                end
            end
        end
        mesecon.receptor_on(pos, output_rules)
        mesecon.receptor_off(pos, input_rules)
    end
end

local interrupts = {}

local initialize_interrupt_pos = function(pos)
    interrupts[minetest.pos_to_string(pos)] = interrupts[minetest.pos_to_string(pos)] or {}
    return interrupts[minetest.pos_to_string(pos)]
end

local perform_interrupt = function(pos, time, iid)
    local intp = initialize_interrupt_pos(pos)
    time = time or 0
    iid = iid or 0
    if not intp[iid] then
        intp[iid] = true
        minetest.after(time, function()
            if luablock.code[minetest.pos_to_string(pos)] then
                luablock.handle_digilines_action(pos, minetest.get_node(pos), "", {type="interrupt",iid=iid})
            end
            intp[iid] = nil
        end)
    end
end

------------------
-- Luablock Code--
------------------
local luablock_messages = {}

local luablock_send = function(pos, channel, msg, _rules)
    local random = 0
    repeat
        random = math.random(1, 1000000)
    until not luablock_messages["uid" .. random]

    local uid = "uid" .. random
    luablock_messages[uid] = msg

    digiline:receptor_send(pos, _rules or rules, channel, {
        type = "luablock_msg",
        uid = uid
    })
    
    minetest.after(5, function()
        luablock_messages[uid] = nil
    end)
end

local luablock_recieve = function(uid)
    return luablock_messages[uid]
end

-- expose luablock_send
luablock.luablock_send = luablock_send

local set_error = function(pos, error)
    local meta = minetest.get_meta(pos)
    meta:set_string("error", error or "")
end

local load_memory = function(pos)
    local meta = minetest.get_meta(pos)
    return minetest.deserialize(meta:get_string("memory")) or {}
end

local save_memory = function(pos, memory)
    local meta = minetest.get_meta(pos)
    meta:set_string("memory", minetest.serialize(memory))
end

-- This code handles the callbacks for the node's inventory and timer
luablock.callbacks = {}

local register_luablock_callback = function(pos, name, func)
    local _pos = minetest.pos_to_string(pos)
    luablock.callbacks[_pos] = luablock.callbacks[_pos] or {}
    if type(func) ~= "function" then
        func = nil
    end
    luablock.callbacks[_pos][name] = func
end

local call_luablock_callback = function(pos, name, ...)
    local callback = luablock.callbacks[minetest.pos_to_string(pos)][name]
    if type(callback) == "function" then
        local status, err = pcall(callback, ...)
        if not status then
            minetest.get_meta(pos):set_string("error", "luablock callback error:" .. tostring(err))
        else
            return err
        end
    end
end

--networks
local load_networks = function()
    return minetest.deserialize(luablock.mod_storage.get_string("networks")) or {}
end

local save_networks = function()
    luablock.mod_storage.set_string("networks", minetest.serialize(luablock.networks))
end

luablock.networks = load_networks()

local set_network_error = function(pos, error)
    local node = minetest.get_node(pos)
    local nodedef = minetest.registered_nodes[node.name] or {}
    if not nodedef.is_digilines_luablock == true then return end
    minetest.get_meta(pos):set_string("network_error", error or "")
end

local get_network_error = function(pos)
    local error = minetest.get_meta(pos):get_string("network_error")
    if error ~= "" then
        return error
    end
end

local get_network_data = function(pos)
    local meta = minetest.get_meta(pos)
    local network_name = meta:get_string("network")
    local node = minetest.get_node(pos)
    local node_def = minetest.registered_nodes[node.name]
    local data = {}
    data.pos = pos
    data.is_luablock = (node_def.is_luablock == true)
    data.is_digilines_luablock = (node_def.is_digilines_luablock == true)
    data.is_private = true
    local network = luablock.networks[network_name]
    if network then
        data.network_name = network_name
        data.is_private = false
    end
    return data
end

function luablock.network_set_response(network_name, response)
    local network = luablock.networks[network_name]
    if network then
        network.response = response
        minetest.after(5, function()
            network.response = nil
        end)
    end
end

local network_get_response = function(network_name)
    local network = luablock.networks[network_name]
    if network then
        return network.response
    end
end

function luablock.network_send(from_pos, network_name, channel, msg)
    local nt = type(network_name)
    if nt == "string" then
        set_network_error(from_pos)
        local network = luablock.networks[network_name]
        if network then
            local node = minetest.get_node(network.pos)
            local _msg = {
                type = "luablock_network_msg",
                snd = get_network_data(from_pos),
                msg = msg
            }
            if minetest.registered_nodes[node.name].is_digilines_luablock then
                luablock.handle_digilines_action(network.pos, node, channel, _msg)
                local response = network_get_response(network_name)
                return true, response
            end
        end
        set_network_error(from_pos, "network error: network \""..network_name.."\" could not be found.")
    else
        error("string expected, got "..nt)
    end
    return false
end

local remove_network = function(pos)
    local network_name = minetest.get_meta(pos):get_string("network")
    luablock.networks[network_name] = nil
    save_networks()
end

local set_network = function(pos, name)
    local meta = minetest.get_meta(pos)
    remove_network(pos)
    meta:set_string("network", name)
    if type(name) == "string" and name ~= "" then
        local network = luablock.networks[name]
        if not network or (minetest.pos_to_string(pos) == minetest.pos_to_string(network.pos)) then
            luablock.networks[name] = {name=name,pos=pos}
            set_network_error(pos)
        else
            set_network_error(pos, "network error: network "..
                "'"..name.."' is already registered at a different location.")
        end
    else
        set_network_error(pos)
    end
    save_networks()
end

-- This code is responsible for executing the code that belongs to an individual Lua Block
local luablock_digilines_execute_internal = function(pos, event)
    local execute = function(pos, _code)
        -- environment
        local env = {}
        env.luablock = {
            memory = load_memory(pos),
            event = event,
            pin = get_pins(pos),
            port = get_ports(pos, event.type == "program"),
            callbacks = {},
        }
        env.here = pos
        env.luablock_send = function(channel, msg)
            luablock_send(pos, channel, msg)
        end
        env.luablock_network_send = function(network_name, channel, msg)
            local data = get_network_data(pos)
            if network_name ~= data.network_name then
                set_network_error(pos)
                return luablock.network_send(pos, network_name, channel, msg)
            else
                set_network_error(pos, "network error: a network cannot send a message to itself.")
            end
        end
        env.luablock_network_set_response = function(response)
            local data = get_network_data(pos)
            local network_name = data.network_name
            if luablock.networks[network_name] then
                luablock.network_set_response(network_name, response)
                set_network_error(pos)
            else
                set_network_error(pos, "network error: luablock is not set as a network.")
            end
        end
        env.luablock_network_ping = function(network_name)
            return type(luablock.networks[network_name]) == "table"
        end
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
        env.interrupt = function(time, iid)
            if type(time) ~= "number" then time = 0 end
            if type(iid) ~= "string" then iid = "" end
            perform_interrupt(pos, time, iid)
        end
        env.digiline_send = function(channel, msg)
            digiline:receptor_send(pos, rules, channel, msg)
        end
        env.load_memory = function(_pos)
            if not _pos then
                _pos = pos
            end
            return load_memory(_pos)
        end
        env.save_memory = function(arg1, arg2)
            local _pos
            local memory
            if arg1 and arg2 then
                _pos = arg1
                memory = arg2
            elseif arg1 and not arg2 then
                _pos = pos
                memory = arg1
            elseif not arg1 and not arg2 then
                _pos = pos
                memory = env.luablock.memory or {}
            end
            save_memory(_pos, memory or {})
        end
        -- lbapi
        for k, v in pairs(luablock.lbapi.env) do
            env[k] = v
        end
        setmetatable(env, {
            __index = _G
        })
        setfenv(_code, env)

        -- execute code
        local result = _code()

        -- register callbacks
        local callback_names = {"on_timer", "on_receive_fields", "allow_metadata_inventory_move",
                                "allow_metadata_inventory_put", "allow_metadata_inventory_take",
                                "on_metadata_inventory_move", "on_metadata_inventory_put", "on_metadata_inventory_take"}

        for _, callback_name in pairs(callback_names) do
            register_luablock_callback(pos, callback_name, env.luablock.callbacks[callback_name])
        end

        -- save memory
        save_memory(pos, env.luablock.memory or {})

        -- set ports
        local reset = event.type == "program"
        if env.luablock.reset_ports == true then
            reset = true
        end
        set_new_state(pos, env.luablock.port or {}, reset)

        -- return result
        if type(result) ~= "table" then
            return {}
        end

        return result
    end

    local meta = minetest.get_meta(pos)
    local s_code = luablock.code[minetest.pos_to_string(pos)] or ""
    local code, errMsg = loadstring(s_code);
    local success, result = pcall(execute, pos, code)
    local network_error = get_network_error(pos)
    
    if network_error then
        set_error(pos, network_error)
    end

    local set_err = false
    local err = ""
    if not code then
        err = errMsg
        set_err = true
    elseif not success then
        err = result
        set_err = true
    end
    
    if set_err then
        set_error(pos, err)
    else
        return result
    end
    return {}
end

local timeout = function()
    debug.sethook()
    error("Timed out.")
end

local luablock_digilines_execute_external = function(pos, code, env, metatable, hook)
    local execute = function(pos, _code)
        -- environment
        setmetatable(env, metatable or {})
        setfenv(_code, env)

        -- debug.set_hook
        if hook then
            debug.sethook(timeout, "", hook)
        end

        -- execute code
        return {
            result = _code()
        }
    end

    local func, errMsg = loadstring(code);
    local success, result = pcall(execute, pos, func)
    debug.sethook()

    if type(result) == "table" then
        return result.result
    else
        local meta = minetest.get_meta(pos)
        set_error(pos, "external error:" .. result)
    end
end

-----------------
--Digiline Code--
-----------------
function luablock.handle_digilines_action(pos, node, channel, msg)
    --ensure the area is loaded to prevent errors
    minetest.load_area(
        vector.offset(pos, 5, 5, 5),
        vector.offset(pos, -5,-5,-5)
    )
    local meta = minetest.get_meta(pos)
    local setchannel = meta:get_string("channel")
    local receive_all_events = meta:get_string("receive_all_events")
    if receive_all_events ~= "true" then
        if channel ~= setchannel then
            return
        end
    end
    -- if type(msg) ~= "table" and type(msg) ~= "string" then return end
    if type(msg) ~= "table" then
        msg = {
            type = "unspecified",
            msg = msg
        }
    elseif type(msg) == "table" and type(msg.type) ~= "string" and type(msg.code) ~= "string" then
        msg = {
            type = "unspecified",
            msg = msg
        }
    end

    msg.type = msg.type or "unspecified"

    meta:set_string("error", "")

    if msg.type == "execute_code" then
        local event = {
            type = msg.type,
            channel = channel,
            msg = msg,
            extra_data = msg.extra_data or {}
        }

        -- executes the code with the full environment. This can only be edited
        -- by people with the 'luablock' priv.
        local result = luablock_digilines_execute_internal(pos, event)

        -- handle the environment returned by the internal, and external code
        local env = result.environment or {}
        local metatable = result.metatable or {}
        local code = ""
        -- get the second environment from digiline_send
        local _env = {}

        if type(msg.code) == "string" then
            code = msg.code
        elseif type(msg.func) == "string" then
            code = msg.func
        elseif type(msg[1]) == "string" then
            code = msg[1]
        elseif type(msg[2]) == "string" then
            code = msg[2]
        end

        if type(msg.environment) == "table" then
            _env = msg.environment
        elseif type(msg.env) == "table" then
            _env = msg.env
        elseif type(msg[1]) == "table" then
            _env = msg[1]
        elseif type(msg[2]) == "table" then
            _env = msg[2]
        end

        -- merge the second environment with the main one
        for k, v in pairs(_env) do
            env[k] = env[k] or v
        end

        -- handle hook
        -- The below code configures how debug.set_hook will be used when the local variable 'hook' is passed to
        -- 'luablock_digilines_execute_external'.
        -- If 'hook' is set to nil when passed to 'luablock_digilines_execute_external' then debug.set_hook will not be used.
        -- If 'hook' is a string and is equel to "infinite" then 'hook' will be passed as nil. Otherwise it will be passed as
        -- as a number set to 25000.
        -- If 'hook' is nil or is not a number, then 'hook' will be passed as a number set to 25000.

        local hook = result.hook
        if type(hook) == "string" then
            if hook == "infinite" then
                hook = nil
            else
                hook = 25000
            end
        elseif type(hook) ~= "number" then
            hook = 25000
        end

        -- execute external code
        if type(env) == "table" then
            luablock_digilines_execute_external(pos, code, env, metatable, hook)
        end
    elseif msg.type == "execute_luablock" then
        local event = {
            type = msg.type,
            channel = channel,
            msg = msg
        }
        luablock_digilines_execute_internal(pos, event)
    elseif msg.type == "msg" then
        local event = {
            type = msg.type,
            channel = channel,
            msg = msg.msg,
            full_msg = msg
        }
        luablock_digilines_execute_internal(pos, event)
    elseif msg.type == "luablock_msg" and type(msg.uid) == "string" then
        local luablock_msg = luablock_recieve(msg.uid)
        local event = {
            type = msg.type,
            channel = channel,
            msg = luablock_msg
        }
        luablock_digilines_execute_internal(pos, event)
    elseif msg.type == "luablock_network_msg" then
        local event = {
            type = msg.type,
            channel = channel,
            snd = msg.snd,
            msg = msg.msg
        }
        luablock_digilines_execute_internal(pos, event)
    elseif msg.type == "off" then
        local event = {
            type = msg.type,
            channel = "",
            msg = {}
        }
        luablock_digilines_execute_internal(pos, event)
    elseif msg.type == "on" then
        local event = {
            type = msg.type,
            channel = "",
            msg = {}
        }
        luablock_digilines_execute_internal(pos, event)
    elseif msg.type == "program" then
        local event = {
            type = msg.type,
            channel = "",
            msg = {}
        }
        luablock_digilines_execute_internal(pos, event)
    elseif msg.type == "interrupt" then
        local event = {
            type = msg.type,
            channel = "",
            iid = msg.iid or "",
            msg = {}
        }
        luablock_digilines_execute_internal(pos, event)
    elseif msg.type == "unspecified" then
        local event = {
            type = msg.type,
            channel = channel,
            msg = msg.msg
        }
        luablock_digilines_execute_internal(pos, event)
    end
end

-- Formspecs--
-------------

-- To be added
-- formspec_version[5]
-- size[14,19]
-- textarea[0.9,4.7;12,10.5;code;Code;]
-- button[5,17.7;4,0.8;execute;Execute]
-- textarea[0.9,15.9;12,1.5;error;Error;]
-- textarea[0.9,3.3;12,0.7;channel;Channel;]
-- checkbox[0.9,0.7;receive_all_events;Receive All Events;false]
-- field[0.9,1.9;12,0.7;network;Network;]

-- formspec_version[5]
-- size[14,17]
-- textarea[0.9,3.3;12,9.9;code;Code;]
-- button[5,15.7;4,0.8;execute;Execute]
-- textarea[0.9,13.9;12,1.5;error;Error;]
-- textarea[0.9,1.9;12,0.7;channel;Channel;]
-- checkbox[0.9,0.7;receive_all_events;Receive All Events;false]

function luablock.digilines_formspec(pos)
    local meta = minetest.get_meta(pos)
    local recieve_all_events = meta:get_string("receive_all_events")
    local code = luablock.code[minetest.pos_to_string(pos)] or ""
    local error = meta:get_string("error")
    local channel = meta:get_string("channel")
    local network = meta:get_string("network")

    if recieve_all_events ~= "true" then
        recieve_all_events = "false"
    end

    local formspec = "formspec_version[5]" .. "size[14,19]" .. 
        "textarea[0.9,4.7;12,10.5;code;Code;" .. minetest.formspec_escape(code) .. "]" ..
        "button[5,17.7;4,0.8;execute;Execute]" ..
        "textarea[0.9,15.9;12,1.5;error;Error;" .. minetest.formspec_escape(error) .. "]" ..
        "field[0.9,1.9;12,0.7;network;Network;" .. minetest.formspec_escape(network) .. "]" ..
        "field[0.9,3.3;12,0.7;channel;Channel;" .. minetest.formspec_escape(channel) .. "]" ..
        "checkbox[0.9,0.7;receive_all_events;Receive All Events;" .. recieve_all_events .. "]"

    return formspec
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "luablock:luablock_digilines_formspec_"..player:get_player_name() then
        local is_approved = minetest.check_player_privs(player:get_player_name(), {
            server = true,
            luablock = true
        })
        if is_approved then
            local name = player:get_player_name()
            local meta = player:get_meta()
            local pos = minetest.string_to_pos(meta:get_string("luablock:pos"))
            local node = minetest.registered_nodes[minetest.get_node(pos).name]
            local node_meta = minetest.get_meta(pos)
            if fields.execute then
                node_meta:set_string("channel", fields.channel)
                set_network(pos, fields.network)
                luablock.code[minetest.pos_to_string(pos)] = fields.code
                luablock.save_code()
                luablock.handle_digilines_action(pos, node, "", {type="program"})
                minetest.show_formspec(name, "luablock:luablock_digilines_formspec_"..name,
                    luablock.digilines_formspec(pos))
            elseif fields.receive_all_events then
                node_meta:set_string("receive_all_events", fields.receive_all_events)
            end
        end
    end
end)

----------------------
--Node Registrations--
----------------------

local preserve_metadata = function(pos, oldnode, oldmeta, drops)
    local key = minetest.pos_to_string(pos)
    if type(luablock.code[key]) == "string" and luablock.code[key] ~= "" then
        luablock.itemstacks_code[key] = luablock.code[key]
        drops[1]:get_meta():set_string("channel", oldmeta.channel)
        drops[1]:get_meta():set_string("memory", oldmeta.memory)
        drops[1]:get_meta():set_string("old_pos", minetest.pos_to_string(pos))
        drops[1]:get_meta():set_string("description", "Digilines Lua Block (With Code)")
    end
end

local restore_code = function(pos, itemstack)
    local key = itemstack:get_meta():get_string("old_pos")
    local meta = minetest.get_meta(pos)
    if luablock.itemstacks_code[key] then
        luablock.code[minetest.pos_to_string(pos)] = luablock.itemstacks_code[key]
        meta:set_string("channel", itemstack:get_meta():get_string("channel"))
        meta:set_string("memory", itemstack:get_meta():get_string("memory"))
    end
end

local luablock_def = {
    description = "Digilines Lua Block",
    groups = {
        cracky = 3,
        stone = 2,
        oddly_breakable_by_hand = 3,
        not_in_creative_inventory = 1
    },
    digiline = {
        receptor = {},
        wire = {
            rules = rules
        },
        effector = {
            action = function(pos, node, channel, msg)
                luablock.handle_digilines_action(pos, node, channel, msg)
            end
        }
    },
    is_luablock = true,
    is_digilines_luablock = true,

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
            restore_code(pos, itemstack)
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
            minetest.show_formspec(clicker:get_player_name(), "luablock:luablock_digilines_formspec_"..clicker:get_player_name(),
                luablock.digilines_formspec(pos))
        elseif can_view then
            minetest.show_formspec(clicker:get_player_name(), "luablock:luablock_view_formspec_"..clicker:get_player_name(),
                luablock.formspec_view(pos))
        end
    end,

    on_destruct = function(pos)
        remove_network(pos)
    end,

    after_destruct = function(pos, oldnode)
        luablock.code[minetest.pos_to_string(pos)] = nil
        luablock.callbacks[minetest.pos_to_string(pos)] = nil
    end,

    -- registerable callbacks in luablock code
    on_timer = function(pos, ...)
        local result
        call_luablock_callback(pos, "on_timer", pos, ...)
        if type(result) ~= "boolean" and type(result) ~= "nil" then
            return nil
        end
        return result
    end,
    on_receive_fields = function(pos, ...)
        return call_luablock_callback(pos, "on_receive_fields", pos, ...)
    end,
    allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
        local result = call_luablock_callback(pos, "allow_metadata_inventory_move", pos, from_list, from_index, to_list,
            to_index, count, player)
        if type(result) ~= "number" then
            return count
        end
        return result
    end,
    allow_metadata_inventory_put = function(pos, listname, index, stack, player)
        local result = call_luablock_callback(pos, "allow_metadata_inventory_put", pos, listname, index, stack, player)
        if type(result) ~= "number" then
            return stack:get_count()
        end
        return result
    end,
    allow_metadata_inventory_take = function(pos, listname, index, stack, player)
        local result = call_luablock_callback(pos, "allow_metadata_inventory_take", pos, listname, index, stack, player)
        if type(result) ~= "number" then
            return stack:get_count()
        end
        return result
    end,
    on_metadata_inventory_move = function(pos, ...)
        return call_luablock_callback(pos, "on_metadata_inventory_move", pos, ...)
    end,
    on_metadata_inventory_put = function(pos, ...)
        return call_luablock_callback(pos, "on_metadata_inventory_put", pos, ...)
    end,
    on_metadata_inventory_take = function(pos, ...)
        return call_luablock_callback(pos, "on_metadata_inventory_take", pos, ...)
    end
}

for a = 0, 1 do
for b = 0, 1 do
for c = 0, 1 do
for d = 0, 1 do
for e = 0, 1 do
for f = 0, 1 do
  local states = { a=a, b=b, c=c, d=d, e=e, f=f }
  local id = a..b..c..d..e..f
  local name = "luablock:luablock_digilines_"..id
  if id == "000000" then
      name = "luablock:luablock_digilines"
  end
  local state = mesecon.state.off
  local paramtype
  local light_source
  local drop
  if id ~= "000000" then
      state = mesecon.state.on
      paramtype = "light"
      light_source = 7
      drop = {
          items = {{
              items = {'luablock:luablock_digilines'}
          }}
      }
  end
  local output_rules = {}
  local input_rules = {}
  for port_name, _state in pairs(states) do
    if _state == 0 then
        table.insert(input_rules, ports[port_name])
    elseif _state == 1 then
        table.insert(output_rules, ports[port_name])
    end
  end
  local mesecons = {
        receptor = {
            state = state,
            rules = output_rules
        },
        effector = {
            rules = input_rules,
            action_change = function (pos, node, rule_name, new_state)
                set_pin(pos, rule_name, new_state)
                luablock.handle_digilines_action(pos, node, "", {type=new_state})
            end
        }
  }
  -- Textures of node; +Y, -Y, +X, -X, +Z, -Z
  local tiles = {}
  local tile_indexes = {a=3,b=5,c=4,d=6,e=2,f=1}
  for k, v in pairs(states) do
    local tile_index = tile_indexes[k]
    if v == 0 then
        tiles[tile_index] = "luablock_digilines.png"
    elseif v == 1 then
        tiles[tile_index] = "luablock_digilines_port_on.png"
    end
  end

  --node definition
  --create a shallow copy of the definition
  local def = {}
  for k, v in pairs(luablock_def) do
    def[k] = v
  end
  def.tiles = tiles
  def.paramtype = paramtype
  def.light_source = light_source
  def.drop = drop
  def.mesecons = mesecons

  --register the node here
  minetest.register_node(name, def)
end
end
end
end
end
end

---------------------------------------------
--Mesecons Lua Controller Block Environment--
---------------------------------------------

if minetest.get_modpath("mesecons_luacontroller_block") then

    mesecon.register_luacontroller_block_modify_environment(function(pos, env)
        env.luablock = env.luablock or {}
        env.luablock.network_send = function(network_name, channel, msg)
            return luablock.network_send(pos, network_name, channel, msg)
        end
        env.luablock.network_ping = function(network_name)
            return type(luablock.networks[network_name]) == "table"
        end
    end)

end