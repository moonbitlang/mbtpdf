// Property-based tests for the PDF object syntax: printer/parser round trips
// (PdfObject::to_string, PdfWrite::string_of_pdf, parse_single_object), name
// and string escaping, number formatting and lexer robustness.

///|
fn rand_int(rs : @quickcheck.RandomState, n : Int) -> Int {
  rs.next_uint(limit=n.reinterpret_as_uint()).reinterpret_as_int()
}

///|
/// A byte string stored the way the library stores PDF strings/names: one
/// UTF-16 code unit per byte (0..=255). Biased towards the bytes that need
/// escaping.
fn gen_byte_string(size : Int, rs : @quickcheck.RandomState) -> String {
  let special = "()\\\r\n\t\u{8}\u{c} /#%<>[]{}\u{0}\u{7f}\u{80}\u{ff}"
  let n = rand_int(rs, size + 1)
  let sb = StringBuilder()
  for _ in 0..<n {
    let c = match rand_int(rs, 3) {
      0 => special[rand_int(rs, special.length())].to_int()
      1 => 0x20 + rand_int(rs, 0x5f)
      _ => rand_int(rs, 256)
    }
    sb.write_char(c.unsafe_to_char())
  }
  sb.to_string()
}

///|
fn gen_real(rs : @quickcheck.RandomState) -> Double {
  match rand_int(rs, 6) {
    0 => (rand_int(rs, 2000001) - 1000000).to_double() / 1000.0
    1 => rs.next_double() * 1.0e-9
    2 => -rs.next_double() * 1.0e25
    3 =>
      @quickcheck.elements([
        0.1, -0.5, 1.0e-7, 1.5e-5, 1.0e21, 123456789.125, 5.0e-324, 1.7976931348623157e308,
        -2.0, 3.0e9, 0.30000000000000004,
      ]).run(8, rs)
    _ => {
      // random finite double from bits
      let d = rs.next_int64().reinterpret_as_double()
      if d.is_nan() || d.is_inf() {
        1.0
      } else {
        d
      }
    }
  }
}

///|
fn gen_obj(size : Int, rs : @quickcheck.RandomState) -> @pdf.PdfObject {
  let atoms = 8
  let k = if size <= 0 { rand_int(rs, atoms) } else { rand_int(rs, atoms + 3) }
  match k {
    0 => Null
    1 => Boolean(rand_int(rs, 2) == 0)
    2 => Integer(@quickcheck.Arbitrary::arbitrary(size, rs))
    3 => Real(gen_real(rs))
    4 | 5 => PdfString(gen_byte_string(size + 4, rs))
    6 => Name(@pdf.PdfName::of_string("/" + gen_byte_string(size + 4, rs)))
    7 => Indirect(rand_int(rs, 100000))
    8 | 9 => {
      let n = rand_int(rs, 5)
      PdfArray(Array::makei(n, _ => gen_obj(size / 2, rs)))
    }
    _ => {
      let n = rand_int(rs, 5)
      Dictionary(
        Array::makei(n, _ => {
          ("/" + gen_byte_string(6, rs), gen_obj(size / 2, rs))
        }),
      )
    }
  }
}

///|
priv struct Obj(@pdf.PdfObject) derive(Debug)

///|
impl @quickcheck.Arbitrary for Obj with fn arbitrary(size, rs) {
  Obj(gen_obj(size, rs))
}

///|
/// Shrink by replacing a container with one of its children.
impl @quickcheck.Shrink for Obj with fn shrink(self) {
  let Obj(o) = self
  let children : Array[Obj] = match o {
    PdfArray(xs) => xs.map(x => Obj(x))
    Dictionary(es) => es.map(e => Obj(e.1))
    _ => []
  }
  children.iter()
}

///|
/// Structural equality, with Integer/Real compared numerically: the printer
/// writes integral reals without a fraction ("3"), which reads back as an
/// Integer — the same number, and PDF treats them interchangeably.
fn obj_eq(a : @pdf.PdfObject, b : @pdf.PdfObject) -> Bool {
  match (a, b) {
    (Null, Null) => true
    (Boolean(x), Boolean(y)) => x == y
    (Integer(x), Integer(y)) => x == y
    (Real(x), Real(y)) => x == y
    (Real(x), Integer(y)) | (Integer(y), Real(x)) => x == y.to_double()
    (PdfString(x), PdfString(y)) => x == y
    (Name(x), Name(y)) => x == y
    (Indirect(x), Indirect(y)) => x == y
    (PdfArray(xs), PdfArray(ys)) =>
      xs.length() == ys.length() &&
      xs.iter().zip(ys.iter()).all(p => obj_eq(p.0, p.1))
    (Dictionary(xs), Dictionary(ys)) =>
      xs.length() == ys.length() &&
      xs.iter().zip(ys.iter()).all(p => p.0.0 == p.1.0 && obj_eq(p.0.1, p.1.1))
    _ => false
  }
}

