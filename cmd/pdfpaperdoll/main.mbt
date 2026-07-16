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
  @pdfpaper.usletter
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
fn ops_fill_polygon(
  points : Array[(Double, Double)],
  rgb : (Double, Double, Double),
) -> Array[Op] {
  let (r, g, b) = rgb
  [Opq, Oprg(r, g, b)] + ops_poly_path(points, close=true) + [Opf, OpQ]
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
fn add_layers(pdf : @pdf.Pdf) -> (Int, Int, Int, Int, Int) raise {
  let dress : PdfObject = Dictionary([
    ("/Type", Name(PdfName(b"/OCG"))),
    ("/Name", PdfString("DRESS")),
  ])
  let space : PdfObject = Dictionary([
    ("/Type", Name(PdfName(b"/OCG"))),
    ("/Name", PdfString("SPACE SUIT")),
  ])
  let hero : PdfObject = Dictionary([
    ("/Type", Name(PdfName(b"/OCG"))),
    ("/Name", PdfString("HERO CAPE")),
  ])
  let hat : PdfObject = Dictionary([
    ("/Type", Name(PdfName(b"/OCG"))),
    ("/Name", PdfString("HAT")),
  ])
  let sparkles : PdfObject = Dictionary([
    ("/Type", Name(PdfName(b"/OCG"))),
    ("/Name", PdfString("SPARKLES")),
  ])
  let dress_num = pdf.addobj(dress)
  let space_num = pdf.addobj(space)
  let hero_num = pdf.addobj(hero)
  let hat_num = pdf.addobj(hat)
  let sparkles_num = pdf.addobj(sparkles)
  let default_dict : PdfObject = Dictionary([
    ("/BaseState", Name(PdfName(b"/ON"))),
    ("/Intent", Name(PdfName(b"/View"))),
    ("/Name", PdfString("Default")),
    (
      "/OFF",
      PdfArray([
        Indirect(dress_num),
        Indirect(space_num),
        Indirect(hero_num),
        Indirect(hat_num),
        Indirect(sparkles_num),
      ]),
    ),
  ])
  let ocprops : PdfObject = Dictionary([
    (
      "/OCGs",
      PdfArray([
        Indirect(dress_num),
        Indirect(space_num),
        Indirect(hero_num),
        Indirect(hat_num),
        Indirect(sparkles_num),
      ]),
    ),
    ("/D", default_dict),
  ])
  let ocprops_num = pdf.addobj(ocprops)
  set_catalog_entry(pdf, "/OCProperties", Indirect(ocprops_num))
  (dress_num, space_num, hero_num, hat_num, sparkles_num)
}

///|
fn add_layer_properties_to_pages(
  pdf : @pdf.Pdf,
  dress_num : Int,
  space_num : Int,
  hero_num : Int,
  hat_num : Int,
  sparkles_num : Int,
) -> @pdf.Pdf raise {
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  for i in 0..<pages.length() {
    let page = pages[i]
    let props : PdfObject = Dictionary([
      ("/DRESS", Indirect(dress_num)),
      ("/SPACE", Indirect(space_num)),
      ("/HERO", Indirect(hero_num)),
      ("/HAT", Indirect(hat_num)),
      ("/SPARKLES", Indirect(sparkles_num)),
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
  let titles : Array[String] = [
    "Cover", "Mix and Match", "Dress (poster)", "Space Suit (poster)", "Hero (poster)",
  ]
  let marks : Array[@pdfmarks.Bookmark] = Array::new()
  for i in 0..<titles.length() {
    marks.push({
      level: 0,
      text: titles[i],
      target: Fit(PageObject(refs[i])),
      isopen: true,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    })
  }
  @pdfmarks.PdfMarks::new(pdf).add_bookmarks(marks)
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
  ops.append(ops_fill_rect(x, y + hh - 7.0, ww, 7.0, accent)[:])
  ops.append(
    ops_text(x + 14.0, y + 16.0, "/F0", 14.0, label, (0.12, 0.14, 0.18))[:],
  )
  (ops, (x, y, x + ww, y + hh))
}

///|
fn home_rect() -> (Double, Double, Double, Double) {
  (w() - 160.0, h() - 70.0, w() - 60.0, h() - 30.0)
}

///|
fn ops_home_badge() -> Array[Op] {
  let (x0, y0, x1, y1) = home_rect()
  let ww = x1 - x0
  let hh = y1 - y0
  let accent = (0.18, 0.48, 0.86)
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(x0, y0, ww, hh, (1.0, 1.0, 1.0))[:])
  ops.append(ops_stroke_rect(x0, y0, ww, hh, accent, 2.0)[:])
  ops.append(ops_fill_rect(x0, y0 + hh - 6.0, ww, 6.0, accent)[:])
  ops.append(
    ops_text(x0 + 24.0, y0 + 14.0, "/F0", 14.0, "HOME", (0.12, 0.14, 0.18))[:],
  )
  ops
}

///|
fn doll_origin() -> (Double, Double) {
  (w() * 0.47, 150.0)
}

///|
fn ops_doll_outline() -> Array[Op] {
  let ops : Array[Op] = Array::new()
  let (cx, base_y) = doll_origin()

  // Head
  let head = circle_points(cx, base_y + 500.0, 46.0, 70)
  ops.append(ops_stroke_polyline(head + [head[0]], (0.1, 0.1, 0.1), 4.5)[:])

  // Torso (rounded-ish polygon)
  let torso : Array[(Double, Double)] = [
    (cx - 55.0, base_y + 440.0),
    (cx + 55.0, base_y + 440.0),
    (cx + 70.0, base_y + 340.0),
    (cx + 46.0, base_y + 250.0),
    (cx - 46.0, base_y + 250.0),
    (cx - 70.0, base_y + 340.0),
  ]
  ops.append(ops_stroke_polyline(torso + [torso[0]], (0.1, 0.1, 0.1), 4.5)[:])

  // Arms
  let arm_l : Array[(Double, Double)] = [
    (cx - 70.0, base_y + 400.0),
    (cx - 150.0, base_y + 360.0),
    (cx - 164.0, base_y + 310.0),
    (cx - 132.0, base_y + 282.0),
    (cx - 70.0, base_y + 320.0),
  ]
  let arm_r : Array[(Double, Double)] = [
    (cx + 70.0, base_y + 400.0),
    (cx + 150.0, base_y + 360.0),
    (cx + 164.0, base_y + 310.0),
    (cx + 132.0, base_y + 282.0),
    (cx + 70.0, base_y + 320.0),
  ]
  ops.append(ops_stroke_polyline(arm_l + [arm_l[0]], (0.1, 0.1, 0.1), 4.5)[:])
  ops.append(ops_stroke_polyline(arm_r + [arm_r[0]], (0.1, 0.1, 0.1), 4.5)[:])

  // Legs
  let leg_l : Array[(Double, Double)] = [
    (cx - 30.0, base_y + 250.0),
    (cx - 54.0, base_y + 130.0),
    (cx - 34.0, base_y + 30.0),
    (cx - 10.0, base_y + 30.0),
    (cx - 6.0, base_y + 130.0),
    (cx - 10.0, base_y + 250.0),
  ]
  let leg_r : Array[(Double, Double)] = [
    (cx + 30.0, base_y + 250.0),
    (cx + 54.0, base_y + 130.0),
    (cx + 34.0, base_y + 30.0),
    (cx + 10.0, base_y + 30.0),
    (cx + 6.0, base_y + 130.0),
    (cx + 10.0, base_y + 250.0),
  ]
  ops.append(ops_stroke_polyline(leg_l + [leg_l[0]], (0.1, 0.1, 0.1), 4.5)[:])
  ops.append(ops_stroke_polyline(leg_r + [leg_r[0]], (0.1, 0.1, 0.1), 4.5)[:])
  ops
}

///|
fn ops_cut_border() -> Array[Op] {
  let ops : Array[Op] = Array::new()
  ops.append(
    ops_stroke_rect(44.0, 44.0, w() - 88.0, h() - 88.0, (0.78, 0.8, 0.84), 2.0)[:],
  )
  ops.append(
    ops_text(
      54.0,
      56.0,
      "/F2",
      10.0,
      "Cut on the border. Toggle Layers for outfits.",
      (0.45, 0.48, 0.52),
    )[:],
  )
  ops
}

///|
fn ops_outfits_layers() -> Array[Op] {
  let ops : Array[Op] = Array::new()
  let (cx, base_y) = doll_origin()

  // Dress layer
  ops.push(OpBDC("/OC", Name(PdfName(b"/DRESS"))))
  let skirt : Array[(Double, Double)] = [
    (cx - 94.0, base_y + 250.0),
    (cx + 94.0, base_y + 250.0),
    (cx + 120.0, base_y + 120.0),
    (cx - 120.0, base_y + 120.0),
  ]
  ops.append(ops_fill_polygon(skirt, (0.95, 0.75, 0.9))[:])
  ops.append(
    ops_fill_rect(cx - 62.0, base_y + 330.0, 124.0, 120.0, (0.95, 0.75, 0.9))[:],
  )
  ops.append(ops_stroke_polyline(skirt + [skirt[0]], (0.1, 0.1, 0.1), 3.0)[:])
  ops.append(
    ops_stroke_rect(
      cx - 62.0,
      base_y + 330.0,
      124.0,
      120.0,
      (0.1, 0.1, 0.1),
      3.0,
    )[:],
  )
  ops.append(
    ops_text(
      cx - 52.0,
      base_y + 462.0,
      "/F2",
      11.0,
      "DRESS",
      (0.92, 0.33, 0.36),
    )[:],
  )
  ops.push(OpEMC)

  // Space suit layer
  ops.push(OpBDC("/OC", Name(PdfName(b"/SPACE"))))
  ops.append(
    ops_fill_rect(cx - 78.0, base_y + 250.0, 156.0, 230.0, (0.92, 0.95, 0.98))[:],
  )
  ops.append(
    ops_stroke_rect(
      cx - 78.0,
      base_y + 250.0,
      156.0,
      230.0,
      (0.1, 0.1, 0.1),
      3.0,
    )[:],
  )
  let visor = circle_points(cx, base_y + 500.0, 34.0, 50)
  ops.append(ops_fill_polygon(visor, (0.7, 0.9, 1.0))[:])
  ops.append(ops_stroke_polyline(visor + [visor[0]], (0.1, 0.1, 0.1), 3.0)[:])
  ops.append(
    ops_fill_rect(cx - 62.0, base_y + 364.0, 124.0, 18.0, (0.18, 0.48, 0.86))[:],
  )
  ops.append(
    ops_text(
      cx - 54.0,
      base_y + 462.0,
      "/F2",
      11.0,
      "SPACE SUIT",
      (0.18, 0.48, 0.86),
    )[:],
  )
  ops.push(OpEMC)

  // Hero layer
  ops.push(OpBDC("/OC", Name(PdfName(b"/HERO"))))
  let cape : Array[(Double, Double)] = [
    (cx - 70.0, base_y + 420.0),
    (cx + 70.0, base_y + 420.0),
    (cx + 160.0, base_y + 250.0),
    (cx + 110.0, base_y + 70.0),
    (cx - 110.0, base_y + 70.0),
    (cx - 160.0, base_y + 250.0),
  ]
  ops.append(ops_fill_polygon(cape, (0.92, 0.33, 0.36))[:])
  ops.append(ops_stroke_polyline(cape + [cape[0]], (0.1, 0.1, 0.1), 3.0)[:])
  ops.append(
    ops_fill_rect(cx - 64.0, base_y + 330.0, 128.0, 120.0, (0.95, 0.75, 0.2))[:],
  )
  ops.append(
    ops_stroke_rect(
      cx - 64.0,
      base_y + 330.0,
      128.0,
      120.0,
      (0.1, 0.1, 0.1),
      3.0,
    )[:],
  )
  ops.append(
    ops_text(cx - 48.0, base_y + 462.0, "/F2", 11.0, "HERO", (0.52, 0.4, 0.86))[:],
  )
  ops.push(OpEMC)

  // Hat layer
  ops.push(OpBDC("/OC", Name(PdfName(b"/HAT"))))
  let hat : Array[(Double, Double)] = [
    (cx - 82.0, base_y + 550.0),
    (cx + 82.0, base_y + 550.0),
    (cx + 70.0, base_y + 590.0),
    (cx - 70.0, base_y + 590.0),
  ]
  ops.append(ops_fill_polygon(hat, (0.12, 0.14, 0.18))[:])
  ops.append(
    ops_fill_rect(cx - 54.0, base_y + 590.0, 108.0, 36.0, (0.12, 0.14, 0.18))[:],
  )
  ops.append(
    ops_text(cx - 26.0, base_y + 560.0, "/F2", 10.0, "HAT", (0.95, 0.96, 0.98))[:],
  )
  ops.push(OpEMC)

  // Sparkles layer (tiny stars)
  ops.push(OpBDC("/OC", Name(PdfName(b"/SPARKLES"))))
  let spark : Array[(Double, Double)] = [
    (cx - 120.0, base_y + 520.0),
    (cx - 150.0, base_y + 470.0),
    (cx - 110.0, base_y + 440.0),
    (cx - 165.0, base_y + 440.0),
    (cx - 120.0, base_y + 405.0),
    (cx - 136.0, base_y + 350.0),
    (cx - 92.0, base_y + 384.0),
    (cx - 46.0, base_y + 350.0),
    (cx - 72.0, base_y + 405.0),
    (cx - 28.0, base_y + 440.0),
    (cx - 82.0, base_y + 440.0),
    (cx - 42.0, base_y + 470.0),
  ]
  ops.append(ops_fill_polygon(spark, (0.95, 0.75, 0.2))[:])
  ops.append(
    ops_fill_polygon(
      circle_points(cx + 150.0, base_y + 470.0, 9.0, 18),
      (0.18, 0.66, 0.52),
    )[:],
  )
  ops.append(
    ops_text(
      cx - 70.0,
      base_y + 300.0,
      "/F2",
      10.0,
      "SPARKLES",
      (0.95, 0.75, 0.2),
    )[:],
  )
  ops.push(OpEMC)
  ops
}

///|
fn cover_ops() -> (Array[Op], (Double, Double, Double, Double)) {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, w(), h(), (0.98, 0.98, 0.99))[:])
  ops.append(ops_fill_rect(0.0, h() - 130.0, w(), 130.0, (0.52, 0.4, 0.86))[:])
  ops.append(
    ops_text(54.0, h() - 78.0, "/F0", 46.0, "Paper Doll", (1.0, 1.0, 1.0))[:],
  )
  ops.append(
    ops_text(
      56.0,
      h() - 110.0,
      "/F1",
      16.0,
      "A tiny dress-up PDF (layers + links)",
      (0.92, 0.94, 0.98),
    )[:],
  )
  ops.append(
    ops_text(
      54.0,
      114.0,
      "/F1",
      14.0,
      "Open Layers and toggle outfits: DRESS / SPACE / HERO / HAT / SPARKLES",
      (0.45, 0.48, 0.52),
    )[:],
  )
  let (btn, rect) = ops_button(
    54.0,
    70.0,
    320.0,
    62.0,
    "Dress Up!",
    (0.92, 0.33, 0.36),
  )
  ops.append(btn[:])
  (ops, rect)
}

///|
fn mixmatch_ops() -> (Array[Op], Array[(Double, Double, Double, Double)]) {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, w(), h(), (1.0, 1.0, 1.0))[:])
  ops.append(
    ops_text(54.0, h() - 78.0, "/F0", 40.0, "Mix & Match", (0.12, 0.14, 0.18))[:],
  )
  ops.append(
    ops_text(
      54.0,
      h() - 108.0,
      "/F1",
      14.0,
      "Toggle layers to swap outfits like a game.",
      (0.45, 0.48, 0.52),
    )[:],
  )
  ops.append(ops_home_badge()[:])
  ops.append(ops_cut_border()[:])
  ops.append(ops_doll_outline()[:])
  ops.append(ops_outfits_layers()[:])

  // Poster links
  let rects : Array[(Double, Double, Double, Double)] = Array::new()
  let (b1, r1) = ops_button(
    54.0,
    520.0,
    220.0,
    44.0,
    "DRESS poster",
    (0.95, 0.75, 0.9),
  )
  let (b2, r2) = ops_button(
    54.0,
    468.0,
    220.0,
    44.0,
    "SPACE poster",
    (0.18, 0.48, 0.86),
  )
  let (b3, r3) = ops_button(
    54.0,
    416.0,
    220.0,
    44.0,
    "HERO poster",
    (0.92, 0.33, 0.36),
  )
  ops.append(b1[:])
  ops.append(b2[:])
  ops.append(b3[:])
  rects.push(r1)
  rects.push(r2)
  rects.push(r3)
  (ops, rects)
}

