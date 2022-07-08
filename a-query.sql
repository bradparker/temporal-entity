SELECT
    "a_name_attributes"."value" AS name,
    "a_age_attributes"."value" AS age,
    "as".*,
    "as"."id" AS t0_r0,
    "bs"."id" AS t1_r0,
    "bs"."created_at" AS t1_r1
FROM (
    SELECT
        "as".*,
        '2022-07-28 07:33:50.426896'::timestamp AS current_time
    FROM
        "as") "as"
    INNER JOIN "a_name_attributes" ON "a_name_attributes"."entity_id" = "as"."id"
    INNER JOIN "a_age_attributes" ON "a_age_attributes"."entity_id" = "as"."id"
    LEFT OUTER JOIN "as_bs" ON "as_bs"."left_id" = "as"."id"
        AND ("as_bs"."valid_at" = (
                SELECT
                    max("sub"."valid_at")
                FROM
                    "as_bs" sub
            WHERE ("sub"."valid_at" <= "as"."current_time")
            AND ("sub"."right_id" = "as_bs"."right_id")))
    LEFT OUTER JOIN "bs" ON "bs"."id" = "as_bs"."right_id"
WHERE ("a_name_attributes"."valid_at" = (
        SELECT
            max("sub"."valid_at")
        FROM
            "a_name_attributes" sub
        WHERE ("sub"."entity_id" = "a_name_attributes".entity_id)
        AND ("sub"."valid_at" <= "as"."current_time")))
AND ("a_age_attributes"."valid_at" = (
        SELECT
            max("sub"."valid_at")
        FROM
            "a_age_attributes" sub
        WHERE ("sub"."entity_id" = "a_age_attributes".entity_id)
        AND ("sub"."valid_at" <= "as"."current_time")))
