--[[
    KoPet — Main Plugin
    A virtual pet that evolves with your reading habits.

    This is the entry point registered with KOReader.
    It handles:
    - Plugin lifecycle (init, close, suspend/resume)
    - Event hooks (page turns, book completion)
    - Menu registration
    - State persistence via G_reader_settings
    - Spawning the UI panel
]]

local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local _ = require("gettext")

-- ─────────────────────────────────────────────────────────────
-- Local module loader (resolve path relative to this plugin)
-- ─────────────────────────────────────────────────────────────
local _plugin_dir = nil

local function get_plugin_dir()
    if _plugin_dir then return _plugin_dir end
    local src = debug.getinfo(1, "S").source
    if src:sub(1, 1) == "@" then
        src = src:sub(2)
    end
    _plugin_dir = src:match("(.*/)")
    if not _plugin_dir then
        _plugin_dir = "./"
    end
    return _plugin_dir
end

local _modules = {}

local function load_local(name)
    if _modules[name] then return _modules[name] end
    local dir = get_plugin_dir()
    local path = dir .. name .. ".lua"
    local ok, mod = pcall(dofile, path)
    if ok and mod then
        _modules[name] = mod
        return mod
    else
        logger.warn("[KoPet] Failed to load module:", name, mod)
        return nil
    end
end

-- ─────────────────────────────────────────────────────────────
-- i18n helper (lazy loaded)
-- ─────────────────────────────────────────────────────────────
local function T(key)
    local i18n = load_local("kopet_i18n")
    if i18n then return i18n.T(key) end
    return key
end

local function TF(key, ...)
    local i18n = load_local("kopet_i18n")
    if i18n then return i18n.TF(key, ...) end
    return string.format(key, ...)
end

-- ─────────────────────────────────────────────────────────────
-- Settings persistence helpers
-- ─────────────────────────────────────────────────────────────
local SAVE_KEY = "kopet_state"

local function get_default_state()
    local Logic = load_local("kopet_logic")
    if Logic then
        return Logic.get_default_state()
    end
    return {
        hunger = 80, happiness = 60, energy = 100, xp = 0,
        food = 3, treats = 0, crystals = 0,
        total_pages = 0, session_pages = 0, books_completed = 0,
        streak_days = 0, last_read_date = nil, today_pages = 0,
        last_hunger_tick = os.time(), last_happiness_tick = os.time(),
        last_petting_time = 0, last_offline_time = os.time(),
        starving_since = nil, is_deep_sleep = false,
        pages_per_food = 10, book_milestones = {},
        completed_books = {}, pet_name = "KoPet", created_at = os.time(),
    }
end

local function load_state()
    local G = G_reader_settings
    if G and G:has(SAVE_KEY) then
        local saved = G:readSetting(SAVE_KEY)
        if saved and type(saved) == "table" then
            local defaults = get_default_state()
            for k, v in pairs(defaults) do
                if saved[k] == nil then
                    saved[k] = v
                end
            end
            return saved
        end
    end
    return get_default_state()
end

local function save_state(state)
    local G = G_reader_settings
    if G then
        G:saveSetting(SAVE_KEY, state)
        G:flush()
    end
end

-- ─────────────────────────────────────────────────────────────
-- Notification helper
-- ─────────────────────────────────────────────────────────────
local function notify(msg, duration)
    pcall(function()
        UIManager:show(InfoMessage:new{
            text = tostring(msg),
            timeout = duration or 2,
        })
    end)
end

