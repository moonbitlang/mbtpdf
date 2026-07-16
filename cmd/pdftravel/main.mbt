///|
type PdfObject = @pdf.PdfObject

///|
type Op = @pdfops.Op

///|
const TAB_W : Double = 92.0

///|
const TAB_H : Double = 30.0

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
fn ops_polyline(
  points : Array[(Double, Double)],
  rgb : (Double, Double, Double),
  width : Double,
) -> Array[Op] {
  match points {
    [] => []
    [(x0, y0), .. rest] => {
      let (r, g, b) = rgb
      let ops : Array[Op] = [Opq, Opw(width), OpRG(r, g, b), Opm(x0, y0)]
      for p in rest {
        let (x, y) = p
        ops.push(Opl(x, y))
      }
      ops.push(OpS)
      ops.push(OpQ)
      ops
    }
  }
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
fn ops_fill_polygon(
  points : Array[(Double, Double)],
  rgb : (Double, Double, Double),
) -> Array[Op] {
  match points {
    [] => []
    [(x0, y0), .. rest] => {
      let (r, g, b) = rgb
      let ops : Array[Op] = [Opq, Oprg(r, g, b), Opm(x0, y0)]
      for p in rest {
        let (x, y) = p
        ops.push(Opl(x, y))
      }
      ops.push(Oph)
      ops.push(Opf)
      ops.push(OpQ)
      ops
    }
  }
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
  let night : PdfObject = Dictionary([
    ("/Type", Name(PdfName(b"/OCG"))),
    ("/Name", PdfString("NIGHT MODE")),
  ])
  let surprise : PdfObject = Dictionary([
    ("/Type", Name(PdfName(b"/OCG"))),
    ("/Name", PdfString("SURPRISE")),
  ])
  let night_num = pdf.addobj(night)
  let surprise_num = pdf.addobj(surprise)
  let default_dict : PdfObject = Dictionary([
    ("/BaseState", Name(PdfName(b"/ON"))),
    ("/Intent", Name(PdfName(b"/View"))),
    ("/Name", PdfString("Default")),
    ("/OFF", PdfArray([Indirect(night_num), Indirect(surprise_num)])),
  ])
  let ocprops : PdfObject = Dictionary([
    ("/OCGs", PdfArray([Indirect(night_num), Indirect(surprise_num)])),
    ("/D", default_dict),
  ])
  let ocprops_num = pdf.addobj(ocprops)
  set_catalog_entry(pdf, "/OCProperties", Indirect(ocprops_num))
  (night_num, surprise_num)
}

///|
fn add_layer_properties_to_pages(
  pdf : @pdf.Pdf,
  night_num : Int,
  surprise_num : Int,
) -> @pdf.Pdf raise {
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  for i in 0..<pages.length() {
    let page = pages[i]
    let props : PdfObject = Dictionary([
      ("/NIGHT", Indirect(night_num)),
      ("/SURPRISE", Indirect(surprise_num)),
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
fn uri_action(uri : String) -> PdfObject {
  Dictionary([("/S", Name(PdfName(b"/URI"))), ("/URI", PdfString(uri))])
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
    "Cover", "Map", "Itinerary", "Coupons", "Postcard", "Packing List",
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
fn tab_titles() -> Array[String] {
  ["MAP", "PLAN", "DEALS", "POSTCARD", "PACK"]
}

///|
fn tab_colors() -> Array[(Double, Double, Double)] {
  [
    (0.18, 0.48, 0.86),
    (0.18, 0.66, 0.52),
    (0.95, 0.75, 0.2),
    (0.92, 0.33, 0.36),
    (0.52, 0.4, 0.86),
  ]
}

///|
fn tab_rect(i : Int) -> (Double, Double, Double, Double) {
  let x1 = w() - 10.0
  let x0 = x1 - TAB_W
  let y1 = h() - 120.0 - i.to_double() * (TAB_H + 10.0)
  let y0 = y1 - TAB_H
  (x0, y0, x1, y1)
}

///|
fn ops_tabs(active? : Int = -1) -> Array[Op] {
  let titles = tab_titles()
  let colors = tab_colors()
  let ops : Array[Op] = Array::new()
  for i in 0..<titles.length() {
    let (x0, y0, x1, y1) = tab_rect(i)
    let ww = x1 - x0
    let hh = y1 - y0
    let accent = colors[i]
    let fill = if i == active { accent } else { (1.0, 1.0, 1.0) }
    let text_rgb = if i == active {
      (1.0, 1.0, 1.0)
    } else {
      (0.12, 0.14, 0.18)
    }
    ops.append(ops_fill_rect(x0, y0, ww, hh, fill)[:])
    ops.append(ops_stroke_rect(x0, y0, ww, hh, accent, 2.0)[:])
    ops.append(
      ops_text(x0 + 12.0, y0 + 10.0, "/F0", 11.0, titles[i], text_rgb)[:],
    )
  }
  ops
}

///|
fn home_rect() -> (Double, Double, Double, Double) {
  (18.0, h() - 54.0, 114.0, h() - 22.0)
}

///|
fn ops_home_badge() -> Array[Op] {
  let (x0, y0, x1, y1) = home_rect()
  let ww = x1 - x0
  let hh = y1 - y0
  let accent = (0.12, 0.14, 0.18)
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(x0, y0, ww, hh, (1.0, 1.0, 1.0))[:])
  ops.append(ops_stroke_rect(x0, y0, ww, hh, accent, 2.0)[:])
  ops.append(
    ops_text(x0 + 20.0, y0 + 10.0, "/F0", 12.0, "HOME", (0.12, 0.14, 0.18))[:],
  )
  ops
}

///|
fn ops_night_sky(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Array[Op] {
  let ops : Array[Op] = Array::new()
  ops.push(OpBDC("/OC", Name(PdfName(b"/NIGHT"))))
  let ww = x1 - x0
  let hh = y1 - y0
  let stars : Array[(Double, Double)] = [
    (x0 + 24.0, y1 - 26.0),
    (x0 + ww * 0.22, y0 + hh * 0.62),
    (x0 + ww * 0.44, y0 + hh * 0.74),
    (x0 + ww * 0.66, y0 + hh * 0.58),
    (x0 + ww * 0.86, y0 + hh * 0.70),
    (x0 + ww * 0.78, y0 + hh * 0.86),
    (x0 + ww * 0.50, y0 + hh * 0.90),
  ]
  for s in stars {
    let (sx, sy) = s
    let p = circle_points(sx, sy, 2.2, 10)
    ops.append(ops_fill_polygon(p, (0.95, 0.96, 0.98))[:])
  }
  ops.append(
    ops_fill_rect(x0 + 12.0, y1 - 34.0, 196.0, 22.0, (0.06, 0.07, 0.1))[:],
  )
  ops.append(
    ops_stroke_rect(x0 + 12.0, y1 - 34.0, 196.0, 22.0, (0.95, 0.96, 0.98), 1.2)[:],
  )
  ops.append(
    ops_text(
      x0 + 20.0,
      y1 - 26.0,
      "/F2",
      10.0,
      "NIGHT MODE (Layers)",
      (0.95, 0.96, 0.98),
    )[:],
  )
  ops.push(OpEMC)
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
  ops.append(ops_fill_rect(x, y + hh - 7.0, ww, 7.0, accent)[:])
  ops.append(
    ops_text(x + 14.0, y + 16.0, "/F0", 14.0, label, (0.12, 0.14, 0.18))[:],
  )
  (ops, (x, y, x + ww, y + hh))
}

///|
fn cover_ops() -> (Array[Op], Array[(Double, Double, Double, Double)]) {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, w(), h(), (0.98, 0.98, 0.99))[:])
  ops.append(ops_fill_rect(0.0, h() - 130.0, w(), 130.0, (0.18, 0.48, 0.86))[:])
  ops.append(
    ops_text(54.0, h() - 78.0, "/F0", 46.0, "Weekend Getaway", (1.0, 1.0, 1.0))[:],
  )
  ops.append(
    ops_text(
      56.0,
      h() - 110.0,
      "/F1",
      16.0,
      "An interactive mini travel brochure",
      (0.92, 0.94, 0.98),
    )[:],
  )
  ops.append(
    ops_text(
      54.0,
      114.0,
      "/F1",
      14.0,
      "Tip: toggle NIGHT MODE + SURPRISE in Layers.",
      (0.45, 0.48, 0.52),
    )[:],
  )
  ops.append(ops_tabs()[:])
  ops.append(ops_night_sky(0.0, h() - 130.0, w(), h())[:])
  ops.push(OpBDC("/OC", Name(PdfName(b"/NIGHT"))))
  ops.append(ops_fill_rect(0.0, h() - 130.0, w(), 130.0, (0.06, 0.07, 0.1))[:])
  ops.append(
    ops_text(
      54.0,
      h() - 78.0,
      "/F0",
      46.0,
      "Weekend Getaway",
      (0.95, 0.96, 0.98),
    )[:],
  )
  ops.append(
    ops_text(
      56.0,
      h() - 110.0,
      "/F1",
      16.0,
      "An interactive mini travel brochure",
      (0.8, 0.84, 0.9),
    )[:],
  )
  ops.push(OpEMC)
  let x = 54.0
  let ww = 360.0
  let hh = 54.0
  let rects : Array[(Double, Double, Double, Double)] = Array::new()
  let (b1, r1) = ops_button(x, 440.0, ww, hh, "Open Map", (0.18, 0.48, 0.86))
  let (b2, r2) = ops_button(x, 372.0, ww, hh, "Itinerary", (0.18, 0.66, 0.52))
  let (b3, r3) = ops_button(x, 304.0, ww, hh, "Coupons", (0.95, 0.75, 0.2))
  let (b4, r4) = ops_button(x, 236.0, ww, hh, "Postcard", (0.92, 0.33, 0.36))
  let (b5, r5) = ops_button(x, 168.0, ww, hh, "Packing List", (0.52, 0.4, 0.86))
  ops.append(b1[:])
  ops.append(b2[:])
  ops.append(b3[:])
  ops.append(b4[:])
  ops.append(b5[:])
  rects.push(r1)
  rects.push(r2)
  rects.push(r3)
  rects.push(r4)
  rects.push(r5)
  (ops, rects)
}

///|
fn map_ops() -> (Array[Op], (Double, Double, Double, Double)) {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, w(), h(), (1.0, 1.0, 1.0))[:])
  ops.append(ops_tabs(active=0)[:])
  ops.append(ops_home_badge()[:])
  ops.append(
    ops_text(54.0, h() - 78.0, "/F0", 40.0, "Map", (0.12, 0.14, 0.18))[:],
  )
  ops.append(
    ops_text(
      54.0,
      h() - 108.0,
      "/F1",
      14.0,
      "Tap markers. Or tap OPEN MAP for online view.",
      (0.45, 0.48, 0.52),
    )[:],
  )
  let frame_x = 54.0
  let frame_y = 120.0
  let frame_w = w() - 140.0
  let frame_h = h() - 280.0
  ops.append(
    ops_stroke_rect(frame_x, frame_y, frame_w, frame_h, (0.12, 0.14, 0.18), 3.0)[:],
  )

  // River
  let river : Array[(Double, Double)] = [
    (frame_x + 40.0, frame_y + 520.0),
    (frame_x + 120.0, frame_y + 460.0),
    (frame_x + 220.0, frame_y + 420.0),
    (frame_x + 320.0, frame_y + 360.0),
    (frame_x + 420.0, frame_y + 300.0),
    (frame_x + 520.0, frame_y + 260.0),
  ]
  ops.append(ops_polyline(river, (0.18, 0.48, 0.86), 10.0)[:])

  // Landmarks
  fn marker(
    cx : Double,
    cy : Double,
    label : String,
    color : (Double, Double, Double),
  ) -> Unit {
    let p = circle_points(cx, cy, 16.0, 40)
    ops.append(ops_fill_polygon(p, color)[:])
    ops.append(
      ops_text(cx - 5.0, cy - 5.0, "/F0", 14.0, label, (1.0, 1.0, 1.0))[:],
    )
  }

  marker(frame_x + 140.0, frame_y + 420.0, "A", (0.18, 0.66, 0.52))
  marker(frame_x + 360.0, frame_y + 360.0, "B", (0.95, 0.75, 0.2))
  marker(frame_x + 480.0, frame_y + 240.0, "C", (0.92, 0.33, 0.36))
  ops.append(
    ops_text(
      frame_x + 60.0,
      frame_y + 90.0,
      "/F1",
      12.0,
      "A = Scenic lookout   B = Snack stop   C = Sunset pier",
      (0.12, 0.14, 0.18),
    )[:],
  )

  // Night overlay just on the frame area
  ops.append(
    ops_night_sky(frame_x, frame_y, frame_x + frame_w, frame_y + frame_h)[:],
  )
  let (btn, rect) = ops_button(
    54.0,
    60.0,
    220.0,
    44.0,
    "OPEN MAP",
    (0.18, 0.48, 0.86),
  )
  ops.append(btn[:])
  (ops, rect)
}

///|
fn itinerary_ops() -> Array[Op] {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, w(), h(), (1.0, 1.0, 1.0))[:])
  ops.append(ops_tabs(active=1)[:])
  ops.append(ops_home_badge()[:])
  ops.append(
    ops_text(54.0, h() - 78.0, "/F0", 40.0, "Itinerary", (0.12, 0.14, 0.18))[:],
  )
  ops.append(
    ops_text(
      54.0,
      h() - 108.0,
      "/F1",
      14.0,
      "A weekend plan you can actually follow.",
      (0.45, 0.48, 0.52),
    )[:],
  )
  fn checkbox(x : Double, y : Double) -> Unit {
    ops.append(ops_stroke_rect(x, y, 12.0, 12.0, (0.12, 0.14, 0.18), 1.6)[:])
  }

  fn item(y : Double, time : String, label : String) -> Unit {
    checkbox(56.0, y + 2.0)
    ops.append(
      ops_text(76.0, y + 2.0, "/F2", 11.0, time, (0.18, 0.48, 0.86))[:],
    )
    ops.append(
      ops_text(132.0, y + 2.0, "/F1", 12.0, label, (0.12, 0.14, 0.18))[:],
    )
  }

  ops.append(
    ops_fill_rect(54.0, 520.0, w() - 160.0, 30.0, (0.95, 0.96, 0.98))[:],
  )
  ops.append(ops_text(62.0, 530.0, "/F0", 14.0, "DAY 1", (0.12, 0.14, 0.18))[:])
  item(486.0, "09:30", "Coffee + a walk by the river")
  item(462.0, "11:00", "Lookout A (photos!)")
  item(438.0, "13:00", "Snack stop B")
  item(414.0, "16:30", "Sunset at pier C")
  item(390.0, "19:00", "Dinner + dessert")
  ops.append(
    ops_fill_rect(54.0, 334.0, w() - 160.0, 30.0, (0.95, 0.96, 0.98))[:],
  )
  ops.append(ops_text(62.0, 344.0, "/F0", 14.0, "DAY 2", (0.12, 0.14, 0.18))[:])
  item(300.0, "09:00", "Lazy breakfast")
  item(276.0, "10:30", "Pick a souvenir")
  item(252.0, "12:00", "One last photo at A")
  item(228.0, "13:30", "Head home")

  // Night sticker
  ops.push(OpBDC("/OC", Name(PdfName(b"/NIGHT"))))
  ops.append(
    ops_text(
      54.0,
      80.0,
      "/F2",
      11.0,
      "NIGHT MODE: add stars + mood (Layers)",
      (0.95, 0.96, 0.98),
    )[:],
  )
  ops.push(OpEMC)
  ops
}

