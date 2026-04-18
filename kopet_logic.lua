--[[
    KoPet Logic — Game engine for the virtual pet.

    Handles XP, levels, hunger, happiness, energy, inventory,
    streaks, sickness, accessories, and game economy calculations.

    This module is pure logic with no UI dependencies.
]]

local logger = require("logger")

local KoPetLogic = {}

KoPetLogic.MAX_STAT = 100
KoPetLogic.MIN_STAT = 0

KoPetLogic.HUNGER_DECAY_INTERVAL = 600
KoPetLogic.HAPPINESS_PAGES_INTERVAL = 30
KoPetLogic.PET_HAPPINESS_BONUS = 15
KoPetLogic.PET_COOLDOWN = 1800
KoPetLogic.ENERGY_PAGES_INTERVAL = 15
KoPetLogic.ENERGY_RECOVERY_PER_HOUR = 2

KoPetLogic.XP_PER_PAGE = 1
KoPetLogic.XP_PER_TREAT = 50
KoPetLogic.XP_PER_CRYSTAL = 200
KoPetLogic.STREAK_BONUS_MULTIPLIER = 5
KoPetLogic.STREAK_MIN_PAGES = 10

KoPetLogic.DIFFICULTIES = {
    easy = {
        min_pages = 3, max_pages = 7,
        food_restore = 14,
        medicine_pages = 30,
        xp_mult = 1.15,
        hunger_decay_mult = 0.80,
        happiness_decay_mult = 0.85,
    },
    normal = {
        min_pages = 10, max_pages = 15,
        food_restore = 25,
        medicine_pages = 50,
        xp_mult = 1.0,
        hunger_decay_mult = 1.0,
        happiness_decay_mult = 1.0,
    },
    hard = {
        min_pages = 20, max_pages = 30,
        food_restore = 40,
        medicine_pages = 65,
        xp_mult = 0.90,
        hunger_decay_mult = 1.25,
        happiness_decay_mult = 1.20,
    },
}

KoPetLogic.HAPPINESS_DECAY_INTERVAL = 1200
KoPetLogic.DEATH_HOURS = 24
KoPetLogic.MILESTONES = { 25, 50, 75 }
KoPetLogic.BORED_AFTER_SECONDS = 12 * 3600
KoPetLogic.SLEEPY_ENERGY_THRESHOLD = 15

local function clamp(val, min_v, max_v)
    if val < min_v then return min_v end
    if val > max_v then return max_v end
    return val
end

local function add_event(events, event)
    table.insert(events, event)
end

local function ensure_difficulty(state)
    local d = state.difficulty or "normal"
    if not KoPetLogic.DIFFICULTIES[d] then
        d = "normal"
        state.difficulty = d
    end
    return d
end

local function get_medicine_target(state)
    local d = ensure_difficulty(state)
    return KoPetLogic.DIFFICULTIES[d].medicine_pages
end

local function get_today_key()
    return os.date("%Y-%m-%d")
end

local function ensure_daily_history(state)
    if type(state.daily_history) ~= "table" then
        state.daily_history = {}
    end
end

local function add_daily_metric(state, key, amount)
    ensure_daily_history(state)
    local today = get_today_key()
    if type(state.daily_history[today]) ~= "table" then
        state.daily_history[today] = {
            pages = 0,
            care = 0,
            books = 0,
            medicine_found = 0,
        }
    end
    state.daily_history[today][key] = (state.daily_history[today][key] or 0) + (amount or 1)
end

local function get_accessory_bonus(state)
    local bonus = {
        xp_per_page = 0,
        feed_hunger = 0,
        pet_happiness = 0,
        treat_happiness = 0,
        pet_cooldown_mult = 1.0,
    }

    local accessory = state.equipped_accessory
    if accessory == "glasses" then
        bonus.xp_per_page = 1
    elseif accessory == "hat" then
        bonus.feed_hunger = 5
    elseif accessory == "ribbon" then
        bonus.pet_cooldown_mult = 0.8
    elseif accessory == "bowtie" then
        bonus.pet_happiness = 5
    elseif accessory == "wand" then
        bonus.treat_happiness = 4
    end

    return bonus
end

