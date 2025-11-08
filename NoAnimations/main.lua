local ok_cfg, Config = pcall(require, 'config')
if not ok_cfg then
  Config = {
    enabled = true,
    min_duration = 0,
    features = {
      skip_card_flips = true,
    },
  }
end

local function log(...)
  if print then
    print('[NoAnimations]', ...)
  end
end

local function safe_get(tbl, key)
  if type(tbl) == 'table' then
    return tbl[key]
  end
end

local NA = rawget(_G, 'NoAnimations') or {}
_G.NoAnimations = NA
NA.enabled = (Config.enabled ~= false)
NA._wrapped = NA._wrapped or {}
NA._patched = NA._patched or {}

function NA.set_enabled(v)
  local flag = not not v
  NA.enabled = flag
  Config.enabled = flag
  log('Enabled =', flag)
end

local function is_enabled()
  return NA.enabled ~= false
end

local unpack_f = table.unpack or _G.unpack
if not unpack_f then
  local function recursive_unpack(list, i)
    if i > #list then
      return nil
    end
    return list[i], recursive_unpack(list, i + 1)
  end
  unpack_f = function(list)
    return recursive_unpack(list, 1)
  end
end

local function min_duration()
  local value = Config.min_duration
  if type(value) ~= 'number' or value < 0 then
    value = 0
  end
  return value
end

local background_labels = {
  transition = true,
  fade = true,
  fade_to = true,
}

local function target_duration(label)
  local base = min_duration()
  if label and background_labels[label] and Config.features and Config.features.allow_background_transition ~= false then
    local bg = Config.background_duration
    if type(bg) ~= 'number' or bg < base then
      bg = math.max(base, 0.18)
    end
    return bg
  end
  return base
end

local function clamp_duration(x, label)
  if type(x) ~= 'number' then
    return x
  end
  local limit = target_duration(label)
  if x > limit then
    x = limit
  end
  if x < 0 then
    x = 0
  end
  return x
end

local function wrap_function_numeric(container, key, label)
  local original = safe_get(container, key)
  if type(original) ~= 'function' then
    return false
  end
  if NA._wrapped[original] then
    return false
  end

  container[key] = function(...)
    if not is_enabled() then
      return original(...)
    end
    local args = { ... }
    local changed = false
    local limit = target_duration(label)
    for i = 1, #args do
      if type(args[i]) == 'number' and args[i] > limit then
        args[i] = limit
        changed = true
      end
    end
    if changed then
      return original(unpack_f(args))
    end
    return original(...)
  end

  NA._wrapped[original] = true
  NA._wrapped[container[key]] = true
  log('Patched function:', label)
  return true
end

local function wrap_method_first_numeric(container, key, label)
  local original = safe_get(container, key)
  if type(original) ~= 'function' then
    return false
  end
  if NA._wrapped[original] then
    return false
  end

  container[key] = function(self, first, ...)
    if is_enabled() and type(first) == 'number' then
      first = clamp_duration(first, label)
    end
    return original(self, first, ...)
  end

  NA._wrapped[original] = true
  NA._wrapped[container[key]] = true
  log('Patched method:', label)
  return true
end

local function patch_global_helpers()
  local count = 0
  local targets = {
    'delay', 'wait', 'ease', 'transition', 'shake',
    'pulse', 'bounce', 'fade', 'fade_to', 'slide',
    'pop_in', 'pop_out', 'flash', 'tween', 'lerp',
  }
  for _, name in ipairs(targets) do
    if wrap_function_numeric(_G, name, name) then
      count = count + 1
    end
  end
  return count
end

local function patch_timer_library()
  local patched = 0
  if type(_G.Timer) == 'table' then
    patched = patched + (wrap_function_numeric(_G.Timer, 'tween', 'Timer.tween') and 1 or 0)
    patched = patched + (wrap_function_numeric(_G.Timer, 'after', 'Timer.after') and 1 or 0)
    patched = patched + (wrap_function_numeric(_G.Timer, 'every', 'Timer.every') and 1 or 0)
  end
  if type(_G.timer) == 'table' then
    patched = patched + (wrap_function_numeric(_G.timer, 'tween', 'timer.tween') and 1 or 0)
    patched = patched + (wrap_function_numeric(_G.timer, 'after', 'timer.after') and 1 or 0)
    patched = patched + (wrap_function_numeric(_G.timer, 'every', 'timer.every') and 1 or 0)
  end
  return patched
end

local function patch_flux_library()
  local patched = 0
  local flux = _G.flux
  if type(flux) == 'table' then
    patched = patched + (wrap_function_numeric(flux, 'to', 'flux.to') and 1 or 0)
    patched = patched + (wrap_function_numeric(flux, 'from', 'flux.from') and 1 or 0)
    patched = patched + (wrap_function_numeric(flux, 'update', 'flux.update') and 1 or 0)
  end
  return patched
end

local function patch_tween_library()
  local patched = 0
  local tween = _G.tween
  if type(tween) == 'table' then
    patched = patched + (wrap_function_numeric(tween, 'new', 'tween.new') and 1 or 0)
  end
  return patched
end

