///|
fn assert_close(a : Double, b : Double) -> Unit raise {
  let diff = (a - b).abs()
  assert_true(diff < 0.000001)
}

///|
fn default_rect() -> @pdf.PdfObject {
  Array([Integer(0), Integer(0), Integer(100), Integer(100)])
}

///|
fn pdf_with_pages(count : Int, mediabox : @pdf.PdfObject) -> @pdf.Pdf raise {
  let pdf = @pdf.Pdf::empty()
  let pages_root_num = pdf.addobj(
    @pdf.d([
      ("/Type", Name(PdfName("/Pages"))),
      ("/Kids", Array([])),
      ("/Count", Integer(count)),
    ]),
  )
  let kids : Array[@pdf.PdfObject] = []
  let mut i = 0
  while i < count {
    let page_num = pdf.addobj(
      @pdf.d([
        ("/Type", Name(PdfName("/Page"))),
        ("/Parent", Indirect(pages_root_num)),
        ("/MediaBox", mediabox),
      ]),
    )
    kids.push(Indirect(page_num))
    i = i + 1
  }
  pdf.addobj_given_num(
    (
      pages_root_num,
      @pdf.d([
        ("/Type", Name(PdfName("/Pages"))),
        ("/Kids", Array(kids)),
        ("/Count", Integer(count)),
      ]),
    ),
  )
  let catalog_num = pdf.addobj(
    @pdf.d([
      ("/Type", Name(PdfName("/Catalog"))),
      ("/Pages", Indirect(pages_root_num)),
    ]),
  )
  let trailerdict = pdf.trailerdict.add_entry("/Root", Indirect(catalog_num))
  {
    major: pdf.major,
    minor: pdf.minor,
    root: catalog_num,
    objects: pdf.objects,
    trailerdict,
    was_linearized: pdf.was_linearized,
    saved_encryption: pdf.saved_encryption,
  }
}

///|
fn minimum_valid_pdf() -> @pdf.Pdf raise {
  pdf_with_pages(1, default_rect())
}

///|
test "read_destination array" {
  let pdf = @pdf.Pdf::empty()
  let obj : @pdf.PdfObject = Array([
    Indirect(7),
    Name(PdfName("/FitH")),
    Real(200.0),
  ])
  let dest = Destination::read(pdf, obj)
  match dest {
    FitH(PageObject(7), Some(top)) => assert_close(top, 200.0)
    _ => fail("expected FitH destination")
  }
}

///|
test "read_destination shallow name" {
  let pdf = @pdf.Pdf::empty()
  let dest = Destination::read(pdf, Name(PdfName("/Chapter1")), shallow=true)
  match dest {
    NamedDestination(PdfName("/Chapter1")) => ()
    _ => fail("expected NamedDestination")
  }
}

///|
test "destination to_pdf_object" {
  let dest = Destination::FitR(OtherDocPageNumber(3), 10.0, 20.0, 30.0, 40.0)
  let obj = dest.to_pdf_object()
  match (obj : @pdf.PdfObject) {
    Array(
      [Integer(3), Name(name), Real(10.0), Real(20.0), Real(30.0), Real(40.0)]
    ) if name is PdfName("/FitR") => ()
    _ => fail("unexpected pdfobject for destination")
  }
}

///|
test "transform_destination translate" {
  let pdf = @pdf.Pdf::empty()
  let dest = Destination::XYZ(PageObject(1), Some(10.0), Some(20.0), Some(1.0))
  let tr = @pdftransform.TransformMatrix::translate(5.0, -3.0)
  let transformed = dest.transform(pdf, tr)
  match transformed {
    XYZ(PageObject(1), Some(left), Some(top), Some(zoom)) => {
      assert_close(left, 15.0)
      assert_close(top, 17.0)
      assert_close(zoom, 1.0)
    }
    _ => fail("expected transformed XYZ destination")
  }
}

