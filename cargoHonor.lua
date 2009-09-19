-- Short configuration
local hideWinLoss = false			--[[	true: hides Win/Loss statistics on tooltip		]]
local hideWintergrasp = false		--[[	true: hides the wait time for Wintergrasp		]]
local hideWintergraspMarks = false	--[[	true: hides Wintergrasp marks and shards		]]

local useSI = true					--[[	true: SI-units, e.g. 3.7k instead of 3750			]]
-- Configuration end

local LPVP = LibStub("LibCargPVP")
local suffixes = {
	"total",
	"today",
	"bg",
	"arena",
	"honor",
}

local function siUnits(value)
	if(not useSI) then
		return value
	elseif(not value or value == 0) then
		return 0
	elseif(value >= 10^3) then
		return ("%.1fk"):format(value / 10^3)
	elseif(value >= 10^6) then
		return ("%.1fm"):format(value / 10^6)
	else
		return value
	end
end

local function texturizeIcon(arg1)
	return format("|T%s:15:15:0:0|t", type(arg1) == "number" and GetItemIcon(arg1) or arg1)
end

-- Initializing the object and frame
local honorIcon = "Interface\\AddOns\\cargoHonor\\"..UnitFactionGroup("player").."Icon"
local arenaIcon = [[Interface\PVPFrame\PVP-ArenaPoints-Icon]]

local OnEvent = function(self, event, ...) self[event](self, event, ...) end
local dataobj = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("cargoHonor", {
	type = "data source",
	text = "0 total",
	value = "0",
	icon = honorIcon,
	suffix = " total",
})
local frame = CreateFrame"Frame"

-- Color function for Marks of Honor
local function ColorGradient(perc, r1, g1, b1, r2, g2, b2, r3, g3, b3)
	if perc >= 1 then return r3, g3, b3 elseif perc <= 0 then return r1, g1, b1 end

	local segment, relperc = math.modf(perc*2)
	if segment == 1 then r1, g1, b1, r2, g2, b2 = r2, g2, b2, r3, g3, b3 end
	return r1 + (r2-r1)*relperc, g1 + (g2-g1)*relperc, b1 + (b2-b1)*relperc
end

-- [[    Update the display !    ]] --
local session, total, startTime
local startHonor, isBG
function frame:HONOR_CURRENCY_UPDATE()
	local displ = cargoHonor.displ
	local value

	local _, session = GetPVPSessionStats()
	local total = siUnits(GetHonorCurrency())
	local arena = siUnits(GetArenaCurrency())
	local bg = siUnits(session - startHonor or 0)

	if(displ == 5) then
		if(isBG) then
			value = bg.. " | "..siUnits(session).." | "
		elseif(session > 0) then
			value = siUnits(session).." | "
		else
			value = ""
		end
		value = value..total
	elseif(displ == 4) then
		value =  arena
	elseif(displ == 3) then
		value = bg
	elseif(displ == 2) then
		value = siUnits(session)
	else
		value = total
	end
	dataobj.value = value
	dataobj.text = value.." "..dataobj.suffix
end

--[[   Initialize all variables    ]] --
function frame:PLAYER_ENTERING_WORLD()
	if(not cargoHonor) then cargoHonor = {} end
	local session = select(2, GetPVPSessionStats())
	if(startHonor and isBG) then
		cargoHonor.LastBG = session - startHonor
	end
	startHonor = session
	isBG = (select(2, IsInInstance()) =="pvp")
	if(isBG) then
		if(not startTime) then startTime = time() end
		if(not startSession) then startSession = session end
	end
	if(cargoHonor.displ == 4) then dataobj.icon = [[Interface\PVPFrame\PVP-ArenaPoints-Icon]] end
	self:HONOR_CURRENCY_UPDATE()
end

frame:SetScript("OnEvent", OnEvent)
frame:RegisterEvent"HONOR_CURRENCY_UPDATE"
frame:RegisterEvent"PLAYER_ENTERING_WORLD"

