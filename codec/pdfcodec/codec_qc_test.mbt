// Property-based tests for the stream filters: encode/decode round trips,
// decoder models, encoder output invariants and decoder robustness.

///|
let qc_codec : @pdfcodec.PdfCodec = @pdfcodec.PdfCodec::new()

///|
fn random_byte(rs : @quickcheck.RandomState) -> Byte {
  rs.next_uint(limit=256).reinterpret_as_int().to_byte()
}

///|
/// Stream payloads mixing uniformly random bytes, long runs (RunLength),
/// repetitive text (LZW dictionary growth) and a few large inputs that force
/// LZW code-width changes and table resets.
priv struct Data(Array[Byte]) derive(Debug)

///|
fn gen_data(size : Int, rs : @quickcheck.RandomState) -> Array[Byte] {
  let kind = rs.next_uint(limit=10).reinterpret_as_int()
  match kind {
    0 | 1 | 2 => {
      let n = rs
        .next_uint(limit=(size + 1).reinterpret_as_uint())
        .reinterpret_as_int()
      Array::makei(n, _ => random_byte(rs))
    }
    3 | 4 => {
      // runs of repeated bytes with random lengths (incl. > 128)
      let out = []
      let runs = rs.next_uint(limit=8).reinterpret_as_int()
      for _ in 0..<runs {
        let b = random_byte(rs)
        let len = rs.next_uint(limit=300).reinterpret_as_int() + 1
        for _ in 0..<len {
          out.push(b)
        }
        if rs.next_uint(limit=2) == 0 {
          out.push(random_byte(rs))
        }
      }
      out
    }
    5 | 6 => {
      // repetitive text from a tiny alphabet
      let n = rs
        .next_uint(limit=(size * 8 + 1).reinterpret_as_uint())
        .reinterpret_as_int()
      Array::makei(n, _ => {
        (b'a'.to_int() + rs.next_uint(limit=3).reinterpret_as_int()).to_byte()
      })
    }
    7 => {
      // zeros and 4-byte zero groups (ASCII85 'z')
      let n = rs.next_uint(limit=40).reinterpret_as_int()
      Array::makei(n, _ => {
        if rs.next_uint(limit=5) == 0 {
          random_byte(rs)
        } else {
          b'\x00'
        }
      })
    }
    8 => {
      // large random input: > 4096 LZW codes, several code-width switches
      let n = 3000 + rs.next_uint(limit=9000).reinterpret_as_int()
      Array::makei(n, _ => random_byte(rs))
    }
    _ => []
  }
}

///|
impl @quickcheck.Arbitrary for Data with fn arbitrary(size, rs) {
  Data(gen_data(size, rs))
}

///|
impl @quickcheck.Shrink for Data with fn shrink(self) {
  let Data(bytes) = self
  @quickcheck.Shrink::shrink(bytes).map(b => Data(b))
}

///|
priv struct Enc(@pdfcodec.Encoding) derive(Debug)

///|
let round_trip_encodings : Array[@pdfcodec.Encoding] = [
  ASCIIHex,
  ASCII85,
  RunLength,
  LZW(0),
  LZW(1),
  Flate,
]

///|
impl @quickcheck.Arbitrary for Enc with fn arbitrary(size, rs) {
  Enc(@quickcheck.elements(round_trip_encodings).run(size, rs))
}

///|
impl @quickcheck.Shrink for Enc

///|
fn stream_of(
  data : Array[Byte],
) -> (@pdf.PdfObject, Ref[(@pdf.PdfObject, @pdf.Stream)]) {
  let dict : @pdf.PdfObject = Dictionary([("/Length", Integer(data.length()))])
  let r = Ref((dict, @pdf.Stream::Got(data.copy())))
  (Stream(r), r)
}

///|
fn got(r : Ref[(@pdf.PdfObject, @pdf.Stream)]) -> Array[Byte] {
  match r.val.1 {
    Got(b) => b
    _ => []
  }
}

