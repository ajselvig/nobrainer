class NoBrainer::Selection
  attr_accessor :query, :klass

  def initialize(query_or_selection, klass=nil)
    # We are saving klass as a context
    # so that the table_on_demand middleware can do its job
    # TODO FIXME Sadly it gets funny with associations
    if query_or_selection.is_a? NoBrainer::Selection
      selection = query_or_selection
      self.query = selection.query
      self.klass = selection.klass
    else
      query = query_or_selection
      self.query = query
      self.klass = klass
    end
  end

  delegate :inspect, :to => :query

  def chain(query)
    NoBrainer::Selection.new(query, klass)
  end

  def run
    NoBrainer.run { self }
  end

  [:filter, :skip, :limit].each do |method|
    class_eval <<-RUBY, __FILE__, __LINE__ + 1
      def #{method}(*args, &block)
        chain query.#{method}(*args, &block)
      end
    RUBY
  end

  alias_method :where, :filter

  [:count, :update, :delete].each do |method|
    class_eval <<-RUBY, __FILE__, __LINE__ + 1
      def #{method}(*args, &block)
        chain(query.#{method}(*args, &block)).run
      end
    RUBY
  end

  # @rules is a hash with the format {:field1 => :asc, :field2 => :desc}
  # XXX This only make sense because we have ordered hashes since 1.9.3
  # But is it true for other interpreters?
  def order_by(rules)
    rules = rules.map do |k,v|
      case v
      when :asc  then [k, true]
      when :desc then [k, false]
      else raise "please pass :asc or :desc, not #{v}"
      end
    end
    chain query.order_by(*rules)
  end

  def first(order = :asc)
    klass.ensure_table! # needed as soon as we get a Query_Result
    # TODO FIXME are not sequential, how do we do that ?? :(
    # TODO FIXME do not add an order_by if there is already one
    attrs = order_by(:id => order).limit(1).run.first
    klass.new_from_db(attrs)
  end

  def last
    first(:desc)
  end

  def each(&block)
    return enum_for(:each) unless block

    klass.ensure_table! # needed as soon as we get a Query_Result
    run.each do |attrs|
      yield klass.new_from_db(attrs)
    end
    self
  end

  def empty?
    count == 0
  end

  def any?
    !empty?
  end

  def destroy
    each { |doc| doc.destroy }
  end
  alias_method :destroy_all, :destroy

  def method_missing(name, *args, &block)
    each.__send__(name, *args, &block)
  end
end