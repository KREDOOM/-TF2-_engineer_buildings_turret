TF2_ENG = TF2_ENG or {}

util.AddNetworkString("TF2_OpenBuildMenu")
util.AddNetworkString("TF2_OpenDestroyMenu")
util.AddNetworkString("TF2_StartPlacement")
util.AddNetworkString("TF2_PlaceBuilding")
util.AddNetworkString("TF2_DestroyBuilding")
util.AddNetworkString("TF2_SyncMetal")
util.AddNetworkString("TF2_SwitchTeamSkin")
util.AddNetworkString("TF2_BuildingSound")

-- Автоматическая регистрация всех ресурсов для полной автономности (не требует наличия TF2)
local function AddFolderResources(dir)
	local files, dirs = file.Find(dir .. "/*", "GAME")
	for _, f in ipairs(files or {}) do
		resource.AddFile(dir .. "/" .. f)
	end
	for _, d in ipairs(dirs or {}) do
		AddFolderResources(dir .. "/" .. d)
	end
end

AddFolderResources("models/buildables")
AddFolderResources("models/weapons/v_models")
AddFolderResources("models/weapons/w_models")
AddFolderResources("materials/models/buildables")
AddFolderResources("materials/effects/tiledfire")
AddFolderResources("materials/vgui/entities")
AddFolderResources("materials/cubemaps")
AddFolderResources("materials/cubemaps")
AddFolderResources("materials/models/weapons")
AddFolderResources("sound/weapons")

-- Начальный металл при спавне
hook.Add("PlayerSpawn", "TF2_ENG.PlayerSpawn", function(ply)
	if not IsValid(ply) then return end
	if ply:TF2_GetMetal() <= 0 then
		ply:TF2_SetMetal(200)
	end
end)

-- Постепенное восстановление металла (если нет раздатчика поблизости)
timer.Create("TF2_ENG.MetalRegen", 5.0, 0, function()
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and ply:Alive() then
			local curMetal = ply:TF2_GetMetal()
			if curMetal < 200 then
				ply:TF2_SetMetal(math.min(200, curMetal + 10))
			end
		end
	end
end)

-- Обработка запроса на постройку объекта
net.Receive("TF2_PlaceBuilding", function(len, ply)
	if not IsValid(ply) or not ply:Alive() then return end

	local bType = net.ReadUInt(4)
	local pos = net.ReadVector()
	local ang = net.ReadAngle()

	local bDef = TF2_ENG.Buildings[bType]
	if not bDef then return end

	-- Проверка дистанции (до 1600 юнитов вдаль)
	if ply:GetPos():Distance(pos) > 1650 then
		ply:ChatPrint("[TF2 Engineer] Слишком далеко для постройки!")
		return
	end

	-- Проверка на запрет постройки на спавне и в безопасных зонах
	local isSpawnOrSafe, reason = TF2_ENG.IsSpawnOrSafeZone(pos)
	if isSpawnOrSafe then
		ply:ChatPrint("[TF2 Engineer] Запрещено ставить постройки " .. (reason or "на спавне") .. "!")
		ply:EmitSound("player/suit_denydevice.wav", 75, 100)
		return
	end

	-- Проверка наличия металла
	local curMetal = ply:TF2_GetMetal()
	if curMetal < bDef.cost then
		ply:ChatPrint("[TF2 Engineer] Недостаточно металла! Нужно " .. bDef.cost .. " (у вас " .. curMetal .. ").")
		ply:EmitSound("player/suit_denydevice.wav", 75, 100)
		return
	end

	-- Удаляем предыдущую постройку этого типа, если была
	local oldBuilding = ply:TF2_GetBuilding(bType)
	if IsValid(oldBuilding) then
		oldBuilding:TakeDamage(9999, ply, ply)
	end

	-- Списание металла
	ply:TF2_SetMetal(curMetal - bDef.cost)

	-- Создание постройки
	local ent = ents.Create(bDef.class)
	if not IsValid(ent) then return end

	ent:SetPos(pos)
	ent:SetAngles(ang)
	ent.BuildingType = bType
	ent.BuildingOwner = ply
	ent.IsTF2Building = true
	ent:SetCreator(ply)
	ent:SetNWEntity("BuildingOwner", ply)
	ent.BuildingTeam = ply:TF2_GetTeamSkin()

	ent:Spawn()
	ent:Activate()

	if ent.SetBuildingSkin then
		ent:SetBuildingSkin(ply:TF2_GetTeamSkin())
	end

	ply:SetNWEntity("TF2_Building_" .. bType, ent)

	ply:ChatPrint("[TF2 Engineer] " .. bDef.name .. " успешно построена! Осталось металла: " .. ply:TF2_GetMetal())
	ply:EmitSound("weapons/sentry_finish.wav", 75, 100)

	-- Эффект завершения постройки
	local ef = EffectData()
	ef:SetOrigin(pos + Vector(0, 0, 20))
	ef:SetScale(1)
	util.Effect("cball_explode", ef)
end)

