MODEL (
    name public.statcast_pitches,
    kind FULL,
    grain (pk)
);

SELECT
    -- identity / keys
    HASHTEXTEXTENDED(play_id, 0) & x'7fffffffffffffff'::BIGINT AS pk,
    HASHTEXTEXTENDED(
        '2:' || game_pk::TEXT || ':' || (ab_number - 1)::TEXT,
        0
    ) & x'7fffffffffffffff'::BIGINT AS play_pk,
    play_id::TEXT AS play_id,
    game_pk::BIGINT AS game_pk,
    ab_number::BIGINT AS ab_number,

    -- context
    year::SMALLINT AS season,
    inning::SMALLINT AS inning,
    half_inning::TEXT AS half_inning,
    outs::SMALLINT AS outs,
    pitch_number::SMALLINT AS pitch_number,

    -- participants
    batter::BIGINT AS batter_pk,
    pitcher::BIGINT AS pitcher_pk,
    catcher::BIGINT AS catcher_pk,
    stand::TEXT AS batter_stand,
    p_throws::TEXT AS pitcher_throws,
    team_batting_id::BIGINT AS team_batting_id,
    team_fielding_id::BIGINT AS team_fielding_id,

    -- count (before/after this pitch)
    pre_balls::SMALLINT AS balls_before,
    pre_strikes::SMALLINT AS strikes_before,
    balls::SMALLINT AS balls_after,
    strikes::SMALLINT AS strikes_after,

    -- pitch identity / call outcome
    pitch_type::TEXT AS pitch_type,
    pitch_name::TEXT AS pitch_name,
    pitch_call::TEXT AS pitch_call,
    description::TEXT AS pitch_description,
    is_strike_swinging::BOOLEAN AS is_strike_swinging,
    savant_is_in_zone::BOOLEAN AS is_in_zone,

    -- at-bat result context carried on the pitch record
    events::TEXT AS event_type,

    -- pitch physics
    start_speed::DOUBLE PRECISION AS release_speed,
    end_speed::DOUBLE PRECISION AS plate_speed,
    extension::DOUBLE PRECISION AS extension,
    spin_rate::BIGINT AS spin_rate,
    pfx_x::DOUBLE PRECISION AS horizontal_break,
    pfx_z::DOUBLE PRECISION AS induced_vertical_break,
    plate_x::DOUBLE PRECISION AS plate_x,
    plate_z::DOUBLE PRECISION AS plate_z,
    sz_top::DOUBLE PRECISION AS strike_zone_top,
    sz_bot::DOUBLE PRECISION AS strike_zone_bottom,
    zone::SMALLINT AS zone,
    x0::DOUBLE PRECISION AS release_pos_x,
    y0::DOUBLE PRECISION AS release_pos_y,
    z0::DOUBLE PRECISION AS release_pos_z,
    vx0::DOUBLE PRECISION AS vx0,
    vy0::DOUBLE PRECISION AS vy0,
    vz0::DOUBLE PRECISION AS vz0,
    ax::DOUBLE PRECISION AS ax,
    ay::DOUBLE PRECISION AS ay,
    az::DOUBLE PRECISION AS az,

    -- swing flags (batted-ball detail lives in statcast_batted_balls)
    bat_speed::DOUBLE PRECISION AS bat_speed,
    is_bip_out = 'Y' AS is_bip_out,
    is_sword::BOOLEAN AS is_sword,

    -- game-state counters
    pitcher_pa_number::SMALLINT AS pitcher_pa_number,
    pitcher_time_thru_order::SMALLINT AS pitcher_time_thru_order,
    game_total_pitches::SMALLINT AS game_total_pitches,
    player_total_pitches::SMALLINT AS pitcher_total_pitches
FROM raw.statcast_pitches;