///|
fn early_param(enc : @pdfcodec.Encoding) -> @pdf.PdfObject? {
  match enc {
    LZW(e) => Some(Dictionary([("/EarlyChange", Integer(e))]))
    _ => None
  }
}

///|
/// Encode `data` with `encs` (applied in order) and return the stream.
fn encode_all(
  data : Array[Byte],
  encs : Array[@pdfcodec.Encoding],
) -> (@pdf.PdfObject, Ref[(@pdf.PdfObject, @pdf.Stream)]) raise {
  let pdf = @pdf.Pdf::empty()
  let (obj, r) = stream_of(data)
  for e in encs {
    qc_codec.encode_pdfstream(pdf, e, obj)
    // encode_pdfstream does not record /EarlyChange; add it so a decoder can
    // pick the right variant.
    match early_param(e) {
      Some(p) => {
        let (d, s) = r.val
        let d2 = match d.lookup_immediate("/DecodeParms") {
          None => d.add_entry("/DecodeParms", p)
          Some(PdfArray(ps)) =>
            d.replace_entry("/DecodeParms", PdfArray([p, ..ps]))
          Some(other) => d.replace_entry("/DecodeParms", PdfArray([p, other]))
        }
        r.val = (d2, s)
      }
      None =>
        match r.val.0.lookup_immediate("/DecodeParms") {
          Some(PdfArray(ps)) => {
            let (d, s) = r.val
            r.val = (d.replace_entry("/DecodeParms", PdfArray([Null, ..ps])), s)
          }
          Some(other) => {
            let (d, s) = r.val
            r.val = (
              d.replace_entry("/DecodeParms", PdfArray([Null, other])),
              s,
            )
          }
          None => ()
        }
    }
  }
  (obj, r)
}

///|
test "prop: decode_from_bytes inverts encode_pdfstream for every filter" {
  @quickcheck.check(
    (input : (Enc, Data)) => {
      let (Enc(enc), Data(data)) = input
      let (_, r) = encode_all(data, [enc])
      let (dict, _) = r.val
      let encoded = got(r)
      let length_ok = match dict.lookup_immediate("/Length") {
        Some(Integer(n)) => n == encoded.length()
        _ => false
      }
      length_ok && qc_codec.decode_from_bytes(encoded, dict) == Some(data)
    },
    observe=input => {
      let (Enc(enc), Data(data)) = input
      [
        @quickcheck.label(
          match enc {
            ASCIIHex => "hex"
            ASCII85 => "a85"
            RunLength => "rl"
            LZW(e) => "lzw\{e}"
            Flate => "flate"
            _ => "other"
          },
        ),
        @quickcheck.classify(data.length() == 0, "empty"),
        @quickcheck.classify(data.length() > 2000, "large (LZW reset)"),
      ]
    },
    count=400,
    seed=0xc0dec,
  )
}

///|
test "prop: decode_pdfstream undoes a chain of encodings" {
  @quickcheck.check(
    (input : (Array[Enc], Data)) => {
      let (encs, Data(data)) = input
      let encs = encs[:if encs.length() > 3 { 3 } else { encs.length() }].map(e => {
        e.0
      })
      let (obj, r) = encode_all(data, encs)
      let (dict, _) = r.val
      let via_bytes = qc_codec.decode_from_bytes(got(r), dict)
      qc_codec.decode_pdfstream(@pdf.Pdf::empty(), obj)
      let (dict2, _) = r.val
      let pure_ok = encs.length() == 0 || via_bytes == Some(data)
      pure_ok && got(r) == data && dict2.lookup_immediate("/Filter") is None
    },
    observe=input => {
      [
        @quickcheck.collect(
          if input.0.length() > 3 {
            3
          } else {
            input.0.length()
          },
        ),
      ]
    },
    count=150,
    seed=0xc4a1,
  )
}

