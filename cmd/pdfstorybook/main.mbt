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
fn ops_line(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  rgb : (Double, Double, Double),
  width : Double,
) -> Array[Op] {
  let (r, g, b) = rgb
  [Opq, Opw(width), OpRG(r, g, b), Opm(x0, y0), Opl(x1, y1), OpS, OpQ]
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
fn ops_robot(cx : Double, cy : Double, s : Double) -> Array[Op] {
  let ops : Array[Op] = Array::new()
  let body_w = 140.0 * s
  let body_h = 160.0 * s
  let head_w = 160.0 * s
  let head_h = 90.0 * s

  // Shadow
  ops.append(
    ops_fill_rect(
      cx - body_w / 2.0,
      cy - 18.0 * s,
      body_w,
      10.0 * s,
      (0.88, 0.9, 0.92),
    )[:],
  )

  // Body
  ops.append(
    ops_fill_rect(cx - body_w / 2.0, cy, body_w, body_h, (0.92, 0.95, 0.98))[:],
  )
  ops.append(
    ops_stroke_rect(
      cx - body_w / 2.0,
      cy,
      body_w,
      body_h,
      (0.2, 0.22, 0.26),
      2.0,
    )[:],
  )

  // Head
  ops.append(
    ops_fill_rect(
      cx - head_w / 2.0,
      cy + body_h + 16.0 * s,
      head_w,
      head_h,
      (1.0, 1.0, 1.0),
    )[:],
  )
  ops.append(
    ops_stroke_rect(
      cx - head_w / 2.0,
      cy + body_h + 16.0 * s,
      head_w,
      head_h,
      (0.2, 0.22, 0.26),
      2.0,
    )[:],
  )

  // Antenna
  ops.append(
    ops_line(
      cx,
      cy + body_h + 16.0 * s + head_h,
      cx,
      cy + body_h + 16.0 * s + head_h + 30.0 * s,
      (0.2, 0.22, 0.26),
      2.0,
    )[:],
  )
  ops.append(
    ops_fill_rect(
      cx - 5.0 * s,
      cy + body_h + 16.0 * s + head_h + 30.0 * s,
      10.0 * s,
      10.0 * s,
      (0.92, 0.33, 0.36),
    )[:],
  )

  // Eyes
  ops.append(
    ops_fill_rect(
      cx - 50.0 * s,
      cy + body_h + 16.0 * s + 34.0 * s,
      34.0 * s,
      14.0 * s,
      (0.18, 0.48, 0.86),
    )[:],
  )
  ops.append(
    ops_fill_rect(
      cx + 16.0 * s,
      cy + body_h + 16.0 * s + 34.0 * s,
      34.0 * s,
      14.0 * s,
      (0.18, 0.48, 0.86),
    )[:],
  )

  // Chest panel
  ops.append(
    ops_fill_rect(
      cx - 46.0 * s,
      cy + 80.0 * s,
      92.0 * s,
      44.0 * s,
      (1.0, 1.0, 1.0),
    )[:],
  )
  ops.append(
    ops_stroke_rect(
      cx - 46.0 * s,
      cy + 80.0 * s,
      92.0 * s,
      44.0 * s,
      (0.78, 0.8, 0.84),
      1.0,
    )[:],
  )
  ops.append(
    ops_fill_rect(
      cx - 36.0 * s,
      cy + 92.0 * s,
      20.0 * s,
      12.0 * s,
      (0.92, 0.33, 0.36),
    )[:],
  )
  ops.append(
    ops_fill_rect(
      cx - 10.0 * s,
      cy + 92.0 * s,
      20.0 * s,
      12.0 * s,
      (0.18, 0.48, 0.86),
    )[:],
  )
  ops.append(
    ops_fill_rect(
      cx + 16.0 * s,
      cy + 92.0 * s,
      20.0 * s,
      12.0 * s,
      (0.22, 0.7, 0.5),
    )[:],
  )
  ops
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
fn add_spoilers_layer(pdf : @pdf.Pdf) -> Int raise {
  let ocg : PdfObject = Dictionary([
    ("/Type", Name(PdfName(b"/OCG"))),
    ("/Name", PdfString("SPOILERS")),
  ])
  let ocg_num = pdf.addobj(ocg)
  let default_dict : PdfObject = Dictionary([
    ("/BaseState", Name(PdfName(b"/OFF"))),
    ("/Intent", Name(PdfName(b"/View"))),
    ("/Name", PdfString("Default")),
  ])
  let ocprops : PdfObject = Dictionary([
    ("/OCGs", PdfArray([Indirect(ocg_num)])),
    ("/D", default_dict),
  ])
  let ocprops_num = pdf.addobj(ocprops)
  set_catalog_entry(pdf, "/OCProperties", Indirect(ocprops_num))
  ocg_num
}

///|
fn add_spoilers_properties_to_pages(
  pdf : @pdf.Pdf,
  ocg_num : Int,
) -> @pdf.Pdf raise {
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  for i in 0..<pages.length() {
    let page = pages[i]
    let props : PdfObject = Dictionary([("/SPOILERS", Indirect(ocg_num))])
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
  let entries : Array[(String, Int)] = [
    ("Cover", 0),
    ("Map", 1),
    ("Crossroads", 2),
    ("Forest", 3),
    ("City", 4),
    ("Cave", 5),
    ("Museum", 6),
    ("The End", 7),
  ]
  for e in entries {
    let (name, idx) = e
    if idx < refs.length() {
      marks.push({
        level: 0,
        text: name,
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
fn cover_ops() -> (Array[Op], (Double, Double, Double, Double)) {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, w(), h(), (0.97, 0.98, 0.99))[:])
  ops.append(ops_fill_rect(0.0, h() - 120.0, w(), 120.0, (0.18, 0.48, 0.86))[:])
  ops.append(
    ops_text(
      72.0,
      h() - 74.0,
      "/F0",
      44.0,
      "The Button Kingdom",
      (1.0, 1.0, 1.0),
    )[:],
  )
  ops.append(
    ops_text(
      72.0,
      h() - 106.0,
      "/F1",
      16.0,
      "A tiny choose-your-own-adventure PDF",
      (0.92, 0.94, 0.98),
    )[:],
  )
  ops.append(ops_robot(w() - 220.0, 140.0, 1.0)[:])
  ops.append(
    ops_text(
      72.0,
      210.0,
      "/F1",
      18.0,
      "Click to start. No spoilers... unless you enable the SPOILERS layer.",
      (0.12, 0.14, 0.18),
    )[:],
  )
  let (btn_ops, rect) = ops_button(
    72.0,
    80.0,
    260.0,
    62.0,
    "Start the story",
    (0.92, 0.33, 0.36),
  )
  ops.append(btn_ops[:])
  (ops, rect)
}

///|
fn map_ops() -> (Array[Op], Array[(Int, (Double, Double, Double, Double))]) {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, w(), h(), (0.99, 0.985, 0.97))[:])
  ops.append(
    ops_text(72.0, h() - 70.0, "/F0", 36.0, "Map", (0.12, 0.14, 0.18))[:],
  )
  ops.append(
    ops_text(
      72.0,
      h() - 102.0,
      "/F1",
      16.0,
      "Pick a scene (they’re clickable).",
      (0.45, 0.48, 0.52),
    )[:],
  )
  let cards : Array[(String, Int, Double, Double, (Double, Double, Double))] = [
    ("Crossroads", 2, 72.0, 310.0, (0.18, 0.48, 0.86)),
    ("Forest", 3, 372.0, 310.0, (0.22, 0.7, 0.5)),
    ("City", 4, 72.0, 190.0, (0.92, 0.33, 0.36)),
    ("Cave", 5, 372.0, 190.0, (0.4, 0.45, 0.55)),
    ("Museum", 6, 72.0, 70.0, (0.7, 0.45, 0.9)),
    ("The End", 7, 372.0, 70.0, (0.92, 0.75, 0.2)),
  ]
  let links : Array[(Int, (Double, Double, Double, Double))] = Array::new()
  for c in cards {
    let (title, page_i, x, y, accent) = c
    let (btn_ops, rect) = ops_button(x, y, 260.0, 88.0, title, accent)
    ops.append(btn_ops[:])
    links.push((page_i, rect))
  }
  ops.push(OpBDC("/OC", Name(PdfName(b"/SPOILERS"))))
  ops.append(
    ops_text(
      72.0,
      22.0,
      "/F2",
      11.0,
      "SPOILERS: Best path is Crossroads → Forest → Cave → The End.",
      (0.2, 0.18, 0.05),
    )[:],
  )
  ops.push(OpEMC)
  (ops, links)
}

///|
fn scene_ops(
  title : String,
  subtitle : String,
  accent : (Double, Double, Double),
  body : Array[String],
  choices : Array[(String, Int)],
) -> (Array[Op], Array[(Int, (Double, Double, Double, Double))]) {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, w(), h(), (0.985, 0.985, 0.99))[:])
  ops.append(ops_fill_rect(0.0, h() - 84.0, w(), 84.0, accent)[:])
  ops.append(ops_text(72.0, h() - 52.0, "/F0", 30.0, title, (1.0, 1.0, 1.0))[:])
  ops.append(
    ops_text(72.0, h() - 74.0, "/F1", 14.0, subtitle, (0.92, 0.94, 0.98))[:],
  )
  ops.append(ops_robot(w() - 240.0, 110.0, 0.9)[:])
  let mut y = h() - 140.0
  for line in body {
    ops.append(ops_text(72.0, y, "/F1", 18.0, line, (0.12, 0.14, 0.18))[:])
    y = y - 28.0
  }
  let links : Array[(Int, (Double, Double, Double, Double))] = Array::new()
  let mut by = 70.0
  for ch in choices {
    let (label, target) = ch
    let (btn_ops, rect) = ops_button(
      72.0,
      by,
      520.0,
      56.0,
      label,
      (0.92, 0.33, 0.36),
    )
    ops.append(btn_ops[:])
    links.push((target, rect))
    by = by + 70.0
  }

  // Always-visible “Map” button.
  let (map_ops, map_rect) = ops_button(
    w() - 220.0,
    h() - 74.0,
    180.0,
    46.0,
    "Map",
    (1.0, 1.0, 1.0),
  )
  ops.append(map_ops[:])
  links.push((1, map_rect))
  (ops, links)
}

///|
pub async fn run(
  out_file? : String = "storybook.pdf",
  quiet? : Bool = false,
) -> Unit {
  try {
    // Page order:
    // 0 Cover
    // 1 Map
    // 2 Crossroads
    // 3 Forest
    // 4 City
    // 5 Cave
    // 6 Museum
    // 7 The End
    let (cover, cover_start_rect) = cover_ops()
    let (map, map_links) = map_ops()
    let (cross, cross_links) = scene_ops(
      "Crossroads",
      "A signpost. A breeze. Two shiny buttons.",
      (0.18, 0.48, 0.86),
      [
        "You wake up in the Button Kingdom.", "A robot guide waves politely.", "\"Choose wisely,\" it says.",
      ],
      [
        ("Go into the forest (it smells like cookies)", 3),
        ("Head to the city (someone is playing jazz)", 4),
      ],
    )
    let (forest, forest_links) = scene_ops(
      "Forest",
      "Whispers, wind, and a suspiciously friendly squirrel.",
      (0.22, 0.7, 0.5),
      [
        "The trees spell your name in the leaves.", "A hidden trail glows faintly.",
      ],
      [
        ("Follow the glowing trail (definitely not cursed)", 5),
        ("Return to the crossroads (you miss the signpost)", 2),
      ],
    )
    let (city, city_links) = scene_ops(
      "City",
      "Neon signs. A tiny jazz club. Free lemonade.",
      (0.92, 0.33, 0.36),
      [
        "A street artist offers you a sticker.", "A museum door clicks open on its own.",
      ],
      [
        ("Enter the museum (it’s quieter inside)", 6),
        ("Sneak into the subway (dramatic whoosh)", 5),
      ],
    )
    let (cave, cave_links) = scene_ops(
      "Cave",
      "Echoes. Glittering walls. A button shaped like a star.",
      (0.4, 0.45, 0.55),
      ["You find a stone pedestal.", "The robot whispers: \"Press it.\""],
      [
        ("Press the star button (hero moment)", 7),
        ("Tiptoe back to the forest (no shame)", 3),
      ],
    )
    let (museum, museum_links) = scene_ops(
      "Museum",
      "Ancient paintings of... buttons?",
      (0.7, 0.45, 0.9),
      ["A curator hands you a map.", "It only has one path highlighted."],
      [
        ("Follow the highlighted path (shortcut)", 7),
        ("Return to the city (encore jazz)", 4),
      ],
    )
    let (end, end_links) = scene_ops(
      "The End",
      "Confetti falls in slow motion.",
      (0.92, 0.75, 0.2),
      ["You made it!", "The robot bows.", "It gives you one last shiny button."],
      [("Play again (back to Map)", 1)],
    )
    let pages : Array[@pdfpage.Page] = [
      page_of_ops(cover),
      page_of_ops(map),
      page_of_ops(cross),
      page_of_ops(forest),
      page_of_ops(city),
      page_of_ops(cave),
      page_of_ops(museum),
      page_of_ops(end),
    ]
    let (pdf, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree(
      pages,
    )
    let pdf = @pdfpage.PdfPageDoc::new(pdf).add_root(pageroot, [])
    let spoilers_num = add_spoilers_layer(pdf)
    let pdf = add_spoilers_properties_to_pages(pdf, spoilers_num)
    let refs = pdf.page_reference_numbers()
    let pdf = add_bookmarks(pdf, refs)

    // Add links.
    let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
    let out_pages = pages

    // Cover start button -> Crossroads (page 3, index 2)
    out_pages[0] = add_link(
      pdf,
      out_pages[0],
      cover_start_rect,
      goto_action(refs[2]),
    )

    // Map cards
    let mut map_page = out_pages[1]
    for item in map_links {
      let (target, rect) = item
      map_page = add_link(pdf, map_page, rect, goto_action(refs[target]))
    }
    out_pages[1] = map_page

    // Scene pages: each has links (including Map)
    fn link_all(
      pdf : @pdf.Pdf,
      page : @pdfpage.Page,
      refs : Array[Int],
      links : Array[(Int, (Double, Double, Double, Double))],
    ) -> @pdfpage.Page raise {
      let mut p = page
      for item in links {
        let (target, rect) = item
        p = add_link(pdf, p, rect, goto_action(refs[target]))
      }
      p
    }

    out_pages[2] = link_all(pdf, out_pages[2], refs, cross_links)
    out_pages[3] = link_all(pdf, out_pages[3], refs, forest_links)
    out_pages[4] = link_all(pdf, out_pages[4], refs, city_links)
    out_pages[5] = link_all(pdf, out_pages[5], refs, cave_links)
    out_pages[6] = link_all(pdf, out_pages[6], refs, museum_links)
    out_pages[7] = link_all(pdf, out_pages[7], refs, end_links)
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
