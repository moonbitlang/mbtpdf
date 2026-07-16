///|
fn mk_point(x : Double, y : Double, z : Double) -> @pdf.PdfObject {
  PdfArray([Real(x), Real(y), Real(z)])
}

///|
fn stream_of_bytes(values : Array[Int]) -> @pdf.PdfObject {
  let dict : @pdf.PdfObject = Dictionary([])
  let data = @pdfio.bytes_of_list(values)
  Stream(Ref((dict, Got(data))))
}

///|
fn icc_stream_with_n(n : Int) -> @pdf.PdfObject {
  let dict : @pdf.PdfObject = Dictionary([("/N", Integer(n))])
  let data = @pdfio.bytes_of_list([0, 1, 2, 3])
  Stream(Ref((dict, Got(data))))
}

///|
test "read_colourspace resolves named entry from resources" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([
    ("/ColorSpace", Dictionary([("/CS1", Name(PdfName(b"/DeviceCMYK")))])),
  ])
  let space = ColourSpace::read(pdf, resources, Name(PdfName(b"/CS1")))
  match (space : ColourSpace) {
    DeviceCMYK => ()
    _ => fail("expected DeviceCMYK")
  }
}

///|
test "read_colourspace uses default gamma for CalGray" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([
    ("/WhitePoint", mk_point(1.0, 1.0, 1.0)),
    ("/BlackPoint", mk_point(0.0, 0.0, 0.0)),
  ])
  let space = ColourSpace::read(
    pdf,
    Dictionary([]),
    PdfArray([Name(PdfName(b"/CalGray")), dict]),
  )
  match (space : ColourSpace) {
    CalGray(_, _, gamma) => assert_eq(gamma, 1.0)
    _ => fail("expected CalGray")
  }
}

///|
test "read_colourspace uses default gamma and matrix for CalRGB" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([
    ("/WhitePoint", mk_point(1.0, 1.0, 1.0)),
    ("/BlackPoint", mk_point(0.0, 0.0, 0.0)),
  ])
  let space = ColourSpace::read(
    pdf,
    Dictionary([]),
    PdfArray([Name(PdfName(b"/CalRGB")), dict]),
  )
  match (space : ColourSpace) {
    CalRGB(_, _, gamma, matrix) => {
      assert_eq(gamma, [1.0, 1.0, 1.0])
      assert_eq(matrix, [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0])
    }
    _ => fail("expected CalRGB")
  }
}

///|
test "read_colourspace uses default range for Lab" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([
    ("/WhitePoint", mk_point(1.0, 1.0, 1.0)),
    ("/BlackPoint", mk_point(0.0, 0.0, 0.0)),
  ])
  let space = ColourSpace::read(
    pdf,
    Dictionary([]),
    PdfArray([Name(PdfName(b"/Lab")), dict]),
  )
  match (space : ColourSpace) {
    Lab(_, _, range) => assert_eq(range, [-100.0, 100.0, -100.0, 100.0])
    _ => fail("expected Lab")
  }
}

///|
test "read_colourspace Indexed parses lookup stream" {
  let pdf = @pdf.Pdf::empty()
  let stream_obj = stream_of_bytes([1, 2, 3, 4, 5, 6])
  let space = ColourSpace::read(
    pdf,
    Dictionary([]),
    PdfArray([
      Name(PdfName(b"/Indexed")),
      Name(PdfName(b"/DeviceRGB")),
      Integer(1),
      stream_obj,
    ]),
  )
  match (space : ColourSpace) {
    Indexed(DeviceRGB, table) => {
      match table.get(0) {
        Some(values) => assert_eq(values, [1, 2, 3])
        None => fail("missing table entry 0")
      }
      match table.get(1) {
        Some(values) => assert_eq(values, [4, 5, 6])
        None => fail("missing table entry 1")
      }
    }
    _ => fail("expected Indexed DeviceRGB")
  }
}

