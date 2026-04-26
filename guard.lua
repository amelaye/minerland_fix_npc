-- minerland_fix_npc/guard.lua
-- Garde immortel qui salue amelaye et menace les autres joueurs

local S = core.get_translator("minerland_fix_npc")
local mcl = core.get_modpath("mcl_core") ~= nil

local QUEEN = "amelaye"
local GREET_DIST = 3
local THREAT_DIST = 3

-- état par garde : clé = object (weak), valeur = {greeted, threatened, bowing}
local guard_states = setmetatable({}, {__mode = "k"})

local function get_state(obj)
	if not guard_states[obj] then
		guard_states[obj] = {greeted = {}, threatened = {}, bowing = false}
	end
	return guard_states[obj]
end

-- lève les deux bras (révérence)
local function bow(obj)
	if obj.set_bone_override then
		-- Luanti 5.9+
		obj:set_bone_override("Arm_Right", {
			rotation = {vec = vector.new(math.pi * 0.8, 0, 0), absolute = true}
		})
		obj:set_bone_override("Arm_Left", {
			rotation = {vec = vector.new(math.pi * 0.8, 0, 0), absolute = true}
		})
	else
		-- fallback ancien API
		obj:set_bone_position("Arm_Right", vector.new(0,0,0), vector.new(-145, 0, 0))
		obj:set_bone_position("Arm_Left",  vector.new(0,0,0), vector.new(-145, 0, 0))
	end
end

-- remet les bras en position normale
local function unbowarms(obj)
	if obj.set_bone_override then
		obj:set_bone_override("Arm_Right", {})
		obj:set_bone_override("Arm_Left",  {})
	else
		obj:set_bone_position("Arm_Right", vector.new(0,0,0), vector.new(0, 0, 0))
		obj:set_bone_position("Arm_Left",  vector.new(0,0,0), vector.new(0, 0, 0))
	end
end

mobs:register_mob("minerland_fix_npc:guard", {
	description = S("Guard"),
	type = "npc",
	passive = true,
	damage = 8,
	attack_type = "dogfight",
	attack_monsters = true,
	attack_npcs = false,
	attack_players = false,
	owner_loyal = true,
	pathfinding = true,
	hp_min = 99999,
	hp_max = 99999,
	armor = {immortal = 1},
	collisionbox = {-0.35,-1.0,-0.35, 0.35,0.8,0.35},
	visual = "mesh",
	mesh = "mobs_character.b3d",
	textures = {
		{"minerland_guard1.png"},
		{"minerland_guard2.png"},
		{"minerland_guard3.png"},
		{"minerland_guard4.png"},
		{"minerland_guard5.png"},
	},
	makes_footstep_sound = true,
	sounds = {},
	walk_velocity = 2,
	run_velocity = 3,
	drops = {},
	water_damage = 0,
	lava_damage = 0,
	light_damage = 0,
	view_range = 10,
	owner = QUEEN,
	order = "stand",
	fear_height = 0,
	animation = {
		speed_normal = 30, speed_run = 30,
		stand_start = 0, stand_end = 79,
		walk_start = 168, walk_end = 187,
		run_start = 168, run_end = 187,
		punch_start = 189, punch_end = 198,
	},

	-- leads : totalement non attachable
	_leads_leashable = false,
	_leads_immobile = true,

	-- éjecte TOUT joueur qui tente d'attacher une laisse
	_leads_on_interact = function(self, itemstack, user, pointed_thing, is_punch)
		if user and user:is_player() then
			local pname = user:get_player_name()
			local dir = user:get_look_dir()
			user:set_velocity({
				x = -dir.x * 20,
				y = 8,
				z = -dir.z * 20,
			})
			core.chat_send_player(pname,
				"<" .. (self.nametag or S("Guard")) .. "> " ..
				S("Oses-tu m'attacher ?!"))
		end
		return true, nil
	end,

	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		if puncher and puncher:is_player() then
			local name = puncher:get_player_name()
			if name ~= QUEEN then
				self.attack_players = true
				self.state = "attack"
				self.attack = puncher
			end
		end
	end,

	on_rightclick = function(self, clicker)
		local item = clicker:get_wielded_item()
		local name = clicker:get_player_name()
		local stick = mcl and "mcl_core:stick" or "default:stick"

		if item:get_name() == stick and name == QUEEN then
			core.chat_send_player(name,
				"<" .. (self.nametag or S("Guard")) .. "> " ..
				S("À vos ordres, majesté."))
		end
	end,
})

-- globalstep : détection de proximité + fix animation stand
local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 0.5 then return end
	timer = 0

	local players = core.get_connected_players()

	for _, obj in pairs(core.luaentities) do
		if obj.name == "minerland_fix_npc:guard" and obj.object then
			local pos = obj.object:get_pos()
			if not pos then goto continue end

			local state = get_state(obj.object)

			-- fix animation stand : stoppe le mouvement si ordre = stand
			if obj.order == "stand" and obj.state ~= "attack" then
				obj:set_velocity(0)
				obj:set_animation("stand")
			end

			for _, player in ipairs(players) do
				local pname = player:get_player_name()
				local ppos = player:get_pos()
				if not ppos then goto next_player end

				local dist = vector.distance(pos, ppos)

				if pname == QUEEN then
					if dist <= GREET_DIST and not state.greeted[pname] and not state.bowing then
						state.greeted[pname] = true
						state.bowing = true

						-- lève les bras
						bow(obj.object)
						core.chat_send_player(pname,
							"<" .. (obj.nametag or S("Guard")) .. "> " ..
							S("Bonjour votre majesté !"))

						-- remet les bras après 2s
						local o = obj.object
						local st = state
						core.after(2, function()
							if o and o:get_pos() then
								unbowarms(o)
							end
							st.bowing = false
						end)

					elseif dist > GREET_DIST then
						state.greeted[pname] = nil
					end

				else
					if dist <= THREAT_DIST and not state.threatened[pname] then
						state.threatened[pname] = true

						obj.object:set_properties({
							wield_item = mcl and "mcl_tools:sword_diamond"
								or "default:sword_diamond",
						})
						core.chat_send_player(pname,
							"<" .. (obj.nametag or S("Guard")) .. "> " ..
							S("Halte ! Vous n'êtes pas autorisé ici !"))

					elseif dist > THREAT_DIST and state.threatened[pname] then
						state.threatened[pname] = nil
						obj.object:set_properties({wield_item = ""})
					end
				end

				::next_player::
			end

			::continue::
		end
	end
end)

-- spawn egg
mobs:register_egg("minerland_fix_npc:guard", S("Guard"),
	mcl and "mcl_core:iron_block.png" or "default_steel_block.png", 1)

-- bloque l'attachement via leads même par le owner
core.register_on_mods_loaded(function()
	if leads and leads.custom_leashable_entities then
		leads.custom_leashable_entities["minerland_fix_npc:guard"] = false
	end
    if lead_def then
        core.log("action", "leads:lead handlers: " .. dump({
            on_use = lead_def.on_use ~= nil,
            on_secondary_use = lead_def.on_secondary_use ~= nil,
            on_rightclick = lead_def.on_rightclick ~= nil,
            on_place = lead_def.on_place ~= nil,
        }))
    end
end)