///|
let ctx : @pdfflate.PdfFlate = PdfFlate::new()

///|
priv struct LsbBitWriter {
  out : Array[Byte]
  mut cur : Int
  mut bit_pos : Int
}

///|
fn LsbBitWriter::new() -> LsbBitWriter {
  { out: Array::new(), cur: 0, bit_pos: 0 }
}

///|
fn LsbBitWriter::write_bits(
  self : LsbBitWriter,
  value : Int,
  count : Int,
) -> Unit {
  for i in 0..<count {
    let bit = (value >> i) & 1
    self.cur = self.cur | (bit << self.bit_pos)
    self.bit_pos = self.bit_pos + 1
    if self.bit_pos == 8 {
      self.out.push(self.cur.to_byte())
      self.cur = 0
      self.bit_pos = 0
    }
  }
}

///|
fn LsbBitWriter::finish(self : LsbBitWriter) -> Array[Byte] {
  if self.bit_pos != 0 {
    self.out.push(self.cur.to_byte())
  }
  self.out
}

///|
fn run_uncompress(
  data : Array[Byte],
  header : Bool,
) -> Array[Byte] raise FlateError {
  let mut pos = 0
  let input = (buf : Array[Byte]) => {
    let remaining = data.length() - pos
    if remaining <= 0 {
      0
    } else {
      let n = if remaining < buf.length() { remaining } else { buf.length() }
      for i in 0..<n {
        buf[i] = data[pos + i]
      }
      pos = pos + n
      n
    }
  }
  let out : Array[Byte] = Array::new()
  let output = (buf : Array[Byte], length : Int) => {
    for i in 0..<length {
      out.push(buf[i])
    }
  }
  ctx.uncompress(header~, input, output)
  out
}

///|
fn run_compress(data : Array[Byte], header : Bool) -> Array[Byte] {
  let mut pos = 0
  let input = (buf : Array[Byte]) => {
    let remaining = data.length() - pos
    if remaining <= 0 {
      0
    } else {
      let n = if remaining < buf.length() { remaining } else { buf.length() }
      for i in 0..<n {
        buf[i] = data[pos + i]
      }
      pos = pos + n
      n
    }
  }
  let out : Array[Byte] = Array::new()
  let output = (buf : Array[Byte], length : Int) => {
    for i in 0..<length {
      out.push(buf[i])
    }
  }
  ctx.compress(header~, input, output)
  out
}

///|
fn[T] assert_flate_error(
  result : Result[T, Error],
  expected : String,
) -> Unit raise {
  match result {
    Err(FlateError::Error(_stage, msg)) => assert_eq(msg, expected)
    Ok(_) => fail("expected flate error")
    Err(_) => fail("unexpected error")
  }
}

///|
test "uncompress stored zlib" {
  let data : Array[Byte] = [
    120, 1, 1, 11, 0, 244, 255, 104, 101, 108, 108, 111, 32, 119, 111, 114, 108,
    100, 26, 11, 4, 93,
  ]
  let out = run_uncompress(data, true) catch {
    Error(stage, msg) => fail("\{stage}: \{msg}")
  }
  let ints = out.map(b => b.to_int())
  inspect(
    ints,
    content="[104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100]",
  )
}

///|
test "uncompress fixed huffman" {
  let data : Array[Byte] = [
    203, 72, 205, 201, 201, 87, 40, 207, 47, 202, 73, 1, 0,
  ]
  let out = run_uncompress(data, false) catch {
    Error(stage, msg) => fail("\{stage}: \{msg}")
  }
  let ints = out.map(b => b.to_int())
  inspect(
    ints,
    content="[104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100]",
  )
}

///|
test "uncompress fixed huffman with length/distance pairs" {
  // Hand-crafted raw DEFLATE stream (fixed Huffman) which emits:
  // "ABCDEF" then (len=11, dist=5) then (len=3, dist=1) then end-of-block.
  let data : Array[Byte] = [
    0x73, 0x74, 0x72, 0x76, 0x71, 0x75, 0x43, 0x22, 0x80, 0x00, 0x00,
  ]
  let out = run_uncompress(data, false) catch {
    Error(stage, msg) => fail("\{stage}: \{msg}")
  }
  assert_eq(@pdfio.string_of_bytes(out), "ABCDEFBCDEFBCDEFBBBB")
}

///|
test "uncompress dynamic huffman" {
  let data : Array[Byte] = [
    120, 156, 237, 196, 57, 1, 0, 0, 8, 4, 160, 172, 231, 211, 191, 130, 41, 220,
    96, 32, 213, 179, 145, 36, 73, 146, 36, 73, 146, 244, 217, 1, 198, 122, 142,
    2,
  ]
  let out = run_uncompress(data, true) catch {
    Error(stage, msg) => fail("\{stage}: \{msg}")
  }
  let expected = @pdfio.bytes_of_string("abcde".repeat(1000))
  assert_eq(out, expected)
}

///|
test "compress/uncompress roundtrip zlib" {
  let input = @pdfio.bytes_of_string("hello flate")
  let encoded = run_compress(input, true)
  let decoded = run_uncompress(encoded, true) catch {
    Error(stage, msg) => fail("\{stage}: \{msg}")
  }
  assert_eq(@pdfio.string_of_bytes(decoded), "hello flate")
}

