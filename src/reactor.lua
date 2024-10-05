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

local strReactorStatus = "Status:  "
local lenReactorStatus = string.len(strReactorStatus)
local strTemperature   = "Temp.:   "
local lenTemperature   = string.len(strTemperature)
local strDamage        = "Dmg.:    "
local lenDamage        = string.len(strDamage)
local strFuel          = "Fuel:    "
local lenFuel          = string.len(strFuel)
local strCoolant       = "Cool.:   "
local lenCoolant       = string.len(strCoolant)
local strWaste         = "Waste:   "
local lenWaste         = string.len(strWaste)
local strEnergy        = "Energy:  "
local lenEnergy        = string.len(strEnergy)
local strTransfer      = "I/O (t): "
local lenTransfer      = string.len(strTransfer)

-- Used to construct the static status keys
strs = { strReactorStatus, strTemperature, strDamage, strFuel, strCoolant, strWaste, strEnergy, strTransfer }

userEnabled = false
energySatisfied = false

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
		local l = string.len(info)
		local c = l > 1 and "e" or "0"
		monitor.blit(info, string.rep(c, l), string.rep("f", l))
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
	local val = reactor.getTemperature()
	local valStr = string.format("%.1fK/1200K", val)
	local l = string.len(valStr)
	local c = val >= TEMPERATURE_MAX and "e" or "0"
	monitor.blit(valStr, string.rep(c, l), string.rep("f", l))
	clearEOL()
end

local function printDamage()
	monitor.setCursorPos(lenDamage + 1, 4)
	local val = reactor.getDamagePercent()
	local valStr = string.format("%d%%", val)
	local l = string.len(valStr)
	local c = val >= DAMAGE_MAX and "e" or "0"
	monitor.blit(valStr, string.rep(c, l), string.rep("f", l))
	clearEOL()
end

local function printFuel()
	monitor.setCursorPos(lenFuel + 1, 5)
	local val = (reactor.getFuel().amount / reactor.getFuelCapacity()) * 100
	local valStr = string.format("%.1f%%", val)
	local l = string.len(valStr)
	local c = val < 20 and "e" or "0"
	monitor.blit(valStr, string.rep(c, l), string.rep("f", l))
	clearEOL()
end

local function getCoolantPercent()
	return (reactor.getCoolant().amount / reactor.getCoolantCapacity()) * 100
end

local function printCoolant()
	monitor.setCursorPos(lenCoolant + 1, 6)
	local val = getCoolantPercent()
	local valStr = string.format("%.1f%%", val)
	local l = string.len(valStr)
	local c = val < 20 and "e" or "0"
	monitor.blit(valStr, string.rep(c, l), string.rep("f", l))
	clearEOL()
end

local function printWaste()
	monitor.setCursorPos(lenWaste + 1, 7)
	local val = (reactor.getWaste().amount / reactor.getWasteCapacity()) * 100
	local valStr = string.format("%.1f%%", val)
	local l = string.len(valStr)
	local c = val > 80 and "e" or "0"
	monitor.blit(valStr, string.rep(c, l), string.rep("f", l))
	clearEOL()
end

local function getEnergyPercent()
	return (storage.getEnergy() / storage.getMaxEnergy()) * 100
end

local function formatEnergy(val)
	val = val / 2.5
	fmt = (val < 1000000 and {val / 1000, "K"})
		or (val < 1000000000 and {val / 1000000, "M"})
		or (val < 1000000000000 and {val / 1000000000, "G"})
		or (val < 1000000000000000 and {val / 1000000000, "T"})
	return string.format("%.1f" .. fmt[2], fmt[1])
end

local function printEnergy()
	monitor.setCursorPos(lenEnergy + 1, 8)
	local valPct = getEnergyPercent()
	local valStr = formatEnergy(storage.getEnergy()) .. "/" ..
		formatEnergy(storage.getMaxEnergy()) .. " ("
	local l = string.len(valStr)
	monitor.blit(valStr, string.rep("0", l), string.rep("f", l))
	valStr = string.format("%d%%", valPct)
	l = string.len(valStr)
	local c = (valPct < 20  and "e") or (valPct < 80 and "4") or "5"
	monitor.blit(valStr, string.rep(c, l), string.rep("f", l))
	monitor.write(")")
	clearEOL()
end

local function printTransfer()
	monitor.setCursorPos(lenTransfer + 1, 9)
	local valI = storage.getLastInput()
	local valO = storage.getLastOutput()
	local c = valI > 0 and "5" or "0"
	valI = formatEnergy(valI)
	local l = string.len(valI)
	monitor.blit(valI, string.rep(c, l), string.rep("f", l))
	monitor.write("/")
	c = valO > 0 and "e" or "0"
	valO = formatEnergy(valO)
	l = string.len(valO)
	monitor.blit(valO, string.rep(c, l), string.rep("f", l))
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
		printTransfer()
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
			info = "--- ENERGY FULL ---"
		elseif energySatisfied and getEnergyPercent() > ENERGY_THRESHOLD then
			stopReactor()
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

