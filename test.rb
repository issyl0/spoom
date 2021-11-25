# typed: true

a = T.let([], T::Array[T.untyped])
a << 1
puts a.length

first = T.must(a.first)
puts first.foo
