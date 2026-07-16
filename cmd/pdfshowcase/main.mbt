///|
fn pi() -> Double {
  4.0 * @math.atan(1.0)
}

///|
fn clamp01(x : Double) -> Double {
  if x < 0.0 {
    0.0
  } else if x > 1.0 {
    1.0
  } else {
    x
  }
}

///|
fn hsv_to_rgb(h : Double, s : Double, v : Double) -> (Double, Double, Double) {
  let h = h % 360.0
  let s = clamp01(s)
  let v = clamp01(v)
  if s == 0.0 {
    return (v, v, v)
  }
  let c = v * s
  let x = c * (1.0 - (h / 60.0 % 2.0 - 1.0).abs())
  let m = v - c
  let (rp, gp, bp) = if h < 60.0 {
    (c, x, 0.0)
  } else if h < 120.0 {
    (x, c, 0.0)
  } else if h < 180.0 {
    (0.0, c, x)
  } else if h < 240.0 {
    (0.0, x, c)
  } else if h < 300.0 {
    (x, 0.0, c)
  } else {
    (c, 0.0, x)
  }
  (rp + m, gp + m, bp + m)
}

///|
fn font_type1(base_font : String) -> @pdf.PdfObject {
  Dictionary([
    ("/Type", Name(PdfName(b"/Font"))),
    ("/Subtype", Name(PdfName(b"/Type1"))),
    ("/BaseFont", Name(@pdf.PdfName::of_string("/" + base_font))),
  ])
}

