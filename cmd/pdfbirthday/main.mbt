///|
type PdfObject = @pdf.PdfObject

///|
type Op = @pdfops.Op

///|
fn font_type1(base_font : String) -> PdfObject {
  Dictionary([
    ("/Type", Name(PdfName(b"/Font"))),
    ("/Subtype", Name(PdfName(b"/Type1"))),
    ("/BaseFont", Name(@pdf.PdfName::of_string("/" + base_font))),
  ])
}

///|
fn resources() -> PdfObject {
  Dictionary([
    (
      "/Font",
      Dictionary([
        ("/F0", font_type1("Helvetica-Bold")),
        ("/F1", font_type1("Helvetica")),
        ("/F2", font_type1("Courier")),
      ]),
    ),
  ])
}

///|
fn paper() -> @pdfpaper.Paper {
  @pdfpaper.usletter.landscape()
}

///|
fn mediabox() -> PdfObject {
  paper().rectangle()
}

///|
fn w() -> Double {
  paper().unit().to_points(paper().width())
}

///|
fn h() -> Double {
  paper().unit().to_points(paper().height())
}

///|
fn ops_text(
  x : Double,
  y : Double,
  font : String,
  size : Double,
  text : String,
  rgb : (Double, Double, Double),
) -> Array[Op] {
  let (r, g, b) = rgb
  let tr = @pdftransform.Transform::new([Translate(x, y)]).to_matrix()
  [Opq, Oprg(r, g, b), OpBT, OpTf(font, size), OpTm(tr), OpTj(text), OpET, OpQ]
}

///|
fn ops_fill_rect(
  x : Double,
  y : Double,
  ww : Double,
  hh : Double,
  rgb : (Double, Double, Double),
) -> Array[Op] {
  let (r, g, b) = rgb
  [Opq, Oprg(r, g, b), Opre(x, y, ww, hh), Opf, OpQ]
}

///|
fn ops_stroke_rect(
  x : Double,
  y : Double,
  ww : Double,
  hh : Double,
  rgb : (Double, Double, Double),
  width : Double,
) -> Array[Op] {
  let (r, g, b) = rgb
  [Opq, Opw(width), OpRG(r, g, b), Opre(x, y, ww, hh), OpS, OpQ]
}

///|
fn ops_poly_path(
  points : Array[(Double, Double)],
  close? : Bool = true,
) -> Array[Op] {
  match points {
    [] => []
    [(x0, y0), .. rest] => {
      let ops : Array[Op] = Array::new(capacity=points.length() + 2)
      ops.push(Opm(x0, y0))
      for p in rest {
        let (x, y) = p
        ops.push(Opl(x, y))
      }
      if close {
        ops.push(Oph)
      }
      ops
    }
  }
}

///|
fn ops_fill_polygon(
  points : Array[(Double, Double)],
  rgb : (Double, Double, Double),
) -> Array[Op] {
  let (r, g, b) = rgb
  [Opq, Oprg(r, g, b)] + ops_poly_path(points) + [Opf, OpQ]
}

///|
fn ops_stroke_polyline(
  points : Array[(Double, Double)],
  rgb : (Double, Double, Double),
  width : Double,
) -> Array[Op] {
  let (r, g, b) = rgb
  [Opq, Opw(width), OpRG(r, g, b)] +
  ops_poly_path(points, close=false) +
  [OpS, OpQ]
}

///|
fn circle_points(
  cx : Double,
  cy : Double,
  r : Double,
  n : Int,
) -> Array[(Double, Double)] {
  let out = Array::new(capacity=n)
  let two_pi = 8.0 * @math.atan(1.0)
  for i in 0..<n {
    let t = two_pi * (i.to_double() / n.to_double())
    out.push((cx + r * @math.cos(t), cy + r * @math.sin(t)))
  }
  out
}

