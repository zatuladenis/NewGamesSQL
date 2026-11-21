/* Анализ монетизации RPG-игры «Секреты Темнолесья»
 * Часть 1. Исследовательский анализ данных (EDA)
 *
 * Цель: оценить долю платящих игроков в целом и по расам, распределение стоимости
 * внутриигровых покупок, объем нулевых транзакций и концентрацию спроса на эпические предметы.
 *
 * Автор: Затула Денис Викторович
 * Дата: 20.04.2026
 */

-- 1.1. Расчет общей доли платящих игроков (приобретающих валюту «райские лепестки» за реальные деньги)
-- Результат: 3 929 из 22 214 зарегистрированных игроков (17,69%).
SELECT
    COUNT(*) AS total_players,
    SUM(payer) AS paying_players,
    ROUND(SUM(payer)::numeric / COUNT(*), 4) AS players_share
FROM fantasy.users;


-- 1.2. Расчет доли платящих игроков в разрезе расы персонажа
-- Результат: диапазон долей составляет 17–19% (лидер — Demon 19%, минимум — Elf и Angel по 17%).
SELECT
    r.race AS name_race,
    COUNT(*) AS total_players,
    SUM(payer) AS paying_players,
    ROUND(SUM(payer)::NUMERIC / COUNT(*), 2) AS players_share
FROM fantasy.race AS r
LEFT JOIN fantasy.users AS u ON r.race_id = u.race_id
GROUP BY r.race
ORDER BY players_share DESC;


-- 2.1. Описательные статистики стоимости внутриигровых покупок (поле amount)
-- Результат: 1 307 678 покупок на сумму 686 615 040; min = 0,0, max = 486 615,1,
-- среднее = 525,69, медиана = 74,86, стандартное отклонение = 2 517,35.
SELECT
    COUNT(*) AS count_purchases,
    SUM(amount) AS sum_amount,
    MIN(amount) AS min_purchases_price,
    MAX(amount) AS max_purchases_price,
    ROUND(AVG(amount)::numeric, 2) AS avg_amount,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS mediana_amount,
    ROUND(STDDEV(amount)::numeric, 2) AS stddev_amount
FROM fantasy.events;


-- 2.2. Оценка объема и доли аномальных покупок с нулевой стоимостью (amount = 0)
-- Результат: 907 транзакций (0,07% от всех покупок); в дальнейших расчетах исключаются.
SELECT
    COUNT(*) AS zero_purchases,
    ROUND(COUNT(*)::numeric / (SELECT COUNT(*) FROM fantasy.events), 4) AS zero_share
FROM fantasy.events
WHERE amount = 0;


-- 2.3. Рейтинг популярности эпических предметов по объему платных продаж и охвату покупателей
-- Считаем количество платных покупок (amount > 0) для каждого предмета
WITH paid_purchases AS (
    SELECT
        e.item_code,
        COUNT(e.transaction_id) AS count_purchases
    FROM fantasy.events AS e
    WHERE e.amount > 0
    GROUP BY e.item_code
),
-- Считаем общий объем платных покупок по всей игре для расчета долей
paid_purchases_total AS (
    SELECT
        COUNT(e.transaction_id) AS all_purchases
    FROM fantasy.events AS e
    WHERE e.amount > 0
),
-- Считаем общее число уникальных игроков, совершивших хотя бы одну платную покупку
all_buyers_players AS (
    SELECT
        COUNT(DISTINCT e.id) AS total_players
    FROM fantasy.events AS e
    WHERE e.amount > 0
),
-- Считаем число уникальных покупателей в разрезе каждого эпического предмета
item_buyers_players AS (
    SELECT
        i.game_items AS name_item,
        e.item_code,
        COUNT(DISTINCT e.id) AS total_players_buy_item
    FROM fantasy.events AS e
    LEFT JOIN fantasy.items AS i ON e.item_code = i.item_code
    WHERE e.amount > 0
    GROUP BY e.item_code, i.game_items
)
-- Формируем итоговый рейтинг предметов с долей от всех платных покупок и долей охвата покупателей
-- Топ-3: Book of Legends (76,87% / 88,41%), Bag of Holding (20,81% / 86,77%), Necklace of Wisdom (1,06% / 11,80%).
SELECT
    pp.item_code,
    ibp.name_item,
    pp.count_purchases,
    ROUND(pp.count_purchases::numeric / ppt.all_purchases, 4) AS share_purchases,
    ibp.total_players_buy_item,
    ROUND(ibp.total_players_buy_item::numeric / abp.total_players, 4) AS share_players
FROM paid_purchases AS pp
LEFT JOIN item_buyers_players AS ibp ON pp.item_code = ibp.item_code
CROSS JOIN paid_purchases_total AS ppt
CROSS JOIN all_buyers_players AS abp
ORDER BY ibp.total_players_buy_item DESC;