///|
priv struct PredCase {
  lzw : Bool
  pred : @pdfcodec.Predictor
  columns : Int
  data : Array[Byte]
} derive(Debug)

///|
impl @quickcheck.Arbitrary for PredCase with fn arbitrary(size, rs) {
  let pred = @quickcheck.elements([
    @pdfcodec.Predictor::TIFF2,
    PNGNone,
    PNGSub,
    PNGUp,
    PNGAverage,
    PNGPaeth,
    PNGOptimum,
  ]).run(size, rs)
  let columns = @quickcheck.int_range(1, 17).run(size, rs)
  let rows = @quickcheck.int_range(0, 12).run(size, rs)
  let smooth = rs.next_uint(limit=2) == 0
  let mut acc = 0
  let data = Array::makei(rows * columns, _ => {
    if smooth {
      acc = acc + rs.next_uint(limit=5).reinterpret_as_int()
      acc.to_byte()
    } else {
      random_byte(rs)
    }
  })
  { lzw: rs.next_uint(limit=2) == 0, pred, columns, data, }
}

///|
impl @quickcheck.Shrink for PredCase

///|
test "prop: Flate/LZW + predictor round trips whole scanlines" {
  // PDF 32000-1 7.4.4.4: /Predictor applies to both FlateDecode and LZWDecode.
  @quickcheck.check(
    (c : PredCase) => {
      let pdf = @pdf.Pdf::empty()
      let (obj, r) = stream_of(c.data)
      qc_codec.encode_pdfstream(
        pdf,
        if c.lzw {
          LZW(1)
        } else {
          Flate
        },
        obj,
        predictor=c.pred,
        predictor_columns=c.columns,
      )
      let (dict, _) = r.val
      qc_codec.decode_from_bytes(got(r), dict) == Some(c.data)
    },
    observe=c => {
      [@quickcheck.collect(c.pred), @quickcheck.classify(c.lzw, "LZW")]
    },
    count=300,
    seed=0x9e7,
  )
}

///|
fn decode_named(name : String, data : Array[Byte]) -> Array[Byte]? {
  qc_codec.decode_from_bytes(
    data,
    Dictionary([("/Filter", Name(@pdf.PdfName::of_string(name)))]),
  )
}

///|
/// Hex text: hex digits in either case, arbitrary PDF whitespace between them,
/// optionally terminated by `>`.
priv struct HexText {
  nibbles : Array[Int]
  text : Array[Byte]
  terminated : Bool
} derive(Debug)

///|
impl @quickcheck.Arbitrary for HexText with fn arbitrary(size, rs) {
  let n = rs
    .next_uint(limit=(2 * size + 2).reinterpret_as_uint())
    .reinterpret_as_int()
  let nibbles = Array::makei(n, _ => rs.next_uint(limit=16).reinterpret_as_int())
  let ws = [b' ', b'\n', b'\r', b'\t', b'\x0c', b'\x00']
  let text = []
  for v in nibbles {
    while rs.next_uint(limit=4) == 0 {
      text.push(ws[rs.next_uint(limit=6).reinterpret_as_int()])
    }
    let digits = if rs.next_uint(limit=2) == 0 {
      "0123456789abcdef"
    } else {
      "0123456789ABCDEF"
    }
    text.push(digits[v].to_byte())
  }
  let terminated = rs.next_uint(limit=4) != 0
  if terminated {
    text.push(b'>')
  }
  { nibbles, text, terminated, }
}

///|
impl @quickcheck.Shrink for HexText

