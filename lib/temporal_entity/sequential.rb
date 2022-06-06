module TemporalEntity
  module Sequential
    def self.included(base)
      base.extend(ClassMethods)
    end

    # TODO: relation setter callbacks?
    Options = Struct.new(
      :sequence,
      :valid_at_column_name,
      :invalid_at_column_name,
      keyword_init: true,
    )

    module ClassMethods
      def sequential(
        valid_at_column_name: :valid_at,
        invalid_at_column_name: :invalid_at,
        &block
      )
        @sequential_options = Options.new(
          sequence: block,
          valid_at_column_name: valid_at_column_name.to_sym,
          invalid_at_column_name: invalid_at_column_name.to_sym,
        )
      end

      def sequential_options
        @sequential_options
      end
    end

    def predecessor
      @predecessor ||= instance_eval(&sequential_options.sequence)
        .order(sequential_options.valid_at_column_name => :desc)
        .find_by(sequential_options.valid_at_column_name => ...valid_at)
    end

    def subordinates
      @subordinates ||= instance_eval(&sequential_options.sequence)
        .where(sequential_options.valid_at_column_name => valid_at..)
        .or(
          instance_eval(&sequential_options.sequence)
            .where(sequential_options.invalid_at_column_name => invalid_at..),
        )
    end

    def successor
      @successor ||= instance_eval(&sequential_options.sequence)
        .where.not(sequential_options.invalid_at_column_name => ..invalid_at)
        .or(
          instance_eval(&sequential_options.sequence)
            .where(sequential_options.invalid_at_column_name => nil)
        )
        .order(sequential_options.valid_at_column_name => :asc)
        .first
    end

    def validate_sequence
      if predecessor&.invalid?
        errors.add(:predecessor, :invalid)
      end

      if successor&.invalid?
        errors.add(:successor, :invalid)
      end
    end

    def save_sequence!
      predecessor.save!
      successor.save!
    end

    def reload_predecessor
      @predecessor = nil
    end

    def reload_successor
      @successor = nil
    end

    def reload_sequence
      reload_predecessor
      reload_successor
    end
  end
end