///|
test "read_colourspace Indexed handles DeviceN base" {
  let pdf = @pdf.Pdf::empty()
  let tint = sample_tint_function().to_pdf_object(pdf)
  let table = @pdfio.string_of_int_array([0, 0, 0])
  let indexed_arr : Array[@pdf.PdfObject] = [
    Name(PdfName(b"/Indexed")),
    PdfArray([
      Name(PdfName(b"/DeviceN")),
      PdfArray([Name(PdfName(b"/C1"))]),
      Name(PdfName(b"/DeviceRGB")),
      tint,
    ]),
    Integer(0),
    PdfString(table),
  ]
  let space = ColourSpace::read(pdf, Dictionary([]), PdfArray(indexed_arr))
  match (space : ColourSpace) {
    Indexed(DeviceN(_, _, _, _), table_map) =>
      match table_map.get(0) {
        Some(values) => assert_eq(values, [0, 0, 0])
        None => fail("expected table entry")
      }
    _ => fail("expected Indexed DeviceN")
  }
}

///|
test "read_colourspace Indexed handles DeviceCMYK base" {
  let pdf = @pdf.Pdf::empty()
  let stream_obj = stream_of_bytes([1, 2, 3, 4])
  let space = ColourSpace::read(
    pdf,
    Dictionary([]),
    PdfArray([
      Name(PdfName(b"/Indexed")),
      Name(PdfName(b"/DeviceCMYK")),
      Integer(0),
      stream_obj,
    ]),
  )
  match (space : ColourSpace) {
    Indexed(DeviceCMYK, table) =>
      match table.get(0) {
        Some(values) => assert_eq(values.length(), 4)
        None => fail("expected table entry")
      }
    _ => fail("expected Indexed DeviceCMYK")
  }
}

///|
test "read_colourspace Indexed errors on invalid inputs" {
  let pdf = @pdf.Pdf::empty()
  let stream_obj = stream_of_bytes([0, 0, 0])
  let bad_hival_arr : Array[@pdf.PdfObject] = [
    Name(PdfName(b"/Indexed")),
    Name(PdfName(b"/DeviceRGB")),
    Name(PdfName(b"/Bad")),
    PdfString(@pdfio.string_of_int_array([0, 0, 0])),
  ]
  let bad_hival : Result[ColourSpace, Error] = try
    ColourSpace::read(pdf, Dictionary([]), PdfArray(bad_hival_arr)) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(bad_hival is Err(_))
  let bad_base_stream_arr : Array[@pdf.PdfObject] = [
    Name(PdfName(b"/Indexed")),
    Name(PdfName(b"/Pattern")),
    Integer(0),
    stream_obj,
  ]
  let bad_base_stream : Result[ColourSpace, Error] = try
    ColourSpace::read(pdf, Dictionary([]), PdfArray(bad_base_stream_arr)) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(bad_base_stream is Err(_))
  let bad_base_string_arr : Array[@pdf.PdfObject] = [
    Name(PdfName(b"/Indexed")),
    Name(PdfName(b"/DeviceGray")),
    Integer(0),
    PdfString(@pdfio.string_of_int_array([0])),
  ]
  let bad_base_string : Result[ColourSpace, Error] = try
    ColourSpace::read(pdf, Dictionary([]), PdfArray(bad_base_string_arr)) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(bad_base_string is Err(_))
  let bad_lookup_arr : Array[@pdf.PdfObject] = [
    Name(PdfName(b"/Indexed")),
    Name(PdfName(b"/DeviceRGB")),
    Integer(0),
    Integer(5),
  ]
  let bad_lookup : Result[ColourSpace, Error] = try
    ColourSpace::read(pdf, Dictionary([]), PdfArray(bad_lookup_arr)) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(bad_lookup is Err(_))
  let toget = @pdf.ToGet::new(@pdfio.Input::of_string("abc"), 0, 3)
  let stream_dict : @pdf.PdfObject = Dictionary([])
  let bad_stream : @pdf.PdfObject = Stream(Ref((stream_dict, ToGet(toget))))
  let bad_toget_arr : Array[@pdf.PdfObject] = [
    Name(PdfName(b"/Indexed")),
    Name(PdfName(b"/DeviceRGB")),
    Integer(0),
    bad_stream,
  ]
  let bad_toget : Result[ColourSpace, Error] = try
    ColourSpace::read(pdf, Dictionary([]), PdfArray(bad_toget_arr)) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(bad_toget is Err(_))
}