function KoPetLogic.get_default_state()
    return {
        state_version = 2,

        hunger = 80,
        happiness = 60,
        energy = 100,
        xp = 0,

        food = 3,
        treats = 0,
        crystals = 0,
        medicines = 0,
        accessories = {},
        equipped_accessory = nil,

        total_pages = 0,
        session_pages = 0,
        books_completed = 0,

        streak_days = 0,
        last_read_date = nil,
        today_pages = 0,

        last_hunger_tick = os.time(),
        last_happiness_tick = os.time(),
        last_petting_time = 0,
        last_offline_time = os.time(),
        last_page_time = os.time(),

        starving_since = nil,
        is_deep_sleep = false,
        is_sick = false,
        pages_sick = 0,
        is_bored = false,
        is_sleepy = false,

        pages_per_food = 10,
        book_milestones = {},
        completed_books = {},

        pet_name = "KoPet",
        difficulty = "normal",

        evolution_path = "normal",
        reading_habits = {
            night_pages = 0,
            day_pages = 0,
            total_read_time = 0,
            read_pages_count = 0,
        },

        journal = {},
        daily_history = {},
        created_at = os.time(),

        config = {
            panel_mode = "detailed",
            notifications = "normal",
            routine_notify_cooldown = 30,
            pet_animation = true,
            pet_animation_interval = 1.6,
        },

        last_quick_action = "view_pet",

    }
end

function KoPetLogic.log_journal(state, msg)
    if not state.journal then state.journal = {} end
    table.insert(state.journal, { text = msg, date = os.time() })
end

function KoPetLogic.get_level(xp)
    if xp <= 0 then return 0 end
    return math.floor(math.sqrt(xp / 50))
end

function KoPetLogic.get_xp_for_level(level)
    return level * level * 50
end

function KoPetLogic.get_xp_progress(xp)
    local level = KoPetLogic.get_level(xp)
    local current_level_xp = KoPetLogic.get_xp_for_level(level)
    local next_level_xp = KoPetLogic.get_xp_for_level(level + 1)
    local progress = xp - current_level_xp
    local needed = next_level_xp - current_level_xp
    return progress, needed, level
end

function KoPetLogic.get_mood(state)
    if state.is_sick then
        return "sick"
    end
    if state.is_deep_sleep then
        return "sleeping"
    end
    if state.energy <= 10 then
        return "sleeping"
    end
    if state.hunger <= 15 then
        return "hungry"
    end
    if state.happiness >= 70 then
        return "happy"
    end
    return "idle"
end

