MODEL (
    name public.statcast_batted_balls,
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

    -- context (kept so this model stands alone / joins to plays independently)
    year::SMALLINT AS season,
    inning::SMALLINT AS inning,
    half_inning::TEXT AS half_inning,
    outs::SMALLINT AS outs,

    -- participants
    batter::BIGINT AS batter_pk,
    pitcher::BIGINT AS pitcher_pk,
    stand::TEXT AS batter_stand,
    p_throws::TEXT AS pitcher_throws,
    team_batting_id::BIGINT AS team_batting_id,
    team_fielding_id::BIGINT AS team_fielding_id,

    -- pitch that was put in play
    pitch_type::TEXT AS pitch_type,
    pitch_name::TEXT AS pitch_name,

    -- batted-ball outcome
    events::TEXT AS event_type,
    launch_speed::DOUBLE PRECISION AS exit_velocity,
    launch_angle::DOUBLE PRECISION AS launch_angle,
    hit_distance::DOUBLE PRECISION AS hit_distance,
    xba::DOUBLE PRECISION AS expected_batting_avg,
    is_barrel = 1 AS is_barrel,
    is_bip_out = 'Y' AS is_bip_out,

    -- spray chart coordinates
    hc_x::DOUBLE PRECISION AS hit_coord_x,
    hc_y::DOUBLE PRECISION AS hit_coord_y,
    hc_x_ft::DOUBLE PRECISION AS hit_coord_x_ft,
    hc_y_ft::DOUBLE PRECISION AS hit_coord_y_ft
FROM raw.statcast_batted_balls;