///|
fn ops_balloon(
  cx : Double,
  cy : Double,
  r : Double,
  rgb : (Double, Double, Double),
) -> Array[Op] {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_polygon(circle_points(cx, cy, r, 40), rgb)[:])
  ops.append(
    ops_stroke_polyline(
      circle_points(cx, cy, r, 40) + [circle_points(cx, cy, r, 40)[0]],
      (0.2, 0.2, 0.2),
      1.2,
    )[:],
  )
  // Knot
  ops.append(
    ops_fill_polygon(
      [(cx - 6.0, cy - r + 2.0), (cx + 6.0, cy - r + 2.0), (cx, cy - r - 10.0)],
      rgb,
    )[:],
  )
  // String
  ops.append(
    ops_stroke_polyline(
      [
        (cx, cy - r - 10.0),
        (cx - 10.0, cy - r - 80.0),
        (cx + 14.0, cy - r - 160.0),
      ],
      (0.2, 0.2, 0.2),
      1.0,
    )[:],
  )
  ops
}

///|
fn ops_button(
  x : Double,
  y : Double,
  ww : Double,
  hh : Double,
  label : String,
  accent : (Double, Double, Double),
) -> (Array[Op], (Double, Double, Double, Double)) {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(x, y, ww, hh, (1.0, 1.0, 1.0))[:])
  ops.append(ops_stroke_rect(x, y, ww, hh, accent, 2.0)[:])
  ops.append(ops_fill_rect(x, y + hh - 6.0, ww, 6.0, accent)[:])
  ops.append(
    ops_text(x + 14.0, y + 16.0, "/F0", 16.0, label, (0.12, 0.14, 0.18))[:],
  )
  (ops, (x, y, x + ww, y + hh))
}

///|
fn page_of_ops(ops : Array[Op]) -> @pdfpage.Page raise {
  let stream = @pdfops.Op::stream_of_ops(ops)
  Page(
    content=[stream],
    mediabox=mediabox(),
    resources=resources(),
    rotate=Rotate0,
    rest=Dictionary([]),
  )
}

///|
fn set_catalog_entry(
  pdf : @pdf.Pdf,
  key : String,
  value : PdfObject,
) -> Unit raise {
  let rootnum = pdf.root
  let root = pdf.lookup_obj(rootnum)
  let updated_root = root.add_entry(key, value)
  pdf.addobj_given_num((rootnum, updated_root))
  pdf.trailerdict = pdf.trailerdict.add_entry("/Root", Indirect(rootnum))
}

///|
fn add_layers(pdf : @pdf.Pdf) -> (Int, Int) raise {
  let secret : PdfObject = Dictionary([
    ("/Type", Name(PdfName(b"/OCG"))),
    ("/Name", PdfString("SECRET")),
  ])
  let party : PdfObject = Dictionary([
    ("/Type", Name(PdfName(b"/OCG"))),
    ("/Name", PdfString("PARTY MODE")),
  ])
  let secret_num = pdf.addobj(secret)
  let party_num = pdf.addobj(party)
  let default_dict : PdfObject = Dictionary([
    ("/BaseState", Name(PdfName(b"/ON"))),
    ("/Intent", Name(PdfName(b"/View"))),
    ("/Name", PdfString("Default")),
    ("/OFF", PdfArray([Indirect(secret_num)])),
    ("/ON", PdfArray([Indirect(party_num)])),
  ])
  let ocprops : PdfObject = Dictionary([
    ("/OCGs", PdfArray([Indirect(secret_num), Indirect(party_num)])),
    ("/D", default_dict),
  ])
  let ocprops_num = pdf.addobj(ocprops)
  set_catalog_entry(pdf, "/OCProperties", Indirect(ocprops_num))
  (secret_num, party_num)
}

///|
fn add_layer_properties_to_pages(
  pdf : @pdf.Pdf,
  secret_num : Int,
  party_num : Int,
) -> @pdf.Pdf raise {
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  for i in 0..<pages.length() {
    let page = pages[i]
    let props : PdfObject = Dictionary([
      ("/SECRET", Indirect(secret_num)),
      ("/PARTY", Indirect(party_num)),
    ])
    let resources = page.resources.add_entry("/Properties", props)
    pages[i] = Page(
      content=page.content,
      mediabox=page.mediabox,
      resources~,
      rotate=page.rotate,
      rest=page.rest,
    )
  }
  @pdfpage.PdfPageDoc::new(pdf).change_pages(true, pages)
}

