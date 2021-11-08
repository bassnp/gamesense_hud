
--==================================== Bassn's hud lua =======================================--

local ffi = require "ffi"
local images = require "gamesense/images"             -- https://gamesense.pub/forums/viewtopic.php?id=22917
local csgo_weapons = require "gamesense/csgo_weapons" -- https://gamesense.pub/forums/viewtopic.php?id=18807
local easing = require "gamesense/easing"             -- https://gamesense.pub/forums/viewtopic.php?id=22920
local entityinfo = require 'gamesense/entity'         -- https://gamesense.pub/forums/viewtopic.php?id=27529
local surface = require 'gamesense/surface'           -- https://gamesense.pub/forums/viewtopic.php?id=18793
local localize = require "gamesense/localize"         -- https://gamesense.pub/forums/viewtopic.php?id=30643

local pan = panorama.open()
local InventoryAPI = pan.InventoryAPI
local GameStateAPI = pan.GameStateAPI
local MyPersonaAPI = pan.MyPersonaAPI
local GameInterfaceAPI = pan.GameInterfaceAPI

local mp = {"CONFIG", "Presets"}

local ui_get = ui.get

local function as_clr(r, g, b)
	local to_return
	if type(r) == "number" then
		to_return = {
			r = r,
			g = g,
			b = b,
			a = 255,
		}
	elseif type(r) == "table" then
		to_return = {
			r = r[1],
			g = r[2],
			b = r[3],
			a = r[4] or 255,
		}
	end
	return to_return
end

local function color_and_label(name, color)
	return {
		label = ui.new_label(mp[1], mp[2], name),
		clr = ui.new_color_picker(mp[1], mp[2], name .. " Color Picker", color.r, color.g, color.b, color.a or 255)
	}
end

local hud_enable = ui.new_checkbox(mp[1], mp[2], "Simple Hud")
local hud_offset = ui.new_slider(mp[1], mp[2], "Hud Offset", 10, 250, 50)

local cross_gap     = ui.new_label(mp[1], mp[2], " ")
local cross_enable  = ui.new_checkbox(mp[1], mp[2], "Crosshair")
local crosshair = {
	clr     = ui.new_color_picker(mp[1], mp[2], "  - Crosshair Color Picker", 255, 255, 255, 255),
	tshape  = ui.new_checkbox(mp[1], mp[2],     "  - T-Shape"),
	outline = ui.new_checkbox(mp[1], mp[2],     "  - Outline"),
	out_clr = ui.new_color_picker(mp[1], mp[2], "  - Outline Color Picker", 0, 0, 0, 255),
	dot     = ui.new_checkbox(mp[1], mp[2],     "  - Center Dot"),
	dot_clr = ui.new_color_picker(mp[1], mp[2], "  - Center Dot Color Picker", 0, 0, 0, 255),
	len     = ui.new_slider(mp[1], mp[2],       "  - Length", 1, 100, 5, true, "px"),
	thic    = ui.new_slider(mp[1], mp[2],       "  - Thiccness", 1, 50, 5, true, "px"),
	gap    = ui.new_slider(mp[1], mp[2],        "  - Gap",  1, 50, 5, true, "px"),
}
local cross_gap     = ui.new_label(mp[1], mp[2], " ")

local hud_scheme = ui.new_combobox(mp[1], mp[2], "Color Scheme", { "Default CS:GO", "Custom" }, 1)

local ct_color = {  94, 121, 174 }
local t_color  = { 204, 186, 124 }
local b_color  = {  15,  15,  15 }
local d_color  = {  52, 137, 235 }

local clrs = { -- cancer
	label_0 = ui.new_label(mp[1], mp[2], "----------------------- Colors -----------------------"),
	health_1 = color_and_label("Health Gradient 1", as_clr(255, 0, 0)),
	health_2 = color_and_label("Health Gradient 2", as_clr(0, 255, 0)),
	label_1 = ui.new_label(mp[1], mp[2], " "),
	armor_1 = color_and_label("Armor Gradient 1", as_clr(0, 50, 255)),
	armor_2 = color_and_label("Armor Gradient 2", as_clr(0, 185, 255)),
	label_2 = ui.new_label(mp[1], mp[2], " "),
	ct = color_and_label("Counter Terrorist", as_clr(ct_color)),
	t = color_and_label("Terrorist", as_clr(t_color)),
	label_3 = ui.new_label(mp[1], mp[2], " "),
	ammo = color_and_label("Ammo Bar", as_clr(d_color)),
	gun_active = color_and_label("Active Weapon", as_clr(225, 225, 225)),
	gun_dropshadow = color_and_label("Weapon Dropshadow", as_clr(0, 0, 0)),
	label_4 = ui.new_label(mp[1], mp[2], " "),
	equipment = color_and_label("Equipment", as_clr(255, 255, 255)),
	label_5 = ui.new_label(mp[1], mp[2], " "),
	timer = color_and_label("Timer", as_clr(255, 255, 255)),
	timer_end = color_and_label("Timer Ending", as_clr(255, 50, 0)),
	label_6 = ui.new_label(mp[1], mp[2], " "),
	feed_local_name = color_and_label("Killfeed Self Name", as_clr(0, 155, 255)),
	feed_gun = color_and_label("Killfeed Gun", as_clr(255, 255, 255)),
	feed_data = color_and_label("Killfeed Icons", as_clr(255, 255, 255)),
}

local dpi_scale = ui.reference("MISC", "Settings", "DPI scale")

local screen_w, screen_h = client.screen_size()
local s = tonumber(ui_get(dpi_scale):sub(1, -2))/100

local kill_list, chat_queue, ended_header, mvp_header = {}, {}, {}, {}

--local font_str = "DIN Mittelschrift"
local font_str = "Calibri"
local fo = 2
--======================================= Functions =========================================--

local function setTableVisibility(table, state) -- thx to whoever made this
    for i, v in pairs(table) do
		if type(table[i]) == "table" then
			ui.set_visible(table[i].clr, state)
			ui.set_visible(table[i].label, state)
		else
        	ui.set_visible(table[i], state)
		end	
    end
end

local function round(number, precision) -- stolen from somewhere
    local mult = 10 ^ (precision or 0)
    return math.floor(number * mult + 0.5) / mult
end

local function is_within(value, num1, num2)
    return value > num1 and value < num2
end

local function steam_64(steamid3)
	if type(steamid3) ~= "userdata" then
		if steamid3 == " " then
			return ' '
		end

		local y
		local z
			
		if ((steamid3 % 2) == 0) then
			y = 0
			z = (steamid3 / 2)
		else
			y = 1
			z = ((steamid3 - 1) / 2)
		end
		
		return '7656119' .. ((z * 2) + (7960265728 + y))
	else
		return nil
	end
end

function SecondsToClock(seconds) -- https://gist.github.com/Hristiyanii/3fe3a4d9f5522bdd8a3f5ce93104f48f
	local seconds = tonumber(seconds)
	local to_return = { clock = "00:00", time = seconds} 

	if seconds > 0 then
		hours = 0;
		mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
		secs = string.format("%02.f", math.floor(seconds - hours*3600 - mins *60));
		to_return.clock = mins .. " : " .. secs
	end

	return to_return
end

-- Los is a god
local native_Key_LookupBinding = vtable_bind("engine.dll", "VEngineClient014", 21, "const char* (__thiscall*)(void*, const char*)")
local function get_key_binding(cmd)
    return ffi.string(native_Key_LookupBinding(cmd))
end

local function char_to_keycode(char)
    return string.format("0x%02X", string.byte(string.upper(char)))