///|
fn coupons_ops() -> Array[Op] {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, w(), h(), (1.0, 1.0, 1.0))[:])
  ops.append(ops_tabs(active=2)[:])
  ops.append(ops_home_badge()[:])
  ops.append(
    ops_text(54.0, h() - 78.0, "/F0", 40.0, "Coupons", (0.12, 0.14, 0.18))[:],
  )
  ops.append(
    ops_text(
      54.0,
      h() - 108.0,
      "/F1",
      14.0,
      "Print these and cut along the dashed lines.",
      (0.45, 0.48, 0.52),
    )[:],
  )
  ops.append(
    ops_text(
      54.0,
      h() - 132.0,
      "/F1",
      14.0,
      "Toggle SURPRISE layer to reveal codes.",
      (0.45, 0.48, 0.52),
    )[:],
  )
  fn dashed_box(
    x : Double,
    y : Double,
    ww : Double,
    hh : Double,
    accent : (Double, Double, Double),
  ) -> Unit {
    // fake dashes by small segments
    let (r, g, b) = accent
    ops.push(Opq)
    ops.push(Opw(2.0))
    ops.push(OpRG(r, g, b))
    let step = 12.0
    let dash = 7.0
    let mut xx = x
    while xx < x + ww {
      ops.push(Opm(xx, y))
      ops.push(Opl(if xx + dash < x + ww { xx + dash } else { x + ww }, y))
      ops.push(Opm(xx, y + hh))
      ops.push(Opl(if xx + dash < x + ww { xx + dash } else { x + ww }, y + hh))
      xx = xx + step
    }
    let mut yy = y
    while yy < y + hh {
      ops.push(Opm(x, yy))
      ops.push(Opl(x, if yy + dash < y + hh { yy + dash } else { y + hh }))
      ops.push(Opm(x + ww, yy))
      ops.push(Opl(x + ww, if yy + dash < y + hh { yy + dash } else { y + hh }))
      yy = yy + step
    }
    ops.push(OpS)
    ops.push(OpQ)
  }

  fn coupon(
    y : Double,
    title : String,
    perk : String,
    accent : (Double, Double, Double),
    code : String,
  ) -> Unit {
    let x = 54.0
    let ww = w() - 170.0
    let hh = 120.0
    ops.append(ops_fill_rect(x, y, ww, hh, (0.98, 0.98, 0.99))[:])
    dashed_box(x, y, ww, hh, accent)
    ops.append(
      ops_text(x + 16.0, y + hh - 34.0, "/F0", 20.0, title, (0.12, 0.14, 0.18))[:],
    )
    ops.append(
      ops_text(x + 16.0, y + hh - 62.0, "/F1", 13.0, perk, (0.45, 0.48, 0.52))[:],
    )
    ops.append(
      ops_text(
        x + 16.0,
        y + 18.0,
        "/F2",
        10.0,
        "Show at checkout. One per person.",
        (0.45, 0.48, 0.52),
      )[:],
    )
    ops.push(OpBDC("/OC", Name(PdfName(b"/SURPRISE"))))
    ops.append(
      ops_fill_rect(x + ww - 170.0, y + 18.0, 150.0, 34.0, (1.0, 1.0, 1.0))[:],
    )
    ops.append(
      ops_stroke_rect(x + ww - 170.0, y + 18.0, 150.0, 34.0, accent, 2.0)[:],
    )
    ops.append(
      ops_text(
        x + ww - 158.0,
        y + 29.0,
        "/F2",
        12.0,
        "CODE: " + code,
        (0.12, 0.14, 0.18),
      )[:],
    )
    ops.push(OpEMC)
  }

  coupon(
    468.0,
    "Free Sticker",
    "Pick any tiny sticker at the shop.",
    (0.18, 0.48, 0.86),
    "STARS-7",
  )
  coupon(
    324.0,
    "Snack Upgrade",
    "Upgrade to a bigger treat for free.",
    (0.18, 0.66, 0.52),
    "CRUNCH-5",
  )
  coupon(
    180.0,
    "Postcard Bonus",
    "Free stamp with any postcard.",
    (0.92, 0.33, 0.36),
    "HELLO-9",
  )
  ops
}

