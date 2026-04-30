-- minerland_fix_npc/guard.lua
-- Garde immortel qui salue la reine et menace les autres joueurs

local S = core.get_translator("minerland_fix_npc")
local mcl = core.get_modpath("mcl_core") ~= nil

QUEEN = core.settings:get("minerland_guard_queen")
if not QUEEN then QUEEN = "amelaye" end

GREET_DIST = tonumber(core.settings:get("minerland_guard_greet_dist"))
if not GREET_DIST then GREET_DIST = 3 end

THREAT_DIST = tonumber(core.settings:get("minerland_guard_threat_dist"))
if not THREAT_DIST then THREAT_DIST = 3 end

SUSPECT = core.settings:get("minerland_guard_suspect")
if not SUSPECT then SUSPECT = "Luffy0805" end

SUSPECT_DIST = tonumber(core.settings:get("minerland_guard_suspect_dist"))
if not SUSPECT_DIST then SUSPECT_DIST = 10 end

RESCUE_DIST = tonumber(core.settings:get("minerland_guard_rescue_dist"))
if not RESCUE_DIST then RESCUE_DIST = 20 end

GUARD_COLOR = core.settings:get("minerland_guard_color")
if not GUARD_COLOR then GUARD_COLOR = "#FF0000" end

-- garde d'urgence actif (un seul à la fois)
local rescue_guard_obj = nil

-- détecte toute arme rangedweapons
local function is_ranged_weapon(item_name)
	local def = core.registered_items[item_name]
	return def and def.RW_gun_capabilities ~= nil
end

-- état par garde (weak table) -- exposé pour init.lua
guard_states = setmetatable({}, {__mode = "k"})

local function get_state(obj)
	if not guard_states[obj] then
		guard_states[obj] = {
			greeted        = {},
			threatened     = {},
			bowing         = false,
			lead_warned    = {},
			gun_warned     = {},
			shooting       = false,
			suspect_warned = {},
		}
	end
	return guard_states[obj]
end

local function bow(obj)
	obj:set_bone_override("Arm_Right", {
		rotation = {vec = vector.new(math.pi * 0.8, 0, 0), absolute = true}
	})
	obj:set_bone_override("Arm_Left", {
		rotation = {vec = vector.new(math.pi * 0.8, 0, 0), absolute = true}
	})
end

local function unbow(obj)
	obj:set_bone_override("Arm_Right", {})
	obj:set_bone_override("Arm_Left",  {})
end

local function eject(player, pname, gpos)
	local privs = core.get_player_privs(pname)
	local had_fly = privs.fly
	if had_fly then
		privs.fly = false
		core.set_player_privs(pname, privs)
	end
	local ppos = player:get_pos()
	local dir = vector.normalize(vector.subtract(ppos, gpos))
	dir.y = 0
	local hvel = vector.multiply(dir, 15)
	player:add_velocity({x = hvel.x, y = 12, z = hvel.z})
	core.after(3, function()
		if had_fly then
			privs.fly = true
			core.set_player_privs(pname, privs)
		end
	end)
end

core.register_entity("minerland_fix_npc:taurus_visual", {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = false,
		visual = "wielditem",
		textures = {"rangedweapons:taurus"},
		visual_size = {x = 0.20, y = 0.20},
		is_visible = true,
	},
	on_activate = function(self, staticdata)
		local data = core.deserialize(staticdata) or {}
		if data.remove then self.object:remove() end
	end,
	get_staticdata = function(self)
		return core.serialize({remove = true})
	end,
})

function attach_taurus(guard_obj)
	local ent = core.add_entity(guard_obj:get_pos(), "minerland_fix_npc:taurus_visual")
	if not ent then return nil end
	ent:set_attach(guard_obj, "Arm_Right",
		{x = 0, y = 6, z = 1},
		{x = 0, y = 270, z = 0}
	)
	return ent
end

function detach_taurus(taurus_ent)
	if taurus_ent and taurus_ent:get_pos() then
		taurus_ent:remove()
	end
end

