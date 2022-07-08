require "logger"
require "securerandom"
require_relative "../lib/temporal_entity"

ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Base.establish_connection(ENV["DATABASE_URL"])

connection = ActiveRecord::Base.connection

connection.create_table :as, force: true do |t|
  # HACK for seeds, not strictly necessary
  t.datetime :created_at, null: false
end

connection.create_table :a_name_attributes, force: true do |t|
  t.belongs_to :entity, null: false
  t.text :value
  t.datetime :valid_at, null: false, index: true

  t.index [:entity_id, :valid_at], unique: true
end

connection.create_table :a_age_attributes, force: true do |t|
  t.belongs_to :entity, null: false
  t.integer :value
  t.datetime :valid_at, null: false, index: true

  t.index [:entity_id, :valid_at], unique: true
end

connection.create_table :bs, force: true do |t|
  # HACK for seeds, not strictly necessary
  t.datetime :created_at, null: false
end

connection.create_table :b_age_attributes, force: true do |t|
  t.belongs_to :entity, null: false
  t.integer :value
  t.datetime :valid_at, null: false, index: true

  t.index [:entity_id, :valid_at], unique: true
end

connection.create_table :as_bs, force: true do |t|
  t.belongs_to :left, null: false
  t.belongs_to :right, null: false
  t.datetime :valid_at, null: false, index: true

  t.index [:left_id, :right_id, :valid_at], unique: true
end

class A < ActiveRecord::Base
  include TemporalEntity

  temporal do
    attribute :name, :string
    attribute :age, :integer

    has_many :bs, class_name: "B"
  end
end

class B < ActiveRecord::Base
  include TemporalEntity

  temporal do
    attribute :age, :integer

    belongs_to :a, class_name: "A"
  end
end

a = A.create!
a.temporal_names.create!(
  value: "An old name",
  valid_at: Time.current.advance(days: -2),
)
a.temporal_names.create!(
  value: "A name",
  valid_at: Time.current.advance(days: -1),
)
a.temporal_names.create!(
  value: "A future name",
  valid_at: Time.current.advance(days: 1),
)
a.temporal_ages.create!(
  value: 56,
  valid_at: Time.current.advance(days: -2),
)
a.temporal_ages.create!(
  value: 55,
  valid_at: Time.current.advance(days: -1),
)
a.temporal_ages.create!(
  value: 54,
  valid_at: Time.current.advance(days: 1),
)

puts A
  .at_time(Time.current.advance(days: -1.5))
  .map {|r| r.slice(:id, :name, :age, :current_time)}
  .inspect
puts A
  .at_time(Time.current)
  .map {|r| r.slice(:id, :name, :age, :current_time)}
  .inspect
puts A
  .at_time(Time.current.advance(days: 3))
  .map {|r| r.slice(:id, :name, :age, :current_time)}
  .inspect

b = B.create!
b.temporal_ages.create!(
  value: 37,
  valid_at: Time.current.advance(days: -2),
)
b.temporal_ages.create!(
  value: 36,
  valid_at: Time.current.advance(days: -1),
)
b.temporal_ages.create!(
  value: 35,
  valid_at: Time.current.advance(days: 1),
)
puts B
  .at_time(Time.current)
  .find(b.id)
  .age

b_2 = B.create!
b_2.temporal_ages.create!(
  valid_at: Time.current.advance(days: -3),
  value: 10,
)
b_3 = B.create!
b_3.temporal_ages.create!(
  valid_at: Time.current.advance(days: -3),
  value: 11,
)

a.temporal_as_bs.create!(
  right: b_2,
  valid_at: Time.current.advance(days: -2),
)
a.temporal_as_bs.create!(
  right: b,
  valid_at: Time.current.advance(days: -1),
)
a.temporal_as_bs.create!(
  right: b_3,
  valid_at: Time.current.advance(days: 1),
)
puts A
  .at_time(Time.current)
  .includes(:bs)
  .references(:bs)
  .find(a.id)
  .bs
  .inspect

puts B
  .at_time(Time.current)
  .includes(:a)
  .references(:as)
  .find(b.id)
  .a
  .inspect
puts B
  .at_time(Time.current)
  .includes(:a)
  .references(:as)
  .find(b_2.id)
  .a
  .inspect

a_2 = A.create!
a_2.temporal_names.create!(
  value: "A name",
  valid_at: Time.current.advance(days: -3),
)
a_2.temporal_ages.create!(
  value: 10,
  valid_at: Time.current.advance(days: -3),
)

