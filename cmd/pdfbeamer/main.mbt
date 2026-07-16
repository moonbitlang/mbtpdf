///|
type PdfObject = @pdf.PdfObject

///|
type Op = @pdfops.Op

///|
const SLIDE_W : Double = 960.0

///|
const SLIDE_H : Double = 540.0

///|
const MARGIN_X : Double = 56.0

///|
const HEADER_H : Double = 44.0

///|
const FOOTER_H : Double = 32.0

///|
fn theme_bg() -> (Double, Double, Double) {
  (0.99, 0.99, 0.995)
}

///|
fn theme_ink() -> (Double, Double, Double) {
  (0.12, 0.14, 0.18)
}

///|
fn theme_muted() -> (Double, Double, Double) {
  (0.45, 0.48, 0.52)
}

///|
fn theme_accent() -> (Double, Double, Double) {
  (0.18, 0.48, 0.86)
}

///|
fn theme_accent2() -> (Double, Double, Double) {
  (0.92, 0.33, 0.36)
}

///|
fn font_type1(base_font : String) -> PdfObject {
  Dictionary([
    ("/Type", Name(PdfName(b"/Font"))),
    ("/Subtype", Name(PdfName(b"/Type1"))),
    ("/BaseFont", Name(@pdf.PdfName::of_string("/" + base_font))),
  ])
}

///|
fn slide_resources() -> PdfObject {
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
fn slide_paper() -> @pdfpaper.Paper {
  @pdfpaper.Paper::new(unit=PdfPoint, width=SLIDE_W, height=SLIDE_H)
}

///|
fn slide_mediabox() -> PdfObject {
  slide_paper().rectangle()
}

///|
fn ops_fill_rect(
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  rgb : (Double, Double, Double),
) -> Array[Op] {
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
) -> Array[Op] {
  let (r, g, b) = rgb
  [Opq, Opw(width), OpRG(r, g, b), Opre(x, y, w, h), OpS, OpQ]
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
fn ops_code_block(
  x : Double,
  y_top : Double,
  lines : Array[String],
) -> Array[Op] {
  let ops : Array[Op] = Array::new()
  let line_h = 15.0
  let w = SLIDE_W - 2.0 * MARGIN_X
  let h = line_h * lines.length().to_double() + 26.0
  let y = y_top - h
  ops.append(ops_fill_rect(MARGIN_X, y, w, h, (0.965, 0.97, 0.98))[:])
  ops.append(ops_stroke_rect(MARGIN_X, y, w, h, (0.78, 0.8, 0.84), 1.0)[:])
  let mut i = 0
  for line in lines {
    let yy = y_top - 18.0 - i.to_double() * line_h
    ops.append(ops_text(x, yy, "/F2", 11.0, line, (0.12, 0.14, 0.18))[:])
    i = i + 1
  }
  ops
}

///|
fn header_ops(section : String, title : String) -> Array[Op] {
  let ops : Array[Op] = Array::new()
  let accent = theme_accent()
  ops.append(
    ops_fill_rect(0.0, SLIDE_H - HEADER_H, SLIDE_W, HEADER_H, accent)[:],
  )
  ops.append(
    ops_text(MARGIN_X, SLIDE_H - 28.0, "/F1", 13.0, section, (1.0, 1.0, 1.0))[:],
  )
  ops.append(
    ops_text(MARGIN_X, SLIDE_H - 18.0, "/F0", 18.0, title, (1.0, 1.0, 1.0))[:],
  )
  ops
}

///|
fn footer_ops(
  page_index_1 : Int,
  total_pages : Int,
  progress0_1 : Double,
) -> Array[Op] {
  let ops : Array[Op] = Array::new()
  let bar = (0.12, 0.14, 0.18)
  ops.append(ops_fill_rect(0.0, 0.0, SLIDE_W, FOOTER_H, bar)[:])
  ops.append(
    ops_fill_rect(
      0.0,
      FOOTER_H - 3.0,
      SLIDE_W * progress0_1,
      3.0,
      theme_accent2(),
    )[:],
  )
  let label = page_index_1.to_string() + " / " + total_pages.to_string()
  ops.append(
    ops_text(
      SLIDE_W - MARGIN_X - 72.0,
      12.0,
      "/F2",
      10.0,
      label,
      (0.85, 0.88, 0.92),
    )[:],
  )
  ops.append(
    ops_text(MARGIN_X, 12.0, "/F2", 10.0, "Prev", (0.85, 0.88, 0.92))[:],
  )
  ops.append(
    ops_text(
      SLIDE_W - MARGIN_X - 28.0,
      12.0,
      "/F2",
      10.0,
      "Next",
      (0.85, 0.88, 0.92),
    )[:],
  )
  ops
}

///|
fn notes_ops(note : String) -> Array[Op] {
  let ops : Array[Op] = Array::new()
  let x = MARGIN_X
  let w = SLIDE_W - 2.0 * MARGIN_X
  let y = FOOTER_H + 10.0
  let h = 54.0
  ops.push(OpBDC("/OC", Name(PdfName(b"/NOTES"))))
  ops.append(ops_fill_rect(x, y, w, h, (1.0, 1.0, 0.9))[:])
  ops.append(ops_stroke_rect(x, y, w, h, (0.88, 0.84, 0.4), 1.0)[:])
  ops.append(
    ops_text(
      x + 10.0,
      y + 36.0,
      "/F2",
      11.0,
      "NOTES (layer): " + note,
      (0.2, 0.18, 0.05),
    )[:],
  )
  ops.push(OpEMC)
  ops
}

///|
fn slide_ops(
  section : String,
  title : String,
  body : Array[Op],
  note : String?,
  page_index_1 : Int,
  total_pages : Int,
) -> Array[Op] {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, SLIDE_W, SLIDE_H, theme_bg())[:])
  ops.append(header_ops(section, title)[:])
  let progress = page_index_1.to_double() / total_pages.to_double()
  ops.append(footer_ops(page_index_1, total_pages, progress)[:])
  for op in body {
    ops.push(op)
  }
  match note {
    None => ()
    Some(n) => ops.append(notes_ops(n)[:])
  }
  ops
}

