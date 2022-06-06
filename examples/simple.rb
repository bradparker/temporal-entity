require "logger"
require "securerandom"
require_relative "../lib/temporal_entity"

# ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Base.establish_connection(ENV["DATABASE_URL"])

connection = ActiveRecord::Base.connection

connection.create_table :as, force: :cascade

connection.create_table :a_name_attributes, force: :cascade do |t|
  t.text :value

  t.belongs_to :entity, null: false, foreign_key: {to_table: :as}

  t.datetime :valid_at, null: false, index: true
  t.datetime :invalid_at, null: true, index: true
  t.virtual :valid_time_range, type: :tsrange, as: "tsrange(valid_at, invalid_at)", stored: true, index: true

  t.check_constraint "valid_at < invalid_at"
end

# TODO it'd be nice to ensure that attribute ranges have no gaps.
connection.execute <<~SQL
  CREATE EXTENSION IF NOT EXISTS btree_gist;

  ALTER TABLE a_name_attributes
    ADD CONSTRAINT a_name_attributes_validity_range
    EXCLUDE USING GIST (entity_id WITH =, valid_time_range WITH &&)
SQL

connection.create_table :a_age_attributes, force: :cascade do |t|
  t.integer :value

  t.belongs_to :entity, null: false, foreign_key: {to_table: :as}

  t.datetime :valid_at, null: false, index: true
  t.datetime :invalid_at, null: true, index: true
  t.virtual :valid_time_range, type: :tsrange, as: "tsrange(valid_at, invalid_at)", stored: true, index: true

  t.check_constraint "valid_at < invalid_at"
end

connection.execute <<~SQL
  ALTER TABLE a_age_attributes
    ADD CONSTRAINT a_age_attributes_validity_range
    EXCLUDE USING GIST (entity_id WITH =, valid_time_range WITH &&)
SQL

connection.create_table :bs, force: :cascade

connection.create_table :b_age_attributes, force: :cascade do |t|
  t.integer :value

  t.belongs_to :entity, null: false, foreign_key: {to_table: :bs}

  t.datetime :valid_at, null: false, index: true
  t.datetime :invalid_at, null: true, index: true
  t.virtual :valid_time_range, type: :tsrange, as: "tsrange(valid_at, invalid_at)", stored: true, index: true

  t.check_constraint "valid_at < invalid_at"
end

connection.execute <<~SQL
  ALTER TABLE b_age_attributes
    ADD CONSTRAINT b_age_attributes_validity_range
    EXCLUDE USING GIST (entity_id WITH =, valid_time_range WITH &&)
SQL

connection.create_table :cs, force: :cascade

connection.create_table :c_name_attributes, force: :cascade do |t|
  t.text :value

  t.belongs_to :entity, null: false, foreign_key: {to_table: :cs}

  t.datetime :valid_at, null: false, index: true
  t.datetime :invalid_at, null: true, index: true
  t.virtual :valid_time_range, type: :tsrange, as: "tsrange(valid_at, invalid_at)", stored: true, index: true

  t.check_constraint "valid_at < invalid_at"
end

connection.execute <<~SQL
  ALTER TABLE c_name_attributes
    ADD CONSTRAINT c_name_attributes_validity_range
    EXCLUDE USING GIST (entity_id WITH =, valid_time_range WITH &&)
SQL

connection.create_table :as_bs, force: :cascade do |t|
  t.belongs_to :left, null: false, foreign_key: {to_table: :as}
  t.belongs_to :right, null: false, foreign_key: {to_table: :bs}

  t.datetime :valid_at, null: false, index: true
  t.datetime :invalid_at, null: true, index: true
  t.virtual :valid_time_range, type: :tsrange, as: "tsrange(valid_at, invalid_at)", stored: true, index: true

  t.check_constraint "valid_at < invalid_at"
end

connection.execute <<~SQL
  ALTER TABLE as_bs
    ADD CONSTRAINT as_bs_validity_range
    EXCLUDE USING GIST (right_id WITH =, valid_time_range WITH &&)
SQL

