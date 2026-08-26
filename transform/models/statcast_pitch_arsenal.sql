MODEL (
    name public.statcast_pitch_arsenal,
    kind FULL,
    grain (pk)
);

WITH pitches AS (
    SELECT
        season,
        pitcher_pk,
        pitch_type,
        pitch_name,
        pitch_call,
        is_in_zone,
        event_type,
        strikes_before,
        release_speed,
        spin_rate,
        extension,
        horizontal_break,
        induced_vertical_break,
        pitch_call IN (
            'foul', 'foul_tip', 'foul_bunt', 'bunt_foul_tip',
            'hit_into_play',
            'swinging_strike', 'swinging_strike_blocked',
            'missed_bunt', 'swinging_pitchout'
        ) AS is_swing,
        pitch_call IN (
            'swinging_strike', 'swinging_strike_blocked',
            'missed_bunt', 'swinging_pitchout'
        ) AS is_whiff
    FROM public.statcast_pitches
    WHERE pitch_type IS NOT NULL
),
pitcher_totals AS (
    SELECT season, pitcher_pk, COUNT(*) AS total_pitches
    FROM pitches
    GROUP BY season, pitcher_pk
)

SELECT
    HASHTEXTEXTENDED(
        p.season::TEXT || ':' || p.pitcher_pk::TEXT || ':' || p.pitch_type,
        0
    ) & x'7fffffffffffffff'::BIGINT AS pk,
    p.season::SMALLINT AS season,
    p.pitcher_pk::BIGINT AS pitcher_pk,
    p.pitch_type::TEXT AS pitch_type,
    MAX(p.pitch_name)::TEXT AS pitch_name,

    -- volume / usage
    COUNT(*)::INTEGER AS pitches,
    (COUNT(*)::NUMERIC / MAX(pt.total_pitches)) AS usage_pct,

    -- velocity
    AVG(p.release_speed) AS avg_velocity,
    MAX(p.release_speed) AS max_velocity,

    -- spin
    AVG(p.spin_rate) AS avg_spin_rate,

    -- extension
    AVG(p.extension) AS avg_extension,

    -- movement profile
    AVG(p.horizontal_break) AS avg_horizontal_break,
    AVG(p.induced_vertical_break) AS avg_induced_vertical_break,

    -- plate discipline / results
    COUNT(*) FILTER (WHERE p.is_swing)::INTEGER AS swings,
    COUNT(*) FILTER (WHERE p.is_whiff)::INTEGER AS whiffs,
    (COUNT(*) FILTER (WHERE p.is_swing)::NUMERIC / NULLIF(COUNT(*), 0)) AS swing_pct,
    (COUNT(*) FILTER (WHERE p.is_whiff)::NUMERIC / NULLIF(COUNT(*) FILTER (WHERE p.is_swing), 0)) AS whiff_pct,
    (COUNT(*) FILTER (WHERE p.is_in_zone)::NUMERIC / NULLIF(COUNT(*), 0)) AS zone_pct,
    (COUNT(*) FILTER (WHERE p.is_swing AND NOT p.is_in_zone)::NUMERIC
        / NULLIF(COUNT(*) FILTER (WHERE NOT p.is_in_zone), 0)) AS chase_pct,

    -- two-strike putaway rate: share of two-strike pitches with this pitch
    -- type that end the at-bat via strikeout
    COUNT(*) FILTER (WHERE p.strikes_before = 2)::INTEGER AS two_strike_pitches,
    (COUNT(*) FILTER (
        WHERE p.strikes_before = 2 AND p.event_type IN ('Strikeout', 'Strikeout Double Play')
    )::NUMERIC / NULLIF(COUNT(*) FILTER (WHERE p.strikes_before = 2), 0)) AS putaway_pct
FROM pitches AS p
JOIN pitcher_totals AS pt
    ON pt.season = p.season AND pt.pitcher_pk = p.pitcher_pk
GROUP BY p.season, p.pitcher_pk, p.pitch_type;