///|
fn ops_dress_plain() -> Array[Op] {
  let ops : Array[Op] = Array::new()
  let (cx, base_y) = doll_origin()
  let skirt : Array[(Double, Double)] = [
    (cx - 94.0, base_y + 250.0),
    (cx + 94.0, base_y + 250.0),
    (cx + 120.0, base_y + 120.0),
    (cx - 120.0, base_y + 120.0),
  ]
  ops.append(ops_fill_polygon(skirt, (0.95, 0.75, 0.9))[:])
  ops.append(
    ops_fill_rect(cx - 62.0, base_y + 330.0, 124.0, 120.0, (0.95, 0.75, 0.9))[:],
  )
  ops.append(ops_stroke_polyline(skirt + [skirt[0]], (0.1, 0.1, 0.1), 3.0)[:])
  ops.append(
    ops_stroke_rect(
      cx - 62.0,
      base_y + 330.0,
      124.0,
      120.0,
      (0.1, 0.1, 0.1),
      3.0,
    )[:],
  )
  ops
}

///|
fn ops_space_plain() -> Array[Op] {
  let ops : Array[Op] = Array::new()
  let (cx, base_y) = doll_origin()
  ops.append(
    ops_fill_rect(cx - 78.0, base_y + 250.0, 156.0, 230.0, (0.92, 0.95, 0.98))[:],
  )
  ops.append(
    ops_stroke_rect(
      cx - 78.0,
      base_y + 250.0,
      156.0,
      230.0,
      (0.1, 0.1, 0.1),
      3.0,
    )[:],
  )
  let visor = circle_points(cx, base_y + 500.0, 34.0, 50)
  ops.append(ops_fill_polygon(visor, (0.7, 0.9, 1.0))[:])
  ops.append(ops_stroke_polyline(visor + [visor[0]], (0.1, 0.1, 0.1), 3.0)[:])
  ops.append(
    ops_fill_rect(cx - 62.0, base_y + 364.0, 124.0, 18.0, (0.18, 0.48, 0.86))[:],
  )
  ops
}