///|
test "prop: ASCIIHexDecode matches a nibble model (whitespace, case, odd tail)" {
  @quickcheck.check(
    (h : HexText) => {
      let n = h.nibbles.length()
      let expected = Array::makei((n + 1) / 2, i => {
        let hi = h.nibbles[2 * i]
        let lo = if 2 * i + 1 < n { h.nibbles[2 * i + 1] } else { 0 }
        (hi * 16 + lo).to_byte()
      })
      // Without the `>` terminator a trailing odd nibble is dropped.
      let expected = if !h.terminated && n % 2 == 1 {
        expected[:expected.length() - 1].to_owned()
      } else {
        expected
      }
      decode_named("/ASCIIHexDecode", h.text) == Some(expected)
    },
    observe=h => {
      [
        @quickcheck.classify(h.nibbles.length() % 2 == 1, "odd"),
        @quickcheck.classify(h.terminated, "terminated"),
      ]
    },
    count=300,
    seed=0x4e3,
  )
}

///|
fn encode_bytes(
  enc : @pdfcodec.Encoding,
  data : Array[Byte],
) -> Array[Byte] raise {
  let (_, r) = encode_all(data, [enc])
  got(r)
}

///|
test "prop: ASCII85Decode ignores whitespace inserted anywhere" {
  @quickcheck.check(
    (input : (Data, Array[(UInt, Byte)])) => {
      let (Data(data), inserts) = input
      let enc = encode_bytes(ASCII85, data)
      let ws = [b' ', b'\n', b'\r', b'\t', b'\x0c', b'\x00']
      let noisy = enc.copy()
      for ins in inserts {
        let pos = (ins.0 % (noisy.length() + 1).reinterpret_as_uint()).reinterpret_as_int()
        noisy.insert(pos, ws[ins.1.to_int() % 6])
      }
      decode_named("/ASCII85Decode", noisy) == Some(data)
    },
    count=200,
    seed=0x85,
  )
}

///|
test "prop: ASCII encoders emit only their alphabet with bounded expansion" {
  @quickcheck.check(
    (d : Data) => {
      let Data(data) = d
      let n = data.length()
      let hex = encode_bytes(ASCIIHex, data)
      let a85 = encode_bytes(ASCII85, data)
      let rl = encode_bytes(RunLength, data)
      let hex_ok = hex.length() == 2 * n + 1 &&
        hex[hex.length() - 1] == b'>' &&
        hex[:hex.length() - 1]
        .iter()
        .all(b => (b >= b'0' && b <= b'9') || (b >= b'A' && b <= b'F'))
      let a85_body = a85[:a85.length() - 2]
      let a85_ok = a85[a85.length() - 2] == b'~' &&
        a85[a85.length() - 1] == b'>' &&
        a85_body.iter().all(b => (b >= b'!' && b <= b'u') || b == b'z') &&
        a85.length() <= (n + 3) / 4 * 5 + 2
      let rl_ok = rl.length() <= n + (n + 127) / 128 + 1 &&
        rl[rl.length() - 1] == b'\x80'
      hex_ok && a85_ok && rl_ok
    },
    count=200,
    seed=0xa5c,
  )
}

// ---------------------------------------------------------------------------
// Inflate vs. a reference DEFLATE encoder (RFC 1951 fixed-Huffman and stored
// blocks). `PdfCodec::encode_flate` only emits stored blocks, so this is what
// exercises the Huffman / back-reference paths of the decoder.

///|
priv struct BitWriter {
  bytes : Array[Byte]
  mut cur : Int
  mut nbits : Int
}

///|
fn BitWriter::new() -> BitWriter {
  { bytes: [], cur: 0, nbits: 0, }
}

///|
/// Write `n` bits of `value`, least significant bit first.
fn BitWriter::bits(self : BitWriter, value : Int, n : Int) -> Unit {
  for i in 0..<n {
    self.cur = self.cur | (((value >> i) & 1) << self.nbits)
    self.nbits = self.nbits + 1
    if self.nbits == 8 {
      self.bytes.push(self.cur.to_byte())
      self.cur = 0
      self.nbits = 0
    }
  }
}

///|
/// Write a Huffman code (most significant bit first).
fn BitWriter::code(self : BitWriter, code : Int, n : Int) -> Unit {
  for i = n - 1; i >= 0; i = i - 1 {
    self.bits((code >> i) & 1, 1)
  }
}

