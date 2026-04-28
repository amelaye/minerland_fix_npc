-- minerland_fix_npc/guard.lua
-- Garde immortel qui salue la reine et menace les autres joueurs

local S = core.get_translator("minerland_fix_npc")
local mcl = core.get_modpath("mcl_core") ~= nil

local QUEEN      = core.settings:get("minerland_guard_queen")      or "amelaye"
local GREET_DIST = tonumber(core.settings:get("minerland_guard_greet_dist")) or 3
local THREAT_DIST= tonumber(core.settings:get("minerland_guard_threat_dist")) or 3

-- état par garde (weak table)
local guard_states = setmetatable({}, {__mode = "k"})

local function get_state(obj)
	if not guard_states[obj] then
		guard_states[obj] = {
			greeted    = {},
			threatened = {},
			bowing     = false,
			lead_warned= {},
			gun_warned = {},
		}
	end
	return guard_states[obj]
end

-- lève les deux bras
local function bow(obj)
	obj:set_bone_override("Arm_Right", {
		rotation = {vec = vector.new(math.pi * 0.8, 0, 0), absolute = true}
	})
	obj:set_bone_override("Arm_Left", {
		rotation = {vec = vector.new(math.pi * 0.8, 0, 0), absolute = true}
	})
end

-- remet les bras en place
local function unbow(obj)
	obj:set_bone_override("Arm_Right", {})
	obj:set_bone_override("Arm_Left",  {})
end

-- éjecte un joueur depuis la position du garde
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

-- entité visuelle du taurus attachée au bras
core.register_entity("minerland_fix_npc:taurus_visual", {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = false,
		visual = "wielditem",
		textures = {"rangedweapons:taurus"},
		visual_size = {x = 0.13, y = 0.13},
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

local function attach_taurus(guard_obj)
	local ent = core.add_entity(guard_obj:get_pos(), "minerland_fix_npc:taurus_visual")
	if not ent then return nil end
	ent:set_attach(guard_obj, "Arm_Right",
		{x = 0, y = 6, z = 1},
		{x = 0, y = 270, z = 0}
	)
	return ent
end

local function detach_taurus(taurus_ent)
	if taurus_ent and taurus_ent:get_pos() then
		taurus_ent:remove()
	end
end

-- projectile maison tiré par le garde
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
	_damage = 14,
	_timer = 0,
	on_activate = function(self, staticdata)
		local data = core.deserialize(staticdata) or {}
		if data.remove then self.object:remove() end
		self._timer = 0
	end,
	get_staticdata = function(self)
		return core.serialize({remove = true})
	end,
	on_step = function(self, dtime)
		self._timer = (self._timer or 0) + dtime
		if self._timer > 3 then
			self.object:remove()
			return
		end
		local pos = self.object:get_pos()
		if not pos then return end
		-- détecte collision avec joueur
		local objs = core.get_objects_inside_radius(pos, 0.8)
		for _, obj in ipairs(objs) do
			if obj:is_player() then
				local hp = obj:get_hp()
				obj:set_hp(math.max(0, hp - self._damage))
				local vel = self.object:get_velocity()
				if vel then
					local dir = vector.normalize(vel)
					obj:add_velocity({x=dir.x*5, y=3, z=dir.z*5})
				end
				core.sound_play("rangedweapons_deagle", {pos=pos, gain=0.5}, true)
				self.object:remove()
				return
			end
		end
		-- détecte collision avec noeud
		local node = core.get_node(pos)
		local def = core.registered_nodes[node.name]
		if def and def.walkable then
			self.object:remove()
		end
	end,
})

local function fire_bullet(guard_obj, target_player)
	local gpos = guard_obj:get_pos()
	if not gpos then return end
	local ppos = target_player:get_pos()
	if not ppos then return end

	gpos.y = gpos.y + 0.8
	local dir = vector.normalize(vector.subtract(ppos, gpos))

	local bullet = core.add_entity(gpos, "minerland_fix_npc:guard_bullet")
	if bullet then
		bullet:set_velocity(vector.multiply(dir, 50))
		bullet:set_acceleration({x=0, y=-2, z=0})
	end
	core.sound_play("rangedweapons_deagle", {pos=gpos, gain=1.0, max_hear_distance=50}, true)
end

local function raise_arm(obj)
	obj:set_bone_override("Arm_Right", {
		rotation = {vec = {x = 1.5708, y = 0, z = 0}, interpolation = 0.15}
	})
