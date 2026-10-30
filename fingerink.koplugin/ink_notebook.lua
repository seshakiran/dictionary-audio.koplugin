-- Portable, offline notebook: typed notes plus SVG handwriting, without book text.
local Notebook = {}
local Colors=require("ink_colors")

local function escape(s)
    return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;")
        :gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&#39;"))
end

function Notebook.pages(store, notes)
    local seen, pages = {}, {}
    for _, page in ipairs(store:pageList()) do seen[page] = true end
    for page, note in pairs(notes) do
        if note ~= "" then seen[page] = true end
    end
    for page in pairs(seen) do pages[#pages + 1] = page end
    table.sort(pages)
    return pages
end

function Notebook.html(book, store, notes)
    local out = {
        '<!doctype html><html lang="en"><meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width,initial-scale=1">',
        '<title>' .. escape(book) .. ' — notebook</title>',
        '<style>body{max-width:55rem;margin:2rem auto;padding:1rem;font-family:system-ui}',
        'svg{width:100%;max-height:80vh;border:1px solid #aaa}pre{white-space:pre-wrap}',
        'section{break-inside:avoid;margin:2rem 0}</style>',
        '<h1>' .. escape(book) .. '</h1>',
        '<p>PageScribe notebook. Drawings are page overlays; book text and native KOReader highlights are not included.</p>',
    }
    for _, page in ipairs(Notebook.pages(store, notes)) do
        local list = store:get(page) or {}
        out[#out + 1] = '<section><h2>Page ' .. page .. '</h2><pre>' .. escape(notes[page] or "") .. '</pre>'
        -- Separate canvases for different saved screen sizes; do not distort older ink.
        local groups, order = {}, {}
        for _, s in ipairs(list) do
            local width, height = s.sw or 1000, s.sh or 1400
            local key = width .. "x" .. height
            if not groups[key] then
                groups[key] = { width = width, height = height }
                order[#order + 1] = key
            end
            groups[key][#groups[key] + 1] = s
        end
        for _, key in ipairs(order) do
            local group = groups[key]
            out[#out + 1] = string.format('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %g %g" role="img" aria-label="Handwriting on page %d">', group.width, group.height, page)
            for _, s in ipairs(group) do
                local points = {}
                for i = 1, s.n * 2, 2 do points[#points + 1] = string.format('%g,%g', s[i], s[i + 1]) end
                local color = s.color and Colors.hex(s.color,s.tool=="highlight" and "yellow" or "black")
                    or (s.tool == "highlight" and '#d5aa00' or 'black')
                local opacity = s.tool == "highlight" and '0.25' or '1'
                if s.n == 1 then
                    out[#out + 1] = string.format('<circle cx="%g" cy="%g" r="%g" fill="%s" opacity="%s"/>', s[1], s[2], s.w / 2, color, opacity)
                else
                    out[#out + 1] = string.format('<polyline points="%s" fill="none" stroke="%s" stroke-width="%g" stroke-linecap="round" stroke-linejoin="round" opacity="%s"/>', table.concat(points, ' '), color, s.w, opacity)
                end
            end
            out[#out + 1] = '</svg>'
        end
        out[#out + 1] = '</section>'
    end
    out[#out + 1] = '</html>'
    return table.concat(out, '\n')
end

function Notebook.export(path, book, store, notes)
    local content = Notebook.html(book, store, notes)
    local temporary = path .. '.tmp'
    local file, err = io.open(temporary, 'wb')
    if not file then return nil, err end
    local written, write_err = file:write(content)
    local closed, close_err = file:close()
    if not written or not closed then
        os.remove(temporary)
        return nil, write_err or close_err
    end
    local ok, rename_err = os.rename(temporary, path)
    if not ok then os.remove(temporary) end
    return ok, rename_err
end

return Notebook