///|
fn BitWriter::align(self : BitWriter) -> Unit {
  if self.nbits > 0 {
    self.bytes.push(self.cur.to_byte())
    self.cur = 0
    self.nbits = 0
  }
}

///|
priv enum DeflateOp {
  Lit(Byte)
  Copy(Int, Int) // (length 3..=258, distance 1..=32768)
} derive(Debug)

///|
priv enum DeflateBlock {
  Stored(Array[Byte])
  Fixed(Array[DeflateOp])
} derive(Debug)

///|
priv struct DeflateCase(Array[DeflateBlock]) derive(Debug)

///|
fn gen_ops(
  size : Int,
  produced : Int,
  rs : @quickcheck.RandomState,
) -> (Array[DeflateOp], Int) {
  let n = rs
    .next_uint(limit=(size * 4 + 1).reinterpret_as_uint())
    .reinterpret_as_int()
  let ops = []
  let mut out = produced
  for _ in 0..<n {
    if out > 0 && rs.next_uint(limit=5) < 2 {
      let len = if rs.next_uint(limit=4) == 0 {
        3 + rs.next_uint(limit=256).reinterpret_as_int()
      } else {
        3 + rs.next_uint(limit=16).reinterpret_as_int()
      }
      let max_dist = if out > 32768 { 32768 } else { out }
      let dist = 1 +
        rs.next_uint(limit=max_dist.reinterpret_as_uint()).reinterpret_as_int()
      ops.push(Copy(len, dist))
      out = out + len
    } else {
      ops.push(Lit(random_byte(rs)))
      out = out + 1
    }
  }
  (ops, out)
}

///|
impl @quickcheck.Arbitrary for DeflateCase with fn arbitrary(size, rs) {
  let nblocks = 1 + rs.next_uint(limit=3).reinterpret_as_int()
  let blocks = []
  let mut produced = 0
  for _ in 0..<nblocks {
    if rs.next_uint(limit=4) == 0 {
      let n = rs
        .next_uint(limit=(size + 1).reinterpret_as_uint())
        .reinterpret_as_int()
      blocks.push(Stored(Array::makei(n, _ => random_byte(rs))))
      produced = produced + n
    } else {
      let (ops, out) = gen_ops(size, produced, rs)
      blocks.push(Fixed(ops))
      produced = out
    }
  }
  DeflateCase(blocks)
}

///|
impl @quickcheck.Shrink for DeflateCase

///|
/// Naive interpretation of the block list (the expected inflate output).
fn deflate_model(blocks : Array[DeflateBlock]) -> Array[Byte] {
  let out : Array[Byte] = []
  for b in blocks {
    match b {
      Stored(bytes) => out.append(bytes)
      Fixed(ops) =>
        for op in ops {
          match op {
            Lit(x) => out.push(x)
            Copy(len, dist) =>
              for _ in 0..<len {
                out.push(out[out.length() - dist])
              }
          }
        }
    }
  }
  out
}

///|
let rfc_len_base : Array[Int] = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83,
  99, 115, 131, 163, 195, 227, 258,
]

///|
let rfc_len_extra : Array[Int] = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5,
  5, 0,
]

///|
let rfc_dist_base : Array[Int] = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
  1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
]

///|
let rfc_dist_extra : Array[Int] = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
  12, 12, 13, 13,
]

///|
fn fixed_lit(w : BitWriter, sym : Int) -> Unit {
  if sym < 144 {
    w.code(0x30 + sym, 8)
  } else if sym < 256 {
    w.code(0x190 + sym - 144, 9)
  } else if sym < 280 {
    w.code(sym - 256, 7)
  } else {
    w.code(0xc0 + sym - 280, 8)
  }
}

///|
fn find_index(bases : Array[Int], v : Int) -> Int {
  let mut i = bases.length() - 1
  while bases[i] > v {
    i = i - 1
  }
  i
}