-- [[   The tooltip  ]] --
function dataobj.OnTooltipShow(tooltip)

	-- Honor Stats
	local holidayID, isHoliday = LPVP.GetBattlegroundHoliday()
	local _, holidayAbbr = LPVP.GetBattlegroundName(holidayID)
	session = select(2, GetPVPSessionStats())
	total = GetHonorCurrency()
	local perHour
	if(startTime) then perHour = (session-startSession)/((time()-startTime)/3600) end
	
	tooltip:AddDoubleLine(total.." Honor", isHoliday and holidayAbbr, 0,1,0, 0,1,0)
	tooltip:AddDoubleLine("Today:", ("|cff00ff00%i|r (|cff00ff00%i|r/h) %s"):format(session, perHour or 0, texturizeIcon(honorIcon)), 1,1,1, 1,1,1)
	if(isBG and startHonor) then
		tooltip:AddDoubleLine("This BG:", (session-startHonor).." "..texturizeIcon(honorIcon), 1,1,1, 0,1,0)
	end
	if(cargoHonor and cargoHonor.LastBG) then
		tooltip:AddDoubleLine("Last BG:", cargoHonor.LastBG.." "..texturizeIcon(honorIcon), 1,1,1, 0,1,0)
	end

	-- Arena points
	local arena = GetArenaCurrency()
	if(arena > 0) then
		tooltip:AddDoubleLine("Arena points:", arena.." "..texturizeIcon(arenaIcon), 1,1,1, 0,1,0)
	end

	-- Next holiday
	if(not isHoliday) then
		tooltip:AddDoubleLine("Next holiday:", holidayAbbr, 1,1,1, 1,1,1)
	end

	tooltip:AddLine(" ")
	local dailyID = LPVP.GetBattlegroundDaily()
	for i=1, GetNumBattlegroundTypes() do
		local marks, itemID = LPVP.GetBattlegroundMarkCount(i)
		local won, total = LPVP.GetBattlegroundWinTotal(i)
		local _, abbr = LPVP.GetBattlegroundName(i)

		local left = ""
		if(not hideWinLoss and total > 0) then
			local r,g,b = ColorGradient(won/total, 1,0,0, 1,1,0, 0,1,0)
			left = ("|cff%2x%2x%2x%.0f%%|r "):format(r*255,g*255,b*255, won/total*100)
		end
		tooltip:AddDoubleLine(left..abbr..(i == dailyID and " |cff8899ff[D]|r" or ""), marks.." "..texturizeIcon(itemID), 1,1,1, 1,1,1)
	end

	local wgTime = GetWintergraspWaitTime()
	if(not hideWintergrasp) then
		if(wgTime and wgTime > 0) then
			tooltip:AddLine(" ")
			local battleSec = mod(wgTime, 60)
			local battleMin = mod(floor(wgTime / 60), 60)
			local battleHour = floor(wgTime / 3600)
			wgTime = ("%01d:%02d:%02d"):format(battleHour, battleMin, battleSec)
			tooltip:AddDoubleLine("Wintergrasp start:", wgTime, 1,1,1, 0,1,0)
		else
			tooltip:AddDoubleLine("Wintergrasp start:", "In Progress", 1,1,1, 0,1,0)
		end
	end
	if(not hideWintergraspMarks) then
		local markString = ("%d %s %d %s"):format(GetItemCount(43589),
			texturizeIcon(43589),
			GetItemCount(43228),
			texturizeIcon(43228))
		tooltip:AddDoubleLine("Wintergrasp Marks:", markString, 1,1,1, 1,1,1)
	end
	tooltip:AddLine(" ")
	tooltip:AddLine("Click to toggle display")
	tooltip:AddLine("Right-click to open PvP-Panel")
	tooltip.updateFunction = dataobj.OnTooltipShow
end

function dataobj.OnClick(self, button)
	if(button == "RightButton") then
		TogglePVPFrame()
	else
		cargoHonor.displ = (cargoHonor.displ == 5 and 1) or (cargoHonor.displ and cargoHonor.displ+1) or 2
		local displ = cargoHonor.displ
		if(displ == 4) then
			dataobj.icon = arenaIcon
		elseif(displ == 5) then
			dataobj.icon = honorIcon
		end
		dataobj.suffix = suffixes[displ]
		frame:HONOR_CURRENCY_UPDATE()
	end
end
