-- minerland_fix_npc/guard.lua
-- Garde immortel qui salue amelaye et menace les autres joueurs

local S = core.get_translator("minerland_fix_npc")
local mcl = core.get_modpath("mcl_core") ~= nil

local QUEEN = "amelaye"
local GREET_DIST = 3   -- distance de salutation pour la reine
local THREAT_DIST = 3  -- distance de menace pour les autres

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
	pathfinding = false,
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
	walk_velocity = 0,
	run_velocity = 0,
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

	-- leads : non attachable, non déplaçable
	_leads_leashable = false,
	_leads_immobile = true,

	-- éjecte le joueur qui tente de l'attacher
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

	-- état interne
	_greeted = {},
	_threatened = {},

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

	on_step = function(self, dtime)

		-- reste immobile
		self:set_velocity(0)
		self.order = "stand"

		local pos = self.object:get_pos()
		if not pos then return end

		local players = core.get_connected_players()
		for _, player in ipairs(players) do
			local pname = player:get_player_name()
			local ppos = player:get_pos()
			if ppos then
				local dist = vector.distance(pos, ppos)

				if pname == QUEEN then
					-- salutation de la reine
					if dist <= GREET_DIST and not self._greeted[pname] then
						self._greeted[pname] = true

						-- s'accroupit
						self.object:set_properties({
							visual_size = {x=1, y=0.5},
							collisionbox = {-0.35,-1.0,-0.35, 0.35,0.3,0.35},
						})
						core.chat_send_player(pname,
							"<" .. (self.nametag or S("Guard")) .. "> " ..
							S("Bonjour votre majesté !"))

						-- se relève après 2s
						local obj = self.object
						core.after(2, function()
							if obj and obj:get_pos() then
								obj:set_properties({
									visual_size = {x=1, y=1},
									collisionbox = {-0.35,-1.0,-0.35, 0.35,0.8,0.35},
								})
							end
						end)

					elseif dist > GREET_DIST then
						self._greeted[pname] = nil
					end

				else
					-- menace les autres joueurs
					if dist <= THREAT_DIST and not self._threatened[pname] then
						self._threatened[pname] = true

						self.object:set_properties({
							wield_item = mcl and "mcl_tools:sword_diamond"
								or "default:sword_diamond",
						})
						core.chat_send_player(pname,
							"<" .. (self.nametag or S("Guard")) .. "> " ..
							S("Halte ! Vous n'êtes pas autorisé ici !"))

					elseif dist > THREAT_DIST then
						if self._threatened[pname] then
							self._threatened[pname] = nil
							self.object:set_properties({wield_item = ""})
						end
					end
				end
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

-- spawn egg
mobs:register_egg("minerland_fix_npc:guard", S("Guard"),
	mcl and "mcl_core:iron_block.png" or "default_steel_block.png", 1)