-- Translate an event message (the message is an English key/template)
local function translate_message(msg)
    local i18n = load_local("kopet_i18n")
    if not i18n then return msg end

    -- Try direct lookup first
    local translated = i18n.T(msg)
    if translated ~= msg then return translated end

    -- For messages with embedded values like "Level 5!", extract the template
    -- Match patterns: "Level %d!" etc.
    local patterns = {
        { pattern = "^Level (%d+)!$", key = "Level %d!" },
        { pattern = "^Food %+1! %(Total: (%d+)%)$", key = "Food +1! (Total: %d)" },
        { pattern = "^Rare Treat! %((%d+)%% of book%)$", key = "Rare Treat! (%d%% of book)" },
        { pattern = "^Streak lost! %((%d+) days%)$", key = "Streak lost! (%d days)" },
        { pattern = "^Streak: (%d+) days!$", key = "Streak: %d days!" },
        { pattern = "^Fed! Hunger: (%d+)%%$", key = "Fed! Hunger: %d%%" },
        { pattern = "^Petted! Happiness: (%d+)%%$", key = "Petted! Happiness: %d%%" },
        { pattern = "^Wait (%d+) min to pet again%.$", key = "Wait %d min to pet again." },
        { pattern = "^Your pet is hungry! %((%d+)%%%)$", key = "Your pet is hungry! (%d%%)" },
        { pattern = "^Treat given! Hunger: (%d+)%% | Happiness: (%d+)%%$", key = "Treat given! Hunger: %d%% | Happiness: %d%%" },
    }

    for _, p in ipairs(patterns) do
        local captures = { msg:match(p.pattern) }
        if #captures > 0 then
            local tmpl = i18n.T(p.key)
            local nums = {}
            for _, c in ipairs(captures) do
                table.insert(nums, tonumber(c))
            end
            return string.format(tmpl, unpack(nums))
        end
    end

    return msg
end

-- ═══════════════════════════════════════════════════════════════
-- KoPet Plugin Class
-- ═══════════════════════════════════════════════════════════════
local KoPet = WidgetContainer:extend{
    name = "kopet",
    fullname = _("KoPet"),
    is_doc_only = false,
    _state = nil,
    _last_page = nil,
    _panel_widget = nil,
    _decay_scheduled = false,
    _suppress_notifications = false,
    _last_notify_time = 0,
    _notify_cooldown = 30,
}

-- ─────────────────────────────────────────────────────────────
-- Init
-- ─────────────────────────────────────────────────────────────
function KoPet:init()
    self._state = load_state()
    self._suppress_notifications = true

    local Logic = load_local("kopet_logic")
    if Logic then
        local events
        self._state, events = Logic.update_time_decay(self._state)
        save_state(self._state)
    end

    self._suppress_notifications = false

    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    else
        logger.warn("[KoPet] ui.menu not available in init, scheduling retry")
        UIManager:scheduleIn(1, function()
            if self.ui and self.ui.menu then
                self.ui.menu:registerToMainMenu(self)
            end
        end)
    end

    self:_schedule_decay()
end