///|
fn postcard_ops() -> Array[Op] {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, w(), h(), (0.98, 0.98, 0.99))[:])
  ops.append(ops_tabs(active=3)[:])
  ops.append(ops_home_badge()[:])
  ops.append(
    ops_text(54.0, h() - 78.0, "/F0", 40.0, "Postcard", (0.12, 0.14, 0.18))[:],
  )
  ops.append(
    ops_text(
      54.0,
      h() - 108.0,
      "/F1",
      14.0,
      "Print this page. Cut on the border. Write on the back.",
      (0.45, 0.48, 0.52),
    )[:],
  )
  let x = 54.0
  let y = 140.0
  let ww = w() - 170.0
  let hh = h() - 300.0
  ops.append(ops_fill_rect(x, y, ww, hh, (1.0, 1.0, 1.0))[:])
  ops.append(ops_stroke_rect(x, y, ww, hh, (0.12, 0.14, 0.18), 3.0)[:])

  // Simple "photo" (vector landscape)
  ops.append(ops_fill_rect(x, y + hh - 220.0, ww, 220.0, (0.18, 0.48, 0.86))[:])
  let hills : Array[(Double, Double)] = [
    (x, y + hh - 140.0),
    (x + 120.0, y + hh - 170.0),
    (x + 220.0, y + hh - 130.0),
    (x + 340.0, y + hh - 180.0),
    (x + ww, y + hh - 140.0),
    (x + ww, y + hh - 220.0),
    (x, y + hh - 220.0),
  ]
  ops.append(ops_fill_polygon(hills, (0.18, 0.66, 0.52))[:])
  ops.append(ops_fill_rect(x, y + hh - 64.0, ww, 64.0, (0.95, 0.75, 0.2))[:])
  ops.append(
    ops_text(
      x + 18.0,
      y + hh - 42.0,
      "/F0",
      22.0,
      "Wish you were here!",
      (0.12, 0.14, 0.18),
    )[:],
  )

  // Back layout lines
  ops.append(
    ops_polyline(
      [(x + ww / 2.0, y + 18.0), (x + ww / 2.0, y + hh - 236.0)],
      (0.78, 0.8, 0.84),
      1.5,
    )[:],
  )
  for i in 0..<6 {
    let yy = y + 32.0 + i.to_double() * 26.0
    ops.append(
      ops_polyline(
        [(x + ww / 2.0 + 16.0, yy), (x + ww - 16.0, yy)],
        (0.78, 0.8, 0.84),
        1.0,
      )[:],
    )
  }
  ops.append(
    ops_text(
      x + ww / 2.0 + 16.0,
      y + hh - 260.0,
      "/F2",
      10.0,
      "ADDRESS",
      (0.45, 0.48, 0.52),
    )[:],
  )
  ops.append(ops_night_sky(x, y + hh - 220.0, x + ww, y + hh)[:])
  ops
}