connection.create_table :as_cs, force: :cascade do |t|
  t.belongs_to :left, null: false, foreign_key: {to_table: :as}
  t.belongs_to :right, null: false, foreign_key: {to_table: :cs}

  t.datetime :valid_at, null: false, index: true
  t.datetime :invalid_at, null: true, index: true
  t.virtual :valid_time_range, type: :tsrange, as: "tsrange(valid_at, invalid_at)", stored: true, index: true

  t.check_constraint "valid_at < invalid_at"
end

connection.execute <<~SQL
  ALTER TABLE as_cs
    ADD CONSTRAINT as_cs_left_validity_range
    EXCLUDE USING GIST (left_id WITH =, valid_time_range WITH &&);

  ALTER TABLE as_cs
    ADD CONSTRAINT as_cs_right_validity_range
    EXCLUDE USING GIST (right_id WITH =, valid_time_range WITH &&)
SQL

connection.create_table :bs_cs, force: :cascade do |t|
  t.belongs_to :left, null: false, foreign_key: {to_table: :as}
  t.belongs_to :right, null: false, foreign_key: {to_table: :cs}

  t.datetime :valid_at, null: false, index: true
  t.datetime :invalid_at, null: true, index: true
  t.virtual :valid_time_range, type: :tsrange, as: "tsrange(valid_at, invalid_at)", stored: true, index: true

  t.check_constraint "valid_at < invalid_at"
end

connection.execute <<~SQL
  ALTER TABLE bs_cs
    ADD CONSTRAINT bs_cs_validity_range
    EXCLUDE USING GIST (left_id WITH =, right_id WITH =, valid_time_range WITH &&)
SQL

class A < ActiveRecord::Base
  include TemporalEntity

  temporal do
    attribute :name, :string
    attribute :age, :integer

    has_many :bs, class_name: "B"

    has_and_belongs_to_one :c, class_name: "C"
  end
end

class B < ActiveRecord::Base
  include TemporalEntity

  temporal do
    attribute :age, :integer

    belongs_to :a, class_name: "A"

    has_and_belongs_to_many :cs, class_name: "C"
  end
end

class C < ActiveRecord::Base
  include TemporalEntity

  temporal do
    attribute :name, :string

    has_and_belongs_to_many :bs, class_name: "B"

    has_and_belongs_to_one :a, class_name: "A"
  end
end

a_1 = A.create!(
  name: "A1 Initial Name",
  age: 10,
)

puts a_1.inspect

(1..5).to_a.each do |n|
  a_1.at_time(Time.current + n.days).update!(
    name: "A1 Name #{n}",
    age: 10 + n,
  )
end

(1..5).to_a.each do |n|
  puts a_1.at_time(Time.current + n.days).inspect
end
#=> #<A id: 1, relative_time: "2022-08-19 06:14:26.244825000 +0000", name: "A1 Name 1", age: 11>
#=> #<A id: 1, relative_time: "2022-08-20 06:14:26.246937000 +0000", name: "A1 Name 2", age: 12>
#=> #<A id: 1, relative_time: "2022-08-21 06:14:26.250195000 +0000", name: "A1 Name 3", age: 13>
#=> #<A id: 1, relative_time: "2022-08-22 06:14:26.259044000 +0000", name: "A1 Name 4", age: 14>
#=> #<A id: 1, relative_time: "2022-08-23 06:14:26.264995000 +0000", name: "A1 Name 5", age: 15>
#=> #<A id: 1, relative_time: "2022-08-21 06:14:26.505633000 +0000", name: "A1 Name 3", age: 13>

a_2 = A.at_time(Time.current + 3.days).create!(
  name: "A2 Initial Name",
  age: 100,
)
a_2.at_time(Time.current + 5.days).update!(
  name: "A2 Name Updated",
)

b_1 = B.create!(
  age: 20,
)

(1..5).to_a.each do |n|
  b_1.at_time(Time.current + n.days).update!(
    age: 20 + n,
  )
end

b_2 = B.create!(
  age: 200,
)

c_1 = C.at_time(Time.current - 5.days).create!(
  name: "C1 Initial Name",
)
c_2 = C.at_time(Time.current - 3.days).create!(
  name: "C2 Initial Name",
)

a_1.temporal_as_bs.create!(
  right: b_1,
  valid_at: Time.current,
)
a_1.temporal_as_bs.create!(
  right: b_2,
  valid_at: Time.current + 3.days,
)