///|
fn depth(o : @pdf.PdfObject) -> Int {
  match o {
    PdfArray(xs) =>
      1 + xs.fold(init=0, (m, x) => if depth(x) > m { depth(x) } else { m })
    Dictionary(es) =>
      1 + es.fold(init=0, (m, e) => if depth(e.1) > m { depth(e.1) } else { m })
    _ => 0
  }
}

///|
fn reparse(printed : String) -> @pdf.PdfObject raise {
  // A top-level "n 0 R" is read as the lone integer n by parse_single_object
  // (it stops after one atom), so compare references inside an array.
  @pdfsyntax.parse_single_object(printed)
}

///|
fn wrap(o : @pdf.PdfObject) -> @pdf.PdfObject {
  match o {
    Indirect(_) => PdfArray([o])
    _ => o
  }
}

///|
let writer : @pdfwrite.PdfWrite = @pdfwrite.PdfWrite::new(logger=_ => ())

///|
test "prop: parse_single_object inverts PdfObject::to_string" {
  @quickcheck.check(
    (o : Obj) => {
      let o = wrap(o.0)
      obj_eq(reparse(o.to_string()), o)
    },
    observe=o => {
      let o = o.0
      [
        @quickcheck.label(
          match o {
            PdfArray(_) => "array"
            Dictionary(_) => "dict"
            PdfString(_) => "string"
            Name(_) => "name"
            Real(_) => "real"
            Integer(_) => "int"
            _ => "other atom"
          },
        ),
        @quickcheck.classify(depth(o) >= 3, "depth>=3"),
      ]
    },
    counterexample_context=o => wrap(o.0).to_string(),
    count=1000,
    max_size=12,
    seed=0x9a45e,
  )
}

///|
test "prop: parse_single_object inverts PdfWrite::string_of_pdf" {
  @quickcheck.check(
    (o : Obj) => {
      let o = wrap(o.0)
      obj_eq(reparse(writer.string_of_pdf(o)), o)
    },
    counterexample_context=o => writer.string_of_pdf(wrap(o.0)),
    count=500,
    max_size=12,
    seed=0x3217e,
  )
}

///|
test "prop: the core and pdfwrite serializers agree" {
  @quickcheck.check(
    (o : Obj) => o.0.to_string() == writer.string_of_pdf(o.0),
    count=500,
    max_size=12,
    seed=0xa9ee,
  )
}

///|
test "prop: printing is idempotent through a parse (print . parse . print = print)" {
  @quickcheck.check(
    (o : Obj) => {
      let s = wrap(o.0).to_string()
      reparse(s).to_string() == s
    },
    filter=o => !has_integral_real(o.0),
    count=500,
    max_size=12,
    seed=0x1de9,
  )
}

///|
fn has_integral_real(o : @pdf.PdfObject) -> Bool {
  match o {
    Real(_) => true
    PdfArray(xs) => xs.iter().any(has_integral_real)
    Dictionary(es) => es.iter().any(e => has_integral_real(e.1))
    _ => false
  }
}

///|
/// A finite double.
priv struct Num(Double) derive(Debug)

///|
impl @quickcheck.Arbitrary for Num with fn arbitrary(_size, rs) {
  Num(gen_real(rs))
}

///|
impl @quickcheck.Shrink for Num

///|
fn is_pdf_number_syntax(s : String) -> Bool {
  // [-]digits[.digits] (no exponent, no leading '+', no trailing '.')
  let chars = s.to_array()
  let mut i = 0
  if i < chars.length() && chars[i] == '-' {
    i = i + 1
  }
  let int_start = i
  while i < chars.length() && chars[i] >= '0' && chars[i] <= '9' {
    i = i + 1
  }
  if i == int_start {
    return false
  }
  if i < chars.length() && chars[i] == '.' {
    i = i + 1
    let frac_start = i
    while i < chars.length() && chars[i] >= '0' && chars[i] <= '9' {
      i = i + 1
    }
    if i == frac_start {
      return false
    }
  }
  i == chars.length()
}

