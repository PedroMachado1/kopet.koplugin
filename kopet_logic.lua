--[[
    KoPet Logic — Game engine for the virtual pet.

    Handles XP, levels, hunger, happiness, energy, inventory,
    streaks, and all the game economy calculations.

    This module is pure logic with no UI dependencies.
]]

local logger = require("logger")

local KoPetLogic = {}

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------
KoPetLogic.MAX_STAT = 100
KoPetLogic.MIN_STAT = 0

-- Hunger decay: 1 point per this many seconds of reading
KoPetLogic.HUNGER_DECAY_INTERVAL = 600 -- 10 minutes

-- Happiness: +5 per this many pages
KoPetLogic.HAPPINESS_PAGES_INTERVAL = 30

-- Happiness: bonus from petting
KoPetLogic.PET_HAPPINESS_BONUS = 15

-- Petting cooldown in seconds
KoPetLogic.PET_COOLDOWN = 1800 -- 30 minutes

-- Energy: -1 per this many pages
KoPetLogic.ENERGY_PAGES_INTERVAL = 15

-- Energy: recovery per hour of offline time
KoPetLogic.ENERGY_RECOVERY_PER_HOUR = 2

-- XP per page read
KoPetLogic.XP_PER_PAGE = 1

-- XP from rare treat
KoPetLogic.XP_PER_TREAT = 50

-- XP from evolution crystal
KoPetLogic.XP_PER_CRYSTAL = 200

-- Streak bonus multiplier (streak_days * this)
KoPetLogic.STREAK_BONUS_MULTIPLIER = 5

-- Difficulty configuration for food drops
KoPetLogic.DIFFICULTIES = {
    easy = { min_pages = 3, max_pages = 7, food_restore = 10 },
    normal = { min_pages = 10, max_pages = 15, food_restore = 25 },
    hard = { min_pages = 20, max_pages = 30, food_restore = 40 },
}

-- Happiness decay: -1 per this many seconds of inactivity
KoPetLogic.HAPPINESS_DECAY_INTERVAL = 1200 -- 20 minutes

-- Death threshold: hours with 0 hunger before deep sleep
KoPetLogic.DEATH_HOURS = 24

-- Book progress milestones for rare treats (percentage)
KoPetLogic.MILESTONES = { 25, 50, 75 }

--------------------------------------------------------------------------------
-- Default State
--------------------------------------------------------------------------------
function KoPetLogic.get_default_state()
    return {
        -- Core attributes
        hunger = 80,
        happiness = 60,
        energy = 100,
        xp = 0,

        -- Inventory
        food = 3,       -- Start with 3 rations
        treats = 0,     -- Rare treats
        crystals = 0,   -- Evolution crystals
        medicines = 0,  -- Cures sickness
        accessories = {}, -- Found accessories
        equipped_accessory = nil,

        -- Counters
        total_pages = 0,
        session_pages = 0,
        books_completed = 0,

        -- Streak
        streak_days = 0,
        last_read_date = nil, -- "YYYY-MM-DD"
        today_pages = 0,

        -- Timing
        last_hunger_tick = os.time(),
        last_happiness_tick = os.time(),
        last_petting_time = 0,
        last_offline_time = os.time(),
        last_page_time = os.time(),

        -- Sickness / Death state
        starving_since = nil,   -- timestamp when hunger hit 0
        is_sick = false,
        pages_sick = 0,

        -- Pages per food config
        pages_per_food = 10,

        -- Milestone tracking: { [book_path] = { [25]=true, [50]=true, ... } }
        book_milestones = {},

        -- Completed books tracking
        completed_books = {},

        -- Pet name
        pet_name = "KoPet",

        -- Difficulty mode
        difficulty = "normal",

        -- Evolution & Habits
        evolution_path = "normal",
        reading_habits = {
            night_pages = 0,
            day_pages = 0,
            total_read_time = 0,
            read_pages_count = 0,
        },

        -- Journal
        journal = {},

        -- Pet creation time
        created_at = os.time(),
    }
end

