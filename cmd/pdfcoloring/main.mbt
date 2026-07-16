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
  let color : PdfObject = Dictionary([
    ("/Type", Name(PdfName(b"/OCG"))),
    ("/Name", PdfString("COLOR")),
  ])
  let answers : PdfObject = Dictionary([
    ("/Type", Name(PdfName(b"/OCG"))),
    ("/Name", PdfString("ANSWERS")),
  ])
  let color_num = pdf.addobj(color)
  let answers_num = pdf.addobj(answers)
  let default_dict : PdfObject = Dictionary([
    ("/BaseState", Name(PdfName(b"/ON"))),
    ("/Intent", Name(PdfName(b"/View"))),
    ("/Name", PdfString("Default")),
    ("/OFF", PdfArray([Indirect(color_num), Indirect(answers_num)])),
  ])
  let ocprops : PdfObject = Dictionary([
    ("/OCGs", PdfArray([Indirect(color_num), Indirect(answers_num)])),
    ("/D", default_dict),
  ])
  let ocprops_num = pdf.addobj(ocprops)
  set_catalog_entry(pdf, "/OCProperties", Indirect(ocprops_num))
  (color_num, answers_num)
}

///|
fn add_layer_properties_to_pages(
  pdf : @pdf.Pdf,
  color_num : Int,
  answers_num : Int,
) -> @pdf.Pdf raise {
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  for i in 0..<pages.length() {
    let page = pages[i]
    let props : PdfObject = Dictionary([
      ("/COLOR", Indirect(color_num)),
      ("/ANSWERS", Indirect(answers_num)),
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
  let marks : Array[@pdfmarks.Bookmark] = Array::new()
  let titles : Array[String] = [
    "Cover", "Cupcake", "Rocket", "Hidden Objects", "The End",
  ]
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
  ops.append(ops_fill_rect(x, y + hh - 6.0, ww, 6.0, accent)[:])
  ops.append(
    ops_text(x + 12.0, y + 14.0, "/F0", 14.0, label, (0.12, 0.14, 0.18))[:],
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
fn cover_ops() -> (Array[Op], (Double, Double, Double, Double)) {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, w(), h(), (0.98, 0.98, 0.99))[:])
  ops.append(ops_fill_rect(0.0, h() - 120.0, w(), 120.0, (0.18, 0.48, 0.86))[:])
  ops.append(
    ops_text(72.0, h() - 76.0, "/F0", 52.0, "Color & Find!", (1.0, 1.0, 1.0))[:],
  )
  ops.append(
    ops_text(
      74.0,
      h() - 106.0,
      "/F1",
      18.0,
      "A tiny printable coloring book",
      (0.92, 0.94, 0.98),
    )[:],
  )
  ops.append(
    ops_text(
      72.0,
      190.0,
      "/F1",
      18.0,
      "Print pages 2–4. Or toggle COLOR/ANSWERS in Layers.",
      (0.12, 0.14, 0.18),
    )[:],
  )
  let (btn, rect) = ops_button(
    72.0,
    70.0,
    280.0,
    62.0,
    "Start",
    (0.92, 0.33, 0.36),
  )
  ops.append(btn[:])
  (ops, rect)
}

///|
fn cupcake_ops() -> Array[Op] {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, w(), h(), (1.0, 1.0, 1.0))[:])
  ops.append(
    ops_text(72.0, h() - 80.0, "/F0", 40.0, "Cupcake", (0.12, 0.14, 0.18))[:],
  )
  ops.append(
    ops_text(
      72.0,
      h() - 108.0,
      "/F1",
      14.0,
      "Color it! (Toggle COLOR layer to peek.)",
      (0.45, 0.48, 0.52),
    )[:],
  )
  ops.append(ops_home_badge()[:])
  let cx = w() / 2.0
  let base_y = 190.0

  // Wrapper outline
  let wrapper : Array[(Double, Double)] = [
    (cx - 180.0, base_y + 210.0),
    (cx - 140.0, base_y),
    (cx + 140.0, base_y),
    (cx + 180.0, base_y + 210.0),
  ]
  ops.append(
    ops_stroke_polyline(wrapper + [wrapper[0]], (0.1, 0.1, 0.1), 5.0)[:],
  )

  // Wrapper stripes
  for i in 0..<10 {
    let t = i.to_double() / 9.0
    let x = cx - 120.0 + 240.0 * t
    ops.append(
      ops_stroke_polyline(
        [(x, base_y + 20.0), (x, base_y + 186.0)],
        (0.2, 0.2, 0.2),
        2.0,
      )[:],
    )
  }

  // Frosting outline (big fluffy circle-ish)
  let frosting = circle_points(cx, base_y + 310.0, 150.0, 80)
  ops.append(
    ops_stroke_polyline(frosting + [frosting[0]], (0.1, 0.1, 0.1), 6.0)[:],
  )

  // Cherry outline
  let cherry = circle_points(cx + 80.0, base_y + 430.0, 28.0, 30)
  ops.append(ops_stroke_polyline(cherry + [cherry[0]], (0.1, 0.1, 0.1), 5.0)[:])
  ops.append(
    ops_stroke_polyline(
      [(cx + 80.0, base_y + 458.0), (cx + 60.0, base_y + 498.0)],
      (0.1, 0.1, 0.1),
      3.0,
    )[:],
  )

  // COLOR layer fills
  ops.push(OpBDC("/OC", Name(PdfName(b"/COLOR"))))
  ops.append(ops_fill_polygon(wrapper, (0.97, 0.9, 0.65))[:])
  ops.append(ops_fill_polygon(frosting, (0.95, 0.75, 0.9))[:])
  ops.append(ops_fill_polygon(cherry, (0.92, 0.33, 0.36))[:])
  ops.push(OpEMC)
  ops
}

///|
fn rocket_ops() -> Array[Op] {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, w(), h(), (1.0, 1.0, 1.0))[:])
  ops.append(
    ops_text(72.0, h() - 80.0, "/F0", 40.0, "Rocket", (0.12, 0.14, 0.18))[:],
  )
  ops.append(
    ops_text(
      72.0,
      h() - 108.0,
      "/F1",
      14.0,
      "Color it! (Toggle COLOR layer to peek.)",
      (0.45, 0.48, 0.52),
    )[:],
  )
  ops.append(ops_home_badge()[:])
  let cx = w() / 2.0
  let cy = 360.0
  let body_w = 160.0
  let body_h = 320.0

  // Body outline
  ops.append(
    ops_stroke_rect(
      cx - body_w / 2.0,
      cy - body_h / 2.0,
      body_w,
      body_h,
      (0.1, 0.1, 0.1),
      6.0,
    )[:],
  )

  // Nose cone outline
  let nose : Array[(Double, Double)] = [
    (cx - body_w / 2.0, cy + body_h / 2.0),
    (cx, cy + body_h / 2.0 + 90.0),
    (cx + body_w / 2.0, cy + body_h / 2.0),
  ]
  ops.append(ops_stroke_polyline(nose + [nose[0]], (0.1, 0.1, 0.1), 6.0)[:])

  // Window outline
  let window = circle_points(cx, cy + 40.0, 36.0, 40)
  ops.append(ops_stroke_polyline(window + [window[0]], (0.1, 0.1, 0.1), 5.0)[:])

  // Fins outline
  let fin_l : Array[(Double, Double)] = [
    (cx - body_w / 2.0, cy - 90.0),
    (cx - body_w / 2.0 - 60.0, cy - 150.0),
    (cx - body_w / 2.0, cy - 190.0),
  ]
  let fin_r : Array[(Double, Double)] = [
    (cx + body_w / 2.0, cy - 90.0),
    (cx + body_w / 2.0 + 60.0, cy - 150.0),
    (cx + body_w / 2.0, cy - 190.0),
  ]
  ops.append(ops_stroke_polyline(fin_l + [fin_l[0]], (0.1, 0.1, 0.1), 6.0)[:])
  ops.append(ops_stroke_polyline(fin_r + [fin_r[0]], (0.1, 0.1, 0.1), 6.0)[:])

  // Flame outline
  let flame : Array[(Double, Double)] = [
    (cx - 30.0, cy - body_h / 2.0),
    (cx, cy - body_h / 2.0 - 90.0),
    (cx + 30.0, cy - body_h / 2.0),
    (cx, cy - body_h / 2.0 - 40.0),
  ]
  ops.append(ops_stroke_polyline(flame + [flame[0]], (0.1, 0.1, 0.1), 5.0)[:])

  // Stars (outline)
  let stars : Array[(Double, Double)] = [
    (120.0, 560.0),
    (150.0, 610.0),
    (500.0, 620.0),
    (480.0, 520.0),
    (90.0, 420.0),
    (520.0, 420.0),
  ]
  for s in stars {
    let (sx, sy) = s
    let p = circle_points(sx, sy, 10.0, 12)
    ops.append(ops_stroke_polyline(p + [p[0]], (0.1, 0.1, 0.1), 3.0)[:])
  }

  // COLOR layer
  ops.push(OpBDC("/OC", Name(PdfName(b"/COLOR"))))
  ops.append(
    ops_fill_rect(
      cx - body_w / 2.0,
      cy - body_h / 2.0,
      body_w,
      body_h,
      (0.92, 0.95, 0.98),
    )[:],
  )
  ops.append(ops_fill_polygon(nose, (0.18, 0.48, 0.86))[:])
  ops.append(ops_fill_polygon(window, (0.7, 0.9, 1.0))[:])
  ops.append(ops_fill_polygon(fin_l, (0.92, 0.33, 0.36))[:])
  ops.append(ops_fill_polygon(fin_r, (0.92, 0.33, 0.36))[:])
  ops.append(ops_fill_polygon(flame, (0.95, 0.75, 0.2))[:])
  for s in stars {
    let (sx, sy) = s
    ops.append(
      ops_fill_polygon(circle_points(sx, sy, 10.0, 12), (0.95, 0.75, 0.2))[:],
    )
  }
  ops.push(OpEMC)
  ops
}

