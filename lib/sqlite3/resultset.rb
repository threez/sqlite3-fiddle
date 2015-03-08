module SQLite3

  # The ResultSet object encapsulates the enumerability of a query's output.
  # It is a simple cursor over the data that the query returns. It will
  # very rarely (if ever) be instantiated directly. Instead, clients should
  # obtain a ResultSet instance via Statement#execute.
  class ResultSet
    include Enumerable

    class ArrayWithTypes < Array # :nodoc:
      attr_accessor :types
    end

    class ArrayWithTypesAndFields < Array # :nodoc:
      attr_writer :types
      attr_writer :fields

      def types
        @types
      end

      def fields
        @fields
      end
    end

    # The class of which we return an object in case we want a Hash as
    # result.
    class HashWithTypesAndFields < Hash # :nodoc:
      attr_writer :types
      attr_writer :fields

      def types
        @types
      end

      def fields
        @fields
      end

      def [] key
        key = fields[key] if key.is_a? Numeric
        super key
      end
    end

    # Create a new ResultSet attached to the given database, using the
    # given sql text.
    def initialize db, stmt
      @db   = db
      @stmt = stmt
    end

    # Reset the cursor, so that a result set which has reached end-of-file
    # can be rewound and reiterated.
    def reset( *bind_params )
      must_be_open!
      @stmt.reset!
      @stmt.bind_params( *bind_params )
      @eof = false
    end

    # Query whether the cursor has reached the end of the result set or not.
    def eof?
      @stmt.done?
    end

    # Obtain the next row from the cursor. If there are no more rows to be
    # had, this will return +nil+. If type translation is active on the
    # corresponding database, the values in the row will be translated
    # according to their types.
    #
    # The returned value will be an array, unless Database#results_as_hash has
    # been set to +true+, in which case the returned value will be a hash.
    #
    # For arrays, the column names are accessible via the +fields+ property,
    # and the column types are accessible via the +types+ property.
    #
    # For hashes, the column names are the keys of the hash, and the column
    # types are accessible via the +types+ property.
    def next
      must_be_open!
      if @db.results_as_hash
        return next_hash
      end

      row = @stmt.step
      return nil if @stmt.done?
      row = ArrayWithTypesAndFields.new(row)
      row.fields = @stmt.columns
      row.types = @stmt.types
      row
    end

    # Required by the Enumerable mixin. Provides an internal iterator over the
    # rows of the result set.
    def each
      must_be_open!
      while node = self.next
        yield node
      end
    end

    # Provides an internal iterator over the rows of the result set where
    # each row is yielded as a hash.
    def each_hash
      while node = next_hash
        yield node
      end
    end

    # Closes the statement that spawned this result set.
    # <em>Use with caution!</em> Closing a result set will automatically
    # close any other result sets that were spawned from the same statement.
    def close
      @stmt.close
    end

    # Queries whether the underlying statement has been closed or not.
    def closed?
      @stmt.closed?
    end

    # Returns the types of the columns returned by this result set.
    def types
      must_be_open!
      @stmt.types
    end

    # Returns the names of the columns returned by this result set.
    def columns
      must_be_open!
      @stmt.columns
    end

    # Return the next row as a hash
    def next_hash
      must_be_open!
      row = @stmt.step
      return nil if @stmt.done?

      # FIXME: this can be switched to a regular hash in 2.0
      row = HashWithTypesAndFields[*@stmt.columns.zip(row).flatten]

      # FIXME: these methods are deprecated for version 2.0, so we can remove
      # this code in 2.0
      row.fields = @stmt.columns
      row.types = @stmt.types
      row
    end

    private

    def must_be_open!
      raise Exception, "#{self.class} is closed!" if closed?
    end
  end
end
