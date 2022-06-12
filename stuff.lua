local rules = {}
for dist = 1, 25, 1 do
    local _rules = {
        {x=dist,y=0,z=0},
        {x=0-dist,y=0,z=0},
        {x=0,y=dist,z=0},
        {x=0,y=0-dist,z=0},
        {x=0,y=0,z=dist},
        {x=0,y=0,z=0-dist}
    }
    for _, rule in pairs(_rules) do
        table.insert(rules, rule)
    end
end

local on_punch = function(pos, node, player, pointed_thing)
    local channel = minetest.get_meta(pos):get_string("channel")
    local msg = {
		is_callback = true,
        callback_type = "on_punch",
        pos = pos,
        node = node,
        player = player,
        pointed_thing = pointed_thing
    }
    luablock.luablock_send(pos, channel, msg, rules)
end

local on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
    local channel = minetest.get_meta(pos):get_string("channel")
    local msg = {
		is_callback = true,
        callback_type = "on_rightclick",
        pos = pos,
        node = node,
        clicker = clicker,
        itemstack = itemstack,
        pointed_thing = pointed_thing
    }
    luablock.luablock_send(pos, channel, msg, rules)
end

------------------
--Channel Editor--
------------------

local is_authorized = function(player)
    return minetest.check_player_privs(player:get_player_name(), {server=true,luablock=true})
end

-- "formspec_version[5]" ..
-- "size[10.5,2.2]" ..
-- "field[0.2,0.5;10.1,0.8;channel;Channel;]" ..
-- "button[0.2,1.5;10.1,0.5;set_channel;Set Channel]"

local formspec_data = {}
local channel_editor_formspec = function(player, pos)
    local name = player:get_player_name()
    formspec_data[name] = formspec_data[name] or {}
    formspec_data[name].pos = pos

    local meta = minetest.get_meta(pos)
    local channel = meta:get_string("channel")

    local formspec = "formspec_version[5]" ..
    "size[10.5,2.2]" ..
    "field[0.2,0.5;10.1,0.8;channel;Channel;"..minetest.formspec_escape(channel).."]" ..
    "button[0.2,1.5;10.1,0.5;set_channel;Set Channel]"

    return formspec
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "luablock:channel_editor_"..player:get_player_name() then
        if is_authorized(player) then
            if fields.set_channel then
                local name = player:get_player_name()
                formspec_data[name] = formspec_data[name] or {}
                if formspec_data[name].pos then
                    local meta = minetest.get_meta(formspec_data[name].pos)
                    meta:set_string("channel", fields.channel)
                end
            end
        end
    end
end)

local show_channel_editor_formspec = function(player, pos)
    if is_authorized(player) then
        local name = player:get_player_name()
        minetest.show_formspec(name, "luablock:channel_editor_"..name, channel_editor_formspec(player, pos))
    end
end

minetest.register_tool("luablock:channel_editor", {
    description = "Channel Editor",
    groups = {not_in_creative_inventory=1},
    inventory_image = "luablock_channel_editor.png",
    on_place = function(itemstack, player, pointed_thing)
        if pointed_thing and pointed_thing.type == "node" then
            show_channel_editor_formspec(player, pointed_thing.under)
        end
    end
})

---------
--Nodes--
---------

minetest.register_node("luablock:bluetooth_box", {
    description = "Digilines Bluetooth Box",
    groups = {cracky = 3, not_in_creative_inventory=1},
    tiles = { "luablock_bluetooth_box.png" },
    digiline = {
		receptor = {},
		wire = {
			rules = rules,
		},
    }
})

minetest.register_node("luablock:touchscreen", {
	description = "Digilines Touchscreen",
	groups = {cracky=3, not_in_creative_inventory=1},
	drawtype = "nodebox",
	tiles = {
		"luablock_ts_front.png",
		"luablock_panel_back.png",
		"luablock_panel_back.png",
		"luablock_panel_back.png",
		"luablock_panel_back.png",
		"luablock_panel_back.png"
		},
	paramtype = "light",
	paramtype2 = "wallmounted",
	node_box = {
		type = "fixed",
		fixed = {
			{ -0.5, -0.5, -0.5, 0.5, -0.4, 0.5 }
		}
    },
	digiline = {
		receptor = {},
		wire = {
			rules = rules,
		},
		effector = {
			action = function(pos, node, channel, msg) end
		},
	},
    on_punch = on_punch,
    on_rightclick = on_rightclick
})

minetest.register_node("luablock:fancy_touchscreen_wall", {
	description = "Digilines Touchscreen",
	groups = {cracky=3, not_in_creative_inventory=1},
	drawtype = "nodebox",
	tiles = {
		"luablock_fts_panel.png",
		"luablock_fts_panel.png",
		"luablock_fts_panel.png",
		"luablock_fts_panel.png",
		"luablock_fts_panel.png",
		"luablock_fts_front.png"
    },
	paramtype = "light",
	paramtype2 = "facedir",
	node_box = {
		type = "fixed",
		fixed = {
			{ -0.5, -0.5, 0.4, 0.5, 0.5, 0.5 }
		}
    },
	digiline = {
		receptor = {},
		wire = {
			rules = rules,
		},
		effector = {
			action = function(pos, node, channel, msg) end
		},
	},
    on_punch = on_punch,
    on_rightclick = on_rightclick
})

minetest.register_node("luablock:fancy_touchscreen_counter", {
	description = "Digilines Touchscreen",
	groups = {cracky=3, not_in_creative_inventory=1},
	drawtype = "nodebox",
	tiles = {
		"luablock_fts_front.png",
		"luablock_fts_panel.png",
		"luablock_fts_panel.png",
		"luablock_fts_panel.png",
		"luablock_fts_panel.png",
		"luablock_fts_panel.png"
    },
	paramtype = "light",
	paramtype2 = "facedir",
	node_box = {
		type = "fixed",
		fixed = {
			{ -0.5, -0.5, -0.5, 0.5, -0.4, 0.5 }
		}
    },
	digiline = {
		receptor = {},
		wire = {
			rules = rules,
		},
		effector = {
			action = function(pos, node, channel, msg) end
		},
	},
    on_punch = on_punch,
    on_rightclick = on_rightclick
})

minetest.register_node("luablock:card_reader",{
	description = "Digilines Magnetic Card Reader/Writer",
	groups = {cracky = 3, not_in_creative_inventory=1},
	paramtype = "light",
	paramtype2 = "facedir",
	tiles = {
		"luablock_cardreader_sides.png",
		"luablock_cardreader_sides.png",
		"luablock_cardreader_sides.png",
		"luablock_cardreader_sides.png",
		"luablock_cardreader_sides.png",
		"luablock_cardreader_top.png",
	},
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.08,-0.12,0.4,0.08,0.12,0.5},
		}
	},
	digiline = {
		receptor = {},
		wire = {
			rules = rules,
		},
		effector = {
			action = function(pos, node, channel, msg) end
		},
	},
    on_punch = on_punch,
    on_rightclick = on_rightclick
})