///|
fn packing_ops() -> Array[Op] {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, w(), h(), (1.0, 1.0, 1.0))[:])
  ops.append(ops_tabs(active=4)[:])
  ops.append(ops_home_badge()[:])
  ops.append(
    ops_text(54.0, h() - 78.0, "/F0", 40.0, "Packing List", (0.12, 0.14, 0.18))[:],
  )
  ops.append(
    ops_text(
      54.0,
      h() - 108.0,
      "/F1",
      14.0,
      "Print and check things off.",
      (0.45, 0.48, 0.52),
    )[:],
  )
  fn checkbox(x : Double, y : Double) -> Unit {
    ops.append(ops_stroke_rect(x, y, 12.0, 12.0, (0.12, 0.14, 0.18), 1.6)[:])
  }

  fn line(y : Double, item : String) -> Unit {
    checkbox(56.0, y)
    ops.append(
      ops_text(76.0, y + 2.0, "/F1", 12.0, item, (0.12, 0.14, 0.18))[:],
    )
  }

  let items : Array[String] = [
    "Phone + charger", "Water bottle", "Sunglasses", "Light jacket", "Snacks", "Small umbrella",
    "Camera (optional)", "Postcards (from this PDF)", "One tiny gift for future-you",
  ]
  let mut y = 560.0
  for it in items {
    line(y, it)
    y = y - 26.0
  }
  ops.push(OpBDC("/OC", Name(PdfName(b"/SURPRISE"))))
  ops.append(
    ops_fill_rect(54.0, 120.0, w() - 170.0, 62.0, (0.95, 0.96, 0.98))[:],
  )
  ops.append(
    ops_stroke_rect(54.0, 120.0, w() - 170.0, 62.0, (0.52, 0.4, 0.86), 2.0)[:],
  )
  ops.append(
    ops_text(66.0, 158.0, "/F0", 16.0, "SURPRISE NOTE", (0.12, 0.14, 0.18))[:],
  )
  ops.append(
    ops_text(
      66.0,
      136.0,
      "/F1",
      12.0,
      "Send this PDF to someone and invite them.",
      (0.12, 0.14, 0.18),
    )[:],
  )
  ops.push(OpEMC)
  ops
}

