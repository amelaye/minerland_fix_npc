-- minerland_fix_npc/guard.lua
-- Garde immortel qui salue amelaye et menace les autres joueurs

local S = core.get_translator("minerland_fix_npc")
local mcl = core.get_modpath("mcl_core") ~= nil

local QUEEN = core.settings:get("minerland_guard_queen") or "amelaye"
local GREET_DIST = tonumber(core.settings:get("minerland_guard_greet_dist")) or 3
local THREAT_DIST = tonumber(core.settings:get("minerland_guard_threat_dist")) or 3

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
		-- annule toute projection
		self.object:set_velocity({x = 0, y = 0, z = 0})
		core.after(0.05, function()
			if self.object and self.object:get_pos() then
				self.object:set_velocity({x = 0, y = 0, z = 0})
			end
		end)
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

			-- détection revolver dans un rayon de 10 blocs
			if not state.gun_warned then
				state.gun_warned = {}
			end
			for _, player in ipairs(players) do
				local pname = player:get_player_name()
				local ppos = player:get_pos()
				if ppos then
					local dist = vector.distance(pos, ppos)
					local wielded = player:get_wielded_item():get_name()
					if dist <= 10 and (wielded == "rangedweapons:taurus" or wielded == "rangedweapons:python") then
						if not state.gun_warned[pname] then
							state.gun_warned[pname] = true
							core.chat_send_all("<" .. (obj.nametag or S("Guard")) .. "> HALTE !! Un terroriste !!!")
							core.after(5, function()
								if state.gun_warned then
									state.gun_warned[pname] = nil
								end
							end)
						end
					else
						state.gun_warned[pname] = nil
					end
				end
			end

			for _, player in ipairs(players) do
				local pname = player:get_player_name()
				local ppos = player:get_pos()
				if not ppos then goto next_player end

				local dist = vector.distance(pos, ppos)

				-- éjecte si le joueur tient une laisse et est proche
				if player:get_wielded_item():get_name() == "leads:lead"
				and dist <= 3 then
					if not state.lead_warned then
						state.lead_warned = {}
					end
					if not state.lead_warned[pname] then
						state.lead_warned[pname] = true

						-- retire le fly temporairement
						local privs = core.get_player_privs(pname)
						local had_fly = privs.fly
						if had_fly then
							privs.fly = false
							core.set_player_privs(pname, privs)
						end

						-- éjection
						local gpos = obj.object:get_pos()
						local ppos = player:get_pos()
						local dir = vector.normalize(vector.subtract(ppos, gpos))
						dir.y = 0
						local hvel = vector.multiply(dir, 15)
						player:add_velocity({x = hvel.x, y = 12, z = hvel.z})

						-- coup de pied
						local o = obj.object
						o:set_bone_override("Leg_Right", {
							rotation = {vec = {x = -1.0, y = 0, z = 0}, interpolation = 0.1}
						})
						core.after(0.5, function()
							if o and o:get_pos() then
								o:set_bone_override("Leg_Right", {
									rotation = {vec = {x = 0, y = 0, z = 0}, interpolation = 0.2}
								})
							end
						end)

						core.chat_send_player(pname,
							"<" .. (obj.nametag or "Garde") .. "> Oses-tu m'attacher ?!")

						-- reset après 3s
						core.after(3, function()
							if state.lead_warned then
								state.lead_warned[pname] = nil
							end
							-- remet le fly
							if had_fly then
								local p = privs
								p.fly = true
								core.set_player_privs(pname, p)
							end
						end)
					end
					goto next_player
				end
				if state.lead_warned then
					state.lead_warned[pname] = nil
				end

				-- se tourne vers tout joueur proche
				if dist <= THREAT_DIST then
					local gpos = obj.object:get_pos()
					local ppos = player:get_pos()
					local dir = vector.subtract(ppos, gpos)
					local yaw = math.atan2(-dir.x, dir.z)
					obj.object:set_yaw(yaw)
				end

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

-- réserve l'oeuf aux admins (priv server)
core.register_on_mods_loaded(function()
	local egg_def = core.registered_items["minerland_fix_npc:guard"]
	if not egg_def then return end

	core.override_item("minerland_fix_npc:guard", {
		on_place = function(itemstack, placer, pointed_thing)
			if not placer or not placer:is_player() then return end
			if not core.check_player_privs(placer, {server = true}) then
				core.chat_send_player(placer:get_player_name(),
					S("Vous n'avez pas la permission d'invoquer un garde."))
				-- éjecte le joueur
				local privs = core.get_player_privs(placer:get_player_name())
				local had_fly = privs.fly
				if had_fly then
					privs.fly = false
					core.set_player_privs(placer:get_player_name(), privs)
				end
				local dir = placer:get_look_dir()
				dir.y = 0
				local hvel = vector.multiply(vector.normalize(dir), -15)
				placer:add_velocity({x = hvel.x, y = 12, z = hvel.z})
				core.after(3, function()
					if had_fly then
						privs.fly = true
						core.set_player_privs(placer:get_player_name(), privs)
					end
				end)
				return itemstack
			end
			local pos = core.get_pointed_thing_position(pointed_thing, true)
			if pos then
				core.add_entity(pos, "minerland_fix_npc:guard")
				if not core.is_creative_enabled(placer:get_player_name()) then
					itemstack:take_item()
				end
			end
			return itemstack
		end
	})
end)

-- bloque l'attachement via leads même par le owner
core.register_on_mods_loaded(function()
	if leads and leads.custom_leashable_entities then
		leads.custom_leashable_entities["minerland_fix_npc:guard"] = false
	end
end)