///|
test "read_colourspace ICCBased invalid N errors" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([("/N", Integer(2))])
  let data = @pdfio.bytes_of_list([1, 2, 3])
  let stream_obj : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  let res : Result[ColourSpace, Error] = try
    ColourSpace::read(
      pdf,
      Dictionary([]),
      PdfArray([Name(PdfName(b"/ICCBased")), stream_obj]),
    )
    |> Ok
  catch {
    e => Err(e)
  }
  match res {
    Err(_) => ()
    _ => fail("expected ICCBased /N error")
  }
}

///|
test "read_colourspace ICCBased defaults alternate by N" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let cs1 = ColourSpace::read(
    pdf,
    resources,
    PdfArray([Name(PdfName(b"/ICCBased")), icc_stream_with_n(1)]),
  )
  let cs3 = ColourSpace::read(
    pdf,
    resources,
    PdfArray([Name(PdfName(b"/ICCBased")), icc_stream_with_n(3)]),
  )
  let cs4 = ColourSpace::read(
    pdf,
    resources,
    PdfArray([Name(PdfName(b"/ICCBased")), icc_stream_with_n(4)]),
  )
  match (cs1 : ColourSpace) {
    ICCBased(icc) =>
      match (icc.icc_alternate : ColourSpace) {
        DeviceGray => ()
        _ => fail("expected DeviceGray alternate")
      }
    _ => fail("expected ICCBased")
  }
  match (cs3 : ColourSpace) {
    ICCBased(icc) =>
      match (icc.icc_alternate : ColourSpace) {
        DeviceRGB => ()
        _ => fail("expected DeviceRGB alternate")
      }
    _ => fail("expected ICCBased")
  }
  match (cs4 : ColourSpace) {
    ICCBased(icc) =>
      match (icc.icc_alternate : ColourSpace) {
        DeviceCMYK => ()
        _ => fail("expected DeviceCMYK alternate")
      }
    _ => fail("expected ICCBased")
  }
}

///|
test "write_colourspace Indexed unsupported base returns null" {
  let pdf = @pdf.Pdf::empty()
  let table : Map[Int, Array[Int]] = Map([])
  table.set(0, [0, 0, 0])
  let space : ColourSpace = Indexed(Pattern, table)
  let obj = @pdfe.with_logger(_ => (), fn() { space.to_pdf_object(pdf) })
  match (obj : @pdf.PdfObject) {
    Null => ()
    _ => fail("expected null for unsupported base")
  }
}

///|
test "write_colourspace ICCBased missing stream falls back" {
  let pdf = @pdf.Pdf::empty()
  let icc : ICCBased = {
    icc_n: 3,
    icc_alternate: DeviceRGB,
    icc_range: [0.0, 1.0, 0.0, 1.0, 0.0, 1.0],
    icc_metadata: None,
    icc_stream: Null,
  }
  let obj = @pdfe.with_logger(_ => (), fn() {
    ColourSpace::ICCBased(icc).to_pdf_object(pdf)
  })
  match (obj : @pdf.PdfObject) {
    PdfArray([Name(PdfName(b"/ICCBased")), alt]) =>
      match (alt : @pdf.PdfObject) {
        Name(PdfName(b"/DeviceRGB")) => ()
        _ => fail("expected alternate colourspace")
      }
    _ => fail("expected ICCBased array")
  }
}

///|
test "write_colourspace DeviceN omits empty attributes" {
  let pdf = @pdf.Pdf::empty()
  let tint = sample_tint_function()
  let space : ColourSpace = DeviceN(["C1"], DeviceRGB, tint, Dictionary([]))
  let obj = space.to_pdf_object(pdf)
  match (obj : @pdf.PdfObject) {
    PdfArray(items) => assert_eq(items.length(), 4)
    _ => fail("expected DeviceN array")
  }
}

