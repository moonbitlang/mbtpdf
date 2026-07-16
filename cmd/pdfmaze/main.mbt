///|
type PdfObject = @pdf.PdfObject

///|
type Op = @pdfops.Op

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
fn font_type1(base_font : String) -> PdfObject {
  Dictionary([
    ("/Type", Name(PdfName(b"/Font"))),
    ("/Subtype", Name(PdfName(b"/Type1"))),
    ("/BaseFont", Name(@pdf.PdfName::of_string("/" + base_font))),
  ])
}

///|
fn default_resources() -> PdfObject {
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
fn a4_mediabox() -> PdfObject {
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
fn ops_stroke_line(
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
fn ops_crosshatch(
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  step : Double,
  rgb : (Double, Double, Double),
  width : Double,
) -> Array[Op] {
  let ops : Array[Op] = Array::new()
  let mut i = 0.0
  while i <= w + h {
    let x0 = x + i
    let y0 = y
    let x1 = x
    let y1 = y + i
    let (sx0, sy0, sx1, sy1) = if x0 <= x + w && y1 <= y + h {
      (x0, y0, x1, y1)
    } else if x0 > x + w {
      (x + w, y + (i - w), x1, y1)
    } else {
      (x0, y0, x + (i - h), y + h)
    }
    ops.append(ops_stroke_line(sx0, sy0, sx1, sy1, rgb, width)[:])
    i = i + step
  }
  let mut j = 0.0
  while j <= w + h {
    let x0 = x + j
    let y0 = y + h
    let x1 = x
    let y1 = y + h - j
    let (sx0, sy0, sx1, sy1) = if x0 <= x + w && y1 >= y {
      (x0, y0, x1, y1)
    } else if x0 > x + w {
      (x + w, y + h - (j - w), x1, y1)
    } else {
      (x0, y0, x + (j - h), y)
    }
    ops.append(ops_stroke_line(sx0, sy0, sx1, sy1, rgb, width)[:])
    j = j + step
  }
  ops
}

///|
priv struct Rng {
  state : Ref[UInt]
}

///|
fn Rng::new(seed : UInt) -> Rng {
  let s = if seed == 0 { 0x9E3779B9U } else { seed }
  { state: { val: s } }
}

///|
fn Rng::next_u32(self : Rng) -> UInt {
  let mut x = self.state.val
  x = x ^ (x << 13)
  x = x ^ (x >> 17)
  x = x ^ (x << 5)
  self.state.val = x
  x
}

///|
fn Rng::next_int(self : Rng, n : Int) -> Int {
  if n <= 0 {
    return 0
  }
  self.next_u32().reinterpret_as_int().abs() % n
}

///|
priv enum Dir {
  N
  E
  S
  W
} derive(Eq)

///|
fn opposite(d : Dir) -> Dir {
  match d {
    N => S
    S => N
    E => W
    W => E
  }
}

///|
fn dir_delta(d : Dir) -> (Int, Int) {
  match d {
    N => (0, 1)
    S => (0, -1)
    E => (1, 0)
    W => (-1, 0)
  }
}

///|
priv struct Cell {
  open_n : Bool
  open_e : Bool
  open_s : Bool
  open_w : Bool
}

///|
fn Cell::empty() -> Cell {
  { open_n: false, open_e: false, open_s: false, open_w: false }
}

///|
fn Cell::is_open(self : Cell, d : Dir) -> Bool {
  match d {
    N => self.open_n
    E => self.open_e
    S => self.open_s
    W => self.open_w
  }
}

///|
fn Cell::with_open(self : Cell, d : Dir, value : Bool) -> Cell {
  match d {
    N =>
      {
        open_n: value,
        open_e: self.open_e,
        open_s: self.open_s,
        open_w: self.open_w,
      }
    E =>
      {
        open_n: self.open_n,
        open_e: value,
        open_s: self.open_s,
        open_w: self.open_w,
      }
    S =>
      {
        open_n: self.open_n,
        open_e: self.open_e,
        open_s: value,
        open_w: self.open_w,
      }
    W =>
      {
        open_n: self.open_n,
        open_e: self.open_e,
        open_s: self.open_s,
        open_w: value,
      }
  }
}

///|
priv struct Maze {
  w : Int
  h : Int
  cells : Array[Cell]
}

///|
fn Maze::new(w : Int, h : Int) -> Maze {
  let cells = Array::new(capacity=w * h)
  for _ in 0..<(w * h) {
    cells.push(Cell::empty())
  }
  { w, h, cells }
}

///|
fn idx(w : Int, x : Int, y : Int) -> Int {
  y * w + x
}

///|
fn in_bounds(w : Int, h : Int, x : Int, y : Int) -> Bool {
  x >= 0 && x < w && y >= 0 && y < h
}

///|
fn Maze::neighbors(self : Maze, x : Int, y : Int) -> Array[(Dir, Int, Int)] {
  let out = Array::new(capacity=4)
  let dirs : Array[Dir] = [N, E, S, W]
  for d in dirs {
    let (dx, dy) = dir_delta(d)
    let nx = x + dx
    let ny = y + dy
    if in_bounds(self.w, self.h, nx, ny) {
      out.push((d, nx, ny))
    }
  }
  out
}

///|
fn Maze::carved(self : Maze, seed : UInt) -> Maze {
  let maze = self
  let rng = Rng::new(seed)
  let visited = Array::new(capacity=maze.w * maze.h)
  for _ in 0..<(maze.w * maze.h) {
    visited.push(false)
  }
  let stack : Array[(Int, Int)] = [(0, 0)]
  visited[idx(maze.w, 0, 0)] = true
  while stack.length() > 0 {
    let (cx, cy) = stack[stack.length() - 1]
    let neighbors = maze.neighbors(cx, cy)
    let candidates : Array[(Dir, Int, Int)] = Array::new()
    for entry in neighbors {
      let (_, nx, ny) = entry
      if !visited[idx(maze.w, nx, ny)] {
        candidates.push(entry)
      }
    }
    if candidates.length() == 0 {
      let _ = stack.pop()
      continue
    }
    let choice = candidates[rng.next_int(candidates.length())]
    let (d, nx, ny) = choice
    let i0 = idx(maze.w, cx, cy)
    let i1 = idx(maze.w, nx, ny)
    maze.cells[i0] = maze.cells[i0].with_open(d, true)
    maze.cells[i1] = maze.cells[i1].with_open(opposite(d), true)
    visited[i1] = true
    stack.push((nx, ny))
  }
  maze
}

///|
fn Maze::cell(self : Maze, x : Int, y : Int) -> Cell {
  self.cells[idx(self.w, x, y)]
}

///|
fn Maze::bfs_parents(
  self : Maze,
  start : (Int, Int),
) -> (Array[Int], Array[Int]) {
  let n = self.w * self.h
  let dist = Array::new(capacity=n)
  let parent = Array::new(capacity=n)
  for _ in 0..<n {
    dist.push(-1)
    parent.push(-1)
  }
  let q = Array::new()
  let (sx, sy) = start
  let s = idx(self.w, sx, sy)
  dist[s] = 0
  q.push(s)
  let mut qi = 0
  while qi < q.length() {
    let v = q[qi]
    qi = qi + 1
    let x = v % self.w
    let y = v / self.w
    let cell = self.cell(x, y)
    let dirs : Array[Dir] = [N, E, S, W]
    for d in dirs {
      if !cell.is_open(d) {
        continue
      }
      let (dx, dy) = dir_delta(d)
      let nx = x + dx
      let ny = y + dy
      if !in_bounds(self.w, self.h, nx, ny) {
        continue
      }
      let u = idx(self.w, nx, ny)
      if dist[u] != -1 {
        continue
      }
      dist[u] = dist[v] + 1
      parent[u] = v
      q.push(u)
    }
  }
  (dist, parent)
}

///|
fn farthest(dist : Array[Int]) -> Int {
  let mut best_i = 0
  let mut best_d = -1
  for i in 0..<dist.length() {
    if dist[i] > best_d {
      best_d = dist[i]
      best_i = i
    }
  }
  best_i
}

///|
fn build_path(parent : Array[Int], start_i : Int, goal_i : Int) -> Array[Int] {
  let out = Array::new()
  let mut cur = goal_i
  while cur != -1 {
    out.push(cur)
    if cur == start_i {
      break
    }
    cur = parent[cur]
  }
  out.rev_in_place()
  out
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
  let fog : PdfObject = Dictionary([
    ("/Type", Name(PdfName(b"/OCG"))),
    ("/Name", PdfString("FOG")),
  ])
  let solution : PdfObject = Dictionary([
    ("/Type", Name(PdfName(b"/OCG"))),
    ("/Name", PdfString("SOLUTION")),
  ])
  let fog_num = pdf.addobj(fog)
  let sol_num = pdf.addobj(solution)
  let default_dict : PdfObject = Dictionary([
    ("/BaseState", Name(PdfName(b"/ON"))),
    ("/Intent", Name(PdfName(b"/View"))),
    ("/Name", PdfString("Default")),
    ("/ON", PdfArray([Indirect(fog_num)])),
    ("/OFF", PdfArray([Indirect(sol_num)])),
  ])
  let ocprops : PdfObject = Dictionary([
    ("/OCGs", PdfArray([Indirect(fog_num), Indirect(sol_num)])),
    ("/D", default_dict),
  ])
  let ocprops_num = pdf.addobj(ocprops)
  set_catalog_entry(pdf, "/OCProperties", Indirect(ocprops_num))
  (fog_num, sol_num)
}

///|
fn add_layer_properties_to_pages(
  pdf : @pdf.Pdf,
  fog_num : Int,
  sol_num : Int,
) -> @pdf.Pdf raise {
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  for i in 0..<pages.length() {
    let page = pages[i]
    let props : PdfObject = Dictionary([
      ("/FOG", Indirect(fog_num)),
      ("/SOLUTION", Indirect(sol_num)),
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
fn page_of_ops(ops : Array[Op]) -> @pdfpage.Page raise {
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
fn cover_ops(seed : UInt) -> Array[Op] {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, 595.0, 842.0, (0.06, 0.07, 0.1))[:])
  for i in 0..<20 {
    let t = i.to_double() / 19.0
    let rgb = hsv_to_rgb(210.0 - 140.0 * t, 0.75, 0.95)
    ops.append(
      ops_fill_rect(0.0, 720.0 - 12.0 * i.to_double(), 595.0, 10.0, rgb)[:],
    )
  }
  ops.append(
    ops_text(54.0, 760.0, "/F0", 36.0, "PDF Escape Maze", (0.95, 0.96, 0.98))[:],
  )
  ops.append(
    ops_text(
      56.0,
      720.0,
      "/F1",
      14.0,
      "A clickable maze: each door is a link to another room.",
      (0.8, 0.84, 0.9),
    )[:],
  )
  ops.append(
    ops_text(
      56.0,
      698.0,
      "/F1",
      14.0,
      "Open the Bookmarks panel for quick jumps.",
      (0.8, 0.84, 0.9),
    )[:],
  )
  ops.append(
    ops_text(
      56.0,
      676.0,
      "/F1",
      14.0,
      "Open the Layers panel to toggle FOG and SOLUTION.",
      (0.8, 0.84, 0.9),
    )[:],
  )
  ops.append(
    ops_text(
      56.0,
      620.0,
      "/F2",
      12.0,
      "Seed: " + seed.to_string(),
      (0.6, 0.64, 0.7),
    )[:],
  )
  ops.append(
    ops_text(
      56.0,
      590.0,
      "/F2",
      12.0,
      "Start in Room 1. Find the Exit.",
      (0.6, 0.64, 0.7),
    )[:],
  )
  ops
}

///|
fn room_ops(
  w : Int,
  h : Int,
  x : Int,
  y : Int,
  room_idx_1 : Int,
  is_start : Bool,
  is_exit : Bool,
  cell : Cell,
  next_hint? : Dir? = None,
) -> Array[Op] {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, 595.0, 842.0, (0.985, 0.985, 0.99))[:])
  let title = if is_exit {
    "Room " + room_idx_1.to_string() + " • EXIT"
  } else if is_start {
    "Room " + room_idx_1.to_string() + " • START"
  } else {
    "Room " + room_idx_1.to_string()
  }
  ops.append(ops_text(54.0, 800.0, "/F0", 24.0, title, (0.12, 0.14, 0.18))[:])
  ops.append(
    ops_text(
      54.0,
      774.0,
      "/F2",
      11.0,
      "Grid: " +
      w.to_string() +
      "×" +
      h.to_string() +
      " | Coord: (" +
      x.to_string() +
      "," +
      y.to_string() +
      ")",
      (0.35, 0.38, 0.42),
    )[:],
  )

  // Room frame
  let rx = 120.0
  let ry = 280.0
  let rw = 355.0
  let rh = 410.0
  ops.append(ops_fill_rect(rx, ry, rw, rh, (1.0, 1.0, 1.0))[:])
  ops.append(ops_stroke_rect(rx, ry, rw, rh, (0.15, 0.17, 0.2), 2.0)[:])

  // Door gaps
  let door_w = 86.0
  let door_h = 20.0
  let cx = rx + rw / 2.0
  let cy = ry + rh / 2.0
  let hole = (0.985, 0.985, 0.99)
  if cell.open_n {
    ops.append(
      ops_fill_rect(cx - door_w / 2.0, ry + rh - 2.0, door_w, door_h, hole)[:],
    )
  }
  if cell.open_s {
    ops.append(
      ops_fill_rect(cx - door_w / 2.0, ry - door_h + 2.0, door_w, door_h, hole)[:],
    )
  }
  if cell.open_e {
    ops.append(
      ops_fill_rect(rx + rw - 2.0, cy - door_w / 2.0, door_h, door_w, hole)[:],
    )
  }
  if cell.open_w {
    ops.append(
      ops_fill_rect(rx - door_h + 2.0, cy - door_w / 2.0, door_h, door_w, hole)[:],
    )
  }

  // Icons indicating available doors
  let accent_on = (0.25, 0.55, 0.9)
  let accent_off = (0.78, 0.8, 0.84)
  ops.append(
    ops_text(56.0, 720.0, "/F2", 11.0, "Doors:", (0.35, 0.38, 0.42))[:],
  )
  ops.append(
    ops_text(
      120.0,
      720.0,
      "/F2",
      11.0,
      "N",
      if cell.open_n {
        accent_on
      } else {
        accent_off
      },
    )[:],
  )
  ops.append(
    ops_text(
      136.0,
      720.0,
      "/F2",
      11.0,
      "E",
      if cell.open_e {
        accent_on
      } else {
        accent_off
      },
    )[:],
  )
  ops.append(
    ops_text(
      152.0,
      720.0,
      "/F2",
      11.0,
      "S",
      if cell.open_s {
        accent_on
      } else {
        accent_off
      },
    )[:],
  )
  ops.append(
    ops_text(
      168.0,
      720.0,
      "/F2",
      11.0,
      "W",
      if cell.open_w {
        accent_on
      } else {
        accent_off
      },
    )[:],
  )

  // Fog layer: soft crosshatch overlay
  ops.push(OpBDC("/OC", Name(PdfName(b"/FOG"))))
  ops.append(ops_crosshatch(rx, ry, rw, rh, 18.0, (0.92, 0.93, 0.95), 0.5)[:])
  ops.push(OpEMC)

  // Solution layer: hint arrow
  match next_hint {
    None => ()
    Some(d) => {
      ops.push(OpBDC("/OC", Name(PdfName(b"/SOLUTION"))))
      let arrow_color = (0.95, 0.3, 0.35)
      let ax0 = cx
      let ay0 = cy
      let (ax1, ay1) = match d {
        N => (cx, ry + rh - 40.0)
        S => (cx, ry + 40.0)
        E => (rx + rw - 40.0, cy)
        W => (rx + 40.0, cy)
      }
      ops.append(ops_stroke_line(ax0, ay0, ax1, ay1, arrow_color, 4.0)[:])
      ops.append(
        ops_text(
          54.0,
          70.0,
          "/F2",
          11.0,
          "SOLUTION hint: follow the red arrow.",
          (0.55, 0.58, 0.62),
        )[:],
      )
      ops.push(OpEMC)
    }
  }

  // Footer
  ops.append(
    ops_text(
      54.0,
      40.0,
      "/F2",
      10.0,
      "Tip: click doors; use Back in your viewer too.",
      (0.55, 0.58, 0.62),
    )[:],
  )
  ops
}

///|
fn draw_map_ops(
  maze : Maze,
  start_i : Int,
  exit_i : Int,
  path : Array[Int],
) -> Array[Op] {
  let ops : Array[Op] = Array::new()
  ops.append(ops_fill_rect(0.0, 0.0, 595.0, 842.0, (0.99, 0.985, 0.97))[:])
  ops.append(
    ops_text(
      54.0,
      800.0,
      "/F0",
      26.0,
      "Maze Map (Clickable)",
      (0.12, 0.14, 0.18),
    )[:],
  )
  ops.append(
    ops_text(
      54.0,
      772.0,
      "/F1",
      13.0,
      "Click a tile to jump to that room.",
      (0.25, 0.28, 0.32),
    )[:],
  )
  let gx = 54.0
  let gy = 160.0
  let gw = 487.0
  let gh = 560.0
  ops.append(ops_stroke_rect(gx, gy, gw, gh, (0.2, 0.22, 0.26), 1.5)[:])
  let cell_w = gw / maze.w.to_double()
  let cell_h = gh / maze.h.to_double()

  // Grid lines
  for i in 1..<maze.w {
    let x = gx + cell_w * i.to_double()
    ops.append(ops_stroke_line(x, gy, x, gy + gh, (0.85, 0.86, 0.88), 1.0)[:])
  }
  for j in 1..<maze.h {
    let y = gy + cell_h * j.to_double()
    ops.append(ops_stroke_line(gx, y, gx + gw, y, (0.85, 0.86, 0.88), 1.0)[:])
  }

  // Carved corridors
  for y in 0..<maze.h {
    for x in 0..<maze.w {
      let cell = maze.cell(x, y)
      let cx = gx + x.to_double() * cell_w
      let cy = gy + y.to_double() * cell_h
      let mx = cx + cell_w / 2.0
      let my = cy + cell_h / 2.0
      if cell.open_n {
        ops.append(
          ops_stroke_line(mx, my, mx, cy + cell_h, (0.2, 0.22, 0.26), 2.0)[:],
        )
      }
      if cell.open_e {
        ops.append(
          ops_stroke_line(mx, my, cx + cell_w, my, (0.2, 0.22, 0.26), 2.0)[:],
        )
      }
    }
  }

  // Start/Exit tiles
  let sx = start_i % maze.w
  let sy = start_i / maze.w
  let ex = exit_i % maze.w
  let ey = exit_i / maze.w
  ops.append(
    ops_fill_rect(
      gx + sx.to_double() * cell_w,
      gy + sy.to_double() * cell_h,
      cell_w,
      cell_h,
      (0.85, 0.95, 0.9),
    )[:],
  )
  ops.append(
    ops_fill_rect(
      gx + ex.to_double() * cell_w,
      gy + ey.to_double() * cell_h,
      cell_w,
      cell_h,
      (0.98, 0.88, 0.88),
    )[:],
  )

  // Labels (after fills)
  ops.append(
    ops_text(
      gx + sx.to_double() * cell_w + 6.0,
      gy + sy.to_double() * cell_h + cell_h - 18.0,
      "/F2",
      10.0,
      "START",
      (0.1, 0.12, 0.14),
    )[:],
  )
  ops.append(
    ops_text(
      gx + ex.to_double() * cell_w + 6.0,
      gy + ey.to_double() * cell_h + cell_h - 18.0,
      "/F2",
      10.0,
      "EXIT",
      (0.1, 0.12, 0.14),
    )[:],
  )

  // Solution path (layer)
  ops.push(OpBDC("/OC", Name(PdfName(b"/SOLUTION"))))
  for i in 0..<(path.length() - 1) {
    let a = path[i]
    let b = path[i + 1]
    let ax = a % maze.w
    let ay = a / maze.w
    let bx = b % maze.w
    let by = b / maze.w
    let x0 = gx + (ax.to_double() + 0.5) * cell_w
    let y0 = gy + (ay.to_double() + 0.5) * cell_h
    let x1 = gx + (bx.to_double() + 0.5) * cell_w
    let y1 = gy + (by.to_double() + 0.5) * cell_h
    ops.append(ops_stroke_line(x0, y0, x1, y1, (0.95, 0.3, 0.35), 4.0)[:])
  }
  ops.push(OpEMC)
  ops.append(
    ops_text(
      54.0,
      80.0,
      "/F2",
      11.0,
      "Layer tips: turn off FOG for clarity; turn on SOLUTION for the red route.",
      (0.25, 0.28, 0.32),
    )[:],
  )
  ops
}

///|
fn add_bookmarks(
  pdf : @pdf.Pdf,
  room_refs : Array[Int],
  map_ref : Int,
) -> @pdf.Pdf raise {
  let marks : Array[@pdfmarks.Bookmark] = Array::new()
  if room_refs.length() > 0 {
    marks.push({
      level: 0,
      text: "Cover",
      target: Fit(PageObject(room_refs[0])),
      isopen: true,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    })
  }
  marks.push({
    level: 0,
    text: "Map",
    target: Fit(PageObject(map_ref)),
    isopen: true,
    colour: (0.0, 0.0, 0.0),
    flags: 0,
  })
  if room_refs.length() > 1 {
    marks.push({
      level: 0,
      text: "Rooms",
      target: Fit(PageObject(room_refs[1])),
      isopen: true,
      colour: (0.0, 0.0, 0.0),
      flags: 2,
    })
    for i in 1..<room_refs.length() {
      marks.push({
        level: 1,
        text: "Room " + i.to_string(),
        target: Fit(PageObject(room_refs[i])),
        isopen: false,
        colour: (0.0, 0.0, 0.0),
        flags: 0,
      })
    }
  }
  @pdfmarks.PdfMarks::new(pdf).add_bookmarks(marks)
}

///|
fn annotate_room_page(
  pdf : @pdf.Pdf,
  page : @pdfpage.Page,
  map_ref : Int,
  neighbors : Array[(Dir, Int)],
  room_refs : Array[Int],
) -> @pdfpage.Page raise {
  let mut p = page

  // A "Map" button.
  p = add_link(pdf, p, (54.0, 20.0, 124.0, 42.0), goto_action(map_ref))

  // Door buttons.
  let btn_y = 120.0
  let btn_w = 112.0
  let btn_h = 40.0
  let left_x = 54.0
  let mid_x = 54.0 + btn_w + 16.0
  let right_x = 54.0 + (btn_w + 16.0) * 2.0
  let positions : Array[(Dir, (Double, Double))] = [
    (N, (mid_x, btn_y + btn_h + 12.0)),
    (W, (left_x, btn_y)),
    (E, (right_x, btn_y)),
    (S, (mid_x, btn_y - btn_h - 12.0)),
  ]
  for entry in positions {
    let (d, (x, y)) = entry
    let found = neighbors.filter_map(n => {
      let (nd, ti) = n
      if nd == d {
        Some(ti)
      } else {
        None
      }
    })
    match found {
      [] => ()
      [ti, ..] => {
        let target_ref = room_refs[ti]
        p = add_link(
          pdf,
          p,
          (x, y, x + btn_w, y + btn_h),
          goto_action(target_ref),
        )
      }
    }
  }
  p
}

///|
fn annotate_map_page(
  pdf : @pdf.Pdf,
  page : @pdfpage.Page,
  maze : Maze,
  room_refs : Array[Int],
) -> @pdfpage.Page raise {
  let mut p = page
  let gx = 54.0
  let gy = 160.0
  let gw = 487.0
  let gh = 560.0
  let cell_w = gw / maze.w.to_double()
  let cell_h = gh / maze.h.to_double()
  for y in 0..<maze.h {
    for x in 0..<maze.w {
      let i = idx(maze.w, x, y)
      let x0 = gx + x.to_double() * cell_w
      let y0 = gy + y.to_double() * cell_h
      let rect = (x0, y0, x0 + cell_w, y0 + cell_h)
      p = add_link(pdf, p, rect, goto_action(room_refs[i + 1]))
    }
  }
  p
}

///|
pub async fn run(
  out_file? : String = "maze.pdf",
  seed? : UInt = 20260131U,
  quiet? : Bool = false,
) -> Unit {
  try {
    let maze = Maze::new(4, 4).carved(seed)
    let (dist, parent) = maze.bfs_parents((0, 0))
    let start_i = idx(maze.w, 0, 0)
    let exit_i = farthest(dist)
    let path = build_path(parent, start_i, exit_i)
    let path_set = Map([], capacity=path.length())
    for p in path {
      path_set.set(p, ())
    }

    // Pages: cover + rooms (w*h) + map.
    let pages : Array[@pdfpage.Page] = Array::new()
    pages.push(page_of_ops(cover_ops(seed)))
    for y in 0..<maze.h {
      for x in 0..<maze.w {
        let i = idx(maze.w, x, y)
        let is_start = i == start_i
        let is_exit = i == exit_i

        // Hint: next step along path if present.
        let mut hint : Dir? = None
        if path_set.get(i) is Some(_) && !is_exit {
          for k in 0..<(path.length() - 1) {
            if path[k] == i {
              let next = path[k + 1]
              let nx = next % maze.w
              let ny = next / maze.w
              if nx == x + 1 {
                hint = Some(E)
              } else if nx == x - 1 {
                hint = Some(W)
              } else if ny == y + 1 {
                hint = Some(N)
              } else if ny == y - 1 {
                hint = Some(S)
              }
            }
          }
        }
        let ops = room_ops(
          maze.w,
          maze.h,
          x,
          y,
          i + 1,
          is_start,
          is_exit,
          maze.cell(x, y),
          next_hint=hint,
        )
        pages.push(page_of_ops(ops))
      }
    }
    let map_ops = draw_map_ops(maze, start_i, exit_i, path)
    pages.push(page_of_ops(map_ops))
    let (pdf, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree(
      pages,
    )
    let pdf = @pdfpage.PdfPageDoc::new(pdf).add_root(pageroot, [])
    let (fog_num, sol_num) = add_layers(pdf)
    let pdf = add_layer_properties_to_pages(pdf, fog_num, sol_num)
    let refs = pdf.page_reference_numbers()
    // refs: cover at 0, rooms at 1..(w*h), map at end.
    let map_ref = refs[refs.length() - 1]
    let room_refs = refs[:refs.length() - 1].to_owned()
    let pdf = add_bookmarks(pdf, room_refs, map_ref)

    // Annotate pages (links).
    let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
    let out_pages = pages

    // Map page gets tile links.
    out_pages[out_pages.length() - 1] = annotate_map_page(
      pdf,
      out_pages[out_pages.length() - 1],
      maze,
      room_refs,
    )

    // Each room page (skip cover at 0, map at end).
    for y in 0..<maze.h {
      for x in 0..<maze.w {
        let i = idx(maze.w, x, y) // 0..(w*h-1)
        let page_i = 1 + i
        let cell = maze.cell(x, y)
        let nbs : Array[(Dir, Int)] = Array::new()
        let dirs : Array[Dir] = [N, E, S, W]
        for d in dirs {
          if !cell.is_open(d) {
            continue
          }
          let (dx, dy) = dir_delta(d)
          let nx = x + dx
          let ny = y + dy
          if in_bounds(maze.w, maze.h, nx, ny) {
            nbs.push((d, idx(maze.w, nx, ny) + 1))
          }
        }
        out_pages[page_i] = annotate_room_page(
          pdf,
          out_pages[page_i],
          map_ref,
          nbs,
          room_refs,
        )
      }
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
    [_, out, seed] =>
      try @string.parse_int(seed) catch {
        _ => run(out_file=out)
      } noraise {
        n => run(out_file=out, seed=n.reinterpret_as_uint())
      }
    _ => run()
  }
}
