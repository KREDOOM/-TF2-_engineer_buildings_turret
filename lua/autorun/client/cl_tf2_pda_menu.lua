TF2_ENG = TF2_ENG or {}

local colors = TF2_ENG.Colors

surface.CreateFont("TF2_PDA_Header", {
	font = "Arial Black",
	extended = true,
	size = 22,
	weight = 900,
})

surface.CreateFont("TF2_PDA_Title", {
	font = "Arial Black",
	extended = true,
	size = 15,
	weight = 900,
})

surface.CreateFont("TF2_PDA_Key", {
	font = "Arial Black",
	extended = true,
	size = 24,
	weight = 900,
})

surface.CreateFont("TF2_PDA_Medium", {
	font = "Arial Black",
	extended = true,
	size = 16,
	weight = 800,
})

surface.CreateFont("TF2_PDA_Small", {
	font = "Arial",
	extended = true,
	size = 13,
	weight = 800,
})

surface.CreateFont("TF2_PDA_Status", {
	font = "Arial Black",
	extended = true,
	size = 12,
	weight = 800,
})

surface.CreateFont("TF2_PDA_Large", {
	font = "Arial Black",
	extended = true,
	size = 28,
	weight = 900,
})

local pdaMenuFrame = nil

function TF2_ENG.OpenPDAMenu(isDestroy)
	if IsValid(pdaMenuFrame) then
		pdaMenuFrame:Close()
		pdaMenuFrame = nil
	end

	local lp = LocalPlayer()
	if not IsValid(lp) or not lp:Alive() then return end

	local myTeamSkin = lp:TF2_GetTeamSkin()

	local w, h = 1040, 460
	local f = vgui.Create("DFrame")
	f:SetSize(w, h)
	f:Center()
	f:SetTitle("")
	f:ShowCloseButton(false)
	f:SetDraggable(true)
	f:MakePopup()

	pdaMenuFrame = f

	surface.PlaySound("weapons/draw_pda_engineer.wav")

	f.Paint = function(s, pw, ph)
		-- Основной темный фон в индустриальном стиле TF2
		draw.RoundedBox(10, 0, 0, pw, ph, Color(22, 20, 18, 250))
		surface.SetDrawColor(colors.tf2_hud_border)
		surface.DrawOutlinedRect(0, 0, pw, ph, 2)

		-- Верхняя заголовочная плашка
		local headerCol = isDestroy and colors.tf2_red or (myTeamSkin == TF2_ENG.TEAM_BLU and colors.tf2_blu or colors.tf2_red)
		draw.RoundedBoxEx(10, 0, 0, pw, 56, headerCol, true, true, false, false)

		local headerText = isDestroy and "КПК УНИЧТОЖЕНИЯ ПОСТРОЕК (DEMOLISH PDA)" or "КПК СТРОИТЕЛЬСТВА (BUILD PDA)"
		draw.SimpleText(headerText, "TF2_PDA_Header", 20, 28, colors.tf2_text_gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		-- Нижняя информационная строка
		local curMetal = lp:TF2_GetMetal()
		local metalText = "МЕТАЛЛ: " .. curMetal .. " / 200"
		draw.SimpleText(metalText, "TF2_PDA_Header", pw - 24, ph - 26, colors.tf2_text_gold, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	-- Кнопка закрытия
	local closeBtn = vgui.Create("DButton", f)
	closeBtn:SetSize(36, 36)
	closeBtn:SetPos(w - 44, 10)
	closeBtn:SetText("X")
	closeBtn:SetFont("TF2_PDA_Large")
	closeBtn:SetTextColor(colors.tf2_text_yellow)
	closeBtn.Paint = function(s, bw, bh)
		draw.RoundedBox(6, 0, 0, bw, bh, s:IsHovered() and Color(200, 40, 40) or Color(28, 24, 22, 140))
	end
	closeBtn.DoClick = function() f:Close() end

	-- Кнопка переключения скина команды (RED / BLU)
	local skinBtn = vgui.Create("DButton", f)
	skinBtn:SetSize(140, 32)
	skinBtn:SetPos(w - 200, 12)
	skinBtn:SetText(myTeamSkin == TF2_ENG.TEAM_BLU and "КОМАНДА: BLU" or "КОМАНДА: RED")
	skinBtn:SetFont("TF2_PDA_Medium")
	skinBtn:SetTextColor(color_white)
	skinBtn.Paint = function(s, bw, bh)
		local col = myTeamSkin == TF2_ENG.TEAM_BLU and Color(60, 95, 120) or Color(140, 45, 45)
		draw.RoundedBox(6, 0, 0, bw, bh, col)
		surface.SetDrawColor(245, 195, 65, s:IsHovered() and 255 or 120)
		surface.DrawOutlinedRect(0, 0, bw, bh, 1)
	end
	skinBtn.DoClick = function()
		local nextSkin = myTeamSkin == TF2_ENG.TEAM_RED and TF2_ENG.TEAM_BLU or TF2_ENG.TEAM_RED
		net.Start("TF2_SwitchTeamSkin")
		net.WriteUInt(nextSkin, 2)
		net.SendToServer()
		f:Close()
		timer.Simple(0.1, function() TF2_ENG.OpenPDAMenu(isDestroy) end)
	end

	-- Переключатель режима Постройка / Уничтожение
	local modeBtn = vgui.Create("DButton", f)
	modeBtn:SetSize(190, 34)
	modeBtn:SetPos(20, h - 44)
	modeBtn:SetText(isDestroy and "В РЕЖИМ ПОСТРОЙКИ" or "В РЕЖИМ СНОСА")
	modeBtn:SetFont("TF2_PDA_Small")
	modeBtn:SetTextColor(color_white)
	modeBtn.Paint = function(s, bw, bh)
		draw.RoundedBox(6, 0, 0, bw, bh, isDestroy and Color(40, 110, 60) or Color(140, 40, 40))
		surface.SetDrawColor(245, 195, 65, 160)
		surface.DrawOutlinedRect(0, 0, bw, bh, 1)
	end
	modeBtn.DoClick = function()
		f:Close()
		TF2_ENG.OpenPDAMenu(not isDestroy)
	end

	-- Контейнер карточек 4-х построек
	local cardsContainer = vgui.Create("DPanel", f)
	cardsContainer:SetPos(16, 68)
	cardsContainer:SetSize(w - 32, 340)
	cardsContainer.Paint = nil

	local cardWidth = (w - 32 - 30) / 4

	for bType = 1, 4 do
		local bDef = TF2_ENG.Buildings[bType]
		local hasBuilding = lp:TF2_HasBuilding(bType)
		local existingEnt = lp:TF2_GetBuilding(bType)
		local curMetal = lp:TF2_GetMetal()
		local canAfford = (curMetal >= bDef.cost)

		local card = vgui.Create("DPanel", cardsContainer)
		card:SetPos((bType - 1) * (cardWidth + 10), 0)
		card:SetSize(cardWidth, 335)

		card.Paint = function(s, pw, ph)
			-- Фон карточки чертежа TF2 Blueprint
			local bg = s:IsHovered() and Color(32, 38, 48, 240) or Color(24, 28, 36, 230)
			if isDestroy and hasBuilding then
				bg = s:IsHovered() and Color(58, 26, 26, 240) or Color(42, 20, 20, 230)
			end
			draw.RoundedBox(8, 0, 0, pw, ph, bg)

			-- Обводка
			local borderCol = Color(70, 85, 110)
			if hasBuilding then
				borderCol = colors.tf2_green
			elseif not canAfford and not isDestroy then
				borderCol = Color(80, 50, 50)
			end
			surface.SetDrawColor(borderCol)
			surface.DrawOutlinedRect(0, 0, pw, ph, 1)

			-- Клавиша быстрого выбора [1, 2, 3, 4]
			draw.RoundedBox(6, 10, 10, 34, 34, Color(14, 18, 24, 200))
			draw.SimpleText(tostring(bType), "TF2_PDA_Key", 27, 27, colors.tf2_text_gold, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			-- Название постройки
			draw.SimpleText(bDef.name, "TF2_PDA_Title", pw * 0.5 + 16, 28, colors.tf2_text_yellow, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			-- Подзаголовок стоимости / статуса
			if not isDestroy then
				local costCol = canAfford and colors.tf2_text_gold or Color(220, 60, 60)
				draw.SimpleText("Стоимость: " .. bDef.cost .. " металла", "TF2_PDA_Small", pw * 0.5, 56, costCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			else
				if hasBuilding then
					draw.SimpleText("ПОСТРОЕНО", "TF2_PDA_Status", pw * 0.5, 52, Color(255, 120, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					draw.SimpleText("(ГОТОВО К СНОСУ)", "TF2_PDA_Small", pw * 0.5, 66, Color(240, 180, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				else
					draw.SimpleText("НЕ ПОСТРОЕНО", "TF2_PDA_Small", pw * 0.5, 58, colors.tf2_disabled, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
			end
		end

		-- 3D Модель превью постройки
		local mdlPanel = vgui.Create("DModelPanel", card)
		mdlPanel:SetPos(10, 84)
		mdlPanel:SetSize(cardWidth - 20, 185)
		mdlPanel:SetModel(TF2_ENG.GetBuildingModel(bType))
		mdlPanel:SetMouseInputEnabled(false)

		if IsValid(mdlPanel.Entity) then
			local mn, mx = mdlPanel.Entity:GetRenderBounds()
			local size = math.max(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z)
			mdlPanel:SetFOV(45)
			mdlPanel:SetCamPos(Vector(size * 1.15, size * 1.15, size * 0.6))
			mdlPanel:SetLookAt((mn + mx) * 0.5)
			mdlPanel.Entity:SetSkin(myTeamSkin)

			-- Освещение
			mdlPanel:SetAmbientLight(Color(100, 100, 100))
			mdlPanel:SetDirectionalLight(BOX_TOP, Color(245, 245, 245))
			mdlPanel:SetDirectionalLight(BOX_FRONT, Color(245, 195, 65))

			mdlPanel.LayoutEntity = function(s, ent)
				if not IsValid(ent) then return end
				if bType == TF2_ENG.BUILDING_DISPENSER then
					for i = 0, ent:GetBoneCount() - 1 do
						local bName = ent:GetBoneName(i)
						if bName and string.find(string.lower(bName), "chain") then
							ent:ManipulateBoneScale(i, Vector(0, 0, 0))
							ent:ManipulateBonePosition(i, Vector(0, 0, -100))
						end
					end
				end
				ent:SetAngles(Angle(0, CurTime() * 35, 0))
			end
		end

		-- Кнопка действия (Построить / Снести)
		local actionBtn = vgui.Create("DButton", card)
		actionBtn:SetPos(10, 276)
		actionBtn:SetSize(cardWidth - 20, 48)

		if not isDestroy then
			local btnText = "ПОСТРОИТЬ [" .. bType .. "]"
			if hasBuilding then
				btnText = "ПЕРЕНЕСТИ [" .. bType .. "]"
			end

			actionBtn:SetText(btnText)
			actionBtn:SetFont("TF2_PDA_Medium")
			actionBtn:SetTextColor(color_white)

			local btnBg = canAfford and (hasBuilding and Color(36, 110, 60) or Color(45, 85, 120)) or Color(75, 45, 45)
			actionBtn.Paint = function(s, bw, bh)
				draw.RoundedBox(6, 0, 0, bw, bh, s:IsHovered() and Color(btnBg.r + 25, btnBg.g + 25, btnBg.b + 25) or btnBg)
				surface.SetDrawColor(245, 195, 65, s:IsHovered() and 255 or 120)
				surface.DrawOutlinedRect(0, 0, bw, bh, 1)
			end

			actionBtn.DoClick = function()
				if not canAfford then
					surface.PlaySound("player/suit_denydevice.wav")
					return
				end
				f:Close()
				TF2_ENG.StartBuildingPlacement(bType)
			end
		else
			actionBtn:SetText("СНЕСТИ [" .. bType .. "]")
			actionBtn:SetFont("TF2_PDA_Medium")
			actionBtn:SetTextColor(color_white)

			local btnBg = hasBuilding and Color(160, 35, 35) or Color(65, 40, 40)
			actionBtn.Paint = function(s, bw, bh)
				draw.RoundedBox(6, 0, 0, bw, bh, s:IsHovered() and Color(btnBg.r + 30, btnBg.g + 15, btnBg.b + 15) or btnBg)
				surface.SetDrawColor(245, 195, 65, s:IsHovered() and 255 or 100)
				surface.DrawOutlinedRect(0, 0, bw, bh, 1)
			end

			actionBtn.DoClick = function()
				if not hasBuilding then
					surface.PlaySound("player/suit_denydevice.wav")
					return
				end
				net.Start("TF2_DestroyBuilding")
				net.WriteUInt(bType, 4)
				net.SendToServer()
				f:Close()
			end
		end
	end

	-- Горячие клавиши 1, 2, 3, 4 для мгновенного выбора
	f.OnKeyCodePressed = function(s, key)
		local bType = nil
		if key == KEY_1 or (KEY_PAD_1 and key == KEY_PAD_1) then
			bType = 1
		elseif key == KEY_2 or (KEY_PAD_2 and key == KEY_PAD_2) then
			bType = 2
		elseif key == KEY_3 or (KEY_PAD_3 and key == KEY_PAD_3) then
			bType = 3
		elseif key == KEY_4 or (KEY_PAD_4 and key == KEY_PAD_4) then
			bType = 4
		end

		if bType then
			if not isDestroy then
				local curMetal = lp:TF2_GetMetal()
				local bDef = TF2_ENG.Buildings[bType]
				if bDef and curMetal >= bDef.cost then
					f:Close()
					TF2_ENG.StartBuildingPlacement(bType)
				else
					surface.PlaySound("player/suit_denydevice.wav")
				end
			else
				if lp:TF2_HasBuilding(bType) then
					net.Start("TF2_DestroyBuilding")
					net.WriteUInt(bType, 4)
					net.SendToServer()
					f:Close()
				else
					surface.PlaySound("player/suit_denydevice.wav")
				end
			end
		end
	end
end

-- Приём команд открытия меню от сервера (чат-команды !build / !destroy)
net.Receive("TF2_OpenBuildMenu", function()
	TF2_ENG.OpenPDAMenu(false)
end)

net.Receive("TF2_OpenDestroyMenu", function()
	TF2_ENG.OpenPDAMenu(true)
end)
