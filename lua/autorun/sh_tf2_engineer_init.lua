--[[
	=========================================================================
	TEAM FORTRESS 2 - ENGINEER BUILDINGS & PDA SYSTEM
	=========================================================================
	Полноценный аддон инженера TF2:
	- КПК Строительства (Build PDA) и меню постройки (Турель, Раздатчик, Телепорты)
	- Самонаводящаяся турель (Sentry Gun)
	- Раздатчик (Dispenser) с лечебным лучом, броней и патронами
	- Входной и выходной телепорты (Teleporters)
	- Гаечный ключ (Wrench) для починки и ускорения постройки
	=========================================================================
]]

TF2_ENG = TF2_ENG or {}

TF2_ENG.BUILDING_SENTRY = 1
TF2_ENG.BUILDING_DISPENSER = 2
TF2_ENG.BUILDING_TELE_ENTER = 3
TF2_ENG.BUILDING_TELE_EXIT = 4

TF2_ENG.TEAM_RED = 0
TF2_ENG.TEAM_BLU = 1

-- Конфигурация построек
TF2_ENG.Buildings = {
	[TF2_ENG.BUILDING_SENTRY] = {
		id = TF2_ENG.BUILDING_SENTRY,
		name = "Турель (Sentry Gun)",
		cost = 130,
		health = 150,
		class = "ent_tf2_sentry",
		model = "models/buildables/sentry1.mdl",
		fallbackModel = "models/combine_turrets/floor_turret.mdl",
		desc = "Автоматическая турель с самонаведением на 360 градусов.",
		icon = "models/buildables/sentry1.mdl",
	},
	[TF2_ENG.BUILDING_DISPENSER] = {
		id = TF2_ENG.BUILDING_DISPENSER,
		name = "Раздатчик (Dispenser)",
		cost = 100,
		health = 150,
		class = "ent_tf2_dispenser",
		model = "models/buildables/dispenser.mdl",
		fallbackModel = "models/props_combine/suit_charger001.mdl",
		desc = "Лечит союзников, пополняет броню, боеприпасы и металл.",
		icon = "models/buildables/dispenser.mdl",
	},
	[TF2_ENG.BUILDING_TELE_ENTER] = {
		id = TF2_ENG.BUILDING_TELE_ENTER,
		name = "Телепорт: Вход (Entrance)",
		cost = 50,
		health = 150,
		class = "ent_tf2_teleport_enter",
		model = "models/buildables/teleporter.mdl",
		fallbackModel = "models/props_c17/utilityconnecter006c.mdl",
		desc = "Входная площадка телепорта. Телепортирует к выходу.",
		icon = "models/buildables/teleporter.mdl",
	},
	[TF2_ENG.BUILDING_TELE_EXIT] = {
		id = TF2_ENG.BUILDING_TELE_EXIT,
		name = "Телепорт: Выход (Exit)",
		cost = 50,
		health = 150,
		class = "ent_tf2_teleport_exit",
		model = "models/buildables/teleporter.mdl",
		fallbackModel = "models/props_c17/utilityconnecter006c.mdl",
		desc = "Выходная площадка для прибытия телепортированных игроков.",
		icon = "models/buildables/teleporter.mdl",
	},
}

-- Цветовая палитра TF2
TF2_ENG.Colors = {
	tf2_red = Color(184, 56, 59),
	tf2_blu = Color(91, 122, 140),
	tf2_dark = Color(43, 39, 37),
	tf2_hud_bg = Color(40, 36, 34, 240),
	tf2_hud_border = Color(100, 90, 80, 255),
	tf2_hud_header = Color(184, 56, 59),
	tf2_text_yellow = Color(235, 226, 202),
	tf2_text_gold = Color(245, 195, 65),
	tf2_disabled = Color(120, 110, 100, 200),
	tf2_green = Color(90, 210, 120),
	tf2_blueprint_valid = Color(0, 255, 120, 160),
	tf2_blueprint_invalid = Color(255, 50, 50, 180),
}

-- Получение модели постройки
function TF2_ENG.GetBuildingModel(bType)
	local bDef = TF2_ENG.Buildings[bType]
	if not bDef then return "models/error.mdl" end
	return bDef.model
end

-- Металл инженера
local meta = FindMetaTable("Player")

function meta:TF2_GetMetal()
	return self:GetNWInt("TF2_Metal", 200)
end

function meta:TF2_SetMetal(amount)
	self:SetNWInt("TF2_Metal", math.Clamp(amount, 0, 200))
end

function meta:TF2_AddMetal(amount)
	self:TF2_SetMetal(self:TF2_GetMetal() + amount)