///|
fn goto_action(refnum : Int) -> PdfObject {
  let dest = @pdfdest.Destination::Fit(PageObject(refnum)).to_pdf_object()
  Dictionary([("/S", Name(PdfName(b"/GoTo"))), ("/D", dest)])
}

///|
fn add_link(
  pdf : @pdf.Pdf,
  page : @pdfpage.Page,
  rect : (Double, Double, Double, Double),
  action : PdfObject,
) -> @pdfpage.Page raise {
  let annot : @pdfannot.Annotation = {
    subtype: Link,
    annot_contents: None,
    subject: None,
    rectangle: rect,
    border: @pdfannot.Border::new(0.0),
    colour: None,
    annotrest: Dictionary([("/A", action)]),
  }
  @pdfannot.PdfAnnot::new(pdf).add_annotation(page, annot)
}

///|
fn add_bookmarks(pdf : @pdf.Pdf, refs : Array[Int]) -> @pdf.Pdf raise {
  let marks : Array[@pdfmarks.Bookmark] = [
    {
      level: 0,
      text: "Cover",
      target: Fit(PageObject(refs[0])),
      isopen: true,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "Inside",
      target: Fit(PageObject(refs[1])),
      isopen: true,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ]
  @pdfmarks.PdfMarks::new(pdf).add_bookmarks(marks)
}

///|
fn cover_ops(name : String) -> (Array[Op], (Double, Double, Double, Double)) {
  let ops : Array[Op] = Array::new()
  let accent = (0.92, 0.33, 0.36)
  ops.append(ops_fill_rect(0.0, 0.0, w(), h(), (0.98, 0.98, 0.99))[:])
  ops.append(ops_fill_rect(0.0, h() - 110.0, w(), 110.0, (0.18, 0.48, 0.86))[:])
  ops.append(
    ops_text(72.0, h() - 70.0, "/F0", 52.0, "Happy Birthday!", (1.0, 1.0, 1.0))[:],
  )
  ops.append(
    ops_text(74.0, h() - 100.0, "/F1", 18.0, "For " + name, (0.92, 0.94, 0.98))[:],
  )

  // Balloons
  ops.append(ops_balloon(w() - 170.0, 340.0, 58.0, (0.92, 0.33, 0.36))[:])
  ops.append(ops_balloon(w() - 280.0, 360.0, 50.0, (0.18, 0.48, 0.86))[:])
  ops.append(ops_balloon(w() - 230.0, 280.0, 44.0, (0.22, 0.7, 0.5))[:])
  ops.append(ops_balloon(w() - 350.0, 300.0, 40.0, (0.92, 0.75, 0.2))[:])
  ops.append(
    ops_text(
      72.0,
      190.0,
      "/F1",
      18.0,
      "This card has a secret. (Open Layers → toggle SECRET.)",
      (0.12, 0.14, 0.18),
    )[:],
  )
  let (btn, rect) = ops_button(72.0, 70.0, 300.0, 62.0, "Open the card", accent)
  ops.append(btn[:])
  (ops, rect)
}

///|
fn inside_ops(name : String) -> (Array[Op], (Double, Double, Double, Double)) {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, w(), h(), (1.0, 1.0, 1.0))[:])
  ops.append(ops_fill_rect(0.0, 0.0, w(), 64.0, (0.12, 0.14, 0.18))[:])
  ops.append(
    ops_text(
      72.0,
      26.0,
      "/F2",
      12.0,
      "Tip: toggle PARTY MODE / SECRET in the Layers panel.",
      (0.85, 0.88, 0.92),
    )[:],
  )
  ops.append(
    ops_text(72.0, h() - 110.0, "/F0", 44.0, "Make a wish,", (0.12, 0.14, 0.18))[:],
  )
  ops.append(
    ops_text(72.0, h() - 150.0, "/F0", 44.0, name + "!", (0.18, 0.48, 0.86))[:],
  )
  ops.append(
    ops_text(
      72.0,
      h() - 210.0,
      "/F1",
      18.0,
      "May your day be full of small surprises and big laughs.",
      (0.45, 0.48, 0.52),
    )[:],
  )
  ops.append(
    ops_text(
      72.0,
      h() - 240.0,
      "/F1",
      18.0,
      "— from your friendly PDF robot",
      (0.45, 0.48, 0.52),
    )[:],
  )

  // Party mode: confetti overlay
  ops.push(OpBDC("/OC", Name(PdfName(b"/PARTY"))))
  let colors : Array[(Double, Double, Double)] = [
    (0.92, 0.33, 0.36),
    (0.18, 0.48, 0.86),
    (0.22, 0.7, 0.5),
    (0.92, 0.75, 0.2),
    (0.7, 0.45, 0.9),
  ]
  for i in 0..<160 {
    let x = 40.0 + i.to_double() * 37.0 % (w() - 80.0)
    let y = 90.0 + i.to_double() * 71.0 % (h() - 180.0)
    let c = colors[i % colors.length()]
    ops.append(ops_fill_rect(x, y, 10.0, 4.0, c)[:])
  }
  ops.push(OpEMC)

  // Secret message layer
  ops.push(OpBDC("/OC", Name(PdfName(b"/SECRET"))))
  ops.append(ops_fill_rect(72.0, 90.0, w() - 144.0, 90.0, (1.0, 1.0, 0.9))[:])
  ops.append(
    ops_stroke_rect(72.0, 90.0, w() - 144.0, 90.0, (0.88, 0.84, 0.4), 2.0)[:],
  )
  ops.append(
    ops_text(92.0, 145.0, "/F0", 22.0, "SECRET:", (0.2, 0.18, 0.05))[:],
  )
  ops.append(
    ops_text(
      92.0,
      118.0,
      "/F1",
      18.0,
      "You are officially awesome. Keep being you.",
      (0.2, 0.18, 0.05),
    )[:],
  )
  ops.push(OpEMC)
  let (btn, rect) = ops_button(
    w() - 260.0,
    70.0,
    188.0,
    50.0,
    "Back",
    (0.12, 0.14, 0.18),
  )
  ops.append(btn[:])
  (ops, rect)
}