end

--------------------
-- Credit: Bobby UI
local function vmt_entry(instance, index, type)
	return ffi.cast(type, (ffi.cast("void***", instance)[0])[index])
end
-- Credit: Bobby UI
local function vmt_bind(module, interface, index, typestring)
	local instance = client.create_interface(module, interface) or error("invalid interface")
	local success, typeof = pcall(ffi.typeof, typestring)
	if not success then
		error(typeof, 2)
	end
	local fnptr = vmt_entry(instance, index, typeof) or error("invalid vtable")
	return function(...)
		return fnptr(instance, ...)
	end
end
-- Credit: Bobby UI
local get_event_data = vmt_bind("inputsystem.dll", "InputSystemVersion001", 21, "const struct {int m_nType, m_nTick, m_nData, m_nData2, m_nData3;}*(__thiscall*)(void*)")
local button_code_to_string = vmt_bind("inputsystem.dll", "InputSystemVersion001", 40, "const char*(__thiscall*)(void*, int)")
-- Credit: Bobby UI
local event_types = {
	[0] = "IE_ButtonPressed",
	[1] = "IE_ButtonReleased",
	[2] = "IE_ButtonDoubleClicked",
	[203] = "IE_KeyCodeTyped",
}
--  Credit: Bobby UI | Slightly modified
local last_tick, last_button, continues_button = 0, -1, -1
local input_string, hit_exit_key = false, 0
local function capture_key_input()
    local event_data = get_event_data()

    local etype = event_types[event_data.m_nType]
    local pressed_key_char = nil
    local pressed_key_int = nil

    if etype == "IE_ButtonPressed" or etype == "IE_ButtonDoubleClicked" then
        pressed_key_char = ffi.string(button_code_to_string(event_data.m_nData))
        pressed_key_int = event_data.m_nData

		if pressed_key_int == 70 or pressed_key_int == 64 then
			hit_exit_key = pressed_key_int
		end

        if last_tick ~= event_data.m_nTick then
            if pressed_key_int <= 36 and continues_button ~= 83 and continues_button ~= 84 then
                input_string = input_string .. pressed_key_char
            elseif pressed_key_int == 65 then
                input_string = input_string .. " "
            elseif pressed_key_int == 66 then
                input_string = string.sub(input_string, 1, #input_string - 1)
            end
            last_button = pressed_key_int
        end
        last_tick = event_data.m_nTick
    elseif etype == "IE_ButtonReleased" then
        pressed_key_char = ""
        pressed_key_int = event_data.m_nData
    elseif etype == "IE_KeyCodeTyped" then
        pressed_key_char = ffi.string(button_code_to_string(event_data.m_nData))
        pressed_key_int = event_data.m_nData
        if last_tick ~= event_data.m_nTick then
            if pressed_key_int <= 36 then
                input_string = input_string .. pressed_key_char
            elseif pressed_key_int == 65 then
                input_string = input_string .. " "
            elseif pressed_key_int == 66 then
                input_string = string.sub(input_string, 1, #input_string - 1)
            end
            continues_button = pressed_key_int
        end
    end
end
--------------------
local function clamp(num, min, max)
	if num < min then
		num = min
	elseif num > max then
		num = max    
	end
	return num
end


local function fix_str(font, str) -- completely useless, too lazy to take it out, might need to modify it for somethin else
	local new_str = ""
	local i_off = 0
	for i = 1, #str do
		local curr_char = string.sub(str, i + i_off, i + i_off)
		local char_w, char_h = surface.get_text_size(font, curr_char)
		new_str = new_str .. curr_char
	end
	return new_str
end

local function return_overflow_table(line, font, max_width) -- for chat overflow
	local whole = line.name .. " : " .. line.text
	local name_offset = #line.name + 4 -- " : "
	local total_length = surface.get_text_size(font, whole)
	local overflow = {}
	local offset = 0
	for i = 1, #whole do
		local loop_length = surface.get_text_size(font, string.sub(whole, offset, i))
		if loop_length >= max_width then
			local sub = string.sub(whole, offset, i - 1)
			table.insert(overflow, (offset == 0 and { tsay = line.tsay, dead = line.dead, team = line.team, name = line.name, text = string.sub(sub, name_offset, #sub) } or sub))
			offset = i
		end
	end
	local sub = string.sub(whole, offset, #whole)
	table.insert(overflow, (offset == 0 and { tsay = line.tsay, dead = line.dead, team = line.team, name = line.name, text = string.sub(sub, name_offset, #sub) } or sub))

	return overflow
end

local function player()
	local local_player = entity.get_local_player()
	
	local player = not entity.is_alive(local_player) and entity.get_prop(local_player, 'm_hObserverTarget') or local_player
	if entity.get_prop(local_player, 'm_iObserverMode') == 6 then
		player = nil
	end

	return player
end

local invalids = {
	"Tablet",
	"Bump Mine",
	"Riot Shield",
}

local function valid_weapon(weapon)
    for i=1,#invalids do
        if invalids[i] == weapon.name then 
            return false
        end
    end
    return true 
end

local nades = { -- inverse priority list
	"Tactical Awareness Grenade",
	"Molotov",
	"Incendiary Grenade",
	"Decoy Grenade",
	"Smoke Grenade",
	"Flashbang",
	"High Explosive Grenade",
	"Snowball",
}

local function sort_grenades(grenades)
	local sorted = {}
	for i = 1, #nades do
		for j = 1, #grenades do
			if grenades[j].name == nades[i] then
				table.insert(sorted, grenades[j])
				break
			end
		end 
	end
	return sorted
end

local function get_weapons(player) -- thx ally
    local all_weapons = {}

    for i = 0, 16 do
        local weapon = entity.get_prop(player, 'm_hMyWeapons', i)
        if weapon ~= nil then
			table.insert(all_weapons, csgo_weapons(weapon))
        end
    end

    return all_weapons
end

-- thax papa phil
local js = panorama.loadstring([[
    let _GetSpeakingPlayers = function() {
        let children = $.GetContextPanel().FindChildTraverse("VoicePanel").Children()
        let result = []
        children.forEach((panel) => {
            if(!panel.BHasClass("Hidden")) {
                try {
                    let avatar = panel.GetChild(1).GetChild(1)
                    result.push(avatar.steamid)
                } catch (err) {
                    // ignored
                }
            }
        })
        if(result.length > 0) {
            let lookup = {}
            for(let i=1; i <= 64; i++) {
                let xuid = GameStateAPI.GetPlayerXuidStringFromEntIndex(i)
                if(xuid && xuid != "0")
                    lookup[xuid] = i
            }
            for(let i=0; i < result.length; i++)
                result[i] = lookup[ result[i] ]
        }
        return result
    }
    return {
        get_speaking_players: _GetSpeakingPlayers
    }
]], "CSGOHud")()

local function get_speaking_players()
    return json.parse(tostring(js.get_speaking_players()))
end

local function get_active_color()
	local scheme = ui_get(hud_scheme)
	local to_return
	if scheme == "Default CS:GO" then
		to_return = {
			health_1 = as_clr(255, 0, 0), 
			health_2 = as_clr(0, 255, 0),

			armor_1 = as_clr(0, 50, 255),
			armor_2 = as_clr(0, 185, 255),
		
			ct = as_clr(ct_color),
			t = as_clr(t_color),
		
			ammo = as_clr(d_color),
			gun_active = as_clr(225, 225, 225),
			gun_dropshadow = as_clr(0, 0, 0),
		
			equipment = as_clr(255, 255, 255),

			timer = as_clr(255, 255, 255),
			timer_end = as_clr(255, 50, 0),
		
			feed_local_name = as_clr(99, 179, 84),
			feed_gun = as_clr(255, 255, 255),
			feed_data = as_clr(255, 255, 255),
		}
	elseif scheme == "Custom" then
		to_return = {
			health_1 = as_clr(ui_get(clrs.health_1.clr)),
			health_2 = as_clr(ui_get(clrs.health_2.clr)),

			armor_1 = as_clr(ui_get(clrs.armor_1.clr)),
			armor_2 = as_clr(ui_get(clrs.armor_2.clr)),
		
			ct = as_clr(ui_get(clrs.ct.clr)),
			t = as_clr(ui_get(clrs.t.clr)),
		
			ammo = as_clr(ui_get(clrs.ammo.clr)),
			gun_active = as_clr(ui_get(clrs.gun_active.clr)),
			gun_dropshadow = as_clr(ui_get(clrs.gun_dropshadow.clr)),
		
			equipment = as_clr(ui_get(clrs.equipment.clr)),

			timer = as_clr(ui_get(clrs.timer.clr)),
			timer_end = as_clr(ui_get(clrs.timer_end.clr)),
		
			feed_local_name = as_clr(ui_get(clrs.feed_local_name.clr)),
			feed_gun = as_clr(ui_get(clrs.feed_gun.clr)),
			feed_data = as_clr(ui_get(clrs.feed_data.clr)),
		}
	end
	return to_return
end

local b = 4 * s
local b_gap = b * 3

local function draw_bar(x, y, w, h, value, c1, c2)
	local cover_width = w * ((100 - value) / 100)

	surface.draw_filled_gradient_rect(x, y, w, h, c1.r, c1.g, c1.b, 215, c2.r, c2.g, c2.b, 215, true)
	surface.draw_filled_rect((x + w) - cover_width, y - 1, cover_width + 1, h + 2, 15, 15, 15, 255)

	local font = surface.create_font(font_str, (25 + fo) * s, 100, {0x010}) -- 
	local o_w, o_h = surface.get_text_size(font, tostring(value))
	surface.draw_text(x + w + (23 * s) - (o_w / 2), y + h / 2.1 - (o_h / 2), 195, 195, 195, 235, font, tostring(value))
end

local function draw_box(x, y, w, h, o_clr, alpha)
	local clr = b_color
	alpha = alpha == nil and 131 or alpha
	surface.draw_filled_rect(x - b, y - b, w + (b * 2), h + (b * 2), clr[1], clr[2], clr[3], alpha)

	clr = (o_clr ~= nil and o_clr or b_color)
	surface.draw_filled_rect(x, y, w, h, clr[1], clr[2], clr[3], alpha)
end
--====================================== Runtime Funcs ========================================--

local equipment = {}
local old_health, old_armor, ease_cash, ease_color, old_cash, cash_change = 0, 0, 0, 0, 0, 0
local function draw_health_and_equipment(gap, accent, player)	
	local health  = entity.get_prop(player, "m_iHealth") or 0
	local armor   = entity.get_prop(player, "m_ArmorValue") or 0

	local w, h = (screen_w / 4) * s, (53 * s)
	local x, y = gap, screen_h - gap - h
	local sap = 10 * s

	draw_box(x, y, w, h)

	local bar_height = (12 * s)
	draw_bar(x + sap, (y + h) - sap - bar_height, w - (sap * 2) - (40 * s), bar_height, round(old_health, 0), accent.health_1, accent.health_2)
	draw_bar(x + sap, (y + sap),                  w - (sap * 2) - (40 * s), bar_height, round(old_armor, 0), accent.armor_1, accent.armor_2)

	old_health = easing.quad_out(1, old_health, health - old_health, 10)
	old_armor  = easing.quad_out(1, old_armor,  armor - old_armor,   10)

	local has_defuser = entity.get_prop(player, "m_bHasDefuser") == 1 and true or false
	if has_defuser then
		table.insert(equipment, { type = "equiped", name = "Defuser", image = "hud/deathnotice/icon-defuser.png"} )
	end

	local has_helmet = entity.get_prop(player, "m_bHasHelmet") == 1 and true or false
	local has_kevlar = armor > 0
	if has_helmet then
		table.insert(equipment, { type = "equiped", name = "Helmet + Kevlar", image = "hud/deathnotice/icon-armor_helmet.png"} )
	elseif has_kevlar then
		table.insert(equipment, { type = "equiped", name = "Kevlar",          image = "hud/deathnotice/icon-armor.png"} )
	end

	local n_h = (h / 1.5)
	for i = 1, #equipment do
		local curr_equip = equipment[#equipment - (i - 1)]
		local equip_image = curr_equip.type == "equiped" and images.get_panorama_image(curr_equip.image) or images.get_weapon_icon(curr_equip)

		local c_w, c_h = equip_image.width, equip_image.height
		local s_w, s_h = n_h - 4 - (c_w), n_h - 4 - (c_h)
		local space = math.min(s_w, s_h)
		local mod_w, mod_h = n_h, n_h
		local mod_x, mod_y = x + ((mod_w + b_gap) * (i - 1)), y - mod_h - b_gap
		
		draw_box(mod_x, mod_y, mod_w, mod_h)

		local active_weapon = csgo_weapons(entity.get_player_weapon(player))
		if active_weapon ~= nil then
			local alpha = (active_weapon.idx == curr_equip.idx or curr_equip.type == "equiped") and 255 or 115
			equip_image:draw(mod_x + ((mod_w - (c_w + space)) / 2), mod_y + ((mod_h - (c_h + space)) / 2), c_w + space, c_h + space, accent.equipment.r, accent.equipment.g, accent.equipment.b, alpha, false)
		end
	end
	
	local cash = entity.get_prop(player, "m_iAccount")
	if cash ~= nil then
		local cash_w = 83 * s
		local cash_x, cash_y = x + w - cash_w, y - n_h - b_gap
		if cash ~= cash_change then
			old_cash = cash_change
			ease_color = old_cash
		end

		local cash_diff = old_cash - cash
		local percent = (math.abs(cash_diff) - math.abs(round(ease_color - cash, 0))) / math.abs(cash_diff)
		if tostring(percent) == "nan" then
			percent = 1
		end

		local c_color
		if cash_diff == 0 then
			c_color = {255, 255, 255}
		else
			c_color = cash_diff < 0 and {255 * percent, 255, 255 * percent} or {255, 255 * percent, 255 * percent}
		end
			
		draw_box(cash_x, cash_y, cash_w, n_h)

		local font = surface.create_font(font_str, (25 + fo) * s, 1, {0x010}) -- 
		local o_w, o_h = surface.get_text_size(font, "$" .. tostring(round(ease_cash, 0)))

		surface.draw_text(cash_x + cash_w - (b * s) - o_w, cash_y + (b * s), c_color[1], c_color[2], c_color[3], 255, font, "$" .. tostring(round(ease_cash, 0)))

		ease_cash = easing.quad_out(1, ease_cash, cash - ease_cash, 20)
		ease_color = easing.quint_in(1, ease_color, cash - ease_color, 2.8)

		cash_change = cash
	end
end

local old_ammo, old_weapon = 0, 0
local function draw_weapons(gap, accent, player)	
	local weapons = get_weapons(player)
	equipment = {} -- clear

	local w, h = screen_w / 11, (62 * s)
	local x, y = screen_w - w - (gap * 2), screen_h - gap - h
	local sap = 10 * s

	local grenades = {}

	local n = 0
	local player_weapon = entity.get_player_weapon(player)
	if player_weapon ~= nil then
		local active_weapon = csgo_weapons(player_weapon)
		local curr_ammo     = entity.get_prop(player_weapon, 'm_iClip1') -- "-1" if nil
		local max_clip = active_weapon.primary_clip_size
		local reserve  = entity.get_prop(player_weapon, 'm_iPrimaryReserveAmmoCount') -- "0" if nil
		local reload   = entity.get_prop(player_weapon, "m_bInReload") == 1 and true or false

		for i = 1, #weapons do
			local curr_weapon = weapons[i]
			local is_active = active_weapon.idx == curr_weapon.idx
			local alpha = is_active and 255 or 115
			local gun_color = is_active and accent.gun_active or {r = 235, g = 235, b = 235}
			if curr_weapon.type ~= "grenade" and curr_weapon.name ~= "Snowball" then
				if valid_weapon(curr_weapon) then
					local weapon_icon = images.get_weapon_icon(curr_weapon)
					if curr_weapon.name == "Zeus x27" then -- 41.5
						n = n + 1
						local mod_w, mod_h = (41.5 * s) + 20, weapon_icon.height * s
						local mod_x = x - mod_w - b_gap

						draw_box(mod_x, y, mod_w, h)	

						
						if is_active then
							weapon_icon:draw(mod_x + (mod_w / 2.2) - (weapon_icon.width / 2) + 4, y + (mod_h / 2.6) + 2, weapon_icon.width * s + 1, mod_h + 1, accent.gun_dropshadow.r, accent.gun_dropshadow.g, accent.gun_dropshadow.b, alpha, true)
						end
						weapon_icon:draw(mod_x + (mod_w / 2.2) - (weapon_icon.width / 2) + 2, y + (mod_h / 2.6), weapon_icon.width * s, mod_h, gun_color.r, gun_color.g, gun_color.b, alpha, true)
					elseif curr_weapon.name == "C4 Explosive" then
						n = n + 1
						local mod_w, mod_h = (41.5 * s) + 20, weapon_icon.height * s
						local mod_x, mod_y = x - mod_w - b_gap, y - h - b_gap

						draw_box(mod_x, mod_y, mod_w, h)	

						if is_active then
							weapon_icon:draw(mod_x + (mod_w / 2.5) - (weapon_icon.width / 2) + 4, mod_y + (mod_h / 2.6) + 2, weapon_icon.width * s + 1, mod_h + 1, accent.gun_dropshadow.r, accent.gun_dropshadow.g, accent.gun_dropshadow.b, alpha, true)
						end
						weapon_icon:draw(mod_x + (mod_w / 2.5) - (weapon_icon.width / 2) + 2, mod_y + (mod_h / 2.6), weapon_icon.width * s, mod_h, gun_color.r, gun_color.g, gun_color.b, alpha, true)
					elseif curr_weapon.name == "Medi-Shot" then
						n = n + 1
						local mod_w, mod_h = (41.5 * s) + 20, weapon_icon.height * s
						local mod_x, mod_y = x - mod_w - b_gap, y - (h * 2) - 30

						draw_box(mod_x, mod_y, mod_w, h)	

						if is_active then
							weapon_icon:draw(mod_x + (mod_w / 2.5) - (weapon_icon.width / 2) + 4, mod_y + (mod_h / 2) + 2, weapon_icon.width * s + 1, mod_h + 1, accent.gun_dropshadow.r, accent.gun_dropshadow.g, accent.gun_dropshadow.b, alpha, true)
						end
						weapon_icon:draw(mod_x + (mod_w / 2.5) - (weapon_icon.width / 2) + 2, mod_y + (mod_h / 2), weapon_icon.width * s, mod_h, gun_color.r, gun_color.g, gun_color.b, alpha, true)
					else
						local mod_w, mod_h = (weapon_icon.width * s) * 1.25, (weapon_icon.height * s) * 1.25
						local mod_y = y - ((h + b_gap) * ((i - n) - 1))

						draw_box(x, mod_y, w, h)	

						if is_active then
							if reload then
								local me = entityinfo.new(player) -- stolen from satori
								local anim_layer = me:get_anim_overlay(1)
								local activity = me:get_sequence_activity(anim_layer.sequence)
								if activity == 967 and anim_layer.weight ~= 0 and anim_layer.weight ~= nil and activity ~= -1 then --reloading
									cycle = anim_layer.cycle
								end

								if cycle ~= nil then
									surface.draw_filled_rect(x, mod_y, w * cycle + 1, h, 155, 155, 155, 125)
								end
							else
								cycle = 0
							end

							if old_weapon ~= player_weapon then
								old_ammo = 0
							end
							if old_ammo > 0 then
								local ammo_thic = 3 * s
								surface.draw_filled_rect(x, mod_y + h - ammo_thic, clamp(w * (old_ammo / max_clip), 0, w), ammo_thic, accent.ammo.r, accent.ammo.g, accent.ammo.b, 235)	
							end
							weapon_icon:draw(x + (w / 2) - (mod_w / 2) + 2, mod_y + (mod_h / 3) + 2, mod_w + 1, mod_h + 1, accent.gun_dropshadow.r, accent.gun_dropshadow.g, accent.gun_dropshadow.b, alpha, true)

							old_ammo = easing.quad_out(1, old_ammo, curr_ammo - old_ammo, 10)
							old_weapon = player_weapon
						end
						weapon_icon:draw(x + (w / 2) - (mod_w / 2), mod_y + (mod_h / 3), mod_w, mod_h, gun_color.r, gun_color.g, gun_color.b, alpha, true)	
					end	
				else
					table.insert(equipment, curr_weapon)
				end
			else
				table.insert(grenades, curr_weapon)
				n = n + 1
			end
			grenades = sort_grenades(grenades)
		end

		local nades = #grenades
		if nades > 0 then
			local e_w, e_h = 40 * s, (nades > 1 and (h + b + (2.5 * (nades - 1))) * nades or (h) * (nades))
			local e_x, e_y = x + w + b_gap * s, y + h - e_h
			draw_box(e_x, e_y, e_w, e_h)
			for i = 1, nades do
				local equip_icon = images.get_weapon_icon(grenades[i])

				local mod_w, mod_h = equip_icon.width * s * 1.15, equip_icon.height * s * 1.15
				local mod_x, mod_y = e_x + (e_w / 2) - (mod_w / 2), (e_y + e_h) - (i * h) - (i > 1 and i * (2.5 + (2.5 * i)) or 0) + ((h - mod_h) / 3)

				local is_active = csgo_weapons(entity.get_player_weapon(player)).idx == grenades[i].idx
				local alpha = is_active and 255 or 115

				if is_active then
					equip_icon:draw(mod_x + 2, mod_y + 2, mod_w - 1, mod_h + 1, accent.gun_dropshadow.r, accent.gun_dropshadow.g, accent.gun_dropshadow.b, alpha, true)
				end

				equip_icon:draw(mod_x, mod_y, mod_w, mod_h, accent.gun_active.r, accent.gun_active.g, accent.gun_active.b, alpha, true)
			end
		end
	end
end

local planted_time, got_bomb_time = 0, false
local ct_bot     = images.get_panorama_image("hud/teamcounter/teamcounter_alivebgct.png") -- bot ct
local t_bot      = images.get_panorama_image("hud/teamcounter/teamcounter_alivebgt.png")  -- bot t
local bomb_image = images.get_panorama_image("hud/radar/icon-bomb-planted-detail.png")

local ended_header = {}
local function draw_header(gap, accent, player)
	local game = entity.get_game_rules()

	local w, h = 80 * s, 30 * s
	local x, y = (screen_w / 2) - (w / 2), 35 * s
	
	draw_box(x, y, w, h)

	local total_time = entity.get_prop(game, "m_iRoundTime") 
	local start_time = entity.get_prop(game, "m_fRoundStartTime")
	local curr_time  = globals.curtime()

	local bomb_planted = entity.get_prop(game, "m_bBombPlanted") == 1 and true or false
	if not got_bomb_time and bomb_planted then
		planted_time = globals.curtime()
		got_bomb_time = true
	end
	local time_left = not bomb_planted and SecondsToClock(total_time - (curr_time - start_time)) or SecondsToClock(41 - (curr_time - planted_time)) -- big brain time
	local d = player ~= nil and (entity.get_prop(player, "m_bHasDefuser") == 1 and 1 or 2) or 2
	local time_color = time_left.time <= 5 * d and accent.timer_end or accent.timer

	--local header_font = surface.create_font("Trebuchet MS", 25 * s, 10, {0x010}) -- 
	local header_font = surface.create_font(font_str, (26 + fo) * s, 1, {0x010})
	local o_w, o_h    = surface.get_text_size(header_font, tostring(time_left.clock))
	surface.draw_text(x + (w / 2) - (o_w / 2), y + (h / 2) - (o_h / 2), time_color.r, time_color.g, time_color.b, 255, header_font, tostring(time_left.clock))

	if bomb_planted then
		local mod_w, mod_h = w - 30, h * 1.5
		local mod_x, mod_y = x + ((w - mod_w) / 2), y + (h) + b_gap

		draw_box(mod_x, mod_y, mod_w, mod_h)

		-- thx phil
		local bomb_index = entity.get_all("CPlantedC4")
		local native_GetClientEntity = vtable_bind('client.dll', 'VClientEntityList003', 3, 'uintptr_t(__thiscall*)(void*, int)')
		local bomb_client_ent = native_GetClientEntity(bomb_index[1])
		local next_beep = ffi.cast("float*", bomb_client_ent + 0x299C)[0]

		local alpha = is_within(next_beep, curr_time - 0.025, curr_time + 0.125) and 255 or 115

		bomb_image:draw(mod_x + 7, mod_y + 3, mod_w - 10, mod_h - 10, 255, 255, 255, alpha, true)
	end

	--thx again ally
	local info    = json.parse(tostring(GameStateAPI.GetScoreDataJSO()))
	local t_side  = info.teamdata.TERRORIST
	local ct_side = info.teamdata.CT

    local t_win  = t_side.score
    local ct_win = ct_side.score

	local t_alive = GameStateAPI.GetTeamLivingPlayerCount(t_side.team_name)
	local t_total = GameStateAPI.GetTeamTotalPlayerCount (t_side.team_name)

	local ct_alive = GameStateAPI.GetTeamLivingPlayerCount(ct_side.team_name)
	local ct_total = GameStateAPI.GetTeamTotalPlayerCount (ct_side.team_name)

	local box_size = h

	local ct_x = x - (box_size) - b_gap
	draw_box(ct_x, y, box_size, box_size)
	o_w, o_h = surface.get_text_size(header_font, tostring(ct_win))
	surface.draw_text(ct_x - (o_w / 2) + (box_size / 2), y + ((box_size / 2) - (o_h / 2)), accent.ct.r, accent.ct.g, accent.ct.b, 255, header_font, tostring(ct_win))

	local t_x = x + w + b_gap  
	draw_box(t_x, y, box_size, box_size)
	o_w, o_h = surface.get_text_size(header_font, tostring(t_win))
	surface.draw_text(t_x - (o_w / 2) + (box_size / 2), y + ((box_size / 2) - (o_h / 2)), accent.t.r, accent.t.g, accent.t.b, 255, header_font, tostring(t_win))

	local mod_w, mod_h = h / 2, h / 2

	local ct_r = 1
	for i = 1, ct_total do
		if i % 2 == 1 and i ~= 1 then
			ct_r = ct_r + 1
		end

		--local mod_x, mod_y = (x - (w / 1.75)) - ((mod_w + b_gap) * ct_r), i % 2 == 0 and y + mod_h + b_gap or y -- 2 rows
		local mod_x, mod_y = (x - (w / 1.75)) - ((mod_w + b_gap) * i), y
		local color = i <= ct_alive and {accent.ct.r, accent.ct.g, accent.ct.b} or b_color

		draw_box(mod_x, mod_y, mod_w, mod_h, color)
	end

	local t_r = 1
	for i = 1, t_total do
		if i % 2 == 1 and i ~= 1 then
			t_r = t_r + 1
		end
		
		--local mod_x, mod_y = ((x + (w / 1.75)) + w - mod_w) + ((mod_w + b_gap) * t_r), i % 2 == 0 and y + mod_h + b_gap or y
		local mod_x, mod_y = ((x + (w / 1.75)) + w - mod_w) + ((mod_w + b_gap) * i), y
		local color = i <= t_alive and {accent.t.r, accent.t.g, accent.t.b} or b_color

		draw_box(mod_x, mod_y, mod_w, mod_h, color)
	end

	--round end header
	if ended_header.winner ~= nil then
		local winner_name = ended_header.winner == 3 and ct_side.team_name or t_side.team_name
		local path = GameStateAPI.GetTeamLogoImagePath(winner_name)
		local image = ended_header.winner == 3 and ct_bot or t_bot
		
		local h_color = ended_header.winner == 3 and accent.ct or accent.t
		local win_font = surface.create_font(font_str, (26 + fo) * s, 1, {0x010})
		local sub_font = surface.create_font(font_str, (19 + fo) * s, 1, {0x010})
		local win_w, win_h = surface.get_text_size(win_font, ended_header.message)
		local sub_w, sub_h = surface.get_text_size(win_font, "MVP : " .. mvp_header.name)

		local end_h = h * 2
		local end_w = end_h + (b * 5) + math.max(win_w, sub_w)

		local end_x, end_y = (screen_w / 2) - (end_w / 2), y + h + (b * 30)
		
		image:draw(end_x + b, end_y + b, end_h - (b * 2), end_h - (b * 2), 255, 255, 255, 255, false)

		draw_box(end_x, end_y, end_w, end_h)
		draw_box(end_x, end_y, end_w, end_h)

		surface.draw_text((b * 2) + end_x + end_h, end_y + (b / 2), h_color.r, h_color.g, h_color.b, 255, win_font, ended_header.message)
		surface.draw_text((b * 2) + end_x + end_h, end_y + b + win_h, 255, 255, 255, 215, sub_font, "MVP : " .. mvp_header.name)
	end
end

local decay_time = 11
local suicide_image   = images.get_panorama_image("hud/deathnotice/icon_suicide.svg")
local noscope_image   = images.get_panorama_image("hud/deathnotice/noscope.svg")
local headshot_image  = images.get_panorama_image("hud/deathnotice/icon_headshot.svg")
local penetrate_image = images.get_panorama_image("hud/deathnotice/penetrate.svg")
-- in order 
-- noscope -- wallbang -- headshot --
local function draw_kill_feed(gap, accent, player)
	if #kill_list > 0 then
		local pad = b * s
		local feed_font = surface.create_font(font_str, (20 + fo) * s, 100, {0x010}) -- 
		local local_player = entity.get_local_player()
		local time = globals.curtime()
		local x, y = screen_w - (10 * s) - gap, (10 * s) + gap
		local lines = 0
		for i, line in ipairs(kill_list) do -- this gets very dirty, please pardon me lord :pray:
			if line ~= nil and lines < 15 then
				local weapon_icon = type(line.weapon) == "table" and images.get_weapon_icon(line.weapon) or images.get_panorama_image("hud/deathnotice/icon-" .. line.weapon .. ".png")

				if weapon_icon == nil then -- safety
					weapon_icon = images.get_panorama_image("hud/deathnotice/icon_suicide.svg")
				end

				local assist = line.assister ~= nil
				local victim_w, text_h = surface.get_text_size(feed_font, line.victim)
				local attack_w = surface.get_text_size(feed_font, line.attacker)
				local add_w    = assist and surface.get_text_size(feed_font, " + ") + pad or 0
				local assist_w = assist and add_w + surface.get_text_size(feed_font, line.assister) + pad or 0

				local noscope_w   = line.noscope    and (noscope_image.width * s) / 1.35   or 0
				local headshot_w  = line.headshot   and (headshot_image.width * s) / 1.35  or 0
				local penetrate_w = line.penetrated and (penetrate_image.width * s) / 1.35 or 0

				local line_width = pad + attack_w + pad + assist_w + ((weapon_icon.width * s) / 1.2) + pad + noscope_w + headshot_w + penetrate_w + pad + victim_w + pad

				local mod_w, mod_h = line_width, 30 * s
				local mod_x, mod_y = x - mod_w - b_gap, y + ((mod_h + b_gap) * (i - 1))

				draw_box(mod_x, mod_y, mod_w, mod_h)

				local local_name = entity.get_player_name(local_player)
				local attacker_color = (line.attacker == local_name and accent.feed_local_name or (line.attacker_team == 3 and accent.ct or accent.t))
				local victim_color   = (line.victim   == local_name and accent.feed_local_name or (line.victim_team   == 3 and accent.ct or accent.t))
				local assister_color = (line.assister == local_name and accent.feed_local_name or (line.assister_team == 3 and accent.ct or accent.t))
				local weapon_color = accent.feed_gun
				local xtra_color   = accent.feed_data

				local text_y = mod_y + (text_h / 2) - pad
				surface.draw_text(mod_x + pad, text_y, attacker_color.r, attacker_color.g, attacker_color.b, line.alpha, feed_font, line.attacker)
				if assist then 
					surface.draw_text(mod_x + pad + attack_w + pad, text_y, 255, 255, 255, line.alpha, feed_font, " + ")
					surface.draw_text(mod_x + pad + attack_w + pad + add_w, text_y, assister_color.r, assister_color.g, assister_color.b, line.alpha, feed_font, line.assister)
				end
				surface.draw_text(mod_x + line_width - pad - victim_w - pad, text_y, victim_color.r, victim_color.g, victim_color.b, line.alpha, feed_font, line.victim)

				text_y = mod_y + pad

				local c_weapon_off = ((line_width - pad - noscope_w - headshot_w - penetrate_w - pad - victim_w - pad) - (pad + attack_w + pad + assist_w + (weapon_icon.width * s) / 1.35)) / 2
				weapon_icon:draw(mod_x + pad + attack_w + pad + assist_w + c_weapon_off, text_y, (weapon_icon.width * s) / 1.35, (weapon_icon.height * s) / 1.35, weapon_color.r, weapon_color.g, weapon_color.b, line.alpha, false)

				local xtra_x = mod_x + pad + attack_w + pad + assist_w + c_weapon_off + (weapon_icon.width * s) / 1.35 + pad
				if line.noscope then
					noscope_image:draw(xtra_x, text_y, (noscope_image.width * s) / 1.35, (noscope_image.height * s) / 1.35, xtra_color.r, xtra_color.g, xtra_color.b, line.alpha, false)
				end
				if line.headshot then
					headshot_image:draw(xtra_x + noscope_w, text_y, (headshot_image.width * s) / 1.35, (headshot_image.height * s) / 1.35, xtra_color.r, xtra_color.g, xtra_color.b, line.alpha, false)
				end
				if line.penetrated then
					penetrate_image:draw(xtra_x + noscope_w + headshot_w, text_y, (penetrate_image.width * s) / 1.35, (penetrate_image.height * s) / 1.35, xtra_color.r, xtra_color.g, xtra_color.b, line.alpha, false)
				end

				if line.time + decay_time <= time then
					line.alpha = line.alpha - 6
				else
					line.alpha = clamp(line.alpha + 15, 0, 255)
				end	
				if line.alpha < 0 then
					table.remove(kill_list, i)
				end
				lines = lines + 1
			end
		end
	end
end

local function draw_spectating(gap, accent, player)	
	if player ~= entity.get_local_player() then
		local w, h = 300 * s, 80 * s
		local ava_r = h - (b * 2)
		local steam_id = entity.get_steam64(player)
		if steam_id ~= nil then
			local avatar = steam_id == 0 and (entity.get_prop(player, "m_iTeamNum") == 3 and ct_bot or t_bot) or images.get_steam_avatar(steam_id)
			if avatar ~= nil then
				local t_font = surface.create_font(font_str, (29 + fo) * s, 1, {0x010, 0x200}) -- 
				local t_w, t_h = surface.get_text_size(t_font, entity.get_player_name(player))
				
				local long_w = ava_r + t_w + (b * 4)
				w = w > long_w and w or long_w
				local x, y = (screen_w / 2) - (w / 2), screen_h - gap - (h * 2)
				
				draw_box(x, y, w, h)
				draw_box(x, y, w, h)

				avatar:draw(x + b, y + b, h - (b * 2), h - (b * 2), 255, 255, 255, 255, true)

				local mod_x, mod_y = x + ava_r + b_gap, y + t_h + b
				local name_color = entity.get_prop(player, "m_iTeamNum") == 3 and accent.ct or accent.t
				surface.draw_text(mod_x - b, y + b, name_color.r, name_color.g, name_color.b, 255, t_font, entity.get_player_name(player))

				local player_resource = entity.get_player_resource()
				local kills = entity.get_prop(player_resource, "m_iKills", player) 
				local deaths = entity.get_prop(player_resource, "m_iDeaths", player)
				local assists = entity.get_prop(player_resource, "m_iAssists", player)
				local headshots = entity.get_prop(player_resource, "m_iMatchStats_HeadShotKills_Total", player)

				local i_font = surface.create_font(font_str, (18 + fo) * s, 1, {0x010}) 
				local i_w, i_h = surface.get_text_size(i_font, "HEIGHT")
				surface.draw_text(mod_x, mod_y, 185, 185, 185, 255, i_font, "Kills : " .. kills)
				surface.draw_text(mod_x, mod_y + (i_h) + b, 185, 185, 185, 255, i_font, "Deaths : " .. deaths)
				
				surface.draw_text(mod_x + (w / 3), mod_y, 185, 185, 185, 255, i_font, "Assists : " .. assists)
				surface.draw_text(mod_x + (w / 3), mod_y + (i_h) + b, 185, 185, 185, 255, i_font, "HS% : " .. math.floor(headshots / kills * 100) .. "%")
			end
		end
	end
end

local chat_hide_time, last_chat_time, box_alpha, text_alpha, max_lines, clear_time, hid_time, flash = 6.5, 0, 0, 0, 8, 5, 0, 0
-- max chat char length is 245 chars
local chat_input = false
local function draw_chat(gap, accent, player)
	---------------------------
	local keycode = char_to_keycode(get_key_binding("messagemode"))
	local is_down = client.key_state(keycode)
	if is_down and not chat_input then
		chat_input = true
	end
	---------------------------

	local max_h = (150 * s)
	local line_h = 20 * s	
	box_alpha = last_chat_time + chat_hide_time > globals.curtime() and box_alpha + 15 or box_alpha - 8
	box_alpha = clamp(box_alpha, 0, 131)

	text_alpha = last_chat_time + chat_hide_time > globals.curtime() and box_alpha + 30 or box_alpha - 16
	text_alpha = clamp(text_alpha, 0, 255)

	local c_font = surface.create_font(font_str, (21 + fo) * s, 1, {0x010}) 
	
	local w, h = (screen_w / 4) * s, line_h
	local x, y = gap, (screen_h - gap - (53 * s)) - ((53 * s) / 1.5) - h - (100 * s)
	if box_alpha > 0 then
		local total_lines, index = 0, 1
		local chat_list = {}
		hid_time = globals.curtime()

		while((total_lines < max_lines) and (index <= #chat_queue)) do -- i hate while loops
			local chat_line = chat_queue[index]
			local overflow = return_overflow_table(chat_line, c_font, w - b) 
			total_lines = total_lines + #overflow
			index = index + 1

			for i = #overflow, 1, -1 do
				table.insert(chat_list, overflow[i])
			end
		end

		h = line_h * math.min(total_lines, max_lines)
		y = (screen_h - gap - (53 * s)) - ((53 * s) / 1.5) - h - (100 * s)

		draw_box(x, y, w, h, nil, box_alpha)
		for i = 1, math.min(#chat_list, max_lines) do
			local mod_x = x + b
			local mod_y = y + h - (line_h * i) - (b / 3)
			if type(chat_list[i]) == "table" then
				local p_name = chat_list[i].name
				local name_color = p_name == ((chat_list[i].dead and "*DEAD* " or "") .. (chat_list[i].tsay and "(TEAM) " or "") .. entity.get_player_name(entity.get_local_player())) and accent.feed_local_name or (chat_list[i].team == 3 and accent.ct or accent.t)
				surface.draw_text(mod_x, mod_y, name_color.r, name_color.g, name_color.b, text_alpha, c_font, p_name)
				local name_offset = {surface.get_text_size(c_font, p_name)}
				surface.draw_text(mod_x + name_offset[1], mod_y, 255, 255, 255, text_alpha, c_font, " : " .. chat_list[i].text)
			else
				surface.draw_text(mod_x, mod_y, 255, 255, 255, text_alpha, c_font, hat_list[i])
			end
		end
	else
		if clear_time + hid_time < globals.curtime() then
			chat_queue = {}
		end
	end

	if chat_input then -- ready for chat input
		last_chat_time = globals.curtime()
		if hit_exit_key ~= 0 then -- 
			chat_input = false
			if hit_exit_key == 64 then
				client.exec("say \"" .. string.sub(input_string, 2, #input_string) .. "\"")
			end
			hit_exit_key = 0	
		end
		local mod_y = y + h + (b * 2)
		draw_box(x, mod_y, w, line_h)

		local visual_str = string.sub(input_string, 2, #input_string)
		local str_w, str_h = surface.get_text_size(c_font, visual_str)
		if str_w >= w - b then
			local measure_str = ""
			for i = #visual_str, 1, -1 do
				local this_w, this_h = surface.get_text_size(c_font, string.sub(visual_str, i, i) .. measure_str)
				if this_w < w - b then
					measure_str = string.sub(visual_str, i, i) .. measure_str
				end
			end
			visual_str = measure_str
		end
		surface.draw_text(x + b, mod_y, 255, 255, 255, text_alpha, c_font, visual_str)
		if flash + 0.5 <= globals.curtime() then
			str_w, str_h = surface.get_text_size(c_font, visual_str)
			surface.draw_filled_rect(x + b + str_w + b, mod_y + 2, 5 * s, line_h - 2, 255, 255, 255, 215)
			if flash + 1 <= globals.curtime() then
				flash = globals.curtime()
			end
		end
	else
		input_string = ""
		local speakers = get_speaking_players()
		local max_chat = 4
		for i = 1, (math.min(max_chat, #speakers)) do
			local speaker = speakers[i]
			if speaker ~= nil then
				local mod_x = x + (math.floor((i - 1) / 2) * (w / 2.5))
				local mod_y = y + h + b_gap + ((line_h + b_gap) * (i % 2 == 0 and 1 or 0))
				draw_box(mod_x, mod_y, line_h, line_h)
				
				local steam_id = entity.get_steam64(speaker)
				local avatar = steam_id == 0 and (entity.get_prop(speaker, "m_iTeamNum") == 3 and ct_bot or t_bot) or images.get_steam_avatar(steam_id)
				if avatar ~= nil then
					avatar:draw(mod_x, mod_y, line_h, line_h, 255, 255, 255, 255, true)
				end

				local name_color = speaker == entity.get_local_player() and accent.feed_local_name or (entity.get_prop(speaker, "m_iTeamNum") == 3 and accent.ct or accent.t)
				local s_font = surface.create_font(font_str, (21 + fo) * s, 1, {0x010, 0x200}) 
				surface.draw_text(mod_x + line_h + (b * 2), mod_y, name_color.r, name_color.g, name_color.b, 205, s_font, entity.get_player_name(speaker))
			end
		end
	end
end

local third_person, third_person_key = ui.reference('VISUALS', 'Effects', 'Force third person (alive)')
local function draw_crosshair()
	if ui.get(third_person) and ui.get(third_person_key) then return end

	local cx, cy = screen_w / 2, screen_h / 2
	local thicc, length, gapp, outline, t, dot = ui_get(crosshair.thic), ui_get(crosshair.len), ui_get(crosshair.gap), ui_get(crosshair.outline), ui_get(crosshair.tshape), ui_get(crosshair.dot)
	local c_color, o_color, d_color = as_clr({ui_get(crosshair.clr)}), as_clr({ui_get(crosshair.out_clr)}), as_clr({ui_get(crosshair.dot_clr)})

	local top_x, top_y = cx - (thicc / 2), cy - length - gapp
	local bot_x, bot_y = cx - (thicc / 2), cy + gapp

	local lef_x, lef_y = cx - length - gapp, cy - (thicc / 2)
	local rig_x, rig_y = cx + gapp, cy - (thicc / 2)

	if outline then
		if not t then
			surface.draw_outlined_rect(top_x - 1, top_y - 1, thicc + 2, length + 2, o_color.r, o_color.g, o_color.b, o_color.a)
		end
		surface.draw_outlined_rect(bot_x - 1, bot_y - 1, thicc + 2, length + 2, o_color.r, o_color.g, o_color.b, o_color.a)

		surface.draw_outlined_rect(lef_x - 1, lef_y - 1, length + 2, thicc + 2, o_color.r, o_color.g, o_color.b, o_color.a)
		surface.draw_outlined_rect(rig_x - 1, rig_y - 1, length + 2, thicc + 2, o_color.r, o_color.g, o_color.b, o_color.a)
	end
	
	if dot then
		if outline then
			surface.draw_outlined_rect(cx - (thicc / 2) - 1, cy - (thicc / 2) - 1, thicc + 2, thicc + 2, o_color.r, o_color.g, o_color.b, o_color.a)
		end
		surface.draw_filled_rect(cx - (thicc / 2), cy - (thicc / 2), thicc, thicc, d_color.r, d_color.g, d_color.b, d_color.a)
	end

	if not t then
		surface.draw_filled_rect(top_x, top_y, thicc, length, c_color.r, c_color.g, c_color.b, c_color.a)
	end

	surface.draw_filled_rect(bot_x, bot_y, thicc, length, c_color.r, c_color.g, c_color.b, c_color.a)

	surface.draw_filled_rect(lef_x, lef_y, length, thicc, c_color.r, c_color.g, c_color.b, c_color.a)
	surface.draw_filled_rect(rig_x, rig_y, length, thicc, c_color.r, c_color.g, c_color.b, c_color.a)
end

--====================================== Callbacks ==========================================--

client.set_event_callback("round_start", function()
	planted_time, got_bomb_time = 0, false
	kill_list, ended_header, mvp_header = {}, {}, {}
end)

client.set_event_callback("round_end", function(e)
	local ent = client.userid_to_entindex(e.userid) 
	ended_header = {
		winner = e.winner,
		message = localize(e.message),
	}
end)

client.set_event_callback("round_mvp", function(e)
	local ent = client.userid_to_entindex(e.userid) 
	mvp_header = {
		name = entity.get_player_name(ent),
		reason = e.reason,
	}
end)

client.set_event_callback("paint", function() --> Main
	if not ui_get(hud_enable) then return end

	local gap     = ui_get(hud_offset) * s
	local accent  = get_active_color()

	s = tonumber(ui_get(dpi_scale):sub(1, -2))/100
	b = 4 * s
	b_gap = b * 3

	screen_w, screen_h = client.screen_size()

	local player = player()
	if player ~= nil then	
		draw_health_and_equipment(gap, accent, player)
		draw_weapons(gap, accent, player)	
		draw_spectating(gap, accent, player)
		if ui_get(cross_enable) and entity.get_prop(player, "m_bIsScoped") ~= 1 then
			draw_crosshair()
		end	
	end

	draw_kill_feed(gap, accent, player)	
	draw_header(gap, accent, player)
	draw_chat(gap, accent, player)
end)

client.set_event_callback("predict_command", function()
	if chat_input then
    	capture_key_input()
	end
end)

client.set_event_callback("player_chat", function(e) 
	local ent = e.entity
	if not GameStateAPI.IsSelectedPlayerMuted(steam_64(entity.get_steam64(ent))) then
		last_chat_time = globals.curtime()
		table.insert(chat_queue, 1,
		{
			time = globals.curtime(),
			name = (not entity.is_alive(ent) and "*DEAD* " or "") .. (e.teamonly and "(TEAM) " or "")  .. entity.get_player_name(ent),
			team = entity.get_prop(ent, "m_iTeamNum"),
			dead = not entity.is_alive(ent),
			tsay = e.teamonly,
			text = e.text,
		})

		if #chat_queue > 20 then
			table.remove(chat_queue, #chat_queue)
		end
	end
end)

-- LOOK AWAY, THIS IS EMBARRASING STOP LOOKING HOLY FUCK PLEASE LOOK AWAY
client.set_event_callback("setup_command", function(e)
	if chat_input then
		e.in_jump = 0; e.in_duck = 0; e.in_forward = 0; e.in_back = 0; e.in_use = 0
		e.in_cancel = 0; e.in_left = 0; e.in_right = 0; e.in_moveleft = 0; e.in_moveright = 0
		e.in_attack = 0; e.in_attack2 = 0; e.in_run = 0; e.in_reload = 0
-- LOOK AWAY, THIS IS EMBARRASING STOP LOOKING HOLY FUCK PLEASE LOOK AWAY
		e.in_alt1 = 0; e.in_alt2 = 0; e.in_score = 0; e.forwardmove = 0; e.sidemove = 0
		e.in_speed = 0; e.in_walk = 0; e.in_zoom = 0; e.in_weapon1 = 0; e.in_weapon2 = 0
		e.in_bullrush = 0; e.in_grenade1 = 0; e.in_grenade2 = 0; e.in_attack3 = 0
		e.weaponselect = 0; e.weaponsubtype = 0
	end
end)
-- LOOK AWAY, THIS IS EMBARRASING STOP LOOKING HOLY FUCK PLEASE LOOK AWAY
-- LOOK AWAY, THIS IS EMBARRASING STOP LOOKING HOLY FUCK PLEASE LOOK AWAY
local cached_angles = {did = false, x = 0, y = 0, z = 0, pitch = 0, yaw = 0, fov = 0}
client.set_event_callback("override_view", function(e)
	if chat_input then
		if not cached_angles.did then
			cached_angles = {did = true, x = e.x, y = e.y, z = e.z, pitch = e.pitch, yaw = e.yaw, fov = e.fov}
		end
		-- LOOK AWAY, THIS IS EMBARRASING STOP LOOKING HOLY FUCK PLEASE LOOK AWAY
		--e.x = cached_angles.x
		--e.y = cached_angles.y
		--e.z = cached_angles.z
		e.pitch = cached_angles.pitch
		e.yaw   = cached_angles.yaw
		e.fov   = cached_angles.fov
		-- LOOK AWAY, THIS IS EMBARRASING STOP LOOKING HOLY FUCK PLEASE LOOK AWAY
		client.camera_angles(cached_angles.pitch, cached_angles.yaw)
	else
		cached_angles = {did = false, x = 0, y = 0, z = 0, pitch = 0, yaw = 0, fov = 0}
	end
end)

client.set_event_callback('player_death', function(e)
	local attacker, victim, assister = client.userid_to_entindex(e.attacker), client.userid_to_entindex(e.userid), client.userid_to_entindex(e.assister)
	local weapon, headshot, penetrated, noscope, thrusmoke = csgo_weapons[tonumber(InventoryAPI.GetItemDefinitionIndex(e.weapon_fauxitemid))], e.headshot, e.penetrated == 1 and true or false, e.noscope, e.thrusmoke

	--could pass all event data, but too much shit
	if weapon == nil then
		weapon = e.weapon
	end

	table.insert(kill_list, 
	{
		time = globals.curtime(),

		attacker = entity.get_player_name(attacker),
		attacker_team = entity.get_prop(attacker, "m_iTeamNum"),

		victim   = entity.get_player_name(victim),
		victim_team = entity.get_prop(victim, "m_iTeamNum"),

		assister = assister ~= 0 and entity.get_player_name(assister) or nil,
		assister_team = assister ~= 0 and entity.get_prop(assister, "m_iTeamNum") or nil,

		weapon = weapon, -- as csgo_weapon
		-- bools -- 
		headshot = headshot, 
		penetrated = penetrated,
		noscope = noscope,
		thrusmoke = thrusmoke,
		alpha = 1
	})
end)

local hud = cvar.cl_drawhud
local radar = cvar.cl_drawhud_force_radar
local old_status = false
client.set_event_callback("paint_ui", function()
	local connected = GameStateAPI.IsPlayerConnected(panorama.open().MyPersonaAPI.GetXuid())
	if connected ~= old_status then
		kill_list, ended_header, mvp_header, chat_queue, last_chat_time = {}, {}, {}, {}, globals.curtime() - chat_hide_time
	end
	old_status = connected

	local enable = ui_get(hud_enable)
	hud:set_int(enable and 0 or 1)
	radar:set_raw_int(1)

	setTableVisibility({ hud_offset, hud_scheme }, enable)
	setTableVisibility(crosshair, enable and ui_get(cross_enable))
	setTableVisibility(clrs, (enable and ui_get(hud_scheme) == "Custom"))
end)
client.set_event_callback("shutdown", function()
	hud:set_int(1)
end)

--============================================================================================--