core.register_entity("minerland_fix_npc:guard_bullet", {
	initial_properties = {
		physical = true,
		collide_with_objects = false,
		pointable = false,
		visual = "wielditem",
		textures = {"rangedweapons:shot_bullet_visual"},
		visual_size = {x = 0.1, y = 0.1},
		collisionbox = {-0.05, -0.05, -0.05, 0.05, 0.05, 0.05},
		is_visible = true,
	},
	_damage = 50,
	_timer = 0,
	_hit = false,
	on_activate = function(self, staticdata)
		local data = core.deserialize(staticdata) or {}
		if data.remove then self.object:remove() end
		self._timer = 0
		self._hit = false
	end,
	get_staticdata = function(self)
		return core.serialize({remove = true})
	end,
	on_step = function(self, dtime)
		self._timer = (self._timer or 0) + dtime
		if self._timer > 5 then self.object:remove() return end
		if self._hit then return end
		local pos = self.object:get_pos()
		if not pos then return end
		local objs = core.get_objects_inside_radius(pos, 2.5)
		for _, obj in ipairs(objs) do
			if obj:is_player() then
				self._hit = true
				local pname = obj:get_player_name()
				local privs = core.get_player_privs(pname)
				local had_fly = privs.fly
				if had_fly then
					core.chat_send_player(pname,
    					core.colorize(GUARD_COLOR, "<Garde Royale>") ..
    					" Vous avez le fly désactivé 30 secondes.")
					privs.fly = nil
					core.set_player_privs(pname, privs)
					local t = core.get_us_time()
					core.after(30, function()
						local p = core.get_player_by_name(pname)
						if not p then return end
						-- ne rend le fly que si aucun retrait plus récent
						if core.get_us_time() - t < 31000000 then
							local p_privs = core.get_player_privs(pname)
							p_privs.fly = true
							core.set_player_privs(pname, p_privs)
						end
					end)
				end
				local hp = obj:get_hp()
				obj:set_hp(math.max(0, hp - self._damage))
				local vel = self.object:get_velocity()
				if vel and vector.length(vel) > 0 then
					local dir = vector.normalize(vel)
					obj:add_velocity({x=dir.x*20, y=15, z=dir.z*20})
				end
				core.sound_play("rangedweapons_deagle", {pos=pos, gain=1.0, max_hear_distance=50}, true)
				self.object:remove()
				return
			end
		end
		local node = core.get_node(pos)
		local def = core.registered_nodes[node.name]
		if def and def.walkable then self.object:remove() end
	end,
})

function fire_bullet(guard_obj, target_player)
	local gpos = guard_obj:get_pos()
	if not gpos then return end
	local ppos = target_player:get_pos()
	if not ppos then return end
	gpos.y = gpos.y + 0.8
	local dir = vector.normalize(vector.subtract(ppos, gpos))
	local bullet = core.add_entity(gpos, "minerland_fix_npc:guard_bullet")
	if bullet then
		bullet:set_velocity(vector.multiply(dir, 60))
		bullet:set_acceleration({x=0, y=-2, z=0})
	end
	core.sound_play("rangedweapons_deagle", {pos=gpos, gain=1.0, max_hear_distance=50}, true)
end

function raise_arm(obj)
	obj:set_bone_override("Arm_Right", {
		rotation = {vec = {x = 1.5708, y = 0, z = 0}, interpolation = 0.15}
	})
end

function lower_arm(obj)
	obj:set_bone_override("Arm_Right", {})
end

mobs:register_mob("minerland_fix_npc:guard", {
	description = "Garde Royale",
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
	armor = {immortal = 1, fleshy = 100},
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
		stand_start = 0,   stand_end = 79,
		walk_start = 168,  walk_end = 187,
		run_start = 168,   run_end = 187,
		punch_start = 189, punch_end = 198,
	},

	_leads_leashable = false,
	_leads_immobile  = true,

	_leads_on_interact = function(self, itemstack, user, pointed_thing, is_punch)
		return true, nil
	end,

	on_step = function(self, dtime)
		if self.order ~= "follow" then
			self.object:set_velocity({x = 0, y = 0, z = 0})
		end
	end,

	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		self.object:set_velocity({x = 0, y = 0, z = 0})
	end,

	on_rightclick = function(self, clicker)
		local item = clicker:get_wielded_item()
		local name = clicker:get_player_name()
		local stick = mcl and "mcl_core:stick" or "default:stick"
		if item:get_name() == stick and name == QUEEN then
			core.chat_send_player(name,
				core.colorize(GUARD_COLOR, "<" .. (self.nametag or "Garde Royale") .. ">") .. " " ..
				S("À vos ordres, majesté."))
		end
	end,
})

