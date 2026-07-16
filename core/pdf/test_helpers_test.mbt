///|
fn[T] assert_is_err(result : Result[T, Error]) -> Unit raise {
  match result {
    Err(_) => ()
    Ok(_) => fail("expected error")
  }
}

///|
fn make_stream(dict : @pdf.PdfObject, data : Array[Byte]) -> @pdf.PdfObject {
  Stream(Ref((dict, Got(data))))
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
  let pages = @pdf.PdfObject::Dictionary([
    ("/Type", Name(PdfName(b"/Pages"))),
    ("/Kids", PdfArray([Indirect(2)])),
  ])
  let page = @pdf.PdfObject::Dictionary([("/Type", Name(PdfName(b"/Page")))])
  let catalog = @pdf.PdfObject::Dictionary([
    ("/Type", Name(PdfName(b"/Catalog"))),
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
    trailerdict: Dictionary([("/Root", Indirect(3))]),
    was_linearized: base.was_linearized,
    saved_encryption: base.saved_encryption,
  }
}
