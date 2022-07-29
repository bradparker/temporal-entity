require "active_record"
require "active_support"

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
          const_set(definition.model_name, Class.new(ActiveRecord::Base) {
            self.table_name = definition.table_name

            attribute :value, definition.type
            attribute :valid_at, :datetime

            belongs_to :entity, class_name: definition.source_class.name

            scope :at_time, -> (time) do
              sub = reselect("max(`sub`.`valid_at`)")
                .from("`#{self.table_name}` sub")
                .where("`sub`.`entity_id` = `#{self.table_name}`.`entity_id`")
                .where("`sub`.`valid_at` <= ?", time)

              where("`#{self.table_name}`.`valid_at` = (#{sub.to_sql})")
            end

            scope :matching_time, -> do
              sub = reselect("max(`sub`.`valid_at`)")
                .from("`#{self.table_name}` sub")
                .where("`sub`.`entity_id` = `#{self.table_name}`.`entity_id`")
                .where("`sub`.`valid_at` <= `#{definition.source_class.table_name}`.`current_time`")

              where("`#{self.table_name}`.`valid_at` = (#{sub.to_sql})")
            end
          })

          has_many(
            definition.temporal_association_name,
            class_name: const_get(definition.model_name).name,
            foreign_key: :entity_id,
            inverse_of: :entity,
          )

          scope :"with_#{definition.name}", -> do
            select("`#{definition.table_name}`.`value` AS #{definition.name}")
              .joins(definition.temporal_association_name)
              .merge(const_get(definition.model_name).matching_time)
          end
        end
      end

      def temporal_association_name
        "temporal_#{name.to_s.pluralize}".to_sym
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
          const_set(definition.model_name, Class.new(ActiveRecord::Base) {
            self.table_name = definition.table_name

            attribute :valid_at, :datetime

            belongs_to :left, class_name: definition.left_class_name
            belongs_to :right, class_name: definition.right_class_name

            scope :at_time, -> (time) do
              sub = reselect("max(sub.valid_at)")
                .from("`#{self.table_name}` sub")
                .where("`sub`.`left_id` = `#{self.table_name}`.`left_id`")
                .where("`sub`.`right_id` = `#{self.table_name}`.`right_id`")
                .where("`sub`.`valid_at` <= ?", time)

              where("`#{self.table_name}`.`valid_at` = (#{sub.to_sql})")
            end

            scope :matching_time, -> (joined_table_name) do
              sub = reselect("max(`sub`.`valid_at`)")
                .from("`#{self.table_name}` sub")
                .where("`sub`.`valid_at` <= `#{joined_table_name}`.`current_time`")

              if definition.source.unique?
                sub = sub
                  .where("`sub`.`#{definition.source_side}_id` = `#{self.table_name}`.`#{definition.source_side}_id`")
              elsif definition.target.unique?
                sub = sub
                  .where("`sub`.`#{definition.target_side}_id` = `#{self.table_name}`.`#{definition.target_side}_id`")
              else
                sub = sub
                  .where("`sub`.`left_id` = `#{self.table_name}`.`left_id`")
                  .where("`sub`.`right_id` = `#{self.table_name}`.`right_id`")
              end

              where("`#{self.table_name}`.`valid_at` = (#{sub.to_sql})")
            end
          })

          has_many(
            definition.temporal_join_association_name,
            class_name: const_get(definition.model_name).name,
            foreign_key: "#{definition.source_side}_id".to_sym,
          )

          if definition.source.unique?
            has_one(
              definition.current_join_association_name,
              -> () { matching_time(definition.source.source_class.table_name) },
              class_name: const_get(definition.model_name).name,
              foreign_key: "#{definition.source_side}_id".to_sym,
            )

            has_one(
              definition.name.to_sym,
              -> () {
                select(
                  "`#{const_get(definition.target.target_class_name).table_name}`.*",
                  "`#{definition.source.source_class.table_name}`.`current_time` AS current_time",
                )
              },
              through: definition.current_join_association_name,
              source: definition.target_side,
            )
          else
            has_many(
              definition.current_join_association_name,
              -> () { matching_time(definition.source.source_class.table_name) },
              class_name: const_get(definition.model_name).name,
              foreign_key: "#{definition.source_side}_id".to_sym,
            )

            has_many(
              definition.name.to_sym,
              -> () {
                select(
                  "`#{const_get(definition.target.target_class_name).table_name}`.*",
                  "`#{definition.source.source_class.table_name}`.`current_time` AS current_time",
                )
              },
              through: definition.current_join_association_name,
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

      def temporal_join_association_name
        @temporal_join_association_name ||= "temporal_#{table_name}".to_sym
      end

      def current_join_association_name
        @current_join_association_name ||= if target.unique?
          "current_#{table_name.singularize}".to_sym
        else
           "current_#{table_name}".to_sym
        end
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

    def initialize(source_class)
      @source_class = source_class
      @attributes = {}
      @associations = {}
    end

    def apply
      @attributes.values.each(&:apply)
      @associations.values.each(&:apply)

      source_class = @source_class
      attributes = @attributes

      @source_class.class_eval do
        scope :at_time, -> (time) do
          with_current_time = from(
            select(
              "`#{source_class.table_name}`.*",
              sanitize_sql_array(["? AS `current_time`", time]),
            ),
            "`#{source_class.table_name}`",
          )

          with_attributes = attributes.keys.reduce(with_current_time) do |scope, attribute_name|
            scope.public_send(:"with_#{attribute_name}")
          end

          with_attributes.select("`#{source_class.table_name}`.*")
        end
      end
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
