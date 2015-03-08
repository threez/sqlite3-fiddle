module SQLite3
  class Backup
    def initialize(dest, destname, source, sourcename)
	    fail "Destination db closed" if dest.closed?
	    fail "Source db closed" if source.closed?
      @backup = Driver.sqlite3_backup_init(dest.handle, destname,
                                           source.handle, sourcename)
    end

    def step(page)
      Driver.sqlite3_backup_step(@backup, page)
    end

    def finish
      Driver.sqlite3_backup_finish(@backup)
    end

    def remaining
      Driver.sqlite3_backup_remaining(@backup)
    end

    def pagecount
      Driver.sqlite3_backup_pagecount(@backup)
    end
  end
end
