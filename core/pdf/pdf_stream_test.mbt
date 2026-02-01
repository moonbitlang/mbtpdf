///|
test "streams and transforms" {
  let pdf = Pdf::empty()
  pdf.addobj_given_num((1, Integer(7)))
  let input = @pdfio.Input::of_string("abcd", source="stream")
  let t = ToGet::new(input, 0, 4)
  let dict = d([("/Length", Integer(0))])
  let stream_ref = Ref::new((dict, Stream::ToGet(t)))
  let stream_obj = PdfObject::Stream(stream_ref)
  stream_obj.getstream()
  match stream_ref.val {
    (Dictionary(entries), Got(bytes)) => {
      assert_eq(@pdfio.bytes_size(bytes), 4)
      match entries.search_by(pair => pair.0 == "/Length") {
        Some(i) => assert_integer(entries[i].1, 4)
        None => fail("expected /Length")
      }
    }
    _ => fail("expected got stream")
  }
  let bytes = stream_obj.bigarray_of_stream()
  assert_eq(@pdfio.bytes_size(bytes), 4)
  assert_is_err(try? PdfObject::Integer(1).getstream())
  assert_is_err(try? PdfObject::Integer(1).bigarray_of_stream())
  assert_eq(pdf.getnum(Real(3.5)), 3.5)
  assert_eq(pdf.getnum(Integer(4)), 4.0)
  assert_eq(pdf.getnum(Indirect(1)), 7.0)
  assert_is_err(try? pdf.getnum(Name(PdfName("/A"))))
  assert_eq(
    pdf.parse_rectangle(Array([Integer(2), Integer(1), Integer(4), Integer(3)])),
    (2.0, 1.0, 4.0, 3.0),
  )
  assert_is_err(try? pdf.parse_rectangle(Array([Integer(1)])))
  assert_is_err(try? pdf.parse_rectangle(Integer(1)))
  let dict_matrix = d([
    (
      "/Matrix",
      Array([
        Integer(1),
        Integer(0),
        Integer(0),
        Integer(1),
        Integer(2),
        Integer(3),
      ]),
    ),
  ])
  let matrix = pdf.parse_matrix("/Matrix", dict_matrix)
  assert_eq(matrix.a, 1.0)
  assert_eq(matrix.d, 1.0)
  assert_eq(matrix.e, 2.0)
  assert_eq(matrix.f, 3.0)
  let identity = pdf.parse_matrix("/Missing", dict_matrix)
  assert_eq(identity.a, @pdftransform.TransformMatrix::identity().a)
  assert_eq(identity.d, @pdftransform.TransformMatrix::identity().d)
  assert_is_err(
    try? pdf.parse_matrix("/Matrix", d([("/Matrix", Array([Integer(1)]))])),
  )
  assert_is_err(try? pdf.parse_matrix("/Matrix", d([("/Matrix", Integer(1))])))
  match make_matrix(@pdftransform.TransformMatrix::identity()) {
    Array(values) => assert_eq(values.length(), 6)
    _ => fail("expected matrix array")
  }
  let rect = PdfObject::Array([Integer(0), Integer(0), Integer(2), Integer(3)])
  match pdf.transform_rect(@pdftransform.TransformMatrix::identity(), rect) {
    Array(values) => {
      assert_eq(values.length(), 4)
      match values[0] {
        Real(value) => assert_eq(value, 0.0)
        _ => fail("expected real")
      }
      match values[2] {
        Real(value) => assert_eq(value, 2.0)
        _ => fail("expected real")
      }
      match values[3] {
        Real(value) => assert_eq(value, 3.0)
        _ => fail("expected real")
      }
    }
    _ => fail("expected transformed rect")
  }
  let qp = PdfObject::Array([
    Real(0.0),
    Real(0.0),
    Real(1.0),
    Real(0.0),
    Real(1.0),
    Real(1.0),
    Real(0.0),
    Real(1.0),
    Real(0.0),
    Real(0.0),
    Real(2.0),
    Real(0.0),
    Real(2.0),
    Real(2.0),
    Real(0.0),
    Real(2.0),
  ])
  match
    pdf.transform_quadpoints(@pdftransform.TransformMatrix::identity(), qp) {
    Array(values) => assert_eq(values.length(), 16)
    _ => fail("expected quadpoints")
  }
  let qp_mixed = PdfObject::Array([
    Real(0.0),
    Real(1.0),
    Real(2.0),
    Real(3.0),
    Real(4.0),
    Real(5.0),
    Real(6.0),
    Real(7.0),
    Real(8.0),
    Real(9.0),
  ])
  @pdfe.with_logger(_ => (), fn() {
    match
      pdf.transform_quadpoints(
        @pdftransform.TransformMatrix::identity(),
        qp_mixed,
      ) {
      Array(values) => assert_eq(values.length(), 10)
      _ => fail("expected quadpoints")
    }
    let qp_bad = PdfObject::Array([Real(0.0), Real(1.0)])
    match
      pdf.transform_quadpoints(
        @pdftransform.TransformMatrix::identity(),
        qp_bad,
      ) {
      Array(values) => assert_eq(values.length(), 2)
      _ => fail("expected quadpoints")
    }
    match
      pdf.transform_quadpoints(
        @pdftransform.TransformMatrix::identity(),
        Integer(1),
      ) {
      Integer(1) => ()
      _ => fail("expected passthrough")
    }
    ()
  })
}

///|
test "getstream error cases" {
  let input = @pdfio.Input::of_string("abc", source="crypt")
  let crypt = ToGetCrypt::ToDecrypt({
    crypt_type: AESV2,
    file_encryption_key: None,
    obj: 1,
    gen: 0,
    key: [1],
    keylength: 40,
    r: 5,
  })
  let toget_crypt = ToGet::new(input, 0, 3, crypt~)
  let crypt_ref = Ref::new((d([]), Stream::ToGet(toget_crypt)))
  let crypt_stream = PdfObject::Stream(crypt_ref)
  assert_is_err(try? crypt_stream.getstream())
  let plain = @pdfio.Input::of_string("abc", source="plain")
  let toget_plain = ToGet::new(plain, 0, 3)
  let plain_ref = Ref::new((PdfObject::Integer(9), Stream::ToGet(toget_plain)))
  let plain_stream = PdfObject::Stream(plain_ref)
  plain_stream.getstream()
  match plain_ref.val {
    (Integer(9), Got(bytes)) => assert_eq(@pdfio.bytes_size(bytes), 3)
    _ => fail("expected stream data")
  }
}

///|
test "lookup_immediate_all preserves duplicate dictionary keys" {
  let dict = d([("/A", Integer(1)), ("/A", Integer(2)), ("/B", Integer(3))])
  let values = dict.lookup_immediate_all("/A")
  assert_eq(values.length(), 2)
  match values[0] {
    Integer(1) => ()
    _ => fail("expected first /A value")
  }
  match values[1] {
    Integer(2) => ()
    _ => fail("expected second /A value")
  }
}