///|
test "write_colourspace DeviceN includes non-dict attributes" {
  let pdf = @pdf.Pdf::empty()
  let tint = sample_tint_function()
  let space : ColourSpace = DeviceN(
    ["/Spot"],
    DeviceRGB,
    tint,
    Name(PdfName(b"/Attrs")),
  )
  let obj = space.to_pdf_object(pdf)
  match (obj : @pdf.PdfObject) {
    PdfArray(items) => assert_eq(items.length(), 5)
    _ => fail("expected DeviceN array with attrs")
  }
}

///|
test "write_colourspace Indexed handles DeviceGray and DeviceCMYK" {
  let pdf = @pdf.Pdf::empty()
  let table_gray : Map[Int, Array[Int]] = Map([])
  table_gray.set(0, [0])
  let gray = ColourSpace::Indexed(DeviceGray, table_gray).to_pdf_object(pdf)
  match (gray : @pdf.PdfObject) {
    PdfArray([Name(PdfName(b"/Indexed")), _, _, _]) => ()
    _ => fail("expected indexed DeviceGray")
  }
  let table_cmyk : Map[Int, Array[Int]] = Map([])
  table_cmyk.set(0, [0, 0, 0, 0])
  let cmyk = ColourSpace::Indexed(DeviceCMYK, table_cmyk).to_pdf_object(pdf)
  match (cmyk : @pdf.PdfObject) {
    PdfArray([Name(PdfName(b"/Indexed")), _, _, _]) => ()
    _ => fail("expected indexed DeviceCMYK")
  }
}

///|
test "write_colourspace returns pattern name" {
  let pdf = @pdf.Pdf::empty()
  let obj = ColourSpace::Pattern.to_pdf_object(pdf)
  match (obj : @pdf.PdfObject) {
    Name(PdfName(b"/Pattern")) => ()
    _ => fail("expected /Pattern name")
  }
}

///|
test "write_colourspace ICCBased preserves length and skips bad range" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([
    ("/N", Integer(1)),
    ("/Length", Integer(3)),
  ])
  let stream_obj : @pdf.PdfObject = Stream(
    Ref((dict, Got(@pdfio.bytes_of_string("icc")))),
  )
  let icc : ICCBased = {
    icc_n: 3,
    icc_alternate: DeviceRGB,
    icc_range: [0.0],
    icc_metadata: None,
    icc_stream: stream_obj,
  }
  let obj = ColourSpace::ICCBased(icc).to_pdf_object(pdf)
  match (obj : @pdf.PdfObject) {
    PdfArray([Name(PdfName(b"/ICCBased")), Indirect(n)]) =>
      match (pdf.lookup_obj(n) : @pdf.PdfObject) {
        Stream(r) => {
          let (dict_obj, _) = r.val
          assert_true(pdf.lookup_direct("/Length", dict_obj) is Some(_))
          assert_true(pdf.lookup_direct("/Range", dict_obj) is None)
        }
        _ => fail("expected ICCBased stream")
      }
    _ => fail("expected ICCBased array")
  }
}

///|
test "write_colourspace ICCBased handles non-dict stream data" {
  let pdf = @pdf.Pdf::empty()
  let toget = @pdf.ToGet::new(@pdfio.Input::of_string("data"), 0, 4)
  let stream_dict : @pdf.PdfObject = Name(PdfName(b"/Bad"))
  let stream_obj : @pdf.PdfObject = Stream(Ref((stream_dict, ToGet(toget))))
  let icc : ICCBased = {
    icc_n: 3,
    icc_alternate: DeviceRGB,
    icc_range: [],
    icc_metadata: None,
    icc_stream: stream_obj,
  }
  let obj = ColourSpace::ICCBased(icc).to_pdf_object(pdf)
  match (obj : @pdf.PdfObject) {
    PdfArray([Name(PdfName(b"/ICCBased")), Indirect(_)]) => ()
    _ => fail("expected ICCBased array")
  }
}

