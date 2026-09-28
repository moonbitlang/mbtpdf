// Property-based tests for the byte Input abstraction every parser in the
// library reads through.

///|
/// A byte buffer and a seek target, which may lie before the start or past
/// the end (file offsets such as /Prev, /XRefStm or object-stream /First come
/// from untrusted input).
priv struct SeekCase {
  data : Array[Byte]
  pos : Int
} derive(Debug)

///|
impl @quickcheck.Arbitrary for SeekCase with fn arbitrary(size, rs) {
  let n = rs
    .next_uint(limit=(size + 1).reinterpret_as_uint())
    .reinterpret_as_int()
  let data = Array::makei(n, _ => {
    rs.next_uint(limit=256).reinterpret_as_int().to_byte()
  })
  let pos = @quickcheck.frequency([
    (3, @quickcheck.int_range(0, n + 1)),
    (1, @quickcheck.int_range(-16, 0)),
    (1, @quickcheck.int_range(n, n + 16)),
    (1, @quickcheck.elements([-2147483648, -1000000000, 2147483647])),
  ]).run(size, rs)
  { data, pos, }
}

///|
impl @quickcheck.Shrink for SeekCase

///|
test "prop: Input::of_bytes reads data[pos] in range and no_more anywhere else" {
  @quickcheck.check(
    (c : SeekCase) => {
      let input = @pdfio.Input::of_bytes(c.data)
      (input.seek_in)(c.pos)
      let expected = if c.pos >= 0 && c.pos < c.data.length() {
        c.data[c.pos].to_int()
      } else {
        @pdfio.no_more
      }
      (input.input_byte)() == expected && (input.pos_in)() == c.pos + 1
    },
    observe=c => {
      [
        @quickcheck.classify(c.pos < 0, "before start"),
        @quickcheck.classify(c.pos >= c.data.length(), "past end"),
      ]
    },
    count=500,
    seed=0x5eec,
  )
}

///|
test "prop: sequential input_byte reproduces the buffer, then no_more" {
  @quickcheck.check(
    (data : Array[Byte]) => {
      let input = @pdfio.Input::of_bytes(data)
      let read = Array::makei(data.length(), _ => (input.input_byte)().to_byte())
      read == data &&
      (input.input_byte)() == @pdfio.no_more &&
      (input.input_byte)() == @pdfio.no_more &&
      input.in_channel_length == data.length()
    },
    count=200,
    seed=0x5e9,
  )
}

///|
test "regression: reading before the start of an input" {
  // A negative /Prev offset seeks before the buffer; input_byte used to do an
  // unchecked read at a negative index.
  let input = @pdfio.Input::of_string("abc")
  (input.seek_in)(-1)
  inspect((input.input_byte)() == @pdfio.no_more, content="true")
  (input.seek_in)(-1000000000)
  inspect((input.input_char)() is None, content="true")
}