///|
fn ops_hero_plain() -> Array[Op] {
  let ops : Array[Op] = Array::new()
  let (cx, base_y) = doll_origin()
  let cape : Array[(Double, Double)] = [
    (cx - 70.0, base_y + 420.0),
    (cx + 70.0, base_y + 420.0),
    (cx + 160.0, base_y + 250.0),
    (cx + 110.0, base_y + 70.0),
    (cx - 110.0, base_y + 70.0),
    (cx - 160.0, base_y + 250.0),
  ]
  ops.append(ops_fill_polygon(cape, (0.92, 0.33, 0.36))[:])
  ops.append(ops_stroke_polyline(cape + [cape[0]], (0.1, 0.1, 0.1), 3.0)[:])
  ops.append(
    ops_fill_rect(cx - 64.0, base_y + 330.0, 128.0, 120.0, (0.95, 0.75, 0.2))[:],
  )
  ops.append(
    ops_stroke_rect(
      cx - 64.0,
      base_y + 330.0,
      128.0,
      120.0,
      (0.1, 0.1, 0.1),
      3.0,
    )[:],
  )
  ops
}

///|
fn ops_hat_plain() -> Array[Op] {
  let ops : Array[Op] = Array::new()
  let (cx, base_y) = doll_origin()
  let hat : Array[(Double, Double)] = [
    (cx - 82.0, base_y + 550.0),
    (cx + 82.0, base_y + 550.0),
    (cx + 70.0, base_y + 590.0),
    (cx - 70.0, base_y + 590.0),
  ]
  ops.append(ops_fill_polygon(hat, (0.12, 0.14, 0.18))[:])
  ops.append(
    ops_fill_rect(cx - 54.0, base_y + 590.0, 108.0, 36.0, (0.12, 0.14, 0.18))[:],
  )
  ops
}

