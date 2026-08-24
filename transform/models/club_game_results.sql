MODEL (
  name public.club_game_results,
  kind FULL,
  grain (game_pk, club_pk),
);

SELECT
  pk AS game_pk,
  home_club_pk AS club_pk,
  season,
  game_date,
  day_night,
  double_header,
  TRUE AS is_home,
  home_is_winner AS did_win
FROM public.games

UNION ALL

SELECT
  pk AS game_pk,
  away_club_pk AS club_pk,
  season,
  game_date,
  day_night,
  double_header,
  FALSE AS is_home,
  away_is_winner AS did_win
FROM public.games