///|
fn default_resources() -> @pdf.PdfObject {
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
fn a4_mediabox() -> @pdf.PdfObject {
  @pdfpage.Page::blank(@pdfpaper.a4).mediabox
}

///|
fn ops_text(
  x : Double,
  y : Double,
  font : String,
  size : Double,
  text : String,
  rgb : (Double, Double, Double),
  rotate_rad? : Double = 0.0,
) -> Array[@pdfops.Op] {
  let (r, g, b) = rgb
  let tr = if rotate_rad == 0.0 {
    @pdftransform.Transform::new([Translate(x, y)]).to_matrix()
  } else {
    @pdftransform.Transform::new([
      Rotate((0.0, 0.0), rotate_rad),
      Translate(x, y),
    ]).to_matrix()
  }
  [Opq, Oprg(r, g, b), OpBT, OpTf(font, size), OpTm(tr), OpTj(text), OpET, OpQ]
}

///|
fn ops_fill_rect(
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  rgb : (Double, Double, Double),
) -> Array[@pdfops.Op] {
  let (r, g, b) = rgb
  [Opq, Oprg(r, g, b), Opre(x, y, w, h), Opf, OpQ]
}

///|
fn ops_stroke_rect(
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  rgb : (Double, Double, Double),
  width : Double,
) -> Array[@pdfops.Op] {
  let (r, g, b) = rgb
  [Opq, Opw(width), OpRG(r, g, b), Opre(x, y, w, h), OpS, OpQ]
}

///|
fn ops_poly_path(
  points : Array[(Double, Double)],
  close? : Bool = true,
) -> Array[@pdfops.Op] {
  match points {
    [] => []
    [(x0, y0), .. rest] => {
      let ops : Array[@pdfops.Op] = Array::new(capacity=points.length() + 2)
      ops.push(Opm(x0, y0))
      for point in rest {
        let (x, y) = point
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
) -> Array[@pdfops.Op] {
  let (r, g, b) = rgb
  [Opq, Oprg(r, g, b)] + ops_poly_path(points) + [Opf, OpQ]
}

///|
fn ops_stroke_polyline(
  points : Array[(Double, Double)],
  rgb : (Double, Double, Double),
  width : Double,
) -> Array[@pdfops.Op] {
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
  let two_pi = 2.0 * pi()
  for i in 0..<n {
    let t = two_pi * (i.to_double() / n.to_double())
    out.push((cx + r * @math.cos(t), cy + r * @math.sin(t)))
  }
  out
}

///|
fn cover_ops() -> Array[@pdfops.Op] {
  let w = 595.0
  let h = 842.0
  let stripes = 28
  let ops : Array[@pdfops.Op] = Array::new()
  for i in 0..<stripes {
    let t = i.to_double() / (stripes - 1).to_double()
    let rgb = hsv_to_rgb(210.0 - 120.0 * t, 0.75, 0.95)
    let y = h * (i.to_double() / stripes.to_double())
    let sh = h / stripes.to_double() + 0.5
    ops.append(ops_fill_rect(0.0, y, w, sh, rgb)[:])
  }
  ops.append(ops_fill_rect(0.0, 0.0, w, 180.0, (0.05, 0.07, 0.1))[:])
  ops.append(
    ops_text(54.0, 720.0, "/F0", 44.0, "mbtpdf Showcase", (1.0, 1.0, 1.0))[:],
  )
  ops.append(
    ops_text(
      56.0,
      680.0,
      "/F1",
      16.0,
      "Generative art • Layers • Clickable navigation",
      (1.0, 1.0, 1.0),
    )[:],
  )
  ops.append(
    ops_text(
      56.0,
      120.0,
      "/F2",
      12.0,
      "Tip: open your PDF viewer's bookmarks / layers panel.",
      (0.85, 0.9, 0.95),
    )[:],
  )
  ops.append(
    ops_text(
      56.0,
      96.0,
      "/F2",
      12.0,
      "This PDF contains internal links; click the page footer buttons.",
      (0.85, 0.9, 0.95),
    )[:],
  )
  ops
}

///|
fn spiro_point(t : Double) -> (Double, Double) {
  let r1 = 120.0
  let r2 = 45.0
  let d = 80.0
  let a = r1 - r2
  let k = a / r2
  let x = a * @math.cos(t) + d * @math.cos(k * t)
  let y = a * @math.sin(t) - d * @math.sin(k * t)
  (x, y)
}

///|
fn spiro_ops() -> Array[@pdfops.Op] {
  let ops : Array[@pdfops.Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, 595.0, 842.0, (0.98, 0.98, 0.985))[:])
  ops.append(
    ops_text(
      54.0,
      800.0,
      "/F0",
      24.0,
      "Procedural Spirograph",
      (0.1, 0.12, 0.16),
    )[:],
  )
  let cx = 297.5
  let cy = 420.0
  let loops = 7.0
  let steps = 1400
  let dt = 2.0 * pi() * loops / steps.to_double()
  for i in 0..<steps {
    let t0 = i.to_double() * dt
    let t1 = (i + 1).to_double() * dt
    let (x0, y0) = spiro_point(t0)
    let (x1, y1) = spiro_point(t1)
    let hue = 360.0 * (i.to_double() / steps.to_double())
    let rgb = hsv_to_rgb(hue, 0.85, 0.9)
    ops.append(
      ops_stroke_polyline([(cx + x0, cy + y0), (cx + x1, cy + y1)], rgb, 1.2)[:],
    )
  }
  ops.append(
    ops_text(
      54.0,
      60.0,
      "/F2",
      11.0,
      "Drawn with plain PDF operators (m/l/S) + a tiny HSV palette.",
      (0.25, 0.28, 0.32),
    )[:],
  )
  ops
}

///|
fn layers_ops() -> Array[@pdfops.Op] {
  let ops : Array[@pdfops.Op] = Array::new()

  // "Day" layer
  ops.push(OpBDC("/OC", Name(PdfName(b"/DAY"))))
  ops.append(ops_fill_rect(0.0, 0.0, 595.0, 842.0, (0.75, 0.9, 1.0))[:])
  ops.append(ops_fill_rect(0.0, 0.0, 595.0, 160.0, (0.9, 0.95, 0.98))[:])
  ops.append(
    ops_fill_polygon(circle_points(470.0, 700.0, 46.0, 40), (1.0, 0.86, 0.1))[:],
  )
  ops.append(
    ops_stroke_rect(70.0, 320.0, 455.0, 240.0, (0.15, 0.25, 0.35), 2.0)[:],
  )
  ops.append(ops_text(90.0, 520.0, "/F0", 28.0, "DAY", (0.12, 0.18, 0.22))[:])
  ops.append(
    ops_text(
      90.0,
      480.0,
      "/F1",
      14.0,
      "A light theme layer.",
      (0.12, 0.18, 0.22),
    )[:],
  )
  ops.push(OpEMC)

  // "Night" layer
  ops.push(OpBDC("/OC", Name(PdfName(b"/NIGHT"))))
  ops.append(ops_fill_rect(0.0, 0.0, 595.0, 842.0, (0.05, 0.06, 0.1))[:])
  ops.append(ops_fill_rect(0.0, 0.0, 595.0, 160.0, (0.09, 0.1, 0.16))[:])
  for i in 0..<120 {
    let x = 30.0 + i.to_double() * 43.0 % 540.0
    let y = 200.0 + i.to_double() * 97.0 % 610.0
    let r = 0.8 + (i % 7).to_double() * 0.3
    ops.append(
      ops_fill_polygon(circle_points(x, y, r, 10), (0.95, 0.98, 1.0))[:],
    )
  }
  ops.append(
    ops_fill_polygon(circle_points(470.0, 700.0, 40.0, 40), (0.9, 0.92, 0.95))[:],
  )
  ops.append(
    ops_fill_polygon(circle_points(485.0, 710.0, 40.0, 40), (0.05, 0.06, 0.1))[:],
  )
  ops.append(
    ops_stroke_rect(70.0, 320.0, 455.0, 240.0, (0.8, 0.86, 0.95), 2.0)[:],
  )
  ops.append(ops_text(90.0, 520.0, "/F0", 28.0, "NIGHT", (0.9, 0.92, 0.95))[:])
  ops.append(
    ops_text(90.0, 480.0, "/F1", 14.0, "A dark theme layer.", (0.9, 0.92, 0.95))[:],
  )
  ops.push(OpEMC)

  // Non-layer instructions (always visible)
  ops.append(
    ops_text(
      54.0,
      800.0,
      "/F0",
      24.0,
      "Optional Content Groups (Layers)",
      (0.98, 0.98, 0.985),
    )[:],
  )
  ops.append(
    ops_text(
      54.0,
      70.0,
      "/F2",
      11.0,
      "Toggle DAY/NIGHT in the viewer's layers panel.",
      (0.9, 0.92, 0.95),
    )[:],
  )
  ops
}

///|
fn map_ops() -> Array[@pdfops.Op] {
  let ops : Array[@pdfops.Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, 595.0, 842.0, (0.99, 0.985, 0.97))[:])
  ops.append(
    ops_text(54.0, 800.0, "/F0", 26.0, "Clickable Map", (0.12, 0.14, 0.18))[:],
  )
  ops.append(
    ops_text(
      54.0,
      770.0,
      "/F1",
      13.0,
      "These cards are backed by PDF link annotations (GoTo/URI).",
      (0.25, 0.28, 0.32),
    )[:],
  )
  let cards : Array[(Double, Double, String, String, (Double, Double, Double))] = [
    (54.0, 620.0, "Go: Spirograph", "Page 2", (0.9, 0.3, 0.35)),
    (310.0, 620.0, "Go: Layers", "Page 3", (0.25, 0.55, 0.9)),
    (54.0, 440.0, "Go: Mini Comic", "Page 5", (0.45, 0.75, 0.35)),
    (310.0, 440.0, "Go: Stickers", "Page 6", (0.95, 0.75, 0.2)),
    (54.0, 260.0, "Go: Credits", "Page 7", (0.6, 0.35, 0.9)),
  ]
  for card in cards {
    let (x, y, title, subtitle, accent) = card
    ops.append(ops_fill_rect(x, y, 231.0, 140.0, (1.0, 1.0, 1.0))[:])
    ops.append(ops_stroke_rect(x, y, 231.0, 140.0, (0.2, 0.22, 0.26), 1.2)[:])
    ops.append(ops_fill_rect(x, y + 134.0, 231.0, 6.0, accent)[:])
    ops.append(
      ops_text(x + 16.0, y + 92.0, "/F0", 16.0, title, (0.15, 0.17, 0.2))[:],
    )
    ops.append(
      ops_text(x + 16.0, y + 66.0, "/F2", 12.0, subtitle, (0.35, 0.38, 0.42))[:],
    )
    ops.append(ops_text(x + 16.0, y + 24.0, "/F2", 10.0, "Click me", accent)[:])
  }
  ops
}

///|
fn comic_ops() -> Array[@pdfops.Op] {
  let ops : Array[@pdfops.Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, 595.0, 842.0, (1.0, 1.0, 1.0))[:])
  ops.append(
    ops_text(54.0, 800.0, "/F0", 24.0, "Tiny PDF Comic", (0.12, 0.14, 0.18))[:],
  )
  let panels : Array[(Double, Double, Double, Double)] = [
    (54.0, 520.0, 487.0, 220.0),
    (54.0, 280.0, 487.0, 200.0),
    (54.0, 80.0, 487.0, 160.0),
  ]
  for panel in panels {
    let (x, y, w, h) = panel
    ops.append(ops_stroke_rect(x, y, w, h, (0.1, 0.1, 0.1), 2.0)[:])
  }

  // Speech bubble (panel 1)
  ops.append(
    ops_fill_polygon(circle_points(180.0, 680.0, 56.0, 40), (1.0, 1.0, 1.0))[:],
  )
  ops.append(
    ops_stroke_polyline(
      circle_points(180.0, 680.0, 56.0, 40),
      (0.1, 0.1, 0.1),
      1.5,
    )[:],
  )
  ops.append(
    ops_fill_polygon(
      [(210.0, 642.0), (240.0, 612.0), (204.0, 624.0)],
      (1.0, 1.0, 1.0),
    )[:],
  )
  ops.append(
    ops_stroke_polyline(
      [(210.0, 642.0), (240.0, 612.0), (204.0, 624.0), (210.0, 642.0)],
      (0.1, 0.1, 0.1),
      1.5,
    )[:],
  )
  ops.append(
    ops_text(140.0, 688.0, "/F1", 12.0, "This is just ops.", (0.12, 0.14, 0.18))[:],
  )
  ops.append(
    ops_text(144.0, 668.0, "/F1", 12.0, "No raster images.", (0.12, 0.14, 0.18))[:],
  )

  // Panel 2: a simple "burst"
  let burst = Array::new(capacity=16)
  for i in 0..<16 {
    let t = 2.0 * pi() * (i.to_double() / 16.0)
    let r = if i % 2 == 0 { 70.0 } else { 35.0 }
    burst.push((300.0 + r * @math.cos(t), 380.0 + r * @math.sin(t)))
  }
  ops.append(ops_fill_polygon(burst, (1.0, 0.92, 0.2))[:])
  ops.append(ops_stroke_polyline(burst + [burst[0]], (0.2, 0.18, 0.05), 2.0)[:])
  ops.append(ops_text(250.0, 374.0, "/F0", 18.0, "BANG!", (0.2, 0.18, 0.05))[:])

  // Panel 3: diagonal caption
  ops.append(
    ops_text(
      90.0,
      130.0,
      "/F2",
      12.0,
      "Rotate text with OpTm",
      (0.15, 0.17, 0.2),
      rotate_rad=0.35,
    )[:],
  )
  ops
}

///|
fn stickers_ops() -> Array[@pdfops.Op] {
  let ops : Array[@pdfops.Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, 595.0, 842.0, (0.97, 0.98, 0.99))[:])
  ops.append(
    ops_text(54.0, 800.0, "/F0", 24.0, "Vector Stickers", (0.12, 0.14, 0.18))[:],
  )
  ops.append(
    ops_text(
      54.0,
      770.0,
      "/F1",
      13.0,
      "Everything here is rectangles, polylines, and polygons.",
      (0.25, 0.28, 0.32),
    )[:],
  )
  let centers : Array[(Double, Double, (Double, Double, Double))] = [
    (150.0, 600.0, (0.95, 0.3, 0.35)),
    (297.5, 600.0, (0.25, 0.55, 0.9)),
    (445.0, 600.0, (0.45, 0.75, 0.35)),
    (150.0, 380.0, (0.95, 0.75, 0.2)),
    (297.5, 380.0, (0.6, 0.35, 0.9)),
    (445.0, 380.0, (0.2, 0.7, 0.75)),
  ]
  for c in centers {
    let (cx, cy, accent) = c
    let outline = circle_points(cx, cy, 78.0, 50)
    ops.append(ops_fill_polygon(outline, (1.0, 1.0, 1.0))[:])
    ops.append(
      ops_stroke_polyline(outline + [outline[0]], (0.2, 0.22, 0.26), 1.5)[:],
    )
    ops.append(ops_fill_rect(cx - 78.0, cy + 70.0, 156.0, 8.0, accent)[:])
  }

  // Star sticker
  let star = Array::new(capacity=10)
  for i in 0..<10 {
    let t = 2.0 * pi() * (i.to_double() / 10.0) - pi() / 2.0
    let r = if i % 2 == 0 { 46.0 } else { 20.0 }
    star.push((150.0 + r * @math.cos(t), 600.0 + r * @math.sin(t)))
  }
  ops.append(ops_fill_polygon(star, (0.95, 0.75, 0.2))[:])

  // Heart sticker (two circles + triangle-ish)
  ops.append(
    ops_fill_polygon(circle_points(282.0, 615.0, 22.0, 30), (0.95, 0.3, 0.35))[:],
  )
  ops.append(
    ops_fill_polygon(circle_points(314.0, 615.0, 22.0, 30), (0.95, 0.3, 0.35))[:],
  )
  ops.append(
    ops_fill_polygon(
      [(264.0, 612.0), (332.0, 612.0), (298.0, 564.0)],
      (0.95, 0.3, 0.35),
    )[:],
  )

  // Lightning bolt sticker
  let bolt : Array[(Double, Double)] = [
    (445.0, 632.0),
    (420.0, 598.0),
    (444.0, 598.0),
    (416.0, 560.0),
    (468.0, 604.0),
    (444.0, 604.0),
  ]
  ops.append(ops_fill_polygon(bolt, (0.25, 0.55, 0.9))[:])
  ops
}