-- ─────────────────────────────────────────────────────────────
-- Menu
-- ─────────────────────────────────────────────────────────────
function KoPet:addToMainMenu(menu_items)
    menu_items.kopet = {
        text = _("KoPet"),
        sorting_hint = "tools",
        sub_item_table = {
            {
                text_func = function() return T("View Pet") end,
                keep_menu_open = false,
                callback = function()
                    self:_show_panel()
                end,
            },
            {
                text_func = function() return T("Feed") end,
                keep_menu_open = true,
                callback = function()
                    self:_action_feed()
                end,
            },
            {
                text_func = function() return T("Pet") end,
                keep_menu_open = true,
                callback = function()
                    self:_action_pet()
                end,
            },
            {
                text_func = function() return T("Give Treat") end,
                keep_menu_open = true,
                callback = function()
                    self:_action_treat()
                end,
            },
            {
                text_func = function() return T("Give Medicine") end,
                keep_menu_open = true,
                callback = function()
                    self:_action_medicine()
                end,
            },
            {
                text_func = function() return T("Journal") end,
                keep_menu_open = false,
                callback = function()
                    local entries = {}
                    if self._state.journal and #self._state.journal > 0 then
                        for i = #self._state.journal, 1, -1 do
                            local e = self._state.journal[i]
                            table.insert(entries, os.date("%Y-%m-%d: ", e.date) .. e.text)
                        end
                    else
                        table.insert(entries, T("No journal entries yet."))
                    end
                    local InfoMessage = require("ui/widget/infomessage")
                    UIManager:show(InfoMessage:new{
                        text = table.concat(entries, "\n\n"),
                    })
                end,
            },
            {
                text_func = function() return T("Accessories") end,
                sub_item_table_func = function()
                    local items = {}
                    if not self._state.accessories or #self._state.accessories == 0 then
                        table.insert(items, {
                            text_func = function() return T("No accessories found yet.") end,
                            callback = function() end,
                        })
                        return items
                    end

                    -- Unequip option
                    table.insert(items, {
                        text_func = function() return T("Unequip Accessory") end,
                        checked_func = function() return self._state.equipped_accessory == nil end,
                        callback = function()
                            self._state.equipped_accessory = nil
                            save_state(self._state)
                            notify(T("Unequipped"))
                        end,
                    })

                    -- Equip options
                    for _, acc in ipairs(self._state.accessories) do
                        table.insert(items, {
                            text_func = function() return acc end,
                            checked_func = function() return self._state.equipped_accessory == acc end,
                            callback = function()
                                self._state.equipped_accessory = acc
                                save_state(self._state)
                                notify(TF("Equipped: %s", acc))
                            end,
                        })
                    end
                    return items
                end,
            },
            {
                text_func = function() return T("Statistics") end,
                keep_menu_open = true,
                callback = function()
                    self:_show_stats()
                end,
            },
            {
                text_func = function()
                    local d = self._state.difficulty or "normal"
                    local displays = { easy = T("Easy (3-7 pgs)"), normal = T("Normal (10-15 pgs)"), hard = T("Hard (20-30 pgs)") }
                    return TF("Difficulty: %s", displays[d] or displays.normal)
                end,
                sub_item_table = {
                    {
                        text_func = function() return T("Easy (3-7 pgs)") end,
                        checked_func = function() return self._state.difficulty == "easy" end,
                        callback = function()
                            self._state.difficulty = "easy"
                            save_state(self._state)
                            notify(TF("Set to: %s", T("Easy (3-7 pgs)")))
                        end,
                    },
                    {
                        text_func = function() return T("Normal (10-15 pgs)") end,
                        checked_func = function() return (self._state.difficulty or "normal") == "normal" end,
                        callback = function()
                            self._state.difficulty = "normal"
                            save_state(self._state)
                            notify(TF("Set to: %s", T("Normal (10-15 pgs)")))
                        end,
                    },
                    {
                        text_func = function() return T("Hard (20-30 pgs)") end,
                        checked_func = function() return self._state.difficulty == "hard" end,
                        callback = function()
                            self._state.difficulty = "hard"
                            save_state(self._state)
                            notify(TF("Set to: %s", T("Hard (20-30 pgs)")))
                        end,
                    },
                },
            },

            {
                text_func = function() return T("Rename Pet") end,
                keep_menu_open = true,
                callback = function()
                    self:_rename_pet()
                end,
            },
            {
                text_func = function() return T("Reset Pet") end,
                keep_menu_open = true,
                callback = function()
                    self:_confirm_reset()
                end,
            },
        },
    }
end

