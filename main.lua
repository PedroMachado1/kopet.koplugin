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
local Dispatcher = require("dispatcher")
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

local function copy_table(tbl)
    local out = {}
    for k, v in pairs(tbl or {}) do
        if type(v) == "table" then
            out[k] = copy_table(v)
        else
            out[k] = v
        end
    end
    return out
end

local function merge_missing(dst, defaults)
    for k, v in pairs(defaults or {}) do
        if dst[k] == nil then
            if type(v) == "table" then
                dst[k] = copy_table(v)
            else
                dst[k] = v
            end
        elseif type(v) == "table" and type(dst[k]) == "table" then
            merge_missing(dst[k], v)
        end
    end
end

local function append_events(target, src)
    if not src then return end
    for _, e in ipairs(src) do
        table.insert(target, e)
    end
end

local function panel_mode_label(mode)
    if mode == "compact" then return T("Compact") end
    if mode == "normal" then return T("Normal") end
    if mode == "detailed" then return T("Detailed") end
    return T("Auto")
end

local function notifications_label(mode)
    if mode == "quiet" then return T("Quiet") end
    if mode == "verbose" then return T("Verbose") end
    return T("Normal")
end

local function animation_label(enabled)
    return enabled and T("On") or T("Off")
end

local function cycle_value(current, ordered)
    local idx = 1
    for i, v in ipairs(ordered) do
        if v == current then
            idx = i
            break
        end
    end
    return ordered[(idx % #ordered) + 1]
end

local function difficulty_label(key)
    local displays = {
        easy = T("Easy (3-7 pgs)"),
        normal = T("Normal (10-15 pgs)"),
        hard = T("Hard (20-30 pgs)"),
    }
    return displays[key or "normal"] or displays.normal
end

local function show_journal(self)
    local entries = {}
    if self._state.journal and #self._state.journal > 0 then
        for i = #self._state.journal, 1, -1 do
            local e = self._state.journal[i]
            table.insert(entries, os.date("%Y-%m-%d: ", e.date) .. e.text)
        end
    else
        table.insert(entries, T("No journal entries yet."))
    end
    UIManager:show(InfoMessage:new{
        text = table.concat(entries, "\n\n"),
    })
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
        state_version = 2,
        hunger = 80, happiness = 60, energy = 100, xp = 0,
        food = 3, treats = 0, crystals = 0, medicines = 0,
        total_pages = 0, session_pages = 0, books_completed = 0,
        streak_days = 0, last_read_date = nil, today_pages = 0,
        last_hunger_tick = os.time(), last_happiness_tick = os.time(),
        last_petting_time = 0, last_offline_time = os.time(), last_page_time = os.time(),
        starving_since = nil, is_deep_sleep = false, is_sick = false, pages_sick = 0,
        pages_per_food = 10, book_milestones = {},
        completed_books = {}, pet_name = "KoPet", created_at = os.time(),
        accessories = {}, equipped_accessory = nil,
        difficulty = "normal",
        evolution_path = "normal",
        reading_habits = {
            night_pages = 0,
            day_pages = 0,
            total_read_time = 0,
            read_pages_count = 0,
        },
        journal = {},
        config = {
            panel_mode = "detailed",
            notifications = "normal",
            routine_notify_cooldown = 30,
            pet_animation = true,
            pet_animation_interval = 1.6,
        },
    }
end

local function load_state()
    local defaults = get_default_state()
    local state = {}

    local G = G_reader_settings
    if G and G:has(SAVE_KEY) then
        local saved = G:readSetting(SAVE_KEY)
        if saved and type(saved) == "table" then
            state = saved
        end
    end

    merge_missing(state, defaults)

    local Migrations = load_local("kopet_migrations")
    if Migrations then
        state = Migrations.migrate(state, defaults)
    end

    local Config = load_local("kopet_config")
    if Config then
        state.config = Config.merge(state.config)
    end

    return state
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

local function render_event_message(event)
    if not event then return "" end

    local key = event.key or event.message or ""
    local payload = event.payload or {}

    if key == "event.level_up" then
        return TF("Level %d!", payload.level or event.level or 0)
    elseif key == "event.food_earned" then
        return TF("Food +1! (Total: %d)", payload.total_food or 0)
    elseif key == "event.treat_earned" then
        return TF("Rare Treat! (%d%% of book)", payload.milestone or 0)
    elseif key == "event.streak_lost" then
        return TF("Streak lost! (%d days)", payload.days or 0)
    elseif key == "event.streak" then
        return TF("Streak: %d days!", payload.days or 0)
    elseif key == "event.fed" then
        return TF("Fed! Hunger: %d%%", payload.hunger or 0)
    elseif key == "event.treat_used" then
        return TF("Treat given! Hunger: %d%% | Happiness: %d%%", payload.hunger or 0, payload.happiness or 0)
    elseif key == "event.cooldown" then
        return TF("Wait %d min to pet again.", payload.mins or 0)
    elseif key == "event.petted" then
        return TF("Petted! Happiness: %d%%", payload.happiness or 0)
    elseif key == "event.hungry_warning" then
        return TF("Your pet is hungry! (%d%%)", payload.hunger or 0)
    elseif key == "event.medicine_found" then
        return T("Found Medicine!")
    elseif key == "event.no_medicine" then
        return T("No medicine! Keep reading while sick to find some.")
    elseif key == "event.cured" then
        return T("Cured! Your pet is healthy again.")
    elseif key == "event.not_sick" then
        return T("Your pet is healthy! No need for medicine.")
    elseif key == "event.is_sick" then
        return T("Your pet is sick and cannot eat. Needs Medicine!")
    elseif key == "event.became_sick" then
        return T("Your pet became sick from starvation!")
    elseif key == "event.pet_sick" then
        return T("Your pet is sick...")
    elseif key == "event.accessory_found" then
        return TF("Found accessory: %s", tostring(payload.accessory or "?"))
    elseif key == "event.bored" then
        return T("Your pet looks bored. Give it some attention.")
    elseif key == "event.sleepy" then
        return T("Your pet is sleepy. Let it rest a bit.")
    elseif key == "event.rested" then
        return T("Your pet feels rested again.")
    end

    local translated = T(key)
    if translated ~= key then
        return translated
    end
    if event.message then
        return event.message
    end
    return tostring(key)
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
    self:onDispatcherRegisterActions()

    self._state = load_state()
    self._notify_cooldown = (self._state.config and self._state.config.routine_notify_cooldown) or self._notify_cooldown
    self._suppress_notifications = true

    local Logic = load_local("kopet_logic")
    if Logic then
        local all_events = {}
        local events
        self._state, events = Logic.update_time_decay(self._state)
        append_events(all_events, events)

        self:_process_events(all_events)
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

function KoPet:onDispatcherRegisterActions()
    Dispatcher:registerAction("kopet_show_panel", {
        category = "none",
        event = "KoPetShowPanel",
        title = _("KoPet: View Pet"),
        general = true,
    })
end

function KoPet:onKoPetShowPanel()
    self:_show_panel()
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
                    self._state.last_quick_action = "view_pet"
                    save_state(self._state)
                    self:_show_panel()
                end,
            },
            {
                text_func = function() return T("Quick Action") end,
                keep_menu_open = false,
                callback = function()
                    local action = self._state.last_quick_action or "view_pet"
                    if action == "feed" then
                        self:_action_feed()
                    elseif action == "pet" then
                        self:_action_pet()
                    elseif action == "treat" then
                        self:_action_treat()
                    elseif action == "medicine" then
                        self:_action_medicine()
                    elseif action == "stats" then
                        self:_show_stats()
                    elseif action == "journal" then
                        show_journal(self)
                    else
                        self:_show_panel()
                    end
                end,
            },
            {
                text_func = function() return T("Care") end,
                sub_item_table = {
                    {
                        text_func = function() return T("Feed") end,
                        keep_menu_open = true,
                        callback = function()
                            self._state.last_quick_action = "feed"
                            save_state(self._state)
                            self:_action_feed()
                        end,
                    },
                    {
                        text_func = function() return T("Pet") end,
                        keep_menu_open = true,
                        callback = function()
                            self._state.last_quick_action = "pet"
                            save_state(self._state)
                            self:_action_pet()
                        end,
                    },
                    {
                        text_func = function() return T("Give Treat") end,
                        keep_menu_open = true,
                        callback = function()
                            self._state.last_quick_action = "treat"
                            save_state(self._state)
                            self:_action_treat()
                        end,
                    },
                    {
                        text_func = function() return T("Give Medicine") end,
                        keep_menu_open = true,
                        callback = function()
                            self._state.last_quick_action = "medicine"
                            save_state(self._state)
                            self:_action_medicine()
                        end,
                    },
                },
            },
            {
                text_func = function() return T("Pet Info") end,
                sub_item_table = {
                    {
                        text_func = function() return T("Today Summary") end,
                        keep_menu_open = false,
                        callback = function()
                            self:_show_daily_summary()
                        end,
                    },
                    {
                        text_func = function() return T("Statistics") end,
                        keep_menu_open = true,
                        callback = function()
                            self._state.last_quick_action = "stats"
                            save_state(self._state)
                            self:_show_stats()
                        end,
                    },
                    {
                        text_func = function() return T("Journal") end,
                        keep_menu_open = false,
                        callback = function()
                            self._state.last_quick_action = "journal"
                            save_state(self._state)
                            show_journal(self)
                        end,
                    },
                    {
                        text_func = function() return T("Accessories") end,
                        keep_menu_open = true,
                        sub_item_table_func = function()
                            local items = {}
                            if not self._state.accessories or #self._state.accessories == 0 then
                                table.insert(items, {
                                    text_func = function() return T("No accessories found yet.") end,
                                    callback = function() end,
                                })
                                return items
                            end

                            table.insert(items, {
                                text_func = function() return T("Unequip Accessory") end,
                                checked_func = function() return self._state.equipped_accessory == nil end,
                                callback = function()
                                    self._state.equipped_accessory = nil
                                    save_state(self._state)
                                end,
                            })

                            for _, acc in ipairs(self._state.accessories) do
                                table.insert(items, {
                                    text_func = function() return acc end,
                                    checked_func = function() return self._state.equipped_accessory == acc end,
                                    callback = function()
                                        self._state.equipped_accessory = acc
                                        save_state(self._state)
                                    end,
                                })
                            end
                            return items
                        end,
                    },
                    {
                        text_func = function() return T("Rename Pet") end,
                        keep_menu_open = true,
                        callback = function()
                            self:_rename_pet()
                        end,
                    },
                },
            },
            {
                text_func = function() return T("Settings") end,
                sub_item_table = {
                    {
                        text_func = function()
                            local d = self._state.difficulty or "normal"
                            return TF("Difficulty: %s", difficulty_label(d))
                        end,
                        sub_item_table = {
                            {
                                text_func = function() return T("Easy (3-7 pgs)") end,
                                checked_func = function() return self._state.difficulty == "easy" end,
                                callback = function()
                                    self._state.difficulty = "easy"
                                    save_state(self._state)
                                end,
                            },
                            {
                                text_func = function() return T("Normal (10-15 pgs)") end,
                                checked_func = function() return (self._state.difficulty or "normal") == "normal" end,
                                callback = function()
                                    self._state.difficulty = "normal"
                                    save_state(self._state)
                                end,
                            },
                            {
                                text_func = function() return T("Hard (20-30 pgs)") end,
                                checked_func = function() return self._state.difficulty == "hard" end,
                                callback = function()
                                    self._state.difficulty = "hard"
                                    save_state(self._state)
                                end,
                            },
                        },
                    },
                    {
                        text_func = function()
                            local mode = (self._state.config and self._state.config.panel_mode) or "auto"
                            return TF("Panel mode: %s", panel_mode_label(mode))
                        end,
                        keep_menu_open = true,
                        callback = function(menu)
                            if not self._state.config then
                                self._state.config = {}
                            end
                            self._state.config.panel_mode = cycle_value(self._state.config.panel_mode or "auto", {
                                "auto", "compact", "normal", "detailed",
                            })
                            save_state(self._state)
                            if menu and menu.updateItems then
                                menu:updateItems()
                            end
                        end,
                    },
                    {
                        text_func = function()
                            local mode = (self._state.config and self._state.config.notifications) or "normal"
                            return TF("Notifications: %s", notifications_label(mode))
                        end,
                        keep_menu_open = true,
                        callback = function(menu)
                            if not self._state.config then
                                self._state.config = {}
                            end
                            self._state.config.notifications = cycle_value(self._state.config.notifications or "normal", {
                                "normal", "quiet", "verbose",
                            })
                            save_state(self._state)
                            if menu and menu.updateItems then
                                menu:updateItems()
                            end
                        end,
                    },
                    {
                        text_func = function()
                            local enabled = true
                            if self._state.config and self._state.config.pet_animation ~= nil then
                                enabled = self._state.config.pet_animation
                            end
                            return TF("Pet animation: %s", animation_label(enabled))
                        end,
                        keep_menu_open = true,
                        callback = function(menu)
                            if not self._state.config then
                                self._state.config = {}
                            end
                            local current = self._state.config.pet_animation
                            if current == nil then current = true end
                            self._state.config.pet_animation = not current
                            save_state(self._state)
                            if menu and menu.updateItems then
                                menu:updateItems()
                            end
                        end,
                    },
                },
            },
            {
                text_func = function() return T("Danger Zone") end,
                sub_item_table = {
                    {
                        text_func = function() return T("Reset Pet") end,
                        keep_menu_open = true,
                        callback = function()
                            self:_confirm_reset()
                        end,
                    },
                },
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
    append_events(all_events, events)

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
            append_events(all_events, m_events)
        end
    end

    local s_events
    self._state, s_events = Logic.check_streak(self._state)
    append_events(all_events, s_events)

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

    local all_events = {}
    local events
    self._state, events = Logic.on_book_finished(self._state, book_path)
    append_events(all_events, events)

    self:_process_events(all_events)
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
        local all_events = {}
        local events
        self._state, events = Logic.update_time_decay(self._state)
        append_events(all_events, events)

        self:_process_events(all_events)
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

    self._state.last_quick_action = "feed"

    local all_events = {}
    local events
    self._state, events = Logic.feed(self._state)
    append_events(all_events, events)

    self:_process_events(all_events)
    save_state(self._state)
end

function KoPet:_action_pet()
    local Logic = load_local("kopet_logic")
    if not Logic then return end

    self._state.last_quick_action = "pet"

    local all_events = {}
    local events
    self._state, events = Logic.pet(self._state)
    append_events(all_events, events)

    self:_process_events(all_events)
    save_state(self._state)
end

function KoPet:_action_treat()
    local Logic = load_local("kopet_logic")
    if not Logic then return end

    self._state.last_quick_action = "treat"

    local all_events = {}
    local events
    self._state, events = Logic.feed_treat(self._state)
    append_events(all_events, events)

    self:_process_events(all_events)
    save_state(self._state)
end

function KoPet:_action_medicine()
    local Logic = load_local("kopet_logic")
    if not Logic then return end

    self._state.last_quick_action = "medicine"

    local all_events = {}
    local events
    self._state, events = Logic.feed_medicine(self._state)
    append_events(all_events, events)

    self:_process_events(all_events)
    save_state(self._state)
end

function KoPet:_show_daily_summary()
    local history = self._state.daily_history or {}
    local today = os.date("%Y-%m-%d")
    local day = history[today] or { pages = 0, care = 0, books = 0, medicine_found = 0 }

    local lines = {
        T("Today Summary"),
        "",
        TF("Pages read: %d", day.pages or 0),
        TF("Care actions: %d", day.care or 0),
        TF("Books completed: %d", day.books or 0),
        TF("Medicine found: %d", day.medicine_found or 0),
    }

    UIManager:show(InfoMessage:new{
        text = table.concat(lines, "\n"),
    })
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
        mode = self._state.config and self._state.config.panel_mode or "auto",
        animate_pet = self._state.config == nil or self._state.config.pet_animation ~= false,
        animation_interval = (self._state.config and self._state.config.pet_animation_interval) or 1.6,
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
    local stage = Sprites.get_stage(stats.level, self._state.evolution_path)
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
        TF("Medicine: %d", stats.medicines or 0),
        TF("Crystals: %d", stats.crystals),
        TF("Accessory: %s", stats.equipped_accessory or T("None")),
        TF("Difficulty: %s", difficulty_label(stats.difficulty or "normal")),
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

    local Events = load_local("kopet_events")
    if Events then
        events = Events.normalize_list(events)
    end

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
        local msg = prefix .. render_event_message(event)
        if event.type == "level_up" and Sprites then
            local level = event.level or (event.payload and event.payload.level)
            local stage = Sprites.get_stage(level or 0)
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

    local Events = load_local("kopet_events")
    if Events then
        events = Events.normalize_list(events)
    end

    if self._state and self._state.config and self._state.config.notifications == "quiet" then
        local filtered = {}
        for _, event in ipairs(events) do
            if event.priority == "important" then
                table.insert(filtered, event)
            end
        end
        events = filtered
        if #events == 0 then return end
    end

    local important = {}
    local routine = {}
    if Events and Events.split_by_priority then
        important, routine = Events.split_by_priority(events)
    else
        routine = events
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
            local msg = render_event_message(event)
            if event.type == "level_up" and Sprites then
                local level = event.level or (event.payload and event.payload.level)
                local stage = Sprites.get_stage(level or 0)
                msg = msg .. " " .. T(stage.name) .. "!"
            end
            table.insert(lines, msg)
        end
        notify(pet_name .. " " .. mini .. " " .. table.concat(lines, "\n"), 4)
        self._last_notify_time = os.time()
        return
    end

    local now = os.time()
    local cooldown = self._notify_cooldown
    if self._state and self._state.config and self._state.config.notifications == "verbose" then
        cooldown = math.max(10, math.floor(self._notify_cooldown / 2))
    end

    if (now - self._last_notify_time) < cooldown then
        return
    end

    if #routine > 0 then
        local Sprites = load_local("kopet_sprites")
        local Logic = load_local("kopet_logic")
        local mini = "(o.o)"
        if Logic and Sprites then
            mini = Sprites.get_mini(Logic.get_mood(self._state))
        end
        notify(pet_name .. " " .. mini .. " " .. render_event_message(routine[1]), 2)
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
            local all_events = {}
            local events
            self._state, events = Logic.update_time_decay(self._state)
            append_events(all_events, events)

            self:_process_events(all_events)
            save_state(self._state)
        end

        self:_schedule_decay()
    end)
end

return KoPet
