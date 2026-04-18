local Config = {}

local DEFAULT_CONFIG = {
    panel_mode = "detailed", -- auto | compact | normal | detailed
    notifications = "normal", -- quiet | normal | verbose
    routine_notify_cooldown = 30,
    pet_animation = true,
    pet_animation_interval = 1.6,
}

local function copy_table(tbl)
    local out = {}
    for k, v in pairs(tbl or {}) do
        out[k] = v
    end
    return out
end

function Config.get_defaults()
    return copy_table(DEFAULT_CONFIG)
end

function Config.merge(user_cfg)
    local cfg = Config.get_defaults()
    if type(user_cfg) == "table" then
        for k, v in pairs(user_cfg) do
            cfg[k] = v
        end
    end
    return cfg
end

return Config
