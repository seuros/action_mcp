module ActionMCP
  module UriAmbiguityChecker
    extend ActiveSupport::Concern

    class_methods do
      # Determines if a segment is a parameter
      def parameter?(segment)
        segment =~ /\A\{[a-z0-9_]+\}\z/
      end

      # Checks if two URI patterns could potentially match the same URI
      def are_potentially_ambiguous?(pattern1, pattern2)
        # If the patterns are exactly the same, they're definitely ambiguous
        return true if pattern1 == pattern2

        segments1 = pattern1.split("/")
        segments2 = pattern2.split("/")

        # If different number of segments, they can't be ambiguous
        if segments1.size != segments2.size
          return false
        end

        # Extract literals (non-parameters) from each pattern
        literals1 = []
        literals2 = []

        segments1.each_with_index do |seg, i|
          literals1 << [ seg, i ] unless parameter?(seg)
        end

        segments2.each_with_index do |seg, i|
          literals2 << [ seg, i ] unless parameter?(seg)
        end

        # Check each segment for direct literal mismatches
        segments1.zip(segments2).each_with_index do |(seg1, seg2), index|
          param1 = parameter?(seg1)
          param2 = parameter?(seg2)

          # When both segments are literals, they must match exactly
          if !param1 && !param2 && seg1 != seg2
            return false
          end
        end

        # Check for structural incompatibility in the literals
        # If the same literals appear in different relative order, the patterns are structurally different
        if literals1.size >= 2 && literals2.size >= 2
          # Create arrays of just the literals (without positions)
          lit_values1 = literals1.map(&:first)
          lit_values2 = literals2.map(&:first)

          # Find common literals
          common_literals = lit_values1 & lit_values2

          if common_literals.size >= 2
            # Check if the relative ordering of common literals differs
            common_literal_indices1 = common_literals.map { |lit| lit_values1.index(lit) }
            common_literal_indices2 = common_literals.map { |lit| lit_values2.index(lit) }

            # If the relative ordering is different, patterns are not ambiguous
            if common_literal_indices1 != common_literal_indices2
              return false
            end
          end
        end

        # If we got here, the patterns are potentially ambiguous
        true
      end
    end
  end
end