///|
fn adler32(data : Array[Byte]) -> Int {
  let mut a = 1
  let mut b = 0
  for x in data {
    a = (a + x.to_int()) % 65521
    b = (b + a) % 65521
  }
  (b << 16) | a
}

///|
fn deflate_encode(blocks : Array[DeflateBlock]) -> Array[Byte] {
  let w = BitWriter::new()
  w.bits(0x78, 8)
  w.bits(0x9c, 8)
  for i, b in blocks {
    let final_bit = if i == blocks.length() - 1 { 1 } else { 0 }
    w.bits(final_bit, 1)
    match b {
      Stored(bytes) => {
        w.bits(0, 2)
        w.align()
        w.bits(bytes.length(), 16)
        w.bits(bytes.length() ^ 0xffff, 16)
        for x in bytes {
          w.bits(x.to_int(), 8)
        }
      }
      Fixed(ops) => {
        w.bits(1, 2)
        for op in ops {
          match op {
            Lit(x) => fixed_lit(w, x.to_int())
            Copy(len, dist) => {
              // 258 has its own code (285); never encode it as 284 + extra.
              let li = if len == 258 {
                28
              } else {
                find_index(rfc_len_base, len)
              }
              fixed_lit(w, 257 + li)
              w.bits(len - rfc_len_base[li], rfc_len_extra[li])
              let di = find_index(rfc_dist_base, dist)
              w.code(di, 5)
              w.bits(dist - rfc_dist_base[di], rfc_dist_extra[di])
            }
          }
        }
        fixed_lit(w, 256)
      }
    }
  }
  w.align()
  let checksum = adler32(deflate_model(blocks))
  for shift in [24, 16, 8, 0] {
    w.bits((checksum >> shift) & 0xff, 8)
  }
  w.bytes
}

///|
test "prop: FlateDecode agrees with a reference DEFLATE encoder (fixed + stored blocks)" {
  @quickcheck.check(
    (c : DeflateCase) => {
      let DeflateCase(blocks) = c
      let expected = deflate_model(blocks)
      qc_codec.decode_flate(deflate_encode(blocks)) == expected
    },
    observe=c => {
      let DeflateCase(blocks) = c
      let copies = blocks
        .iter()
        .any(b => b is Fixed(ops) && ops.iter().any(op => op is Copy(_, _)))
      let overlapping = blocks
        .iter()
        .any(b => {
          b is Fixed(ops) &&
          ops.iter().any(op => op is Copy(len, dist) && dist < len)
        })
      [
        @quickcheck.collect(blocks.length()),
        @quickcheck.classify(copies, "back-references"),
        @quickcheck.classify(overlapping, "overlapping copy"),
        @quickcheck.classify(blocks.iter().any(b => b is Stored(_)), "stored"),
      ]
    },
    count=300,
    seed=0xf1a7e,
  )
}

///|
test "FlateDecode handles a long fixed-Huffman literal run without deep recursion" {
  let data = Array::makei(200000, i => ((i * 7) & 0xff).to_byte())
  let blocks = [Fixed(data.map(b => Lit(b)))]
  inspect(qc_codec.decode_flate(deflate_encode(blocks)) == data, content="true")
}

// ---------------------------------------------------------------------------
// Robustness: decoders are fed untrusted stream data and /DecodeParms from the
// PDF file. They may reject it (None) but must never abort.

///|
priv struct DecodeCase {
  filter : String
  parms : @pdf.PdfObject?
  data : Array[Byte]
} derive(Debug)

///|
let filter_names : Array[String] = [
  "/FlateDecode", "/ASCIIHexDecode", "/ASCII85Decode", "/RunLengthDecode", "/LZWDecode",
  "/CCITTFaxDecode", "/Crypt", "/JBIG2Decode", "/DCTDecode",
]

