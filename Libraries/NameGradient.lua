local text = "IdaliaTMC"

local pText = {}

for char in text:gmatch("[\x00-\x7F\xC2-\xF4][\x80-\xBF]*") do
    table.insert(pText, char)
end

local color1 = vec(1, 0, 0)
local color2 = vec(1, 0.847, 0.004)

local json = {
    text = "",

    hoverEvent = {
        action = "show_text",
        contents = {
            text = "Idalia, The Metal Catgirl\nPronouns: She/her\nLicensed Colour Fixer\nRuns Birdwatch Office as a Solo Office",
            color = "#ff0000"
        }
    },

    extra = {}
}

-- Gradient name
for i, c in ipairs(pText) do
    table.insert(json.extra, {
        text = c,
        color = "#" .. vectors.rgbToHex(
            math.lerp(color1, color2, (i - 1) / #pText)
        )
    })
end

-- Emoji after the name
table.insert(json.extra, {
    text = ":@idalia:",
    color = "#ffffff"
})


nameplate.ALL:setText(toJson(json))

nameplate.ENTITY
    :setOutline(true)
    :setOutlineColor(50 / 255, 0, 0)
    :setBackgroundColor(0, 0, 0)