///|
fn ops_sparkles_plain() -> Array[Op] {
  let ops : Array[Op] = Array::new()
  let (cx, base_y) = doll_origin()
  let spark : Array[(Double, Double)] = [
    (cx - 120.0, base_y + 520.0),
    (cx - 150.0, base_y + 470.0),
    (cx - 110.0, base_y + 440.0),
    (cx - 165.0, base_y + 440.0),
    (cx - 120.0, base_y + 405.0),
    (cx - 136.0, base_y + 350.0),
    (cx - 92.0, base_y + 384.0),
    (cx - 46.0, base_y + 350.0),
    (cx - 72.0, base_y + 405.0),
    (cx - 28.0, base_y + 440.0),
    (cx - 82.0, base_y + 440.0),
    (cx - 42.0, base_y + 470.0),
  ]
  ops.append(ops_fill_polygon(spark, (0.95, 0.75, 0.2))[:])
  ops.append(
    ops_fill_polygon(
      circle_points(cx + 150.0, base_y + 470.0, 9.0, 18),
      (0.18, 0.66, 0.52),
    )[:],
  )
  ops
}

///|
fn poster_ops(
  title : String,
  kind : Int,
  bg : (Double, Double, Double),
) -> Array[Op] {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, w(), h(), (1.0, 1.0, 1.0))[:])
  ops.append(ops_fill_rect(0.0, h() - 130.0, w(), 130.0, bg)[:])
  ops.append(ops_text(54.0, h() - 78.0, "/F0", 44.0, title, (1.0, 1.0, 1.0))[:])
  ops.append(
    ops_text(
      54.0,
      h() - 110.0,
      "/F1",
      16.0,
      "Print or screenshot. Or use Mix & Match.",
      (0.92, 0.94, 0.98),
    )[:],
  )
  ops.append(ops_home_badge()[:])
  ops.append(ops_cut_border()[:])
  ops.append(ops_doll_outline()[:])
  match kind {
    0 => ops.append(ops_dress_plain()[:])
    1 => ops.append(ops_space_plain()[:])
    2 => ops.append(ops_hero_plain()[:])
    _ => ()
  }
  ops.append(ops_hat_plain()[:])
  ops.append(ops_sparkles_plain()[:])
  ops
}

