-- Config section ---

-- Overwrite the peripheral names if necessary
local monitor = peripheral.wrap("left")
local reactor = peripheral.wrap("fissionReactorLogicAdapter_2")
local storage = peripheral.wrap("inductionPort_2")

local ENERGY_MAX = 95
local ENERGY_THRESHOLD = 90
local DAMAGE_MAX = 1
-- 1200 is the maximum safe temperature
local TEMPERATURE_MAX = 1000

--- Config end ---

local strReactorStatus = "Status:    "
local lenReactorStatus = string.len(strReactorStatus)
local strTemperature   = "Temp (K):  "
local lenTemperature   = string.len(strTemperature)
local strDamage        = "Damage:    "
local lenDamage        = string.len(strDamage)
local strFuel          = "Fuel:      "
local lenFuel          = string.len(strFuel)
local strCoolant       = "Coolant:   "
local lenCoolant       = string.len(strCoolant)
local strWaste         = "Waste:     "
local lenWaste         = string.len(strWaste)
local strEnergy        = "Energy:    "
local lenEnergy        = string.len(strEnergy)

-- Used to construct the static status keys
strs = { strReactorStatus, strTemperature, strDamage, strFuel, strCoolant, strWaste, strEnergy }

userEnabled = false
energySatisfied = false
-- Used to display target/threshold energy
energyNote = 0

-- Urgent status information
info = " "

local function toggleReactor()
	userEnabled = not userEnabled
	if string.len(info) == 1 then
		if reactor.getStatus() then
			reactor.scram()
		else
			reactor.activate()
		end
	end
end

local function stopReactor()
	if reactor.getStatus() then
		reactor.scram()
	end
end

local function clearEOL()
	local col, _ = monitor.getCursorPos()
	local len, _ = monitor.getSize()
	len = (len - col) + 1
	monitor.blit(string.rep(" ", len), string.rep("f", len), string.rep("f", len))
end

local function printInfo()
	if string.len(info) == 1 then
		monitor.setCursorPos(1,1)
		monitor.clearLine()
	else
		local len, _ = monitor.getSize()
		monitor.setCursorPos((len / 2 - string.len(info) / 2) + 1, 1)
		local c = string.len(info) > 1 and "e" or "0"
		monitor.blit(info, string.rep(c, string.len(info)), string.rep("f", string.len(info)))
		clearEOL()
	end
end

local function printStatus()
	monitor.setCursorPos(lenReactorStatus + 1, 2)
	if reactor.getStatus() then
		monitor.blit(" ON  ", "00000", "55555")
	else
		monitor.blit(" OFF ", "00000", "eeeee")
	end
	monitor.write(" (" .. (userEnabled and "on)" or "off)"))
	clearEOL()
end

local function printTemperature()
	monitor.setCursorPos(lenTemperature + 1, 3)
	local t = reactor.getTemperature()
	local tStr = string.format("%.1f/%d", t, TEMPERATURE_MAX)
	local c = t >= TEMPERATURE_MAX and "e" or "0"
	monitor.blit(tStr, string.rep(c, string.len(tStr)), string.rep("f", string.len(tStr)))
	clearEOL()
end

local function printDamage()
	monitor.setCursorPos(lenDamage + 1, 4)
	local d = reactor.getDamagePercent()
	local c = d >= DAMAGE_MAX and "e" or "0"
	dStr = string.format("%d%%", d)
	monitor.blit(dStr, string.rep(c, string.len(dStr)), string.rep("f", string.len(dStr)))
	clearEOL()
end

local function printFuel()
	monitor.setCursorPos(lenFuel + 1, 5)
	local f = (reactor.getFuel().amount / reactor.getFuelCapacity()) * 100
	local c = f < 20 and "e" or "0"
	fStr = string.format("%.1f%%", f)
	monitor.blit(fStr, string.rep(c, string.len(fStr)), string.rep("f", string.len(fStr)))
	clearEOL()
end

local function getCoolantPercent()
	return (reactor.getCoolant().amount / reactor.getCoolantCapacity()) * 100
end

local function printCoolant()
	monitor.setCursorPos(lenCoolant + 1, 6)
	local co = getCoolantPercent()
	local c = co < 20 and "e" or "0"
	coStr = string.format("%.1f%%", co)
	monitor.blit(coStr, string.rep(c, string.len(coStr)), string.rep("f", string.len(coStr)))
	clearEOL()
end

local function printWaste()
	monitor.setCursorPos(lenWaste + 1, 7)
	local w = (reactor.getWaste().amount / reactor.getWasteCapacity()) * 100
	local c = w > 80 and "e" or "0"
	wStr = string.format("%.1f%%", w)
	monitor.blit(wStr, string.rep(c, string.len(wStr)), string.rep("f", string.len(wStr)))
	clearEOL()
end

local function getEnergyPercent()
	return (storage.getEnergy() / storage.getMaxEnergy()) * 100
end

local function printEnergy()
	monitor.setCursorPos(lenEnergy + 1, 8)
	local w = getEnergyPercent()
	local c = w > ENERGY_MAX and "e" or "0"
	wStr = string.format("%.1f%% (%d%%)", w, energyNote)
	monitor.blit(wStr, string.rep(c, string.len(wStr)), string.rep("f", string.len(wStr)))
	clearEOL()
end

local function printTimeStamp()
	monitor.setCursorPos(1, 12)
	monitor.write(os.date())
end

local function renderMonitor()
	monitor.clear()
	for i, s in pairs(strs) do
		monitor.setCursorPos(1, i + 1)
		monitor.write(s)
	end

	while true do
		printInfo()
		printStatus()
		printTemperature()
		printDamage()
		printFuel()
		printCoolant()
		printWaste()
		printEnergy()
		printTimeStamp()
		os.sleep(0.5)
	end
end

local function controlReactor()
	while true do
		-- Toggle alarm
		if (reactor.getTemperature() >= TEMPERATURE_MAX or getCoolantPercent() <= 20) then
			redstone.setOutput("top", true)
		else
			redstone.setOutput("top", false)
		end

		if reactor.getTemperature() >= TEMPERATURE_MAX then
			stopReactor()
			info = "--- TEMPERATURE CRITICAL ---"
		elseif reactor.getDamagePercent() > DAMAGE_MAX then
			stopReactor()
			info = "--- DAMAGE CRITICAL ---"
		elseif getCoolantPercent() <= 20 then
			stopReactor()
			info = "--- COOLANT LOW ---"
		elseif getEnergyPercent() >= ENERGY_MAX then
			stopReactor()
			energySatisfied = true
			energyNote = ENERGY_THRESHOLD
			info = "--- ENERGY FULL ---"
		elseif energySatisfied and getEnergyPercent() > ENERGY_THRESHOLD then
			stopReactor()
			energyNote = ENERGY_THRESHOLD
			info = "--- ENERGY FULL ---"
		else
			if userEnabled then
				if not reactor.getStatus() then
					reactor.activate()
				end
			else
				if  reactor.getStatus() then
					reactor.scram()
				end
			end
			energySatisfied = false
			energyNote = ENERGY_MAX
			info = " "
		end

		sleep(1)
	end
end

local function handleInputs()
	while true do
		local event, side, col, row = os.pullEvent("monitor_touch")
		if row == 2 and col > lenReactorStatus and col <= lenReactorStatus + 5 then
			toggleReactor()
		end
	end
end

parallel.waitForAll(renderMonitor, controlReactor, handleInputs)

