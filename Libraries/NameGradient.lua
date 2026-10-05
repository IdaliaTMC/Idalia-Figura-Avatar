local text = "IdaliaTMC" -- replace name with whatever you want
local pText = {}
for char in text:gmatch("[\x00-\x7F\xC2-\xF4][\x80-\xBF]*") do
  table.insert(pText, char)
end
local color1 = vec(1, 0, 0) -- replace these with whatever rgbs you want
local color2 = vec(1, 0.847, 0.004)
local json = {}
for i, c in ipairs(pText) do
  table.insert(json, {
    text = c,
    color = "#" .. vectors.rgbToHex(math.lerp(color1, color2, (i - 1) / #pText)),
  })
end
table.insert(json, {text = ":@idalia:", color = "#ffffff"}) -- insert emoji after gradient

nameplate.ALL:setText(toJson(json))
nameplate.Entity:setOutline(true):setOutlineColor(50 / 255, 0 / 255, 0 / 255):setBackgroundColor(0 / 255, 0 / 255, 0 / 255)