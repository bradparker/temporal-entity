module TemporalEntity
  module Consecutive
    def self.included(base)
      base.extend(ClassMethods)

      base.class_eval do
        after_initialize :align_sequence
        before_validation :validate_sequence
        before_save :save_sequence!
      end
    end

    Options = Struct.new(
      :sequence,
      :valid_at_column_name,
      :invalid_at_column_name,
      keyword_init: true,
    )

    module ClassMethods
      def consecutive(
        valid_at_column_name: :valid_at,
        invalid_at_column_name: :invalid_at,
        &block
      )
        @consecutive_options = Options.new(
          sequence: block,
          valid_at_column_name: valid_at_column_name.to_sym,
          invalid_at_column_name: invalid_at_column_name.to_sym,
        )

        define_method "#{consecutive_options.valid_at_column_name}=" do |value|
          super(value)
          reload_sequence
        end
      end

      def consecutive_options
        @consecutive_options
      end
    end

    def consecutive_options
      self.class.consecutive_options
    end

    def predecessor
      @predecessor ||= instance_eval(&consecutive_options.sequence)
        .order(consecutive_options.valid_at_column_name => :desc)
        .find_by(consecutive_options.valid_at_column_name => ...valid_at)
    end

    def successor
      @successor ||= instance_eval(&consecutive_options.sequence)
        .order(consecutive_options.valid_at_column_name => :asc)
        .where.not(consecutive_options.valid_at_column_name => ..valid_at)
        .first
    end

    def align_sequence
      valid_at = public_send(consecutive_options.valid_at_column_name)
      predecessor_invalid_at = predecessor&.public_send(consecutive_options.invalid_at_column_name)

      if predecessor_invalid_at != valid_at
        predecessor&.assign_attributes(
          consecutive_options.invalid_at_column_name => valid_at,
        )
      end

      invalid_at = public_send(consecutive_options.invalid_at_column_name)

      if invalid_at.nil?
        successor_valid_at = successor&.public_send(consecutive_options.valid_at_column_name)

        assign_attributes(
          consecutive_options.invalid_at_column_name => successor_valid_at,
        )
      end

      self
    end

    def validate_sequence
      if predecessor_loaded? && predecessor&.invalid?
        errors.add(:predecessor, :invalid)
      end

      if successor_loaded? && successor&.invalid?
        errors.add(:successor, :invalid)
      end
    end

    def save_sequence!
      predecessor&.save!
    end

    def predecessor_loaded?
      !@predecessor.nil?
    end

    def successor_loaded?
      !@successor.nil?
    end

    def reload_sequence
      @predecessor = nil
      @successor = nil
      align_sequence
    end
  end
end
