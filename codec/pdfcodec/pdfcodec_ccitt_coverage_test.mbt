///|
fn assert_bytes_eq(left : Array[Byte], right : Array[Byte]) -> Unit raise {
  assert_eq(left.length(), right.length())
  for i in 0..<left.length() {
    assert_eq(left[i], right[i])
  }
}

///|
fn bitmap_bytes_from_row_runs(
  rows : Array[Array[Int]],
  start_bit : Int,
) -> Array[Byte] {
  let output = @pdfio.BitstreamWrite::new()
  for row in rows {
    let mut bit = start_bit
    for n in row {
      for _ in 0..<n {
        output.putbit(bit)
      }
      bit = 1 - bit
    }
    output.align()
  }
  output.bytes()
}

///|
fn ccitt_roundtrip(
  encoding : Encoding,
  k : Int,
  columns : Int,
  rows : Int,
  raw : Array[Byte],
) -> Unit raise {
  let pdf = @pdf.Pdf::empty()
  let decodeparms : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/K"), Integer(k)),
    (@pdf.PdfName::of_bytes("/Columns"), Integer(columns)),
    (@pdf.PdfName::of_bytes("/Rows"), Integer(rows)),
  ])
  let dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/Length"), Integer(@pdfio.bytes_size(raw))),
    (@pdf.PdfName::of_bytes("/DecodeParms"), decodeparms),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(raw)))
  let stream_obj = @pdf.PdfObject::Stream(stream_ref)
  let ctx : PdfCodec = PdfCodec::new()
  ctx.encode_pdfstream(pdf, encoding, stream_obj)
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let (_decoded_dict, decoded_stream) = stream_ref.val
  let decoded_bytes = match decoded_stream {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_bytes_eq(decoded_bytes, raw)
}

///|
test "ccitt g3 roundtrip covers many terminating codes" {
  let columns = 65
  let rows : Array[Array[Int]] = []
  for i in 1..<=64 {
    rows.push([i, columns - i])
  }
  let raw = bitmap_bytes_from_row_runs(rows, 0)
  ccitt_roundtrip(CCITT(columns, 64), 0, columns, 64, raw)
}

///|
test "ccitt g4 roundtrip covers many terminating codes" {
  let columns = 8
  let rows = 2
  let raw = bitmap_bytes_from_row_runs(
    [[1, 1, 1, 1, 1, 1, 1, 1], [1, 1, 1, 1, 1, 1, 1, 1]],
    1,
  )
  ccitt_roundtrip(CCITTG4(columns, rows), -1, columns, rows, raw)
}

///|
test "ccitt g4 roundtrip covers pass mode" {
  let columns = 16
  let rows = 2
  let raw = bitmap_bytes_from_row_runs([[4, 2, 10], [8, 2, 6]], 1)
  ccitt_roundtrip(CCITTG4(columns, rows), -1, columns, rows, raw)
}

///|
test "ccitt g4 roundtrip covers vertical modes" {
  let columns = 16
  let rows = 4
  let raw = bitmap_bytes_from_row_runs(
    [[5, 5, 6], [7, 3, 6], [10, 1, 5], [7, 3, 6]],
    1,
  )
  ccitt_roundtrip(CCITTG4(columns, rows), -1, columns, rows, raw)
}

///|
test "ccitt g3 roundtrip covers many makeup codes" {
  let columns = 2624
  let rows : Array[Array[Int]] = []
  for i in 1..<=40 {
    let n = 64 * i
    rows.push([n, columns - n])
  }
  let raw = bitmap_bytes_from_row_runs(rows, 0)
  ccitt_roundtrip(CCITT(columns, 40), 0, columns, 40, raw)
}

///|
test "ccitt g4 roundtrip covers many makeup codes" {
  let columns = 256
  let rows = 1
  let raw = bitmap_bytes_from_row_runs([[64, 64, 64, 64]], 1)
  ccitt_roundtrip(CCITTG4(columns, rows), -1, columns, rows, raw)
}

///|
test "ccitt g4 roundtrip covers varied run lengths (single-row)" {
  // Stable mix of short + long runs.
  let runs : Array[Int] = []
  let mut columns = 0
  for i in 1..<=16 {
    runs.push(i)
    columns = columns + i
  }
  runs.push(64)
  columns = columns + 64
  runs.push(256 - columns)
  columns = 256
  let rows = 2
  let raw = bitmap_bytes_from_row_runs([runs, runs], 1)
  ccitt_roundtrip(CCITTG4(columns, rows), -1, columns, rows, raw)
}

///|
test "ccitt g4 roundtrip covers 1..=64 run lengths starting black" {
  let runs : Array[Int] = []
  let mut columns = 0
  for i in 1..<=64 {
    runs.push(i)
    columns = columns + i
  }
  let rows = 1
  let raw = bitmap_bytes_from_row_runs([runs], 0)
  ccitt_roundtrip(CCITTG4(columns, rows), -1, columns, rows, raw)
}

///|
test "encode_pdfstream CCITT errors on insufficient data" {
  let pdf = @pdf.Pdf::empty()
  let data = @pdfio.mkbytes(0)
  let dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/Length"), Integer(0)),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  let ctx : PdfCodec = PdfCodec::new()
  let res : Result[Unit, Error] = try? ctx.encode_pdfstream(
    pdf,
    CCITT(16, 1),
    stream_obj,
    only_if_smaller=false,
  )
  assert_true(res is Err(_))
}

///|
test "encode_pdfstream CCITTG4 errors on insufficient data" {
  let pdf = @pdf.Pdf::empty()
  let data = @pdfio.mkbytes(0)
  let dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/Length"), Integer(0)),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  let ctx : PdfCodec = PdfCodec::new()
  let res : Result[Unit, Error] = try? ctx.encode_pdfstream(
    pdf,
    CCITTG4(16, 1),
    stream_obj,
    only_if_smaller=false,
  )
  assert_true(res is Err(_))
}
