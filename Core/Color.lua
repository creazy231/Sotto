-------------------------------------------------------------------------------
--  Sotto: colour maths (sRGB, OKLab lightness, WCAG contrast). Pure functions.
--  The grounds of the window are EllesmereUI's panel colour moved in OKLab
--  lightness, the same steps Polestar's "EllesmereUI" scheme takes; name and
--  accent colours are lifted toward the text colour until they read at 4.5:1.
-------------------------------------------------------------------------------
local _, ns = ...
local C = {}
ns.Color = C

local floor, max, min = math.floor, math.max, math.min

local function toLinear(c)
    if c <= 0.04045 then return c / 12.92 end
    return ((c + 0.055) / 1.055) ^ 2.4
end

local function toGamma(c)
    if c <= 0 then return 0 end
    c = c <= 0.0031308 and 12.92 * c or 1.055 * c ^ (1 / 2.4) - 0.055
    return c > 1 and 1 or c
end

local function cbrt(x)
    if x < 0 then return -((-x) ^ (1 / 3)) end
    return x ^ (1 / 3)
end

local function toLab(r, g, b)
    r, g, b = toLinear(r), toLinear(g), toLinear(b)
    local l = cbrt(0.4122214708 * r + 0.5363151677 * g + 0.0514459929 * b)
    local m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    local s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    return 0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
        1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s,
        0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s
end

local function fromLab(L, a, b)
    local l = (L + 0.3963377774 * a + 0.2158037573 * b) ^ 3
    local m = (L - 0.1055613458 * a - 0.0638541728 * b) ^ 3
    local s = (L - 0.0894841775 * a - 1.291485548 * b) ^ 3
    return toGamma(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
        toGamma(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
        toGamma(-0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s)
end

-- c moved by dL in OKLab lightness, chroma scaled by k (default 1).
function C.Shift(c, dL, k)
    local L, a, b = toLab(c[1], c[2], c[3])
    k = k or 1
    L = max(0, min(1, L + dL))
    local r, g, bb = fromLab(L, a * k, b * k)
    return { r, g, bb, c[4] or 1 }
end

function C.Luminance(r, g, b)
    return 0.2126 * toLinear(r) + 0.7152 * toLinear(g) + 0.0722 * toLinear(b)
end

function C.Contrast(c1, c2)
    local a, b = C.Luminance(c1[1], c1[2], c1[3]), C.Luminance(c2[1], c2[2], c2[3])
    if a < b then a, b = b, a end
    return (a + 0.05) / (b + 0.05)
end

-- c moved toward `toward` (the text colour) in 15 % steps until it reads at
-- `ratio` on `ground`. -> r, g, b
function C.Lift(ground, toward, c, ratio)
    ratio = ratio or 4.5
    local r, g, b = c[1], c[2], c[3]
    for _ = 1, 24 do
        if C.Contrast({ r, g, b }, ground) >= ratio then break end
        r = r + (toward[1] - r) * 0.15
        g = g + (toward[2] - g) * 0.15
        b = b + (toward[3] - b) * 0.15
    end
    return r, g, b
end

-- "ffrrggbb" for |c escapes.
function C.Hex(r, g, b)
    return string.format("ff%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end
