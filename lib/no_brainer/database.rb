class NoBrainer::Database
  attr_accessor :connection

  # FIXME This class is a bit weird as we don't use it to represent the current
  # database.

  delegate :database_name, :to => :connection

  def initialize(connection)
    self.connection = connection
  end

  def raw
    @raw ||= RethinkDB::RQL.new.db(database_name)
  end

  def drop!
    # FIXME Sad hack.
    db = (Thread.current[:nobrainer_options] || {})[:db] || database_name
    connection.db_drop(db)['dropped'] == 1
  end

  # Note that truncating each table (purge) is much faster than dropping the
  # database (drop)
  def purge!(options={})
    table_list.each do |table_name|
      NoBrainer.run { |r| r.table(table_name).delete }
    end
    true
  rescue RuntimeError => e
    raise e unless e.message =~ /No entry with that name/
  end

  [:table_create, :table_drop, :table_list].each do |cmd|
    class_eval <<-RUBY, __FILE__, __LINE__ + 1
      def #{cmd}(*args)
        NoBrainer.run { |r| r.#{cmd}(*args) }
      end
    RUBY
  end
end
