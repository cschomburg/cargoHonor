-- Short configuration
local useSI = true					--[[	true: SI-units, e.g. 3.7k instead of 3750			]]
-- Configuration end

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
local honorIcon = "Interface\\PVPFrame\\PVP-Currency-"..UnitFactionGroup("player")
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