///|
fn gen_parms(filter : String, rs : @quickcheck.RandomState) -> @pdf.PdfObject? {
  // mostly sane widths, but regularly zero / negative
  let small = () => {
    @pdf.PdfObject::Integer(
      @quickcheck.frequency([
        (2, @quickcheck.int_range(1, 65)),
        (1, @quickcheck.elements([-3, -1, 0])),
      ]).run(8, rs),
    )
  }
  match rs.next_uint(limit=3) {
    0 => None
    _ =>
      match filter {
        "/FlateDecode" | "/LZWDecode" =>
          Some(
            Dictionary([
              (
                "/Predictor",
                Integer(
                  @quickcheck.elements([1, 2, 10, 11, 12, 13, 14, 15, 7]).run(
                    8, rs,
                  ),
                ),
              ),
              ("/Colors", small()),
              (
                "/BitsPerComponent",
                Integer(@quickcheck.elements([8, 8, 1, 16]).run(8, rs)),
              ),
              ("/Columns", small()),
              (
                "/EarlyChange",
                Integer(rs.next_uint(limit=2).reinterpret_as_int()),
              ),
            ]),
          )
        "/CCITTFaxDecode" =>
          Some(
            Dictionary([
              ("/K", Integer(rs.next_uint(limit=5).reinterpret_as_int() - 2)),
              ("/Columns", small()),
              ("/Rows", small()),
              ("/EncodedByteAlign", Boolean(rs.next_uint(limit=2) == 0)),
              ("/EndOfLine", Boolean(rs.next_uint(limit=2) == 0)),
              ("/BlackIs1", Boolean(rs.next_uint(limit=2) == 0)),
            ]),
          )
        _ => Some(Dictionary([]))
      }
  }
}

///|
impl @quickcheck.Arbitrary for DecodeCase with fn arbitrary(size, rs) {
  let filter = @quickcheck.elements(filter_names).run(size, rs)
  let parms = gen_parms(filter, rs)
  let data = match rs.next_uint(limit=4) % 3 {
    // plausible prefix so decoders get past their first sanity check
    0 => {
      let d = gen_data(size, rs)
      let enc = match filter {
        "/ASCIIHexDecode" => Some(@pdfcodec.Encoding::ASCIIHex)
        "/ASCII85Decode" => Some(ASCII85)
        "/RunLengthDecode" => Some(RunLength)
        "/LZWDecode" => Some(LZW(1))
        "/FlateDecode" => Some(Flate)
        _ => None
      }
      match enc {
        Some(e) => {
          let full = encode_bytes(e, d) catch { _ => d }
          // keep intact (so /DecodeParms predictors run), or truncate and
          // flip one bit
          let cut = if rs.next_uint(limit=2) == 0 {
            full.length()
          } else {
            rs
            .next_uint(limit=(full.length() + 1).reinterpret_as_uint())
            .reinterpret_as_int()
          }
          let t = full[:cut].to_owned()
          if t.length() > 0 && rs.next_uint(limit=3) == 0 {
            let i = rs
              .next_uint(limit=t.length().reinterpret_as_uint())
              .reinterpret_as_int()
            t[i] = t[i] ^
              (1 << rs.next_uint(limit=8).reinterpret_as_int()).to_byte()
          }
          t
        }
        None => d
      }
    }
    1 => {
      // zlib header followed by garbage: reaches the Huffman decoder
      let rest = Array::makei(rs.next_uint(limit=64).reinterpret_as_int(), _ => {
        random_byte(rs)
      })
      [b'\x78', b'\x9c', ..rest]
    }
    _ =>
      Array::makei(
        rs
        .next_uint(limit=(size + 1).reinterpret_as_uint())
        .reinterpret_as_int(),
        _ => random_byte(rs),
      )
  }
  { filter, parms, data, }
}

///|
impl @quickcheck.Shrink for DecodeCase with fn shrink(self) {
  @quickcheck.Shrink::shrink(self.data).map(data => { ..self, data, })
}