///|
/// Generate a printable paper-doll PDF with mix-and-match layers and clickable navigation.
pub async fn run(
  out_file? : String = "paperdoll.pdf",
  quiet? : Bool = false,
) -> Unit {
  try {
    let (cover, cover_rect) = cover_ops()
    let (mix, poster_rects) = mixmatch_ops()
    let pages : Array[@pdfpage.Page] = [
      page_of_ops(cover),
      page_of_ops(mix),
      page_of_ops(poster_ops("Dress", 0, (0.95, 0.75, 0.9))),
      page_of_ops(poster_ops("Space Suit", 1, (0.18, 0.48, 0.86))),
      page_of_ops(poster_ops("Hero", 2, (0.92, 0.33, 0.36))),
    ]
    let (pdf, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree(
      pages,
    )
    let pdf = @pdfpage.PdfPageDoc::new(pdf).add_root(pageroot, [])
    let (dress_num, space_num, hero_num, hat_num, sparkles_num) = add_layers(
      pdf,
    )
    let pdf = add_layer_properties_to_pages(
      pdf, dress_num, space_num, hero_num, hat_num, sparkles_num,
    )
    let refs = pdf.page_reference_numbers()
    let pdf = add_bookmarks(pdf, refs)

    // Add navigation links
    let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
    let out_pages = pages

    // Cover button -> Mix page
    out_pages[0] = add_link(pdf, out_pages[0], cover_rect, goto_action(refs[1]))

    // Home badge on pages 1..4
    let home = home_rect()
    for i in 1..<out_pages.length() {
      out_pages[i] = add_link(pdf, out_pages[i], home, goto_action(refs[0]))
    }

    // Mix page poster buttons -> poster pages
    out_pages[1] = add_link(
      pdf,
      out_pages[1],
      poster_rects[0],
      goto_action(refs[2]),
    )
    out_pages[1] = add_link(
      pdf,
      out_pages[1],
      poster_rects[1],
      goto_action(refs[3]),
    )
    out_pages[1] = add_link(
      pdf,
      out_pages[1],
      poster_rects[2],
      goto_action(refs[4]),
    )
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
    _ => run()
  }
}