-- ─────────────────────────────────────────────────────────────
-- Event Hooks from KOReader
-- ─────────────────────────────────────────────────────────────
function KoPet:onPageUpdate(pageno)
    if not pageno then return end
    if self._last_page == pageno then return end
    self._last_page = pageno

    local Logic = load_local("kopet_logic")
    if not Logic then return end

    local all_events = {}

    local events
    self._state, events = Logic.on_page_read(self._state)
    if events then
        for _, e in ipairs(events) do table.insert(all_events, e) end
    end

    if self.ui and self.ui.document then
        local total = nil
        if self.ui.document.getPageCount then
            total = self.ui.document:getPageCount()
        end
        if total and total > 0 and self.ui.document.file then
            local progress_pct = math.floor((pageno / total) * 100)
            local m_events
            self._state, m_events = Logic.check_book_milestone(
                self._state,
                self.ui.document.file,
                progress_pct
            )
            if m_events then
                for _, e in ipairs(m_events) do table.insert(all_events, e) end
            end
        end
    end

    local s_events
    self._state, s_events = Logic.check_streak(self._state)
    if s_events then
        for _, e in ipairs(s_events) do table.insert(all_events, e) end
    end

    if #all_events > 0 then
        self:_process_events_batched(all_events)
    end

    if self._state.total_pages % 5 == 0 then
        save_state(self._state)
    end
end

function KoPet:onEndOfBook()
    local Logic = load_local("kopet_logic")
    if not Logic then return false end

    local book_path = nil
    if self.ui and self.ui.document and self.ui.document.file then
        book_path = self.ui.document.file
    end

    local events
    self._state, events = Logic.on_book_finished(self._state, book_path)
    self:_process_events(events)
    save_state(self._state)
    return false
end

-- ─────────────────────────────────────────────────────────────
-- Lifecycle Events
-- ─────────────────────────────────────────────────────────────
function KoPet:onSuspend()
    if self._state then
        self._state.last_offline_time = os.time()
        save_state(self._state)
    end
    return false
end

function KoPet:onResume()
    local Logic = load_local("kopet_logic")
    if Logic and self._state then
        local events
        self._state, events = Logic.update_time_decay(self._state)
        self:_process_events(events)
        save_state(self._state)
    end
    self:_schedule_decay()
    return false
end

function KoPet:onClose()
    if self._state then
        self._state.last_offline_time = os.time()
        self._state.session_pages = 0
        save_state(self._state)
    end
    return false
end

function KoPet:onCloseDocument()
    if self._state then
        save_state(self._state)
    end
    self._last_page = nil
    return false
end

-- ─────────────────────────────────────────────────────────────
-- Actions
-- ─────────────────────────────────────────────────────────────
function KoPet:_action_feed()
    local Logic = load_local("kopet_logic")
    if not Logic then return end
    local events
    self._state, events = Logic.feed(self._state)
    self:_process_events(events)
    save_state(self._state)
end

function KoPet:_action_medicine()
    local Logic = load_local("kopet_logic")
    if not Logic then return end
    local events
    self._state, events = Logic.feed_medicine(self._state)
    self:_process_events(events)
    save_state(self._state)
end

function KoPet:_action_pet()
    local Logic = load_local("kopet_logic")
    if not Logic then return end
    local events
    self._state, events = Logic.pet(self._state)
    self:_process_events(events)
    save_state(self._state)
end

function KoPet:_action_treat()
    local Logic = load_local("kopet_logic")
    if not Logic then return end
    local events
    self._state, events = Logic.feed_treat(self._state)
    self:_process_events(events)
    save_state(self._state)
end

