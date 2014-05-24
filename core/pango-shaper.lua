local lgi = require("lgi");
require "string"
local pango = lgi.Pango
local fm = lgi.PangoCairo.FontMap.get_default()
local pango_context = lgi.Pango.FontMap.create_context(fm)

SILE.shapers = { pango= {} }

function itemize(s, pal)
  return pango.itemize(pango_context, s, 0, string.len(s), pal, nil)
end

function _shape(s, item)
  local offset = item.offset
  local length = item.length
  local analysis = item.analysis
  local pgs = pango.GlyphString.new()
  pango.shape(string.sub(s,1+offset), length, analysis, pgs)
  return pgs
end

local palcache = {}

local function setDefaultOptions(options)
  if not options.font then options.font = SILE.documentState.fontFamily end
  if not options.size then options.size = SILE.documentState.fontSize end
  if not options.rise then options.rise = SILE.documentState.fontRise end
  if not options.weight then options.weight = SILE.documentState.fontWeight end
  if not options.style then options.style = SILE.documentState.fontStyle end
  if not options.variant then options.variant = SILE.documentState.fontVariant end
  if not options.language then options.language = SILE.documentState.language end
  if not options.underline then options.underline = SILE.documentState.fontUnderline end
  return options
end

local function getPal(options)
  if options.pal then
    pal = options.pal
    return pal
  end
  local p = std.string.pickle(options)
  if palcache[p] then return palcache[p]
  else
    pal = pango.AttrList.new();
    if options.language then pal:insert(pango.Attribute.language_new(pango.Language.from_string(options.language))) end
    if options.font then pal:insert(pango.Attribute.family_new(options.font)) end
    if options.weight then pal:insert(pango.Attribute.weight_new(tonumber(options.weight))) end
    if options.size then pal:insert(pango.Attribute.size_new(options.size * 1024 * 0.75)) end -- I don't know why 0.75
    if options.rise then pal:insert(pango.Attribute.rise_new(options.rise * 1024 * 0.75)) end
    if options.style then pal:insert(pango.Attribute.style_new(
      options.style == "italic" and pango.Style.ITALIC or pango.Style.NORMAL)) end
    if options.variant then pal:insert(pango.Attribute.variant_new(
      options.variant == "smallcaps" and pango.Variant.SMALL_CAPS or pango.Variant.NORMAL)) end
    if options.underline then 
      print("Adding underline "..options.underline)
      pal:insert(pango.Attribute.underline_new(
      options.underline == "single" and pango.Underline.SINGLE or
      options.underline == "double" and pango.Underline.DOUBLE or
      pango.Underline.ERROR))
    end
  end
  if options.language then
    pango_context:set_language(pango.Language.from_string(options.language))
  end
  palcache[p] = pal
  return pal
end  

local function measureSpace( pal )
  local spaceitem = itemize(" ",pal)[1]
  local g = (_shape(" ",spaceitem).glyphs)[1]
  local spacewidth = g.geometry.width / 1024;
  if SILE.documentState.documentClass.state.spaceskip then
    return SILE.documentState.documentClass.state.spaceskip
  end
  return SILE.length.new({ length = spacewidth * 1.2, shrink = spacewidth/3, stretch = spacewidth /2 }) -- XXX
end

function SILE.shapers.pango.shape(text, options)
  if not options then options = {} end
  options = setDefaultOptions(options)

  local pal = getPal(options)
  local nodes = {}
  local gluewidth = measureSpace(pal)
  for token in SU.gtoke(text) do
    if (token.separator) then
      table.insert(nodes, SILE.nodefactory.newGlue({ width = gluewidth }))
    else
      local items = itemize(token.string, pal)
      local nnode = {}
      for i in pairs(items) do
        local pgs = _shape(token.string, items[i])
        -- Sum the glyphs in this string
        local depth, height = 0,0
        local font = items[i].analysis.font
        for g in pairs(pgs.glyphs) do
          local rect = font:get_glyph_extents(pgs.glyphs[g].glyph)
          local desc = rect.y + rect.height
          local asc  = -rect.y 
          if desc > depth then depth = desc end
          if asc > height then height = asc end
        end
        table.insert(nnode, SILE.nodefactory.newHbox({ 
          depth = depth / 1024,
          height= height / 1024,
          width = SILE.length.new({ length= pgs:get_width() / 1024 }),
          value = {font = font, glyphString = pgs, options = options }
        }))
      end
      table.insert(nodes, SILE.nodefactory.newNnode({ 
        nodes = nnode,
        text = token.string,
        pal = pal,
        options = options,
        language = options.language
      }))
    end
  end
  return nodes
end


SILE.shaper = SILE.shapers.pango

-- 
-- local s = "ltr שָׁוְא ltr"
-- inspect = require "inspect"
-- 

-- for i in pairs(items) do
--   local offset = items[i].offset
--   local length = items[i].length
--   local analysis = items[i].analysis
--   local pgs = pango.GlyphString.new()
--   pango.shape(string.sub(s,1+offset), length, analysis, pgs)
--   return pgs
--   cr:move_to(x, 50)
--   cr:show_glyph_string(analysis.font, pgs)
--   x = x + pgs:get_width()/1024
--   print(x)
-- end
