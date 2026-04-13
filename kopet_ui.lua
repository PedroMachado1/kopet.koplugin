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

-- ─────────────────────────────────────────────────────────────
-- i18n helper (same lazy-load approach as main.lua)
-- ─────────────────────────────────────────────────────────────
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

--------------------------------------------------------------------------------
-- Progress Bar (text-based for E-ink compatibility)
--------------------------------------------------------------------------------
local function make_bar_text(label, value, max_value)
    local pct = math.floor((value / max_value) * 100 + 0.5)
    local bar_len = 20
    local filled = math.floor(bar_len * value / max_value + 0.5)
    local empty = bar_len - filled

    local bar = string.rep("#", filled) .. string.rep("-", empty)
    return string.format("%-12s [%s] %d%%", label, bar, pct)
end

--------------------------------------------------------------------------------
-- XP Progress Bar
--------------------------------------------------------------------------------
local function make_xp_bar(xp_progress, xp_needed, level)
    local pct = 0
    if xp_needed > 0 then
        pct = math.floor((xp_progress / xp_needed) * 100 + 0.5)
    end
    local bar_len = 20
    local filled = 0
    if xp_needed > 0 then
        filled = math.floor(bar_len * xp_progress / xp_needed + 0.5)
    end
    local empty = bar_len - filled
    local bar = string.rep("#", filled) .. string.rep("-", empty)
    return string.format("%-12s [%s] %d%%", T("Level") .. " " .. level, bar, pct)
end

--------------------------------------------------------------------------------
-- Full Panel Widget
--------------------------------------------------------------------------------
function KoPetUI.createPanel(stats, sprite_lines, stage_name, callbacks)
    local screen_w = Screen:getWidth()
    local screen_h = Screen:getHeight()

    local face_normal = Font:getFace("cfont", 16)
    local face_sprite = Font:getFace("cfont", 18)
    local face_small = Font:getFace("cfont", 14)
    local face_title = Font:getFace("cfont", 22)

    local pet_name = stats.pet_name or "KoPet"
    local vgroup = VerticalGroup:new{ align = "center" }

    -- ═══════════════════════════════════════════
    -- Title
    -- ═══════════════════════════════════════════
    local title_text
    if stats.is_sick then
        title_text = pet_name .. " - " .. T("Sick")
    else
        title_text = string.format("%s - %s (%s)", pet_name, stage_name, TF("Lv.%d", stats.level))
    end

    table.insert(vgroup, TextWidget:new{
        text = title_text,
        face = face_title,
        bold = true,
    })

    table.insert(vgroup, VerticalSpan:new{ width = Size.span.vertical_default })

    -- ═══════════════════════════════════════════
    -- Separator
    -- ═══════════════════════════════════════════
    table.insert(vgroup, LineWidget:new{
        dimen = Geom:new{ w = screen_w - 40, h = 2 },
        background = Blitbuffer.COLOR_BLACK,
    })
    table.insert(vgroup, VerticalSpan:new{ width = Size.span.vertical_default })

    -- ═══════════════════════════════════════════
    -- Pet Sprite
    -- ═══════════════════════════════════════════
    local sprite_text = table.concat(sprite_lines, "\n")
    table.insert(vgroup, TextBoxWidget:new{
        text = sprite_text,
        face = face_sprite,
        width = screen_w - 60,
        alignment = "center",
    })

    table.insert(vgroup, VerticalSpan:new{ width = Size.span.vertical_default })

    -- ═══════════════════════════════════════════
    -- Mood indicator
    -- ═══════════════════════════════════════════
    local mood_labels = {
        happy = T("Happy"),
        idle = T("Normal"),
        hungry = T("Hungry"),
        sleeping = T("Sleeping"),
        eating = T("Eating"),
        sick = T("Sick"),
    }
    local mood_text = TF("Mood: %s", mood_labels[stats.mood] or stats.mood)
    table.insert(vgroup, TextWidget:new{
        text = mood_text,
        face = face_normal,
    })

    table.insert(vgroup, VerticalSpan:new{ width = Size.span.vertical_default })

    -- ═══════════════════════════════════════════
    -- Status Bars
    -- ═══════════════════════════════════════════
    table.insert(vgroup, LineWidget:new{
        dimen = Geom:new{ w = screen_w - 40, h = 1 },
        background = Blitbuffer.COLOR_DARK_GRAY,
    })
    table.insert(vgroup, VerticalSpan:new{ width = Size.span.vertical_default })

    local bars = {
        make_bar_text(T("Hunger"), stats.hunger, 100),
        make_bar_text(T("Happiness"), stats.happiness, 100),
        make_bar_text(T("Energy"), stats.energy, 100),
        make_xp_bar(stats.xp_progress, stats.xp_needed, stats.level),
    }

    for _, bar in ipairs(bars) do
        table.insert(vgroup, TextWidget:new{
            text = bar,
            face = face_small,
        })
        table.insert(vgroup, VerticalSpan:new{ width = 2 })
    end

    table.insert(vgroup, VerticalSpan:new{ width = Size.span.vertical_default })

    -- ═══════════════════════════════════════════
    -- Inventory
    -- ═══════════════════════════════════════════
    table.insert(vgroup, LineWidget:new{
        dimen = Geom:new{ w = screen_w - 40, h = 1 },
        background = Blitbuffer.COLOR_DARK_GRAY,
    })
    table.insert(vgroup, VerticalSpan:new{ width = Size.span.vertical_default })

    local inv_text = TF("Food: %d  |  Treats: %d  |  Medicine: %d  |  Cryst: %d",
        stats.food, stats.treats, stats.medicines or 0, stats.crystals)
    table.insert(vgroup, TextWidget:new{
        text = inv_text,
        face = face_normal,
    })

    table.insert(vgroup, VerticalSpan:new{ width = Size.span.vertical_default })

    -- ═══════════════════════════════════════════
    -- Reading Stats
    -- ═══════════════════════════════════════════
    local stats_text = TF("Pages: %d  |  Books: %d  |  Streak: %d d  |  Age: %d d",
        stats.total_pages, stats.books_completed, stats.streak_days, stats.age_days)
    table.insert(vgroup, TextWidget:new{
        text = stats_text,
        face = face_small,
    })

    table.insert(vgroup, VerticalSpan:new{ width = Size.span.vertical_default })

    -- XP detail
    local xp_detail = TF("Total XP: %d  |  Next level: %d XP", stats.xp, stats.xp_needed - stats.xp_progress)
    table.insert(vgroup, TextWidget:new{
        text = xp_detail,
        face = face_small,
    })

    table.insert(vgroup, VerticalSpan:new{ width = Size.span.vertical_default })

    -- ═══════════════════════════════════════════
    -- Action Buttons
    -- ═══════════════════════════════════════════
    local button_table = ButtonTable:new{
        width = screen_w - 40,
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

    -- ═══════════════════════════════════════════
    -- Build final container
    -- ═══════════════════════════════════════════
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

    -- Close on back gesture / key
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
        UIManager:close(self)
        -- Force full screen refresh on E-ink
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