///|
test "prop: reals print in PDF number syntax and read back exactly" {
  @quickcheck.check(
    (n : Num) => {
      let Num(x) = n
      let s = @pdf.PdfObject::Real(x).to_string()
      is_pdf_number_syntax(s) &&
      (match reparse(s) {
        Real(y) => y == x
        Integer(i) => i.to_double() == x
        _ => false
      })
    },
    observe=n => {
      let Num(x) = n
      [
        @quickcheck.classify(x.abs() < 1.0e-6 && x != 0.0, "tiny"),
        @quickcheck.classify(x.abs() >= 1.0e21, "huge"),
        @quickcheck.classify(x == x.round(), "integral"),
      ]
    },
    counterexample_context=n => @pdf.PdfObject::Real(n.0).to_string(),
    count=1000,
    seed=0x4ea1,
  )
}

///|
test "prop: names round trip for arbitrary bytes" {
  @quickcheck.check(
    (b : Bytes) => {
      let name = @pdf.PdfName::of_bytes(
        Bytes::from_array([b'/', ..b.to_array()][:]),
      )
      let printed = @pdf.PdfObject::Name(name).to_string()
      // the printed form is plain printable ASCII without delimiters/whitespace
      let chars = printed.to_array()
      let clean = chars[0] == '/' &&
        chars[1:]
        .iter()
        .all(c => {
          c.to_int() > 32 && c.to_int() < 127 && !"()<>[]{}/%".contains_char(c)
        })
      clean && reparse(printed) is Name(n) && n == name
    },
    count=500,
    seed=0x9a3e,
  )
}

///|
/// Hex string text (with whitespace) and the bytes it denotes.
priv struct HexString(String, String) derive(Debug)

///|
impl @quickcheck.Arbitrary for HexString with fn arbitrary(size, rs) {
  let n = rand_int(rs, 2 * size + 2)
  let sb = StringBuilder()
  let nibbles = []
  sb.write_char('<')
  for _ in 0..<n {
    while rand_int(rs, 4) == 0 {
      sb.write_char(@quickcheck.elements([' ', '\n', '\r', '\t']).run(size, rs))
    }
    let v = rand_int(rs, 16)
    nibbles.push(v)
    let digits = if rand_int(rs, 2) == 0 {
      "0123456789abcdef"
    } else {
      "0123456789ABCDEF"
    }
    sb.write_char(digits[v].unsafe_to_char())
  }
  sb.write_char('>')
  let bytes = StringBuilder()
  for i = 0; i < nibbles.length(); i = i + 2 {
    let lo = if i + 1 < nibbles.length() { nibbles[i + 1] } else { 0 }
    bytes.write_char((nibbles[i] * 16 + lo).unsafe_to_char())
  }
  HexString(sb.to_string(), bytes.to_string())
}

///|
impl @quickcheck.Shrink for HexString

///|
test "prop: hex strings decode per nibble (whitespace ignored, odd digit padded)" {
  @quickcheck.check(
    (h : HexString) => {
      let HexString(text, expected) = h
      reparse(text) is PdfString(s) && s == expected
    },
    count=300,
    seed=0x4e45,
  )
}

///|
test "prop: literal strings accept every escape form" {
  // Encode each byte with a randomly chosen legal representation (raw when
  // allowed, \ddd with 1-3 octal digits, or a named escape) and check the
  // lexer recovers the bytes; line continuations are inserted between bytes.
  @quickcheck.check(
    (input : (Bytes, Array[UInt])) => {
      let (bytes, choices) = input
      let sb = StringBuilder()
      sb.write_char('(')
      for i, b in bytes {
        let v = b.to_int()
        let choice = if choices.length() == 0 {
          0U
        } else {
          choices[i % choices.length()]
        }
        if choice % 7 == 6 {
          sb.write_string("\\\r\n") // line continuation: contributes nothing
        }
        let named = match v {
          0x0a => Some("\\n")
          0x0d => Some("\\r")
          0x09 => Some("\\t")
          0x08 => Some("\\b")
          0x0c => Some("\\f")
          0x28 => Some("\\(")
          0x29 => Some("\\)")
          0x5c => Some("\\\\")
          _ => None
        }
        let next_is_digit = i + 1 < bytes.length() &&
          bytes[i + 1] >= b'0' &&
          bytes[i + 1] <= b'7'
        match (choice % 3, named) {
          (0, Some(esc)) => sb.write_string(esc)
          (0, None) => sb.write_char(v.unsafe_to_char())
          (1, _) => {
            // shortest octal form unless the next byte is an octal digit
            let oct = (v >> 6).to_string() +
              ((v >> 3) & 7).to_string() +
              (v & 7).to_string()
            let short = if next_is_digit {
              oct
            } else if v < 8 {
              (v & 7).to_string()
            } else if v < 64 {
              ((v >> 3) & 7).to_string() + (v & 7).to_string()
            } else {
              oct
            }
            sb.write_char('\\')
            sb.write_string(short)
          }
          (_, Some(esc)) => sb.write_string(esc)
          (_, None) => {
            let oct = (v >> 6).to_string() +
              ((v >> 3) & 7).to_string() +
              (v & 7).to_string()
            sb.write_char('\\')
            sb.write_string(oct)
          }
        }
      }
      sb.write_char(')')
      let expected = @pdfio.string_of_bytes(bytes.to_array())
      reparse(sb.to_string()) is PdfString(s) && s == expected
    },
    count=300,
    seed=0x0c7a1,
  )
}

