require "active_record"
require_relative "../lib/temporal-entity/entity"
require_relative "../lib/temporal-entity/association"

ActiveRecord::Base.establish_connection(adapter: :postgresql)

class ABAuto < TemporalEntity::Association
end

class A < TemporalEntity::Entity
  attribute :name, :string

  has_one "B", association_class_name: "ABAuto"
end

puts A::Record.reflect_on_association(:name)
puts A::NameAttribute.reflect_on_association(:entity)

class B < TemporalEntity::Entity
  attribute :name, :string

  belongs_to "A", association_class_name: "ABAuto"
end

puts B::Record.reflect_on_association(:name)
puts B::NameAttribute.reflect_on_association(:entity)

class ABManual < TemporalEntity::Association
  left "A"
  right "B"
end

puts ABManual::Record.reflect_on_association(:left).inspect
puts ABManual::Record.reflect_on_association(:right).inspect

puts ABAuto::Record.reflect_on_association(:left).inspect
puts ABAuto::Record.reflect_on_association(:right).inspect
