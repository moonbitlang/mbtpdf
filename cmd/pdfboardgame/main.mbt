///|
type PdfObject = @pdf.PdfObject

///|
type Op = @pdfops.Op

///|
const COLS : Int = 4

///|
const ROWS : Int = 3

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
fn page_w() -> Double {
  paper().unit().to_points(paper().width())
}

///|
fn page_h() -> Double {
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
fn ops_button(
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  label : String,
  accent : (Double, Double, Double),
) -> (Array[Op], (Double, Double, Double, Double)) {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(x, y, w, h, (1.0, 1.0, 1.0))[:])
  ops.append(ops_stroke_rect(x, y, w, h, accent, 2.0)[:])
  ops.append(ops_fill_rect(x, y + h - 6.0, w, 6.0, accent)[:])
  ops.append(
    ops_text(x + 12.0, y + 14.0, "/F0", 14.0, label, (0.12, 0.14, 0.18))[:],
  )
  (ops, (x, y, x + w, y + h))
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
  let hints : PdfObject = Dictionary([
    ("/Type", Name(PdfName(b"/OCG"))),
    ("/Name", PdfString("HINTS")),
  ])
  let solution : PdfObject = Dictionary([
    ("/Type", Name(PdfName(b"/OCG"))),
    ("/Name", PdfString("SOLUTION")),
  ])
  let hints_num = pdf.addobj(hints)
  let solution_num = pdf.addobj(solution)
  let default_dict : PdfObject = Dictionary([
    ("/BaseState", Name(PdfName(b"/ON"))),
    ("/Intent", Name(PdfName(b"/View"))),
    ("/Name", PdfString("Default")),
    ("/OFF", PdfArray([Indirect(hints_num), Indirect(solution_num)])),
  ])
  let ocprops : PdfObject = Dictionary([
    ("/OCGs", PdfArray([Indirect(hints_num), Indirect(solution_num)])),
    ("/D", default_dict),
  ])
  let ocprops_num = pdf.addobj(ocprops)
  set_catalog_entry(pdf, "/OCProperties", Indirect(ocprops_num))
  (hints_num, solution_num)
}

