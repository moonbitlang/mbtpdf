///|
let ctx : @pdfpagelabels.PdfPageLabels = PdfPageLabels::new()

///|
test "pagelabeltext roman" {
  let labels = [
    PageLabel::{
      labelstyle: LowercaseRoman,
      labelprefix: None,
      startpage: 1,
      startvalue: 1,
    },
  ]
  let text = ctx.pagelabeltext_of_pagenumber(4, labels)
  assert_eq(text, "iv")
}

///|
test "pagelabel_of_pagenumber" {
  let labels = [
    PageLabel::{
      labelstyle: DecimalArabic,
      labelprefix: None,
      startpage: 1,
      startvalue: 1,
    },
  ]
  let label = ctx.pagelabel_of_pagenumber(5, labels)
  assert_eq(label.startpage, 5)
  assert_eq(label.startvalue, 5)
}

///|
fn make_pdf_with_pages(count : Int) -> @pdf.Pdf raise {
  let rect : @pdf.PdfObject = PdfArray([
    Real(0.0),
    Real(0.0),
    Real(100.0),
    Real(100.0),
  ])
  let pdf = @pdf.Pdf::empty()
  let pages_root_num = pdf.addobj(
    Dictionary([
      ("/Type", Name(PdfName(b"/Pages"))),
      ("/Kids", PdfArray([])),
      ("/Count", Integer(count)),
    ]),
  )
  let kids : Array[@pdf.PdfObject] = []
  for _ in 0..<count {
    let page_num = pdf.addobj(
      Dictionary([
        ("/Type", Name(PdfName(b"/Page"))),
        ("/Parent", Indirect(pages_root_num)),
        ("/MediaBox", rect),
      ]),
    )
    kids.push(Indirect(page_num))
  }
  pdf.addobj_given_num(
    (
      pages_root_num,
      Dictionary([
        ("/Type", Name(PdfName(b"/Pages"))),
        ("/Kids", PdfArray(kids)),
        ("/Count", Integer(count)),
      ]),
    ),
  )
  let catalog_num = pdf.addobj(
    Dictionary([
      ("/Type", Name(PdfName(b"/Catalog"))),
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
test "coalesce labels" {
  let labels = [
    PageLabel::{
      labelstyle: DecimalArabic,
      labelprefix: None,
      startpage: 1,
      startvalue: 1,
    },
    {
      labelstyle: DecimalArabic,
      labelprefix: None,
      startpage: 3,
      startvalue: 3,
    },
    {
      labelstyle: DecimalArabic,
      labelprefix: Some("A"),
      startpage: 5,
      startvalue: 5,
    },
  ]
  let merged = ctx.coalesce(labels)
  assert_eq(merged.length(), 2)
  assert_eq(merged[0].startpage, 1)
  match merged[1].labelprefix {
    Some("A") => ()
    _ => fail("expected prefix A")
  }
}

///|
test "complete labels" {
  let labels = [
    PageLabel::{
      labelstyle: DecimalArabic,
      labelprefix: None,
      startpage: 3,
      startvalue: 1,
    },
  ]
  let completed = ctx.complete(labels)
  assert_eq(completed.length(), 2)
  assert_eq(completed[0].startpage, 1)
}

///|
test "string_of_labelstyle and pagelabel string" {
  assert_eq(LabelStyle::UppercaseLetters.to_string(), "UppercaseLetters")
  let label = PageLabel::{
    labelstyle: LowercaseRoman,
    labelprefix: Some("P"),
    startpage: 2,
    startvalue: 5,
  }
  let text = label.to_string()
  assert_true(text.contains("LowercaseRoman"))
  assert_true(text.contains("labelprefix: P"))
}

///|
test "pagelabeltext with prefix and letters" {
  let labels = [
    PageLabel::{
      labelstyle: UppercaseLetters,
      labelprefix: Some("Sec-"),
      startpage: 1,
      startvalue: 1,
    },
  ]
  assert_eq(ctx.pagelabeltext_of_pagenumber(1, labels), "Sec-A")
  assert_eq(ctx.pagelabeltext_of_pagenumber(27, labels), "Sec-AA")
}

///|
test "add_label inserts replica" {
  let labels = [
    PageLabel::{
      labelstyle: DecimalArabic,
      labelprefix: None,
      startpage: 1,
      startvalue: 1,
    },
  ]
  let inserted = ctx.add_label(
    6,
    labels,
    {
      labelstyle: UppercaseRoman,
      labelprefix: None,
      startpage: 3,
      startvalue: 1,
    },
    4,
  )
  assert_eq(inserted.length(), 3)
  assert_eq(inserted[1].startpage, 3)
  assert_eq(inserted[2].startpage, 5)
  assert_eq(inserted[2].startvalue, 5)
}

///|
test "merge_pagelabels combines ranges" {
  let pdf1 = make_pdf_with_pages(2)
  let pdf2 = make_pdf_with_pages(1)
  let labels1 = [
    PageLabel::{
      labelstyle: DecimalArabic,
      labelprefix: Some("A"),
      startpage: 1,
      startvalue: 1,
    },
  ]
  let labels2 = [
    PageLabel::{
      labelstyle: DecimalArabic,
      labelprefix: Some("B"),
      startpage: 1,
      startvalue: 1,
    },
  ]
  @pdfpagelabels.PageLabel::write_all(labels1, pdf1)
  @pdfpagelabels.PageLabel::write_all(labels2, pdf2)
  let merged = ctx.merge_pagelabels([pdf1, pdf2], [[1, 2], [1]])
  assert_eq(merged.length(), 2)
  match merged[0].labelprefix {
    Some("A") => ()
    _ => fail("expected prefix A")
  }
  assert_eq(merged[0].startpage, 1)
  match merged[1].labelprefix {
    Some("B") => ()
    _ => fail("expected prefix B")
  }
  assert_eq(merged[1].startpage, 3)
}

///|
test "write/read pagelabels roundtrip" {
  let pdf = make_pdf_with_pages(3)
  let labels = [
    PageLabel::{
      labelstyle: DecimalArabic,
      labelprefix: Some("A"),
      startpage: 1,
      startvalue: 1,
    },
    {
      labelstyle: LowercaseRoman,
      labelprefix: None,
      startpage: 3,
      startvalue: 1,
    },
  ]
  @pdfpagelabels.PageLabel::write_all(labels, pdf)
  let read_back = @pdfpagelabels.PageLabel::read_all(pdf)
  assert_eq(read_back.length(), 2)
  match read_back[0].labelprefix {
    Some("A") => ()
    _ => fail("expected prefix A")
  }
  assert_eq(read_back[1].startpage, 3)
  @pdfpagelabels.PageLabel::remove_all(pdf)
  assert_eq(@pdfpagelabels.PageLabel::read_all(pdf).length(), 0)
}

///|
test "string_of_labelstyle covers all styles" {
  assert_eq(LabelStyle::DecimalArabic.to_string(), "DecimalArabic")
  assert_eq(LabelStyle::UppercaseRoman.to_string(), "UppercaseRoman")
  assert_eq(LabelStyle::LowercaseRoman.to_string(), "LowercaseRoman")
  assert_eq(LabelStyle::UppercaseLetters.to_string(), "UppercaseLetters")
  assert_eq(LabelStyle::LowercaseLetters.to_string(), "LowercaseLetters")
  assert_eq(LabelStyle::NoLabelPrefixOnly.to_string(), "NoLabelPrefixOnly")
}

///|
fn set_page_labels(pdf : @pdf.Pdf, nums : Array[@pdf.PdfObject]) -> Unit raise {
  let rootnum = pdf.root
  let root = pdf.lookup_obj(rootnum)
  let labels : @pdf.PdfObject = Dictionary([("/Nums", PdfArray(nums))])
  let updated = root.add_entry("/PageLabels", labels)
  pdf.addobj_given_num((rootnum, updated))
  pdf.trailerdict = pdf.trailerdict.add_entry("/Root", Indirect(rootnum))
}

///|
test "read handles label styles and bad startpage" {
  let pdf = make_pdf_with_pages(1)
  let nums : Array[@pdf.PdfObject] = [
    Name(PdfName(b"/Bad")),
    Dictionary([("/S", Name(PdfName(b"/R")))]),
    Integer(0),
    Dictionary([("/S", Name(PdfName(b"/r")))]),
    Integer(1),
    Dictionary([("/S", Name(PdfName(b"/A")))]),
    Integer(2),
    Dictionary([("/S", Name(PdfName(b"/a")))]),
    Integer(3),
    Dictionary([("/S", Name(PdfName(b"/D")))]),
    Integer(4),
    Dictionary([("/P", PdfString("P"))]),
  ]
  set_page_labels(pdf, nums)
  let labels = @pdfe.with_logger(_ => (), fn() {
    @pdfpagelabels.PageLabel::read_all(pdf)
  })
  assert_eq(labels.length(), 6)
  assert_eq(labels[0].startpage, 1)
  match labels[0].labelstyle {
    UppercaseRoman => ()
    _ => fail("expected UppercaseRoman")
  }
  match labels[1].labelstyle {
    LowercaseRoman => ()
    _ => fail("expected LowercaseRoman")
  }
  match labels[2].labelstyle {
    UppercaseLetters => ()
    _ => fail("expected UppercaseLetters")
  }
  match labels[3].labelstyle {
    LowercaseLetters => ()
    _ => fail("expected LowercaseLetters")
  }
  match labels[4].labelstyle {
    DecimalArabic => ()
    _ => fail("expected DecimalArabic")
  }
  match labels[5].labelstyle {
    NoLabelPrefixOnly => ()
    _ => fail("expected NoLabelPrefixOnly")
  }
}

///|
test "pagelabeltext and pagelabel_of_pagenumber error on missing labels" {
  let labels : Array[PageLabel] = []
  let text_res : Result[String, Error] = try? ctx.pagelabeltext_of_pagenumber(
    1, labels,
  )
  assert_true(text_res is Err(_))
  let label_res : Result[PageLabel, Error] = try? ctx.pagelabel_of_pagenumber(
    1, labels,
  )
  assert_true(label_res is Err(_))
}

///|
test "pagelabeltext handles empty roman and letter values" {
  let labels = [
    PageLabel::{
      labelstyle: UppercaseRoman,
      labelprefix: Some("R-"),
      startpage: 5,
      startvalue: 1,
    },
  ]
  assert_eq(ctx.pagelabeltext_of_pagenumber(1, labels), "R-")
  let letter_labels = [
    PageLabel::{
      labelstyle: LowercaseLetters,
      labelprefix: Some("L-"),
      startpage: 4,
      startvalue: 1,
    },
  ]
  assert_eq(ctx.pagelabeltext_of_pagenumber(1, letter_labels), "L-")
}

///|
test "pagelabeltext supports NoLabelPrefixOnly" {
  let labels = [
    PageLabel::{
      labelstyle: NoLabelPrefixOnly,
      labelprefix: Some("P-"),
      startpage: 1,
      startvalue: 1,
    },
  ]
  assert_eq(ctx.pagelabeltext_of_pagenumber(1, labels), "P-")
}

///|
test "coalesce covers all labelstyle equality branches" {
  let labels = [
    PageLabel::{
      labelstyle: DecimalArabic,
      labelprefix: None,
      startpage: 1,
      startvalue: 1,
    },
    {
      labelstyle: DecimalArabic,
      labelprefix: Some("D"),
      startpage: 2,
      startvalue: 2,
    },
    {
      labelstyle: UppercaseRoman,
      labelprefix: None,
      startpage: 3,
      startvalue: 3,
    },
    {
      labelstyle: UppercaseRoman,
      labelprefix: None,
      startpage: 4,
      startvalue: 4,
    },
    {
      labelstyle: LowercaseRoman,
      labelprefix: None,
      startpage: 5,
      startvalue: 5,
    },
    {
      labelstyle: LowercaseRoman,
      labelprefix: None,
      startpage: 6,
      startvalue: 6,
    },
    {
      labelstyle: UppercaseLetters,
      labelprefix: None,
      startpage: 7,
      startvalue: 7,
    },
    {
      labelstyle: UppercaseLetters,
      labelprefix: None,
      startpage: 8,
      startvalue: 8,
    },
    {
      labelstyle: LowercaseLetters,
      labelprefix: None,
      startpage: 9,
      startvalue: 9,
    },
    {
      labelstyle: LowercaseLetters,
      labelprefix: None,
      startpage: 10,
      startvalue: 10,
    },
    {
      labelstyle: NoLabelPrefixOnly,
      labelprefix: Some("N"),
      startpage: 11,
      startvalue: 11,
    },
    {
      labelstyle: NoLabelPrefixOnly,
      labelprefix: Some("N"),
      startpage: 12,
      startvalue: 12,
    },
  ]
  let merged = ctx.coalesce(labels)
  assert_eq(merged.length(), 7)
  match merged[2].labelstyle {
    UppercaseRoman => ()
    _ => fail("expected UppercaseRoman")
  }
  match merged[3].labelstyle {
    LowercaseRoman => ()
    _ => fail("expected LowercaseRoman")
  }
}

///|
test "add_label replica branches" {
  let base = [
    PageLabel::{
      labelstyle: DecimalArabic,
      labelprefix: None,
      startpage: 1,
      startvalue: 1,
    },
  ]
  let no_replica = ctx.add_label(
    3,
    base,
    {
      labelstyle: UppercaseRoman,
      labelprefix: None,
      startpage: 2,
      startvalue: 1,
    },
    3,
  )
  assert_eq(no_replica.length(), 2)
  let with_after = ctx.add_label(
    10,
    [
      {
        labelstyle: DecimalArabic,
        labelprefix: None,
        startpage: 1,
        startvalue: 1,
      },
      {
        labelstyle: DecimalArabic,
        labelprefix: None,
        startpage: 5,
        startvalue: 5,
      },
    ],
    {
      labelstyle: UppercaseRoman,
      labelprefix: None,
      startpage: 2,
      startvalue: 1,
    },
    4,
  )
  assert_eq(with_after.length(), 3)
  let empty_before = ctx.add_label(
    5,
    [
      {
        labelstyle: DecimalArabic,
        labelprefix: None,
        startpage: 5,
        startvalue: 5,
      },
    ],
    {
      labelstyle: UppercaseRoman,
      labelprefix: None,
      startpage: 1,
      startvalue: 1,
    },
    2,
  )
  assert_eq(empty_before.length(), 2)
}

///|
test "coalesce handles single label" {
  let labels = [
    PageLabel::{
      labelstyle: DecimalArabic,
      labelprefix: None,
      startpage: 1,
      startvalue: 1,
    },
  ]
  let merged = ctx.coalesce(labels)
  assert_eq(merged.length(), 1)
}

///|
test "write handles all labelstyle variants" {
  let pdf = make_pdf_with_pages(4)
  let labels = [
    PageLabel::{
      labelstyle: NoLabelPrefixOnly,
      labelprefix: None,
      startpage: 1,
      startvalue: 1,
    },
    {
      labelstyle: UppercaseRoman,
      labelprefix: None,
      startpage: 2,
      startvalue: 1,
    },
    {
      labelstyle: LowercaseLetters,
      labelprefix: Some("P"),
      startpage: 3,
      startvalue: 2,
    },
    {
      labelstyle: UppercaseLetters,
      labelprefix: Some("S-"),
      startpage: 4,
      startvalue: 1,
    },
  ]
  @pdfpagelabels.PageLabel::write_all(labels, pdf)
  let read_back = @pdfpagelabels.PageLabel::read_all(pdf)
  assert_eq(read_back.length(), 4)
  match read_back[0].labelstyle {
    NoLabelPrefixOnly => ()
    _ => fail("expected NoLabelPrefixOnly")
  }
  match read_back[1].labelstyle {
    UppercaseRoman => ()
    _ => fail("expected UppercaseRoman")
  }
  match read_back[2].labelstyle {
    LowercaseLetters => ()
    _ => fail("expected LowercaseLetters")
  }
  match read_back[3].labelstyle {
    UppercaseLetters => ()
    _ => fail("expected UppercaseLetters")
  }
}

///|
test "pagelabel to_string prints None prefix" {
  let label = PageLabel::{
    labelstyle: DecimalArabic,
    labelprefix: None,
    startpage: 1,
    startvalue: 1,
  }
  let s = label.to_string()
  assert_true(s.contains("labelprefix: None"))
}
