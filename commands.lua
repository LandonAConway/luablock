local luacommand_execute = function(name, code)
    local player = minetest.get_player_by_name(name)
    local myname
    local pos
    if player then
        myname = player:get_player_name()
        pos = player:get_pos()
    end
    local execute = function(func)
        -- environment
        local env = {}
        env.me = player
        env.myname = myname
        env.here = pos
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
        -- lbapi
        for k, v in pairs(luablock.lbapi.env) do
            env[k] = v
        end
        setmetatable(env, {
            __index = _G
        })
        setfenv(func, env)

        -- execute code
        return func()
    end

    local func, errMsg = loadstring(code);
    local success, result = pcall(execute, func)

    local has_err = false
    local err = ""
    if not func then
        err = errMsg
        has_err = true
    elseif not success then
        err = result
        has_err = true
    end
    
    if has_err then
        return tostring(err)
    end

    local _result = ""
    if result then
        _result = tostring(result)
    end

    return tostring(_result)
end

minetest.register_chatcommand("lua", {
    description = "Executes lua code.",
    privs = { server = true, luablock = true },
    func = function(name, text)
        return true, luacommand_execute(name, text)
    end
})