///|
type PdfObject = @pdf.PdfObject

///|
type Op = @pdfops.Op

///|
const CARD_W : Double = 420.0

///|
const CARD_H : Double = 560.0

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
fn card_x() -> Double {
  (w() - CARD_W) / 2.0
}

///|
fn card_y() -> Double {
  (h() - CARD_H) / 2.0
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
fn ops_rule(
  x0 : Double,
  y : Double,
  x1 : Double,
  rgb : (Double, Double, Double),
  width : Double,
) -> Array[Op] {
  let (r, g, b) = rgb
  [Opq, Opw(width), OpRG(r, g, b), Opm(x0, y), Opl(x1, y), OpS, OpQ]
}

///|
fn ops_checkbox(x : Double, y : Double) -> Array[Op] {
  ops_stroke_rect(x, y, 10.0, 10.0, (0.12, 0.14, 0.18), 1.6)
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
fn add_swaps_layer(pdf : @pdf.Pdf) -> Int raise {
  let swaps : PdfObject = Dictionary([
    ("/Type", Name(PdfName(b"/OCG"))),
    ("/Name", PdfString("SWAPS")),
  ])
  let swaps_num = pdf.addobj(swaps)
  let default_dict : PdfObject = Dictionary([
    ("/BaseState", Name(PdfName(b"/ON"))),
    ("/Intent", Name(PdfName(b"/View"))),
    ("/Name", PdfString("Default")),
    ("/OFF", PdfArray([Indirect(swaps_num)])),
  ])
  let ocprops : PdfObject = Dictionary([
    ("/OCGs", PdfArray([Indirect(swaps_num)])),
    ("/D", default_dict),
  ])
  let ocprops_num = pdf.addobj(ocprops)
  set_catalog_entry(pdf, "/OCProperties", Indirect(ocprops_num))
  swaps_num
}

///|
fn add_layer_properties_to_pages(
  pdf : @pdf.Pdf,
  swaps_num : Int,
) -> @pdf.Pdf raise {
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  for i in 0..<pages.length() {
    let page = pages[i]
    let props : PdfObject = Dictionary([("/SWAPS", Indirect(swaps_num))])
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
    "Cover", "Mug Cake (front)", "Mug Cake (back)", "Fruit Parfait (front)", "Fruit Parfait (back)",
    "Energy Bites (front)", "Energy Bites (back)", "The End",
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
fn home_rect() -> (Double, Double, Double, Double) {
  let x0 = card_x() + CARD_W - 114.0
  let y0 = card_y() + CARD_H - 46.0
  (x0, y0, x0 + 90.0, y0 + 32.0)
}

///|
fn flip_rect() -> (Double, Double, Double, Double) {
  let x0 = card_x() + CARD_W - 128.0
  let y0 = card_y() + 24.0
  (x0, y0, x0 + 104.0, y0 + 32.0)
}

///|
fn video_rect() -> (Double, Double, Double, Double) {
  let x0 = card_x() + 24.0
  let y0 = card_y() + 24.0
  (x0, y0, x0 + 154.0, y0 + 32.0)
}

///|
fn ops_badge(
  rect : (Double, Double, Double, Double),
  label : String,
  accent : (Double, Double, Double),
) -> Array[Op] {
  let (x0, y0, x1, y1) = rect
  let ww = x1 - x0
  let hh = y1 - y0
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(x0, y0, ww, hh, (1.0, 1.0, 1.0))[:])
  ops.append(ops_stroke_rect(x0, y0, ww, hh, accent, 2.0)[:])
  ops.append(ops_fill_rect(x0, y0 + hh - 5.0, ww, 5.0, accent)[:])
  ops.append(
    ops_text(x0 + 10.0, y0 + 11.0, "/F0", 12.0, label, (0.12, 0.14, 0.18))[:],
  )
  ops
}

///|
fn card_frame_ops(
  title : String,
  subtitle : String,
  accent : (Double, Double, Double),
) -> Array[Op] {
  let cx = card_x()
  let cy = card_y()
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, w(), h(), (0.98, 0.98, 0.99))[:])
  ops.append(ops_fill_rect(cx, cy, CARD_W, CARD_H, (1.0, 1.0, 1.0))[:])
  ops.append(
    ops_stroke_rect(cx, cy, CARD_W, CARD_H, (0.12, 0.14, 0.18), 3.0)[:],
  )
  ops.append(ops_fill_rect(cx, cy + CARD_H - 76.0, CARD_W, 76.0, accent)[:])
  ops.append(
    ops_text(cx + 24.0, cy + CARD_H - 40.0, "/F0", 28.0, title, (1.0, 1.0, 1.0))[:],
  )
  ops.append(
    ops_text(
      cx + 24.0,
      cy + CARD_H - 62.0,
      "/F1",
      12.0,
      subtitle,
      (0.92, 0.94, 0.98),
    )[:],
  )
  ops.append(ops_badge(home_rect(), "HOME", accent)[:])
  ops.append(ops_badge(video_rect(), "OPEN VIDEO", (0.92, 0.33, 0.36))[:])
  ops.append(ops_badge(flip_rect(), "FLIP", (0.18, 0.48, 0.86))[:])
  ops
}

///|
fn cover_ops() -> (Array[Op], Array[(Double, Double, Double, Double)]) {
  let cx = card_x()
  let cy = card_y()
  let accent = (0.18, 0.48, 0.86)
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, w(), h(), (0.06, 0.07, 0.1))[:])
  ops.append(ops_fill_rect(cx, cy, CARD_W, CARD_H, (1.0, 1.0, 1.0))[:])
  ops.append(
    ops_stroke_rect(cx, cy, CARD_W, CARD_H, (0.12, 0.14, 0.18), 3.0)[:],
  )
  ops.append(ops_fill_rect(cx, cy + CARD_H - 96.0, CARD_W, 96.0, accent)[:])
  ops.append(
    ops_text(
      cx + 24.0,
      cy + CARD_H - 46.0,
      "/F0",
      34.0,
      "Recipe Cards",
      (1.0, 1.0, 1.0),
    )[:],
  )
  ops.append(
    ops_text(
      cx + 24.0,
      cy + CARD_H - 72.0,
      "/F1",
      14.0,
      "Tap a card to open. Print & share.",
      (0.92, 0.94, 0.98),
    )[:],
  )
  ops.append(
    ops_text(
      cx + 24.0,
      cy + 54.0,
      "/F1",
      12.0,
      "Tip: toggle SWAPS in Layers for substitutions.",
      (0.45, 0.48, 0.52),
    )[:],
  )
  fn big_btn(
    y : Double,
    label : String,
    accent2 : (Double, Double, Double),
  ) -> (Array[Op], (Double, Double, Double, Double)) {
    let ww = CARD_W - 48.0
    let hh = 66.0
    let x = cx + 24.0
    let (r, g, b) = accent2
    let o : Array[Op] = Array::new()
    o.append(ops_fill_rect(x, y, ww, hh, (1.0, 1.0, 1.0))[:])
    o.append(ops_stroke_rect(x, y, ww, hh, accent2, 2.5)[:])
    o.append(ops_fill_rect(x, y + hh - 8.0, ww, 8.0, accent2)[:])
    o.append(
      ops_text(x + 18.0, y + 20.0, "/F0", 18.0, label, (0.12, 0.14, 0.18))[:],
    )
    o.append(ops_text(x + 18.0, y + 8.0, "/F2", 10.0, "CLICK", (r, g, b))[:])
    (o, (x, y, x + ww, y + hh))
  }

  let rects : Array[(Double, Double, Double, Double)] = Array::new()
  let (b1, r1) = big_btn(
    cy + CARD_H - 220.0,
    "1) Chocolate Mug Cake",
    (0.92, 0.33, 0.36),
  )
  let (b2, r2) = big_btn(
    cy + CARD_H - 310.0,
    "2) Rainbow Fruit Parfait",
    (0.18, 0.66, 0.52),
  )
  let (b3, r3) = big_btn(
    cy + CARD_H - 400.0,
    "3) No-Bake Energy Bites",
    (0.52, 0.4, 0.86),
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
fn mugcake_front_ops() -> Array[Op] {
  let accent = (0.92, 0.33, 0.36)
  let cx = card_x()
  let cy = card_y()
  let ops = card_frame_ops("Mug Cake", "5 min - 1 mug - cozy dessert", accent)
  let out = ops
  out.append(
    ops_text(
      cx + 24.0,
      cy + CARD_H - 108.0,
      "/F1",
      12.0,
      "Ingredients (check as you go):",
      (0.12, 0.14, 0.18),
    )[:],
  )
  let items : Array[String] = [
    "4 tbsp flour", "2 tbsp sugar", "2 tbsp cocoa", "1/4 tsp baking powder", "5 tbsp milk",
    "2 tbsp oil",
  ]
  let mut y = cy + CARD_H - 140.0
  for it in items {
    out.append(ops_checkbox(cx + 26.0, y)[:])
    out.append(
      ops_text(cx + 42.0, y + 1.0, "/F1", 12.0, it, (0.12, 0.14, 0.18))[:],
    )
    y = y - 20.0
  }

  // Little mug doodle
  out.append(
    ops_stroke_rect(
      cx + 260.0,
      cy + CARD_H - 260.0,
      110.0,
      90.0,
      (0.12, 0.14, 0.18),
      3.0,
    )[:],
  )
  out.append(
    ops_stroke_rect(
      cx + 350.0,
      cy + CARD_H - 240.0,
      34.0,
      50.0,
      (0.12, 0.14, 0.18),
      3.0,
    )[:],
  )
  out.append(
    ops_rule(
      cx + 272.0,
      cy + CARD_H - 188.0,
      cx + 358.0,
      (0.12, 0.14, 0.18),
      2.0,
    )[:],
  )
  out.append(
    ops_text(cx + 268.0, cy + CARD_H - 176.0, "/F2", 10.0, "MUG", accent)[:],
  )
  out.append(
    ops_text(
      cx + 24.0,
      cy + 92.0,
      "/F1",
      12.0,
      "Flip for steps. Tap OPEN VIDEO for a quick demo.",
      (0.45, 0.48, 0.52),
    )[:],
  )

  // SWAPS layer
  out.push(OpBDC("/OC", Name(PdfName(b"/SWAPS"))))
  out.append(
    ops_fill_rect(cx + 24.0, cy + 124.0, CARD_W - 48.0, 68.0, (1.0, 0.97, 0.9))[:],
  )
  out.append(
    ops_stroke_rect(cx + 24.0, cy + 124.0, CARD_W - 48.0, 68.0, accent, 1.5)[:],
  )
  out.append(
    ops_text(cx + 34.0, cy + 170.0, "/F0", 12.0, "SWAPS", (0.12, 0.14, 0.18))[:],
  )
  out.append(
    ops_text(
      cx + 34.0,
      cy + 152.0,
      "/F1",
      11.0,
      "- Dairy-free: use oat milk",
      (0.12, 0.14, 0.18),
    )[:],
  )
  out.append(
    ops_text(
      cx + 34.0,
      cy + 136.0,
      "/F1",
      11.0,
      "- No egg needed (it's a mug cake!)",
      (0.12, 0.14, 0.18),
    )[:],
  )
  out.push(OpEMC)
  out
}

///|
fn mugcake_back_ops() -> Array[Op] {
  let accent = (0.92, 0.33, 0.36)
  let cx = card_x()
  let cy = card_y()
  let out = card_frame_ops("Mug Cake", "Steps - microwave magic", accent)
  out.append(
    ops_text(
      cx + 24.0,
      cy + CARD_H - 118.0,
      "/F0",
      16.0,
      "Steps",
      (0.12, 0.14, 0.18),
    )[:],
  )
  let steps : Array[String] = [
    "1) Mix dry ingredients in the mug.", "2) Add milk + oil; stir smooth.", "3) Microwave 60-90s (watch it rise!).",
    "4) Cool 1 min. Add sprinkles. Enjoy.",
  ]
  let mut y = cy + CARD_H - 150.0
  for s in steps {
    out.append(ops_text(cx + 24.0, y, "/F1", 12.0, s, (0.12, 0.14, 0.18))[:])
    y = y - 20.0
  }
  out.append(
    ops_text(cx + 24.0, cy + 260.0, "/F0", 14.0, "Notes", (0.12, 0.14, 0.18))[:],
  )
  for i in 0..<7 {
    let yy = cy + 240.0 - i.to_double() * 18.0
    out.append(
      ops_rule(cx + 24.0, yy, cx + CARD_W - 24.0, (0.78, 0.8, 0.84), 1.0)[:],
    )
  }
  out.push(OpBDC("/OC", Name(PdfName(b"/SWAPS"))))
  out.append(
    ops_text(
      cx + 24.0,
      cy + 98.0,
      "/F2",
      10.0,
      "SWAPS ON: try cinnamon, peanut butter, or espresso powder.",
      accent,
    )[:],
  )
  out.push(OpEMC)
  out
}

///|
fn parfait_front_ops() -> Array[Op] {
  let accent = (0.18, 0.66, 0.52)
  let cx = card_x()
  let cy = card_y()
  let out = card_frame_ops(
    "Fruit Parfait", "bright - crunchy - no cooking", accent,
  )
  out.append(
    ops_text(
      cx + 24.0,
      cy + CARD_H - 108.0,
      "/F1",
      12.0,
      "Ingredients:",
      (0.12, 0.14, 0.18),
    )[:],
  )
  let items : Array[String] = [
    "yogurt", "berries", "banana", "granola", "honey (optional)",
  ]
  let mut y = cy + CARD_H - 140.0
  for it in items {
    out.append(ops_checkbox(cx + 26.0, y)[:])
    out.append(
      ops_text(cx + 42.0, y + 1.0, "/F1", 12.0, it, (0.12, 0.14, 0.18))[:],
    )
    y = y - 20.0
  }

  // Simple jar doodle
  out.append(
    ops_stroke_rect(
      cx + 260.0,
      cy + CARD_H - 270.0,
      110.0,
      130.0,
      (0.12, 0.14, 0.18),
      3.0,
    )[:],
  )
  out.append(
    ops_rule(cx + 260.0, cy + CARD_H - 236.0, cx + 370.0, accent, 5.0)[:],
  )
  out.append(
    ops_rule(
      cx + 260.0,
      cy + CARD_H - 206.0,
      cx + 370.0,
      (0.95, 0.75, 0.2),
      5.0,
    )[:],
  )
  out.append(
    ops_rule(cx + 260.0, cy + CARD_H - 176.0, cx + 370.0, accent, 5.0)[:],
  )
  out.append(
    ops_text(
      cx + 276.0,
      cy + CARD_H - 160.0,
      "/F2",
      10.0,
      "LAYER",
      (0.12, 0.14, 0.18),
    )[:],
  )
  out.push(OpBDC("/OC", Name(PdfName(b"/SWAPS"))))
  out.append(
    ops_fill_rect(cx + 24.0, cy + 124.0, CARD_W - 48.0, 68.0, (0.92, 1.0, 0.95))[:],
  )
  out.append(
    ops_stroke_rect(cx + 24.0, cy + 124.0, CARD_W - 48.0, 68.0, accent, 1.5)[:],
  )
  out.append(
    ops_text(cx + 34.0, cy + 170.0, "/F0", 12.0, "SWAPS", (0.12, 0.14, 0.18))[:],
  )
  out.append(
    ops_text(
      cx + 34.0,
      cy + 152.0,
      "/F1",
      11.0,
      "- Dairy-free: coconut yogurt",
      (0.12, 0.14, 0.18),
    )[:],
  )
  out.append(
    ops_text(
      cx + 34.0,
      cy + 136.0,
      "/F1",
      11.0,
      "- Crunch: toasted nuts instead of granola",
      (0.12, 0.14, 0.18),
    )[:],
  )
  out.push(OpEMC)
  out
}

///|
fn parfait_back_ops() -> Array[Op] {
  let accent = (0.18, 0.66, 0.52)
  let cx = card_x()
  let cy = card_y()
  let out = card_frame_ops(
    "Fruit Parfait", "Steps - build a tiny rainbow", accent,
  )
  let steps : Array[String] = [
    "1) Spoon yogurt into a cup.", "2) Add fruit. Add granola.", "3) Repeat for 2-3 layers.",
    "4) Drizzle honey. Serve cold.",
  ]
  out.append(
    ops_text(
      cx + 24.0,
      cy + CARD_H - 118.0,
      "/F0",
      16.0,
      "Steps",
      (0.12, 0.14, 0.18),
    )[:],
  )
  let mut y = cy + CARD_H - 150.0
  for s in steps {
    out.append(ops_text(cx + 24.0, y, "/F1", 12.0, s, (0.12, 0.14, 0.18))[:])
    y = y - 20.0
  }
  out.append(
    ops_text(cx + 24.0, cy + 260.0, "/F0", 14.0, "Notes", (0.12, 0.14, 0.18))[:],
  )
  for i in 0..<7 {
    let yy = cy + 240.0 - i.to_double() * 18.0
    out.append(
      ops_rule(cx + 24.0, yy, cx + CARD_W - 24.0, (0.78, 0.8, 0.84), 1.0)[:],
    )
  }
  out.push(OpBDC("/OC", Name(PdfName(b"/SWAPS"))))
  out.append(
    ops_text(
      cx + 24.0,
      cy + 98.0,
      "/F2",
      10.0,
      "SWAPS ON: frozen fruit works great; thaw a little first.",
      accent,
    )[:],
  )
  out.push(OpEMC)
  out
}

///|
fn bites_front_ops() -> Array[Op] {
  let accent = (0.52, 0.4, 0.86)
  let cx = card_x()
  let cy = card_y()
  let out = card_frame_ops(
    "Energy Bites", "no-bake - snackable - shareable", accent,
  )
  out.append(
    ops_text(
      cx + 24.0,
      cy + CARD_H - 108.0,
      "/F1",
      12.0,
      "Ingredients:",
      (0.12, 0.14, 0.18),
    )[:],
  )
  let items : Array[String] = [
    "1 cup oats", "1/2 cup peanut butter", "1/3 cup honey", "2 tbsp cocoa (optional)",
    "sprinkles or coconut",
  ]
  let mut y = cy + CARD_H - 140.0
  for it in items {
    out.append(ops_checkbox(cx + 26.0, y)[:])
    out.append(
      ops_text(cx + 42.0, y + 1.0, "/F1", 12.0, it, (0.12, 0.14, 0.18))[:],
    )
    y = y - 20.0
  }

  // Bite doodles (three dots)
  out.append(
    ops_stroke_rect(
      cx + 272.0,
      cy + CARD_H - 256.0,
      92.0,
      92.0,
      (0.12, 0.14, 0.18),
      3.0,
    )[:],
  )
  out.append(
    ops_fill_rect(cx + 292.0, cy + CARD_H - 232.0, 12.0, 12.0, accent)[:],
  )
  out.append(
    ops_fill_rect(
      cx + 324.0,
      cy + CARD_H - 214.0,
      12.0,
      12.0,
      (0.95, 0.75, 0.2),
    )[:],
  )
  out.append(
    ops_fill_rect(
      cx + 310.0,
      cy + CARD_H - 246.0,
      12.0,
      12.0,
      (0.18, 0.66, 0.52),
    )[:],
  )
  out.append(
    ops_text(
      cx + 286.0,
      cy + CARD_H - 168.0,
      "/F2",
      10.0,
      "BITE",
      (0.12, 0.14, 0.18),
    )[:],
  )
  out.push(OpBDC("/OC", Name(PdfName(b"/SWAPS"))))
  out.append(
    ops_fill_rect(cx + 24.0, cy + 124.0, CARD_W - 48.0, 68.0, (0.96, 0.93, 1.0))[:],
  )
  out.append(
    ops_stroke_rect(cx + 24.0, cy + 124.0, CARD_W - 48.0, 68.0, accent, 1.5)[:],
  )
  out.append(
    ops_text(cx + 34.0, cy + 170.0, "/F0", 12.0, "SWAPS", (0.12, 0.14, 0.18))[:],
  )
  out.append(
    ops_text(
      cx + 34.0,
      cy + 152.0,
      "/F1",
      11.0,
      "- Nut-free: sunflower seed butter",
      (0.12, 0.14, 0.18),
    )[:],
  )
  out.append(
    ops_text(
      cx + 34.0,
      cy + 136.0,
      "/F1",
      11.0,
      "- Less sweet: halve honey; add a splash of milk",
      (0.12, 0.14, 0.18),
    )[:],
  )
  out.push(OpEMC)
  out
}

///|
fn bites_back_ops() -> Array[Op] {
  let accent = (0.52, 0.4, 0.86)
  let cx = card_x()
  let cy = card_y()
  let out = card_frame_ops("Energy Bites", "Steps - mix, roll, chill", accent)
  let steps : Array[String] = [
    "1) Stir everything in a bowl.", "2) Chill 10 min (less sticky).", "3) Roll into bite-size balls.",
    "4) Refrigerate. Snack happy.",
  ]
  out.append(
    ops_text(
      cx + 24.0,
      cy + CARD_H - 118.0,
      "/F0",
      16.0,
      "Steps",
      (0.12, 0.14, 0.18),
    )[:],
  )
  let mut y = cy + CARD_H - 150.0
  for s in steps {
    out.append(ops_text(cx + 24.0, y, "/F1", 12.0, s, (0.12, 0.14, 0.18))[:])
    y = y - 20.0
  }
  out.append(
    ops_text(cx + 24.0, cy + 260.0, "/F0", 14.0, "Notes", (0.12, 0.14, 0.18))[:],
  )
  for i in 0..<7 {
    let yy = cy + 240.0 - i.to_double() * 18.0
    out.append(
      ops_rule(cx + 24.0, yy, cx + CARD_W - 24.0, (0.78, 0.8, 0.84), 1.0)[:],
    )
  }
  out.push(OpBDC("/OC", Name(PdfName(b"/SWAPS"))))
  out.append(
    ops_text(
      cx + 24.0,
      cy + 98.0,
      "/F2",
      10.0,
      "SWAPS ON: add chia seeds or mini chocolate chips.",
      accent,
    )[:],
  )
  out.push(OpEMC)
  out
}

///|
fn end_ops() -> Array[Op] {
  let cx = card_x()
  let cy = card_y()
  let accent = (0.18, 0.48, 0.86)
  let out : Array[Op] = Array::new()
  out.append(ops_fill_rect(0.0, 0.0, w(), h(), (0.06, 0.07, 0.1))[:])
  out.append(ops_fill_rect(cx, cy, CARD_W, CARD_H, (1.0, 1.0, 1.0))[:])
  out.append(
    ops_stroke_rect(cx, cy, CARD_W, CARD_H, (0.12, 0.14, 0.18), 3.0)[:],
  )
  out.append(ops_fill_rect(cx, cy + CARD_H - 96.0, CARD_W, 96.0, accent)[:])
  out.append(
    ops_text(
      cx + 24.0,
      cy + CARD_H - 46.0,
      "/F0",
      34.0,
      "Bon appetit!",
      (1.0, 1.0, 1.0),
    )[:],
  )
  out.append(
    ops_text(
      cx + 24.0,
      cy + CARD_H - 72.0,
      "/F1",
      14.0,
      "Print, share, remix, and make your own cards.",
      (0.92, 0.94, 0.98),
    )[:],
  )
  out.append(
    ops_text(
      cx + 24.0,
      cy + 220.0,
      "/F1",
      12.0,
      "Each button is a PDF link annotation (GoTo/URI).",
      (0.12, 0.14, 0.18),
    )[:],
  )
  out.append(
    ops_text(
      cx + 24.0,
      cy + 200.0,
      "/F1",
      12.0,
      "SWAPS is an optional layer (off by default).",
      (0.12, 0.14, 0.18),
    )[:],
  )
  out.append(
    ops_badge(
      (cx + 24.0, cy + 120.0, cx + 220.0, cy + 152.0),
      "BACK TO COVER",
      accent,
    )[:],
  )
  out
}

///|
/// Generate an interactive set of printable recipe cards.
///
/// Features:
/// - Clickable "HOME", "FLIP", and "OPEN VIDEO" badges
/// - Bookmarks for quick navigation
/// - Optional `SWAPS` layer (default hidden) with substitutions
pub async fn run(
  out_file? : String = "recipes.pdf",
  quiet? : Bool = false,
) -> Unit {
  try {
    let (cover, cover_rects) = cover_ops()
    let pages : Array[@pdfpage.Page] = [
      page_of_ops(cover),
      page_of_ops(mugcake_front_ops()),
      page_of_ops(mugcake_back_ops()),
      page_of_ops(parfait_front_ops()),
      page_of_ops(parfait_back_ops()),
      page_of_ops(bites_front_ops()),
      page_of_ops(bites_back_ops()),
      page_of_ops(end_ops()),
    ]
    let (pdf, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree(
      pages,
    )
    let pdf = @pdfpage.PdfPageDoc::new(pdf).add_root(pageroot, [])
    let swaps_num = add_swaps_layer(pdf)
    let pdf = add_layer_properties_to_pages(pdf, swaps_num)
    let refs = pdf.page_reference_numbers()
    let pdf = add_bookmarks(pdf, refs)

    // Navigation links
    let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
    let out_pages = pages

    // Cover buttons: 3 recipes
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
      goto_action(refs[3]),
    )
    out_pages[0] = add_link(
      pdf,
      out_pages[0],
      cover_rects[2],
      goto_action(refs[5]),
    )

    // Card buttons
    let home = home_rect()
    let flip = flip_rect()
    let video = video_rect()
    let video_uri = uri_action("https://example.com")
    fn add_card_links(
      pdf : @pdf.Pdf,
      page : @pdfpage.Page,
      home : (Double, Double, Double, Double),
      flip : (Double, Double, Double, Double),
      video : (Double, Double, Double, Double),
      home_ref : Int,
      flip_ref : Int,
      uri : PdfObject,
    ) -> @pdfpage.Page raise {
      let mut p = page
      p = add_link(pdf, p, home, goto_action(home_ref))
      p = add_link(pdf, p, flip, goto_action(flip_ref))
      p = add_link(pdf, p, video, uri)
      p
    }

    // Mug cake: 1 <-> 2
    out_pages[1] = add_card_links(
      pdf,
      out_pages[1],
      home,
      flip,
      video,
      refs[0],
      refs[2],
      video_uri,
    )
    out_pages[2] = add_card_links(
      pdf,
      out_pages[2],
      home,
      flip,
      video,
      refs[0],
      refs[1],
      video_uri,
    )

    // Parfait: 3 <-> 4
    out_pages[3] = add_card_links(
      pdf,
      out_pages[3],
      home,
      flip,
      video,
      refs[0],
      refs[4],
      video_uri,
    )
    out_pages[4] = add_card_links(
      pdf,
      out_pages[4],
      home,
      flip,
      video,
      refs[0],
      refs[3],
      video_uri,
    )

    // Bites: 5 <-> 6
    out_pages[5] = add_card_links(
      pdf,
      out_pages[5],
      home,
      flip,
      video,
      refs[0],
      refs[6],
      video_uri,
    )
    out_pages[6] = add_card_links(
      pdf,
      out_pages[6],
      home,
      flip,
      video,
      refs[0],
      refs[5],
      video_uri,
    )

    // End: back to cover
    let end_back_rect = (
      card_x() + 24.0,
      card_y() + 120.0,
      card_x() + 220.0,
      card_y() + 152.0,
    )
    out_pages[7] = add_link(
      pdf,
      out_pages[7],
      end_back_rect,
      goto_action(refs[0]),
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