-- Защита построек инженера от перекраски в невидимый цвет, скрытия текстур и изменения прозрачности
local blockedTools = {
	["colour"] = true,
	["color"] = true,
	["material"] = true,
	["submaterial"] = true,
	["renderflags"] = true,
	["invisible"] = true,
	["stealth"] = true,
	["alpha"] = true,
}

hook.Add("CanTool", "TF2_ENG.ProtectBuildingVisibilityTool", function(ply, tr, toolname)
	if IsValid(tr.Entity) then
		local ent = tr.Entity
		if ent.BuildingType or ent.IsTF2Building or string.find(ent:GetClass(), "ent_tf2_") then
			local tName = string.lower(toolname or "")
			if blockedTools[tName] then
				ply:ChatPrint("[TF2 Engineer] Запрещено изменять цвет, материал и видимость построек инженера!")
				return false
			end
		end
	end
end)

hook.Add("CanProperty", "TF2_ENG.ProtectBuildingVisibilityProperty", function(ply, property, ent)
	if IsValid(ent) then
		if ent.BuildingType or ent.IsTF2Building or string.find(ent:GetClass(), "ent_tf2_") then
			local propName = string.lower(property or "")
			if propName == "color" or propName == "material" or propName == "skin" or propName == "bodygroups" then
				return false
			end
		end
	end
end)

-- Обработка сноса постройки через КПК
net.Receive("TF2_DestroyBuilding", function(len, ply)
	if not IsValid(ply) or not ply:Alive() then return end

	local bType = net.ReadUInt(4)
	local building = ply:TF2_GetBuilding(bType)

	if IsValid(building) then
		ply:ChatPrint("[TF2 Engineer] Вы снесли постройку: " .. (TF2_ENG.Buildings[bType] and TF2_ENG.Buildings[bType].name or "Постройка"))
		building:TakeDamage(9999, ply, ply)
		ply:SetNWEntity("TF2_Building_" .. bType, NULL)
		ply:EmitSound("weapons/sentry_explode.wav", 75, 100)
	else
		ply:ChatPrint("[TF2 Engineer] У вас нет этой постройки для сноса.")
	end
end)

-- Переключение команды (RED / BLU)
net.Receive("TF2_SwitchTeamSkin", function(len, ply)
	if not IsValid(ply) then return end

	local newSkin = net.ReadUInt(2)
	ply:SetNWInt("TF2_TeamSkin", newSkin)

	local skinName = (newSkin == TF2_ENG.TEAM_BLU) and "BLU (Синяя)" or "RED (Красная)"
	ply:ChatPrint("[TF2 Engineer] Команда чертежей переключена на: " .. skinName)

	-- Обновляем скины на существующих постройках
	for i = 1, 4 do
		local bEnt = ply:TF2_GetBuilding(i)
		if IsValid(bEnt) and bEnt.SetBuildingSkin then
			bEnt:SetBuildingSkin(newSkin)
		end
	end
end)

-- Команды в чате
hook.Add("PlayerSay", "TF2_ENG.ChatCommands", function(ply, text)
	local txt = string.lower(string.Trim(text))
	if txt == "!build" or txt == "/build" then
		net.Start("TF2_OpenBuildMenu")
		net.Send(ply)
		return ""
	elseif txt == "!destroy" or txt == "/destroy" then
		net.Start("TF2_OpenDestroyMenu")
		net.Send(ply)
		return ""
	elseif txt == "!tf2metal" or txt == "/tf2metal" then
		ply:TF2_SetMetal(200)
		ply:ChatPrint("[TF2 Engineer] Запас металла пополнен до максимума (200)!")
		return ""
	end
end)
