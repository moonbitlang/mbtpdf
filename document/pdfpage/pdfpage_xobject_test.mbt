///|
test "process_xobjects updates form xobject stream" {
  let pdf = @pdf.Pdf::empty()
  let stream_dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/Subtype"), Name(PdfName("/Form"))),
    (@pdf.PdfName::of_bytes("/Filter"), Name(PdfName("/FlateDecode"))),
  ])
  let data = @pdfio.bytes_of_list([0x01, 0x02])
  let stream : @pdf.PdfObject = Stream(Ref::new((stream_dict, Got(data))))
  let xobj_num = pdf.addobj(stream)
  let resources : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (
      @pdf.PdfName::of_bytes("/XObject"),
      @pdf.PdfObject::Dictionary([
        (@pdf.PdfName::of_bytes("/X1"), Indirect(xobj_num)),
      ]),
    ),
  ])
  let page = @pdfpage.Page(
    content=[],
    mediabox=Array([Real(0.0), Real(0.0), Real(10.0), Real(20.0)]),
    resources~,
    rotate=Rotate0,
    rest=@pdf.PdfObject::Dictionary([]),
  )
  let bbox : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(20.0),
  ])
  let update = fn(
    _ : @pdf.Pdf,
    _ : @pdf.PdfObject,
    _ : Array[@pdf.PdfObject],
  ) -> Array[@pdf.PdfObject] {
    let dict_updated : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
      (@pdf.PdfName::of_bytes("/BBox"), bbox),
      (@pdf.PdfName::of_bytes("/Filter"), Name(PdfName("/ASCIIHexDecode"))),
    ])
    let updated_data = @pdfio.bytes_of_list([0x41, 0x42])
    [Stream(Ref::new((dict_updated, Got(updated_data))))]
  }
  page.process_xobjects(pdf, update)
  let updated = pdf.lookup_obj(xobj_num)
  match (pdf.lookup_direct("/Subtype", updated) : @pdf.PdfObject?) {
    Some(Name(PdfName("/Form"))) => ()
    _ => fail("expected /Form subtype")
  }
  match (pdf.lookup_direct("/BBox", updated) : @pdf.PdfObject?) {
    Some(Array(_)) => ()
    _ => fail("expected bbox")
  }
  match pdf.lookup_direct("/Filter", updated) {
    None => ()
    _ => fail("expected filter removal")
  }
  let updated_bytes = updated.bigarray_of_stream()
  assert_eq(@pdfio.int_array_of_bytes(updated_bytes), [0x41, 0x42])
}

///|
test "combine_pdf_resources merges known and keeps unknown" {
  let pdf = @pdf.Pdf::empty()
  let a : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (
      @pdf.PdfName::of_bytes("/Font"),
      @pdf.PdfObject::Dictionary([(@pdf.PdfName::of_bytes("/F1"), Null)]),
    ),
    (@pdf.PdfName::of_bytes("/Foo"), Integer(1)),
  ])
  let b : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (
      @pdf.PdfName::of_bytes("/Font"),
      @pdf.PdfObject::Dictionary([(@pdf.PdfName::of_bytes("/F2"), Null)]),
    ),
    (@pdf.PdfName::of_bytes("/Bar"), Name(PdfName("/Baz"))),
  ])
  let combined = @pdfpage.PdfPageDoc::new(pdf).combine_pdf_resources(a, b)
  match (pdf.lookup_direct("/Font", combined) : @pdf.PdfObject?) {
    Some(Dictionary(entries)) => assert_eq(entries.length(), 2)
    _ => fail("expected merged fonts")
  }
  match (pdf.lookup_direct("/Foo", combined) : @pdf.PdfObject?) {
    Some(Integer(1)) => ()
    _ => fail("expected /Foo")
  }
  match (pdf.lookup_direct("/Bar", combined) : @pdf.PdfObject?) {
    Some(Name(PdfName("/Baz"))) => ()
    _ => fail("expected /Bar")
  }
}

