-----------
--General--
-----------

local is_allowed = function(player)
    if type(player) == "string" then
        player = minetest.get_player_by_name(player)
    end
    return minetest.check_player_privs(player:get_player_name(), {server=true,luablock=true})
end

-----------
--Scripts--
-----------

luablock.scripts = {}

local load_scripts = function()
    luablock.scripts = minetest.deserialize(luablock.mod_storage.get_string("scripts")) or {}
end

local save_scripts = function()
    luablock.mod_storage.set_string("scripts", minetest.serialize(luablock.scripts))
end

minetest.register_on_mods_loaded(function()
    load_scripts()

    --run scripts
    for script_name, script in pairs(luablock.scripts) do
        if script.run_when_server_starts then
            luablock.run_script(script_name)
        end
    end
end)

function luablock.add_script(name, def)
    if type(name) == "string" and name ~= "" then
        def = def or {}
        def.name = name
        def.code = def.code or ""
        if type(def.run_when_server_starts) ~= "boolean" then
            def.run_when_server_starts = false
        end
        luablock.scripts[name] = def
    end
    save_scripts()
end

function luablock.update_script(name, def)
    local script = luablock.scripts[name or ""]
    if script then
        luablock.remove_script(name)
        luablock.add_script(name, def)
    end
    save_scripts()
end

function luablock.rename_script(name, newname)
    local script = luablock.scripts[name or ""]
    if script and type(newname) == "string" and newname ~= "" then
        luablock.remove_script(name)
        luablock.add_script(newname, script)
    end
    save_scripts()
end

function luablock.remove_script(name)
    luablock.scripts[name or ""] = nil
    save_scripts()
end

local show_error = function(error)
    for _, plr in pairs(minetest.get_connected_players()) do
        if is_allowed(plr) then
            minetest.chat_send_player(plr:get_player_name(), "Scripts Error: "..error)
        end
    end
end

function luablock.run_script(name, message)
    local script = luablock.scripts[name]
    if script then
        local execute = function(_code)
            --environment
            local env = {
                message = message
            }
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
            --lbapi
            for k, v in pairs(luablock.lbapi.env) do
                env[k] = v
            end
            setmetatable(env,{ __index = _G })
            setfenv(_code, env)
            
            --execute code
            local result = _code()
            return result
        end
        
        local scode = script.code
        local code, syntaxErrMsg = loadstring(scode);
        local success, errMsg = pcall(execute,code)
        if not code then
            show_error(syntaxErrMsg)
            return false, syntaxErrMsg
        elseif not success then
            show_error(tostring(errMsg))
            return false, errMsg
        end
        --in this case, errMsg is the return value of the script.
        return success, errMsg
    end
    return false, "script_not_found"
end

--add functions to lbapi
luablock.lbapi.env.get_script = function(name)
    return luablock.scripts[name]
end

luablock.lbapi.env.set_script = function(name, def)
    local script = luablock.scripts[name]
    if script then
        luablock.update_script(name, def)
    else
        luablock.add_script(name, def)
    end
end

luablock.lbapi.env.rename_script = function(name, newname)
    luablock.rename_script(name, newname)
end

luablock.lbapi.env.remove_script = function(name)
    luablock.remove_script(name)
end

luablock.lbapi.env.run_script = function(name, message)
    return luablock.run_script(name, message)
end

------------
--Formspec--
------------

local get_scripts_list = function(escape)
    local list = {}
    for name, _ in pairs(luablock.scripts) do
        local entry = name
        if escape then
            entry = minetest.formspec_escape(entry)
        end
        table.insert(list, entry)
    end
    table.sort(list)
    return list
end

-- "formspec_version[5]" ..
-- "size[25,15]" ..
-- "checkbox[8.5,0.5;run_when_server_starts;Run When Server Starts;false]" ..
-- "textlist[0.5,0.8;7.5,11.7;scripts;;1;false]" ..
-- "label[0.5,0.5;Scripts]" ..
-- "button[16.6,13.7;7.9,0.8;run;Run]" ..
-- "button[8.5,13.7;7.9,0.8;save;Save]" ..
-- "textarea[8.5,1.5;16,12;script;;default]" ..
-- "field[8.5,0.8;16,0.5;name;;default]" ..
-- "button[0.5,12.7;7.5,0.8;new;New]" ..
-- "button[0.5,13.7;7.5,0.8;delete;Delete]"

