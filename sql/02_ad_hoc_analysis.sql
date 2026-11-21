/* Анализ монетизации RPG-игры «Секреты Темнолесья»
 * Часть 2. Анализ зависимости покупательской активности от расы персонажа
 *
 * Цель: сравнить конверсию в покупку, долю платящих пользователей, частоту покупок,
 * средний чек и суммарные траты на одного покупателя в разрезе рас персонажей.
 *
 * Автор: Затула Денис Викторович
 * Дата: 20.04.2026
 */

-- Считаем общее число зарегистрированных игроков для каждой расы
WITH total_register_players_by_race AS (
    SELECT
        r.race,
        COUNT(DISTINCT u.id) AS total_players
    FROM fantasy.race AS r
    LEFT JOIN fantasy.users AS u ON r.race_id = u.race_id
    GROUP BY r.race
),
-- Считаем число игроков каждой расы, совершивших хотя бы одну платную внутриигровую покупку
total_buyers_players_by_race AS (
    SELECT
        r.race,
        COUNT(DISTINCT u.id) AS total_buyers_players
    FROM fantasy.race AS r
    LEFT JOIN fantasy.users AS u ON r.race_id = u.race_id
    LEFT JOIN fantasy.events AS e ON u.id = e.id
    WHERE e.amount > 0
    GROUP BY r.race
),
-- Считаем число платящих игроков (payer = 1) среди совершивших внутриигровые покупки
total_payers_buyers_by_race AS (
    SELECT
        r.race,
        COUNT(DISTINCT u.id) AS total_payers_buyers_players
    FROM fantasy.race AS r
    LEFT JOIN fantasy.users AS u ON r.race_id = u.race_id
    LEFT JOIN fantasy.events AS e ON u.id = e.id
    WHERE e.amount > 0 AND u.payer = 1
    GROUP BY r.race
),
-- Считаем долю покупателей от общего числа зарегистрированных игроков по расам
share_buyers_players_by_race AS (
    SELECT
        trp.race,
        ROUND(tbp.total_buyers_players::NUMERIC / trp.total_players, 4) AS share_buyers_players
    FROM total_register_players_by_race AS trp
    LEFT JOIN total_buyers_players_by_race AS tbp ON trp.race = tbp.race
),
-- Считаем долю платящих игроков среди активных покупателей по расам
share_payers_buyers_by_race AS (
    SELECT
        tbp.race,
        ROUND(tpb.total_payers_buyers_players::NUMERIC / tbp.total_buyers_players, 4) AS share_payers_buyers
    FROM total_buyers_players_by_race AS tbp
    LEFT JOIN total_payers_buyers_by_race AS tpb ON tbp.race = tpb.race
),
-- Агрегируем количество платных покупок на уровне каждого покупателя
count_player_purchases AS (
    SELECT
        e.id,
        COUNT(e.transaction_id) AS total_purchases_per_player
    FROM fantasy.events AS e
    WHERE e.amount > 0
    GROUP BY e.id
),
-- Считаем среднее количество покупок на одного покупателя в разрезе рас
avg_count_player_purchases_by_race AS (
    SELECT
        r.race,
        ROUND(AVG(cpp.total_purchases_per_player), 2) AS avg_count_purchases_per_player
    FROM count_player_purchases AS cpp
    LEFT JOIN fantasy.users AS u ON cpp.id = u.id
    LEFT JOIN fantasy.race AS r ON u.race_id = r.race_id
    GROUP BY r.race
),
-- Агрегируем число транзакций и суммарный объем трат по каждому покупателю
player_purchases_stats AS (
    SELECT
        e.id,
        COUNT(e.transaction_id) AS count_purchase_player,
        SUM(e.amount) AS sum_amount_players
    FROM fantasy.events AS e
    WHERE e.amount > 0
    GROUP BY e.id
),
-- Считаем среднюю стоимость одной покупки (средний чек) в разрезе рас
avg_price_per_purchase AS (
    SELECT
        r.race,
        ROUND(SUM(pps.sum_amount_players)::NUMERIC / SUM(pps.count_purchase_player), 2) AS avg_price_per_purchase
    FROM player_purchases_stats AS pps
    LEFT JOIN fantasy.users AS u ON pps.id = u.id
    LEFT JOIN fantasy.race AS r ON u.race_id = r.race_id
    GROUP BY r.race
),
-- Считаем среднюю суммарную стоимость покупок на одного покупателя по расам
avg_total_spent_per_buyer AS (
    SELECT
        r.race,
        ROUND(AVG(pps.sum_amount_players)::NUMERIC, 2) AS avg_total_spent_per_buyer
    FROM player_purchases_stats AS pps
    LEFT JOIN fantasy.users AS u ON pps.id = u.id
    LEFT JOIN fantasy.race AS r ON u.race_id = r.race_id
    GROUP BY r.race
)
-- Собираем сводную витрину метрик покупательской активности по расам персонажей
SELECT
    trp.race,
    trp.total_players,
    tbp.total_buyers_players,
    sbp.share_buyers_players,
    spb.share_payers_buyers,
    acp.avg_count_purchases_per_player,
    app.avg_price_per_purchase,
    ats.avg_total_spent_per_buyer
FROM total_register_players_by_race AS trp
LEFT JOIN total_buyers_players_by_race AS tbp ON trp.race = tbp.race
LEFT JOIN share_buyers_players_by_race AS sbp ON trp.race = sbp.race
LEFT JOIN share_payers_buyers_by_race AS spb ON trp.race = spb.race
LEFT JOIN avg_count_player_purchases_by_race AS acp ON trp.race = acp.race
LEFT JOIN avg_price_per_purchase AS app ON trp.race = app.race
LEFT JOIN avg_total_spent_per_buyer AS ats ON trp.race = ats.race
ORDER BY tbp.total_buyers_players DESC;