// ---------------------------------------------------------------------------
// Robustness: parse_single_object is used on untrusted text (e.g. content of
// object streams and inline dictionaries); it may raise but must not abort.

///|
priv struct Garbage(String) derive(Debug)

///|
impl @quickcheck.Arbitrary for Garbage with fn arbitrary(size, rs) {
  let frags = [
    "<<", ">>", "[", "]", "(", ")", "\\", "/", "#", "#4", "#zz", "<", ">", "R", "obj",
    "endobj", "stream", "\n", "\r\n", "endstream", " ", " ", "0", "1", "-", "--",
    ".", "e", "9999999999", "-1", "/Length", "/Length -5", "%", "true", "null", "1 0 obj",
    "<</Length 3>>", "stream\n", "\u{ff}", "\u{0}", "+", "abc",
  ]
  let n = rand_int(rs, size * 2 + 1)
  let sb = StringBuilder()
  if rand_int(rs, 3) == 0 {
    // mutate a printed valid object
    let s = gen_obj(size, rs).to_string()
    let cut = rand_int(rs, s.length() + 1)
    sb.write_string(s[:cut].to_owned())
  }
  for _ in 0..<n {
    if rand_int(rs, 5) == 0 {
      sb.write_char(rand_int(rs, 256).unsafe_to_char())
    } else {
      sb.write_string(frags[rand_int(rs, frags.length())])
    }
  }
  Garbage(sb.to_string())
}

///|
impl @quickcheck.Shrink for Garbage with fn shrink(self) {
  let Garbage(s) = self
  let n = s.length()
  if n == 0 {
    return [].iter()
  }
  [
    Garbage(s[:n / 2].to_owned()),
    Garbage(s[n / 2:].to_owned()),
    Garbage(s[1:].to_owned()),
    Garbage(s[:n - 1].to_owned()),
  ].iter()
}

///|
test "prop: parse_single_object never aborts on arbitrary input" {
  @pdfe.with_silenced_logs(() => {
    @quickcheck.check(
      (g : Garbage) => {
        // raising is fine; aborting would kill the test process
        let _ = @pdfsyntax.parse_single_object(g.0) catch { _ => Null }
        true
      },
      observe=g => {
        let parsed = try {
          @pdfsyntax.parse_single_object(g.0) |> ignore
          true
        } catch {
          _ => false
        }
        [@quickcheck.classify(parsed, "parsed")]
      },
      count=2000,
      max_size=30,
      seed=0x6a4b,
    )
  })
}

///|
fn parse_or_error(s : String) -> String {
  @pdfe.with_silenced_logs(() => @pdfsyntax.parse_single_object(s).to_string()) catch {
    _ => "error"
  }
}

///|
test "regression: stream keyword at end of input does not loop forever" {
  // Reading past EOF leaves the input position beyond its length, and
  // find_endstream only stopped at `pos == length`: this used to hang.
  inspect(parse_or_error("[1 0 obj<</Length 3>>streamx"), content="error")
  inspect(parse_or_error("[1 0 obj<</Length 3>>stream"), content="error")
}

///|
test "regression: negative or oversized stream /Length" {
  // A negative /Length used to abort in mkbytes; an oversized one allocated a
  // buffer of that size and filled it with bytes read past EOF.
  inspect(
    parse_or_error("[1 0 obj<</Length -3>>stream\nabc\nendstream endobj]"),
    content="error",
  )
  inspect(
    parse_or_error(
      "[1 0 obj<</Length 2000000000>>stream\nabc\nendstream endobj]",
    ),
    content="error",
  )
  // The stream data itself is still recovered by scanning for `endstream`.
  let input = @pdfio.Input::of_string(
    "1 0 obj <</Length -3>> stream\nabc\nendstream endobj",
  )
  let (_, obj) = @pdfsyntax.parse(
    @pdfsyntax.lex_object_at(false, input, true, _ => []),
  )
  inspect(
    obj.to_string_including_data(),
    content="<</Length -3>>\nstream\nabc\nendstream",
  )
}
