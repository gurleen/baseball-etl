MODEL (
  name public.games,
  kind FULL,
  grain (pk),
);

SELECT
  game_pk AS pk,
  game_guid,
  game_type,
  season::SMALLINT AS season,
  game_date,
  official_date::DATE AS official_date,
  day_night,
  double_header,
  game_number,
  scheduled_innings,
  games_in_series,
  series_game_number,
  series_description,
  venue__id AS venue_pk,
  teams__home__team__id AS home_club_pk,
  teams__home__score AS home_score,
  teams__home__is_winner AS home_is_winner,
  teams__away__team__id AS away_club_pk,
  teams__away__score AS away_score,
  teams__away__is_winner AS away_is_winner,
  status__abstract_game_state AS abstract_game_state,
  status__coded_game_state AS coded_game_state,
  status__detailed_state AS detailed_state
FROM raw.games
