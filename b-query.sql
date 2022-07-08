SELECT
    "b_age_attributes"."value" AS age,
    "bs".*,
    "bs"."id" AS t0_r0,
    "as"."id" AS t1_r0,
    "as"."created_at" AS t1_r1
FROM (
    SELECT
        "bs".*,
        '2022-07-28 07:48:56.654513'::timestamp AS current_time
    FROM
        "bs") "bs"
    INNER JOIN "b_age_attributes" ON "b_age_attributes"."entity_id" = "bs"."id"
    LEFT OUTER JOIN "as_bs" ON "as_bs"."right_id" = "bs"."id"
        AND ("as_bs"."valid_at" = (
                SELECT
                    max("sub"."valid_at")
                FROM
                    "as_bs" sub
            WHERE ("sub"."valid_at" <= "bs"."current_time")
            AND ("sub"."right_id" = "as_bs"."right_id")))
    LEFT OUTER JOIN "as" ON "as"."id" = "as_bs"."left_id"
WHERE ("b_age_attributes"."valid_at" = (
        SELECT
            max("sub"."valid_at")
        FROM
            "b_age_attributes" sub
        WHERE ("sub"."entity_id" = "b_age_attributes".entity_id)
        AND ("sub"."valid_at" <= "bs"."current_time")))