-- globalstep
local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 0.05 then return end
	timer = 0

	local players = core.get_connected_players()

	for _, obj in pairs(core.luaentities) do
		if obj.name ~= "minerland_fix_npc:guard" or not obj.object then goto continue end

		local pos = obj.object:get_pos()
		if not pos then goto continue end

		local state = get_state(obj.object)

		-- force immobilité + annule knockback
		if obj.order ~= "follow" then
			obj.object:set_velocity({x = 0, y = 0, z = 0})
			if obj.order == "stand" then
				obj:set_animation("stand")
			end
		end

		-- force HP max en permanence
		obj.object:set_hp(65535)
		if obj.health then obj.health = obj.hp_max or 99999 end

		-- détecte projectile ennemi proche et riposte UNE FOIS
		if not state.shooting then
			for _, bullet in pairs(core.luaentities) do
				if bullet.name == "rangedweapons:shot_bullet" and bullet.object then
					local bpos = bullet.object:get_pos()
					if bpos and vector.distance(pos, bpos) <= 5 then
						local shooter = bullet.owner and core.get_player_by_name(bullet.owner)
						if shooter and shooter:get_pos() then
							state.shooting = true
							if not state.taurus_ent then
								state.taurus_ent = attach_taurus(obj.object)
							end
							raise_arm(obj.object)
							local sdir = vector.subtract(shooter:get_pos(), pos)
							obj.object:set_yaw(math.atan2(-sdir.x, sdir.z))
							local gobj = obj.object
							core.after(0.1, function()
								if not gobj or not gobj:get_pos() then return end
								if not shooter or not shooter:get_pos() then return end
								fire_bullet(gobj, shooter)
							end)
							core.after(3, function()
								state.shooting = false
							end)
						end
						break
					end
				end
			end
		end

		-- reset si aucun joueur proche
		local any_threatened = false
		local any_gun = false
		for _, player in ipairs(players) do
			local ppos = player:get_pos()
			if ppos then
				local dist = vector.distance(pos, ppos)
				local wielded = player:get_wielded_item():get_name()
				if dist <= THREAT_DIST then any_threatened = true end
				if dist <= 10 and is_ranged_weapon(wielded) then any_gun = true end
			end
		end
		if not any_threatened and not any_gun and not state.shooting then
			if state.taurus_ent then
				detach_taurus(state.taurus_ent)
				state.taurus_ent = nil
				lower_arm(obj.object)
			end
			state.threatened = {}
			state.gun_warned = {}
		end

		for _, player in ipairs(players) do
			local pname = player:get_player_name()
			local ppos  = player:get_pos()
			if not ppos then goto next_player end

			local dist    = vector.distance(pos, ppos)
			local wielded = player:get_wielded_item():get_name()

			-- surveillance du suspect
			if pname == SUSPECT then
				if dist <= SUSPECT_DIST and not state.suspect_warned[pname] then
					state.suspect_warned[pname] = true
					local dir = vector.subtract(ppos, pos)
					obj.object:set_yaw(math.atan2(-dir.x, dir.z))
					if not state.taurus_ent then
						state.taurus_ent = attach_taurus(obj.object)
					end
					raise_arm(obj.object)
					core.chat_send_player(pname,
						core.colorize(GUARD_COLOR, "<" .. (obj.nametag or "Garde Royale") .. ">") .. " " ..
						"Je toi surveille, sale mécréant, délinquant, traitre !")
				elseif dist > SUSPECT_DIST and state.suspect_warned[pname] then
					state.suspect_warned[pname] = nil
					if not any_gun and not any_threatened then
						detach_taurus(state.taurus_ent)
						state.taurus_ent = nil
						lower_arm(obj.object)
					end
				end
			end

			-- détection arme
			if dist <= 10 and is_ranged_weapon(wielded) then
				local dir = vector.subtract(ppos, pos)
				obj.object:set_yaw(math.atan2(-dir.x, dir.z))
				if not state.gun_warned[pname] then
					state.gun_warned[pname] = true
					if not state.taurus_ent then
						state.taurus_ent = attach_taurus(obj.object)
					end
					raise_arm(obj.object)
					core.chat_send_all(core.colorize(GUARD_COLOR, "<" .. (obj.nametag or "Garde Royale") .. ">") .. " BAISSEZ VOTRE ARME !! TOUT DE SUITE !!!")
					core.after(5, function()
						if state.gun_warned then state.gun_warned[pname] = nil end
					end)
				end
			else
				if state.gun_warned[pname] then state.gun_warned[pname] = nil end
			end

			-- éjection laisse
			if wielded == "leads:lead" and dist <= 3 then
				if not state.lead_warned[pname] then
					state.lead_warned[pname] = true
					-- se tourne vers le joueur avant d'agir
					local ldir = vector.subtract(ppos, pos)
					obj.object:set_yaw(math.atan2(-ldir.x, ldir.z))
					eject(player, pname, pos)
					obj.object:set_bone_override("Leg_Right", {
						rotation = {vec = {x = 1.0, y = 0, z = 0}, interpolation = 0.1}
					})
					core.after(0.5, function()
						if obj.object and obj.object:get_pos() then
							obj.object:set_bone_override("Leg_Right", {
								rotation = {vec = {x = 0, y = 0, z = 0}, interpolation = 0.2}
							})
						end
					end)
					core.chat_send_player(pname,
						core.colorize(GUARD_COLOR, "<" .. (obj.nametag or "Garde Royale") .. ">") .. " " ..
						S("Oses-tu m'attacher ?!"))
					core.after(3, function()
						if state.lead_warned then state.lead_warned[pname] = nil end
					end)
				end
				goto next_player
			else
				state.lead_warned[pname] = nil
			end

			-- rotation vers tout joueur proche
			if dist <= math.max(THREAT_DIST, GREET_DIST) then
				local dir = vector.subtract(ppos, pos)
				obj.object:set_yaw(math.atan2(-dir.x, dir.z))
			end

			if pname == QUEEN then
				if dist <= GREET_DIST and not state.greeted[pname] and not state.bowing then
					state.greeted[pname] = true
					state.bowing = true
					bow(obj.object)
					core.chat_send_player(pname,
						core.colorize(GUARD_COLOR, "<" .. (obj.nametag or "Garde Royale") .. ">") .. " " ..
						S("Bonjour votre majesté !"))
					local o = obj.object
					local st = state
					core.after(2, function()
						if o and o:get_pos() then unbow(o) end
						st.bowing = false
					end)
				elseif dist > GREET_DIST then
					state.greeted[pname] = nil
				end
			else
				if dist <= THREAT_DIST and not state.threatened[pname] then
					state.threatened[pname] = true
					if not state.taurus_ent then
						state.taurus_ent = attach_taurus(obj.object)
					end
					raise_arm(obj.object)
					core.chat_send_player(pname,
						core.colorize(GUARD_COLOR, "<" .. (obj.nametag or "Garde Royale") .. ">") .. " " ..
						S("Halte ! Vous n'êtes pas autorisé ici !"))
				elseif dist > THREAT_DIST and state.threatened[pname] then
					state.threatened[pname] = nil
					if not any_gun then
						detach_taurus(state.taurus_ent)
						state.taurus_ent = nil
						lower_arm(obj.object)
					end
				end
			end

			::next_player::
		end

		::continue::
	end
