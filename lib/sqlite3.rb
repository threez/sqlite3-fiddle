require 'sqlite3/constants'
require 'sqlite3/driver'
require 'sqlite3/resultset'
require 'sqlite3/statement'
require 'sqlite3/pragmas'
require 'sqlite3/value'
require 'sqlite3/database'
require 'sqlite3/backup'

module SQLite3
  VERSION = '1.3.9'

  def self.libversion
    Driver.sqlite3_libversion().to_s
  end
end