///|
fn add_layer_properties_to_pages(
  pdf : @pdf.Pdf,
  hints_num : Int,
  solution_num : Int,
) -> @pdf.Pdf raise {
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  for i in 0..<pages.length() {
    let page = pages[i]
    let props : PdfObject = Dictionary([
      ("/HINTS", Indirect(hints_num)),
      ("/SOLUTION", Indirect(solution_num)),
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
fn add_bookmarks(
  pdf : @pdf.Pdf,
  refs : Array[Int],
  room_refs : Array[Int],
  board_ref : Int,
  rules_ref : Int,
  clue_ref : Int,
  solution_ref : Int,
) -> @pdf.Pdf raise {
  let marks : Array[@pdfmarks.Bookmark] = Array::new()
  marks.push({
    level: 0,
    text: "Mystery Mansion",
    target: Fit(PageObject(refs[0])),
    isopen: true,
    colour: (0.0, 0.0, 0.0),
    flags: 2,
  })
  marks.push({
    level: 1,
    text: "Board",
    target: Fit(PageObject(board_ref)),
    isopen: true,
    colour: (0.0, 0.0, 0.0),
    flags: 0,
  })
  marks.push({
    level: 1,
    text: "How To Play",
    target: Fit(PageObject(rules_ref)),
    isopen: true,
    colour: (0.0, 0.0, 0.0),
    flags: 0,
  })
  marks.push({
    level: 1,
    text: "Clue Cards",
    target: Fit(PageObject(clue_ref)),
    isopen: true,
    colour: (0.0, 0.0, 0.0),
    flags: 0,
  })
  marks.push({
    level: 1,
    text: "Rooms",
    target: Fit(PageObject(room_refs[0])),
    isopen: true,
    colour: (0.0, 0.0, 0.0),
    flags: 2,
  })
  for i in 0..<room_refs.length() {
    let name = "Room " + (i + 1).to_string()
    marks.push({
      level: 2,
      text: name,
      target: Fit(PageObject(room_refs[i])),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    })
  }
  marks.push({
    level: 1,
    text: "Solution",
    target: Fit(PageObject(solution_ref)),
    isopen: true,
    colour: (0.0, 0.0, 0.0),
    flags: 0,
  })
  @pdfmarks.PdfMarks::new(pdf).add_bookmarks(marks)
}

///|
fn cover_ops() -> (Array[Op], (Double, Double, Double, Double)) {
  let ops : Array[Op] = Array::new()
  let accent = (0.18, 0.48, 0.86)
  ops.append(ops_fill_rect(0.0, 0.0, page_w(), page_h(), (0.98, 0.98, 0.99))[:])
  ops.append(ops_fill_rect(0.0, page_h() - 120.0, page_w(), 120.0, accent)[:])
  ops.append(
    ops_text(
      72.0,
      page_h() - 74.0,
      "/F0",
      54.0,
      "Mystery Mansion",
      (1.0, 1.0, 1.0),
    )[:],
  )
  ops.append(
    ops_text(
      74.0,
      page_h() - 104.0,
      "/F1",
      18.0,
      "A printable mini escape-room board game",
      (0.92, 0.94, 0.98),
    )[:],
  )

  // Big token icon
  ops.append(
    ops_fill_polygon(
      circle_points(page_w() - 240.0, 250.0, 110.0, 60),
      (0.92, 0.33, 0.36),
    )[:],
  )
  ops.append(
    ops_fill_polygon(
      circle_points(page_w() - 240.0, 250.0, 82.0, 60),
      (1.0, 1.0, 1.0),
    )[:],
  )
  ops.append(
    ops_text(page_w() - 286.0, 238.0, "/F0", 28.0, "GO", (0.12, 0.14, 0.18))[:],
  )
  ops.append(
    ops_text(
      72.0,
      240.0,
      "/F1",
      18.0,
      "Print the Board + Cards, then play with friends.",
      (0.12, 0.14, 0.18),
    )[:],
  )
  ops.append(
    ops_text(
      72.0,
      210.0,
      "/F1",
      18.0,
      "Or just click around and explore the rooms.",
      (0.12, 0.14, 0.18),
    )[:],
  )
  ops.append(
    ops_text(
      72.0,
      170.0,
      "/F2",
      12.0,
      "Tip: Layers panel has HINTS and SOLUTION.",
      (0.45, 0.48, 0.52),
    )[:],
  )
  let (btn, rect) = ops_button(
    72.0,
    70.0,
    320.0,
    64.0,
    "Start: open the board",
    (0.92, 0.33, 0.36),
  )
  ops.append(btn[:])
  (ops, rect)
}

///|
fn rules_ops() -> Array[Op] {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, page_w(), page_h(), (1.0, 1.0, 1.0))[:])
  ops.append(
    ops_text(
      72.0,
      page_h() - 80.0,
      "/F0",
      38.0,
      "How To Play (2–4 players)",
      (0.12, 0.14, 0.18),
    )[:],
  )
  let lines : Array[String] = [
    "Goal: find the hidden key, unlock the Vault, and escape.", "Setup: print the Board + Clue Cards page. Cut the cards.",
    "On your turn: move to an adjacent room (or click rooms if digital).", "Draw a clue card. Read it aloud. Keep it face up.",
    "When you think you know the path, head to the Vault and guess.", "", "Digital shortcut: enable the HINTS layer if you get stuck.",
  ]
  let mut y = page_h() - 140.0
  for line in lines {
    ops.append(
      ops_text(72.0, y, "/F1", 18.0, "• " + line, (0.12, 0.14, 0.18))[:],
    )
    y = y - 28.0
  }
  ops.push(OpBDC("/OC", Name(PdfName(b"/HINTS"))))
  ops.append(
    ops_text(
      72.0,
      90.0,
      "/F2",
      12.0,
      "HINT: The key is in a room with a round symbol.",
      (0.2, 0.18, 0.05),
    )[:],
  )
  ops.push(OpEMC)
  ops
}

///|
fn clue_cards_ops() -> Array[Op] {
  let ops : Array[Op] = Array::new()
  ops.append(
    ops_fill_rect(0.0, 0.0, page_w(), page_h(), (0.99, 0.985, 0.97))[:],
  )
  ops.append(
    ops_text(
      72.0,
      page_h() - 80.0,
      "/F0",
      38.0,
      "Clue Cards (Print + Cut)",
      (0.12, 0.14, 0.18),
    )[:],
  )
  ops.append(
    ops_text(
      72.0,
      page_h() - 108.0,
      "/F1",
      14.0,
      "Shuffle these. Draw one each turn.",
      (0.45, 0.48, 0.52),
    )[:],
  )
  let card_w = 250.0
  let card_h = 120.0
  let gap_x = 22.0
  let gap_y = 18.0
  let start_x = 72.0
  let start_y = page_h() - 160.0
  let texts : Array[String] = [
    "A painting watches you.", "You smell cinnamon.", "The floor is cold stone.",
    "A key-shaped shadow.", "You hear running water.", "A tiny bell rings.",
  ]
  let mut i = 0
  for r in 0..<2 {
    for c in 0..<3 {
      let x = start_x + c.to_double() * (card_w + gap_x)
      let y = start_y - r.to_double() * (card_h + gap_y) - card_h
      ops.append(ops_fill_rect(x, y, card_w, card_h, (1.0, 1.0, 1.0))[:])
      ops.append(
        ops_stroke_rect(x, y, card_w, card_h, (0.2, 0.22, 0.26), 1.5)[:],
      )
      ops.append(
        ops_text(
          x + 14.0,
          y + card_h - 28.0,
          "/F0",
          16.0,
          "CLUE",
          (0.18, 0.48, 0.86),
        )[:],
      )
      ops.append(
        ops_text(x + 14.0, y + 52.0, "/F1", 16.0, texts[i], (0.12, 0.14, 0.18))[:],
      )
      i = i + 1
    }
  }
  ops.push(OpBDC("/OC", Name(PdfName(b"/SOLUTION"))))
  ops.append(
    ops_text(
      72.0,
      90.0,
      "/F2",
      12.0,
      "SOLUTION: Use the Board's red path. Then go to the Vault.",
      (0.2, 0.18, 0.05),
    )[:],
  )
  ops.push(OpEMC)
  ops
}

///|
fn board_ops() -> (Array[Op], Array[(Int, (Double, Double, Double, Double))]) {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, page_w(), page_h(), (1.0, 1.0, 1.0))[:])
  ops.append(
    ops_text(
      72.0,
      page_h() - 80.0,
      "/F0",
      38.0,
      "The Board (Clickable)",
      (0.12, 0.14, 0.18),
    )[:],
  )
  ops.append(
    ops_text(
      72.0,
      page_h() - 108.0,
      "/F1",
      14.0,
      "Click a room to open its card.",
      (0.45, 0.48, 0.52),
    )[:],
  )
  let grid_x = 72.0
  let grid_y = 90.0
  let grid_w = page_w() - 144.0
  let grid_h = page_h() - 230.0
  ops.append(
    ops_stroke_rect(grid_x, grid_y, grid_w, grid_h, (0.2, 0.22, 0.26), 2.0)[:],
  )
  let cell_w = grid_w / COLS.to_double()
  let cell_h = grid_h / ROWS.to_double()

  // Grid lines
  for c in 1..<COLS {
    let x = grid_x + c.to_double() * cell_w
    ops.append(
      ops_line(x, grid_y, x, grid_y + grid_h, (0.85, 0.86, 0.88), 1.0)[:],
    )
  }
  for r in 1..<ROWS {
    let y = grid_y + r.to_double() * cell_h
    ops.append(
      ops_line(grid_x, y, grid_x + grid_w, y, (0.85, 0.86, 0.88), 1.0)[:],
    )
  }
  let links : Array[(Int, (Double, Double, Double, Double))] = Array::new()
  let mut room = 1
  for r in 0..<ROWS {
    for c in 0..<COLS {
      let x0 = grid_x + c.to_double() * cell_w
      let y0 = grid_y + (ROWS - 1 - r).to_double() * cell_h
      let rect = (x0, y0, x0 + cell_w, y0 + cell_h)
      links.push((room, rect))
      let label = "ROOM " + room.to_string()
      ops.append(
        ops_text(
          x0 + 14.0,
          y0 + cell_h - 28.0,
          "/F2",
          12.0,
          label,
          (0.45, 0.48, 0.52),
        )[:],
      )

      // Simple symbol per room
      let cx = x0 + cell_w / 2.0
      let cy = y0 + cell_h / 2.0
      let accent = if room % 3 == 0 {
        (0.92, 0.33, 0.36)
      } else if room % 3 == 1 {
        (0.18, 0.48, 0.86)
      } else {
        (0.22, 0.7, 0.5)
      }
      if room % 4 == 0 {
        ops.append(ops_fill_polygon(circle_points(cx, cy, 18.0, 24), accent)[:])
      } else if room % 4 == 1 {
        ops.append(ops_fill_rect(cx - 16.0, cy - 16.0, 32.0, 32.0, accent)[:])
      } else if room % 4 == 2 {
        ops.append(
          ops_fill_polygon(
            [(cx, cy + 20.0), (cx - 20.0, cy - 18.0), (cx + 20.0, cy - 18.0)],
            accent,
          )[:],
        )
      } else {
        ops.append(
          ops_fill_polygon(
            [(cx - 20.0, cy), (cx, cy + 20.0), (cx + 20.0, cy), (cx, cy - 20.0)],
            accent,
          )[:],
        )
      }
      room = room + 1
    }
  }

  // Solution overlay: a red path
  ops.push(OpBDC("/OC", Name(PdfName(b"/SOLUTION"))))
  let path_rooms : Array[Int] = [1, 2, 6, 10, 11, 12]
  for i in 0..<(path_rooms.length() - 1) {
    let a = path_rooms[i] - 1
    let b = path_rooms[i + 1] - 1
    let ax = a % COLS
    let ay = a / COLS
    let bx = b % COLS
    let by = b / COLS
    let x0 = grid_x + (ax.to_double() + 0.5) * cell_w
    let y0 = grid_y + (ROWS - 1 - ay).to_double() * cell_h + cell_h / 2.0
    let x1 = grid_x + (bx.to_double() + 0.5) * cell_w
    let y1 = grid_y + (ROWS - 1 - by).to_double() * cell_h + cell_h / 2.0
    ops.append(ops_line(x0, y0, x1, y1, (0.92, 0.33, 0.36), 6.0)[:])
  }
  ops.push(OpEMC)
  ops.push(OpBDC("/OC", Name(PdfName(b"/HINTS"))))
  ops.append(
    ops_text(
      72.0,
      60.0,
      "/F2",
      12.0,
      "HINT: The Vault is in Room 12.",
      (0.2, 0.18, 0.05),
    )[:],
  )
  ops.push(OpEMC)
  (ops, links)
}