a_2.temporal_as_bs.create!(
  right: b_1,
  valid_at: Time.current + 1.day,
)
a_2.temporal_as_bs.create!(
  right: b_2,
  valid_at: Time.current + 4.days,
)

puts a_1.at_time(Time.current + 3.days).inspect
#=> #<A id: 1, relative_time: "2022-08-21 06:14:26.505633000 +0000", name: "A1 Name 3", age: 13>
puts a_1.at_time(Time.current + 3.days).bs.to_sql
# SELECT
#     "bs".*
# FROM (
#     SELECT
#         "bs"."id",
#         relative_time,
#         "b_age_attributes"."value" AS "age"
#     FROM (
#         SELECT
#             "bs"."id",
#             '2022-08-21 06:14:26.508022'::timestamp WITHOUT time zone AS "relative_time"
#         FROM
#             "bs") "bs"
#         INNER JOIN "b_age_attributes" ON "b_age_attributes"."entity_id" = "bs"."id"
#     WHERE ("b_age_attributes"."valid_time_range" @> "bs"."relative_time")) "bs"
#     INNER JOIN "as_bs" ON "bs"."id" = "as_bs"."right_id"
# WHERE
#     "as_bs"."left_id" = 1
#     AND ('2022-08-21 06:14:26.508022'::timestamp WITHOUT time zone <@ "valid_time_range")

puts a_1.at_time(Time.current + 3.days).bs.inspect
#=> #<ActiveRecord::Associations::CollectionProxy [#<B id: 2, relative_time: "2022-08-21 01:17:59.454270000 +0000", age: 200>]>

puts a_2.at_time(Time.current + 3.days).inspect
#=> #<A id: 2, relative_time: "2022-08-21 06:14:26.523741000 +0000", name: "A2 Initial Name", age: 100>
puts a_2.at_time(Time.current + 3.days).bs.inspect
#=> #<ActiveRecord::Associations::CollectionProxy [#<B id: 1, relative_time: "2022-08-21 06:14:26.527978000 +0000", age: 23>]>

puts a_1.at_time(Time.current + 5.days).inspect
#=> #<A id: 1, relative_time: "2022-08-23 06:14:26.540848000 +0000", name: "A1 Name 5", age: 15>
puts a_1.at_time(Time.current + 5.days).bs.inspect
#=> #<ActiveRecord::Associations::CollectionProxy []>

puts a_2.at_time(Time.current + 5.days).inspect
#=> #<A id: 2, relative_time: "2022-08-23 06:14:26.566120000 +0000", name: "A2 Name Updated", age: 100>
puts a_2.at_time(Time.current + 5.days).bs.inspect
#=> #<ActiveRecord::Associations::CollectionProxy [#<B id: 1, relative_time: "2022-08-23 06:14:26.573276000 +0000", age: 25>, #<B id: 2, relative_time: "2022-08-23 06:14:26.573276000 +0000", age: 200>]>

puts A.at_time(Time.current + 4.days).where(name: "A2 Initial Name").to_sql
# SELECT
#     "as".*
# FROM (
#     SELECT
#         "as"."id",
#         relative_time,
#         "a_name_attributes"."value" AS "name",
#         "a_age_attributes"."value" AS "age"
#     FROM (
#         SELECT
#             "as"."id",
#             '2022-08-22 06:14:26.589836'::timestamp WITHOUT time zone AS "relative_time"
#         FROM
#             "as") "as"
#         INNER JOIN "a_name_attributes" ON "a_name_attributes"."entity_id" = "as"."id"
#         INNER JOIN "a_age_attributes" ON "a_age_attributes"."entity_id" = "as"."id"
#     WHERE ("a_name_attributes"."valid_time_range" @> "as"."relative_time")
#     AND ("a_age_attributes"."valid_time_range" @> "as"."relative_time")) "as"
# WHERE
#     "as"."name" = 'A2 Initial Name'

puts A.at_time(Time.current + 4.days).where(name: "A2 Initial Name").first.inspect
#=> #<A id: 2, relative_time: "2022-08-22 06:14:26.591733000 +0000", name: "A2 Initial Name", age: 100>
puts A.at_time(Time.current + 4.days).where(name: "A2 Initial Name").build.inspect
#=> #<A id: nil, relative_time: "2022-08-22 16:14:26.603245000 +1000", name: "A2 Initial Name", age: nil>