-- ─────────────────────────────────────────────────────────────
-- UI: Show Full Panel
-- ─────────────────────────────────────────────────────────────
function KoPet:_show_panel()
    local Logic = load_local("kopet_logic")
    local Sprites = load_local("kopet_sprites")
    local PetUI = load_local("kopet_ui")

    if not Logic or not Sprites or not PetUI then
        notify(T("Error: KoPet modules failed to load."), 3)
        return
    end

    local events
    self._state, events = Logic.update_time_decay(self._state)
    self:_process_events(events)

    local stats = Logic.get_stats_summary(self._state)
    local stage = Sprites.get_stage(stats.level, self._state.evolution_path)
    local raw_lines = Sprites.get_sprite(stats.level, stats.mood, self._state.evolution_path)

    local sprite_lines = Sprites.apply_compositing(raw_lines, self._state.equipped_accessory)

    local panel_ref = nil

    local function refresh_panel()
        if panel_ref then
            UIManager:close(panel_ref)
        end
        self:_show_panel()
    end

    local panel = PetUI.createPanel(stats, sprite_lines, T(stage.name), {
        feed = function()
            self:_action_feed()
            refresh_panel()
        end,
        pet = function()
            self:_action_pet()
            refresh_panel()
        end,
        treat = function()
            self:_action_treat()
            refresh_panel()
        end,
        medicine = function()
            self:_action_medicine()
            refresh_panel()
        end,
        close = function()
            if panel_ref then
                UIManager:close(panel_ref)
                local Device = require("device")
                UIManager:setDirty(nil, function()
                    return "full", Device.screen:getSize()
                end)
            end
        end,
        show_parent = self,
    })

    panel_ref = panel
    UIManager:show(panel)
end

-- ─────────────────────────────────────────────────────────────
-- UI: Show Stats Dialog
-- ─────────────────────────────────────────────────────────────
function KoPet:_show_stats()
    local Logic = load_local("kopet_logic")
    local Sprites = load_local("kopet_sprites")

    if not Logic or not Sprites then
        notify(T("Error loading statistics."), 3)
        return
    end

    local stats = Logic.get_stats_summary(self._state)
    local stage = Sprites.get_stage(stats.level)
    local mini = Sprites.get_mini(stats.mood)
    local pet_name = stats.pet_name or "KoPet"

    local lines = {
        string.format("%s %s  %s", pet_name, mini, T(stage.name)),
        "",
        TF("Level: %d", stats.level),
        TF("XP: %d / %d (next level)", stats.xp_progress, stats.xp_needed),
        TF("Total XP: %d", stats.xp),
        "",
        TF("Hunger: %d%%", stats.hunger),
        TF("Happiness: %d%%", stats.happiness),
        TF("Energy: %d%%", stats.energy),
        "",
        TF("Food: %d", stats.food),
        TF("Treats: %d", stats.treats),
        TF("Crystals: %d", stats.crystals),
        "",
        TF("Pages read: %d", stats.total_pages),
        TF("Books completed: %d", stats.books_completed),
        TF("Streak: %d days", stats.streak_days),
        TF("Pet age: %d days", stats.age_days),
    }

    UIManager:show(InfoMessage:new{
        text = table.concat(lines, "\n"),
    })
end

-- ─────────────────────────────────────────────────────────────
-- UI: Rename Pet
-- ─────────────────────────────────────────────────────────────
function KoPet:_rename_pet()
    local InputDialog = require("ui/widget/inputdialog")
    local pet_name = self._state.pet_name or "KoPet"

    local input_dialog
    input_dialog = InputDialog:new{
        title = T("Rename Pet"),
        input = pet_name,
        input_hint = T("Enter a name for your pet:"),
        buttons = {
            {
                {
                    text = T("Cancel"),
                    id = "close",
                    callback = function()
                        UIManager:close(input_dialog)
                    end,
                },
                {
                    text = T("Save"),
                    is_enter_default = true,
                    callback = function()
                        local new_name = input_dialog:getInputText()
                        if new_name and new_name ~= "" then
                            new_name = new_name:match("^%s*(.-)%s*$")  -- trim
                            if new_name ~= "" then
                                self._state.pet_name = new_name
                                save_state(self._state)
                                notify(TF("Pet renamed to: %s", new_name), 2)
                            end
                        end
                        UIManager:close(input_dialog)
                    end,
                },
            },
        },
    }
    UIManager:show(input_dialog)
    input_dialog:onShowKeyboard()
end