///|
test "ColourSpace::to_string covers variants" {
  let icc : ICCBased = {
    icc_n: 3,
    icc_alternate: DeviceRGB,
    icc_range: [0.0, 1.0, 0.0, 1.0, 0.0, 1.0],
    icc_metadata: None,
    icc_stream: Null,
  }
  assert_eq(@pdfspace.ColourSpace::DeviceGray.to_string(), "/DeviceGray")
  assert_eq(@pdfspace.ColourSpace::DeviceCMYK.to_string(), "/DeviceCMYK")
  assert_eq(
    @pdfspace.ColourSpace::ICCBased(icc).to_string(),
    "ICCBased (/DeviceRGB)",
  )
  assert_eq(
    @pdfspace.ColourSpace::PatternWithBaseColourspace(DeviceRGB).to_string(),
    "PatternWithBaseColourspace (/DeviceRGB)",
  )
  assert_eq(
    @pdfspace.ColourSpace::Separation("Spot", DeviceRGB, sample_tint_function()).to_string(),
    "Separation (/DeviceRGB)",
  )
  let table : Map[Int, Array[Int]] = Map([])
  table.set(0, [0, 0, 0])
  assert_eq(
    @pdfspace.ColourSpace::Indexed(DeviceRGB, table).to_string(),
    "Indexed (/DeviceRGB)",
  )
  assert_eq(@pdfspace.ColourSpace::Pattern.to_string(), "/Pattern")
  assert_eq(
    @pdfspace.ColourSpace::DeviceN(
      ["C1"],
      DeviceRGB,
      sample_tint_function(),
      Dictionary([]),
    ).to_string(),
    "DeviceN (/DeviceRGB)",
  )
}

///|
test "ColourSpace::name returns none for non-separation" {
  let name = @pdfspace.ColourSpace::DeviceRGB.name()
  match name {
    None => ()
    _ => fail("expected none")
  }
}

///|
test "ColourSpace::to_string covers cal and lab variants" {
  let white = (1.0, 1.0, 1.0)
  let black = (0.0, 0.0, 0.0)
  assert_eq(
    @pdfspace.ColourSpace::CalGray(white, black, 1.0).to_string(),
    "/CalGray",
  )
  assert_eq(
    @pdfspace.ColourSpace::CalRGB(white, black, [1.0, 1.0, 1.0], [
      1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0,
    ]).to_string(),
    "/CalRGB",
  )
  assert_eq(
    @pdfspace.ColourSpace::Lab(white, black, [-100.0, 100.0, -100.0, 100.0]).to_string(),
    "/Lab",
  )
}

///|
test "read_colourspace handles indirect and singleton array" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let objnum = pdf.addobj(Name(PdfName(b"/DeviceGray")))
  let indirect = ColourSpace::read(pdf, resources, Indirect(objnum))
  match (indirect : ColourSpace) {
    DeviceGray => ()
    _ => fail("expected DeviceGray")
  }
  let singleton = ColourSpace::read(
    pdf,
    resources,
    PdfArray([Name(PdfName(b"/DeviceRGB"))]),
  )
  match (singleton : ColourSpace) {
    DeviceRGB => ()
    _ => fail("expected DeviceRGB")
  }
}

///|
test "read_colourspace errors on missing named entry" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([("/ColorSpace", Dictionary([]))])
  let res : Result[ColourSpace, Error] = try
    ColourSpace::read(pdf, resources, Name(PdfName(b"/Missing"))) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Err(_))
}

///|
test "read_colourspace errors when resources lack ColorSpace" {
  let pdf = @pdf.Pdf::empty()
  let res : Result[ColourSpace, Error] = try
    ColourSpace::read(pdf, Dictionary([]), Name(PdfName(b"/Missing"))) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Err(_))
}

