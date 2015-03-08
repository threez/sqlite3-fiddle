module SQLite3
  SQLITE_OK = 0
  SQLITE_ROW = 100
  SQLITE_DONE = 101
  SQLITE_INTEGER = 1
  SQLITE_FLOAT = 2
  SQLITE_TEXT = 3
  SQLITE_BLOB = 4
  SQLITE_NULL = 5

  module Constants
    module TextRep
      UTF8    = 1
      UTF16LE = 2
      UTF16BE = 3
      UTF16   = 4
      ANY     = 5
    end

    module ColumnType
      INTEGER = 1
      FLOAT   = 2
      TEXT    = 3
      BLOB    = 4
      NULL    = 5
    end
  end

  class Exception < ::StandardError
    @code = 0

    # The numeric error code that this exception represents.
    def self.code
      @code
    end

    # A convenience for accessing the error code for this exception.
    def code
      self.class.code
    end
  end

  ERROR      =  1   # SQL error or missing database
  INTERNAL   =  2   # An internal logic error in SQLite
  PERM       =  3   # Access permission denied
  ABORT      =  4   # Callback routine requested an abort
  BUSY       =  5   # The database file is locked
  LOCKED     =  6   # A table in the database is locked
  NOMEM      =  7   # A malloc() failed
  READONLY   =  8   # Attempt to write a readonly database
  INTERRUPT  =  9   # Operation terminated by sqlite_interrupt()
  IOERR      = 10   # Some kind of disk I/O error occurred
  CORRUPT    = 11   # The database disk image is malformed
  NOTFOUND   = 12   # (Internal Only) Table or record not found
  FULL       = 13   # Insertion failed because database is full
  CANTOPEN   = 14   # Unable to open the database file
  PROTOCOL   = 15   # Database lock protocol error
  EMPTY      = 16   # (Internal Only) Database table is empty
  SCHEMA     = 17   # The database schema changed
  TOOBIG     = 18   # Too much data for one row of a table
  CONSTRAINT = 19   # Abort due to contraint violation
  MISMATCH   = 20   # Data type mismatch
  MISUSE     = 21   # Library used incorrectly
  NOLFS      = 22   # Uses OS features not supported on host
  AUTH       = 23   # Authorization denied

  OK         = 0
  DENY       = 1    # Abort the SQL statement with an error
  IGNORE     = 2    # Don't allow access, but don't generate an error

  class SQLException < Exception; end
  class InternalException < Exception; end
  class PermissionException < Exception; end
  class AbortException < Exception; end
  class BusyException < Exception; end
  class LockedException < Exception; end
  class MemoryException < Exception; end
  class ReadOnlyException < Exception; end
  class InterruptException < Exception; end
  class IOException < Exception; end
  class CorruptException < Exception; end
  class NotFoundException < Exception; end
  class FullException < Exception; end
  class CantOpenException < Exception; end
  class ProtocolException < Exception; end
  class EmptyException < Exception; end
  class SchemaChangedException < Exception; end
  class TooBigException < Exception; end
  class ConstraintException < Exception; end
  class MismatchException < Exception; end
  class MisuseException < Exception; end
  class UnsupportedException < Exception; end
  class AuthorizationException < Exception; end
  class FormatException < Exception; end
  class RangeException < Exception; end
  class NotADatabaseException < Exception; end

  ERR_EXEPTION_MAPPING = {
    ERROR      => SQLException,
    INTERNAL   => InternalException,
    PERM       => PermissionException,
    ABORT      => AbortException,
    BUSY       => BusyException,
    LOCKED     => LockedException,
    NOMEM      => MemoryException,
    READONLY   => ReadOnlyException,
    INTERRUPT  => InterruptException,
    IOERR      => IOException,
    CORRUPT    => CorruptException,
    NOTFOUND   => NotFoundException,
    FULL       => FullException,
    CANTOPEN   => CantOpenException,
    PROTOCOL   => ProtocolException,
    EMPTY      => EmptyException,
    SCHEMA     => SchemaChangedException,
    TOOBIG     => TooBigException,
    CONSTRAINT => ConstraintException,
    MISMATCH   => MismatchException,
    MISUSE     => MisuseException,
    NOLFS      => UnsupportedException,
    AUTH       => AuthorizationException
  }.freeze

  ERR_EXEPTION_MAPPING.each do |code, klass|
    klass.instance_variable_set('@code', code)
  end
end

class SQLite3::Blob < String; end

class String
  def to_blob
    SQLite3::Blob.new( self )
  end
end