end)

-- oeuf du garde : invisible dans le créatif, obtention uniquement via /give
-- le on_place reste comme garde-fou si un non-admin l'obtient quand même
core.register_craftitem("minerland_fix_npc:guard", {
	description = "Garde Royale",
	inventory_image = mcl and "mcl_core:iron_block.png" or "default_steel_block.png",
	groups = {not_in_creative_list = 1},
	on_place = function(itemstack, placer, pointed_thing)
		if not placer or not placer:is_player() then return end
		local pname = placer:get_player_name()
		if not core.check_player_privs(placer, {server = true}) then
			core.chat_send_player(pname,
				S("Vous n'avez pas la permission d'invoquer un garde."))
			return itemstack
		end
		local pos = core.get_pointed_thing_position(pointed_thing, true)
		if pos then
			pos.y = pos.y + 1.0
			core.add_entity(pos, "minerland_fix_npc:guard")
			if not core.is_creative_enabled(pname) then
				itemstack:take_item()
			end
		end
		return itemstack
	end,
})

core.register_on_mods_loaded(function()
	if leads and leads.custom_leashable_entities then
		leads.custom_leashable_entities["minerland_fix_npc:guard"] = false
	end
end)

-- ============================================================
-- /osecour : appel d'un garde d'urgence contre Luffy0805
-- ============================================================