///|
test "read_colourspace ICCBased errors on missing N and non-stream" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([])
  let data = @pdfio.bytes_of_string("icc")
  let stream_obj : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  let missing_n : Result[ColourSpace, Error] = try
    ColourSpace::read(
      pdf,
      Dictionary([]),
      PdfArray([Name(PdfName(b"/ICCBased")), stream_obj]),
    )
    |> Ok
  catch {
    e => Err(e)
  }
  assert_true(missing_n is Err(_))
  let non_stream : Result[ColourSpace, Error] = try
    ColourSpace::read(
      pdf,
      Dictionary([]),
      PdfArray([Name(PdfName(b"/ICCBased")), Integer(1)]),
    )
    |> Ok
  catch {
    e => Err(e)
  }
  assert_true(non_stream is Err(_))
}

///|
test "read_colourspace errors on unsupported object" {
  let pdf = @pdf.Pdf::empty()
  let res : Result[ColourSpace, Error] = try
    ColourSpace::read(pdf, Dictionary([]), Integer(5)) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Err(_))
}

///|
test "read_colourspace rejects indexed base colourspaces" {
  let pdf = @pdf.Pdf::empty()
  let arr : Array[@pdf.PdfObject] = [
    Name(PdfName(b"/Indexed")),
    Name(PdfName(b"/Pattern")),
    Integer(0),
    PdfString(""),
  ]
  let res : Result[ColourSpace, Error] = try
    ColourSpace::read(pdf, Dictionary([]), PdfArray(arr)) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Err(_))
}

///|
test "read_colourspace DeviceN attributes and name validation" {
  let pdf = @pdf.Pdf::empty()
  let tint = sample_tint_function().to_pdf_object(pdf)
  let attrs : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(PdfName(b"/DeviceN"))),
  ])
  let space_arr : Array[@pdf.PdfObject] = [
    Name(PdfName(b"/DeviceN")),
    PdfArray([Name(PdfName(b"/Cyan"))]),
    Name(PdfName(b"/DeviceRGB")),
    tint,
    attrs,
  ]
  let space = ColourSpace::read(pdf, Dictionary([]), PdfArray(space_arr))
  match (space : ColourSpace) {
    DeviceN(names, _, _, attr_dict) => {
      assert_eq(names.length(), 1)
      assert_eq(names[0], "/Cyan")
      match pdf.lookup_direct("/Subtype", attr_dict) {
        Some(Name(PdfName(b"/DeviceN"))) => ()
        _ => fail("expected DeviceN subtype")
      }
    }
    _ => fail("expected DeviceN")
  }
  let bad_names_arr : Array[@pdf.PdfObject] = [
    Name(PdfName(b"/DeviceN")),
    PdfArray([Integer(1)]),
    Name(PdfName(b"/DeviceRGB")),
    tint,
  ]
  let bad_names : Result[ColourSpace, Error] = try
    ColourSpace::read(pdf, Dictionary([]), PdfArray(bad_names_arr)) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(bad_names is Err(_))
}

///|
test "write_colourspace writes ICCBased metadata and range" {
  let pdf = @pdf.Pdf::empty()
  let metadata : @pdf.PdfObject = Dictionary([
    ("/Type", Name(PdfName(b"/Metadata"))),
  ])
  let stream_dict : @pdf.PdfObject = Dictionary([])
  let stream_obj : @pdf.PdfObject = Stream(
    Ref((stream_dict, Got(@pdfio.bytes_of_string("icc")))),
  )
  let icc : ICCBased = {
    icc_n: 3,
    icc_alternate: DeviceRGB,
    icc_range: [0.0, 1.0, 0.0, 1.0, 0.0, 1.0],
    icc_metadata: Some(metadata),
    icc_stream: stream_obj,
  }
  let obj = ColourSpace::ICCBased(icc).to_pdf_object(pdf)
  match (obj : @pdf.PdfObject) {
    PdfArray([Name(PdfName(b"/ICCBased")), Indirect(n)]) =>
      match (pdf.lookup_obj(n) : @pdf.PdfObject) {
        Stream(r) => {
          let (dict, _) = r.val
          assert_true(pdf.lookup_direct("/Metadata", dict) is Some(_))
          match pdf.lookup_direct("/Range", dict) {
            Some(PdfArray(values)) => assert_eq(values.length(), 6)
            _ => fail("expected /Range entry")
          }
        }
        _ => fail("expected ICCBased stream")
      }
    _ => fail("expected ICCBased array")
  }
}

