local Config = {
  enabled = true,
  -- Set this to >0 if some animations break without a tiny delay
  min_duration = 0,
  -- Allow certain ambience effects (like menu background) to linger slightly
  background_duration = 0.18,
  features = {
    skip_card_flips = true,
    skip_pack_open = true,
    skip_shop_reveal = true,
    skip_blinds_intro = true,
    instant_scoring = true,
    fast_deck_shuffle = true,
    fast_vouchers = true,
    allow_background_transition = true
  }
}

return Config