end

local function lower_arm(obj)
	obj:set_bone_override("Arm_Right", {})
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
		-- annule knockback en permanence sauf en follow
		if self.order ~= "follow" then
			self.object:set_velocity({x = 0, y = 0, z = 0})
		end
	end,

	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		self.object:set_velocity({x = 0, y = 0, z = 0})
		if puncher and puncher:is_player() then
			local state = get_state(self.object)
			if not state.taurus_ent then
				state.taurus_ent = attach_taurus(self.object)
			end
			raise_arm(self.object)

			-- rafale de 6 coups
			local gobj = self.object
			for i = 1, 6 do
				core.after(i * 0.3, function()
					if not gobj or not gobj:get_pos() then return end
					if not puncher or not puncher:get_pos() then return end
					fire_bullet(gobj, puncher)
				end)
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

-- globalstep
local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 0.1 then return end
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

		-- reset si aucun joueur proche
		local any_threatened = false
		local any_gun = false
		for _, player in ipairs(players) do
			local ppos = player:get_pos()
			if ppos then
				local dist = vector.distance(pos, ppos)
				local wielded = player:get_wielded_item():get_name()
				if dist <= THREAT_DIST then any_threatened = true end
				if dist <= 10 and (wielded == "rangedweapons:taurus" or wielded == "rangedweapons:python") then
					any_gun = true
				end
			end
		end
		if not any_threatened and not any_gun then
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

			-- détection revolver
			if dist <= 10 and (wielded == "rangedweapons:taurus" or wielded == "rangedweapons:python") then
				if not state.gun_warned[pname] then
					state.gun_warned[pname] = true
					if not state.taurus_ent then
						state.taurus_ent = attach_taurus(obj.object)
					end
					raise_arm(obj.object)
					core.chat_send_all("<" .. (obj.nametag or S("Guard")) .. "> HALTE !! Un terroriste !!!")
					core.after(5, function()
						if state.gun_warned then
							state.gun_warned[pname] = nil
						end
					end)
				end
			else
				if state.gun_warned[pname] then
					state.gun_warned[pname] = nil
				end
			end

			-- éjection laisse
			if wielded == "leads:lead" and dist <= 3 then
				if not state.lead_warned[pname] then
					state.lead_warned[pname] = true
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
						"<" .. (obj.nametag or S("Guard")) .. "> " ..
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
				-- salutation
				if dist <= GREET_DIST and not state.greeted[pname] and not state.bowing then
					state.greeted[pname] = true
					state.bowing = true
					bow(obj.object)
					core.chat_send_player(pname,
						"<" .. (obj.nametag or S("Guard")) .. "> " ..
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
				-- menace
				if dist <= THREAT_DIST and not state.threatened[pname] then
					state.threatened[pname] = true
					if not state.taurus_ent then
						state.taurus_ent = attach_taurus(obj.object)
					end
					raise_arm(obj.object)
					core.chat_send_player(pname,
						"<" .. (obj.nametag or S("Guard")) .. "> " ..
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

-- spawn egg
mobs:register_egg("minerland_fix_npc:guard", S("Guard"),
	mcl and "mcl_core:iron_block.png" or "default_steel_block.png", 1)

-- réserve l'oeuf aux admins
core.register_on_mods_loaded(function()
	if not core.registered_items["minerland_fix_npc:guard"] then return end

	core.override_item("minerland_fix_npc:guard", {
		on_place = function(itemstack, placer, pointed_thing)
			if not placer or not placer:is_player() then return end
			local pname = placer:get_player_name()
			if not core.check_player_privs(placer, {server = true}) then
				core.chat_send_player(pname,
					S("Vous n'avez pas la permission d'invoquer un garde."))
				local privs = core.get_player_privs(pname)
				local had_fly = privs.fly
				if had_fly then
					privs.fly = false
					core.set_player_privs(pname, privs)
				end
				local dir = placer:get_look_dir()
				dir.y = 0
				placer:add_velocity({
					x = vector.multiply(vector.normalize(dir), -15).x,
					y = 12,
					z = vector.multiply(vector.normalize(dir), -15).z,
				})
				core.after(3, function()
					if had_fly then
						privs.fly = true
						core.set_player_privs(pname, privs)
					end
				end)
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
		end
	})

	-- bloque leads
	if leads and leads.custom_leashable_entities then
		leads.custom_leashable_entities["minerland_fix_npc:guard"] = false
	end
end)