///|
fn assert_bytes_equal(a : Array[Byte], b : Array[Byte]) -> Unit raise {
  let alen = @pdfio.bytes_size(a)
  let blen = @pdfio.bytes_size(b)
  assert_eq(alen, blen)
  for i in 0..<alen {
    assert_eq(@pdfio.bget_unsafe(a, i), @pdfio.bget_unsafe(b, i))
  }
}

///|
fn mk_stream(
  data : Array[Byte],
  dict_entries : Array[(String, @pdf.PdfObject)],
) -> (@pdf.Pdf, Ref[(@pdf.PdfObject, @pdf.Stream)], @pdf.PdfObject) {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = @pdf.d(
    dict_entries.add([("/Length", Integer(@pdfio.bytes_size(data)))]),
  )
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  (pdf, stream_ref, stream_obj)
}

///|
test "decode_from_bytes handles LZW clear codes mid-stream" {
  let bw = @pdfio.BitstreamWrite::new()
  bw.putval(9, 256)
  bw.putval(9, 65)
  bw.putval(9, 256)
  bw.putval(9, 66)
  bw.putval(9, 257)
  let encoded = bw.bytes()
  let dict : @pdf.PdfObject = @pdf.d([
    ("/Filter", Name(PdfName("/LZWDecode"))),
    ("/DecodeParms", @pdf.d([("/EarlyChange", Integer(1))])),
  ])
  match
    (@pdfcodec.PdfCodec::new().decode_from_bytes(encoded, dict) : Array[Byte]?) {
    Some(decoded) => assert_eq(@pdfio.string_of_bytes(decoded), "AB")
    None => fail("expected LZW decode to succeed")
  }
}

///|
test "decode_from_bytes finishes when clear code is followed by EOD" {
  let bw = @pdfio.BitstreamWrite::new()
  bw.putval(9, 256)
  bw.putval(9, 65)
  bw.putval(9, 256)
  bw.putval(9, 257)
  let encoded = bw.bytes()
  let dict : @pdf.PdfObject = @pdf.d([
    ("/Filter", Name(PdfName("/LZWDecode"))),
    ("/DecodeParms", @pdf.d([("/EarlyChange", Integer(1))])),
  ])
  match
    (@pdfcodec.PdfCodec::new().decode_from_bytes(encoded, dict) : Array[Byte]?) {
    Some(decoded) => assert_eq(@pdfio.string_of_bytes(decoded), "A")
    None => fail("expected LZW decode to succeed")
  }
}

///|
test "decode_from_bytes LZW handles code == next_code (KwKwK)" {
  let bw = @pdfio.BitstreamWrite::new()
  bw.putval(9, 256)
  bw.putval(9, 65)
  // First dictionary code after clear is 258; using it immediately triggers the
  // KwKwK special case (code == next_code).
  bw.putval(9, 258)
  bw.putval(9, 257)
  let encoded = bw.bytes()
  let dict : @pdf.PdfObject = @pdf.d([
    ("/Filter", Name(PdfName("/LZWDecode"))),
    ("/DecodeParms", @pdf.d([("/EarlyChange", Integer(1))])),
  ])
  match
    (@pdfcodec.PdfCodec::new().decode_from_bytes(encoded, dict) : Array[Byte]?) {
    Some(decoded) => assert_eq(@pdfio.string_of_bytes(decoded), "AAA")
    None => fail("expected LZW decode to succeed")
  }
}

///|
test "decode_from_bytes LZW bumps code length past 9 bits (literal-only stream)" {
  let bw = @pdfio.BitstreamWrite::new()
  let mut code_length = 9
  let mut next_code = 258
  let early = 1
  bw.putval(code_length, 256)
  // First literal after clear (no dictionary growth yet).
  bw.putval(code_length, 65)
  // Then feed enough literal codes to force next_code to grow beyond 512.
  for _ in 0..<253 {
    bw.putval(code_length, 65)
    next_code = next_code + 1
    let next_check = next_code + early
    if next_check == 512 || next_check == 1024 || next_check == 2048 {
      code_length = code_length + 1
    }
  }
  bw.putval(code_length, 257)
  let encoded = bw.bytes()
  let dict : @pdf.PdfObject = @pdf.d([
    ("/Filter", Name(PdfName("/LZWDecode"))),
    ("/DecodeParms", @pdf.d([("/EarlyChange", Integer(1))])),
  ])
  match
    (@pdfcodec.PdfCodec::new().decode_from_bytes(encoded, dict) : Array[Byte]?) {
    Some(decoded) => assert_eq(@pdfio.string_of_bytes(decoded), "A".repeat(254))
    None => fail("expected LZW decode to succeed")
  }
}

