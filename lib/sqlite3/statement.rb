module SQLite3
  class Statement
    include Enumerable

    # This is any text that followed the first valid SQL statement in the text
    # with which the statement was initialized. If there was no trailing text,
    # this will be the empty string.
    attr_reader :remainder

    def initialize(db, sql)
      raise TypeError, 'sql has to be a string' unless sql.is_a? String
      raise ArgumentError, 'db has to be open' if db.closed?
      @db = db
      sql = sql.strip.encode(Encoding::UTF_8)
      @prepared_stmt = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
      remainder = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
      @db.check Driver.sqlite3_prepare_v2(db.handle, sql, -1,
                                             @prepared_stmt.ref,
                                             remainder.ref)
      @remainder = remainder.to_s
      @sql = sql
      @done = false
      remainder.free
    end

    def column_count
      Driver.sqlite3_column_count(@prepared_stmt)
    end

    def column_name(index)
      column = Driver.sqlite3_column_name(@prepared_stmt, index.to_i)
      column.to_s unless column.null?
    end

    def column_decltype(index)
      column = Driver.sqlite3_column_decltype(@prepared_stmt, index.to_i)
      column.to_s unless column.null?
    end

    def database_name(index)
      name = Driver.sqlite3_column_database_name(@prepared_stmt, index.to_i)
      name.to_s unless name.null?
    end

    def table_name(index)
      name = Driver.sqlite3_column_table_name(@prepared_stmt, index.to_i)
      name.to_s unless name.null?
    end

    def origin_name(index)
      name = Driver.sqlite3_column_origin_name(@prepared_stmt, index.to_i)
      name.to_s unless name.null?
    end

    def bind_parameter_count
      Driver.sqlite3_bind_parameter_count(@prepared_stmt)
    end

    # Binds the given variables to the corresponding placeholders in the SQL
    # text.
    #
    # See Database#execute for a description of the valid placeholder
    # syntaxes.
    #
    # Example:
    #
    #   stmt = db.prepare( "select * from table where a=? and b=?" )
    #   stmt.bind_params( 15, "hello" )
    #
    # See also #execute, #bind_param, Statement#bind_param, and
    # Statement#bind_params.
    def bind_params( *bind_vars )
      index = 1
      bind_vars.flatten.each do |var|
        if Hash === var
          var.each { |key, val| bind_param key, val }
        else
          bind_param index, var
          index += 1
        end
      end
    end

    def bind_param(index, var)
      must_be_open!
      unless index.is_a? Fixnum
        name = index.to_s
        name = ":#{name}" unless name.start_with? ':'
          # if name !=~ /^[:@?$].*/
        index = Driver.sqlite3_bind_parameter_index(@prepared_stmt, name)
        if index == 0
          raise Exception, "index #{name} unknown for [#{@sql}]"
        end
      end
      @db.check case var
      when Blob
        var = var.force_encoding(Encoding::ASCII_8BIT)
        Driver.sqlite3_bind_blob(@prepared_stmt, index, var.to_s,
                                                        var.size, nil)
      when String
        # if UTF_16BE was passed we have to convert it anyway, than we use
        # the UTF-8 conversion much like the c implementation does.
        # TODO: check if this is slow because the sqlite than has to convert to?
        if var.encoding == Encoding::UTF_16LE
          Driver.sqlite3_bind_text16(@prepared_stmt, index, var, -1, nil)
        else # this string behaves like a blob, so we bind it as such
          if var.encoding == Encoding::ASCII_8BIT
            Driver.sqlite3_bind_blob(@prepared_stmt, index, var.to_s,
                                                            var.size, nil)
          else
            unless var.encoding == Encoding::UTF_8
              var = var.encode(Encoding::UTF_8)
            end
            Driver.sqlite3_bind_text(@prepared_stmt, index, var, -1, nil)
          end
        end
      when Fixnum, Bignum
        Driver.sqlite3_bind_int64(@prepared_stmt, index, var)
      when Float
        Driver.sqlite3_bind_double(@prepared_stmt, index, var)
      when NilClass
        Driver.sqlite3_bind_null(@prepared_stmt, index)
      when TrueClass, FalseClass
        Driver.sqlite3_bind_int(@prepared_stmt, index, var ? 1 : 0)
      else
        Driver.sqlite3_bind_blob(@prepared_stmt, index, var.to_s,
                                                        var.to_s.size, nil)
      end
    end

    def clear_bindings!
      @db.check Driver.sqlite3_clear_bindings(@prepared_stmt)
    end

    def reset!
      @db.check Driver.sqlite3_reset(@prepared_stmt)
      @done = false
    end
    #
    # def execute(*bind_vars, &handler)
    #   must_be_open!
    #   reset! if active? || done?
    #   bind_params *bind_vars unless bind_vars.empty?
    #   if block_given?
    #     each &handler
    #   else
    #     ResultSet.new(@db, self)
    #   end
    # end
    def execute( *bind_vars )
      reset! if active? || done?

      bind_params(*bind_vars) unless bind_vars.empty?
      @results = ResultSet.new(@db, self)

      step if 0 == column_count

      yield @results if block_given?
      @results
    end

    def each
      loop do
        val = step
        break self if done?
        yield val
      end
    end

    def step
      must_be_open!
      case Driver.sqlite3_step(@prepared_stmt)
      when SQLITE_ROW
        row = []
        column_count.times do |i|
          case Driver.sqlite3_column_type(@prepared_stmt, i)
          when SQLITE_INTEGER
            row << Driver.sqlite3_column_int64(@prepared_stmt, i)
          when SQLITE_FLOAT
            row << Driver.sqlite3_column_double(@prepared_stmt, i)
          when SQLITE_TEXT
            text = (Driver.sqlite3_column_text(@prepared_stmt, i)[
              0, Driver.sqlite3_column_bytes(@prepared_stmt, i)
            ])
            default = Encoding.default_internal || Encoding::UTF_8
            row << text.encode(default, Encoding::UTF_8)
          when SQLITE_BLOB
            data = Driver.sqlite3_column_blob(@prepared_stmt, i)[
              0, Driver.sqlite3_column_bytes(@prepared_stmt, i)
            ]
            row << Blob.new(data.force_encoding(Encoding::ASCII_8BIT))
          when SQLITE_NULL
            row << nil
          else
            fail Exception, "bad type"
          end
        end
        return row
      when SQLITE_DONE
        @done = true
        return nil
      else
        reset!
        @done = false
      end
    end

    # Execute the statement. If no block was given, this returns an array of
    # rows returned by executing the statement. Otherwise, each row will be
    # yielded to the block.
    #
    # Any parameters will be bound to the statement using #bind_params.
    #
    # Example:
    #
    #   stmt = db.prepare( "select * from table" )
    #   stmt.execute! do |row|
    #     ...
    #   end
    #
    # See also #bind_params, #execute.
    def execute!( *bind_vars, &block )
      execute(*bind_vars)
      block_given? ? each(&block) : to_a
    end

    # Returns true if the statement has been closed.
    def closed?
      @prepared_stmt.nil?
    end

    # returns true if all rows have been returned.
    def done?
      @done
    end

    def close
      must_be_open!
      @db.check Driver.sqlite3_finalize(@prepared_stmt)
      @prepared_stmt.free
      @prepared_stmt = nil
    end


    # Return an array of the data types for each column in this statement. Note
    # that this may execute the statement in order to obtain the metadata; this
    # makes it a (potentially) expensive operation.
    def types
      must_be_open!
      get_metadata unless @types
      @types
    end

    # Return an array of the column names for this statement. Note that this
    # may execute the statement in order to obtain the metadata; this makes it
    # a (potentially) expensive operation.
    def columns
      must_be_open!
      get_metadata unless @columns
      return @columns
    end

    # Returns true if the statement is currently active, meaning it has an
    # open result set.
    def active?
      !done?
    end

    # Performs a sanity check to ensure that the statement is not
    # closed. If it is, an exception is raised.
    def must_be_open! # :nodoc:
      if closed?
        raise Exception, "cannot use a closed statement"
      end
    end

    private
    # A convenience method for obtaining the metadata about the query. Note
    # that this will actually execute the SQL, which means it can be a
    # (potentially) expensive operation.
    def get_metadata
      @columns = Array.new(column_count) do |column|
        column_name column
      end
      @types = Array.new(column_count) do |column|
        column_decltype column
      end
    end
  end
end
