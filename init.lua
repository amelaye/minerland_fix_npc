-- minerland_fix_npc
-- Enrichit le rightclick des entités mobs_npc avec choix de skin et ordre
-- Sans modifier mobs_npc, sans dépendance externe

mobs.custom_spawn_npc = true

local S = core.get_translator("minerland_fix_npc")
local mcl = core.get_modpath("mcl_core") ~= nil
local stick = mcl and "mcl_core:stick" or "default:stick"

-- Skins disponibles par type d'entité
local SKINS = {
	["mobs_npc:npc"] = {
		"mobs_npc.png",
		"mobs_npc2.png",
		"mobs_npc3.png",
		"mobs_npc4.png",
		"mobs_npc5.png",
		"mobs_npc6.png",
	},
	["mobs_npc:igor"] = {
		"mobs_igor.png",
		"mobs_igor2.png",
		"mobs_igor3.png",
		"mobs_igor4.png",
		"mobs_igor5.png",
		"mobs_igor6.png",
		"mobs_igor7.png",
		"mobs_igor8.png",
	},
	["mobs_npc:trader"] = {
		"mobs_trader.png",
		"mobs_trader2.png",
		"mobs_trader3.png",
		"mobs_trader4.png",
	},
	["minerland_fix_npc:guard"] = {
		"minerland_guard1.png",
		"minerland_guard2.png",
		"minerland_guard3.png",
		"minerland_guard4.png",
		"minerland_guard5.png",
	},
}

-- contexte par joueur
local context = {}

core.register_on_leaveplayer(function(player)
	context[player:get_player_name()] = nil
end)

-- génère un id unique pour l'entité si absent
local function ensure_id(self)
	if not self.id then
		self.id = tostring(math.random(1, 1000000)) .. self.name .. tostring(math.random(1, 1000000))
	end
	return self.id
end

-- retrouve l'entité depuis le contexte
local function get_entity_from_context(pname)
	local ctx = context[pname]
	if not ctx then return nil end
	for _, obj in pairs(core.luaentities) do
		if obj.object and obj.id and obj.id == ctx.npc_id then
			return obj
		end
	end
	return nil
end

-- retrouve l'index du skin actuel
local function get_skin_index(self)
	local skins = SKINS[self.name]
	if not skins then return 1 end
	local current = self.base_texture and self.base_texture[1] or skins[1]
	for i, s in ipairs(skins) do
		if s == current then return i end
	end
	return 1
end

-- construit la liste des labels pour le dropdown
local function get_skin_labels(entity_name)
	local skins = SKINS[entity_name]
	if not skins then return "" end
	local labels = {}
	for i = 1, #skins do
		labels[i] = "skin" .. i
	end
	return table.concat(labels, ",")
end

-- construit la formspec
local function get_formspec(self)
	local skin_idx = get_skin_index(self)
	local skin_labels = get_skin_labels(self.name)

	local order = self.order or "wander"
	local order_idx = 1
	local order_array = {"wander", "stand", "follow"}
	for i, v in ipairs(order_array) do
		if v == order then order_idx = i break end
	end

	return table.concat({
		"formspec_version[4]",
		"size[5.5,4.2]",
		"label[0.375,0.4;", S("NPC Settings"), "]",

		-- skin
		"label[0.375,1.0;", S("Skin:"), "]",
		"dropdown[0.375,1.3;4.75,0.7;skin;", skin_labels, ";", skin_idx, "]",

		-- ordre
		"label[0.375,2.2;", S("Order:"), "]",
		"dropdown[0.375,2.5;4.75,0.7;ordermode;wander,stand,follow;", order_idx, "]",

		-- boutons
		"button[0.375,3.4;2.2,0.6;apply;", S("Apply"), "]",
		"button[2.875,3.4;2.2,0.6;exit;", S("Close"), "]",
	}, "")
end

-- applique le skin à l'entité
local function apply_skin(self, skin_idx)
	local skins = SKINS[self.name]
	if not skins then return end
	local texture = skins[skin_idx] or skins[1]
	self.base_texture = {texture}
	self.object:set_properties({textures = {texture}})
end

-- applique l'ordre à l'entité
local function apply_order(self, order)
	self.order = order
	if order == "stand" then
		self.state = "stand"
		self.attack = nil
		self:set_animation("stand")
		self:set_velocity(0)
	end
end

-- réception des champs de la formspec
core.register_on_player_receive_fields(function(player, formname, fields)

	if formname ~= "minerland_fix_npc:settings" then return end

	local pname = player:get_player_name()
	local self = get_entity_from_context(pname)

	if not self then return end

	if fields["exit"] or fields["quit"] then
		core.close_formspec(pname, "minerland_fix_npc:settings")
		context[pname] = nil
		return
	end

	if fields["apply"] then

		if fields["skin"] then
			local skins = SKINS[self.name]
			if skins then
				local idx = tonumber(fields["skin"]:match("^skin(%d+)$"))
				if idx and skins[idx] then
					apply_skin(self, idx)
				end
			end
		end

		if fields["ordermode"] then
			apply_order(self, fields["ordermode"])
		end

		core.show_formspec(pname, "minerland_fix_npc:settings", get_formspec(self))
		return
	end
end)

-- wrapping du on_rightclick pour les 3 entités
local function wrap_rightclick(entity_name)
	local def = core.registered_entities[entity_name]
	if not def then
		core.log("warning", "minerland_fix_npc: " .. entity_name .. " introuvable")
		return
	end
	local original_rightclick = def.on_rightclick
	def.on_rightclick = function(self, clicker)
		local item = clicker:get_wielded_item()
		local pname = clicker:get_player_name()
		if item:get_name() == stick
		and (self.owner == pname or
			core.check_player_privs(clicker, {protection_bypass = true})) then

			ensure_id(self)

			context[pname] = {
				npc_id = self.id,
				entity_name = entity_name,
			}
			core.show_formspec(pname, "minerland_fix_npc:settings", get_formspec(self))
			return
		end
		if original_rightclick then
			return original_rightclick(self, clicker)
		end
	end
end

local QUEEN = "amelaye"

local function wrap_rightclick_guard(entity_name)
	local def = core.registered_entities[entity_name]
	if not def then
		core.log("warning", "minerland_fix_npc: " .. entity_name .. " introuvable")
		return
	end
	local original_rightclick = def.on_rightclick
	def.on_rightclick = function(self, clicker)
		local item = clicker:get_wielded_item()
		local pname = clicker:get_player_name()
		if item:get_name() == stick and pname == QUEEN then
			ensure_id(self)
			context[pname] = {
				npc_id = self.id,
				entity_name = entity_name,
			}
			core.show_formspec(pname, "minerland_fix_npc:settings", get_formspec(self))
			return
		end
		if original_rightclick then
			return original_rightclick(self, clicker)
		end
	end
end

core.register_on_mods_loaded(function()
	wrap_rightclick("mobs_npc:npc")
	wrap_rightclick("mobs_npc:igor")
	wrap_rightclick("mobs_npc:trader")
	wrap_rightclick_guard("minerland_fix_npc:guard")
end)

-- garde
dofile(core.get_modpath("minerland_fix_npc") .. "/guard.lua")