///|
test "transform_destination clips FitV/FitBH" {
  let pdf = @pdf.Pdf::empty()
  let tr = @pdftransform.TransformMatrix::identity()
  let fitv = Destination::FitV(PageObject(1), Some(40000.0)).transform(pdf, tr)
  match fitv {
    FitV(_, Some(left)) => assert_close(left, 32768.0)
    _ => fail("expected FitV clipped")
  }
  let fitbh = Destination::FitBH(PageObject(1), Some(-40000.0)).transform(
    pdf, tr,
  )
  match fitbh {
    FitBH(_, Some(top)) => assert_close(top, -32768.0)
    _ => fail("expected FitBH clipped")
  }
}

///|
test "transform_destination updates GoTo action" {
  let pdf = minimum_valid_pdf()
  let refs = pdf.page_reference_numbers()
  let action : @pdf.PdfObject = @pdf.d([
    ("/S", Name(PdfName("/GoTo"))),
    (
      "/D",
      Array([
        Indirect(refs[0]),
        Name(PdfName("/XYZ")),
        Real(10.0),
        Real(20.0),
        Null,
      ]),
    ),
  ])
  let tr = @pdftransform.TransformMatrix::translate(5.0, -3.0)
  let updated = Destination::Action(action).transform(pdf, tr)
  match updated {
    Action(dict) =>
      match pdf.lookup_direct("/D", dict) {
        Some(Array([_, Name(PdfName("/XYZ")), left, top, _])) => {
          assert_close(pdf.getnum(left), 15.0)
          assert_close(pdf.getnum(top), 17.0)
        }
        _ => fail("expected updated action destination")
      }
    _ => fail("expected action destination")
  }
}

///|
test "read_destination from dictionary /D" {
  let pdf = @pdf.Pdf::empty()
  let inner : @pdf.PdfObject = Array([
    Integer(0),
    Name(PdfName("/XYZ")),
    Real(10.0),
    Real(20.0),
    Real(1.0),
  ])
  let obj : @pdf.PdfObject = @pdf.d([("/D", inner)])
  let dest = Destination::read(pdf, obj)
  match dest {
    XYZ(OtherDocPageNumber(0), Some(left), Some(top), Some(zoom)) => {
      assert_close(left, 10.0)
      assert_close(top, 20.0)
      assert_close(zoom, 1.0)
    }
    _ => fail("expected XYZ destination")
  }
}

///|
test "read_destination array Fit and FitR" {
  let pdf = @pdf.Pdf::empty()
  let fit : @pdf.PdfObject = Array([Indirect(5), Name(PdfName("/Fit"))])
  match Destination::read(pdf, fit) {
    Fit(PageObject(5)) => ()
    _ => fail("expected Fit destination")
  }
  let fitr : @pdf.PdfObject = Array([
    Indirect(7),
    Name(PdfName("/FitR")),
    Real(1.0),
    Real(2.0),
    Real(3.0),
    Real(4.0),
  ])
  match Destination::read(pdf, fitr) {
    FitR(PageObject(7), left, top, right, bottom) => {
      assert_close(left, 1.0)
      assert_close(top, 2.0)
      assert_close(right, 3.0)
      assert_close(bottom, 4.0)
    }
    _ => fail("expected FitR destination")
  }
}

