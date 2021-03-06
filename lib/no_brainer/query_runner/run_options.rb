class NoBrainer::QueryRunner::RunOptions < NoBrainer::QueryRunner::Middleware
  # XXX NoBrainer::Database#drop() uses Thread.current[:nobrainer_options]
  # We should fix that hack.

  def self.with_database(db_name, &block)
    with_options(:db => db_name, &block)
  end

  def self.with_options(options={}, &block)
    old_options = Thread.current[:nobrainer_options]
    Thread.current[:nobrainer_options] = (old_options || {}).merge(options.symbolize_keys)
    block.call if block
  ensure
    Thread.current[:nobrainer_options] = old_options
  end

  def call(env)
    env[:options].symbolize_keys!
    if Thread.current[:nobrainer_options]
      env[:options] = env[:options].reverse_merge(Thread.current[:nobrainer_options])
    end

    if NoBrainer::Config.durability.to_s != 'hard'
      env[:options] = env[:options].reverse_merge(:durability => NoBrainer::Config.durability)
    end

    if env[:options][:db] && !env[:options][:db].is_a?(RethinkDB::RQL)
      env[:db_name] = env[:options][:db].to_s
      env[:options][:db] = RethinkDB::RQL.new.db(env[:db_name])
    end

    @runner.call(env)
  end
end