///|
pub async fn run(
  out_file? : String = "birthday.pdf",
  name? : String = "Friend",
  quiet? : Bool = false,
) -> Unit {
  try {
    let (cover, cover_rect) = cover_ops(name)
    let (inside, back_rect) = inside_ops(name)
    let pages : Array[@pdfpage.Page] = [page_of_ops(cover), page_of_ops(inside)]
    let (pdf, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree(
      pages,
    )
    let pdf = @pdfpage.PdfPageDoc::new(pdf).add_root(pageroot, [])
    let (secret_num, party_num) = add_layers(pdf)
    let pdf = add_layer_properties_to_pages(pdf, secret_num, party_num)
    let refs = pdf.page_reference_numbers()
    let pdf = add_bookmarks(pdf, refs)
    let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
    let out_pages = pages
    out_pages[0] = add_link(pdf, out_pages[0], cover_rect, goto_action(refs[1]))
    out_pages[1] = add_link(pdf, out_pages[1], back_rect, goto_action(refs[0]))
    let pdf = @pdfpage.PdfPageDoc::new(pdf).change_pages(true, out_pages)
    @pdfwritefs.PdfWriteFs::new().pdf_to_file(pdf, out_file)
  } catch {
    err =>
      if !quiet {
        println("Failed to produce output.")
        println(err)
      }
  }
}

///|
async fn main {
  let args = @env.args()
  match args {
    [_, out] => run(out_file=out)
    [_, out, name] => run(out_file=out, name~)
    _ => run()
  }
}