///|
fn room_ops(
  room_1 : Int,
) -> (Array[Op], Array[(Int, (Double, Double, Double, Double))]) {
  let ops : Array[Op] = Array::new()
  let accent = if room_1 % 3 == 0 {
    (0.92, 0.33, 0.36)
  } else if room_1 % 3 == 1 {
    (0.18, 0.48, 0.86)
  } else {
    (0.22, 0.7, 0.5)
  }
  ops.append(
    ops_fill_rect(0.0, 0.0, page_w(), page_h(), (0.985, 0.985, 0.99))[:],
  )
  ops.append(ops_fill_rect(0.0, page_h() - 86.0, page_w(), 86.0, accent)[:])
  ops.append(
    ops_text(
      72.0,
      page_h() - 54.0,
      "/F0",
      34.0,
      "Room " + room_1.to_string(),
      (1.0, 1.0, 1.0),
    )[:],
  )
  ops.append(
    ops_text(
      72.0,
      page_h() - 78.0,
      "/F1",
      14.0,
      "Read it aloud. Keep it secret from the group.",
      (0.92, 0.94, 0.98),
    )[:],
  )
  let cx = page_w() - 220.0
  let cy = 250.0
  ops.append(
    ops_fill_polygon(circle_points(cx, cy, 92.0, 50), (1.0, 1.0, 1.0))[:],
  )
  ops.append(
    ops_stroke_rect(cx - 92.0, cy - 92.0, 184.0, 184.0, (0.2, 0.22, 0.26), 2.0)[:],
  )
  ops.append(
    ops_text(cx - 36.0, cy - 10.0, "/F0", 24.0, "?", (0.12, 0.14, 0.18))[:],
  )
  let flavor : Array[String] = if room_1 == 12 {
    [
      "You found the VAULT door.", "It has three dials.", "You can attempt the final guess now.",
    ]
  } else if room_1 % 4 == 0 {
    [
      "A drafty hallway.", "A round symbol on the wall.", "Something glints under dust.",
    ]
  } else if room_1 % 4 == 1 {
    [
      "A cozy study.", "Books arranged oddly.", "One spine is warmer than the others.",
    ]
  } else if room_1 % 4 == 2 {
    [
      "A tiled kitchen.", "Cinnamon in the air.", "A note is pinned under a magnet.",
    ]
  } else {
    [
      "A music room.", "A bell vibrates softly.", "You feel like you're being timed.",
    ]
  }
  let mut y = page_h() - 160.0
  for line in flavor {
    ops.append(ops_text(72.0, y, "/F1", 20.0, line, (0.12, 0.14, 0.18))[:])
    y = y - 30.0
  }
  ops.push(OpBDC("/OC", Name(PdfName(b"/HINTS"))))
  ops.append(
    ops_text(
      72.0,
      120.0,
      "/F2",
      12.0,
      "HINT: This room's symbol matters (shape/color).",
      (0.2, 0.18, 0.05),
    )[:],
  )
  ops.push(OpEMC)
  ops.push(OpBDC("/OC", Name(PdfName(b"/SOLUTION"))))
  ops.append(
    ops_text(
      72.0,
      92.0,
      "/F2",
      12.0,
      "SOLUTION: Follow the red path on the Board to reach Room 12.",
      (0.2, 0.18, 0.05),
    )[:],
  )
  ops.push(OpEMC)
  let (btn, rect) = ops_button(
    page_w() - 260.0,
    70.0,
    188.0,
    54.0,
    "Back to Board",
    (0.12, 0.14, 0.18),
  )
  ops.append(btn[:])
  let links : Array[(Int, (Double, Double, Double, Double))] = [(0, rect)]
  (ops, links)
}