///|
test "read_destination array variants" {
  let pdf = @pdf.Pdf::empty()
  let xyz4 : @pdf.PdfObject = Array([
    Indirect(1),
    Name(PdfName("/XYZ")),
    Real(10.0),
    Null,
  ])
  match Destination::read(pdf, xyz4) {
    XYZ(PageObject(1), Some(left), None, None) => assert_close(left, 10.0)
    _ => fail("expected XYZ destination")
  }
  let xyz3 : @pdf.PdfObject = Array([Indirect(2), Name(PdfName("/XYZ")), Null])
  match Destination::read(pdf, xyz3) {
    XYZ(PageObject(2), None, None, None) => ()
    _ => fail("expected XYZ destination")
  }
  let fitv : @pdf.PdfObject = Array([
    Indirect(3),
    Name(PdfName("/FitV")),
    Real(12.0),
  ])
  match Destination::read(pdf, fitv) {
    FitV(PageObject(3), Some(left)) => assert_close(left, 12.0)
    _ => fail("expected FitV destination")
  }
  let fitbh : @pdf.PdfObject = Array([
    Indirect(4),
    Name(PdfName("/FitBH")),
    Real(9.0),
  ])
  match Destination::read(pdf, fitbh) {
    FitBH(PageObject(4), Some(top)) => assert_close(top, 9.0)
    _ => fail("expected FitBH destination")
  }
  let fitbv : @pdf.PdfObject = Array([
    Indirect(5),
    Name(PdfName("/FitBV")),
    Real(8.0),
  ])
  match Destination::read(pdf, fitbv) {
    FitBV(PageObject(5), Some(left)) => assert_close(left, 8.0)
    _ => fail("expected FitBV destination")
  }
  let fitb : @pdf.PdfObject = Array([Indirect(6), Name(PdfName("/FitB"))])
  match Destination::read(pdf, fitb) {
    FitB(PageObject(6)) => ()
    _ => fail("expected FitB destination")
  }
  let bad_target : @pdf.PdfObject = Array([
    Name(PdfName("/NotPage")),
    Name(PdfName("/FitH")),
    Real(1.0),
  ])
  match
    @pdfe.with_logger(_ => (), fn() { Destination::read(pdf, bad_target) }) {
    NullDestination => ()
    _ => fail("expected NullDestination for bad target")
  }
}

///|
test "read_destination returns NullDestination for invalid page targets" {
  let pdf = @pdf.Pdf::empty()
  let not_a_page : @pdf.PdfObject = Name(PdfName("/NotPage"))
  let objs : Array[@pdf.PdfObject] = [
    Array([not_a_page, Name(PdfName("/XYZ")), Null, Null, Null]),
    Array([not_a_page, Name(PdfName("/XYZ")), Null, Null]),
    Array([not_a_page, Name(PdfName("/XYZ")), Null]),
    Array([not_a_page, Name(PdfName("/FitH")), Null]),
    Array([not_a_page, Name(PdfName("/FitV")), Null]),
    Array([not_a_page, Name(PdfName("/FitBH")), Null]),
    Array([not_a_page, Name(PdfName("/FitBV")), Null]),
    Array([not_a_page, Name(PdfName("/Fit"))]),
    Array([not_a_page, Name(PdfName("/FitB"))]),
    Array([
      not_a_page,
      Name(PdfName("/FitR")),
      Real(1.0),
      Real(2.0),
      Real(3.0),
      Real(4.0),
    ]),
    Array([Indirect(1), Name(PdfName("/NotADest"))]),
  ]
  for obj in objs {
    match @pdfe.with_logger(_ => (), fn() { Destination::read(pdf, obj) }) {
      NullDestination => ()
      _ => fail("expected NullDestination for invalid destination array")
    }
  }
}

///|
test "read_destination handles missing and invalid objects" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = @pdf.d([])
  match Destination::read(pdf, dict) {
    NullDestination => ()
    _ => fail("expected NullDestination for missing /D")
  }
  match
    @pdfe.with_logger(_ => (), fn() { Destination::read(pdf, Integer(1)) }) {
    NullDestination => ()
    _ => fail("expected NullDestination for invalid object")
  }
}

///|
test "read_destination name resolution" {
  let pdf_no_root = @pdf.Pdf::empty()
  pdf_no_root.trailerdict = @pdf.d([])
  let no_root : Result[Destination, Error] = try? Destination::read(
    pdf_no_root,
    Name(PdfName("/Missing")),
  )
  assert_true(no_root is Err(_))
  let pdf_missing_dests = minimum_valid_pdf()
  match Destination::read(pdf_missing_dests, Name(PdfName("/Missing"))) {
    NamedDestination(PdfName("/Missing")) => ()
    _ => fail("expected NamedDestination with no /Dests")
  }
  let pdf_missing_entry = minimum_valid_pdf()
  let root = pdf_missing_entry.lookup_obj(pdf_missing_entry.root)
  let dests : @pdf.PdfObject = @pdf.d([("/Other", Null)])
  let root = root.add_entry("/Dests", dests)
  pdf_missing_entry.addobj_given_num((pdf_missing_entry.root, root))
  match Destination::read(pdf_missing_entry, Name(PdfName("/Missing"))) {
    NamedDestination(PdfName("/Missing")) => ()
    _ => fail("expected NamedDestination for missing entry")
  }
}

