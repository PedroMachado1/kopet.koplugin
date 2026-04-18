--[[
    KoPet UI — Full-screen pet panel and dialog widgets.

    Displays the pet sprite, status bars, inventory, and action buttons.
    Optimized for E-ink: no animations, high contrast, clear layout.
]]

local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local LineWidget = require("ui/widget/linewidget")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local ButtonTable = require("ui/widget/buttontable")
local Screen = Device.screen

local _i18n = nil
local function _load_i18n()
    if _i18n then return _i18n end
    local src = debug.getinfo(1, "S").source
    if src:sub(1, 1) == "@" then src = src:sub(2) end
    local dir = src:match("(.*/)")
    if dir then
        local ok, mod = pcall(dofile, dir .. "kopet_i18n.lua")
        if ok and mod then
            _i18n = mod
            return _i18n
        end
    end
    return nil
end

local function T(key)
    local i18n = _load_i18n()
    if i18n then return i18n.T(key) end
    return key
end

local function TF(key, ...)
    local i18n = _load_i18n()
    if i18n then return i18n.TF(key, ...) end
    return string.format(key, ...)
end

local KoPetUI = {}

local function clamp(v, min_v, max_v)
    if v < min_v then return min_v end
    if v > max_v then return max_v end
    return v
end

local function shorten(text, max_len)
    if not text then return "" end
    if #text <= max_len then return text end
    return text:sub(1, max_len - 3) .. "..."
end

local function resolve_panel_mode(mode, screen_w, screen_h)
    if mode and mode ~= "auto" then
        return mode
    end
    if screen_w < 700 or screen_h < 900 then
        return "compact"
    end
    if screen_w > 1100 and screen_h > 1400 then
        return "detailed"
    end
    return "normal"
end

