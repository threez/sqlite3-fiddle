
require 'fiddle'
require 'fiddle/import'

module SQLite3
  module Driver
    extend Fiddle::Importer
    dlload '/usr/local/Cellar/sqlite/3.8.8.3/lib/libsqlite3.dylib' #'/usr/lib/libsqlite3.so'

    extern 'const char *sqlite3_libversion()'
    extern 'int sqlite3_busy_timeout(void*, int)'
    extern 'int sqlite3_open_v2(const char *, sqlite3 **, int, const char *)'
    extern 'int sqlite3_open16(const void *,sqlite3 **)'
    extern 'const char *sqlite3_errstr(int)'
    extern 'int sqlite3_close(sqlite3*)'
    extern 'int sqlite3_changes(void*)'
    extern 'int sqlite3_total_changes(sqlite3*)'
    extern 'long long sqlite3_last_insert_rowid(void*)'
    extern 'int sqlite3_prepare_v2(void*, void*, int, void*, void*)'
    extern 'int sqlite3_step(void*)'
    extern 'int sqlite3_finalize(void*)'
    extern 'int sqlite3_reset(void *)'
    extern 'int sqlite3_clear_bindings(void*)'
    extern 'int sqlite3_bind_parameter_count(void*)'
    extern 'int sqlite3_column_count(void*)'
    extern 'const char *sqlite3_column_name(void*, int)'
    extern 'const char *sqlite3_column_decltype(void*, int)'
    extern 'const char *sqlite3_column_database_name(void*,int)'
    extern 'const char *sqlite3_column_table_name(void*,int)'
    extern 'const char *sqlite3_column_origin_name(void*,int)'
    extern 'int sqlite3_column_type(void*, int)'
    extern 'const void *sqlite3_column_blob(void*, int)'
    extern 'int sqlite3_column_bytes(void*, int)'
    extern 'double sqlite3_column_double(void*, int)'
    extern 'long long sqlite3_column_int64(void*, int)'
    extern 'const unsigned char *sqlite3_column_text(void*, int)'
    extern 'int sqlite3_bind_blob(void*, int, const void*, int, void*)'
    extern 'int sqlite3_bind_double(void*, int, double)'
    extern 'int sqlite3_bind_int64(void*, int, long long)'
    extern 'int sqlite3_bind_null(void*, int)'
    extern 'int sqlite3_bind_text(void*,int,const char*,int,void*)'
    extern 'int sqlite3_bind_text16(void*,int,const char*,int,void*)'
    extern 'int sqlite3_bind_parameter_index(sqlite3_stmt*, const char *)'
    extern 'int sqlite3_errcode(sqlite3 *)'
    extern 'int sqlite3_complete(const char *)'
    extern 'int sqlite3_get_autocommit(sqlite3*)'
    extern 'int sqlite3_db_readonly(sqlite3 *, const char *)'
    extern 'const char *sqlite3_errmsg(sqlite3*)'
    extern 'void *sqlite3_trace(void*, void*, void*)'
    extern 'int sqlite3_set_authorizer(sqlite3*, void*, void*)'
    extern 'const void *sqlite3_value_blob(sqlite3_value*)'
    extern 'int sqlite3_value_bytes(sqlite3_value*)'
    extern 'int sqlite3_value_bytes16(sqlite3_value*)'
    extern 'double sqlite3_value_double(sqlite3_value*)'
    extern 'int sqlite3_value_int(sqlite3_value*)'
    extern 'long long sqlite3_value_int64(sqlite3_value*)'
    extern 'const unsigned char *sqlite3_value_text(sqlite3_value*)'
    extern 'const void *sqlite3_value_text16(sqlite3_value*)'
    extern 'const void *sqlite3_value_text16le(sqlite3_value*)'
    extern 'const void *sqlite3_value_text16be(sqlite3_value*)'
    extern 'int sqlite3_value_type(sqlite3_value*)'
    extern 'int sqlite3_value_numeric_type(sqlite3_value*)'
    extern 'void sqlite3_result_blob(sqlite3_context*, const void*, int, void*)'
    extern 'void sqlite3_result_double(sqlite3_context*, double)'
    extern 'void sqlite3_result_error(sqlite3_context*, const char*, int)'
    extern 'void sqlite3_result_int(sqlite3_context*, int)'
    extern 'void sqlite3_result_int64(sqlite3_context*, long long)'
    extern 'void sqlite3_result_null(sqlite3_context*)'
    extern 'void sqlite3_result_text(sqlite3_context*, const char*, int, void*)'
    extern 'void sqlite3_result_text16(sqlite3_context*, const char*, int, void*)'
    extern 'int sqlite3_create_function(sqlite3 *,const char *,int,int,void*,void*,void*,void*)'
    extern 'void *sqlite3_user_data(sqlite3_context*)'
    extern 'void sqlite3_interrupt(sqlite3*)'
    extern 'int sqlite3_busy_handler(sqlite3*, void*, void*)'
    extern 'int sqlite3_create_collation(sqlite3*,const char *,int,void *,void*)'
    extern 'const char *sqlite3_errmsg(sqlite3*)'

    def self.set_context_result(ctx, var)
      case var
      when Blob
        Driver.sqlite3_result_blob(ctx, var.to_s, var.to_s.size, nil)
      when String
        if var.encoding == Encoding::UTF_16LE ||
           var.encoding == Encoding::UTF_16BE
          Driver.sqlite3_result_text16(ctx, var, -1, nil)
        else

          Driver.sqlite3_result_text(ctx, var.encode(Encoding::UTF_8), -1, nil)
        end
      when Fixnum, Bignum
        Driver.sqlite3_result_int64(ctx, var)
      when Float
        Driver.sqlite3_result_double(ctx, var)
      when NilClass
        Driver.sqlite3_result_null(ctx)
      when TrueClass, FalseClass
        Driver.sqlite3_result_int(ctx, var ? 1 : 0)
      else
        raise RuntimeError, "can't return #{var.class}"
      end
    end
  end
end