function KoPetLogic.on_page_read(state)
    local events = {}

    local now = os.time()
    local hour = tonumber(os.date("%H", now))
    if hour >= 18 or hour < 6 then
        state.reading_habits.night_pages = (state.reading_habits.night_pages or 0) + 1
    else
        state.reading_habits.day_pages = (state.reading_habits.day_pages or 0) + 1
    end

    if state.last_page_time then
        local diff = now - state.last_page_time
        if diff > 0 and diff < 600 then
            state.reading_habits.total_read_time = (state.reading_habits.total_read_time or 0) + diff
            state.reading_habits.read_pages_count = (state.reading_habits.read_pages_count or 0) + 1
        end
    end
    state.last_page_time = now

    state.total_pages = (state.total_pages or 0) + 1
    state.session_pages = (state.session_pages or 0) + 1
    state.today_pages = (state.today_pages or 0) + 1
    add_daily_metric(state, "pages", 1)

    if state.is_sick then
        state.pages_sick = (state.pages_sick or 0) + 1
        local target = get_medicine_target(state)
        if state.pages_sick >= target then
            state.medicines = (state.medicines or 0) + 1
            state.pages_sick = 0
            add_daily_metric(state, "medicine_found", 1)
            add_event(events, {
                type = "medicine_found",
                key = "event.medicine_found",
                payload = { total_medicine = state.medicines },
                priority = "important",
                message = "Found Medicine!",
            })
            KoPetLogic.log_journal(state, "Found medicine while nursing the pet.")
        end
        return state, events
    end

    local xp_gain = KoPetLogic.XP_PER_PAGE
    local bonus = get_accessory_bonus(state)
    local d = ensure_difficulty(state)
    local diff_config = KoPetLogic.DIFFICULTIES[d]

    xp_gain = xp_gain + bonus.xp_per_page
    if state.streak_days and state.streak_days > 0 then
        xp_gain = xp_gain + math.floor(state.streak_days * KoPetLogic.STREAK_BONUS_MULTIPLIER / 10)
    end
    if state.is_bored then
        xp_gain = math.floor(xp_gain * 0.8)
    end
    if state.is_sleepy then
        xp_gain = math.floor(xp_gain * 0.7)
    end
    xp_gain = math.max(1, math.floor(xp_gain * (diff_config.xp_mult or 1.0)))

    local old_level = KoPetLogic.get_level(state.xp)
    state.xp = (state.xp or 0) + xp_gain
    local new_level = KoPetLogic.get_level(state.xp)

    if new_level > old_level then
        add_event(events, {
            type = "level_up",
            level = new_level,
            key = "event.level_up",
            payload = { level = new_level },
            message = string.format("Level %d!", new_level),
        })
        KoPetLogic.log_journal(state, string.format("Reached level %d!", new_level))

        if new_level == 6 and state.evolution_path == "normal" then
            local n = state.reading_habits.night_pages or 0
            local d = state.reading_habits.day_pages or 0
            local avg_speed = 60
            if (state.reading_habits.read_pages_count or 0) > 0 then
                avg_speed = state.reading_habits.total_read_time / state.reading_habits.read_pages_count
            end

            if n > d * 1.5 then
                state.evolution_path = "owl"
                KoPetLogic.log_journal(state, "Evolved into Night Owl path!")
            elseif avg_speed < 30 then
                state.evolution_path = "fox"
                KoPetLogic.log_journal(state, "Evolved into Speedster Fox path!")
            elseif avg_speed > 120 then
                state.evolution_path = "scholar"
                KoPetLogic.log_journal(state, "Evolved into Scholar path!")
            else
                KoPetLogic.log_journal(state, "Evolved into standard Adult path!")
            end
        end
    end

    if math.random(1, 200) == 1 then
        local possible = { "hat", "glasses", "wand", "bowtie", "ribbon" }
        local found = possible[math.random(#possible)]

        local has_it = false
        for _, acc in ipairs(state.accessories or {}) do
            if acc == found then
                has_it = true
                break
            end
        end

        if not has_it then
            state.accessories = state.accessories or {}
            table.insert(state.accessories, found)
            add_event(events, {
                type = "accessory_found",
                key = "event.accessory_found",
                payload = { accessory = found },
                priority = "important",
                message = "Found accessory: " .. found,
            })
            KoPetLogic.log_journal(state, "Found a new accessory: " .. found)
        end
    end

    state.pages_since_last_food = (state.pages_since_last_food or 0) + 1

    local next_food_target = state.next_food_target
    if not next_food_target
        or next_food_target < diff_config.min_pages
        or next_food_target > diff_config.max_pages then
        next_food_target = math.random(diff_config.min_pages, diff_config.max_pages)
        state.next_food_target = next_food_target
    end

    if state.pages_since_last_food >= next_food_target then
        state.food = (state.food or 0) + 1
        state.pages_since_last_food = 0
        state.next_food_target = math.random(diff_config.min_pages, diff_config.max_pages)
        add_event(events, {
            type = "food_earned",
            key = "event.food_earned",
            payload = { total_food = state.food },
            message = string.format("Food +1! (Total: %d)", state.food),
        })
    end

    if state.total_pages % KoPetLogic.HAPPINESS_PAGES_INTERVAL == 0 then
        state.happiness = clamp(state.happiness + 5, KoPetLogic.MIN_STAT, KoPetLogic.MAX_STAT)
    end

    if state.session_pages % KoPetLogic.ENERGY_PAGES_INTERVAL == 0 then
        state.energy = clamp(state.energy - 1, KoPetLogic.MIN_STAT, KoPetLogic.MAX_STAT)
    end

    local today = os.date("%Y-%m-%d")
    if state.last_read_date ~= today then
        local yesterday = os.date("%Y-%m-%d", os.time() - 86400)
        if state.last_read_date == yesterday then
            -- keep streak logic in check_streak
        elseif state.last_read_date ~= nil then
            if state.streak_days > 0 then
                add_event(events, {
                    type = "streak_lost",
                    key = "event.streak_lost",
                    payload = { days = state.streak_days },
                    message = string.format("Streak lost! (%d days)", state.streak_days),
                })
            end
            state.streak_days = 0
        end
        state.today_pages = 1
        state.last_read_date = today
    end

    return state, events
end

function KoPetLogic.check_streak(state)
    local events = {}
    local today = os.date("%Y-%m-%d")

    if state.last_read_date == today and (state.today_pages or 0) >= KoPetLogic.STREAK_MIN_PAGES then
        if not state._streak_counted_today then
            state.streak_days = (state.streak_days or 0) + 1
            state._streak_counted_today = today
            if state.streak_days > 1 then
                add_event(events, {
                    type = "streak",
                    days = state.streak_days,
                    key = "event.streak",
                    payload = { days = state.streak_days },
                    message = string.format("Streak: %d days!", state.streak_days),
                })
            end
        end
    end

    if state._streak_counted_today and state._streak_counted_today ~= today then
        state._streak_counted_today = nil
    end

    return state, events
end

function KoPetLogic.check_book_milestone(state, book_path, progress_pct)
    local events = {}
    if not book_path then return state, events end

    state.book_milestones = state.book_milestones or {}
    state.book_milestones[book_path] = state.book_milestones[book_path] or {}

    for _, milestone in ipairs(KoPetLogic.MILESTONES) do
        if progress_pct >= milestone and not state.book_milestones[book_path][milestone] then
            state.book_milestones[book_path][milestone] = true
            state.treats = (state.treats or 0) + 1

            local old_level = KoPetLogic.get_level(state.xp)
            state.xp = (state.xp or 0) + KoPetLogic.XP_PER_TREAT
            local new_level = KoPetLogic.get_level(state.xp)

            add_event(events, {
                type = "treat_earned",
                milestone = milestone,
                key = "event.treat_earned",
                payload = { milestone = milestone },
                message = string.format("Rare Treat! (%d%% of book)", milestone),
            })

            if new_level > old_level then
                add_event(events, {
                    type = "level_up",
                    level = new_level,
                    key = "event.level_up",
                    payload = { level = new_level },
                    message = string.format("Level %d!", new_level),
                })
            end
        end
    end

    return state, events
end

function KoPetLogic.on_book_finished(state, book_path)
    local events = {}

    if state.is_deep_sleep then
        return state, events
    end

    state.completed_books = state.completed_books or {}
    if book_path and state.completed_books[book_path] then
        return state, events
    end

    if book_path then
        state.completed_books[book_path] = true
    end

    state.books_completed = (state.books_completed or 0) + 1
    add_daily_metric(state, "books", 1)
    state.crystals = (state.crystals or 0) + 1

    local old_level = KoPetLogic.get_level(state.xp)
    state.xp = (state.xp or 0) + KoPetLogic.XP_PER_CRYSTAL
    local new_level = KoPetLogic.get_level(state.xp)

    add_event(events, {
        type = "crystal_earned",
        key = "event.crystal_earned",
        payload = {},
        message = "Evolution Crystal earned!",
    })

    if new_level > old_level then
        add_event(events, {
            type = "level_up",
            level = new_level,
            key = "event.level_up",
            payload = { level = new_level },
            message = string.format("Level %d!", new_level),
        })
    end

    return state, events
end

function KoPetLogic.feed(state)
    local events = {}

    if state.is_sick then
        add_event(events, {
            type = "is_sick",
            key = "event.is_sick",
            payload = {},
            priority = "important",
            message = "Your pet is sick and cannot eat. Needs Medicine!",
        })
        return state, events
    end

    if state.food <= 0 then
        add_event(events, {
            type = "no_food",
            key = "event.no_food",
            payload = {},
            message = "No food! Read more pages to earn some.",
        })
        return state, events
    end

    state.food = state.food - 1
    add_daily_metric(state, "care", 1)
    local d = ensure_difficulty(state)
    local diff_config = KoPetLogic.DIFFICULTIES[d]
    local bonus = get_accessory_bonus(state)
    state.hunger = clamp(state.hunger + diff_config.food_restore + bonus.feed_hunger, KoPetLogic.MIN_STAT, KoPetLogic.MAX_STAT)

    if state.hunger > 0 then
        state.starving_since = nil
        if state.is_deep_sleep then
            state.is_deep_sleep = false
            state.xp = math.max(0, (state.xp or 0) - 100)
            add_event(events, {
                type = "revived",
                key = "event.revived",
                payload = {},
                priority = "important",
                message = "Your pet woke up! (-100 XP)",
            })
        end
    end

    add_event(events, {
        type = "fed",
        key = "event.fed",
        payload = { hunger = state.hunger },
        message = string.format("Fed! Hunger: %d%%", state.hunger),
    })

    return state, events
end

function KoPetLogic.feed_treat(state)
    local events = {}

    if state.treats <= 0 then
        add_event(events, {
            type = "no_treats",
            key = "event.no_treats",
            payload = {},
            message = "No treats! Reach milestones in books.",
        })
        return state, events
    end

    state.treats = state.treats - 1
    add_daily_metric(state, "care", 1)
    local bonus = get_accessory_bonus(state)
    state.hunger = clamp(state.hunger + 40, KoPetLogic.MIN_STAT, KoPetLogic.MAX_STAT)
    state.happiness = clamp(state.happiness + 20 + bonus.treat_happiness, KoPetLogic.MIN_STAT, KoPetLogic.MAX_STAT)

    add_event(events, {
        type = "treat_used",
        key = "event.treat_used",
        payload = { hunger = state.hunger, happiness = state.happiness },
        message = string.format("Treat given! Hunger: %d%% | Happiness: %d%%", state.hunger, state.happiness),
    })

    return state, events
end

function KoPetLogic.feed_medicine(state)
    local events = {}

    if not state.is_sick then
        add_event(events, {
            type = "not_sick",
            key = "event.not_sick",
            payload = {},
            message = "Your pet is healthy! No need for medicine.",
        })
        return state, events
    end

    if (state.medicines or 0) <= 0 then
        add_event(events, {
            type = "no_medicine",
            key = "event.no_medicine",
            payload = { needed_pages = get_medicine_target(state) },
            priority = "important",
            message = "No medicine! Keep reading while sick to find some.",
        })
        return state, events
    end

    state.medicines = state.medicines - 1
    add_daily_metric(state, "care", 1)
    state.is_sick = false
    state.pages_sick = 0
    state.starving_since = nil
    KoPetLogic.log_journal(state, "Pet was cured with medicine.")

    add_event(events, {
        type = "cured",
        key = "event.cured",
        payload = {},
        priority = "important",
        message = "Cured! Your pet is healthy again.",
    })

    return state, events
end

function KoPetLogic.pet(state)
    local events = {}
    local now = os.time()

    if state.is_sick then
        add_event(events, {
            type = "pet_sick",
            key = "event.pet_sick",
            payload = {},
            message = "Your pet is sick...",
        })
        return state, events
    end

    if state.is_deep_sleep then
        add_event(events, {
            type = "sleeping",
            key = "event.sleeping",
            payload = {},
            message = "Your pet is in deep sleep...",
        })
        return state, events
    end

    local bonus = get_accessory_bonus(state)
    local cooldown = math.floor(KoPetLogic.PET_COOLDOWN * (bonus.pet_cooldown_mult or 1.0))

    local elapsed = now - (state.last_petting_time or 0)
    if elapsed < cooldown then
        local remaining = cooldown - elapsed
        local mins = math.ceil(remaining / 60)
        add_event(events, {
            type = "cooldown",
            key = "event.cooldown",
            payload = { mins = mins },
            message = string.format("Wait %d min to pet again.", mins),
        })
        return state, events
    end

    state.last_petting_time = now
    add_daily_metric(state, "care", 1)
    state.happiness = clamp(state.happiness + KoPetLogic.PET_HAPPINESS_BONUS + bonus.pet_happiness, KoPetLogic.MIN_STAT, KoPetLogic.MAX_STAT)
    state.is_bored = false

    add_event(events, {
        type = "petted",
        key = "event.petted",
        payload = { happiness = state.happiness },
        message = string.format("Petted! Happiness: %d%%", state.happiness),
    })

    return state, events
end

function KoPetLogic.update_time_decay(state)
    local events = {}
    local now = os.time()

    if state.is_sick then
        return state, events
    end

    if state.is_deep_sleep then
        return state, events
    end

    local d = ensure_difficulty(state)
    local diff_config = KoPetLogic.DIFFICULTIES[d]

    local hunger_elapsed = now - (state.last_hunger_tick or now)
    if hunger_elapsed >= KoPetLogic.HUNGER_DECAY_INTERVAL then
        local ticks = math.floor(hunger_elapsed / KoPetLogic.HUNGER_DECAY_INTERVAL)
        local decay_amount = math.max(1, math.floor(ticks * (diff_config.hunger_decay_mult or 1.0) + 0.5))
        state.hunger = clamp(state.hunger - decay_amount, KoPetLogic.MIN_STAT, KoPetLogic.MAX_STAT)
        state.last_hunger_tick = now

        if state.hunger <= 0 then
            if not state.starving_since then
                state.starving_since = now
                add_event(events, {
                    type = "starving",
                    key = "event.starving",
                    payload = {},
                    priority = "important",
                    message = "Your pet is starving!",
                })
            else
                local starving_hours = (now - state.starving_since) / 3600
                if starving_hours >= KoPetLogic.DEATH_HOURS then
                    state.is_sick = true
                    state.pages_sick = 0
                    KoPetLogic.log_journal(state, "Pet became sick after long starvation.")
                    add_event(events, {
                        type = "deep_sleep",
                        key = "event.became_sick",
                        payload = { medicine_pages = get_medicine_target(state) },
                        priority = "important",
                        message = "Your pet became sick from starvation!",
                    })
                end
            end
        end

        if state.hunger > 0 and state.hunger <= 20 then
            add_event(events, {
                type = "hungry_warning",
                key = "event.hungry_warning",
                payload = { hunger = state.hunger },
                message = string.format("Your pet is hungry! (%d%%)", state.hunger),
            })
        end
    end

    local happy_elapsed = now - (state.last_happiness_tick or now)
    if happy_elapsed >= KoPetLogic.HAPPINESS_DECAY_INTERVAL then
        local ticks = math.floor(happy_elapsed / KoPetLogic.HAPPINESS_DECAY_INTERVAL)
        local decay_amount = math.max(1, math.floor(ticks * (diff_config.happiness_decay_mult or 1.0) + 0.5))
        state.happiness = clamp(state.happiness - decay_amount, KoPetLogic.MIN_STAT, KoPetLogic.MAX_STAT)
        state.last_happiness_tick = now
    end

    local offline_elapsed = now - (state.last_offline_time or now)
    if offline_elapsed >= 3600 then
        local hours = math.floor(offline_elapsed / 3600)
        state.energy = clamp(state.energy + (hours * KoPetLogic.ENERGY_RECOVERY_PER_HOUR), KoPetLogic.MIN_STAT, KoPetLogic.MAX_STAT)
        state.last_offline_time = now
    end

    if state.energy <= KoPetLogic.SLEEPY_ENERGY_THRESHOLD and not state.is_sleepy then
        state.is_sleepy = true
        add_event(events, {
            type = "sleepy",
            key = "event.sleepy",
            payload = {},
            message = "Your pet is sleepy. Let it rest a bit.",
        })
    elseif state.is_sleepy and state.energy >= 40 then
        state.is_sleepy = false
        add_event(events, {
            type = "rested",
            key = "event.rested",
            payload = {},
            message = "Your pet feels rested again.",
        })
    end

    local last_care = state.last_petting_time or 0
    if last_care > 0 and (now - last_care) >= KoPetLogic.BORED_AFTER_SECONDS and not state.is_bored then
        state.is_bored = true
        add_event(events, {
            type = "bored",
            key = "event.bored",
            payload = {},
            message = "Your pet looks bored. Give it some attention.",
        })
    end

    return state, events
end

function KoPetLogic.get_age_days(state)
    local created = state.created_at or os.time()
    return math.floor((os.time() - created) / 86400)
end

function KoPetLogic.get_stats_summary(state)
    local level = KoPetLogic.get_level(state.xp or 0)
    local progress, needed = KoPetLogic.get_xp_progress(state.xp or 0)

    return {
        level = level,
        xp = state.xp or 0,
        xp_progress = progress,
        xp_needed = needed,
        hunger = state.hunger or 0,
        happiness = state.happiness or 0,
        energy = state.energy or 0,
        food = state.food or 0,
        treats = state.treats or 0,
        medicines = state.medicines or 0,
        crystals = state.crystals or 0,
        total_pages = state.total_pages or 0,
        books_completed = state.books_completed or 0,
        streak_days = state.streak_days or 0,
        age_days = KoPetLogic.get_age_days(state),
        mood = KoPetLogic.get_mood(state),
        is_deep_sleep = state.is_deep_sleep,
        is_sick = state.is_sick,
        is_bored = state.is_bored,
        is_sleepy = state.is_sleepy,
        equipped_accessory = state.equipped_accessory,
        pet_name = state.pet_name or "KoPet",
        difficulty = state.difficulty or "normal",
    }
end

return KoPetLogic