///|
fn credits_ops() -> Array[@pdfops.Op] {
  let ops : Array[@pdfops.Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, 595.0, 842.0, (0.06, 0.07, 0.1))[:])
  ops.append(
    ops_text(54.0, 790.0, "/F0", 26.0, "Credits / Links", (0.95, 0.96, 0.98))[:],
  )
  ops.append(
    ops_text(
      54.0,
      740.0,
      "/F1",
      14.0,
      "Generated entirely with mbtpdf + PDF content stream operators.",
      (0.8, 0.84, 0.9),
    )[:],
  )
  ops.append(
    ops_text(
      54.0,
      700.0,
      "/F2",
      12.0,
      "Click: https://docs.moonbitlang.com",
      (0.8, 0.84, 0.9),
    )[:],
  )
  ops.append(
    ops_text(
      54.0,
      90.0,
      "/F2",
      11.0,
      "Tip: if you modify this demo, run: moon info && moon fmt && moon test",
      (0.6, 0.64, 0.7),
    )[:],
  )
  ops
}

///|
fn page_of_ops(ops : Array[@pdfops.Op]) -> @pdfpage.Page raise {
  let stream = @pdfops.Op::stream_of_ops(ops)
  Page(
    content=[stream],
    mediabox=a4_mediabox(),
    resources=default_resources(),
    rotate=Rotate0,
    rest=Dictionary([]),
  )
}