end

function meta:TF2_HasBuilding(bType)
	local ent = self:GetNWEntity("TF2_Building_" .. bType)
	return IsValid(ent)
end

function meta:TF2_GetBuilding(bType)
	return self:GetNWEntity("TF2_Building_" .. bType)
end

function meta:TF2_GetTeamSkin()
	return self:GetNWInt("TF2_TeamSkin", TF2_ENG.TEAM_RED)
end

-- Гарантия твердой физической коллизии между игроками и постройками
hook.Add("ShouldCollide", "TF2_ENG.BuildingSolidCollision", function(ent1, ent2)
	if not IsValid(ent1) or not IsValid(ent2) then return end
	if (ent1.BuildingType and ent2:IsPlayer()) or (ent2.BuildingType and ent1:IsPlayer()) then
		return true
	end
end)

-- Блокировка стрельбы и действий оружия в руках игрока во время управления турелью
hook.Add("StartCommand", "TF2_ENG.SuppressWeaponInSentry", function(ply, cmd)
	if not IsValid(ply) then return end
	local sentry = ply:GetNWEntity("TF2_ControlledSentry")
	if IsValid(sentry) then
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) then
			wep:SetNextPrimaryFire(CurTime() + 0.5)
			wep:SetNextSecondaryFire(CurTime() + 0.5)
		end
	end
end)

-- =========================================================================
-- ПРОВЕРКА ТОЧЕК СПАВНА И БЕЗОПАСНЫХ ЗОН (ЗАЩИТА ОТ СПАВН-КИЛЛА)
-- =========================================================================
TF2_ENG.SpawnPoints = TF2_ENG.SpawnPoints or {}

local spawnClasses = {
	["info_player_start"] = true,
	["info_player_deathmatch"] = true,
	["info_player_teamspawn"] = true,
	["info_player_combine"] = true,
	["info_player_rebel"] = true,
	["info_player_counterterrorist"] = true,
	["info_player_terrorist"] = true,
	["info_player_allies"] = true,
	["info_player_axis"] = true,
	["gmod_player_start"] = true,
	["insurgency_spawnpoint"] = true,
	["doi_spawnpoint"] = true,
}

if SERVER then
	util.AddNetworkString("TF2_SyncSpawnPoints")

	function TF2_ENG.CollectSpawnPoints()
		TF2_ENG.SpawnPoints = {}
		for class, _ in pairs(spawnClasses) do
			for _, ent in ipairs(ents.FindByClass(class)) do
				if IsValid(ent) then
					table.insert(TF2_ENG.SpawnPoints, ent:GetPos())
				end
			end
		end
	end

	hook.Add("InitPostEntity", "TF2_ENG.CollectSpawns", function()
		TF2_ENG.CollectSpawnPoints()
	end)

	hook.Add("PlayerInitialSpawn", "TF2_ENG.SyncSpawnsOnJoin", function(ply)
		timer.Simple(1.5, function()
			if IsValid(ply) then
				net.Start("TF2_SyncSpawnPoints")
				net.WriteUInt(#TF2_ENG.SpawnPoints, 16)
				for _, pos in ipairs(TF2_ENG.SpawnPoints) do
					net.WriteVector(pos)
				end
				net.Send(ply)
			end
		end)
	end)
else
	net.Receive("TF2_SyncSpawnPoints", function()
		local count = net.ReadUInt(16)
		TF2_ENG.SpawnPoints = {}
		for i = 1, count do
			table.insert(TF2_ENG.SpawnPoints, net.ReadVector())
		end
	end)
end

function TF2_ENG.IsSpawnOrSafeZone(pos)
	if not pos then return false end

	-- 1. Проверка нахождения внутри Safezone (SH Safezones)
	if SH_SZ and SH_SZ.IsWithinSafeZone and SH_SZ:IsWithinSafeZone(pos) ~= nil then
		return true, "в безопасной зоне (Safe Zone)"
	end

	-- 2. Проверка близости к точкам спавна игроков на карте (радиус 380 юнитов)
	local checkRadiusSqr = 380 * 380
	for _, spPos in ipairs(TF2_ENG.SpawnPoints or {}) do
		if spPos:DistToSqr(pos) <= checkRadiusSqr then
			return true, "на точке спавна игроков"
		end
	end

	if SERVER then
		for class, _ in pairs(spawnClasses) do
			for _, ent in ipairs(ents.FindByClass(class)) do
				if IsValid(ent) and ent:GetPos():DistToSqr(pos) <= checkRadiusSqr then
					return true, "на точке спавна игроков"
				end
			end
		end
	end

	return false
end
