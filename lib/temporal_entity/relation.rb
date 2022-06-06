require "active_record"

module TemporalEntity
  class Relation < ActiveRecord::Relation
    attr_reader :relative_time, :klass

    def initialize(relative_time, klass, scope = nil)
      @relative_time = relative_time
      @klass = klass
      @scope = scope
      @values = self.scope.values
    end

    delegate(
      :find,
      :find_by,
      :table,
      :implicit_order_column,
      to: :scope,
    )

    def where(...)
      self.class.new(relative_time, klass, scope.where(...))
    end

    def build(**attributes, &block)
      scope.build(**attributes, relative_time: relative_time, &block)
    end

    alias_method :new, :build

    def create!(**attributes, &block)
      scope.create!(**attributes, relative_time: relative_time, &block)
    end

    private

    def including_relative_time
      klass.from(
        klass.select(
          *klass.column_names,
          klass.sanitize_sql_array(["?::timestamp without time zone AS \"relative_time\"", relative_time]),
        ),
        "\"#{klass.table_name}\""
      ).select(
        *klass.column_names,
        "relative_time",
      )
    end

    def scope
      @scope ||= klass.from(
        klass
          .temporal_schema
          .attributes
          .values
          .reduce(including_relative_time) do |scope, attribute|
            scope
              .joins(attribute.temporal_association_name)
              .where("\"#{attribute.table_name}\".\"valid_time_range\" @> \"#{klass.table_name}\".\"relative_time\"")
              .select("\"#{attribute.table_name}\".\"value\" AS \"#{attribute.name}\"")
          end,
        "\"#{klass.table_name}\"",
      )
    end
  end
end