///|
test "write_colourspace handles indexed empty table and deviceN attrs" {
  let pdf = @pdf.Pdf::empty()
  let empty_table : Map[Int, Array[Int]] = Map([])
  let indexed = ColourSpace::Indexed(DeviceRGB, empty_table).to_pdf_object(pdf)
  match (indexed : @pdf.PdfObject) {
    PdfArray(items) =>
      match (items[2] : @pdf.PdfObject) {
        Integer(0) => ()
        _ => fail("expected hival 0")
      }
    _ => fail("expected Indexed array")
  }
  let attrs : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(PdfName(b"/DeviceN"))),
  ])
  let device_n = ColourSpace::DeviceN(
    ["C1"],
    DeviceRGB,
    sample_tint_function(),
    attrs,
  ).to_pdf_object(pdf)
  match (device_n : @pdf.PdfObject) {
    PdfArray(items) => assert_eq(items.length(), 5)
    _ => fail("expected DeviceN array with attrs")
  }
}

///|
test "write_colourspace handles Pattern with base" {
  let pdf = @pdf.Pdf::empty()
  let obj = ColourSpace::PatternWithBaseColourspace(DeviceGray).to_pdf_object(
    pdf,
  )
  match (obj : @pdf.PdfObject) {
    PdfArray([Name(PdfName(b"/Pattern")), Name(PdfName(b"/DeviceGray"))]) => ()
    _ => fail("expected Pattern with base")
  }
}

///|
test "read_colourspace missing whitepoint defaults to zeros" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([
    ("/BlackPoint", mk_point(0.0, 0.0, 0.0)),
  ])
  let space = ColourSpace::read(
    pdf,
    Dictionary([]),
    PdfArray([Name(PdfName(b"/CalGray")), dict]),
  )
  match (space : ColourSpace) {
    CalGray(white, _, _) => assert_eq(white, (0.0, 0.0, 0.0))
    _ => fail("expected CalGray")
  }
}

///|
test "read_colourspace indexed handles ICCBased base" {
  let pdf = @pdf.Pdf::empty()
  let icc_dict : @pdf.PdfObject = Dictionary([("/N", Integer(3))])
  let icc_stream : @pdf.PdfObject = Stream(
    Ref((icc_dict, Got(@pdfio.bytes_of_list([0])))),
  )
  let base : @pdf.PdfObject = PdfArray([Name(PdfName(b"/ICCBased")), icc_stream])
  let lookup : @pdf.PdfObject = PdfString(
    @pdfio.string_of_bytes(@pdfio.bytes_of_list([1, 2, 3])),
  )
  let space_arr : Array[@pdf.PdfObject] = [
    Name(PdfName(b"/Indexed")),
    base,
    Integer(0),
    lookup,
  ]
  let space = ColourSpace::read(pdf, Dictionary([]), PdfArray(space_arr))
  match (space : ColourSpace) {
    Indexed(ICCBased(_), table) =>
      match table.get(0) {
        Some(values) => assert_eq(values, [1, 2, 3])
        _ => fail("expected indexed table entry")
      }
    _ => fail("expected indexed ICCBased")
  }
}

///|
test "read_colourspace indexed rejects short table" {
  let pdf = @pdf.Pdf::empty()
  let lookup : @pdf.PdfObject = PdfString(
    @pdfio.string_of_bytes(@pdfio.bytes_of_list([1, 2, 3])),
  )
  let arr : Array[@pdf.PdfObject] = [
    Name(PdfName(b"/Indexed")),
    Name(PdfName(b"/DeviceRGB")),
    Integer(1),
    lookup,
  ]
  let res : Result[ColourSpace, Error] = try
    ColourSpace::read(pdf, Dictionary([]), PdfArray(arr)) |> Ok
  catch {
    e => Err(e)
  }
  match res {
    Err(_) => ()
    _ => fail("expected short table error")
  }
}