///|
test "compress/uncompress roundtrip raw" {
  let input = @pdfio.bytes_of_string("hello flate raw")
  let encoded = run_compress(input, false)
  let decoded = run_uncompress(encoded, false) catch {
    Error(stage, msg) => fail("\{stage}: \{msg}")
  }
  assert_eq(@pdfio.string_of_bytes(decoded), "hello flate raw")
}

///|
test "compress/uncompress roundtrip raw multi-block stored" {
  let input : Array[Byte] = Array::make(70000, (0).to_byte())
  for i in 0..<input.length() {
    input[i] = (i & 0xFF).to_byte()
  }
  let encoded = run_compress(input, false)
  let decoded = run_uncompress(encoded, false) catch {
    Error(stage, msg) => fail("\{stage}: \{msg}")
  }
  assert_eq(decoded, input)
}

///|
test "uncompress rejects empty data" {
  let data : Array[Byte] = []
  let result : Result[Array[Byte], Error] = try? run_uncompress(data, false)
  assert_flate_error(result, "unexpected end of input")
}

///|
test "uncompress rejects short zlib header" {
  let data : Array[Byte] = [120]
  let result : Result[Array[Byte], Error] = try? run_uncompress(data, true)
  assert_flate_error(result, "zlib header too short")
}

///|
test "uncompress rejects unsupported method" {
  let data : Array[Byte] = [0, 0]
  let result : Result[Array[Byte], Error] = try? run_uncompress(data, true)
  assert_flate_error(result, "unsupported compression method")
}

///|
test "uncompress rejects invalid header checksum" {
  let data : Array[Byte] = [0x78, 0x00]
  let result : Result[Array[Byte], Error] = try? run_uncompress(data, true)
  assert_flate_error(result, "invalid zlib header")
}

///|
test "uncompress rejects preset dictionary flag" {
  let data : Array[Byte] = [0x78, 0x20]
  let result : Result[Array[Byte], Error] = try? run_uncompress(data, true)
  assert_flate_error(result, "preset dictionary not supported")
}

///|
test "uncompress rejects invalid block type" {
  let data : Array[Byte] = [0x07]
  let result : Result[Array[Byte], Error] = try? run_uncompress(data, false)
  assert_flate_error(result, "invalid block type")
}

///|
test "uncompress rejects stored length mismatch" {
  let data : Array[Byte] = [0x01, 0x01, 0x00, 0x00, 0x00]
  let result : Result[Array[Byte], Error] = try? run_uncompress(data, false)
  assert_flate_error(result, "stored block length mismatch")
}

///|
test "uncompress rejects invalid literal/length symbol" {
  let data : Array[Byte] = [0x1B, 0x03]
  let result : Result[Array[Byte], Error] = try? run_uncompress(data, false)
  assert_flate_error(result, "invalid literal/length symbol")
}

///|
test "uncompress rejects invalid distance symbol" {
  let data : Array[Byte] = [0x03, 0x3E]
  let result : Result[Array[Byte], Error] = try? run_uncompress(data, false)
  assert_flate_error(result, "invalid distance symbol")
}

///|
test "uncompress rejects dynamic repeat with no previous code length" {
  let w = LsbBitWriter::new()
  w.write_bits(1, 1) // BFINAL
  w.write_bits(2, 2) // BTYPE = 2 (dynamic)
  w.write_bits(0, 5) // HLIT = 257
  w.write_bits(0, 5) // HDIST = 1
  w.write_bits(0, 4) // HCLEN = 4
  // code length code lengths: symbols [16, 17, 18, 0]
  w.write_bits(1, 3) // symbol 16 has code length 1
  w.write_bits(0, 3)
  w.write_bits(0, 3)
  w.write_bits(0, 3)
  // first decoded code-length symbol is 16 (repeat) with no previous length
  w.write_bits(0, 1)
  let data = w.finish()
  let result : Result[Array[Byte], Error] = try? run_uncompress(data, false)
  assert_flate_error(result, "repeat with no previous code length")
}

///|
test "uncompress rejects dynamic code length overflow" {
  let w = LsbBitWriter::new()
  w.write_bits(1, 1) // BFINAL
  w.write_bits(2, 2) // BTYPE = 2 (dynamic)
  w.write_bits(0, 5) // HLIT = 257
  w.write_bits(0, 5) // HDIST = 1
  w.write_bits(0, 4) // HCLEN = 4
  // code length code lengths: symbols [16, 17, 18, 0]
  w.write_bits(0, 3)
  w.write_bits(0, 3)
  w.write_bits(1, 3) // symbol 18 has code length 1
  w.write_bits(0, 3)
  // Emit two "repeat zero 138 times" instructions; the second overflows total=258.
  w.write_bits(0, 1) // symbol 18
  w.write_bits(0x7F, 7)
  w.write_bits(0, 1) // symbol 18
  w.write_bits(0x7F, 7)
  let data = w.finish()
  let result : Result[Array[Byte], Error] = try? run_uncompress(data, false)
  assert_flate_error(result, "code length overflow")
}

///|
test "uncompress rejects distance beyond output" {
  // Starts with a (len=3, dist=1) copy with no prior output.
  let data : Array[Byte] = [0x03, 0x02, 0x00]
  let result : Result[Array[Byte], Error] = try? run_uncompress(data, false)
  assert_flate_error(result, "distance beyond output")
}

///|
test "compress handles empty input" {
  let data : Array[Byte] = []
  let encoded = run_compress(data, true)
  let decoded = run_uncompress(encoded, true)
  assert_eq(decoded.length(), 0)
}
