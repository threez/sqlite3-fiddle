module SQLite3
  class Database
    OPEN_READONLY         =  0x00000001  # Ok for sqlite3_open_v2()
    OPEN_READWRITE        =  0x00000002  # Ok for sqlite3_open_v2()
    OPEN_CREATE           =  0x00000004  # Ok for sqlite3_open_v2()
    OPEN_DELETEONCLOSE    =  0x00000008  # VFS only
    OPEN_EXCLUSIVE        =  0x00000010  # VFS only
    OPEN_AUTOPROXY        =  0x00000020  # VFS only
    OPEN_URI              =  0x00000040  # Ok for sqlite3_open_v2()
    OPEN_MEMORY           =  0x00000080  # Ok for sqlite3_open_v2()
    OPEN_MAIN_DB          =  0x00000100  # VFS only
    OPEN_TEMP_DB          =  0x00000200  # VFS only
    OPEN_TRANSIENT_DB     =  0x00000400  # VFS only
    OPEN_MAIN_JOURNAL     =  0x00000800  # VFS only
    OPEN_TEMP_JOURNAL     =  0x00001000  # VFS only
    OPEN_SUBJOURNAL       =  0x00002000  # VFS only
    OPEN_MASTER_JOURNAL   =  0x00004000  # VFS only
    OPEN_NOMUTEX          =  0x00008000  # Ok for sqlite3_open_v2()
    OPEN_FULLMUTEX        =  0x00010000  # Ok for sqlite3_open_v2()
    OPEN_SHAREDCACHE      =  0x00020000  # Ok for sqlite3_open_v2()
    OPEN_PRIVATECACHE     =  0x00040000  # Ok for sqlite3_open_v2()
    OPEN_WAL              =  0x00080000  # VFS only

    SQLITE_UTF8           = 1

    include Fiddle
    include Pragmas

    FUNC_PARAMS = [TYPE_VOIDP, TYPE_INT, TYPE_VOIDP].freeze
    TRACE_PARAMS = [TYPE_VOIDP, TYPE_VOIDP].freeze
    AUTH_PARAMS = [
      TYPE_VOIDP, TYPE_INT, TYPE_VOIDP, TYPE_VOIDP, TYPE_VOIDP, TYPE_VOIDP
    ].freeze
    COLLATION_PARAMS = [
      TYPE_VOIDP, TYPE_INT, TYPE_VOIDP, TYPE_INT, TYPE_VOIDP
    ].freeze
    BUSY_PARAMS = [TYPE_VOIDP, TYPE_INT].freeze

    # A helper class for dealing with custom functions (see #create_function,
    # #create_aggregate, and #create_aggregate_handler). It encapsulates the
    # opaque function object that represents the current invocation. It also
    # provides more convenient access to the API functions that operate on
    # the function object.
    #
    # This class will almost _always_ be instantiated indirectly, by working
    # with the create methods mentioned above.
    class FunctionProxy
      attr_accessor :result

      def self.proxy(handler)
        proc do |*args|
          fp = new
          args.unshift(fp)
          handler.call(*args)
          fp.result
        end
      end

      # Create a new FunctionProxy that encapsulates the given +func+ object.
      # If context is non-nil, the functions context will be set to that. If
      # it is non-nil, it must quack like a Hash. If it is nil, then none of
      # the context functions will be available.
      def initialize
        @result   = nil
        @context  = {}
      end

      # Returns the value with the given key from the context. This is only
      # available to aggregate functions.
      def []( key )
        @context[ key ]
      end

      # Sets the value with the given key in the context. This is only
      # available to aggregate functions.
      def []=( key, value )
        @context[ key ] = value
      end
    end

    class << self

      alias :open :new

      # Quotes the given string, making it safe to use in an SQL statement.
      # It replaces all instances of the single-quote character with two
      # single-quote characters. The modified string is returned.
      def quote( string )
        string.gsub( /'/, "''" )
      end

    end

    def initialize(uri, opts = {})
      fail TypeError, "invalid uri" unless uri.is_a? String

      @results_as_hash = opts[:results_as_hash] || false
      @functions = {}
      @collations = {}
      @authorizer = nil
      @tracefunc = nil
      @encoding = nil
      @busy_handler = nil
      @db = Pointer.malloc(SIZEOF_VOIDP)

      if uri.encoding == Encoding::UTF_16LE ||
         uri.encoding == Encoding::UTF_16BE
        check Driver.sqlite3_open16(uri, @db.ref)
      else
        if opts[:readonly]
          mode = OPEN_READONLY
        else
          mode = OPEN_READWRITE | OPEN_CREATE;
        end
        uri = uri.encode(Encoding::UTF_8)
        check Driver.sqlite3_open_v2(uri, @db.ref, mode, nil)
      end

      if block_given?
        begin
          yield self
        ensure
          close
        end
      end
    end

    attr_reader :collations

    # A boolean that indicates whether rows in result sets should be returned
    # as hashes or not. By default, rows are returned as arrays.
    attr_accessor :results_as_hash

    def close
      must_be_open!
      check Driver.sqlite3_close(@db)
      @db = nil
    end

    def closed?
      @db.nil?
    end

    def handle
      @db
    end

    def interrupt
      must_be_open!
      Driver.sqlite3_interrupt(@db)
    end

    def busy_handler(handler = nil, &block)
      must_be_open!
      if handler.nil? and block_given?
        @busy_handler = block
      else
        @busy_handler = nil
      end

      cb = Closure::BlockCaller.new(TYPE_INT, BUSY_PARAMS) do |_, count|
        @busy_handler.call(self, count) ? 1 : 0
      end if @busy_handler

      check Driver.sqlite3_busy_handler(@db, cb, nil)
    end

    # call-seq: db.collation(name, comparator)
    #
    # Add a collation with name +name+, and a +comparator+ object.  The
    # +comparator+ object should implement a method called "compare" that takes
    # two parameters and returns an integer less than, equal to, or greater than
    # 0.
    def collation(name, comparator)
      must_be_open!
      cb = Closure::BlockCaller.new(TYPE_INT, COLLATION_PARAMS) do |_, aenc, astr, benc, bstr|
        target = Encoding.default_internal || Encoding::UTF_8
        comparator.compare(sqlite_encoding(astr.to_s, aenc).encode(target),
                           sqlite_encoding(bstr.to_s, benc).encode(target)).to_i
      end if comparator
      @collations[name] = comparator

      check Driver.sqlite3_create_collation(@db, name,
            Constants::TextRep::UTF8, nil, cb);
    end

    # call-seq: set_authorizer = auth
    #
    # Set the authorizer for this database.  +auth+ must respond to +call+, and
    # +call+ must take 5 arguments.
    #
    # Installs (or removes) a block that will be invoked for every access
    # to the database. If the block returns 0 (or +true+), the statement
    # is allowed to proceed. Returning 1 or false causes an authorization error to
    # occur, and returning 2 or nil causes the access to be silently denied.
    #
    def authorizer=(handler)
      must_be_open!
      @authorizer = handler

      if handler
        auth = Closure::BlockCaller.new(TYPE_VOIDP, AUTH_PARAMS) do |*args|
          args.shift # remove nil
          ruby_args = [args.shift]
          args.each do |ptr|
            ruby_args << ptr.null? ? nil : ptr.to_s
          end
          ret = @authorizer.call(*ruby_args)
          if ret.is_a? Fixnum
            ret
          elsif ret == false || ret == true
            ret == true ? OK : DENY
          else
            IGNORE
          end
        end
      else
        auth = nil
      end

      check Driver.sqlite3_set_authorizer(@db, auth, nil)
    end

    def authorizer(&block)
      self.authorizer = block if block_given?
      @authorizer
    end

    def busy_timeout(ms)
      must_be_open!
      Driver.sqlite3_busy_timeout(@db, ms)
    end

    # call-seq: define_function(name) { |args,...| }
    #
    # Define a function named +name+ with +args+.  The arity of the block
    # will be used as the arity for the function defined.
    #
    def define_function(name, &handler)
      must_be_open!
      @functions[name] = handler
      check Driver.sqlite3_create_function(@db, name, handler.arity,
        Constants::TextRep::UTF8, nil, compile_function(handler), nil, nil)
    end

    # call-seq: define_aggregator(name, aggregator)
    #
    # Define an aggregate function named +name+ using the object +aggregator+.
    # +aggregator+ must respond to +step+ and +finalize+.  +step+ will be called
    # with row information and +finalize+ must return the return value for the
    # aggregator function.
    #
    def define_aggregator(name, aggregator)
      must_be_open!
      @functions[name] = aggregator

      step = Closure::BlockCaller.new(TYPE_VOIDP, FUNC_PARAMS) do |_, argc, argv|
        aggregator.step(*native_to_ruby_args(argc, argv))
        0 # return something
      end

      fin = Closure::BlockCaller.new(TYPE_VOIDP, FUNC_PARAMS) do |ctx, _, _|
        Driver.set_context_result(ctx, aggregator.finalize())
        0 # return something
      end

    check Driver.sqlite3_create_function(@db, name,
        aggregator.method(:step).arity,
        Constants::TextRep::UTF8, nil, nil, step, fin)
    end

    # Creates a new aggregate function for use in SQL statements. Aggregate
    # functions are functions that apply over every row in the result set,
    # instead of over just a single row. (A very common aggregate function
    # is the "count" function, for determining the number of rows that match
    # a query.)
    #
    # The new function will be added as +name+, with the given +arity+. (For
    # variable arity functions, use -1 for the arity.)
    #
    # The +step+ parameter must be a proc object that accepts as its first
    # parameter a FunctionProxy instance (representing the function
    # invocation), with any subsequent parameters (up to the function's arity).
    # The +step+ callback will be invoked once for each row of the result set.
    #
    # The +finalize+ parameter must be a +proc+ object that accepts only a
    # single parameter, the FunctionProxy instance representing the current
    # function invocation. It should invoke FunctionProxy#result= to
    # store the result of the function.
    #
    # Example:
    #
    #   db.create_aggregate( "lengths", 1 ) do
    #     step do |func, value|
    #       func[ :total ] ||= 0
    #       func[ :total ] += ( value ? value.length : 0 )
    #     end
    #
    #     finalize do |func|
    #       func.result = func[ :total ] || 0
    #     end
    #   end
    #
    #   puts db.get_first_value( "select lengths(name) from table" )
    #
    # See also #create_aggregate_handler for a more object-oriented approach to
    # aggregate functions.
    def create_aggregate( name, arity, step=nil, finalize=nil,
      text_rep=Constants::TextRep::ANY, &block )

      factory = Class.new do
        def self.step( &block )
          define_method(:step, &block)
        end

        def self.finalize( &block )
          define_method(:finalize, &block)
        end
      end

      if block_given?
        factory.instance_eval(&block)
      else
        factory.class_eval do
          define_method(:step, step)
          define_method(:finalize, finalize)
        end
      end

      proxy = factory.new
      proxy.extend(Module.new {
        attr_accessor :ctx

        def step( *args )
          super(@ctx, *args)
        end

        def finalize
          super(@ctx)
        end
      })
      proxy.ctx = FunctionProxy.new
      define_aggregator(name, proxy)
    end

    # This is another approach to creating an aggregate function (see
    # #create_aggregate). Instead of explicitly specifying the name,
    # callbacks, arity, and type, you specify a factory object
    # (the "handler") that knows how to obtain all of that information. The
    # handler should respond to the following messages:
    #
    # +arity+:: corresponds to the +arity+ parameter of #create_aggregate. This
    #           message is optional, and if the handler does not respond to it,
    #           the function will have an arity of -1.
    # +name+:: this is the name of the function. The handler _must_ implement
    #          this message.
    # +new+:: this must be implemented by the handler. It should return a new
    #         instance of the object that will handle a specific invocation of
    #         the function.
    #
    # The handler instance (the object returned by the +new+ message, described
    # above), must respond to the following messages:
    #
    # +step+:: this is the method that will be called for each step of the
    #          aggregate function's evaluation. It should implement the same
    #          signature as the +step+ callback for #create_aggregate.
    # +finalize+:: this is the method that will be called to finalize the
    #              aggregate function's evaluation. It should implement the
    #              same signature as the +finalize+ callback for
    #              #create_aggregate.
    #
    # Example:
    #
    #   class LengthsAggregateHandler
    #     def self.arity; 1; end
    #     def self.name; 'lengths'; end
    #
    #     def initialize
    #       @total = 0
    #     end
    #
    #     def step( ctx, name )
    #       @total += ( name ? name.length : 0 )
    #     end
    #
    #     def finalize( ctx )
    #       ctx.result = @total
    #     end
    #   end
    #
    #   db.create_aggregate_handler( LengthsAggregateHandler )
    #   puts db.get_first_value( "select lengths(name) from A" )
    def create_aggregate_handler( handler )
      proxy = Class.new do
        def initialize klass
          @klass = klass
          @fp    = FunctionProxy.new
        end

        def step( *args )
          instance.step(@fp, *args)
        end

        def finalize
          instance.finalize @fp
          @instance = nil
          @fp.result
        end

        private

        def instance
          @instance ||= @klass.new
        end
      end
      define_aggregator(handler.name, proxy.new(handler))
      self
    end

    # Creates a new function for use in SQL statements. It will be added as
    # +name+, with the given +arity+. (For variable arity functions, use
    # -1 for the arity.)
    #
    # The block should accept at least one parameter--the FunctionProxy
    # instance that wraps this function invocation--and any other
    # arguments it needs (up to its arity).
    #
    # The block does not return a value directly. Instead, it will invoke
    # the FunctionProxy#result= method on the +func+ parameter and
    # indicate the return value that way.
    #
    # Example:
    #
    #   db.create_function( "maim", 1 ) do |func, value|
    #     if value.nil?
    #       func.result = nil
    #     else
    #       func.result = value.split(//).sort.join
    #     end
    #   end
    #
    #   puts db.get_first_value( "select maim(name) from table" )
    def create_function(name, arity, text_rep=Constants::TextRep::ANY, &handler)
      must_be_open!
      @functions[name] = handler
      check Driver.sqlite3_create_function(@db, name, arity,
        text_rep, nil, compile_function(FunctionProxy.proxy(handler)), nil, nil)
    end

    # def create_aggregate_handler(aggregator)
    #   step = lambda do |*args|
    #     fp = FunctionProxy.new
    #     args.unshift(fp)
    #     aggregator.new.step(*args)
    #     fp.result
    #   end
    #   finalize = lambda do |*args|
    #     fp = FunctionProxy.new
    #     args.unshift(fp)
    #     aggregator.new.finalize(*args)
    #     fp.result
    #   end
    #   check Driver.sqlite3_create_function(@db,
    #                                               aggregator.name,
    #                                               aggregator.arity,
    #                                               aggregator.text_rep,
    #                                               nil, nil,
    #                                               compile_function(step),
    #                                               compile_function(finalize))
    # end

    # Executes the given SQL statement. If additional parameters are given,
    # they are treated as bind variables, and are bound to the placeholders in
    # the query.
    #
    # Note that if any of the values passed to this are hashes, then the
    # key/value pairs are each bound separately, with the key being used as
    # the name of the placeholder to bind the value to.
    #
    # The block is optional. If given, it will be invoked for each row returned
    # by the query. Otherwise, any results are accumulated into an array and
    # returned wholesale.
    #
    # See also #execute2, #query, and #execute_batch for additional ways of
    # executing statements.
    def execute sql, bind_vars = [], *args, &block
      if bind_vars.nil? || !args.empty?
        if args.empty?
          bind_vars = []
        else
          bind_vars = [bind_vars] + args
        end
      end

      prepare( sql ) do |stmt|
        stmt.bind_params(bind_vars)
        columns = stmt.columns

        if block_given?
          stmt.each do |row|
            if @results_as_hash
              yield ordered_map_for(columns, row)
            else
              yield row
            end
          end
        else
          if @results_as_hash
            stmt.map { |row| ordered_map_for(columns, row) }
          else
            stmt.to_a
          end
        end
      end
    end

  # Executes the given SQL statement, exactly as with #execute. However, the
  # first row returned (either via the block, or in the returned array) is
  # always the names of the columns. Subsequent rows correspond to the data
  # from the result set.
  #
  # Thus, even if the query itself returns no rows, this method will always
  # return at least one row--the names of the columns.
  #
  # See also #execute, #query, and #execute_batch for additional ways of
  # executing statements.
  def execute2( sql, *bind_vars )
    prepare( sql ) do |stmt|
      result = stmt.execute( *bind_vars )
      if block_given?
        yield stmt.columns
        result.each { |row| yield row }
      else
        return result.inject( [ stmt.columns ] ) { |arr,row|
          arr << row; arr }
      end
    end
  end

    # Executes all SQL statements in the given string. By contrast, the other
    # means of executing queries will only execute the first statement in the
    # string, ignoring all subsequent statements. This will execute each one
    # in turn. The same bind parameters, if given, will be applied to each
    # statement.
    #
    # This always returns +nil+, making it unsuitable for queries that return
    # rows.
    def execute_batch( sql, bind_vars = [], *args )
      # FIXME: remove this stuff later
      unless [Array, Hash].include?(bind_vars.class)
        bind_vars = [bind_vars]
      end

      # FIXME: remove this stuff later
      if bind_vars.nil? || !args.empty?
        if args.empty?
          bind_vars = []
        else
          bind_vars = [nil] + args
        end
      end
      sql = sql.strip
      until sql.empty? do
        prepare( sql ) do |stmt|
          unless stmt.closed?
            # FIXME: this should probably use sqlite3's api for batch execution
            # This implementation requires stepping over the results.
            if bind_vars.length == stmt.bind_parameter_count
              stmt.bind_params(bind_vars)
            end
            stmt.step
          end
          sql = stmt.remainder.strip
        end
      end
      # FIXME: we should not return `nil` as a success return value
      nil
    end

    alias_method :batch, :execute_batch

    def complete?(sql)
      Driver.sqlite3_complete(sql.to_s) == 1
    end

    def changes
      must_be_open!
      Driver.sqlite3_changes(@db)
    end

    def errcode
      must_be_open!
      Driver.sqlite3_errcode(@db)
    end

    def errmsg
      must_be_open!
      Driver.sqlite3_errmsg(@db).to_s
    end

    def total_changes
      must_be_open!
      Driver.sqlite3_total_changes(@db)
    end

    def last_insert_row_id
      must_be_open!
      Driver.sqlite3_last_insert_rowid(@db)
    end

    # This is a convenience method for creating a statement, binding
    # paramters to it, and calling execute:
    #
    #   result = db.query( "select * from foo where a=?", [5])
    #   # is the same as
    #   result = db.prepare( "select * from foo where a=?" ).execute( 5 )
    #
    # You must be sure to call +close+ on the ResultSet instance that is
    # returned, or you could have problems with locks on the table. If called
    # with a block, +close+ will be invoked implicitly when the block
    # terminates.
    def query( sql, bind_vars = [], *args )

      if bind_vars.nil? || !args.empty?
        if args.empty?
          bind_vars = []
        else
          bind_vars = [bind_vars] + args
        end
      end

      result = prepare( sql ).execute( bind_vars )
      if block_given?
        begin
          yield result
        ensure
          result.close
        end
      else
        return result
      end
    end

    alias_method :exec, :execute

    # Returns a Statement object representing the given SQL. This does not
    # execute the statement; it merely prepares the statement for execution.
    #
    # The Statement can then be executed using Statement#execute.
    #
    def prepare sql
      must_be_open!
      stmt = SQLite3::Statement.new(self, sql)
      return stmt unless block_given?

      begin
        yield stmt
      ensure
        stmt.close unless stmt.closed?
      end
    end

    # A convenience method for obtaining the first row of a result set, and
    # discarding all others. It is otherwise identical to #execute.
    #
    # See also #get_first_value.
    def get_first_row( sql, *bind_vars )
      execute( sql, *bind_vars ).first
    end

    # A convenience method for obtaining the first value of the first row of a
    # result set, and discarding all other values and rows. It is otherwise
    # identical to #execute.
    #
    # See also #get_first_row.
    def get_first_value( sql, *bind_vars )
      execute( sql, *bind_vars ) { |row| return row[0] }
      nil
    end

    # Begins a new transaction. Note that nested transactions are not allowed
    # by SQLite, so attempting to nest a transaction will result in a runtime
    # exception.
    #
    # The +mode+ parameter may be either <tt>:deferred</tt> (the default),
    # <tt>:immediate</tt>, or <tt>:exclusive</tt>.
    #
    # If a block is given, the database instance is yielded to it, and the
    # transaction is committed when the block terminates. If the block
    # raises an exception, a rollback will be performed instead. Note that if
    # a block is given, #commit and #rollback should never be called
    # explicitly or you'll get an error when the block terminates.
    #
    # If a block is not given, it is the caller's responsibility to end the
    # transaction explicitly, either by calling #commit, or by calling
    # #rollback.
    def transaction( mode = :deferred )
      execute "begin #{mode.to_s} transaction"

      if block_given?
        abort = false
        begin
          yield self
        rescue ::Object
          abort = true
          raise
        ensure
          abort and rollback or commit
        end
      end

      true
    end

    def transaction_active?
      must_be_open!
      Driver.sqlite3_get_autocommit(@db) != 1
    end

    def encoding
      @encoding = Encoding.find(get_first_value('PRAGMA encoding'))
    end

    # call-seq:
    #    trace { |sql| ... }
    #    trace(Class.new { def call sql; end }.new)
    #
    # Installs (or removes) a block that will be invoked for every SQL
    # statement executed. The block receives one parameter: the SQL statement
    # executed. If the block is +nil+, any existing tracer will be uninstalled.
    #
    def trace(tracer = nil, &block)
      must_be_open!

      tracer = block if block_given?
      @tracefunc = tracer

      if tracer
        cb = Closure::BlockCaller.new(TYPE_VOIDP, TRACE_PARAMS) do |_, sql|
          tracer.call(sql.to_s)
          0 # return something
        end
      end

      Driver.sqlite3_trace(@db, cb, nil)
      @tracefunc
    end

    def readonly?(db = 'main')
      must_be_open!
      Driver.sqlite3_db_readonly(@db, db.to_s) == 1
    end

    # Commits the current transaction. If there is no current transaction,
    # this will cause an error to be raised. This returns +true+, in order
    # to allow it to be used in idioms like
    # <tt>abort? and rollback or commit</tt>.
    def commit
      execute "commit transaction"
      true
    end

    # Rolls the current transaction back. If there is no current transaction,
    # this will cause an error to be raised. This returns +true+, in order
    # to allow it to be used in idioms like
    # <tt>abort? and rollback or commit</tt>.
    def rollback
      execute "rollback transaction"
      true
    end

    def check(error_code)
      if error_code != SQLITE_OK
        ptr = Driver.sqlite3_errmsg(@db)
        fail(ERR_EXEPTION_MAPPING[error_code] || RuntimeError, ptr.to_s)
      end
      error_code
    end

    private

    def sqlite_encoding(str, sqlite_encoding)
      case sqlite_encoding
      when SQLite3::Constants::TextRep::UTF8
        str.force_encoding(Encoding::UTF_8)
      when SQLite3::Constants::TextRep::UTF16LE
        str.force_encoding(Encoding::UTF_16LE)
      when SQLite3::Constants::TextRep::UTF16BE
        str.force_encoding(Encoding::UTF_16BE)
      when SQLite3::Constants::TextRep::UTF16
        str.force_encoding(Encoding::UTF_16)
      when SQLite3::Constants::TextRep::ANY
        str
      end
    end

    def native_to_ruby_args(argc, argv)
      args = []
      argc.times do |i|
        args << Value.new(self, (argv + (i * SIZEOF_VOIDP)).ptr).native
      end
      args
    end

    def compile_function(handler)
      Closure::BlockCaller.new(TYPE_VOIDP, FUNC_PARAMS) do |ctx, argc, argv|
        args = native_to_ruby_args(argc, argv)
        Driver.set_context_result(ctx, handler.call(*args))
        0 # return something
      end
    end

    def must_be_open!
      raise Exception, "#{self.class} closed!" if closed?
    end

    def ordered_map_for columns, row
      h = Hash[*columns.zip(row).flatten]
      row.each_with_index { |r, i| h[i] = r }
      h
    end
  end
end
