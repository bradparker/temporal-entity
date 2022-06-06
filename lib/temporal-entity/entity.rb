require "active_record"
require_relative "attribute"

module TemporalEntity
  class Entity
    class << self
      def inherited(subclass)
        subclass.class_eval do
          const_set("Record", Class.new(ActiveRecord::Base))
        end
      end

      def attribute(attribute_name, type)
        entity_name = name

        const_set("#{attribute_name.to_s.classify}Attribute", Class.new(Attribute) {
          attribute :value, type

          belongs_to :entity, class_name: entity_name
        })

        const_get("Record").class_eval do
          has_many attribute_name
        end
      end

      # Right hand side, left side should be unique
      def belongs_to(left_entity_class_name, association_class_name:)
        right_entity_class_name = name
        Object.const_get(association_class_name).class_eval do
          left left_entity_class_name
          right right_entity_class_name
        end
      end

      # Left hand side, right side should be unique
      def has_one(right_entity_class_name, association_class_name:)
        left_entity_class_name = name
        Object.const_get(association_class_name).class_eval do
          left left_entity_class_name
          right right_entity_class_name
        end
      end

      # Either side, neither side unique
      def has_and_belongs_to_many(other_entity_class_name, association_class_name:)
        left_entity_class_name, right_entity_class_name = [name, other_entity_class_name].sort
        Object.const_get(association_class_name).class_eval do
          left left_entity_class_name
          right right_entity_class_name
        end
      end
    end
  end
end