///|
test "read_destination string resolution" {
  let pdf = minimum_valid_pdf()
  match Destination::read(pdf, String("Shallow"), shallow=true) {
    StringDestination("Shallow") => ()
    _ => fail("expected shallow StringDestination")
  }
  match Destination::read(pdf, String("Missing")) {
    StringDestination("Missing") => ()
    _ => fail("expected StringDestination with no /Names")
  }
  let pdf_no_dests = minimum_valid_pdf()
  let root = pdf_no_dests.lookup_obj(pdf_no_dests.root)
  let root = root.add_entry("/Names", @pdf.d([]))
  pdf_no_dests.addobj_given_num((pdf_no_dests.root, root))
  match Destination::read(pdf_no_dests, String("Missing")) {
    StringDestination("Missing") => ()
    _ => fail("expected StringDestination with missing /Dests")
  }
  let pdf_with_tree = minimum_valid_pdf()
  let dest : @pdf.PdfObject = Array([Integer(0), Name(PdfName("/Fit"))])
  let dests : @pdf.PdfObject = @pdf.d([
    ("/Names", Array([String("Anchor"), dest])),
  ])
  let names : @pdf.PdfObject = @pdf.d([("/Dests", dests)])
  let root = pdf_with_tree.lookup_obj(pdf_with_tree.root)
  let root = root.add_entry("/Names", names)
  pdf_with_tree.addobj_given_num((pdf_with_tree.root, root))
  match Destination::read(pdf_with_tree, String("Anchor")) {
    Fit(OtherDocPageNumber(0)) => ()
    _ => fail("expected resolved StringDestination")
  }
  let pdf_no_match = minimum_valid_pdf()
  let dests : @pdf.PdfObject = @pdf.d([
    ("/Names", Array([String("Other"), dest])),
  ])
  let names : @pdf.PdfObject = @pdf.d([("/Dests", dests)])
  let root = pdf_no_match.lookup_obj(pdf_no_match.root)
  let root = root.add_entry("/Names", names)
  pdf_no_match.addobj_given_num((pdf_no_match.root, root))
  match Destination::read(pdf_no_match, String("Missing")) {
    StringDestination("Missing") => ()
    _ => fail("expected StringDestination for missing name")
  }
}

///|
test "destination to_pdf_object variants" {
  let action = Destination::Action(Name(PdfName("/GoTo")))
  match (action.to_pdf_object() : @pdf.PdfObject) {
    Name(PdfName("/GoTo")) => ()
    _ => fail("expected action to passthrough")
  }
  let named = Destination::NamedDestination(PdfName("/Dest"))
  match (named.to_pdf_object() : @pdf.PdfObject) {
    Name(PdfName("/Dest")) => ()
    _ => fail("expected named destination name")
  }
  let fit = Destination::Fit(PageObject(1))
  match (fit.to_pdf_object() : @pdf.PdfObject) {
    Array([Indirect(1), Name(PdfName("/Fit"))]) => ()
    _ => fail("expected Fit object")
  }
  let fith = Destination::FitH(OtherDocPageNumber(2), None)
  match (fith.to_pdf_object() : @pdf.PdfObject) {
    Array([Integer(2), Name(PdfName("/FitH")), Null]) => ()
    _ => fail("expected FitH object")
  }
  let fitv = Destination::FitV(PageObject(3), Some(12.0))
  match (fitv.to_pdf_object() : @pdf.PdfObject) {
    Array([Indirect(3), Name(PdfName("/FitV")), Real(12.0)]) => ()
    _ => fail("expected FitV object")
  }
  let fitb = Destination::FitB(PageObject(4))
  match (fitb.to_pdf_object() : @pdf.PdfObject) {
    Array([Indirect(4), Name(PdfName("/FitB"))]) => ()
    _ => fail("expected FitB object")
  }
  let fitbh = Destination::FitBH(OtherDocPageNumber(5), Some(1.5))
  match (fitbh.to_pdf_object() : @pdf.PdfObject) {
    Array([Integer(5), Name(PdfName("/FitBH")), Real(1.5)]) => ()
    _ => fail("expected FitBH object")
  }
  let fitbv = Destination::FitBV(OtherDocPageNumber(6), None)
  match (fitbv.to_pdf_object() : @pdf.PdfObject) {
    Array([Integer(6), Name(PdfName("/FitBV")), Null]) => ()
    _ => fail("expected FitBV object")
  }
}