///|
fn solution_ops() -> (Array[Op], (Double, Double, Double, Double)) {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, page_w(), page_h(), (0.06, 0.07, 0.1))[:])
  ops.append(
    ops_text(72.0, page_h() - 90.0, "/F0", 44.0, "Solution", (0.95, 0.96, 0.98))[:],
  )
  ops.append(
    ops_text(
      72.0,
      page_h() - 132.0,
      "/F1",
      16.0,
      "Toggle SOLUTION layer on other pages for help.",
      (0.8, 0.84, 0.9),
    )[:],
  )
  ops.append(
    ops_text(
      72.0,
      page_h() - 190.0,
      "/F1",
      18.0,
      "Best path: 1 → 2 → 6 → 10 → 11 → 12 (Vault).",
      (0.8, 0.84, 0.9),
    )[:],
  )
  ops.append(
    ops_text(
      72.0,
      page_h() - 220.0,
      "/F1",
      18.0,
      "Final guess: the key is in a room with the round symbol.",
      (0.8, 0.84, 0.9),
    )[:],
  )
  let (btn, rect) = ops_button(
    72.0,
    70.0,
    220.0,
    62.0,
    "Back to Board",
    (0.92, 0.33, 0.36),
  )
  ops.append(btn[:])
  (ops, rect)
}