-- ─────────────────────────────────────────────────────────────
-- UI: Confirm Reset
-- ─────────────────────────────────────────────────────────────
function KoPet:_confirm_reset()
    local ConfirmBox = require("ui/widget/confirmbox")
    UIManager:show(ConfirmBox:new{
        text = T("Are you sure you want to reset KoPet?\n\nAll progress will be lost!"),
        ok_text = T("Reset"),
        cancel_text = T("Cancel"),
        ok_callback = function()
            self._state = get_default_state()
            save_state(self._state)
            notify(T("KoPet reset! New pet created."), 3)
        end,
    })
end

-- ─────────────────────────────────────────────────────────────
-- Process game events — for direct actions (feed, pet, treat)
-- ─────────────────────────────────────────────────────────────
function KoPet:_process_events(events)
    if self._suppress_notifications then return end
    if not events or #events == 0 then return end

    local Sprites = load_local("kopet_sprites")
    local Logic = load_local("kopet_logic")
    local mini = "(o.o)"
    if Logic and Sprites then
        mini = Sprites.get_mini(Logic.get_mood(self._state))
    end
    local pet_name = self._state.pet_name or "KoPet"
    local prefix = pet_name .. " " .. mini .. " "

    local event = events[1]
    if event then
        local msg = prefix .. translate_message(event.message)
        if event.type == "level_up" and Sprites then
            local stage = Sprites.get_stage(event.level)
            msg = msg .. "\n" .. T(stage.name) .. "!"
        end
        notify(msg, 3)
    end
end

-- ─────────────────────────────────────────────────────────────
-- Process events batched — for page turns (rate-limited)
-- ─────────────────────────────────────────────────────────────
function KoPet:_process_events_batched(events)
    if self._suppress_notifications then return end
    if not events or #events == 0 then return end

    local important = {}
    local routine = {}

    for _, event in ipairs(events) do
        if event.type == "level_up" or event.type == "treat_earned" or
           event.type == "crystal_earned" or event.type == "streak" or
           event.type == "streak_lost" or event.type == "deep_sleep" or
           event.type == "starving" or event.type == "revived" then
            table.insert(important, event)
        else
            table.insert(routine, event)
        end
    end

    local pet_name = self._state.pet_name or "KoPet"

    if #important > 0 then
        local Sprites = load_local("kopet_sprites")
        local Logic = load_local("kopet_logic")
        local mini = "(o.o)"
        if Logic and Sprites then
            mini = Sprites.get_mini(Logic.get_mood(self._state))
        end

        local lines = {}
        for _, event in ipairs(important) do
            local msg = translate_message(event.message)
            if event.type == "level_up" and Sprites then
                local stage = Sprites.get_stage(event.level)
                msg = msg .. " " .. T(stage.name) .. "!"
            end
            table.insert(lines, msg)
        end
        notify(pet_name .. " " .. mini .. " " .. table.concat(lines, "\n"), 4)
        self._last_notify_time = os.time()
        return
    end

    local now = os.time()
    if (now - self._last_notify_time) < self._notify_cooldown then
        return
    end

    if #routine > 0 then
        local Sprites = load_local("kopet_sprites")
        local Logic = load_local("kopet_logic")
        local mini = "(o.o)"
        if Logic and Sprites then
            mini = Sprites.get_mini(Logic.get_mood(self._state))
        end
        notify(pet_name .. " " .. mini .. " " .. translate_message(routine[1].message), 2)
        self._last_notify_time = now
    end
end

-- ─────────────────────────────────────────────────────────────
-- Periodic decay timer
-- ─────────────────────────────────────────────────────────────
function KoPet:_schedule_decay()
    if self._decay_scheduled then return end
    self._decay_scheduled = true

    UIManager:scheduleIn(300, function()
        self._decay_scheduled = false

        local Logic = load_local("kopet_logic")
        if Logic and self._state then
            local events
            self._state, events = Logic.update_time_decay(self._state)
            self:_process_events(events)
            save_state(self._state)
        end

        self:_schedule_decay()
    end)
end

return KoPet
