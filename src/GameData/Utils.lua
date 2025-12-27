local Utils = {}

function Utils.weightedChoice(list, weights, random)
	if #list == 0 then
		return nil
	elseif #list == 1 then
		return list[1]
	else
		local total = 0
		for i=1, #list do
			assert(typeof(weights[i]) == "number", "Bad weights")
			total = total + weights[i]
		end

		local randomNum
		if random then
			randomNum = random:NextNumber()
		else
			randomNum = math.random()
		end

		local totalSum = 0

		for i=1, #list do
			if weights[i] == 0 then
				continue
			end
			totalSum = totalSum + weights[i]
			local threshold = totalSum/total
			if randomNum <= threshold then
				return list[i]
			end
		end

        warn("GameDataUtils.weightedChoice() Failed to reach threshold! Algorithm is wrong!")
		return list[#list]
	end
end

function Utils.addCommas(number: number): string
	local str = tostring(number)
	return str:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

function Utils.formatNumber(number: number): string
	number = tonumber(number)
	if typeof(number)~="number" then return "0" end
	local suffixes = {"", "K", "M", "B", "T", "Qa", "Qi"} -- extend if needed
	local i = 1

	while number >= 1000 and i < #suffixes do
		number = number / 1000
		i += 1
	end

	if i > 1 then
		return string.format("%.1f%s", number, suffixes[i])
	else
		return Utils.addCommas(math.floor(number + 0.5))
	end
end

function Utils.formatTime(t)
	local min,sec = t//60,math.round(t%60)
	local hour = min//60
	local str=("%1d:%02d"):format(min%60,sec)
	if hour>0 then
		str=("%d:%02d:%02d"):format(hour%24,min%60,sec)
	end
	return str
end

return Utils