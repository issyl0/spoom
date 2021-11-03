# typed: true

require "sorbet-runtime"

extend T::Sig

T.assert_type!([1, 2, 3], Array[Integer])
T.assert_type!({}, Hash[String, Integer])
T.assert_type!([1, 2, 3], Enumerable[Integer])
T.assert_type!([1, 2, 3], Enumerator[Integer])
T.assert_type!([1].lazy.grep(1..10), Enumerator::Lazy[Integer])