///|
fn set_catalog_entry(
  pdf : @pdf.Pdf,
  key : String,
  value : @pdf.PdfObject,
) -> Unit raise {
  let rootnum = pdf.root
  let root = pdf.lookup_obj(rootnum)
  let updated_root = root.add_entry(key, value)
  pdf.addobj_given_num((rootnum, updated_root))
  pdf.trailerdict = pdf.trailerdict.add_entry("/Root", Indirect(rootnum))
}

///|
fn add_day_night_layers(pdf : @pdf.Pdf) -> @pdf.Pdf raise {
  let ocg_day : @pdf.PdfObject = Dictionary([
    ("/Type", Name(PdfName(b"/OCG"))),
    ("/Name", PdfString("DAY")),
  ])
  let ocg_night : @pdf.PdfObject = Dictionary([
    ("/Type", Name(PdfName(b"/OCG"))),
    ("/Name", PdfString("NIGHT")),
  ])
  let day_num = pdf.addobj(ocg_day)
  let night_num = pdf.addobj(ocg_night)
  let default_dict : @pdf.PdfObject = Dictionary([
    ("/BaseState", Name(PdfName(b"/ON"))),
    ("/Intent", Name(PdfName(b"/View"))),
    ("/Name", PdfString("Default")),
    ("/OFF", PdfArray([Indirect(night_num)])),
    ("/ON", PdfArray([Indirect(day_num)])),
  ])
  let ocprops : @pdf.PdfObject = Dictionary([
    ("/OCGs", PdfArray([Indirect(day_num), Indirect(night_num)])),
    ("/D", default_dict),
  ])
  let ocprops_num = pdf.addobj(ocprops)
  set_catalog_entry(pdf, "/OCProperties", Indirect(ocprops_num))
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  if pages.length() < 3 {
    return pdf
  }
  let layer_page = pages[2]
  let props : @pdf.PdfObject = Dictionary([
    ("/DAY", Indirect(day_num)),
    ("/NIGHT", Indirect(night_num)),
  ])
  let resources = layer_page.resources.add_entry("/Properties", props)
  pages[2] = Page(
    content=layer_page.content,
    mediabox=layer_page.mediabox,
    resources~,
    rotate=layer_page.rotate,
    rest=layer_page.rest,
  )
  @pdfpage.PdfPageDoc::new(pdf).change_pages(true, pages)
}

