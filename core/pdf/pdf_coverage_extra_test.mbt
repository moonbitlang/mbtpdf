///|
test "serialization escapes extra cases" {
  let minimal = PdfObject::Name(PdfName("/"))
  assert_eq(minimal.to_string(), "/")
  let delimiter = PdfObject::Name(PdfName("/A(B"))
  assert_true(delimiter.to_string().contains("#28"))
  let delimiter2 = PdfObject::Name(PdfName("/A)B"))
  assert_true(delimiter2.to_string().contains("#29"))
  let delimiter3 = PdfObject::Name(PdfName("/A<B"))
  assert_true(delimiter3.to_string().contains("#3C"))
  let control = PdfObject::Name(PdfName::of_string("/\u0013"))
  assert_true(control.to_string().contains("#13"))
  let multibyte = PdfObject::Name(PdfName::of_string("/\u0094"))
  let multibyte_rendered = multibyte.to_string()
  assert_true(multibyte_rendered.contains("#94"))
  let yen = PdfObject::Name(PdfName::of_string("/\u00A5"))
  assert_true(yen.to_string().contains("#A5"))
  let escaped = PdfObject::String("\t\u000C")
  let rendered = escaped.to_string()
  assert_true(rendered.contains("\\t"))
  assert_true(rendered.contains("\\f"))
}

///|
test "serialization includes stream data when requested" {
  let bytes = @pdfio.bytes_of_string("abc")
  let dict : PdfObject = PdfObject::Dictionary([
    (n("/Length"), Integer(@pdfio.bytes_size(bytes))),
  ])
  let stream_ref = Ref::new((dict, Stream::Got(bytes)))
  let obj = PdfObject::Stream(stream_ref)
  let rendered = obj.to_string_including_data()
  assert_true(rendered.contains("stream"))
  assert_true(rendered.contains("abc"))
  assert_true(rendered.contains("endstream"))
}

///|
test "bigarray_of_stream rejects non-stream objects" {
  let res : Result[Array[Byte], Error] = try? PdfObject::Integer(0).bigarray_of_stream()
  assert_true(res is Err(_))
}

///|
test "lookup_chain treats malformed array key as dictionary key" {
  let pdf = Pdf::empty()
  let start : PdfObject = PdfObject::Dictionary([(n("/["), Integer(7))])
  let out = pdf.lookup_chain(start, ["/["])
  match (out : PdfObject?) {
    Some(Integer(7)) => ()
    _ => fail("expected dictionary lookup for /[")
  }
}
