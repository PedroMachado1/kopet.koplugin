local Events = {}

local IMPORTANT_TYPES = {
    level_up = true,
    treat_earned = true,
    crystal_earned = true,
    streak = true,
    streak_lost = true,
    deep_sleep = true,
    starving = true,
    revived = true,
    medicine_found = true,
    no_medicine = true,
    cured = true,
    became_sick = true,
    is_sick = true,
    accessory_found = true,
    bored = true,
    sleepy = true,
    rested = true,
}

local TYPE_TO_KEY = {
    level_up = "event.level_up",
    food_earned = "event.food_earned",
    treat_earned = "event.treat_earned",
    streak_lost = "event.streak_lost",
    streak = "event.streak",
    fed = "event.fed",
    no_food = "event.no_food",
    no_treats = "event.no_treats",
    treat_used = "event.treat_used",
    sleeping = "event.sleeping",
    cooldown = "event.cooldown",
    petted = "event.petted",
    starving = "event.starving",
    deep_sleep = "event.deep_sleep",
    hungry_warning = "event.hungry_warning",
    crystal_earned = "event.crystal_earned",
    revived = "event.revived",
    medicine_found = "event.medicine_found",
    no_medicine = "event.no_medicine",
    cured = "event.cured",
    not_sick = "event.not_sick",
    is_sick = "event.is_sick",
    became_sick = "event.became_sick",
    accessory_found = "event.accessory_found",
    pet_sick = "event.pet_sick",
    bored = "event.bored",
    sleepy = "event.sleepy",
    rested = "event.rested",
}

local LEGACY_PATTERNS = {
    { pattern = "^Level (%d+)!$", key = "event.level_up", payload = { "level" } },
    { pattern = "^Food %+1! %(Total: (%d+)%)$", key = "event.food_earned", payload = { "total_food" } },
    { pattern = "^Rare Treat! %((%d+)%% of book%)$", key = "event.treat_earned", payload = { "milestone" } },
    { pattern = "^Streak lost! %((%d+) days%)$", key = "event.streak_lost", payload = { "days" } },
    { pattern = "^Streak: (%d+) days!$", key = "event.streak", payload = { "days" } },
    { pattern = "^Fed! Hunger: (%d+)%%$", key = "event.fed", payload = { "hunger" } },
    { pattern = "^Wait (%d+) min to pet again%.$", key = "event.cooldown", payload = { "mins" } },
    { pattern = "^Your pet is hungry! %((%d+)%%%)$", key = "event.hungry_warning", payload = { "hunger" } },
    { pattern = "^Treat given! Hunger: (%d+)%% | Happiness: (%d+)%%$", key = "event.treat_used", payload = { "hunger", "happiness" } },
}

local function normalize_legacy_message(message)
    if type(message) ~= "string" then
        return nil
    end
    for _, item in ipairs(LEGACY_PATTERNS) do
        local caps = { message:match(item.pattern) }
        if #caps > 0 then
            local payload = {}
            for idx, k in ipairs(item.payload) do
                payload[k] = tonumber(caps[idx])
            end
            return item.key, payload
        end
    end
    return nil
end

function Events.normalize(raw)
    if not raw then return nil end

    local event = {
        type = raw.type,
        key = raw.key,
        payload = raw.payload or {},
        priority = raw.priority,
        cooldown_key = raw.cooldown_key,
    }

    if not event.key and event.type and TYPE_TO_KEY[event.type] then
        event.key = TYPE_TO_KEY[event.type]
    end

    if not event.key and raw.message then
        local key, payload = normalize_legacy_message(raw.message)
        if key then
            event.key = key
            for k, v in pairs(payload) do
                if event.payload[k] == nil then
                    event.payload[k] = v
                end
            end
        end
    end

    if not event.key and raw.message then
        event.key = raw.message
    end

    if event.priority == nil then
        if event.type and IMPORTANT_TYPES[event.type] then
            event.priority = "important"
        else
            event.priority = "routine"
        end
    end

    if event.cooldown_key == nil then
        event.cooldown_key = event.type or event.key
    end

    if raw.level and event.payload.level == nil then event.payload.level = raw.level end
    if raw.days and event.payload.days == nil then event.payload.days = raw.days end
    if raw.milestone and event.payload.milestone == nil then event.payload.milestone = raw.milestone end

    return event
end

function Events.normalize_list(raw_events)
    local out = {}
    if type(raw_events) ~= "table" then
        return out
    end
    for _, raw in ipairs(raw_events) do
        local ev = Events.normalize(raw)
        if ev then
            table.insert(out, ev)
        end
    end
    return out
end

function Events.split_by_priority(events)
    local important, routine = {}, {}
    for _, e in ipairs(events or {}) do
        if e.priority == "important" then
            table.insert(important, e)
        else
            table.insert(routine, e)
        end
    end
    return important, routine
end

return Events
