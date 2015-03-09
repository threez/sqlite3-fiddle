module SQLite3
  MAJOR = 1
  MINOR = 0
  PATCH = 0
  VERSION = [MAJOR, MINOR, PATCH].join('.')

  def self.libversion
    Driver.sqlite3_libversion().to_s
  end
end