///|
fn bullet_slide_body(
  x : Double,
  y_top : Double,
  bullets : Array[String],
  shown : Int,
) -> Array[Op] {
  let ops : Array[Op] = Array::new()
  let line_h = 26.0
  let mut i = 0
  for b in bullets {
    i = i + 1
    if i > shown {
      continue
    }
    let y = y_top - (i - 1).to_double() * line_h
    let color = if i == shown { theme_accent2() } else { theme_ink() }
    ops.append(ops_text(x, y, "/F1", 18.0, "- " + b, color)[:])
  }
  ops
}

///|
fn title_slide_body(title : String, subtitle : String) -> Array[Op] {
  let ops : Array[Op] = Array::new()
  ops.append(ops_text(MARGIN_X, 340.0, "/F0", 46.0, title, theme_ink())[:])
  ops.append(ops_text(MARGIN_X, 300.0, "/F1", 20.0, subtitle, theme_muted())[:])
  ops.append(
    ops_text(
      MARGIN_X,
      230.0,
      "/F2",
      12.0,
      "Generated by mbtpdf using PDF content-stream operators.",
      theme_muted(),
    )[:],
  )
  ops.append(
    ops_text(
      MARGIN_X,
      210.0,
      "/F2",
      12.0,
      "Tip: open your viewer's Layers panel and enable NOTES.",
      theme_muted(),
    )[:],
  )
  // Decorative diagonal
  ops.append(ops_line(0.0, 140.0, SLIDE_W, 500.0, theme_accent(), 6.0)[:])
  ops.append(ops_line(0.0, 120.0, SLIDE_W, 480.0, theme_accent2(), 3.0)[:])
  ops
}

///|
fn section_slide_body(section : String) -> Array[Op] {
  let ops : Array[Op] = Array::new()
  ops.append(ops_text(MARGIN_X, 320.0, "/F0", 40.0, section, theme_ink())[:])
  ops.append(
    ops_text(
      MARGIN_X,
      280.0,
      "/F1",
      18.0,
      "Beamer-style layout: header, footer, progress bar, navigation.",
      theme_muted(),
    )[:],
  )
  ops
}