///|
pub async fn run(
  out_file? : String = "boardgame.pdf",
  quiet? : Bool = false,
) -> Unit {
  try {
    // Page layout:
    // 0 Cover
    // 1 Board
    // 2 Rules
    // 3 Clue Cards
    // 4..15 Rooms 1..12
    // 16 Solution
    let (cover, cover_rect) = cover_ops()
    let (board, board_links) = board_ops()
    let rules = rules_ops()
    let clue = clue_cards_ops()
    let room_pages : Array[@pdfpage.Page] = Array::new(capacity=ROWS * COLS)
    let room_links : Array[Array[(Int, (Double, Double, Double, Double))]] = Array::new()
    for i in 1..<=(ROWS * COLS) {
      let (ops, links) = room_ops(i)
      room_pages.push(page_of_ops(ops))
      room_links.push(links)
    }
    let (solution, solution_rect) = solution_ops()
    let pages : Array[@pdfpage.Page] = [
        page_of_ops(cover),
        page_of_ops(board),
        page_of_ops(rules),
        page_of_ops(clue),
      ] +
      room_pages +
      [page_of_ops(solution)]
    let (pdf, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree(
      pages,
    )
    let pdf = @pdfpage.PdfPageDoc::new(pdf).add_root(pageroot, [])
    let (hints_num, solution_num) = add_layers(pdf)
    let pdf = add_layer_properties_to_pages(pdf, hints_num, solution_num)
    let refs = pdf.page_reference_numbers()
    let board_ref = refs[1]
    let rules_ref = refs[2]
    let clue_ref = refs[3]
    let room_refs = refs[4:4 + ROWS * COLS].to_owned()
    let solution_ref = refs[refs.length() - 1]
    let pdf = add_bookmarks(
      pdf, refs, room_refs, board_ref, rules_ref, clue_ref, solution_ref,
    )

    // Add links.
    let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
    let out_pages = pages

    // Cover "Start" -> Board
    out_pages[0] = add_link(
      pdf,
      out_pages[0],
      cover_rect,
      goto_action(board_ref),
    )

    // Board room tiles -> Room pages
    let mut bpage = out_pages[1]
    for entry in board_links {
      let (room_1, rect) = entry
      let target_ref = room_refs[room_1 - 1]
      bpage = add_link(pdf, bpage, rect, goto_action(target_ref))
    }
    out_pages[1] = bpage

    // Room pages "Back to Board"
    for i in 0..<(ROWS * COLS) {
      let page_i = 4 + i
      let links = room_links[i]
      let mut p = out_pages[page_i]
      for entry in links {
        let (_, rect) = entry
        p = add_link(pdf, p, rect, goto_action(board_ref))
      }
      out_pages[page_i] = p
    }

    // Solution page back
    out_pages[refs.length() - 1] = add_link(
      pdf,
      out_pages[refs.length() - 1],
      solution_rect,
      goto_action(board_ref),
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