local function add_divider(vgroup, width)
    table.insert(vgroup, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(vgroup, LineWidget:new{
        dimen = Geom:new{ w = width, h = 1 },
        background = Blitbuffer.COLOR_DARK_GRAY,
    })
    table.insert(vgroup, VerticalSpan:new{ width = Size.span.vertical_default })
end

local function make_meter(label, value, max_value, width)
    local maxv = math.max(1, max_value or 1)
    local cur = clamp(value or 0, 0, maxv)
    local pct = math.floor((cur / maxv) * 100 + 0.5)
    local fill = math.floor(width * cur / maxv + 0.5)
    local empty = width - fill
    return string.format("%-4s [%s%s] %3d%%", label, string.rep("#", fill), string.rep("-", empty), pct)
end

local function add_text_line(vgroup, text, face, width)
    table.insert(vgroup, TextBoxWidget:new{
        text = text,
        face = face,
        width = width,
        alignment = "center",
    })
end

local function shift_lines_horiz(lines, spaces)
    local out = {}
    local pad = ""
    if spaces > 0 then
        pad = string.rep(" ", spaces)
    end
    for i, line in ipairs(lines or {}) do
        if spaces > 0 then
            out[i] = pad .. line
        elseif spaces < 0 then
            local cut = math.min(#line, -spaces)
            out[i] = string.sub(line, cut + 1)
        else
            out[i] = line
        end
    end
    return out
end

local function build_animated_sprite_text(sprite_lines, tick)
    local phase = tick % 4
    if phase == 1 then
        return table.concat(shift_lines_horiz(sprite_lines, 1), "\n")
    elseif phase == 2 then
        return table.concat(shift_lines_horiz(sprite_lines, 2), "\n")
    elseif phase == 3 then
        return table.concat(shift_lines_horiz(sprite_lines, 1), "\n")
    end
    return table.concat(sprite_lines, "\n")
end

function KoPetUI.createPanel(stats, sprite_lines, stage_name, callbacks)
    local screen_w = Screen:getWidth()
    local screen_h = Screen:getHeight()
    local mode = resolve_panel_mode(callbacks.mode, screen_w, screen_h)


    local normal_size = 16
    local sprite_size = 18
    local small_size = 14
    local title_size = 24
    local meter_width = 16
    local content_width = screen_w - 40
    local sprite_box_width = content_width - 20
    local section_gap = 6

    if mode == "compact" then
        normal_size = 14
        sprite_size = 15
        small_size = 12
        title_size = 20
        meter_width = 12
        content_width = screen_w - 26
        sprite_box_width = content_width - 14
        section_gap = 4
    elseif mode == "detailed" then
        normal_size = 18
        sprite_size = 20
        small_size = 15
        title_size = 26
        meter_width = 18
        content_width = screen_w - 52
        sprite_box_width = content_width - 24
        section_gap = 8
    end

    local face_normal = Font:getFace("infont", normal_size)
    local face_sprite = Font:getFace("infont", sprite_size)
    local face_small = Font:getFace("smallinfont", small_size)
    local face_title = Font:getFace("cfont", title_size)

    local pet_name = shorten(stats.pet_name or "KoPet", 18)
    local vgroup = VerticalGroup:new{ align = "center" }

    local title_text = pet_name
    local subtitle_text
    if stats.is_deep_sleep then
        subtitle_text = T("Deep Sleep...")
    else
        subtitle_text = string.format("%s  -  %s", stage_name, TF("Lv.%d", stats.level))
    end

    table.insert(vgroup, TextWidget:new{
        text = title_text,
        face = face_title,
        bold = true,
    })
    add_text_line(vgroup, subtitle_text, face_small, content_width)
    table.insert(vgroup, VerticalSpan:new{ width = section_gap })
    add_divider(vgroup, content_width)
    table.insert(vgroup, VerticalSpan:new{ width = section_gap })

    local animate_pet = callbacks.animate_pet == true and not stats.is_sick and not stats.is_deep_sleep
    local animation_interval = callbacks.animation_interval or 1.6
    local animation_tick = 0
    local sprite_text = table.concat(sprite_lines, "\n")
    if animate_pet then
        sprite_text = build_animated_sprite_text(sprite_lines, animation_tick)
    end

    local sprite_text_widget = TextBoxWidget:new{
        text = sprite_text,
        face = face_sprite,
        width = sprite_box_width,
        alignment = "center",
    }

    local sprite_box = FrameContainer:new{
        bordersize = 1,
        padding = Size.padding.default,
        background = Blitbuffer.COLOR_WHITE,
        sprite_text_widget,
    }
    table.insert(vgroup, sprite_box)
    table.insert(vgroup, VerticalSpan:new{ width = section_gap })

    local mood_labels = {
        happy = T("Happy"),
        idle = T("Normal"),
        hungry = T("Hungry"),
        sleeping = T("Sleeping"),
        eating = T("Eating"),
        sick = T("Sick"),
    }
    add_text_line(vgroup, TF("Mood: %s", mood_labels[stats.mood] or stats.mood), face_normal, content_width)
    if stats.is_bored or stats.is_sleepy or stats.is_sick then
        local badges = {}
        if stats.is_sick then table.insert(badges, T("SICK")) end
        if stats.is_bored then table.insert(badges, T("BORED")) end
        if stats.is_sleepy then table.insert(badges, T("SLEEPY")) end
        add_text_line(vgroup, table.concat(badges, "  |  "), face_small, content_width)
    end
    table.insert(vgroup, VerticalSpan:new{ width = section_gap })

    add_text_line(vgroup, make_meter(T("Hunger"), stats.hunger, 100, meter_width), face_small, content_width)
    table.insert(vgroup, VerticalSpan:new{ width = 2 })
    add_text_line(vgroup, make_meter(T("Happiness"), stats.happiness, 100, meter_width), face_small, content_width)
    table.insert(vgroup, VerticalSpan:new{ width = 2 })
    add_text_line(vgroup, make_meter(T("Energy"), stats.energy, 100, meter_width), face_small, content_width)
    table.insert(vgroup, VerticalSpan:new{ width = 2 })
    add_text_line(vgroup, make_meter("XP", stats.xp_progress, stats.xp_needed, meter_width), face_small, content_width)

    table.insert(vgroup, VerticalSpan:new{ width = section_gap })
    add_divider(vgroup, content_width)
    table.insert(vgroup, VerticalSpan:new{ width = section_gap })

    local inv_text = TF("Food: %d  |  Treats: %d  |  Medicine: %d  |  Cryst: %d",
        stats.food, stats.treats, stats.medicines or 0, stats.crystals)
    add_text_line(vgroup, inv_text, face_normal, content_width)

    table.insert(vgroup, VerticalSpan:new{ width = section_gap })
    add_text_line(vgroup,
        TF("Pages: %d  |  Books: %d  |  Streak: %d d  |  Age: %d d", stats.total_pages, stats.books_completed, stats.streak_days, stats.age_days),
        face_small,
        content_width)

    table.insert(vgroup, VerticalSpan:new{ width = section_gap })

    local next_level = math.max(0, (stats.xp_needed or 0) - (stats.xp_progress or 0))
    add_text_line(vgroup, TF("Total XP: %d  |  Next level: %d XP", stats.xp, next_level), face_small, content_width)

    table.insert(vgroup, VerticalSpan:new{ width = section_gap })

    local button_table = ButtonTable:new{
        width = content_width,
        buttons = {
            {
                {
                    text = TF("Feed (%d)", stats.food),
                    callback = callbacks.feed or function() end,
                },
                {
                    text = T("Pet"),
                    callback = callbacks.pet or function() end,
                },
            },
            {
                {
                    text = TF("Give Treat (%d)", stats.treats),
                    callback = callbacks.treat or function() end,
                },
                {
                    text = TF("Medicine (%d)", stats.medicines or 0),
                    callback = callbacks.medicine or function() end,
                },
            },
            {
                {
                    text = T("Close"),
                    callback = callbacks.close or function() end,
                },
            },
        },
        show_parent = callbacks.show_parent,
    }

    table.insert(vgroup, button_table)

    local content = CenterContainer:new{
        dimen = Geom:new{ w = screen_w, h = screen_h },
        vgroup,
    }

    local frame = FrameContainer:new{
        width = screen_w,
        height = screen_h,
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0,
        padding = Size.padding.large,
        content,
    }

    local widget = InputContainer:new{
        dimen = Geom:new{ w = screen_w, h = screen_h },
        frame,
    }

    if animate_pet then
        widget._kopet_anim_running = true
        widget._kopet_anim_action = function()
            if not widget._kopet_anim_running then return end
            animation_tick = animation_tick + 1
            sprite_text_widget:setText(build_animated_sprite_text(sprite_lines, animation_tick))
            UIManager:setDirty(widget, "ui", widget.dimen)
            UIManager:scheduleIn(animation_interval, widget._kopet_anim_action)
        end
        UIManager:scheduleIn(animation_interval, widget._kopet_anim_action)
    end

    if Device:hasKeys() then
        widget.key_events = {
            Close = { { "Back" }, doc = "close KoPet panel" },
        }
    end

    if Device:isTouchDevice() then
        widget.ges_events = {
            Swipe = {
                GestureRange:new{
                    ges = "swipe",
                    range = Geom:new{
                        x = 0, y = 0,
                        w = screen_w,
                        h = screen_h,
                    },
                },
            },
        }
    end

    function widget:onClose()
        self._kopet_anim_running = false
        if self._kopet_anim_action then
            UIManager:unschedule(self._kopet_anim_action)
        end
        UIManager:close(self)
        UIManager:setDirty(nil, function()
            return "full", Device.screen:getSize()
        end)
        return true
    end

    function widget:onSwipe(_, ges)
        if ges.direction == "south" or ges.direction == "east" then
            self:onClose()
            return true
        end
    end

    return widget
end

return KoPetUI
