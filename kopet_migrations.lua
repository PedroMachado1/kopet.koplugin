local Migrations = {}

local CURRENT_STATE_VERSION = 2

local function shallow_copy(tbl)
    local out = {}
    for k, v in pairs(tbl or {}) do
        out[k] = v
    end
    return out
end

local function ensure_table(state, key)
    if type(state[key]) ~= "table" then
        state[key] = {}
    end
end

local function migrate_1_to_2(state, defaults)
    for k, v in pairs(defaults) do
        if state[k] == nil then
            if type(v) == "table" then
                state[k] = shallow_copy(v)
            else
                state[k] = v
            end
        end
    end

    if state.medicines == nil then state.medicines = 0 end
    if state.is_sick == nil then state.is_sick = false end
    if state.pages_sick == nil then state.pages_sick = 0 end
    if type(state.accessories) ~= "table" then state.accessories = {} end
    if state.equipped_accessory == nil then state.equipped_accessory = nil end
    if state.difficulty == nil then state.difficulty = "normal" end
    if state.evolution_path == nil then state.evolution_path = "normal" end
    if type(state.journal) ~= "table" then state.journal = {} end
    if type(state.reading_habits) ~= "table" then
        state.reading_habits = {
            night_pages = 0,
            day_pages = 0,
            total_read_time = 0,
            read_pages_count = 0,
        }
    else
        if state.reading_habits.night_pages == nil then state.reading_habits.night_pages = 0 end
        if state.reading_habits.day_pages == nil then state.reading_habits.day_pages = 0 end
        if state.reading_habits.total_read_time == nil then state.reading_habits.total_read_time = 0 end
        if state.reading_habits.read_pages_count == nil then state.reading_habits.read_pages_count = 0 end
    end

    if state.is_bored == nil then state.is_bored = false end
    if state.is_sleepy == nil then state.is_sleepy = false end
    if type(state.daily_history) ~= "table" then state.daily_history = {} end
    if state.last_quick_action == nil then state.last_quick_action = "view_pet" end

    if type(state.config) ~= "table" then
        state.config = {}
    end
    if state.config.pet_animation == nil then
        state.config.pet_animation = true
    end
    if state.config.pet_animation_interval == nil then
        state.config.pet_animation_interval = 1.6
    end

    state.state_version = 2
    return state
end

function Migrations.current_version()
    return CURRENT_STATE_VERSION
end

function Migrations.migrate(state, defaults)
    if type(state) ~= "table" then
        state = {}
    end
    defaults = defaults or {}

    local original_version = tonumber(state.state_version) or 1
    local version = original_version
    local changed = false

    if version < 2 then
        state = migrate_1_to_2(state, defaults)
        version = 2
        changed = true
    end

    if state.state_version ~= CURRENT_STATE_VERSION then
        state.state_version = CURRENT_STATE_VERSION
        changed = true
    end

    return state, changed, original_version, CURRENT_STATE_VERSION
end

return Migrations