core.register_chatcommand("osecour", {
	description = S("Appelle un garde d'urgence contre le suspect."),
	func = function(name, param)
		-- Luffy ne peut pas appeler à l'aide contre lui-même
		if name == SUSPECT then
			return false, "<Garde> Non."
		end

		local caller = core.get_player_by_name(name)
		if not caller then return false, "" end

		-- vérifie que Luffy est connecté
		local luffy = core.get_player_by_name(SUSPECT)
		if not luffy then
			return false, S("Le suspect n'est pas connecté.")
		end

		-- un seul garde d'urgence à la fois
		if rescue_guard_obj and rescue_guard_obj:get_pos() then
			return false, S("Un garde est déjà en intervention !")
		end

		-- détection prison et tp home si nécessaire
		local caller_pos = caller:get_pos()
		local PRISON_MIN = {x = -1806, y = -1144,   z = -2120}
		local PRISON_MAX = {x = -1781, y = -1121.9, z = -2064}
		local in_prison = (
			caller_pos.x >= PRISON_MIN.x and caller_pos.x <= PRISON_MAX.x and
			caller_pos.y >= PRISON_MIN.y and caller_pos.y <= PRISON_MAX.y and
			caller_pos.z >= PRISON_MIN.z and caller_pos.z <= PRISON_MAX.z
		)

		-- spawn sur Luffy
		local luffy_pos = luffy:get_pos()
		luffy_pos.y = luffy_pos.y + 1.0
		local obj = core.add_entity(luffy_pos, "minerland_fix_npc:guard")
		if not obj then
			return false, S("Impossible d'invoquer un garde.")
		end

		rescue_guard_obj = obj

		-- message d'arrivée
		core.chat_send_all(core.colorize(GUARD_COLOR, "<Garde Royale>") .. " J'arrive vous sauver citoyen !")

		-- si le joueur était en prison, le tp chez lui 5 secondes après
		if in_prison then
			core.chat_send_player(name, S("La Garde Royale est en route ! Vous serez mis en sécurité dans 5 secondes..."))
			core.after(5, function()
				local p = core.get_player_by_name(name)
				if not p then return end
				local sh_storage = core.get_mod_storage()
				local home_str = sh_storage:get_string("home_" .. name)
				if not home_str or home_str == "" then
					core.chat_send_player(name, S("Aucun home défini, impossible de vous téléporter."))
					return
				end
				local hpos = core.deserialize(home_str)
				if not hpos then
					core.chat_send_player(name, S("Home corrompu, impossible de vous téléporter."))
					return
				end
				p:set_pos(hpos)
				core.chat_send_player(name, S("Vous voici en sécurité, citoyen !"))
			end)
		end

		-- configure le garde pour poursuivre et attaquer Luffy
		local ent = obj:get_luaentity()
		if ent then
			ent.order         = "follow"
			ent.attack_players = true
			ent.owner         = name  -- suit le appelant d'abord

			-- force la poursuite de Luffy via un globalstep dédié
			local guard_ref = obj
			local check_timer = 0
			local step_id = {}  -- table pour pouvoir annuler

			local function rescue_step(dtime)
				check_timer = check_timer + dtime
				if check_timer < 0.2 then return end
				check_timer = 0

				-- garde supprimé ?
				if not guard_ref or not guard_ref:get_pos() then
					core.unregister_globalstep(step_id[1])
					rescue_guard_obj = nil
					return
				end

				local lp = core.get_player_by_name(SUSPECT)
				local gpos = guard_ref:get_pos()

				-- Luffy déconnecté ou trop loin : le garde disparaît
				if not lp or not lp:get_pos() or
				   vector.distance(gpos, lp:get_pos()) > RESCUE_DIST then
					core.chat_send_all(core.colorize(GUARD_COLOR, "<Garde Royale>") .. " Suspect hors de portée. Je rentre.")
					guard_ref:remove()
					rescue_guard_obj = nil
					core.unregister_globalstep(step_id[1])
					return
				end

				-- oriente et force le mouvement vers Luffy
				local lpos = lp:get_pos()
				local dir  = vector.normalize(vector.subtract(lpos, gpos))
				guard_ref:set_yaw(math.atan2(-dir.x, dir.z))

				local ge = guard_ref:get_luaentity()
				if ge then
					ge.object:set_velocity({
						x = dir.x * 5,
						y = 0,
						z = dir.z * 5,
					})
					-- dégâts au contact + fly retiré + knockback (même logique que la balle)
					if vector.distance(gpos, lpos) < 1.5 then
						local privs = core.get_player_privs(SUSPECT)
						local had_fly = privs.fly
						if had_fly then
							privs.fly = nil
							core.set_player_privs(SUSPECT, privs)
							core.after(30, function()
								local p = core.get_player_by_name(SUSPECT)
								if p then
									local p_privs = core.get_player_privs(SUSPECT)
									p_privs.fly = true
									core.set_player_privs(SUSPECT, p_privs)
								end
							end)
						end
						local hp = lp:get_hp()
						lp:set_hp(math.max(0, hp - 4))
						lp:add_velocity({x = dir.x * 20, y = 15, z = dir.z * 20})
					end
				end
			end

			step_id[1] = rescue_step
			core.register_globalstep(rescue_step)
		end

		return true, ""
	end,
})