TF2_ENG = TF2_ENG or {}

local colors = TF2_ENG.Colors

-- Скрытие оружия в руках во время ручного управления турелью
hook.Add("PreDrawViewModel", "TF2_ENG.HideWeaponInSentry", function(vm, ply, wep)
	local sentry = IsValid(ply) and ply:GetNWEntity("TF2_ControlledSentry")
	if IsValid(sentry) and sentry.GetClass and sentry:GetClass() == "ent_tf2_sentry" and sentry:GetNWEntity("TF2_Controller") == ply then
		return true
	end
end)

hook.Add("HUDPaint", "TF2_ENG.DrawBuildingStatusHUD", function()
	local lp = LocalPlayer()
	if not IsValid(lp) or not lp:Alive() then return end

	local scrW, scrH = ScrW(), ScrH()
	local controlledSentry = lp:GetNWEntity("TF2_ControlledSentry")

	-- 1. ИНТЕРФЕЙС И ПРИЦЕЛ РУЧНОГО УПРАВЛЕНИЯ ТУРЕЛЬЮ (3 УРОВЕНЬ)
	if IsValid(controlledSentry) then
		local cx, cy = scrW * 0.5, scrH * 0.5

		-- Круговой аутентичный прицел TF2 Wrangler
		surface.DrawCircle(cx, cy, 14, 245, 195, 65, 220)
		surface.DrawCircle(cx, cy, 15, 245, 195, 65, 220)

		-- Центральная точка
		surface.SetDrawColor(255, 50, 50, 255)
		surface.DrawRect(cx - 2, cy - 2, 5, 5)

		-- Внешние риски прицела
		surface.SetDrawColor(245, 195, 65, 240)
		surface.DrawRect(cx - 24, cy - 1, 8, 3)
		surface.DrawRect(cx + 17, cy - 1, 8, 3)
		surface.DrawRect(cx - 1, cy - 24, 3, 8)
		surface.DrawRect(cx - 1, cy + 17, 3, 8)

		-- Нижняя плашка подсказок управления
		local boxW, boxH = 460, 50
		local bx = (scrW - boxW) * 0.5
		local by = scrH - 120

		draw.RoundedBox(8, bx, by, boxW, boxH, Color(20, 18, 16, 235))
		surface.SetDrawColor(245, 195, 65, 220)
		surface.DrawOutlinedRect(bx, by, boxW, boxH, 2)

		draw.SimpleText("РУЧНОЕ УПРАВЛЕНИЕ ТУРЕЛЬЮ LVL 3", "TF2_PDA_Medium", cx, by + 15, colors.tf2_text_gold, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("[ЛКМ] Пулеметы   |   [ПКМ] Залп ракет   |   [E] Выход", "TF2_PDA_Small", cx, by + 34, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	-- 2. ИНДИКАТОР ЗАПАСА МЕТАЛЛА ИНЖЕНЕРА (ТОЛЬКО С КЛЮЧОМ ИЛИ КПК В РУКАХ)
	local wep = lp:GetActiveWeapon()
	local holdingEngineerTool = IsValid(wep) and (wep:GetClass() == "weapon_tf2_pda" or wep:GetClass() == "weapon_tf2_wrench")

	if holdingEngineerTool then
		local curMetal = lp:TF2_GetMetal()
		local metalBoxW, metalBoxH = 200, 52
		local metalX = scrW - metalBoxW - 24
		local metalY = scrH - metalBoxH - 24

		draw.RoundedBox(8, metalX, metalY, metalBoxW, metalBoxH, Color(28, 24, 22, 230))
		surface.SetDrawColor(colors.tf2_hud_border)
		surface.DrawOutlinedRect(metalX, metalY, metalBoxW, metalBoxH, 2)

		draw.SimpleText("МЕТАЛЛ", "TF2_PDA_Small", metalX + 16, metalY + 14, colors.tf2_text_yellow, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(curMetal .. " / 200", "TF2_PDA_Medium", metalX + metalBoxW - 16, metalY + 14, colors.tf2_text_gold, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		-- Полоска заполнения металла
		local metalPct = math.Clamp(curMetal / 200, 0, 1)
		draw.RoundedBox(3, metalX + 14, metalY + 28, metalBoxW - 28, 14, Color(14, 12, 10, 240))
		draw.RoundedBox(3, metalX + 14, metalY + 28, math.floor((metalBoxW - 28) * metalPct), 14, colors.tf2_text_gold)
	end

	-- 3. СТАТУС ПОСТРОЕК В ЛЕВОМ ВЕРХНЕМ УГЛУ
	local hasAny = false
	for i = 1, 4 do
		if lp:TF2_HasBuilding(i) then
			hasAny = true
			break
		end
	end

	local wep = lp:GetActiveWeapon()
	local holdingPDA = IsValid(wep) and (wep:GetClass() == "weapon_tf2_pda" or wep:GetClass() == "weapon_tf2_wrench")

	if not hasAny and not holdingPDA then return end

	local panelX, panelY = 20, 20
	local pWidth, pHeight = 240, 56
	local bNames = { "ТУРЕЛЬ", "РАЗДАТЧИК", "ТЕЛЕПОРТ ВХОД", "ТЕЛЕПОРТ ВЫХОД" }

	for bType = 1, 4 do
		local bEnt = lp:TF2_GetBuilding(bType)
		local y = panelY + (bType - 1) * (pHeight + 6)

		local isBuilt = IsValid(bEnt)
		local lvl = isBuilt and bEnt:GetNWInt("TF2_Level", 1) or 1
		local upMetal = isBuilt and bEnt:GetNWInt("TF2_UpgradeMetal", 0) or 0

		draw.RoundedBox(6, panelX, y, pWidth, pHeight, Color(34, 30, 28, 220))
		surface.SetDrawColor(colors.tf2_hud_border)
		surface.DrawOutlinedRect(panelX, y, pWidth, pHeight, 1)

		local teamCol = lp:TF2_GetTeamSkin() == TF2_ENG.TEAM_BLU and colors.tf2_blu or colors.tf2_red
		draw.RoundedBoxEx(6, panelX, y, 40, pHeight, isBuilt and teamCol or Color(45, 40, 38), true, false, true, false)
		draw.SimpleText(tostring(bType), "TF2_PDA_Medium", panelX + 20, y + pHeight * 0.5, isBuilt and colors.tf2_text_yellow or colors.tf2_disabled, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local title = bNames[bType] .. (isBuilt and (" (УР. " .. lvl .. ")") or "")
		draw.SimpleText(title, "TF2_PDA_Small", panelX + 48, y + 14, isBuilt and color_white or colors.tf2_disabled, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if isBuilt then
			local hp = bEnt:Health()
			local maxHp = bEnt:GetMaxHealth()
			local hpPct = math.Clamp(hp / math.max(1, maxHp), 0, 1)

			-- Полоска здоровья
			draw.RoundedBox(2, panelX + 48, y + 24, 180, 10, Color(16, 14, 12, 220))
			draw.RoundedBox(2, panelX + 48, y + 24, math.floor(180 * hpPct), 10, colors.tf2_green)
			draw.SimpleText(hp .. " / " .. maxHp .. " HP", "TF2_PDA_Small", panelX + 138, y + 29, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			-- Полоска прокачки (если уровень < 3)
			if lvl < 3 then
				local upPct = math.Clamp(upMetal / 200, 0, 1)
				draw.RoundedBox(2, panelX + 48, y + 38, 180, 8, Color(16, 14, 12, 220))
				draw.RoundedBox(2, panelX + 48, y + 38, math.floor(180 * upPct), 8, colors.tf2_text_gold)
				draw.SimpleText("Апгрейд: " .. upMetal .. " / 200", "TF2_PDA_Small", panelX + 138, y + 42, colors.tf2_text_yellow, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			else
				draw.SimpleText("МАКС. УРОВЕНЬ", "TF2_PDA_Small", panelX + 48, y + 44, colors.tf2_text_gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
		else
			draw.SimpleText("НЕ ПОСТРОЕНО", "TF2_PDA_Small", panelX + 48, y + 34, colors.tf2_disabled, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	-- 4. 3D2D ТАБЛИЧКИ СОСТОЯНИЯ НА ПОСТРОЙКАХ
	if holdingPDA then
		for bType = 1, 4 do
			local ent = lp:TF2_GetBuilding(bType)
			if IsValid(ent) then
				local hp = ent:Health()
				local maxHp = ent:GetMaxHealth()
				local pct = math.Clamp(hp / math.max(1, maxHp), 0, 1)
				local lvl = ent:GetNWInt("TF2_Level", 1)
				local upMetal = ent:GetNWInt("TF2_UpgradeMetal", 0)

				local bPos = ent:GetPos()
				local tagPos = bPos
				local tagAng = ent:GetAngles()
				local scale = 0.05

				if bType == TF2_ENG.BUILDING_DISPENSER then
					tagPos = bPos + ent:GetForward() * 7.5 + ent:GetUp() * 45
					tagAng:RotateAroundAxis(tagAng:Up(), 90)
					tagAng:RotateAroundAxis(tagAng:Forward(), 90)
					scale = 0.055
				elseif bType == TF2_ENG.BUILDING_SENTRY then
					tagPos = bPos - ent:GetForward() * 14 + ent:GetUp() * 26
					tagAng = ent:GetAngles()
					tagAng:RotateAroundAxis(tagAng:Up(), -90)
					tagAng:RotateAroundAxis(tagAng:Forward(), 70)
					scale = 0.055
				else
					tagPos = bPos + ent:GetUp() * 13 - ent:GetForward() * 12
					tagAng = ent:GetAngles()
					tagAng:RotateAroundAxis(tagAng:Up(), 90)
					tagAng:RotateAroundAxis(tagAng:Forward(), 90)
					scale = 0.05
				end

				cam.Start3D2D(tagPos, tagAng, scale)
					local bDef = TF2_ENG.Buildings[bType]
					local name = (bDef and bDef.name or "Постройка") .. " [Ур. " .. lvl .. "]"

					draw.RoundedBox(4, -80, -30, 160, lvl < 3 and 60 or 44, Color(16, 14, 12, 240))
					surface.SetDrawColor(245, 195, 65, 200)
					surface.DrawOutlinedRect(-80, -30, 160, lvl < 3 and 60 or 44, 1)

					draw.SimpleText(name, "TF2_PDA_Small", 0, -18, colors.tf2_text_gold, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

					-- Здоровье
					draw.RoundedBox(2, -70, -8, 140, 10, Color(8, 8, 8, 240))
					draw.RoundedBox(2, -70, -8, math.floor(140 * pct), 10, colors.tf2_green)
					draw.SimpleText(hp .. " / " .. maxHp .. " HP", "TF2_PDA_Small", 0, -3, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

					-- Прокачка
					if lvl < 3 then
						local upPct = math.Clamp(upMetal / 200, 0, 1)
						draw.RoundedBox(2, -70, 8, 140, 9, Color(8, 8, 8, 240))
						draw.RoundedBox(2, -70, 8, math.floor(140 * upPct), 9, colors.tf2_text_gold)
						draw.SimpleText("Апгрейд: " .. upMetal .. " / 200", "TF2_PDA_Small", 0, 13, colors.tf2_text_yellow, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					end
				cam.End3D2D()
			end
		end
	end
end)