--------------------------------------------------------------------------------
-- Journal Helper
--------------------------------------------------------------------------------
function KoPetLogic.log_journal(state, msg)
    if not state.journal then state.journal = {} end
    table.insert(state.journal, { text = msg, date = os.time() })
end

--------------------------------------------------------------------------------
-- Level Calculation
--------------------------------------------------------------------------------
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

--------------------------------------------------------------------------------
-- Mood Determination
--------------------------------------------------------------------------------
function KoPetLogic.get_mood(state)
    if state.is_sick then
        return "sick"
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

--------------------------------------------------------------------------------
-- Stat Clamping
--------------------------------------------------------------------------------
local function clamp(val, min_v, max_v)
    if val < min_v then return min_v end
    if val > max_v then return max_v end
    return val
end

--------------------------------------------------------------------------------
-- Page Read Event
--------------------------------------------------------------------------------
function KoPetLogic.on_page_read(state)
    local events = {}

    local now = os.time()
    local hour = tonumber(os.date("%H", now))
    if hour >= 18 or hour < 6 then
        state.reading_habits.night_pages = state.reading_habits.night_pages + 1
    else
        state.reading_habits.day_pages = state.reading_habits.day_pages + 1
    end

    if state.last_page_time then
        local diff = now - state.last_page_time
        if diff > 0 and diff < 600 then
            state.reading_habits.total_read_time = state.reading_habits.total_read_time + diff
            state.reading_habits.read_pages_count = state.reading_habits.read_pages_count + 1
        end
    end
    state.last_page_time = now

    state.total_pages = state.total_pages + 1
    state.session_pages = state.session_pages + 1
    state.today_pages = (state.today_pages or 0) + 1

    if state.is_sick then
        state.pages_sick = (state.pages_sick or 0) + 1
        if state.pages_sick >= 15 then
            state.medicines = state.medicines + 1
            state.pages_sick = 0
            table.insert(events, {
                type = "medicine_found",
                message = "Found Medicine!",
            })
        end
        return state, events
    end

    -- XP gain
    local xp_gain = KoPetLogic.XP_PER_PAGE
    if state.streak_days and state.streak_days > 0 then
        xp_gain = xp_gain + math.floor(state.streak_days * KoPetLogic.STREAK_BONUS_MULTIPLIER / 10)
    end
    local old_level = KoPetLogic.get_level(state.xp)
    state.xp = state.xp + xp_gain
    local new_level = KoPetLogic.get_level(state.xp)

    if new_level > old_level then
        table.insert(events, {
            type = "level_up",
            level = new_level,
            message = string.format("Level %d!", new_level),
        })
        KoPetLogic.log_journal(state, string.format("Reached level %d!", new_level))

        if new_level == 6 and state.evolution_path == "normal" then
            local n = state.reading_habits.night_pages
            local d = state.reading_habits.day_pages
            local avg_speed = 60
            if state.reading_habits.read_pages_count > 0 then
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
        local possible = {"hat", "glasses", "wand", "bowtie", "ribbon"}
        local found = possible[math.random(#possible)]
        
        local has_it = false
        for _, acc in ipairs(state.accessories) do
            if acc == found then has_it = true; break end
        end
        if not has_it then
            table.insert(state.accessories, found)
            table.insert(events, {
                type = "accessory_found",
                message = "Found accessory: " .. found,
            })
            KoPetLogic.log_journal(state, "Found a new accessory: " .. found)
        end
    end

    -- Food generation (randomized by difficulty)
    local diff_config = KoPetLogic.DIFFICULTIES[state.difficulty or "normal"] or KoPetLogic.DIFFICULTIES.normal
    state.pages_since_last_food = (state.pages_since_last_food or 0) + 1
    
    local next_food_target = state.next_food_target
    if not next_food_target or next_food_target < diff_config.min_pages or next_food_target > diff_config.max_pages then
        next_food_target = math.random(diff_config.min_pages, diff_config.max_pages)
        state.next_food_target = next_food_target
    end

    if state.pages_since_last_food >= next_food_target then
        state.food = state.food + 1
        state.pages_since_last_food = 0
        state.next_food_target = math.random(diff_config.min_pages, diff_config.max_pages)
        table.insert(events, {
            type = "food_earned",
            message = string.format("Food +1! (Total: %d)", state.food),
        })
    end

    -- Happiness from pages
    if state.total_pages % KoPetLogic.HAPPINESS_PAGES_INTERVAL == 0 then
        state.happiness = clamp(state.happiness + 5, KoPetLogic.MIN_STAT, KoPetLogic.MAX_STAT)
    end

    -- Energy drain
    if state.session_pages % KoPetLogic.ENERGY_PAGES_INTERVAL == 0 then
        state.energy = clamp(state.energy - 1, KoPetLogic.MIN_STAT, KoPetLogic.MAX_STAT)
    end

    -- Update today's date for streak tracking
    local today = os.date("%Y-%m-%d")
    if state.last_read_date ~= today then
        -- Check if yesterday was the last read date (streak continues)
        local yesterday = os.date("%Y-%m-%d", os.time() - 86400)
        if state.last_read_date == yesterday then
            if (state.today_pages or 0) >= KoPetLogic.STREAK_MIN_PAGES then
                -- Previous day had enough pages, streak continues
            end
        elseif state.last_read_date ~= nil then
            -- Streak broken (gap of more than 1 day)
            if state.streak_days > 0 then
                table.insert(events, {
                    type = "streak_lost",
                    message = string.format("Streak lost! (%d days)", state.streak_days),
                })
            end
            state.streak_days = 0
        end
        state.today_pages = 1  -- Reset for today (this page is the first)
        state.last_read_date = today
    end

    return state, events
end

--------------------------------------------------------------------------------
-- Check and update streak at end of day / session
--------------------------------------------------------------------------------
function KoPetLogic.check_streak(state)
    local events = {}
    local today = os.date("%Y-%m-%d")

    if state.last_read_date == today and state.today_pages >= KoPetLogic.STREAK_MIN_PAGES then
        -- Check if we already counted today
        local yesterday = os.date("%Y-%m-%d", os.time() - 86400)
        if state.last_read_date == today then
            -- We need to track whether we already incremented streak today
            if not state._streak_counted_today then
                state.streak_days = (state.streak_days or 0) + 1
                state._streak_counted_today = today
                if state.streak_days > 1 then
                    table.insert(events, {
                        type = "streak",
                        days = state.streak_days,
                        message = string.format("Streak: %d days!", state.streak_days),
                    })
                end
            end
        end
    end

    -- Reset the flag if day changed
    if state._streak_counted_today and state._streak_counted_today ~= today then
        state._streak_counted_today = nil
    end

    return state, events
end

--------------------------------------------------------------------------------
-- Book Progress Milestone Check
--------------------------------------------------------------------------------
function KoPetLogic.check_book_milestone(state, book_path, progress_pct)
    local events = {}
    if not book_path then return state, events end

    if not state.book_milestones then
        state.book_milestones = {}
    end
    if not state.book_milestones[book_path] then
        state.book_milestones[book_path] = {}
    end

    for _, milestone in ipairs(KoPetLogic.MILESTONES) do
        if progress_pct >= milestone and not state.book_milestones[book_path][milestone] then
            state.book_milestones[book_path][milestone] = true
            state.treats = state.treats + 1

            local old_level = KoPetLogic.get_level(state.xp)
            state.xp = state.xp + KoPetLogic.XP_PER_TREAT
            local new_level = KoPetLogic.get_level(state.xp)

            table.insert(events, {
                type = "treat_earned",
                milestone = milestone,
                message = string.format("Rare Treat! (%d%% of book)", milestone),
            })

            if new_level > old_level then
                table.insert(events, {
                    type = "level_up",
                    level = new_level,
                    message = string.format("Level %d!", new_level),
                })
            end
        end
    end

    return state, events
end

--------------------------------------------------------------------------------
-- Book Finished Event
--------------------------------------------------------------------------------
function KoPetLogic.on_book_finished(state, book_path)
    local events = {}

    if state.is_deep_sleep then
        return state, events
    end

    if not state.completed_books then
        state.completed_books = {}
    end

    -- Only count each book once
    if book_path and state.completed_books[book_path] then
        return state, events
    end

    if book_path then
        state.completed_books[book_path] = true
    end

    state.books_completed = (state.books_completed or 0) + 1
    state.crystals = (state.crystals or 0) + 1

    local old_level = KoPetLogic.get_level(state.xp)
    state.xp = state.xp + KoPetLogic.XP_PER_CRYSTAL
    local new_level = KoPetLogic.get_level(state.xp)

    table.insert(events, {
        type = "crystal_earned",
        message = "Evolution Crystal earned!",
    })

    if new_level > old_level then
        table.insert(events, {
            type = "level_up",
            level = new_level,
            message = string.format("Level %d!", new_level),
        })
    end

    return state, events
end

--------------------------------------------------------------------------------
-- Feed the Pet
--------------------------------------------------------------------------------
function KoPetLogic.feed(state)
    local events = {}

    if state.is_sick then
        table.insert(events, {
            type = "is_sick",
            message = "Your pet is sick and cannot eat. Needs Medicine!",
        })
        return state, events
    end

    if state.food <= 0 then
        table.insert(events, {
            type = "no_food",
            message = "No food! Read more pages to earn some.",
        })
        return state, events
    end

    state.food = state.food - 1
    local diff_config = KoPetLogic.DIFFICULTIES[state.difficulty or "normal"] or KoPetLogic.DIFFICULTIES.normal
    state.hunger = clamp(state.hunger + diff_config.food_restore, KoPetLogic.MIN_STAT, KoPetLogic.MAX_STAT)

    -- Reset starvation timer
    if state.hunger > 0 then
        state.starving_since = nil
    end

    table.insert(events, {
        type = "fed",
        message = string.format("Fed! Hunger: %d%%", state.hunger),
    })

    return state, events
end

--------------------------------------------------------------------------------
-- Feed with Treat
--------------------------------------------------------------------------------
function KoPetLogic.feed_treat(state)
    local events = {}

    if state.treats <= 0 then
        table.insert(events, {
            type = "no_treats",
            message = "No treats! Reach milestones in books.",
        })
        return state, events
    end

    state.treats = state.treats - 1
    state.hunger = clamp(state.hunger + 40, KoPetLogic.MIN_STAT, KoPetLogic.MAX_STAT)
    state.happiness = clamp(state.happiness + 20, KoPetLogic.MIN_STAT, KoPetLogic.MAX_STAT)

    table.insert(events, {
        type = "treat_used",
        message = string.format("Treat given! Hunger: %d%% | Happiness: %d%%", state.hunger, state.happiness),
    })

    return state, events
end

--------------------------------------------------------------------------------
-- Give Medicine (Cure Sickness)
--------------------------------------------------------------------------------
function KoPetLogic.feed_medicine(state)
    local events = {}

    if not state.is_sick then
        table.insert(events, {
            type = "not_sick",
            message = "Your pet is healthy! No need for medicine.",
        })
        return state, events
    end

    if state.medicines <= 0 then
        table.insert(events, {
            type = "no_medicine",
            message = "No medicine! Keep reading while sick to find some.",
        })
        return state, events
    end

    state.medicines = state.medicines - 1
    state.is_sick = false
    KoPetLogic.log_journal(state, "Pet was cured with Medicine.")

    table.insert(events, {
        type = "cured",
        message = "Cured! Your pet is healthy again.",
    })

    return state, events
end

--------------------------------------------------------------------------------
-- Pet (Acariciar)
--------------------------------------------------------------------------------
function KoPetLogic.pet(state)
    local events = {}
    local now = os.time()

    if state.is_sick then
        table.insert(events, {
            type = "sleeping",
            message = "Your pet is sick...",
        })
        return state, events
    end

    local elapsed = now - (state.last_petting_time or 0)
    if elapsed < KoPetLogic.PET_COOLDOWN then
        local remaining = KoPetLogic.PET_COOLDOWN - elapsed
        local mins = math.ceil(remaining / 60)
        table.insert(events, {
            type = "cooldown",
            message = string.format("Wait %d min to pet again.", mins),
        })
        return state, events
    end

    state.last_petting_time = now
    state.happiness = clamp(state.happiness + KoPetLogic.PET_HAPPINESS_BONUS, KoPetLogic.MIN_STAT, KoPetLogic.MAX_STAT)

    table.insert(events, {
        type = "petted",
        message = string.format("Petted! Happiness: %d%%", state.happiness),
    })

    return state, events
end

--------------------------------------------------------------------------------
-- Time-based Updates (call periodically)
--------------------------------------------------------------------------------
function KoPetLogic.update_time_decay(state)
    local events = {}
    local now = os.time()

    if state.is_sick then
        return state, events
    end

    -- Hunger decay
    local hunger_elapsed = now - (state.last_hunger_tick or now)
    if hunger_elapsed >= KoPetLogic.HUNGER_DECAY_INTERVAL then
        local ticks = math.floor(hunger_elapsed / KoPetLogic.HUNGER_DECAY_INTERVAL)
        state.hunger = clamp(state.hunger - ticks, KoPetLogic.MIN_STAT, KoPetLogic.MAX_STAT)
        state.last_hunger_tick = now

        -- Starvation check
        if state.hunger <= 0 then
            if not state.starving_since then
                state.starving_since = now
                table.insert(events, {
                    type = "starving",
                    message = "Your pet is starving!",
                })
            else
                local starving_hours = (now - state.starving_since) / 3600
                if starving_hours >= KoPetLogic.DEATH_HOURS then
                    state.is_sick = true
                    KoPetLogic.log_journal(state, "Pet became severely sick due to starvation.")
                    table.insert(events, {
                        type = "deep_sleep",
                        message = "Your pet became sick from starvation!",
                    })
                end
            end
        end

        -- Low hunger warning
        if state.hunger > 0 and state.hunger <= 20 then
            table.insert(events, {
                type = "hungry_warning",
                message = string.format("Your pet is hungry! (%d%%)", state.hunger),
            })
        end
    end

    -- Happiness decay
    local happy_elapsed = now - (state.last_happiness_tick or now)
    if happy_elapsed >= KoPetLogic.HAPPINESS_DECAY_INTERVAL then
        local ticks = math.floor(happy_elapsed / KoPetLogic.HAPPINESS_DECAY_INTERVAL)
        state.happiness = clamp(state.happiness - ticks, KoPetLogic.MIN_STAT, KoPetLogic.MAX_STAT)
        state.last_happiness_tick = now
    end

    -- Energy recovery when offline (check gap since last offline)
    local offline_elapsed = now - (state.last_offline_time or now)
    if offline_elapsed >= 3600 then
        local hours = math.floor(offline_elapsed / 3600)
        state.energy = clamp(state.energy + (hours * KoPetLogic.ENERGY_RECOVERY_PER_HOUR), KoPetLogic.MIN_STAT, KoPetLogic.MAX_STAT)
        state.last_offline_time = now
    end

    return state, events
end

--------------------------------------------------------------------------------
-- Get pet age in days
--------------------------------------------------------------------------------
function KoPetLogic.get_age_days(state)
    local created = state.created_at or os.time()
    return math.floor((os.time() - created) / 86400)
end

--------------------------------------------------------------------------------
-- Get stats summary table
--------------------------------------------------------------------------------
function KoPetLogic.get_stats_summary(state)
    local level = KoPetLogic.get_level(state.xp)
    local progress, needed = KoPetLogic.get_xp_progress(state.xp)

    return {
        level = level,
        xp = state.xp,
        xp_progress = progress,
        xp_needed = needed,
        hunger = state.hunger,
        happiness = state.happiness,
        energy = state.energy,
        food = state.food,
        treats = state.treats,
        crystals = state.crystals,
        total_pages = state.total_pages,
        books_completed = state.books_completed or 0,
        streak_days = state.streak_days or 0,
        age_days = KoPetLogic.get_age_days(state),
        mood = KoPetLogic.get_mood(state),
        is_deep_sleep = state.is_deep_sleep,
        pet_name = state.pet_name or "KoPet",
    }
end

return KoPetLogic