///|
test "transform_destination variants" {
  let pdf = @pdf.Pdf::empty()
  let tr = @pdftransform.TransformMatrix::translate(5.0, -3.0)
  let fith = Destination::FitH(PageObject(1), Some(10.0)).transform(pdf, tr)
  match fith {
    FitH(PageObject(1), Some(top)) => assert_close(top, 7.0)
    _ => fail("expected FitH transform")
  }
  let fitbv = Destination::FitBV(PageObject(2), Some(10.0)).transform(pdf, tr)
  match fitbv {
    FitBV(PageObject(2), Some(left)) => assert_close(left, 15.0)
    _ => fail("expected FitBV transform")
  }
  let xyz_top = Destination::XYZ(PageObject(3), None, Some(10.0), None).transform(
    pdf, tr,
  )
  match xyz_top {
    XYZ(PageObject(3), None, Some(top), _) => assert_close(top, 7.0)
    _ => fail("expected XYZ top transform")
  }
  let xyz_left = Destination::XYZ(PageObject(4), Some(10.0), None, None).transform(
    pdf, tr,
  )
  match xyz_left {
    XYZ(PageObject(4), Some(left), None, _) => assert_close(left, 15.0)
    _ => fail("expected XYZ left transform")
  }
  let fitr = Destination::FitR(PageObject(5), 0.0, 0.0, 10.0, 20.0).transform(
    pdf, tr,
  )
  match fitr {
    FitR(PageObject(5), left, bottom, right, top) => {
      assert_close(left, 5.0)
      assert_close(top, 17.0)
      assert_close(right, 15.0)
      assert_close(bottom, -3.0)
    }
    _ => fail("expected FitR transform")
  }
  let action = Destination::Action(@pdf.d([("/S", Name(PdfName("/URI")))]))
  match action.transform(pdf, tr) {
    Action(dict) =>
      match pdf.lookup_direct("/S", dict) {
        Some(Name(PdfName("/URI"))) => ()
        _ => fail("expected unchanged action")
      }
    _ => fail("expected action destination")
  }
  let named = Destination::NamedDestination(PdfName("/Name"))
  match named.transform(pdf, tr) {
    NamedDestination(PdfName("/Name")) => ()
    _ => fail("expected NamedDestination passthrough")
  }
}

///|
test "read_destination resolves named dests in catalog" {
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(100.0),
    Real(100.0),
  ])
  let pdf = pdf_with_pages(1, rect)
  let refs = pdf.page_reference_numbers()
  let dest : @pdf.PdfObject = Array([Indirect(refs[0]), Name(PdfName("/Fit"))])
  let dests : @pdf.PdfObject = @pdf.d([("/Chapter1", dest)])
  let root_obj = pdf.lookup_obj(pdf.root)
  let updated_root = root_obj.add_entry("/Dests", dests)
  pdf.addobj_given_num((pdf.root, updated_root))
  let resolved = Destination::read(pdf, Name(PdfName("/Chapter1")))
  match resolved {
    Fit(PageObject(n)) => assert_eq(n, refs[0])
    _ => fail("expected Fit destination")
  }
}
