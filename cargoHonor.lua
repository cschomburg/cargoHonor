-- Short configuration
local hideMarks = false			--[[	true: hides Marks of Honor tooltip information		]]
local hideWinLoss = false		--[[	true: hides Win/Loss statistics on tooltip			]]
local hideWintergrasp = false	--[[	true: hides the wait time for Wintergrasp			]]

local useSI = true				--[[	true: SI-units, e.g. 3.7k							]]

local info = {
	{
		name = "Alterac Valley",
		abbr = "Alterac",
		achTotal = 53,
		achWon = 49,
		itemID = 20560,
	},{
		name = "Arathi Basin",
		abbr = "Arathi",
		achTotal = 55,
		achWon = 51,
		itemID = 20559,
	},{
		name = "Eye of the Storm",
		abbr = "EotS",
		achTotal = 54,
		achWon = 50,
		itemID = 29024,
	},{
		name = "Isle of Conquest",
		abbr = "IoC",
		achTotal = 4096,
		achWon = 4097,
		itemID = 47395,
	},{
		name = "Strand of the Ancients",
		abbr = "SotA",
		achTotal = 1549,
		achWon = 1550,
		itemID = 42425,
	},{
		name = "Warsong Gulch",
		abbr = "Warsong",
		achTotal = 52,
		achWon = 105,
		itemID = 20558,
	},
	{
		name = "Wintergrasp",
		abbr = "Wintergrasp",
		itemID = 43589,
	},
}

local suffixes = {
	"total",
	"today",
	"bg",
	"arena",
	"honor",
}

local holidays = {
	"Alterac",
	"Warsong",
	"SotA",
	"IoC",
	"Arathi",
	"EotS",
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

-- Initializing the object and frame
local playerFaction = UnitFactionGroup("player")
local OnEvent = function(self, event, ...) self[event](self, event, ...) end
local dataobj = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("cargoHonor", {
	type = "data source",
	text = "0 total",
	value = "0",
	icon = "Interface\\AddOns\\cargoHonor\\"..playerFaction.."Icon",
	suffix = " total",
})
local frame = CreateFrame"Frame"

-- Print the next bg holiday and if it's currently active
local function GetBattlegroundHoliday()
	local max = #holidays
	local now = date("*t")
	local week = floor(now.yday/7)+1
	if(now.wday == 3) then week = week +1 end
	week = (week + 2) % max
	week = week > 0 and week or max
	return holidays[week], now.wday > 5 or now.wday < 3
end

-- Color function for Marks of Honor
local function ColorGradient(perc, r1, g1, b1, r2, g2, b2, r3, g3, b3)
	if perc >= 1 then return r3, g3, b3 elseif perc <= 0 then return r1, g1, b1 end

	local segment, relperc = math.modf(perc*2)
	if segment == 1 then r1, g1, b1, r2, g2, b2 = r2, g2, b2, r3, g3, b3 end
	return r1 + (r2-r1)*relperc, g1 + (g2-g1)*relperc, b1 + (b2-b1)*relperc
end

-- Get percent, win total info by battleground id
local function GetWinTotal(i)
	local total, won
	if(not i) then
		total, won = GetStatistic(839), GetStatistic(840)
	elseif(not info[i].achTotal or not info[i].achWon) then
		return 0, 0
	else
		total, won = GetStatistic(info[i].achTotal), GetStatistic(info[i].achWon)
	end
	if(total == "--") then total = 0 else total = tonumber(total) or 0 end
	if(won == "--") then won = 0 else won = tonumber(won) end
	
	return won, total
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
	session = siUnits(session)

	if(displ == 5) then
		if(isBG) then
			value = bg.. " | "
		elseif(session > 0) then
			value = session.." | "
		else
			value = ""
		end
		value = value..total
	elseif(displ == 4) then
		value =  arena
	elseif(displ == 3) then
		value = bg
	elseif(displ == 2) then
		value = session
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
	local bgHoliday, isHoliday = GetBattlegroundHoliday()
	session = select(2, GetPVPSessionStats())
	total = GetHonorCurrency()
	local perHour
	if(startTime) then perHour = (session-startSession)/((time()-startTime)/3600) end
	
	tooltip:AddDoubleLine(total.." Honor", isHoliday and bgHoliday, 0,1,0, 0,1,0)
	tooltip:AddDoubleLine("Today:", ("|cff00ff00%i|r (|cff00ff00%i|r/h)"):format(session, perHour or 0), 1,1,1, 1,1,1)
	if(isBG and startHonor) then
		tooltip:AddDoubleLine("This BG:", session-startHonor, 1,1,1, 0,1,0)
	end
	if(cargoHonor and cargoHonor.LastBG) then
		tooltip:AddDoubleLine("Last BG:", cargoHonor.LastBG, 1,1,1, 0,1,0)
	end

	-- Arena points
	local arena = GetArenaCurrency()
	if(arena > 0) then
		tooltip:AddDoubleLine("Arena points:", arena, 1,1,1, 0,1,0)
	end

	-- Next holiday
	if(not isHoliday) then
		tooltip:AddDoubleLine("Next holiday:", bgHoliday, 1,1,1, 1,1,1)
	end

	-- Marks
	if(not hideMarks) then
		tooltip:AddLine(" ")
		tooltip:AddLine("Marks of Honor")
		for i, bg in ipairs(info) do
			local marks = GetItemCount(bg.itemID, true)
			if(marks > 0) then
				tooltip:AddDoubleLine(bg.abbr, marks, 1,1,1, ColorGradient(marks/100, 1,0,0, 1,1,0, 0,1,0))
			end
		end
	end

	-- Win/Loss Ratio
	if(not hideWinLoss) then
		tooltip:AddLine(" ")
		tooltip:AddLine("Win/Loss Ratio")
		for i, bg in ipairs(info) do
			local win, total = GetWinTotal(i)
			if(total > 0) then
				tooltip:AddDoubleLine(
					("%dx %s:"):format(total, bg.abbr),
					("%.0f|cffffffff%%|r"):format(win/total*100),
					1,1,1, ColorGradient(win/total, 1,0,0, 1,1,0, 0,1,0)
				)
			end
		end
	end
	local wgTime = GetWintergraspWaitTime()
	if(not hideWintergrasp and wgTime) then
		wgTime = SecondsToTimeAbbrev(wgTime)
		tooltip:AddLine(" ")
		tooltip:AddDoubleLine("Wintergrasp start:", wgTime, 1,1,1, 0,1,0)
	end
	tooltip:AddLine(" ")
	tooltip:AddLine("Click to toggle display")
	tooltip:AddLine("Right-click to open PvP-Panel")
end

function dataobj.OnClick(self, button)
	if(button == "RightButton") then
		TogglePVPFrame()
	else
		cargoHonor.displ = (cargoHonor.displ == 5 and 1) or (cargoHonor.displ and cargoHonor.displ+1) or 2
		local displ = cargoHonor.displ
		if(displ == 4) then
			dataobj.icon = [[Interface\PVPFrame\PVP-ArenaPoints-Icon]]
		elseif(displ == 5) then
			dataobj.icon = "Interface\\AddOns\\cargoHonor\\"..playerFaction.."Icon"
		end
		dataobj.suffix = suffixes[displ]
		frame:HONOR_CURRENCY_UPDATE()
	end
end