///|
fn toc_slide_body(
  entries : Array[(String, Int)],
) -> (Array[Op], Array[(Int, (Double, Double, Double, Double))]) {
  let ops : Array[Op] = Array::new()
  ops.append(ops_text(MARGIN_X, 420.0, "/F0", 30.0, "Outline", theme_ink())[:])
  ops.append(
    ops_text(
      MARGIN_X,
      392.0,
      "/F2",
      12.0,
      "Click a section title to jump.",
      theme_muted(),
    )[:],
  )
  let mut y = 340.0
  let rects : Array[(Int, (Double, Double, Double, Double))] = Array::new()
  for entry in entries {
    let (name, page_i) = entry
    ops.append(ops_text(MARGIN_X, y, "/F1", 22.0, name, theme_accent())[:])
    rects.push((page_i, (MARGIN_X, y - 6.0, MARGIN_X + 420.0, y + 22.0)))
    y = y - 40.0
  }
  (ops, rects)
}

///|
fn page_of_ops(ops : Array[Op]) -> @pdfpage.Page raise {
  let stream = @pdfops.Op::stream_of_ops(ops)
  Page(
    content=[stream],
    mediabox=slide_mediabox(),
    resources=slide_resources(),
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
fn add_notes_layer(pdf : @pdf.Pdf) -> Int raise {
  let ocg_notes : PdfObject = Dictionary([
    ("/Type", Name(PdfName(b"/OCG"))),
    ("/Name", PdfString("NOTES")),
  ])
  let notes_num = pdf.addobj(ocg_notes)
  let default_dict : PdfObject = Dictionary([
    ("/BaseState", Name(PdfName(b"/OFF"))),
    ("/Intent", Name(PdfName(b"/View"))),
    ("/Name", PdfString("Default")),
  ])
  let ocprops : PdfObject = Dictionary([
    ("/OCGs", PdfArray([Indirect(notes_num)])),
    ("/D", default_dict),
  ])
  let ocprops_num = pdf.addobj(ocprops)
  set_catalog_entry(pdf, "/OCProperties", Indirect(ocprops_num))
  notes_num
}

///|
fn add_notes_properties_to_pages(
  pdf : @pdf.Pdf,
  notes_num : Int,
) -> @pdf.Pdf raise {
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  for i in 0..<pages.length() {
    let page = pages[i]
    let props : PdfObject = Dictionary([("/NOTES", Indirect(notes_num))])
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
fn add_nav_links(
  pdf : @pdf.Pdf,
  toc_links : Array[(Int, (Double, Double, Double, Double))],
) -> @pdf.Pdf raise {
  let refs = pdf.page_reference_numbers()
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  for i in 0..<pages.length() {
    let mut page = pages[i]
    // Footer buttons
    if i > 0 {
      page = add_link(
        pdf,
        page,
        (MARGIN_X - 8.0, 6.0, MARGIN_X + 48.0, 28.0),
        goto_action(refs[i - 1]),
      )
    }
    if i + 1 < pages.length() {
      page = add_link(
        pdf,
        page,
        (SLIDE_W - MARGIN_X - 20.0, 6.0, SLIDE_W - MARGIN_X + 52.0, 28.0),
        goto_action(refs[i + 1]),
      )
    }
    pages[i] = page
  }

  // TOC: links on slide 2 (index 1).
  if pages.length() > 1 {
    let mut toc_page = pages[1]
    for item in toc_links {
      let (target_index_1, rect) = item
      let target_i = target_index_1 - 1
      if target_i >= 0 && target_i < refs.length() {
        toc_page = add_link(pdf, toc_page, rect, goto_action(refs[target_i]))
      }
    }
    pages[1] = toc_page
  }
  @pdfpage.PdfPageDoc::new(pdf).change_pages(true, pages)
}

///|
fn add_bookmarks(
  pdf : @pdf.Pdf,
  section_starts : Array[(String, Int)],
) -> @pdf.Pdf raise {
  let refs = pdf.page_reference_numbers()
  let marks : Array[@pdfmarks.Bookmark] = Array::new()
  marks.push({
    level: 0,
    text: "Slides",
    target: Fit(PageObject(refs[0])),
    isopen: true,
    colour: (0.0, 0.0, 0.0),
    flags: 2,
  })
  marks.push({
    level: 1,
    text: "Outline",
    target: Fit(PageObject(refs[1])),
    isopen: true,
    colour: (0.0, 0.0, 0.0),
    flags: 0,
  })
  for entry in section_starts {
    let (name, page_i_1) = entry
    let idx = page_i_1 - 1
    if idx >= 0 && idx < refs.length() {
      marks.push({
        level: 1,
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
priv enum SlideBody {
  Title(String, String)
  Toc
  SectionDivider(String)
  Bullets(Array[String], Int)
  PipelineDiagram
  CodeSnippet
  Takeaways(Array[String])
  Thanks
}

///|
priv struct SlideDef {
  section : String
  title : String
  note : String?
  body : SlideBody
}

///|
fn build_deck() -> (
  Array[@pdfpage.Page],
  Array[(String, Int)],
  Array[(Int, (Double, Double, Double, Double))],
) raise {
  // Section start indices are 1-based slide indices (for TOC/bookmarks).
  let section_starts : Array[(String, Int)] = Array::new()
  let toc_entries : Array[(String, Int)] = Array::new()
  let slides : Array[SlideDef] = Array::new()
  fn push_slide(
    slides : Array[SlideDef],
    section : String,
    title : String,
    note : String?,
    body : SlideBody,
  ) -> Unit {
    slides.push({ section, title, note, body })
  }

  fn begin_section(
    slides : Array[SlideDef],
    section_starts : Array[(String, Int)],
    toc_entries : Array[(String, Int)],
    name : String,
    note : String?,
  ) -> Unit {
    let start = slides.length() + 1
    section_starts.push((name, start))
    toc_entries.push((name, start))
    push_slide(slides, name, name, note, SectionDivider(name))
  }

  push_slide(
    slides,
    "mbtpdf",
    "Beamer-ish Slides",
    Some("We fake 'beamer overlays' by generating multiple slides."),
    Title("Beamer-ish Slides", "Made with pdfops + pdfpage"),
  )
  push_slide(
    slides,
    "mbtpdf",
    "Outline",
    Some("Click section titles; use Prev/Next footer links."),
    Toc,
  )
  begin_section(
    slides,
    section_starts,
    toc_entries,
    "Motivation",
    Some("This is a section divider slide."),
  )
  push_slide(
    slides,
    "Motivation",
    "Why generate slides as PDF?",
    Some("PDF is a universal container: vector, text, links, layers."),
    Bullets(
      [
        "No LaTeX toolchain required", "Precise control over content streams", "Interactive features: links, bookmarks, layers",
      ],
      3,
    ),
  )
  let bullets = [
    "PDF ops are composable (Array[Op])", "You can post-process existing PDFs", "You can add structure (bookmarks) and UI (links)",
  ]
  for shown in 1..<=3 {
    push_slide(
      slides,
      "Motivation",
      "Three things we can do",
      Some("Each slide reveals one more bullet."),
      Bullets(bullets, shown),
    )
  }
  begin_section(
    slides,
    section_starts,
    toc_entries,
    "Pipeline",
    Some("The 'mental model' section."),
  )
  push_slide(
    slides,
    "Pipeline",
    "Read → Ops → Transform → Write",
    Some("This is the mental model slide."),
    PipelineDiagram,
  )
  begin_section(
    slides,
    section_starts,
    toc_entries,
    "Code",
    Some("Concrete API shape."),
  )
  push_slide(
    slides,
    "Code",
    "A slide is just operators",
    Some("Build ops, then stream_of_ops, then attach to a Page."),
    CodeSnippet,
  )
  begin_section(
    slides,
    section_starts,
    toc_entries,
    "Wrap-up",
    Some("Closing thoughts."),
  )
  push_slide(
    slides,
    "Wrap-up",
    "Takeaways",
    Some("Next: add images, gradients, and layout helpers."),
    Takeaways([
      "Beamer-ish decks are feasible with mbtpdf", "Links + bookmarks already feel presentation-like",
      "OCG layers can emulate speaker notes",
    ]),
  )
  push_slide(
    slides,
    "Wrap-up",
    "Thanks",
    Some("Try extending: miniframes, code highlighting, SVG-to-ops."),
    Thanks,
  )
  let total = slides.length()
  let pages : Array[@pdfpage.Page] = Array::new(capacity=total)
  let mut toc_links : Array[(Int, (Double, Double, Double, Double))] = []
  for i in 0..<total {
    let slide = slides[i]
    let body_ops = match (slide.body : SlideBody) {
      Title(t, s) => title_slide_body(t, s)
      SectionDivider(name) => section_slide_body(name)
      Bullets(bs, shown) => bullet_slide_body(MARGIN_X, 420.0, bs, shown)
      PipelineDiagram => {
        let ops : Array[Op] = Array::new()
        ops.append(
          ops_text(
            MARGIN_X,
            420.0,
            "/F1",
            18.0,
            "A tiny pipeline diagram:",
            theme_muted(),
          )[:],
        )
        let y = 290.0
        let box_w = 180.0
        let box_h = 74.0
        let gap = 22.0
        let x0 = MARGIN_X
        fn box(
          ops : Array[Op],
          x : Double,
          y : Double,
          label : String,
        ) -> Unit {
          ops.append(ops_fill_rect(x, y, 180.0, 74.0, (1.0, 1.0, 1.0))[:])
          ops.append(
            ops_stroke_rect(x, y, 180.0, 74.0, (0.2, 0.22, 0.26), 1.5)[:],
          )
          ops.append(
            ops_text(x + 16.0, y + 44.0, "/F0", 16.0, label, theme_ink())[:],
          )
        }

        box(ops, x0, y, "Read/Parse")
        box(ops, x0 + (box_w + gap) * 1.0, y, "Ops")
        box(ops, x0 + (box_w + gap) * 2.0, y, "Transform")
        box(ops, x0 + (box_w + gap) * 3.0, y, "Write")
        let ay = y + box_h / 2.0
        for k in 0..<3 {
          let xa = x0 + (box_w + gap) * (k + 1).to_double() - gap
          let x1 = xa + gap
          ops.append(ops_line(xa, ay, x1, ay, theme_accent2(), 3.0)[:])
        }
        ops
      }
      CodeSnippet => {
        let ops : Array[Op] = Array::new()
        ops.append(
          ops_text(
            MARGIN_X,
            420.0,
            "/F1",
            18.0,
            "This is the rough shape of the API:",
            theme_muted(),
          )[:],
        )
        ops.append(
          ops_code_block(MARGIN_X + 14.0, 360.0, [
            "let ops : Array[@pdfops.Op] = [ ... ]", "let stream = @pdfops.Op::stream_of_ops(ops)",
            "let page = @pdfpage.Page(", "  content=[stream],", "  mediabox=slide_mediabox(),",
            "  resources=slide_resources(),", "  rotate=Rotate0,", "  rest=Dictionary([]),",
            ")",
          ])[:],
        )
        ops
      }
      Takeaways(items) =>
        bullet_slide_body(MARGIN_X, 420.0, items, items.length())
      Thanks => {
        let ops : Array[Op] = Array::new()
        ops.append(
          ops_text(MARGIN_X, 340.0, "/F0", 44.0, "Thanks!", theme_ink())[:],
        )
        ops.append(
          ops_text(
            MARGIN_X,
            300.0,
            "/F1",
            18.0,
            "mbtpdf can generate presentations.",
            theme_muted(),
          )[:],
        )
        ops.append(
          ops_text(
            MARGIN_X,
            250.0,
            "/F2",
            12.0,
            "Run: moon run cmd/pdfbeamer -- tmp/deck.pdf",
            theme_muted(),
          )[:],
        )
        ops
      }
      Toc => {
        let (ops, links) = toc_slide_body(toc_entries)
        toc_links = links
        ops
      }
    }
    let full_ops = slide_ops(
      slide.section,
      slide.title,
      body_ops,
      slide.note,
      i + 1,
      total,
    )
    pages.push(page_of_ops(full_ops))
  }
  (pages, section_starts, toc_links)
}

///|
pub async fn run(
  out_file? : String = "deck.pdf",
  quiet? : Bool = false,
) -> Unit {
  try {
    let (pages, section_starts, toc_links) = build_deck()
    let (pdf, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree(
      pages,
    )
    let pdf = @pdfpage.PdfPageDoc::new(pdf).add_root(pageroot, [])
    let notes_num = add_notes_layer(pdf)
    let pdf = add_notes_properties_to_pages(pdf, notes_num)
    let pdf = add_bookmarks(pdf, section_starts)
    let pdf = add_nav_links(pdf, toc_links)
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