///|
test "process_xobjects errors when xobject subtype missing" {
  let pdf = @pdf.Pdf::empty()
  let stream_dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/Filter"), Name(PdfName("/FlateDecode"))),
  ])
  let data = @pdfio.bytes_of_list([0x01])
  let stream : @pdf.PdfObject = Stream(Ref::new((stream_dict, Got(data))))
  let xobj_num = pdf.addobj(stream)
  let resources : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (
      @pdf.PdfName::of_bytes("/XObject"),
      @pdf.PdfObject::Dictionary([
        (@pdf.PdfName::of_bytes("/X1"), Indirect(xobj_num)),
      ]),
    ),
  ])
  let page = @pdfpage.Page(
    content=[],
    mediabox=Array([Real(0.0), Real(0.0), Real(10.0), Real(20.0)]),
    resources~,
    rotate=Rotate0,
    rest=@pdf.PdfObject::Dictionary([]),
  )
  let update = fn(
    _ : @pdf.Pdf,
    _ : @pdf.PdfObject,
    _ : Array[@pdf.PdfObject],
  ) -> Array[@pdf.PdfObject] {
    []
  }
  let res : Result[Unit, Error] = try? page.process_xobjects(pdf, update)
  assert_true(res is Err(_))
}

///|
test "process_xobjects accepts updated stream with non-dict metadata" {
  let pdf = @pdf.Pdf::empty()
  let stream_dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/Subtype"), Name(PdfName("/Form"))),
    (@pdf.PdfName::of_bytes("/Filter"), Name(PdfName("/FlateDecode"))),
  ])
  let data = @pdfio.bytes_of_list([0x01, 0x02])
  let stream : @pdf.PdfObject = Stream(Ref::new((stream_dict, Got(data))))
  let xobj_num = pdf.addobj(stream)
  let resources : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (
      @pdf.PdfName::of_bytes("/XObject"),
      @pdf.PdfObject::Dictionary([
        (@pdf.PdfName::of_bytes("/X1"), Indirect(xobj_num)),
      ]),
    ),
  ])
  let page = @pdfpage.Page(
    content=[],
    mediabox=Array([Real(0.0), Real(0.0), Real(10.0), Real(20.0)]),
    resources~,
    rotate=Rotate0,
    rest=@pdf.PdfObject::Dictionary([]),
  )
  let update = fn(
    _ : @pdf.Pdf,
    _ : @pdf.PdfObject,
    _ : Array[@pdf.PdfObject],
  ) -> Array[@pdf.PdfObject] {
    let updated_data = @pdfio.bytes_of_list([0x41, 0x42])
    let dict_updated : @pdf.PdfObject = Integer(0)
    [Stream(Ref::new((dict_updated, Got(updated_data))))]
  }
  page.process_xobjects(pdf, update)
  let updated = pdf.lookup_obj(xobj_num)
  match pdf.lookup_direct("/Filter", updated) {
    None => ()
    _ => fail("expected filter removal")
  }
  let updated_bytes = updated.bigarray_of_stream()
  assert_eq(@pdfio.int_array_of_bytes(updated_bytes), [0x41, 0x42])
}

///|
test "process_xobjects errors on non-indirect xobject references" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (
      @pdf.PdfName::of_bytes("/XObject"),
      @pdf.PdfObject::Dictionary([(@pdf.PdfName::of_bytes("/X1"), Integer(0))]),
    ),
  ])
  let page = @pdfpage.Page(
    content=[],
    mediabox=Array([Real(0.0), Real(0.0), Real(10.0), Real(20.0)]),
    resources~,
    rotate=Rotate0,
    rest=@pdf.PdfObject::Dictionary([]),
  )
  let update = fn(
    _ : @pdf.Pdf,
    _ : @pdf.PdfObject,
    _ : Array[@pdf.PdfObject],
  ) -> Array[@pdf.PdfObject] {
    []
  }
  let res : Result[Unit, Error] = try? page.process_xobjects(pdf, update)
  assert_true(res is Err(_))
}

///|
test "process_xobjects ignores non-form xobjects" {
  let pdf = @pdf.Pdf::empty()
  let xobj_dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/Subtype"), Name(PdfName("/Image"))),
  ])
  let xobj_num = pdf.addobj(xobj_dict)
  let resources : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (
      @pdf.PdfName::of_bytes("/XObject"),
      @pdf.PdfObject::Dictionary([
        (@pdf.PdfName::of_bytes("/Im0"), Indirect(xobj_num)),
      ]),
    ),
  ])
  let page = @pdfpage.Page(
    content=[],
    mediabox=Array([Real(0.0), Real(0.0), Real(10.0), Real(20.0)]),
    resources~,
    rotate=Rotate0,
    rest=@pdf.PdfObject::Dictionary([]),
  )
  let calls : Ref[Int] = { val: 0 }
  let update = fn(
    _ : @pdf.Pdf,
    _ : @pdf.PdfObject,
    _ : Array[@pdf.PdfObject],
  ) -> Array[@pdf.PdfObject] {
    calls.val = calls.val + 1
    []
  }
  page.process_xobjects(pdf, update)
  assert_eq(calls.val, 0)
}

