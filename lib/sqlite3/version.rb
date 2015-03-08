module SQLite3
  VERSION = '1.3.9'
  
  def self.libversion
    Driver.sqlite3_libversion().to_s
  end
end