a_3 = A.create!
a_3.temporal_names.create!(
  value: "A name",
  valid_at: Time.current.advance(days: -3),
)
a_3.temporal_ages.create!(
  value: 10,
  valid_at: Time.current.advance(days: -3),
)

b_3.temporal_as_bs.create!(
  left: a,
  valid_at: Time.current.advance(days: -2),
)
b_3.temporal_as_bs.create!(
  left: a_2,
  valid_at: Time.current.advance(days: -1),
)
b_3.temporal_as_bs.create!(
  left: a_3,
  valid_at: Time.current.advance(days: 1),
)

puts B
  .at_time(Time.current)
  .includes(:a)
  .references(:as)
  .find(b_3.id)
  .a
  .inspect

puts B
  .at_time(Time.current.advance(days: 2))
  .includes(:a)
  .references(:as)
  .find(b_3.id)
  .a
  .inspect

puts A
  .at_time(Time.current.advance(days: 2))
  .includes(:bs)
  .references(:bs)
  .find(a.id)
  .bs
  .inspect

current_time = Time.current
MINUTES_IN_A_YEAR = 525600
YEARS = 5
MAX_EDITS_PER_DAY = 10
MAX_ASSOCIATIONS_PER_DAY = 10
TOTAL_AS = 1000
TOTAL_BS = 1000

as = []
TOTAL_AS.times do
  created_at = current_time.advance(minutes: -1 * rand(MINUTES_IN_A_YEAR * YEARS))
  seconds_since_created_at = current_time - created_at

  as << A.create!(
    created_at: created_at,
  ).tap do |a|
    a.temporal_names.create!(
      value: "Initial name for ##{a.id}",
      valid_at: created_at,
    )

    name_offsets = []
    ((seconds_since_created_at / 1.day.in_seconds).to_i * rand(MAX_EDITS_PER_DAY)).times do
      name_offsets << rand(seconds_since_created_at)
    end
    name_valid_ats = name_offsets.uniq.map do |offset|
      created_at.advance(seconds: -1 * offset)
    end

    if name_valid_ats.any?
      A::NameAttribute.insert_all(
        name_valid_ats.map do |valid_at|
          { entity_id: a.id, value: "Name #{SecureRandom.uuid}", valid_at: valid_at }
        end
      )
    end

    age_offsets = []
    ((seconds_since_created_at / 1.day.in_seconds).to_i * rand(MAX_EDITS_PER_DAY)).times do
      age_offsets << rand(seconds_since_created_at)
    end
    age_valid_ats = age_offsets.uniq.map do |offset|
      created_at.advance(seconds: -1 * offset)
    end

    if age_valid_ats.any?
      A::AgeAttribute.insert_all(
        age_valid_ats.map do |valid_at|
          { entity_id: a.id, value: rand(200), valid_at: valid_at }
        end
      )
    end
  end
end

bs = []
TOTAL_AS.times do
  created_at = current_time.advance(minutes: -1 * rand(MINUTES_IN_A_YEAR * YEARS))
  seconds_since_created_at = current_time - created_at

  bs << B.create!(
    created_at: created_at,
  ).tap do |b|
    age_offsets = []
    ((seconds_since_created_at / 1.day.in_seconds).to_i * rand(MAX_EDITS_PER_DAY)).times do
      age_offsets << rand(seconds_since_created_at)
    end
    age_valid_ats = age_offsets.uniq.map do |offset|
      created_at.advance(seconds: -1 * offset)
    end

    if age_valid_ats.any?
      B::AgeAttribute.insert_all(
        age_valid_ats.map do |valid_at|
          { entity_id: b.id, value: rand(200), valid_at: valid_at }
        end
      )
    end
  end
end

as.each do |a|
  seconds_since_created_at = current_time - a.created_at

  offsets = []
  ((seconds_since_created_at / 1.day.in_seconds).to_i * rand(MAX_EDITS_PER_DAY)).times do
    offsets << rand(seconds_since_created_at)
  end
  valid_ats = offsets.uniq.map do |offset|
    a.created_at.advance(seconds: -1 * offset)
  end

  next if valid_ats.empty?

  A::ABAssociation.insert_all(
    valid_ats.map do |valid_at|
      { left_id: a.id, right_id: bs.sample.id, valid_at: valid_at }
    end,
  )
end

puts A
  .at_time(Time.current)
  .includes(:bs)
  .references(:bs)
  .sample(5)
  .map(&:bs)
  .inspect
puts B
  .at_time(Time.current)
  .includes(:a)
  .references(:as)
  .sample(5)
  .map(&:a)
  .inspect
