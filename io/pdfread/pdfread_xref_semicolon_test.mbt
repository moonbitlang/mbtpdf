///|
fn write_zero_pad(sb : StringBuilder, width : Int, value : Int) -> Unit {
  let s = value.to_string()
  let missing = width - s.length()
  if missing > 0 {
    for _ in 0..<missing {
      sb.write_char('0')
    }
  }
  sb.write_string(s)
}

///|
fn build_minimal_pdf_with_xref_section_header_semicolon() -> String {
  let header = "%PDF-1.4\n"
  let obj1 = "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n"
  let obj2 = "2 0 obj\n<< /Type /Pages /Count 0 >>\nendobj\n"
  let offset1 = header.length()
  let offset2 = header.length() + obj1.length()
  let xref_offset = header.length() + obj1.length() + obj2.length()
  let sb = StringBuilder()
  sb.write_string(header)
  sb.write_string(obj1)
  sb.write_string(obj2)
  sb.write_string("xref\n")
  sb.write_string("0 3;\n")
  sb.write_string("0000000000 65535 f \n")
  write_zero_pad(sb, 10, offset1)
  sb.write_string(" 00000 n \n")
  write_zero_pad(sb, 10, offset2)
  sb.write_string(" 00000 n \n")
  sb.write_string("trailer\n")
  sb.write_string("<< /Size 3 /Root 1 0 R >>\n")
  sb.write_string("startxref\n")
  sb.write_string(xref_offset.to_string())
  sb.write_string("\n%%EOF\n")
  sb.to_string()
}

///|
test "PdfRead tolerates ';' after xref section header" {
  let data = build_minimal_pdf_with_xref_section_header_semicolon()
  let input = @pdfio.Input::of_string(data)
  let res : Result[@pdf.Pdf, Error] = try
    @pdfe.with_logger(_ => (), fn() {
      @pdfread.PdfRead::new(logger=_ => ()).pdf_of_input(None, None, input)
    })
    |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Ok(_))
}