///|
fn hidden_objects_ops() -> Array[Op] {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, w(), h(), (1.0, 1.0, 1.0))[:])
  ops.append(
    ops_text(
      72.0,
      h() - 80.0,
      "/F0",
      40.0,
      "Hidden Objects",
      (0.12, 0.14, 0.18),
    )[:],
  )
  ops.append(
    ops_text(
      72.0,
      h() - 108.0,
      "/F1",
      14.0,
      "Find: star, heart, fish, key, lightning.",
      (0.45, 0.48, 0.52),
    )[:],
  )
  ops.append(
    ops_text(
      72.0,
      h() - 132.0,
      "/F1",
      14.0,
      "Toggle ANSWERS layer to reveal.",
      (0.45, 0.48, 0.52),
    )[:],
  )
  ops.append(ops_home_badge()[:])

  // Scene frame
  let frame_x = 72.0
  let frame_y = 120.0
  let frame_w = w() - 144.0
  let frame_h = h() - 280.0
  ops.append(
    ops_stroke_rect(frame_x, frame_y, frame_w, frame_h, (0.1, 0.1, 0.1), 4.0)[:],
  )

  // Shelf
  ops.append(
    ops_stroke_rect(
      frame_x + 40.0,
      frame_y + frame_h - 120.0,
      frame_w - 80.0,
      24.0,
      (0.1, 0.1, 0.1),
      4.0,
    )[:],
  )
  ops.append(
    ops_stroke_rect(
      frame_x + 70.0,
      frame_y + frame_h - 220.0,
      frame_w - 140.0,
      18.0,
      (0.1, 0.1, 0.1),
      4.0,
    )[:],
  )

  // Objects (outlines only)
  // Star
  let star : Array[(Double, Double)] = [
    (170.0, 540.0),
    (182.0, 516.0),
    (208.0, 512.0),
    (188.0, 496.0),
    (194.0, 470.0),
    (170.0, 484.0),
    (146.0, 470.0),
    (152.0, 496.0),
    (132.0, 512.0),
    (158.0, 516.0),
  ]
  ops.append(ops_stroke_polyline(star + [star[0]], (0.1, 0.1, 0.1), 3.5)[:])

  // Heart (two circles + triangle-ish)
  let heart_l = circle_points(300.0, 520.0, 18.0, 24)
  let heart_r = circle_points(330.0, 520.0, 18.0, 24)
  let heart_tip : Array[(Double, Double)] = [
    (282.0, 518.0),
    (348.0, 518.0),
    (315.0, 480.0),
  ]
  ops.append(
    ops_stroke_polyline(heart_l + [heart_l[0]], (0.1, 0.1, 0.1), 3.0)[:],
  )
  ops.append(
    ops_stroke_polyline(heart_r + [heart_r[0]], (0.1, 0.1, 0.1), 3.0)[:],
  )
  ops.append(
    ops_stroke_polyline(heart_tip + [heart_tip[0]], (0.1, 0.1, 0.1), 3.0)[:],
  )

  // Fish (oval + tail)
  let fish = circle_points(460.0, 440.0, 24.0, 30)
  let tail : Array[(Double, Double)] = [
    (484.0, 440.0),
    (514.0, 458.0),
    (514.0, 422.0),
  ]
  ops.append(ops_stroke_polyline(fish + [fish[0]], (0.1, 0.1, 0.1), 3.0)[:])
  ops.append(ops_stroke_polyline(tail + [tail[0]], (0.1, 0.1, 0.1), 3.0)[:])

  // Key (circle + shaft)
  let key_ring = circle_points(220.0, 260.0, 18.0, 28)
  ops.append(
    ops_stroke_polyline(key_ring + [key_ring[0]], (0.1, 0.1, 0.1), 3.0)[:],
  )
  ops.append(ops_stroke_rect(236.0, 252.0, 90.0, 16.0, (0.1, 0.1, 0.1), 3.0)[:])
  ops.append(ops_stroke_rect(312.0, 252.0, 14.0, 26.0, (0.1, 0.1, 0.1), 3.0)[:])
  ops.append(ops_stroke_rect(296.0, 252.0, 14.0, 20.0, (0.1, 0.1, 0.1), 3.0)[:])

  // Lightning bolt
  let bolt : Array[(Double, Double)] = [
    (520.0, 300.0),
    (492.0, 262.0),
    (516.0, 262.0),
    (484.0, 220.0),
    (544.0, 270.0),
    (516.0, 270.0),
  ]
  ops.append(ops_stroke_polyline(bolt + [bolt[0]], (0.1, 0.1, 0.1), 3.5)[:])

  // ANSWERS layer: circles + labels
  ops.push(OpBDC("/OC", Name(PdfName(b"/ANSWERS"))))
  fn circle_mark(cx : Double, cy : Double, r : Double, label : String) -> Unit {
    let c = circle_points(cx, cy, r, 40)
    ops.append(ops_stroke_polyline(c + [c[0]], (0.92, 0.33, 0.36), 3.0)[:])
    ops.append(
      ops_text(cx + r + 8.0, cy - 4.0, "/F2", 12.0, label, (0.92, 0.33, 0.36))[:],
    )
  }

  circle_mark(170.0, 500.0, 34.0, "star")
  circle_mark(315.0, 505.0, 38.0, "heart")
  circle_mark(470.0, 440.0, 44.0, "fish")
  circle_mark(270.0, 260.0, 62.0, "key")
  circle_mark(512.0, 262.0, 58.0, "lightning")
  ops.push(OpEMC)
  ops
}

