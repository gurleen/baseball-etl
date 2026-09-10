MODEL (
    name public.statcast_league_pitch_averages,
    kind FULL,
    grain (pk)
);

SELECT
    HASHTEXTEXTENDED(season::TEXT || ':' || pitch_type, 0)
        & x'7fffffffffffffff'::BIGINT AS pk,
    season::SMALLINT AS season,
    pitch_type::TEXT AS pitch_type,
    MAX(pitch_name)::TEXT AS pitch_name,

    COUNT(*)::INTEGER AS pitches,
    AVG(release_speed) AS avg_velocity,
    MAX(release_speed) AS max_velocity,
    AVG(spin_rate) AS avg_spin_rate,
    AVG(horizontal_break) AS avg_horizontal_break,
    AVG(induced_vertical_break) AS avg_induced_vertical_break,
    AVG(extension) AS avg_extension
FROM public.statcast_pitches
WHERE pitch_type IS NOT NULL
GROUP BY season, pitch_type;