///|
fn add_bookmarks(pdf : @pdf.Pdf) -> @pdf.Pdf raise {
  let refs = pdf.page_reference_numbers()
  if refs.length() == 0 {
    return pdf
  }
  let marks : Array[@pdfmarks.Bookmark] = Array::new()
  let entries : Array[(String, Int)] = [
    ("Cover", 0),
    ("Procedural Spirograph", 1),
    ("DAY / NIGHT Layers", 2),
    ("Clickable Map", 3),
    ("Tiny PDF Comic", 4),
    ("Vector Stickers", 5),
    ("Credits / Links", 6),
  ]
  for entry in entries {
    let (title, idx) = entry
    if idx < refs.length() {
      marks.push({
        level: 0,
        text: title,
        target: Fit(PageObject(refs[idx])),
        isopen: true,
        colour: (0.0, 0.0, 0.0),
        flags: 0,
      })
    }
  }
  @pdfmarks.PdfMarks::new(pdf).add_bookmarks(marks)
}

///|
fn goto_action(refnum : Int) -> @pdf.PdfObject {
  let dest = @pdfdest.Destination::Fit(PageObject(refnum)).to_pdf_object()
  Dictionary([("/S", Name(PdfName(b"/GoTo"))), ("/D", dest)])
}

///|
fn uri_action(uri : String) -> @pdf.PdfObject {
  Dictionary([("/S", Name(PdfName(b"/URI"))), ("/URI", PdfString(uri))])
}