local function patch_card_methods()
  local G = _G.G
  if type(G) ~= 'table' then
    return 0
  end
  local Card = G.Card or safe_get(G, 'CARD') or safe_get(G, 'CardClass')
  if type(Card) ~= 'table' then
    return 0
  end
  local hits = 0
  local method_names = {
    'flip', 'move', 'shake', 'bounce', 'pop_in', 'pop_out',
    'rotate', 'set_animation', 'set_tween', 'setTween', 'set_tilt',
  }
  for _, name in ipairs(method_names) do
    if wrap_method_first_numeric(Card, name, 'Card:' .. name) then
      hits = hits + 1
    end
  end
  return hits
end

local function patch_event_manager()
  local G = _G.G
  if type(G) ~= 'table' then
    return 0
  end
  local manager = G.E_MANAGER or safe_get(G, 'E_MANAGER')
  if type(manager) ~= 'table' then
    return 0
  end
  if NA._patched.event_manager then
    return 0
  end

  local original_add_event = manager.add_event
  local original_prepare_event = manager.prepare_event

  if type(original_add_event) == 'function' then
    manager.add_event = function(self, event)
      if is_enabled() and type(event) == 'table' then
        if type(event.delay) == 'number' then
          event.delay = clamp_duration(event.delay, 'event_delay')
        end
        if type(event.timer) == 'number' then
          event.timer = clamp_duration(event.timer, 'event_timer')
        end
      end
      return original_add_event(self, event)
    end
  end

  if type(original_prepare_event) == 'function' then
    manager.prepare_event = function(self, event)
      if is_enabled() and type(event) == 'table' then
        if type(event.delay) == 'number' then
          event.delay = clamp_duration(event.delay, 'event_delay')
        end
        if type(event.timer) == 'number' then
          event.timer = clamp_duration(event.timer, 'event_timer')
        end
      end
      return original_prepare_event(self, event)
    end
  end

  NA._patched.event_manager = true
  log('Patched event manager to clamp delays')
  return 2
end

local function patch_game_settings()
  local G = _G.G
  if type(G) ~= 'table' then
    return 0
  end
  local settings = G.SETTINGS or G.settings
  if type(settings) ~= 'table' then
    return 0
  end
  local hits = 0

  local bool_keys = {
    'FAST', 'FAST_MODE', 'FASTFORWARD', 'FAST_FORWARD', 'ALWAYS_FAST_FORWARD',
    'SKIP_ANIM', 'SKIP_CARD_EFFECTS'
  }
  for _, key in ipairs(bool_keys) do
    if settings[key] ~= nil and settings[key] ~= true then
      settings[key] = true
      hits = hits + 1
      log('Enabled setting', key)
    end
  end

  local base_limit = target_duration()
  if base_limit <= 0 then
    base_limit = 0
  end

  local numeric_keys = {
    'ANIMATION_SPEED', 'ANIM_SPEED', 'DEAL_SPEED', 'FLIP_SPEED',
    'FX_SPEED', 'ANIMATION_MIN', 'TWEEN_SPEED', 'FASTFORWARD_SPEED'
  }
  for _, key in ipairs(numeric_keys) do
    if type(settings[key]) == 'number' and settings[key] > base_limit then
      settings[key] = base_limit
      hits = hits + 1
      log('Set', key, 'to', base_limit)
    end
  end

  if settings.HAND_LIMIT ~= nil then
    if type(settings.HAND_LIMIT) ~= 'table' then
      settings.HAND_LIMIT = { play = 0, discard = 0 }
      hits = hits + 1
      log('Rebuilt HAND_LIMIT table')
    else
      if type(settings.HAND_LIMIT.play) ~= 'number' then
        settings.HAND_LIMIT.play = tonumber(settings.HAND_LIMIT.play) or 0
        hits = hits + 1
        log('Normalized HAND_LIMIT.play')
      end
      if type(settings.HAND_LIMIT.discard) ~= 'number' then
        settings.HAND_LIMIT.discard = tonumber(settings.HAND_LIMIT.discard) or 0
        hits = hits + 1
        log('Normalized HAND_LIMIT.discard')
      end
    end
  end

  return hits
end

local function patch_hand_limits()
  local G = _G.G
  if type(G) ~= 'table' then
    return 0
  end
  local hand = ((((G or {}).GAME or {}).misc) or {}).hand
  if type(hand) ~= 'table' then
    return 0
  end
  local hits = 0
  if type(hand.discard) == 'table' then
    if type(hand.discard.delay) == 'number' then
      hand.discard.delay = clamp_duration(hand.discard.delay, 'hand_delay')
      hits = hits + 1
    end
  end
  if type(hand.play) == 'table' then
    if type(hand.play.delay) == 'number' then
      hand.play.delay = clamp_duration(hand.play.delay, 'hand_delay')
      hits = hits + 1
    end
  end
  return hits
end

local function apply_patches()
  if not is_enabled() then
    log('Config disables mod; skipping patches.')
    return
  end

  local total = 0
  total = total + patch_global_helpers()
  total = total + patch_timer_library()
  total = total + patch_flux_library()
  total = total + patch_tween_library()
  total = total + patch_card_methods()
  total = total + patch_event_manager()
  total = total + patch_game_settings()
  total = total + patch_hand_limits()

  if total > 0 then
    log('Patched symbols count =', total)
  else
    log('No known symbols were patched. Game version may differ; mod remains safe.')
  end
end

local ok, err = pcall(apply_patches)
if not ok then
  log('Error while applying patches:', err)
end

pcall(require, 'gui')



return true

