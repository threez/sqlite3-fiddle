require 'sqlite3/constants'

module SQLite3

  class Value
    attr_reader :handle

    def initialize(db, handle)
      @handle = handle
    end

    def null?
      type == :null
    end

    def to_blob
      bytes = size
      Blob.new(Driver.sqlite3_value_blob(@handle).to_s(bytes))
    end

    def length(utf16=false)
      if utf16
        Driver.sqlite3_value_bytes16(@handle)
      else
        Driver.sqlite3_value_bytes(@handle)
      end
    end

    alias_method :size, :length

    def to_f
      Driver.sqlite3_value_double(@handle)
    end

    def to_i
      Driver.sqlite3_value_int(@handle)
    end

    def to_int64
      Driver.sqlite3_value_int64(@handle)
    end

    def to_s(utf16=false)
      if utf16
        Driver.sqlite3_result_text16(@handle).to_s
      else
        Driver.sqlite3_value_text(@handle).to_s
      end
    end

    def type
      case Driver.sqlite3_value_type(@handle)
        when SQLITE_INTEGER then :int
        when SQLITE_FLOAT   then :float
        when SQLITE_TEXT    then :text
        when SQLITE_BLOB    then :blob
        when SQLITE_NULL    then :null
      end
    end

    def native
      case Driver.sqlite3_value_type(@handle)
      when SQLITE_INTEGER then to_int64
      when SQLITE_FLOAT   then to_f
      when SQLITE_TEXT    then to_s
      when SQLITE_BLOB    then to_blob
      when SQLITE_NULL    then nil
      end
    end
  end
end