///|
fn add_nav_links(pdf : @pdf.Pdf) -> @pdf.Pdf raise {
  let refs = pdf.page_reference_numbers()
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  if pages.length() == 0 {
    return pdf
  }
  for i in 0..<pages.length() {
    let mut page = pages[i]
    let footer_y = 22.0
    let btn_w = 80.0
    let btn_h = 22.0

    // Prev
    if i > 0 {
      let prev_ref = refs[i - 1]
      let rect = (54.0, footer_y, 54.0 + btn_w, footer_y + btn_h)
      let annot : @pdfannot.Annotation = {
        subtype: Link,
        annot_contents: None,
        subject: None,
        rectangle: rect,
        border: @pdfannot.Border::new(0.0),
        colour: None,
        annotrest: Dictionary([("/A", goto_action(prev_ref))]),
      }
      page = @pdfannot.PdfAnnot::new(pdf).add_annotation(page, annot)
    }

    // Next
    if i + 1 < pages.length() {
      let next_ref = refs[i + 1]
      let rect = (
        595.0 - 54.0 - btn_w,
        footer_y,
        595.0 - 54.0,
        footer_y + btn_h,
      )
      let annot : @pdfannot.Annotation = {
        subtype: Link,
        annot_contents: None,
        subject: None,
        rectangle: rect,
        border: @pdfannot.Border::new(0.0),
        colour: None,
        annotrest: Dictionary([("/A", goto_action(next_ref))]),
      }
      page = @pdfannot.PdfAnnot::new(pdf).add_annotation(page, annot)
    }

    // Cover: add one external link over the URL string
    if i == pages.length() - 1 {
      let rect = (54.0, 696.0, 340.0, 716.0)
      let annot : @pdfannot.Annotation = {
        subtype: Link,
        annot_contents: None,
        subject: None,
        rectangle: rect,
        border: @pdfannot.Border::new(0.0),
        colour: None,
        annotrest: Dictionary([
          ("/A", uri_action("https://docs.moonbitlang.com")),
        ]),
      }
      page = @pdfannot.PdfAnnot::new(pdf).add_annotation(page, annot)
    }
    pages[i] = page
  }

  // Map page: clickable cards -> internal navigation.
  if pages.length() >= 7 {
    let map_i = 3
    let cards : Array[((Double, Double, Double, Double), Int)] = [
      ((54.0, 620.0, 285.0, 760.0), 1),
      ((310.0, 620.0, 541.0, 760.0), 2),
      ((54.0, 440.0, 285.0, 580.0), 4),
      ((310.0, 440.0, 541.0, 580.0), 5),
      ((54.0, 260.0, 285.0, 400.0), 6),
    ]
    let mut page = pages[map_i]
    for card in cards {
      let (rect, target) = card
      let annot : @pdfannot.Annotation = {
        subtype: Link,
        annot_contents: None,
        subject: None,
        rectangle: rect,
        border: @pdfannot.Border::new(0.0),
        colour: None,
        annotrest: Dictionary([("/A", goto_action(refs[target]))]),
      }
      page = @pdfannot.PdfAnnot::new(pdf).add_annotation(page, annot)
    }
    pages[map_i] = page
  }
  @pdfpage.PdfPageDoc::new(pdf).change_pages(true, pages)
}

///|
pub async fn run(
  out_file? : String = "showcase.pdf",
  quiet? : Bool = false,
) -> Unit {
  try {
    let pages : Array[@pdfpage.Page] = [
      page_of_ops(cover_ops()),
      page_of_ops(spiro_ops()),
      page_of_ops(layers_ops()),
      page_of_ops(map_ops()),
      page_of_ops(comic_ops()),
      page_of_ops(stickers_ops()),
      page_of_ops(credits_ops()),
    ]
    let (pdf, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree(
      pages,
    )
    let pdf = @pdfpage.PdfPageDoc::new(pdf).add_root(pageroot, [])
    let pdf = add_day_night_layers(pdf)
    let pdf = add_bookmarks(pdf)
    let pdf = add_nav_links(pdf)
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
  if args.length() == 2 {
    run(out_file=args[1])
  } else {
    run()
  }
}