///|
fn add_tabs_links(
  pdf : @pdf.Pdf,
  pages : Array[@pdfpage.Page],
  refs : Array[Int],
) -> Array[@pdfpage.Page] raise {
  let out = pages
  // tabs correspond to pages 1..5
  for p in 0..<out.length() {
    let mut page = out[p]
    for i in 0..<5 {
      let rect = tab_rect(i)
      page = add_link(pdf, page, rect, goto_action(refs[i + 1]))
    }
    out[p] = page
  }
  out
}

///|
/// Generate an interactive travel brochure PDF.
///
/// It is designed to impress "normal PDF users":
/// - Right-side tabs you can click like an app
/// - Bookmarks for quick navigation
/// - Optional layers: `NIGHT MODE` (mood) and `SURPRISE` (secret codes)
pub async fn run(
  out_file? : String = "travel.pdf",
  quiet? : Bool = false,
) -> Unit {
  try {
    let (cover, cover_rects) = cover_ops()
    let (map, map_open_rect) = map_ops()
    let pages : Array[@pdfpage.Page] = [
      page_of_ops(cover),
      page_of_ops(map),
      page_of_ops(itinerary_ops()),
      page_of_ops(coupons_ops()),
      page_of_ops(postcard_ops()),
      page_of_ops(packing_ops()),
    ]
    let (pdf, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree(
      pages,
    )
    let pdf = @pdfpage.PdfPageDoc::new(pdf).add_root(pageroot, [])
    let (night_num, surprise_num) = add_layers(pdf)
    let pdf = add_layer_properties_to_pages(pdf, night_num, surprise_num)
    let refs = pdf.page_reference_numbers()
    let pdf = add_bookmarks(pdf, refs)

    // Add navigation links
    let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
    let out_pages = pages

    // Cover buttons -> pages 1..5
    out_pages[0] = add_link(
      pdf,
      out_pages[0],
      cover_rects[0],
      goto_action(refs[1]),
    )
    out_pages[0] = add_link(
      pdf,
      out_pages[0],
      cover_rects[1],
      goto_action(refs[2]),
    )
    out_pages[0] = add_link(
      pdf,
      out_pages[0],
      cover_rects[2],
      goto_action(refs[3]),
    )
    out_pages[0] = add_link(
      pdf,
      out_pages[0],
      cover_rects[3],
      goto_action(refs[4]),
    )
    out_pages[0] = add_link(
      pdf,
      out_pages[0],
      cover_rects[4],
      goto_action(refs[5]),
    )

    // Home badge on pages 1..5
    let home = home_rect()
    for i in 1..<out_pages.length() {
      out_pages[i] = add_link(pdf, out_pages[i], home, goto_action(refs[0]))
    }

    // Map "OPEN MAP" -> external link
    out_pages[1] = add_link(
      pdf,
      out_pages[1],
      map_open_rect,
      uri_action("https://www.openstreetmap.org"),
    )

    // Right-side tabs on every page
    let out_pages = add_tabs_links(pdf, out_pages, refs)
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