///|
test "prop: decode_from_bytes never aborts on malformed data or parameters" {
  @quickcheck.check(
    (c : DecodeCase) => {
      let dict_entries = [
        ("/Filter", @pdf.PdfObject::Name(@pdf.PdfName::of_string(c.filter))),
      ]
      match c.parms {
        Some(p) => dict_entries.push(("/DecodeParms", p))
        None => ()
      }
      let _ = qc_codec.decode_from_bytes(c.data, Dictionary(dict_entries))
      true
    },
    observe=c => {
      let dict_entries = [
        ("/Filter", @pdf.PdfObject::Name(@pdf.PdfName::of_string(c.filter))),
      ]
      match c.parms {
        Some(p) => dict_entries.push(("/DecodeParms", p))
        None => ()
      }
      [
        @quickcheck.label(c.filter),
        @quickcheck.classify(
          qc_codec.decode_from_bytes(c.data, Dictionary(dict_entries))
          is Some(_),
          "decoded",
        ),
      ]
    },
    count=1500,
    max_size=200,
    seed=0xfa11,
  )
}

///|
fn ccitt_dict(columns : Int) -> @pdf.PdfObject {
  Dictionary([
    ("/Filter", Name(@pdf.PdfName::of_string("/CCITTFaxDecode"))),
    (
      "/DecodeParms",
      Dictionary([("/K", Integer(-1)), ("/Columns", Integer(columns))]),
    ),
  ])
}

///|
test "regression: CCITTFaxDecode rejects non-positive /Columns" {
  // /Columns 0 used to loop forever (the row never advances the input) and a
  // negative width aborted in Array::make.
  let data = [b'\x00', b'\x10', b'\xff']
  inspect(
    qc_codec.decode_from_bytes(data, ccitt_dict(0)) is None,
    content="true",
  )
  inspect(
    qc_codec.decode_from_bytes(data, ccitt_dict(-1)) is None,
    content="true",
  )
}

///|
test "regression: predictor rejects negative /Colors and /Columns" {
  // Used to abort (negative Array::make / out-of-bounds index). Zero keeps
  // its existing meaning (empty scanlines).
  let enc = qc_codec.encode_flate(Array::makei(12, i => i.to_byte()))
  let dict = (pred : Int, colors : Int, columns : Int) => {
    @pdf.PdfObject::Dictionary([
      ("/Filter", Name(@pdf.PdfName::of_string("/FlateDecode"))),
      (
        "/DecodeParms",
        Dictionary([
          ("/Predictor", Integer(pred)),
          ("/Colors", Integer(colors)),
          ("/Columns", Integer(columns)),
        ]),
      ),
    ])
  }
  inspect(
    qc_codec.decode_from_bytes(enc, dict(2, -3, -2)) is None,
    content="true",
  )
  inspect(
    qc_codec.decode_from_bytes(enc, dict(12, 1, -2)) is None,
    content="true",
  )
  inspect(
    qc_codec.decode_from_bytes(enc, dict(12, -1, 4)) is None,
    content="true",
  )
  debug_inspect(
    qc_codec.decode_from_bytes(enc, dict(2, 1, 0)).map(b => b.length()),
    content="Some(12)",
  )
}

///|
test "regression: LZWDecode honours /Predictor" {
  // LZW-encoded, PNG-Up predicted data used to come back with the predictor
  // tag bytes still in it.
  let data : Array[Byte] = [b'\x01', b'\x02', b'\x03', b'\x04']
  let pdf = @pdf.Pdf::empty()
  let (obj, r) = stream_of(data)
  qc_codec.encode_pdfstream(
    pdf,
    LZW(1),
    obj,
    predictor=PNGUp,
    predictor_columns=2,
  )
  debug_inspect(
    qc_codec.decode_from_bytes(got(r), r.val.0),
    content=(
      #|Some([0x01, 0x02, 0x03, 0x04])
    ),
  )
}