///|
test "process_xobjects does nothing when /XObject is missing" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = @pdf.PdfObject::Dictionary([])
  let page = @pdfpage.Page(
    content=[],
    mediabox=Array([Real(0.0), Real(0.0), Real(10.0), Real(20.0)]),
    resources~,
    rotate=Rotate0,
    rest=@pdf.PdfObject::Dictionary([]),
  )
  page.process_xobjects(pdf, fn(_, _, _) { [] })
}

///|
test "combine_pdf_resources handles non-dictionary inputs" {
  let pdf = @pdf.Pdf::empty()
  let combined = @pdfpage.PdfPageDoc::new(pdf).combine_pdf_resources(
    Integer(1),
    @pdf.PdfObject::Dictionary([
      (
        @pdf.PdfName::of_bytes("/Font"),
        @pdf.PdfObject::Dictionary([(@pdf.PdfName::of_bytes("/F1"), Null)]),
      ),
    ]),
  )
  match (pdf.lookup_direct("/Font", combined) : @pdf.PdfObject?) {
    Some(Dictionary(_)) => ()
    _ => fail("expected /Font to be preserved")
  }
}

///|
test "combine_pdf_resources ignores non-dictionary rhs" {
  let pdf = @pdf.Pdf::empty()
  let combined = @pdfpage.PdfPageDoc::new(pdf).combine_pdf_resources(
    @pdf.PdfObject::Dictionary([
      (
        @pdf.PdfName::of_bytes("/Font"),
        @pdf.PdfObject::Dictionary([(@pdf.PdfName::of_bytes("/F1"), Null)]),
      ),
    ]),
    Integer(0),
  )
  match (pdf.lookup_direct("/Font", combined) : @pdf.PdfObject?) {
    Some(Dictionary(entries)) => assert_eq(entries.length(), 1)
    _ => fail("expected /Font to be preserved")
  }
}

///|
test "process_xobject errors when form xobject is not a stream" {
  let pdf = @pdf.Pdf::empty()
  let xobj_num = pdf.addobj(
    @pdf.PdfObject::Dictionary([
      (@pdf.PdfName::of_bytes("/Subtype"), Name(PdfName("/Form"))),
    ]),
  )
  let res : Result[Unit, Error] = try? @pdfpage.PdfPageDoc::new(pdf).process_xobject(
    fn(_, _, _) { [] },
    @pdf.PdfObject::Dictionary([]),
    xobj_num,
  )
  assert_true(res is Err(_))
}

///|
test "process_xobjects errors when updater returns non-stream" {
  let pdf = @pdf.Pdf::empty()
  let stream_dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.PdfName::of_bytes("/Subtype"), Name(PdfName("/Form"))),
  ])
  let data = @pdfio.bytes_of_list([0x01])
  let stream : @pdf.PdfObject = Stream(Ref::new((stream_dict, Got(data))))
  let xobj_num = pdf.addobj(stream)
  let resources : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (
      @pdf.PdfName::of_bytes("/XObject"),
      @pdf.PdfObject::Dictionary([
        (@pdf.PdfName::of_bytes("/X1"), Indirect(xobj_num)),
      ]),
    ),
  ])
  let page = @pdfpage.Page(
    content=[],
    mediabox=Array([Real(0.0), Real(0.0), Real(10.0), Real(20.0)]),
    resources~,
    rotate=Rotate0,
    rest=@pdf.PdfObject::Dictionary([]),
  )
  let update = fn(
    _ : @pdf.Pdf,
    _ : @pdf.PdfObject,
    _ : Array[@pdf.PdfObject],
  ) -> Array[@pdf.PdfObject] {
    [Integer(0)]
  }
  let res : Result[Unit, Error] = try? page.process_xobjects(pdf, update)
  assert_true(res is Err(_))
}
