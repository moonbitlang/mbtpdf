///|
test "objects_referenced skips entries" {
  let pdf = Pdf::empty()
  let obj = PdfObject::Dictionary([
    ("/Skip", Indirect(1)),
    ("/Keep", Integer(2)),
  ])
  let referenced = pdf.objects_referenced(["/Skip"], [], obj)
  assert_eq(referenced.length(), 0)
}

///|
test "objects_referenced no_follow_contains non-name" {
  let pdf = Pdf::empty()
  let obj = PdfObject::Dictionary([
    ("/Other", Integer(3)),
    ("/Kid", Indirect(2)),
  ])
  pdf.addobj_given_num((1, obj))
  pdf.addobj_given_num((2, Integer(9)))
  let referenced = pdf.objects_referenced(
    [],
    [("/Other", Integer(3))],
    Indirect(1),
  )
  assert_true(referenced.contains(2))
}

///|
test "objects_referenced no_follow_contains name match" {
  let pdf = Pdf::empty()
  let dict = PdfObject::Dictionary([
    ("/Other", Name(PdfName(b"/Other"))),
    ("/Type", Name(PdfName(b"/Page"))),
    ("/Kid", Indirect(2)),
  ])
  pdf.addobj_given_num((1, dict))
  pdf.addobj_given_num((2, Integer(9)))
  let referenced = pdf.objects_referenced(
    [],
    [("/Type", Name(PdfName(b"/Page")))],
    Indirect(1),
  )
  assert_eq(referenced.length(), 0)
}

///|
test "objects_referenced no_follow_contains scans non-name entries" {
  let pdf = Pdf::empty()
  let dict = PdfObject::Dictionary([
    // Duplicate key: first non-Name should be skipped by predicate.
    ("/Type", Integer(1)),
    ("/Type", Name(PdfName(b"/Page"))),
    ("/Kid", Indirect(2)),
  ])
  pdf.addobj_given_num((1, dict))
  pdf.addobj_given_num((2, Integer(9)))
  let referenced = pdf.objects_referenced(
    [],
    [("/Type", Name(PdfName(b"/Page")))],
    Indirect(1),
  )
  assert_eq(referenced.length(), 0)
}

///|
test "objects_referenced indirect and stream targets" {
  let pdf = Pdf::empty()
  pdf.addobj_given_num((5, Integer(99)))
  let stream = make_stream(
    Dictionary([("/Ref", Indirect(5))]),
    @pdfio.bytes_of_string("x"),
  )
  pdf.addobj_given_num((6, stream))
  let indirect_refs = pdf.objects_referenced([], [], Indirect(5))
  assert_true(indirect_refs.contains(5))
  let stream_refs = pdf.objects_referenced([], [], pdf.lookup_obj(6))
  assert_true(stream_refs.contains(5))
}