///|
fn end_ops() -> Array[Op] {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, w(), h(), (0.06, 0.07, 0.1))[:])
  ops.append(
    ops_text(72.0, h() - 110.0, "/F0", 54.0, "Nice work!", (0.95, 0.96, 0.98))[:],
  )
  ops.append(
    ops_text(
      72.0,
      h() - 160.0,
      "/F1",
      18.0,
      "Print, color, and share. Or generate your own pages.",
      (0.8, 0.84, 0.9),
    )[:],
  )
  ops.append(
    ops_text(
      72.0,
      90.0,
      "/F2",
      12.0,
      "Tip: duplicate a page and draw your own outline with pdfops.",
      (0.6, 0.64, 0.7),
    )[:],
  )
  ops.append(ops_home_badge()[:])
  ops
}

///|
/// Generate a tiny printable coloring book PDF.
///
/// This demo intentionally keeps the base artwork black-and-white so it prints
/// well. Use the PDF viewer's "Layers" panel to toggle:
/// - `COLOR`: suggested colors (default hidden)
/// - `ANSWERS`: hidden-object solutions (default hidden)
pub async fn run(
  out_file? : String = "coloring.pdf",
  quiet? : Bool = false,
) -> Unit {
  try {
    let (cover, cover_rect) = cover_ops()
    let pages : Array[@pdfpage.Page] = [
      page_of_ops(cover),
      page_of_ops(cupcake_ops()),
      page_of_ops(rocket_ops()),
      page_of_ops(hidden_objects_ops()),
      page_of_ops(end_ops()),
    ]
    let (pdf, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree(
      pages,
    )
    let pdf = @pdfpage.PdfPageDoc::new(pdf).add_root(pageroot, [])
    let (color_num, answers_num) = add_layers(pdf)
    let pdf = add_layer_properties_to_pages(pdf, color_num, answers_num)
    let refs = pdf.page_reference_numbers()
    let pdf = add_bookmarks(pdf, refs)

    // Add simple navigation links: cover start -> page 2, and a small "Home" link on later pages.
    let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
    let out_pages = pages
    out_pages[0] = add_link(pdf, out_pages[0], cover_rect, goto_action(refs[1]))
    let home_link_rect = home_rect()
    for i in 1..<out_pages.length() {
      out_pages[i] = add_link(
        pdf,
        out_pages[i],
        home_link_rect,
        goto_action(refs[0]),
      )
    }
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
