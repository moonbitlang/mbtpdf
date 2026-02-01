///|
fn[T] assert_is_err(result : Result[T, Error]) -> Unit raise {
  match result {
    Err(_) => ()
    Ok(_) => fail("expected error")
  }
}

///|
fn make_stream(dict : @pdf.PdfObject, data : Array[Byte]) -> @pdf.PdfObject {
  Stream(Ref::new((dict, Got(data))))
}

///|
fn assert_integer(obj : @pdf.PdfObject, expected : Int) -> Unit raise {
  match obj {
    Integer(value) => assert_eq(value, expected)
    _ => fail("expected integer")
  }
}

///|
fn assert_some_integer(obj : @pdf.PdfObject?, expected : Int) -> Unit raise {
  match obj {
    Some(Integer(value)) => assert_eq(value, expected)
    Some(_) => fail("expected integer")
    None => fail("expected some")
  }
}

///|
fn make_basic_pdf() -> @pdf.Pdf {
  let base = @pdf.Pdf::empty()
  let pages = d([
    ("/Type", Name(PdfName("/Pages"))),
    ("/Kids", Array([Indirect(2)])),
  ])
  let page = d([("/Type", Name(PdfName("/Page")))])
  let catalog = d([
    ("/Type", Name(PdfName("/Catalog"))),
    ("/Pages", Indirect(1)),
  ])
  base.addobj_given_num((1, pages))
  base.addobj_given_num((2, page))
  base.addobj_given_num((3, catalog))
  {
    major: base.major,
    minor: base.minor,
    root: 3,
    objects: base.objects,
    trailerdict: d([("/Root", Indirect(3))]),
    was_linearized: base.was_linearized,
    saved_encryption: base.saved_encryption,
  }
}
