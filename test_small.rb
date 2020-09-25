class Foo
  attr_reader :symbols

  def initialize
    @symbols = {}
  end

  def add_symbol(symbol)
    @symbols[symbol.qname] = symbol
  end
end

json = JSON.parse(out)