local scripts_formspec = function(player, index)
    index = index or 1
    local scripts_list = get_scripts_list(true)
    local scripts = table.concat(scripts_list, ",")
    local script = { name = "", code = "", run_when_server_starts = false }
    if scripts_list[index] then
        script = luablock.scripts[scripts_list[index]]
    end
    local formspec = "formspec_version[5]" ..
    "size[25,15]" ..
    "checkbox[8.5,0.5;run_when_server_starts;Run When Server Starts;"..tostring(script.run_when_server_starts).."]" ..
    "textlist[0.5,0.8;7.5,11.7;scripts;"..scripts..";"..index..";false]" ..
    "label[0.5,0.5;Scripts]" ..
    "button[16.6,13.7;7.9,0.8;run;Run]" ..
    "button[8.5,13.7;7.9,0.8;save;Save]" ..
    "textarea[8.5,1.5;16,12;script;;"..minetest.formspec_escape(script.code).."]" ..
    "field[8.5,0.8;16,0.5;name;;"..minetest.formspec_escape(script.name).."]" ..
    "button[0.5,12.7;7.5,0.8;new;New]" ..
    "button[0.5,13.7;7.5,0.8;delete;Delete]"

    return formspec
end

local toboolean = function(value)
    if value == "true" then
        return true
    end
    return false
end

local get_index_at_name = function(script_name)
    local scripts_list = get_scripts_list()
    local by_index = {}
    for k, v in pairs(scripts_list) do
        by_index[v] = k
    end
    return by_index[script_name] or 0
end

local fdata = {}
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "luablock:scripts_"..player:get_player_name() then
        if is_allowed(player) then
            fdata[player:get_player_name()] = fdata[player:get_player_name()] or {}
            local data = fdata[player:get_player_name()]
            data.index = data.index or 1
            local scripts_list = get_scripts_list()
            if fields.scripts then
                local event = minetest.explode_textlist_event(fields.scripts)
                if event.type == "CHG" then
                    data.index = event.index
                    luablock.show_scripts_formspec(player, event.index)
                end
            end
            local script_name = scripts_list[data.index] or ""
            data.scripts = data.scripts or {}
            data.scripts[script_name] = data.scripts[script_name] or {}
            if type(data.scripts[script_name].run_when_server_starts) ~= "boolean" then
                local script = luablock.scripts[script_name]
                local run_when_server_starts = false
                if script then
                    run_when_server_starts = script.run_when_server_starts
                end
                data.scripts[script_name].run_when_server_starts = run_when_server_starts
            end
            if fields.run_when_server_starts then
                data.scripts[script_name].run_when_server_starts = toboolean(fields.run_when_server_starts)
            end
            if fields.new then
                if fields.name ~= "" and fields.name ~= script_name then
                    luablock.add_script(fields.name, {
                        run_when_server_starts = data.run_when_server_starts,
                        code = fields.script
                    })
                    luablock.show_scripts_formspec(player, get_index_at_name(fields.name))
                end
            elseif fields.delete then
                luablock.remove_script(script_name)
                luablock.show_scripts_formspec(player)
            elseif fields.save then
                local script = luablock.scripts[script_name]
                if script then
                    local new_script_name = script_name
                    if fields.name ~= "" then
                        new_script_name = fields.name
                    end
                    script.code = fields.script
                    script.run_when_server_starts = toboolean(data.scripts[script_name].run_when_server_starts)
                    luablock.update_script(script_name, {
                        code = script.code,
                        run_when_server_starts = data.scripts[script_name].run_when_server_starts
                    })
                    luablock.rename_script(script_name, new_script_name)
                    luablock.show_scripts_formspec(player, get_index_at_name(new_script_name))
                end
            elseif fields.run then
                local script = luablock.scripts[script_name]
                if script then
                    local new_script_name = script_name
                    if fields.name ~= "" then
                        new_script_name = fields.name
                    end
                    script.code = fields.script
                    script.run_when_server_starts = toboolean(data.scripts[script_name].run_when_server_starts)
                    luablock.update_script(script_name, {
                        code = script.code,
                        run_when_server_starts = data.scripts[script_name].run_when_server_starts
                    })
                    luablock.rename_script(script_name, new_script_name)
                    luablock.run_script(new_script_name)
                    luablock.show_scripts_formspec(player, get_index_at_name(new_script_name))
                end
            end
        end
    end
end)

function luablock.show_scripts_formspec(player, ...)
    if is_allowed(player) then
        minetest.show_formspec(player:get_player_name(), "luablock:scripts_"..player:get_player_name(), scripts_formspec(player, ...))
    end
end

minetest.register_chatcommand("scripts", {
    description = "Allows players to manage scripts.",
    privs = { server = true, luablock = true },
    func = function(name, text)
        luablock.show_scripts_formspec(minetest.get_player_by_name(name))
    end
})