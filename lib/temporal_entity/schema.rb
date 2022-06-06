require "active_record"
require "active_support"
require_relative "./consecutive"

module TemporalEntity
  class Schema
    class Attribute
      attr_reader :source_class, :name, :type

      def initialize(source_class, name, type)
        @source_class = source_class
        @name = name
        @type = type
      end

      def apply
        definition = self

        source_class.class_eval do
          model = const_set(definition.model_name, Class.new(ActiveRecord::Base) {
            include TemporalEntity::Consecutive

            class_attribute :temporal_schema

            self.temporal_schema = definition
            self.table_name = temporal_schema.table_name

            attribute :value, temporal_schema.type
            attribute :valid_at, :datetime
            attribute :invalid_at, :datetime

            belongs_to :entity, class_name: temporal_schema.source_class.name

            scope :at_time, -> (time) do
              where("?::timestamp without time zone <@ \"valid_time_range\"", time)
            end

            consecutive do
              entity.public_send(temporal_schema.temporal_association_name)
            end
          })

          attribute definition.name, definition.type

          has_many(
            definition.temporal_association_name,
            class_name: model.name,
            foreign_key: :entity_id,
            inverse_of: :entity,
          )

          after_save do
            model.create!(
              entity: self,
              value: public_send(definition.name),
              valid_at: relative_time,
            )
          end
        end
      end

      def temporal_association_name
        "temporal_#{name.to_s.pluralize}_attributes".to_sym
      end

      def model_name
        "#{name.to_s.classify}Attribute"
      end

      def table_name
        "#{source_class.name}::#{model_name}".underscore.gsub("/", "_").pluralize
      end
    end

    class Association
      class Source
        attr_reader :source_class

        def initialize(source_class, unique:)
          @source_class = source_class
          @unique = unique
        end

        def unique?
          !!@unique
        end
      end

      class Target
        attr_reader :target_class_name

        def initialize(target_class_name, unique:)
          @target_class_name = target_class_name
          @unique = unique
        end

        def unique?
          !!@unique
        end
      end

      attr_reader :name, :source, :target

      def initialize(name, source, target)
        @name = name
        @source = source
        @target = target
      end

      def apply
        definition = self

        @source.source_class.class_eval do
          model = const_set(definition.model_name, Class.new(ActiveRecord::Base) {
            include TemporalEntity::Consecutive

            class_attribute :temporal_schema

            self.temporal_schema = definition
            self.table_name = temporal_schema.table_name

            attribute :valid_at, :datetime
            attribute :invalid_at, :datetime

            belongs_to :left, class_name: temporal_schema.left_class_name
            belongs_to :right, class_name: temporal_schema.right_class_name

            scope :at_time, -> (time) do
              where("?::timestamp without time zone <@ \"valid_time_range\"", time)
            end

            consecutive do
              if temporal_schema.source.unique? && temporal_schema.target.unique?
                left.public_send(temporal_schema.temporal_association_name)
                  .or(right.public_send(temporal_schema.temporal_association_name))
              elsif temporal_schema.source.unique?
                public_send(temporal_schema.source_side).public_send(temporal_schema.temporal_association_name)
              elsif temporal_schema.target.unique?
                public_send(temporal_schema.target_side).public_send(temporal_schema.temporal_association_name)
              else
                left.public_send(temporal_schema.temporal_association_name)
                  .and(right.public_send(temporal_schema.temporal_association_name))
              end
            end
          })

          has_many(
            definition.temporal_association_name,
            class_name: model.name,
            foreign_key: "#{definition.source_side}_id".to_sym,
          )

          if definition.source.unique?
            has_one(
              definition.current_association_name,
              -> (entity) { at_time(entity.relative_time) },
              class_name: model.name,
              foreign_key: "#{definition.source_side}_id".to_sym,
            )

            has_one(
              definition.name.to_sym,
              -> (entity) { at_time(entity.relative_time) },
              through: definition.current_association_name,
              source: definition.target_side,
            )
          else
            has_many(
              definition.current_association_name,
              -> (entity) { at_time(entity.relative_time) },
              class_name: model.name,
              foreign_key: "#{definition.source_side}_id".to_sym,
            )

            has_many(
              definition.name.to_sym,
              -> (entity) { at_time(entity.relative_time) },
              through: definition.current_association_name,
              source: definition.target_side,
            )
          end
        end
      end

      def right_class_name
        sorted_class_names.second
      end

      def left_class_name
        sorted_class_names.first
      end

      def model_name
        @model_name ||= "#{left_class_name}#{right_class_name}Association"
      end

      def table_name
        @table_name ||= "#{left_class_name.pluralize}_#{right_class_name.pluralize}".underscore.gsub("/", "_")
      end

      def temporal_association_name
        @temporal_association_name ||= "temporal_#{table_name}".to_sym
      end

      def current_association_name
        @current_association_name ||= "current_#{table_name}".to_sym
      end

      def source_side
        @source_side ||= if @source.source_class.name < @target.target_class_name
          :left
        else
          :right
        end
      end

      def target_side
        @target_side ||= if source_side == :left
          :right
        else
          :left
        end
      end

      private

      def sorted_class_names
        @sorted_class_names ||= [@source.source_class.name, @target.target_class_name].sort
      end
    end

    attr_reader :attributes, :associations

    def initialize(source_class)
      @source_class = source_class
      @attributes = {}
      @associations = {}
    end

    def apply
      @attributes.values.each(&:apply)
      @associations.values.each(&:apply)
    end

    def attribute(name, type)
      @attributes[name] = Attribute.new(@source_class, name, type)
    end

    def has_many(name, class_name:)
      @associations[name] = Association.new(
        name,
        Association::Source.new(@source_class, unique: false),
        Association::Target.new(class_name, unique: true),
      )
    end

    def belongs_to(name, class_name:)
      @associations[name] = Association.new(
        name,
        Association::Source.new(@source_class, unique: true),
        Association::Target.new(class_name, unique: false),
      )
    end

    def has_and_belongs_to_many(name, class_name:)
      @associations[name] = Association.new(
        name,
        Association::Source.new(@source_class, unique: false),
        Association::Target.new(class_name, unique: false),
      )
    end

    def has_and_belongs_to_one(name, class_name:)
      @associations[name] = Association.new(
        name,
        Association::Source.new(@source_class, unique: true),
        Association::Target.new(class_name, unique: true),
      )
    end
  end
end
