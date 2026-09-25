-- Turns big numbers into short text: 1500 -> "1.5K", 2300000 -> "2.3M".

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Format.number(n: number): string
	if n < 1000 then
		return tostring(math.floor(n))
	end

	local index = 1
	while n >= 1000 and index < #SUFFIXES do
		n /= 1000
		index += 1
	end

	-- Round down to one decimal so 999.99K never shows as "1000.0K", and drop a trailing ".0".
	local text = string.format("%.1f", math.floor(n * 10) / 10)
	text = string.gsub(text, "%.0$", "")
	return text .. SUFFIXES[index]
end

return Format