///|
test "decode_from_bytes LZW returns None on truncated input" {
  let dict : @pdf.PdfObject = @pdf.d([
    ("/Filter", Name(PdfName("/LZWDecode"))),
    ("/DecodeParms", @pdf.d([("/EarlyChange", Integer(1))])),
  ])
  // One byte is too short to contain a full clear + data + EOD sequence.
  let out = @pdfcodec.PdfCodec::new().decode_from_bytes(
    @pdfio.bytes_of_list([0]),
    dict,
  )
  assert_true(out is None)
}

///|
test "encode/decode LZW roundtrips medium input" {
  let ctx = @pdfcodec.PdfCodec::new()
  // Keep this payload modest for speed.
  let original = @pdfio.mkbytes(250)
  for i in 0..<250 {
    @pdfio.bset_unsafe(original, i, i % 251)
  }
  let (pdf, stream_ref, stream_obj) = mk_stream(original, [])
  ctx.encode_pdfstream(pdf, LZW(1), stream_obj, only_if_smaller=false)
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let decoded = match (stream_ref.val.1 : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_bytes_equal(decoded, original)
}

///|
test "encode_pdfstream LZW clears dictionary when full" {
  let ctx = @pdfcodec.PdfCodec::new()
  let original = @pdfio.mkbytes(5000)
  let mut s : UInt = 0x1234_5678
  for i in 0..<@pdfio.bytes_size(original) {
    s = s ^ (s << 13)
    s = s ^ (s >> 17)
    s = s ^ (s << 5)
    @pdfio.bset_unsafe(original, i, (s & 0xff).reinterpret_as_int())
  }
  let (pdf, stream_ref, stream_obj) = mk_stream(original, [])
  ctx.encode_pdfstream(pdf, LZW(1), stream_obj, only_if_smaller=false)
  match (pdf.lookup_direct("/Filter", stream_ref.val.0) : @pdf.PdfObject?) {
    Some(Name(PdfName("/LZWDecode"))) => ()
    Some(Array([Name(PdfName("/LZWDecode")), ..])) => ()
    _ => fail("expected /LZWDecode filter after encoding")
  }

  // Sanity-check the produced LZW code stream before running the full decoder:
  // ensure no code exceeds `next_code` under the same growth rules.
  let encoded = match (stream_ref.val.1 : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected encoded stream bytes")
  }
  let bs = @pdfio.Bitstream::of_input(
    @pdfio.Input::of_bytes(encoded, source="lzw"),
  )
  fn read_code(bits : Int) -> Int raise {
    let mut value = 0
    for _ in 0..<bits {
      value = (value << 1) | bs.getbitint()
    }
    value
  }

  let mut code_length = 9
  let mut next_code = 258
  let early = 1
  let mut have_prev = false
  let mut codes_seen = 0
  // Read up to a bounded number of codes for fast failure messages.
  while codes_seen < 2000 {
    let code = read_code(code_length)
    codes_seen = codes_seen + 1
    if code == 257 {
      break
    } else if code == 256 {
      have_prev = false
      next_code = 258
      code_length = 9
    } else if !have_prev {
      have_prev = true
    } else {
      if code > next_code {
        fail(
          "invalid LZW code stream: code=\{code} next=\{next_code} bits=\{code_length} at=\{codes_seen}",
        )
      }
      next_code = next_code + 1
      let next_check = next_code + early
      if next_check == 512 || next_check == 1024 || next_check == 2048 {
        code_length = code_length + 1
      }
    }
  }
  ctx.decode_pdfstream_onestage(pdf, stream_obj) catch {
    CouldntDecodeStream(msg) => fail("expected decode to succeed, got: \{msg}")
    err => raise err
  }
  let decoded = match (stream_ref.val.1 : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_bytes_equal(decoded, original)
}

///|
test "encode_pdfstream LZW grows code length past 9 bits" {
  let ctx = @pdfcodec.PdfCodec::new()
  let data = @pdfio.mkbytes(254)
  for i in 0..<254 {
    @pdfio.bset_unsafe(data, i, i)
  }
  let (pdf, stream_ref, stream_obj) = mk_stream(data, [])
  ctx.encode_pdfstream(pdf, LZW(1), stream_obj, only_if_smaller=false)
  match (pdf.lookup_direct("/Filter", stream_ref.val.0) : @pdf.PdfObject?) {
    Some(Name(PdfName("/LZWDecode"))) => ()
    Some(Array([Name(PdfName("/LZWDecode")), ..])) => ()
    _ => fail("expected /LZWDecode filter after encoding")
  }
}

///|
test "decode_from_bytes RunLength returns empty output on EOF" {
  let dict : @pdf.PdfObject = @pdf.d([
    ("/Filter", Name(PdfName("/RunLengthDecode"))),
  ])
  let out = @pdfcodec.PdfCodec::new().decode_from_bytes(@pdfio.mkbytes(0), dict)
  match out {
    Some(bytes) => assert_eq(@pdfio.bytes_size(bytes), 0)
    None => fail("expected RunLength decode to succeed")
  }
}

///|
test "encode/decode RunLength flushes literal chunks over 128 bytes" {
  let ctx = @pdfcodec.PdfCodec::new()
  let original = @pdfio.mkbytes(130)
  for i in 0..<130 {
    @pdfio.bset_unsafe(original, i, i)
  }
  let (pdf, stream_ref, stream_obj) = mk_stream(original, [])
  ctx.encode_pdfstream(pdf, RunLength, stream_obj, only_if_smaller=false)
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let decoded = match (stream_ref.val.1 : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_bytes_equal(decoded, original)
}

///|
test "encode/decode RunLength flush_literal returns early when empty" {
  let ctx = @pdfcodec.PdfCodec::new()
  // Starts with a run, so encode_runlength will flush an empty literal buffer.
  let original = @pdfio.bytes_of_string("aaab")
  let (pdf, stream_ref, stream_obj) = mk_stream(original, [])
  ctx.encode_pdfstream(pdf, RunLength, stream_obj, only_if_smaller=false)
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let decoded = match (stream_ref.val.1 : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_eq(@pdfio.string_of_bytes(decoded), "aaab")
}

///|
test "decode_from_bytes RunLength returns on truncated literal chunks" {
  let dict : @pdf.PdfObject = @pdf.d([
    ("/Filter", Name(PdfName("/RunLengthDecode"))),
  ])
  let out = @pdfcodec.PdfCodec::new().decode_from_bytes(
    @pdfio.bytes_of_list([0]),
    dict,
  )
  match out {
    Some(bytes) => assert_eq(@pdfio.bytes_size(bytes), 0)
    None => fail("expected RunLength decode to succeed")
  }
}

///|
test "decode_from_bytes RunLength returns on truncated repeat chunks" {
  let dict : @pdf.PdfObject = @pdf.d([
    ("/Filter", Name(PdfName("/RunLengthDecode"))),
  ])
  let out = @pdfcodec.PdfCodec::new().decode_from_bytes(
    @pdfio.bytes_of_list([129]),
    dict,
  )
  match out {
    Some(bytes) => assert_eq(@pdfio.bytes_size(bytes), 0)
    None => fail("expected RunLength decode to succeed")
  }
}

///|
test "decode_from_bytes returns None on empty filter arrays" {
  let dict : @pdf.PdfObject = @pdf.d([("/Filter", Array([]))])
  let out = @pdfcodec.PdfCodec::new().decode_from_bytes(
    @pdfio.bytes_of_string("x"),
    dict,
  )
  assert_true(out is None)
}

///|
test "decode_from_bytes handles non-array DecodeParms for multi-stage filters" {
  let dict : @pdf.PdfObject = @pdf.d([
    ("/Filter", Array([Name(PdfName("/Crypt")), Name(PdfName("/Crypt"))])),
    ("/DecodeParms", @pdf.d([("/Columns", Integer(1))])),
  ])
  match
    (
      @pdfcodec.PdfCodec::new().decode_from_bytes(
        @pdfio.bytes_of_string("abc"),
        dict,
      ) : Array[Byte]?) {
    Some(bytes) => assert_eq(@pdfio.string_of_bytes(bytes), "abc")
    None => fail("expected Crypt decode to succeed")
  }
}

///|
test "decode_from_bytes trims DecodeParms arrays shorter than Filter arrays" {
  let dict : @pdf.PdfObject = @pdf.d([
    ("/Filter", Array([Name(PdfName("/Crypt")), Name(PdfName("/Crypt"))])),
    ("/DecodeParms", Array([@pdf.d([])])),
  ])
  match
    (
      @pdfcodec.PdfCodec::new().decode_from_bytes(
        @pdfio.bytes_of_string("xyz"),
        dict,
      ) : Array[Byte]?) {
    Some(bytes) => assert_eq(@pdfio.string_of_bytes(bytes), "xyz")
    None => fail("expected Crypt decode to succeed")
  }
}

///|
test "encode/decode Flate with PNG Paeth predictor roundtrips" {
  let ctx = @pdfcodec.PdfCodec::new()
  let original = @pdfio.bytes_of_list([128, 255, 0, 0])
  let (pdf, stream_ref, stream_obj) = mk_stream(original, [])
  ctx.encode_pdfstream(
    pdf,
    Flate,
    stream_obj,
    only_if_smaller=false,
    predictor=PNGPaeth,
    predictor_columns=2,
  )
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let decoded = match (stream_ref.val.1 : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_bytes_eq(decoded, original)
}

///|
test "encode/decode Flate with zero-column PNG predictor yields empty stream" {
  let ctx = @pdfcodec.PdfCodec::new()
  let original = @pdfio.mkbytes(0)
  let (pdf, stream_ref, stream_obj) = mk_stream(original, [])
  ctx.encode_pdfstream(
    pdf,
    Flate,
    stream_obj,
    only_if_smaller=false,
    predictor=PNGSub,
    predictor_columns=0,
  )
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let decoded = match (stream_ref.val.1 : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_eq(@pdfio.bytes_size(decoded), 0)
}

///|
test "encode/decode Flate with zero-column TIFF predictor yields empty stream" {
  let ctx = @pdfcodec.PdfCodec::new()
  let original = @pdfio.mkbytes(0)
  let (pdf, stream_ref, stream_obj) = mk_stream(original, [])
  ctx.encode_pdfstream(
    pdf,
    Flate,
    stream_obj,
    only_if_smaller=false,
    predictor=TIFF2,
    predictor_columns=0,
  )
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let decoded = match (stream_ref.val.1 : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_eq(@pdfio.bytes_size(decoded), 0)
}

///|
test "decode Flate errors on PNG predictor with unsupported bpc" {
  let ctx = @pdfcodec.PdfCodec::new()
  let raw = @pdfio.bytes_of_list([0, 7])
  let encoded = ctx.encode_flate(raw)
  let parms : @pdf.PdfObject = @pdf.d([
    ("/Predictor", Integer(12)),
    ("/Colors", Integer(1)),
    ("/BitsPerComponent", Integer(4)),
    ("/Columns", Integer(2)),
  ])
  let (pdf, _stream_ref, stream_obj) = mk_stream(encoded, [
    ("/Filter", Name(PdfName("/FlateDecode"))),
    ("/DecodeParms", parms),
  ])
  let res : Result[Unit, Error] = try? ctx.decode_pdfstream_onestage(
    pdf, stream_obj,
  )
  assert_true(res is Err(_))
}

///|
test "decode Flate errors on TIFF predictor with unsupported bpc" {
  let ctx = @pdfcodec.PdfCodec::new()
  let raw = @pdfio.bytes_of_list([1, 2, 3])
  let encoded = ctx.encode_flate(raw)
  let parms : @pdf.PdfObject = @pdf.d([
    ("/Predictor", Integer(2)),
    ("/Colors", Integer(1)),
    ("/BitsPerComponent", Integer(4)),
    ("/Columns", Integer(1)),
  ])
  let (pdf, _stream_ref, stream_obj) = mk_stream(encoded, [
    ("/Filter", Name(PdfName("/FlateDecode"))),
    ("/DecodeParms", parms),
  ])
  let res : Result[Unit, Error] = try? ctx.decode_pdfstream_onestage(
    pdf, stream_obj,
  )
  assert_true(res is Err(_))
}

///|
test "decode Flate breaks when PNG predictor scanline is truncated" {
  let ctx = @pdfcodec.PdfCodec::new()
  // Decompressed bytes: predictor byte (0) + only 1 data byte; columns=2 => scanline_width=2.
  let raw = @pdfio.bytes_of_list([0, 7])
  let encoded = ctx.encode_flate(raw)
  let parms : @pdf.PdfObject = @pdf.d([
    ("/Predictor", Integer(12)),
    ("/Colors", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    // Use Real here to cover get_int_param's Real-to-int conversion.
    ("/Columns", Real(2.0)),
  ])
  let (pdf, stream_ref, stream_obj) = mk_stream(encoded, [
    ("/Filter", Name(PdfName("/FlateDecode"))),
    ("/DecodeParms", parms),
  ])
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let decoded = match (stream_ref.val.1 : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_eq(@pdfio.bytes_size(decoded), 2)
  assert_eq(@pdfio.bget_unsafe(decoded, 0), 7)
  assert_eq(@pdfio.bget_unsafe(decoded, 1), 0)
}

///|
test "decode Flate TIFF predictor handles zero columns as empty scanlines" {
  let ctx = @pdfcodec.PdfCodec::new()
  let raw = @pdfio.bytes_of_list([1, 2, 3])
  let encoded = ctx.encode_flate(raw)
  let parms : @pdf.PdfObject = @pdf.d([
    ("/Predictor", Integer(2)),
    ("/Colors", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/Columns", Integer(0)),
  ])
  let (pdf, stream_ref, stream_obj) = mk_stream(encoded, [
    ("/Filter", Name(PdfName("/FlateDecode"))),
    ("/DecodeParms", parms),
  ])
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let decoded = match (stream_ref.val.1 : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_bytes_equal(decoded, raw)
}

///|
test "decode Flate errors on unknown PNG predictor bytes" {
  let ctx = @pdfcodec.PdfCodec::new()
  // predictor byte 9 is invalid (valid: 0..4).
  let raw = @pdfio.bytes_of_list([9, 7, 8])
  let encoded = ctx.encode_flate(raw)
  let parms : @pdf.PdfObject = @pdf.d([
    ("/Predictor", Integer(12)),
    ("/Colors", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/Columns", Integer(2)),
  ])
  let (pdf, _stream_ref, stream_obj) = mk_stream(encoded, [
    ("/Filter", Name(PdfName("/FlateDecode"))),
    ("/DecodeParms", parms),
  ])
  let res : Result[Unit, Error] = try? ctx.decode_pdfstream_onestage(
    pdf, stream_obj,
  )
  assert_true(res is Err(_))
}

///|
test "encode_pdfstream errors when existing /Filter has wrong type" {
  let ctx = @pdfcodec.PdfCodec::new()
  let (pdf, _stream_ref, stream_obj) = mk_stream(@pdfio.bytes_of_string("x"), [
    ("/Filter", Integer(1)),
  ])
  let res : Result[Unit, Error] = try? ctx.encode_pdfstream(
    pdf,
    Flate,
    stream_obj,
  )
  assert_true(res is Err(_))
}

///|
test "encode_pdfstream follows indirect streams" {
  let ctx = @pdfcodec.PdfCodec::new()
  let (pdf, _stream_ref, stream_obj) = mk_stream(@pdfio.bytes_of_string("x"), [])
  let objnum = pdf.addobj(stream_obj)
  ctx.encode_pdfstream(pdf, Flate, Indirect(objnum))
}

///|
test "encode_pdfstream errors on malformed stream objects" {
  let ctx = @pdfcodec.PdfCodec::new()
  let pdf = @pdf.Pdf::empty()
  let res : Result[Unit, Error] = try? ctx.encode_pdfstream(pdf, Flate, Null)
  assert_true(res is Err(_))
}

///|
test "decode_pdfstream_onestage errors on malformed stream objects" {
  let ctx = @pdfcodec.PdfCodec::new()
  let pdf = @pdf.Pdf::empty()
  let res : Result[Unit, Error] = try? ctx.decode_pdfstream_onestage(pdf, Null)
  assert_true(res is Err(_))
}

///|
test "decode_pdfstream_onestage removes singleton filter and decode parms arrays" {
  let ctx = @pdfcodec.PdfCodec::new()
  let raw = @pdfio.bytes_of_string("x")
  let encoded = ctx.encode_flate(raw)
  let (pdf, stream_ref, stream_obj) = mk_stream(encoded, [
    ("/Filter", Array([Name(PdfName("/FlateDecode"))])),
    ("/DecodeParms", Array([@pdf.d([("/Predictor", Integer(1))])])),
  ])
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let dict = stream_ref.val.0
  assert_true(dict.lookup_immediate("/Filter") is None)
  assert_true(dict.lookup_immediate("/DecodeParms") is None)
}

///|
test "decode_pdfstream_onestage handles empty DecodeParms arrays" {
  let ctx = @pdfcodec.PdfCodec::new()
  let (pdf, stream_ref, stream_obj) = mk_stream(@pdfio.bytes_of_string("x"), [
    ("/Filter", Name(PdfName("/Crypt"))),
    ("/DecodeParms", Array([])),
  ])
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let decoded = match (stream_ref.val.1 : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_eq(@pdfio.string_of_bytes(decoded), "x")
}

///|
test "decode_pdfstream_onestage handles null DecodeParms" {
  let ctx = @pdfcodec.PdfCodec::new()
  let (pdf, stream_ref, stream_obj) = mk_stream(@pdfio.bytes_of_string("x"), [
    ("/Filter", Name(PdfName("/Crypt"))),
    ("/DecodeParms", Null),
  ])
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let decoded = match (stream_ref.val.1 : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_eq(@pdfio.string_of_bytes(decoded), "x")
}

///|
test "decode_from_bytes treats null DecodeParms as missing" {
  let dict : @pdf.PdfObject = @pdf.d([
    ("/Filter", Name(PdfName("/Crypt"))),
    ("/DecodeParms", Null),
  ])
  match
    (
      @pdfcodec.PdfCodec::new().decode_from_bytes(
        @pdfio.bytes_of_string("x"),
        dict,
      ) : Array[Byte]?) {
    Some(bytes) => assert_eq(@pdfio.string_of_bytes(bytes), "x")
    None => fail("expected Crypt decode to succeed")
  }
}

///|
test "encode_pdfstream maps PdfError via map_pdf_error" {
  let ctx = @pdfcodec.PdfCodec::new()
  let stream_ref : Ref[(@pdf.PdfObject, @pdf.Stream)] = Ref::new(
    (Integer(1), Got(@pdfio.bytes_of_string("x"))),
  )
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  let res : Result[Unit, Error] = try? ctx.encode_pdfstream(
    @pdf.Pdf::empty(),
    Flate,
    stream_obj,
  )
  assert_true(res is Err(_))
}

///|
test "decode_from_bytes reads boolean decode parameters" {
  let dict : @pdf.PdfObject = @pdf.d([
    ("/Filter", Name(PdfName("/CCITTFaxDecode"))),
    (
      "/DecodeParms",
      @pdf.d([("/BlackIs1", Boolean(true)), ("/Columns", Integer(1))]),
    ),
  ])
  let out = @pdfcodec.PdfCodec::new().decode_from_bytes(@pdfio.mkbytes(0), dict)
  // Decoding will fail on empty data, but parameters are still parsed.
  assert_true(out is None)
}

///|
test "decode_pdfstream_until_unknown rethrows malformed stream errors" {
  let ctx = @pdfcodec.PdfCodec::new()
  let pdf = @pdf.Pdf::empty()
  let res : Result[Unit, Error] = try? ctx.decode_pdfstream_until_unknown(
    pdf,
    Null,
  )
  assert_true(res is Err(_))
}

///|
test "decode_pdfstream rejects malformed /Filter type" {
  let ctx = @pdfcodec.PdfCodec::new()
  let (pdf, _stream_ref, stream_obj) = mk_stream(@pdfio.bytes_of_string("x"), [
    ("/Filter", Integer(1)),
  ])
  let res : Result[Unit, Error] = try? ctx.decode_pdfstream(pdf, stream_obj)
  assert_true(res is Err(_))
}

///|
test "decode_pdfstream follows indirect streams" {
  let ctx = @pdfcodec.PdfCodec::new()
  let (pdf, _stream_ref, stream_obj) = mk_stream(
    @pdfio.bytes_of_string("indirect"),
    [("/Filter", Name(PdfName("/Crypt")))],
  )
  let objnum = pdf.addobj(stream_obj)
  ctx.decode_pdfstream(pdf, Indirect(objnum))
}
