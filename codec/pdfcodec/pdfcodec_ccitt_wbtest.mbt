///|
let ccitt_ctx : PdfCodec = PdfCodec::new()

///|
fn bitmap_bytes(
  rows_bits : Array[Array[Int]],
  columns : Int,
) -> Array[Byte] raise {
  let output = @pdfio.BitstreamWrite::new()
  for row in rows_bits {
    assert_eq(row.length(), columns)
    for bit in row {
      output.putbit(bit)
    }
    output.align()
  }
  output.bytes()
}

///|
fn assert_bytes_eq(left : Array[Byte], right : Array[Byte]) -> Unit raise {
  assert_eq(left.length(), right.length())
  for i in 0..<left.length() {
    assert_eq(left[i], right[i])
  }
}

///|
test "ccitt g3 roundtrip" {
  let columns = 8
  let rows = 2
  let rows_bits = [[1, 1, 1, 1, 0, 0, 1, 0], [1, 0, 1, 0, 1, 0, 1, 0]]
  let raw = bitmap_bytes(rows_bits, columns)
  let encoded = encode_ccitt(columns, rows, raw)
  let decoded = decode_ccittfax(
    0,
    false,
    false,
    columns,
    rows,
    true,
    false,
    0,
    @pdfio.Input::of_bytes(encoded, source="ccitt-g3"),
  )
  assert_bytes_eq(decoded, raw)
}

///|
test "ccitt g4 roundtrip" {
  let columns = 8
  let rows = 2
  let rows_bits = [[1, 0, 1, 0, 1, 0, 1, 0], [1, 1, 0, 0, 1, 1, 0, 0]]
  let raw = bitmap_bytes(rows_bits, columns)
  let encoded = encode_ccittg4(columns, rows, raw)
  let decoded = decode_ccittfax(
    -1,
    false,
    false,
    columns,
    rows,
    true,
    false,
    0,
    @pdfio.Input::of_bytes(encoded, source="ccitt-g4"),
  )
  assert_bytes_eq(decoded, raw)
}

///|
test "encode_pdfstream ccitt g3 roundtrip" {
  let pdf = @pdf.Pdf::empty()
  let columns = 8
  let rows = 2
  let rows_bits = [[1, 1, 1, 1, 0, 0, 1, 0], [1, 0, 1, 0, 1, 0, 1, 0]]
  let raw = bitmap_bytes(rows_bits, columns)
  let decodeparms = @pdf.PdfObject::Dictionary([
    ("/K", Integer(0)),
    ("/Columns", Integer(columns)),
    ("/Rows", Integer(rows)),
  ])
  let dict = @pdf.PdfObject::Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(raw))),
    ("/DecodeParms", decodeparms),
  ])
  let stream_ref = Ref((dict, @pdf.Stream::Got(raw)))
  let stream_obj = @pdf.PdfObject::Stream(stream_ref)
  ccitt_ctx.encode_pdfstream(pdf, CCITT(columns, rows), stream_obj)
  let (encoded_dict, _encoded_stream) = stream_ref.val
  match pdf.lookup_direct("/Filter", encoded_dict) {
    Some(Name(PdfName(b"/CCITTFaxDecode")))
    | Some(PdfArray([Name(PdfName(b"/CCITTFaxDecode")), ..])) => ()
    _ => fail("expected /Filter entry")
  }
  ccitt_ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let (_decoded_dict, decoded_stream) = stream_ref.val
  let decoded_bytes = match decoded_stream {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_bytes_eq(decoded_bytes, raw)
}

///|
test "encode_pdfstream ccitt g4 roundtrip" {
  let pdf = @pdf.Pdf::empty()
  let columns = 8
  let rows = 2
  let rows_bits = [[1, 0, 1, 0, 1, 0, 1, 0], [1, 1, 0, 0, 1, 1, 0, 0]]
  let raw = bitmap_bytes(rows_bits, columns)
  let decodeparms = @pdf.PdfObject::Dictionary([
    ("/K", Integer(-1)),
    ("/Columns", Integer(columns)),
    ("/Rows", Integer(rows)),
  ])
  let dict = @pdf.PdfObject::Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(raw))),
    ("/DecodeParms", decodeparms),
  ])
  let stream_ref = Ref((dict, @pdf.Stream::Got(raw)))
  let stream_obj = @pdf.PdfObject::Stream(stream_ref)
  ccitt_ctx.encode_pdfstream(pdf, CCITTG4(columns, rows), stream_obj)
  let (encoded_dict, _encoded_stream) = stream_ref.val
  match pdf.lookup_direct("/Filter", encoded_dict) {
    Some(Name(PdfName(b"/CCITTFaxDecode")))
    | Some(PdfArray([Name(PdfName(b"/CCITTFaxDecode")), ..])) => ()
    _ => fail("expected /Filter entry")
  }
  ccitt_ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let (_decoded_dict, decoded_stream) = stream_ref.val
  let decoded_bytes = match decoded_stream {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_bytes_eq(decoded_bytes, raw)
}
