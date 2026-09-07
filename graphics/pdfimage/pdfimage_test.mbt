///|
test "colspace uses image mask" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let image : @pdf.PdfObject = Dictionary([("/ImageMask", Boolean(true))])
  let space = @pdfimage.Image::colspace(pdf, image, resources)
  match (space : @pdfspace.ColourSpace) {
    DeviceGray => ()
    _ => fail("expected DeviceGray")
  }
}

///|
test "colspace resolves named resource" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([
    ("/ColorSpace", Dictionary([("/CS1", Name(PdfName(b"/DeviceRGB")))])),
  ])
  let image : @pdf.PdfObject = Dictionary([("/CS", Name(PdfName(b"/CS1")))])
  let space = @pdfimage.Image::colspace(pdf, image, resources)
  match (space : @pdfspace.ColourSpace) {
    DeviceRGB => ()
    _ => fail("expected DeviceRGB")
  }
}

///|
test "colspace falls back to unresolved name when resource entry missing" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([("/ColorSpace", Dictionary([]))])
  let image : @pdf.PdfObject = Dictionary([("/CS", Name(PdfName(b"/Missing")))])
  let res : Result[@pdfspace.ColourSpace, Error] = try
    @pdfimage.Image::colspace(pdf, image, resources) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Err(_))
}

///|
test "colspace uses direct ColorSpace object when provided" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([
    ("/ColorSpace", Dictionary([("/CS1", Name(PdfName(b"/DeviceRGB")))])),
  ])
  let image : @pdf.PdfObject = Dictionary([("/ColorSpace", Dictionary([]))])
  let res : Result[@pdfspace.ColourSpace, Error] = try
    @pdfimage.Image::colspace(pdf, image, resources) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Err(_))
}

///|
test "colspace errors when resources has colorspaces but image omits entry" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([("/ColorSpace", Dictionary([]))])
  let image : @pdf.PdfObject = Dictionary([])
  let res : Result[@pdfspace.ColourSpace, Error] = try
    @pdfimage.Image::colspace(pdf, image, resources) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Err(_))
}

///|
test "colspace errors when colorspace missing in both image and resources" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let image : @pdf.PdfObject = Dictionary([])
  let res : Result[@pdfspace.ColourSpace, Error] = try
    @pdfimage.Image::colspace(pdf, image, resources) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Err(_))
}

///|
test "bpc returns component bits" {
  let pdf = @pdf.Pdf::empty()
  let image : @pdf.PdfObject = Dictionary([("/BPC", Integer(8))])
  match (@pdfimage.Image::bpc(pdf, image) : @pdf.PdfObject?) {
    Some(Integer(8)) => ()
    _ => fail("expected /BPC 8")
  }
}

///|
test "bpc defaults to image mask" {
  let pdf = @pdf.Pdf::empty()
  let image : @pdf.PdfObject = Dictionary([("/ImageMask", Boolean(true))])
  match (@pdfimage.Image::bpc(pdf, image) : @pdf.PdfObject?) {
    Some(Integer(1)) => ()
    _ => fail("expected /BPC 1 for image mask")
  }
}

///|
test "bpc none when absent" {
  let pdf = @pdf.Pdf::empty()
  let image : @pdf.PdfObject = Dictionary([])
  match @pdfimage.Image::bpc(pdf, image) {
    None => ()
    _ => fail("expected None")
  }
}

///|
test "get_image_24bpp raw rgb" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let data = @pdfio.bytes_of_list([255, 0, 0, 0, 255, 0])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(2)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", Name(PdfName(b"/DeviceRGB"))),
  ])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    Raw(w, h, layout, bytes) => {
      assert_eq(w, 2)
      assert_eq(h, 1)
      match (layout : @pdfimage.PixelLayout) {
        BPP24 => ()
        _ => fail("expected BPP24 layout")
      }
      assert_eq(bytes.length(), 6)
      assert_eq(bytes[0].to_int(), 255)
      assert_eq(bytes[3].to_int(), 0)
    }
    _ => fail("expected Raw image")
  }
}

///|
test "get_image_24bpp rejects non-stream inputs" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let res : Result[@pdfimage.Image, Error] = try
    @pdfimage.Image::get_image_24bpp(pdf, resources, Integer(1)) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Err(_))
}

///|
test "get_image_24bpp errors on missing height" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let data = @pdfio.bytes_of_list([0])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/BitsPerComponent", Integer(1)),
    ("/ColorSpace", Name(PdfName(b"/DeviceGray"))),
    ("/ImageMask", Boolean(true)),
  ])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  let res : Result[@pdfimage.Image, Error] = try
    @pdfimage.Image::get_image_24bpp(pdf, resources, stream) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Err(_))
}

///|
test "get_image_24bpp errors on non-array decode entry" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let data = @pdfio.bytes_of_list([0])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(1)),
    ("/ColorSpace", Name(PdfName(b"/DeviceGray"))),
    ("/Decode", Integer(1)),
  ])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  let res : Result[@pdfimage.Image, Error] = try
    @pdfimage.Image::get_image_24bpp(pdf, resources, stream) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Err(_))
}

///|
test "get_image_24bpp reads JBIG2 globals for filter array" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let globals_num = pdf.addobj(PdfString("globals"))
  let data = @pdfio.bytes_of_list([1, 2, 3, 4])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(1)),
    ("/Filter", PdfArray([Name(PdfName(b"/JBIG2Decode"))])),
    ("/DecodeParms", Dictionary([("/JBIG2Globals", Indirect(globals_num))])),
  ])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    JBIG2(_, _, globals) =>
      match globals {
        Some(i) => assert_eq(i, globals_num)
        None => fail("expected globals")
      }
    _ => fail("expected JBIG2 image")
  }
}

///|
test "get_image_24bpp JBIG2 filter array ignores non-indirect globals entry" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let data = @pdfio.bytes_of_list([1, 2, 3, 4])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(1)),
    ("/Filter", PdfArray([Name(PdfName(b"/JBIG2Decode"))])),
    ("/DecodeParms", Dictionary([("/JBIG2Globals", Integer(1))])),
  ])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    JBIG2(_, _, globals) => assert_eq(globals, None)
    _ => fail("expected JBIG2 image")
  }
}

///|
test "get_image_24bpp applies decode for 1bpp" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let data = @pdfio.bytes_of_list([128])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(1)),
    ("/ColorSpace", Name(PdfName(b"/DeviceGray"))),
    ("/Decode", PdfArray([Real(1.0), Real(0.0)])),
  ])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    Raw(_, _, _, bytes) => {
      assert_eq(bytes.length(), 3)
      assert_eq(bytes[0].to_int(), 0)
    }
    _ => fail("expected Raw image")
  }
}

///|
test "get_image_24bpp applies decode for 8bpp" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let data = @pdfio.bytes_of_list([0, 255, 0])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", Name(PdfName(b"/DeviceRGB"))),
    (
      "/Decode",
      PdfArray([
        Real(1.0),
        Real(0.0),
        Real(1.0),
        Real(0.0),
        Real(1.0),
        Real(0.0),
      ]),
    ),
  ])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    Raw(_, _, _, bytes) => {
      assert_eq(bytes[0].to_int(), 1)
      assert_eq(bytes[1].to_int(), 0)
      assert_eq(bytes[2].to_int(), 1)
    }
    _ => fail("expected Raw image")
  }
}

///|
test "get_image_24bpp returns jpeg for DCT filter" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let data = @pdfio.bytes_of_list([1, 2, 3, 4])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", Name(PdfName(b"/DeviceRGB"))),
    ("/Filter", Name(PdfName(b"/DCTDecode"))),
  ])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    JPEG(bytes, decode) => {
      assert_eq(bytes.length(), 4)
      match decode {
        Some(arr) => assert_eq(arr.length(), 6)
        _ => fail("expected decode array")
      }
    }
    _ => fail("expected JPEG image")
  }
}

///|
test "get_image_24bpp returns jpeg2000 for JPX filter" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let data = @pdfio.bytes_of_list([1, 2, 3])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", Name(PdfName(b"/DeviceRGB"))),
    ("/Filter", Name(PdfName(b"/JPXDecode"))),
  ])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    JPEG2000(bytes, _) => assert_eq(bytes.length(), 3)
    _ => fail("expected JPEG2000 image")
  }
}

///|
test "get_image_24bpp returns jpeg2000 for JPX filter array" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let data = @pdfio.bytes_of_list([1, 2, 3])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", Name(PdfName(b"/DeviceRGB"))),
    ("/Filter", PdfArray([Name(PdfName(b"/JPXDecode"))])),
  ])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    JPEG2000(bytes, _) => assert_eq(bytes.length(), 3)
    _ => fail("expected JPEG2000 image")
  }
}

///|
test "get_image_24bpp returns JBIG2 with globals" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let globals_obj : @pdf.PdfObject = Dictionary([])
  let globals = pdf.addobj(globals_obj)
  let data = @pdfio.bytes_of_list([9, 8, 7])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(1)),
    ("/ColorSpace", Name(PdfName(b"/DeviceGray"))),
    ("/Filter", Name(PdfName(b"/JBIG2Decode"))),
    ("/DecodeParms", Dictionary([("/JBIG2Globals", Indirect(globals))])),
  ])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    JBIG2(bytes, _, globals_ref) => {
      assert_eq(bytes.length(), 3)
      match globals_ref {
        Some(i) => assert_eq(i, globals)
        None => fail("expected globals")
      }
    }
    _ => fail("expected JBIG2 image")
  }
}

///|
test "get_image_24bpp JBIG2 ignores non-indirect globals entry" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let data = @pdfio.bytes_of_list([9, 8, 7])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(1)),
    ("/ColorSpace", Name(PdfName(b"/DeviceGray"))),
    ("/Filter", Name(PdfName(b"/JBIG2Decode"))),
    ("/DecodeParms", Dictionary([("/JBIG2Globals", Integer(1))])),
  ])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    JBIG2(_, _, globals_ref) => assert_eq(globals_ref, None)
    _ => fail("expected JBIG2 image")
  }
}

///|
test "get_image_24bpp JBIG2 ignores malformed decodeparms" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let data = @pdfio.bytes_of_list([9, 8, 7])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(1)),
    ("/ColorSpace", Name(PdfName(b"/DeviceGray"))),
    ("/Filter", Name(PdfName(b"/JBIG2Decode"))),
    ("/DecodeParms", Integer(1)),
  ])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    JBIG2(_, _, globals_ref) => assert_eq(globals_ref, None)
    _ => fail("expected JBIG2 image")
  }
}

///|
test "get_image_24bpp reads image mask when BitsPerComponent missing" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/ImageMask", Boolean(true)),
  ])
  let data = @pdfio.bytes_of_list([0])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    Raw(_, _, _, bytes) => assert_eq(bytes.length(), 3)
    _ => fail("expected Raw image")
  }
}

///|
test "get_image_24bpp ignores decode for indexed colourspace" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let table = @pdfio.string_of_bytes(@pdfio.bytes_of_list([255, 0, 0]))
  let colorspace : @pdf.PdfObject = PdfArray([
    Name(PdfName(b"/Indexed")),
    Name(PdfName(b"/DeviceRGB")),
    Integer(0),
    PdfString(table),
  ])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", colorspace),
    ("/Decode", PdfArray([Real(1.0), Real(0.0)])),
  ])
  let data = @pdfio.bytes_of_list([0])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    Raw(_, _, _, bytes) => assert_eq(bytes[0].to_int(), 255)
    _ => fail("expected Raw image")
  }
}

///|
fn sample_tint_function() -> @pdffun.PdfFunction {
  {
    func: Interpolation({ c0: [0.0], c1: [1.0], n: 1.0, }),
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
  }
}

///|
fn sample_cmyk_function() -> @pdffun.PdfFunction {
  {
    func: Interpolation({
      c0: [0.0, 0.0, 0.0, 0.0],
      c1: [0.0, 0.0, 0.0, 1.0],
      n: 1.0,
    }),
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0]),
  }
}

///|
fn[T] assert_is_err(res : Result[T, Error]) -> Unit raise {
  match res {
    Err(_) => ()
    Ok(_) => fail("expected error")
  }
}

///|
test "get_image_24bpp default decode for Lab" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let lab : @pdf.PdfObject = PdfArray([
    Name(PdfName(b"/Lab")),
    Dictionary([
      ("/WhitePoint", PdfArray([1.0, 1.0, 1.0].map(fn(v) { Real(v) }))),
      ("/BlackPoint", PdfArray([0.0, 0.0, 0.0].map(fn(v) { Real(v) }))),
      (
        "/Range",
        PdfArray([Real(-128.0), Real(127.0), Real(-128.0), Real(127.0)]),
      ),
    ]),
  ])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", lab),
    ("/Filter", Name(PdfName(b"/DCTDecode"))),
  ])
  let data = @pdfio.bytes_of_list([1, 2, 3])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    JPEG(_, Some(decode)) => {
      assert_eq(decode.length(), 6)
      assert_eq(decode[0], 0.0)
      assert_eq(decode[1], 1.0)
    }
    _ => fail("expected JPEG image with decode")
  }
}

///|
test "from_raw errors on indexed palettes missing entries" {
  let data8 = @pdfio.bytes_of_list([0])
  let table_empty : Map[Int, Array[Int]] = Map([])
  let rgb_indexed : @pdfspace.ColourSpace = Indexed(DeviceRGB, table_empty)
  let res8 : Result[@pdfimage.Image, Error] = try
    @pdfimage.Image::from_raw(1, rgb_indexed, Some(Integer(8)), 1, 1, data8)
    |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res8 is Err(_))
  let data4 = @pdfio.bytes_of_list([0x01])
  let res4 : Result[@pdfimage.Image, Error] = try
    @pdfimage.Image::from_raw(1, rgb_indexed, Some(Integer(4)), 2, 1, data4)
    |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res4 is Err(_))
}

///|
test "from_raw errors on CMYK indexed palettes missing entries" {
  let data4 = @pdfio.bytes_of_list([0x01])
  let table_empty : Map[Int, Array[Int]] = Map([])
  let cmyk_indexed : @pdfspace.ColourSpace = Indexed(DeviceCMYK, table_empty)
  let res : Result[@pdfimage.Image, Error] = try
    @pdfimage.Image::from_raw(1, cmyk_indexed, Some(Integer(4)), 2, 1, data4)
    |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Err(_))
}

///|
test "from_raw errors on 8bpp CMYK indexed palettes missing entries" {
  let data = @pdfio.bytes_of_list([0])
  let table_empty : Map[Int, Array[Int]] = Map([])
  let cmyk_indexed : @pdfspace.ColourSpace = Indexed(DeviceCMYK, table_empty)
  let res : Result[@pdfimage.Image, Error] = try
    @pdfimage.Image::from_raw(1, cmyk_indexed, Some(Integer(8)), 1, 1, data)
    |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Err(_))
}

///|
test "from_raw 4bpp indexed palettes error on second nibble" {
  let data = @pdfio.bytes_of_list([0x01])
  let rgb_table : Map[Int, Array[Int]] = Map([])
  rgb_table.set(0, [255, 0, 0])
  let rgb_indexed : @pdfspace.ColourSpace = Indexed(DeviceRGB, rgb_table)
  let rgb_res : Result[@pdfimage.Image, Error] = try
    @pdfimage.Image::from_raw(1, rgb_indexed, Some(Integer(4)), 2, 1, data)
    |> Ok
  catch {
    e => Err(e)
  }
  assert_true(rgb_res is Err(_))
  let cmyk_table : Map[Int, Array[Int]] = Map([])
  cmyk_table.set(0, [0, 0, 0, 255])
  let cmyk_indexed : @pdfspace.ColourSpace = Indexed(DeviceCMYK, cmyk_table)
  let cmyk_res : Result[@pdfimage.Image, Error] = try
    @pdfimage.Image::from_raw(1, cmyk_indexed, Some(Integer(4)), 2, 1, data)
    |> Ok
  catch {
    e => Err(e)
  }
  assert_true(cmyk_res is Err(_))
}

///|
test "from_raw separation cmyk can overflow values" {
  let tint : @pdffun.PdfFunction = {
    func: Calculator([Pop, Float(2.0), Float(0.0), Float(0.0), Float(0.0)]),
    domain: [0.0, 1.0],
    range: None,
  }
  let space : @pdfspace.ColourSpace = Separation("Spot", DeviceCMYK, tint)
  let data = @pdfio.bytes_of_list([255])
  match @pdfimage.Image::from_raw(1, space, Some(Integer(8)), 1, 1, data) {
    Raw(_, _, _, bytes) => {
      assert_eq(bytes.length(), 3)
      assert_eq(bytes[0].to_int(), 0)
    }
    _ => fail("expected Raw separation image")
  }
}

///|
test "from_raw separation cmyk errors on bad tint transform" {
  let tint : @pdffun.PdfFunction = {
    func: Calculator([Add]),
    domain: [0.0, 1.0],
    range: None,
  }
  let space : @pdfspace.ColourSpace = Separation("Spot", DeviceCMYK, tint)
  let data = @pdfio.bytes_of_list([0])
  let res : Result[@pdfimage.Image, Error] = try
    @pdfimage.Image::from_raw(1, space, Some(Integer(8)), 1, 1, data) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Err(_))
}

///|
test "from_raw supports DeviceN RGB bases in indexed palettes" {
  let data = @pdfio.bytes_of_list([0])
  let table : Map[Int, Array[Int]] = Map([])
  table.set(0, [255, 0, 0])
  let devn : @pdfspace.ColourSpace = DeviceN(
    ["C"],
    DeviceRGB,
    sample_tint_function(),
    Null,
  )
  let space : @pdfspace.ColourSpace = Indexed(devn, table)
  match @pdfimage.Image::from_raw(1, space, Some(Integer(8)), 1, 1, data) {
    Raw(_, _, _, bytes) => assert_eq(bytes[0].to_int(), 255)
    _ => fail("expected Raw indexed image")
  }
}

///|
test "from_raw supports DeviceN ICCBased alternates in indexed palettes" {
  let data = @pdfio.bytes_of_list([0])
  let table : Map[Int, Array[Int]] = Map([])
  table.set(0, [255, 0, 0])
  let icc : @pdfspace.ICCBased = {
    icc_n: 3,
    icc_alternate: DeviceRGB,
    icc_range: [0.0, 1.0, 0.0, 1.0, 0.0, 1.0],
    icc_metadata: None,
    icc_stream: Null,
  }
  let devn : @pdfspace.ColourSpace = DeviceN(
    ["C"],
    ICCBased(icc),
    sample_tint_function(),
    Null,
  )
  let space : @pdfspace.ColourSpace = Indexed(devn, table)
  match @pdfimage.Image::from_raw(1, space, Some(Integer(8)), 1, 1, data) {
    Raw(_, _, _, bytes) => assert_eq(bytes[0].to_int(), 255)
    _ => fail("expected Raw indexed image")
  }
}

///|
test "from_raw supports ICCBased CMYK alternates in indexed palettes" {
  let data = @pdfio.bytes_of_list([0])
  let table : Map[Int, Array[Int]] = Map([])
  table.set(0, [0, 0, 0, 255])
  let icc : @pdfspace.ICCBased = {
    icc_n: 4,
    icc_alternate: DeviceCMYK,
    icc_range: [0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0],
    icc_metadata: None,
    icc_stream: Null,
  }
  let space : @pdfspace.ColourSpace = Indexed(ICCBased(icc), table)
  match @pdfimage.Image::from_raw(1, space, Some(Integer(8)), 1, 1, data) {
    Raw(_, _, _, bytes) => assert_eq(bytes.length(), 3)
    _ => fail("expected Raw indexed image")
  }
}

///|
test "from_raw supports DeviceN ICCBased CMYK alternates in indexed palettes" {
  let data = @pdfio.bytes_of_list([0])
  let table : Map[Int, Array[Int]] = Map([])
  table.set(0, [0, 0, 0, 255])
  let icc : @pdfspace.ICCBased = {
    icc_n: 4,
    icc_alternate: DeviceCMYK,
    icc_range: [0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0],
    icc_metadata: None,
    icc_stream: Null,
  }
  let devn : @pdfspace.ColourSpace = DeviceN(
    ["C"],
    ICCBased(icc),
    sample_tint_function(),
    Null,
  )
  let space : @pdfspace.ColourSpace = Indexed(devn, table)
  match @pdfimage.Image::from_raw(1, space, Some(Integer(8)), 1, 1, data) {
    Raw(_, _, _, bytes) => assert_eq(bytes.length(), 3)
    _ => fail("expected Raw indexed image")
  }
}

///|
test "from_raw DeviceN non-rgb/non-cmyk bases in indexed palettes return error" {
  let data = @pdfio.bytes_of_list([0])
  let table_empty : Map[Int, Array[Int]] = Map([])
  let devn : @pdfspace.ColourSpace = DeviceN(
    ["C"],
    DeviceGray,
    sample_tint_function(),
    Null,
  )
  let space : @pdfspace.ColourSpace = Indexed(devn, table_empty)
  let res : Result[@pdfimage.Image, Error] = try
    @pdfimage.Image::from_raw(1, space, Some(Integer(8)), 1, 1, data) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Err(_))
}

///|
test "from_raw bpc 4 unsupported colourspace returns error" {
  let data = @pdfio.bytes_of_list([0x00])
  let res : Result[@pdfimage.Image, Error] = try
    @pdfimage.Image::from_raw(1, DeviceRGB, Some(Integer(4)), 1, 1, data) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Err(_))
}

///|
test "get_image_24bpp default decode for ICCBased" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let icc_dict : @pdf.PdfObject = Dictionary([
    ("/N", Integer(3)),
    (
      "/Range",
      PdfArray([
        Real(0.0),
        Real(1.0),
        Real(0.0),
        Real(1.0),
        Real(0.0),
        Real(1.0),
      ]),
    ),
  ])
  let icc_stream : @pdf.PdfObject = Stream(
    Ref((icc_dict, Got(@pdfio.bytes_of_list([0])))),
  )
  let colorspace : @pdf.PdfObject = PdfArray([
    Name(PdfName(b"/ICCBased")),
    icc_stream,
  ])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", colorspace),
    ("/Filter", Name(PdfName(b"/DCTDecode"))),
  ])
  let data = @pdfio.bytes_of_list([1, 2, 3])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    JPEG(_, Some(decode)) => assert_eq(decode.length(), 6)
    _ => fail("expected JPEG image with decode")
  }
}

///|
test "get_image_24bpp default decode for DeviceN" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let tint = sample_tint_function().to_pdf_object(pdf)
  let colorspace : @pdf.PdfObject = PdfArray([
    Name(PdfName(b"/DeviceN")),
    PdfArray([Name(PdfName(b"/C1")), Name(PdfName(b"/C2"))]),
    Name(PdfName(b"/DeviceRGB")),
    tint,
  ])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", colorspace),
    ("/Filter", Name(PdfName(b"/DCTDecode"))),
  ])
  let data = @pdfio.bytes_of_list([1, 2, 3])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    JPEG(_, Some(decode)) => assert_eq(decode.length(), 4)
    _ => fail("expected JPEG image with decode")
  }
}

///|
test "get_image_24bpp decode ignored for indexed DCT" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let table = @pdfio.string_of_bytes(@pdfio.bytes_of_list([0, 0, 0]))
  let colorspace : @pdf.PdfObject = PdfArray([
    Name(PdfName(b"/Indexed")),
    Name(PdfName(b"/DeviceRGB")),
    Integer(0),
    PdfString(table),
  ])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", colorspace),
    ("/Filter", Name(PdfName(b"/DCTDecode"))),
    ("/Decode", PdfArray([Real(0.0), Real(1.0)])),
  ])
  let data = @pdfio.bytes_of_list([1, 2, 3])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    JPEG(_, decode) => assert_true(decode is None)
    _ => fail("expected JPEG image")
  }
}

///|
test "get_image_24bpp default decode none for Pattern" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", Name(PdfName(b"/Pattern"))),
    ("/Filter", Name(PdfName(b"/DCTDecode"))),
  ])
  let data = @pdfio.bytes_of_list([1, 2, 3])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    JPEG(_, decode) => assert_true(decode is None)
    _ => fail("expected JPEG image")
  }
}

///|
test "get_image_24bpp converts gray to rgb" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let data = @pdfio.bytes_of_list([128])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", Name(PdfName(b"/DeviceGray"))),
  ])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    Raw(_, _, _, bytes) => {
      assert_eq(bytes.length(), 3)
      assert_eq(bytes[0].to_int(), 128)
      assert_eq(bytes[1].to_int(), 128)
      assert_eq(bytes[2].to_int(), 128)
    }
    _ => fail("expected Raw gray image")
  }
}

///|
test "get_image_24bpp converts cmyk to rgb" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let data = @pdfio.bytes_of_list([0, 0, 0, 0])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", Name(PdfName(b"/DeviceCMYK"))),
  ])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    Raw(_, _, _, bytes) => {
      assert_eq(bytes.length(), 3)
      assert_eq(bytes[0].to_int(), 255)
      assert_eq(bytes[1].to_int(), 255)
      assert_eq(bytes[2].to_int(), 255)
    }
    _ => fail("expected Raw cmyk image")
  }
}

///|
test "get_image_24bpp handles indexed RGB" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let table = @pdfio.string_of_bytes(@pdfio.bytes_of_list([0, 0, 0, 255, 0, 0]))
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    (
      "/ColorSpace",
      PdfArray([
        Name(PdfName(b"/Indexed")),
        Name(PdfName(b"/DeviceRGB")),
        Integer(1),
        PdfString(table),
      ]),
    ),
  ])
  let data = @pdfio.bytes_of_list([1])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    Raw(_, _, _, bytes) => {
      assert_eq(bytes.length(), 3)
      assert_eq(bytes[0].to_int(), 255)
      assert_eq(bytes[1].to_int(), 0)
      assert_eq(bytes[2].to_int(), 0)
    }
    _ => fail("expected indexed RGB image")
  }
}

///|
test "get_image_24bpp handles indexed CMYK" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let table = @pdfio.string_of_bytes(
    @pdfio.bytes_of_list([0, 0, 0, 255, 0, 0, 0, 0]),
  )
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    (
      "/ColorSpace",
      PdfArray([
        Name(PdfName(b"/Indexed")),
        Name(PdfName(b"/DeviceCMYK")),
        Integer(1),
        PdfString(table),
      ]),
    ),
  ])
  let data = @pdfio.bytes_of_list([1])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    Raw(_, _, _, bytes) => {
      assert_eq(bytes.length(), 3)
      assert_eq(bytes[0].to_int(), 255)
      assert_eq(bytes[1].to_int(), 255)
      assert_eq(bytes[2].to_int(), 255)
    }
    _ => fail("expected indexed CMYK image")
  }
}

///|
test "get_image_24bpp handles indexed Lab" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let lab : @pdf.PdfObject = PdfArray([
    Name(PdfName(b"/Lab")),
    Dictionary([
      ("/WhitePoint", PdfArray([1.0, 1.0, 1.0].map(fn(v) { Real(v) }))),
      ("/BlackPoint", PdfArray([0.0, 0.0, 0.0].map(fn(v) { Real(v) }))),
    ]),
  ])
  let table = @pdfio.string_of_bytes(@pdfio.bytes_of_list([127, 127, 127]))
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    (
      "/ColorSpace",
      PdfArray([Name(PdfName(b"/Indexed")), lab, Integer(0), PdfString(table)]),
    ),
  ])
  let data = @pdfio.bytes_of_list([0])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    Raw(_, _, _, bytes) => assert_eq(bytes.length(), 3)
    _ => fail("expected indexed Lab image")
  }
}

///|
test "get_image_24bpp clamps indexed Lab conversions" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let lab : @pdf.PdfObject = PdfArray([
    Name(PdfName(b"/Lab")),
    Dictionary([
      // Large values trigger clamp branches during conversion.
      ("/WhitePoint", PdfArray([Real(5000.0), Real(-5000.0), Real(5000.0)])),
      ("/BlackPoint", PdfArray([Real(0.0), Real(0.0), Real(0.0)])),
    ]),
  ])
  let table = @pdfio.string_of_bytes(@pdfio.bytes_of_list([0, 0, 0]))
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    (
      "/ColorSpace",
      PdfArray([Name(PdfName(b"/Indexed")), lab, Integer(0), PdfString(table)]),
    ),
  ])
  let data = @pdfio.bytes_of_list([0])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    Raw(_, _, _, bytes) => assert_eq(bytes.length(), 3)
    _ => fail("expected indexed Lab image")
  }
}

///|
test "from_raw supports ICCBased RGB alternates in indexed palettes" {
  let data = @pdfio.bytes_of_list([0])
  let table : Map[Int, Array[Int]] = Map([])
  table.set(0, [255, 0, 0])
  let icc : @pdfspace.ICCBased = {
    icc_n: 3,
    icc_alternate: DeviceRGB,
    icc_range: [0.0, 1.0, 0.0, 1.0, 0.0, 1.0],
    icc_metadata: None,
    icc_stream: Null,
  }
  let space : @pdfspace.ColourSpace = Indexed(ICCBased(icc), table)
  match @pdfimage.Image::from_raw(1, space, Some(Integer(8)), 1, 1, data) {
    Raw(_, _, _, bytes) => assert_eq(bytes[0].to_int(), 255)
    _ => fail("expected Raw indexed image")
  }
}

///|
test "from_raw supports DeviceN CMYK bases in indexed palettes" {
  let data = @pdfio.bytes_of_list([0])
  let table : Map[Int, Array[Int]] = Map([])
  table.set(0, [0, 0, 0, 255])
  let devn : @pdfspace.ColourSpace = DeviceN(
    ["C"],
    DeviceCMYK,
    sample_cmyk_function(),
    Null,
  )
  let space : @pdfspace.ColourSpace = Indexed(devn, table)
  match @pdfimage.Image::from_raw(1, space, Some(Integer(8)), 1, 1, data) {
    Raw(_, _, _, bytes) => assert_eq(bytes.length(), 3)
    _ => fail("expected Raw indexed image")
  }
}

///|
test "from_raw rejects non-integer bpc and unknown indexed bases" {
  let data = @pdfio.bytes_of_list([0])
  let bad_bpc : Result[@pdfimage.Image, Error] = try
    @pdfimage.Image::from_raw(
      1,
      DeviceRGB,
      Some(Name(PdfName(b"/BPC"))),
      1,
      1,
      data,
    )
    |> Ok
  catch {
    e => Err(e)
  }
  assert_true(bad_bpc is Err(_))
  let table : Map[Int, Array[Int]] = Map([])
  table.set(0, [0])
  let bad_indexed : Result[@pdfimage.Image, Error] = try
    @pdfimage.Image::from_raw(
      1,
      Indexed(DeviceGray, table),
      Some(Integer(8)),
      1,
      1,
      data,
    )
    |> Ok
  catch {
    e => Err(e)
  }
  assert_true(bad_indexed is Err(_))
}

///|
test "get_image_24bpp JBIG2 ignores non-dictionary DecodeParms" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let data = @pdfio.bytes_of_list([1, 2, 3, 4])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(1)),
    ("/Filter", Name(PdfName(b"/JBIG2Decode"))),
    ("/DecodeParms", Integer(0)),
  ])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    JBIG2(_, _, globals) => assert_true(globals is None)
    _ => fail("expected JBIG2 image")
  }
}

///|
test "get_image_24bpp errors when Decode present but BitsPerComponent missing for mask" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(8)),
    ("/Height", Integer(1)),
    ("/ImageMask", Boolean(true)),
    ("/Decode", PdfArray([Real(1.0), Real(0.0)])),
  ])
  let data = @pdfio.bytes_of_list([0xff])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  let res : Result[@pdfimage.Image, Error] = try
    @pdfimage.Image::get_image_24bpp(pdf, resources, stream) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Err(_))
}

///|
test "get_image_24bpp indexed rgb missing table entry" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let table = @pdfio.string_of_bytes(@pdfio.bytes_of_list([0, 0, 0]))
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    (
      "/ColorSpace",
      PdfArray([
        Name(PdfName(b"/Indexed")),
        Name(PdfName(b"/DeviceRGB")),
        Integer(0),
        PdfString(table),
      ]),
    ),
  ])
  let data = @pdfio.bytes_of_list([1])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  let result : Result[@pdfimage.Image, Error] = try
    @pdfimage.Image::get_image_24bpp(pdf, resources, stream) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(result is Err(_))
}

///|
test "get_image_24bpp handles 4bpp gray" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(2)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(4)),
    ("/ColorSpace", Name(PdfName(b"/DeviceGray"))),
  ])
  let data = @pdfio.bytes_of_list([0xf0])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    Raw(_, _, _, bytes) => {
      assert_eq(bytes.length(), 6)
      assert_eq(bytes[0].to_int(), 255)
      assert_eq(bytes[3].to_int(), 0)
    }
    _ => fail("expected 4bpp gray image")
  }
}

///|
test "get_image_24bpp rejects bad decode" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", Name(PdfName(b"/DeviceRGB"))),
    ("/Decode", PdfArray([Real(0.0), Real(1.0), Real(0.0)])),
  ])
  let data = @pdfio.bytes_of_list([0, 0, 0])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  let result : Result[@pdfimage.Image, Error] = try
    @pdfimage.Image::get_image_24bpp(pdf, resources, stream) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(result is Err(_))
}

///|
test "get_image_24bpp handles ICCBased raw" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let icc_dict : @pdf.PdfObject = Dictionary([("/N", Integer(3))])
  let icc_stream : @pdf.PdfObject = Stream(
    Ref((icc_dict, Got(@pdfio.bytes_of_list([0])))),
  )
  let colorspace : @pdf.PdfObject = PdfArray([
    Name(PdfName(b"/ICCBased")),
    icc_stream,
  ])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", colorspace),
  ])
  let data = @pdfio.bytes_of_list([0, 0, 0])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    Raw(w, h, layout, bytes) => {
      assert_eq(w, 1)
      assert_eq(h, 1)
      match (layout : @pdfimage.PixelLayout) {
        BPP24 => ()
        _ => fail("expected BPP24")
      }
      assert_eq(bytes.length(), 3)
    }
    _ => fail("expected raw ICCBased image")
  }
}

///|
test "get_image_24bpp handles separation cmyk" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let tint = sample_cmyk_function().to_pdf_object(pdf)
  let colorspace : @pdf.PdfObject = PdfArray([
    Name(PdfName(b"/Separation")),
    Name(PdfName(b"/Spot")),
    Name(PdfName(b"/DeviceCMYK")),
    tint,
  ])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", colorspace),
  ])
  let data = @pdfio.bytes_of_list([0])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    Raw(_, _, _, bytes) => assert_eq(bytes.length(), 3)
    _ => fail("expected separation image")
  }
}

///|
test "get_image_24bpp rejects bad separation function" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let tint = sample_tint_function().to_pdf_object(pdf)
  let colorspace : @pdf.PdfObject = PdfArray([
    Name(PdfName(b"/Separation")),
    Name(PdfName(b"/Spot")),
    Name(PdfName(b"/DeviceCMYK")),
    tint,
  ])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", colorspace),
  ])
  let data = @pdfio.bytes_of_list([0])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  assert_is_err(
    try @pdfimage.Image::get_image_24bpp(pdf, resources, stream) |> Ok catch {
      e => Err(e)
    },
  )
}

///|
test "get_image_24bpp default decode for separation DCT" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let tint = sample_tint_function().to_pdf_object(pdf)
  let colorspace : @pdf.PdfObject = PdfArray([
    Name(PdfName(b"/Separation")),
    Name(PdfName(b"/Spot")),
    Name(PdfName(b"/DeviceGray")),
    tint,
  ])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", colorspace),
    ("/Filter", Name(PdfName(b"/DCTDecode"))),
  ])
  let data = @pdfio.bytes_of_list([1, 2, 3])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    JPEG(_, Some(decode)) => {
      assert_eq(decode.length(), 2)
      assert_eq(decode[0], 0.0)
      assert_eq(decode[1], 1.0)
    }
    _ => fail("expected JPEG decode")
  }
}

///|
test "get_image_24bpp loads ToGet stream" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", Name(PdfName(b"/DeviceRGB"))),
    ("/Length", Integer(3)),
  ])
  let data = @pdfio.bytes_of_list([0, 255, 0])
  let input = @pdfio.Input::of_bytes(data)
  let toget = @pdf.ToGet::new(input, 0, 3)
  let stream : @pdf.PdfObject = Stream(Ref((dict, ToGet(toget))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    Raw(_, _, _, bytes) => assert_eq(bytes.length(), 3)
    _ => fail("expected raw image")
  }
}

///|
test "get_image_24bpp rejects missing width" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", Name(PdfName(b"/DeviceRGB"))),
  ])
  let data = @pdfio.bytes_of_list([0, 0, 0])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  assert_is_err(
    try @pdfimage.Image::get_image_24bpp(pdf, resources, stream) |> Ok catch {
      e => Err(e)
    },
  )
}

///|
fn make_indexed_colorspace(
  base : @pdf.PdfObject,
  hival : Int,
  table_bytes : Array[Int],
) -> @pdf.PdfObject {
  let table = @pdfio.string_of_bytes(@pdfio.bytes_of_list(table_bytes))
  PdfArray([Name(PdfName(b"/Indexed")), base, Integer(hival), PdfString(table)])
}

///|
test "get_image_24bpp raw with empty filter array" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let data = @pdfio.bytes_of_list([128])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", Name(PdfName(b"/DeviceGray"))),
    ("/Filter", PdfArray([])),
  ])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    Raw(_, _, _, bytes) => assert_eq(bytes[0].to_int(), 128)
    _ => fail("expected raw image")
  }
}

///|
test "get_image_24bpp accepts DCT filter array" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let data = @pdfio.bytes_of_list([4, 5, 6])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", Name(PdfName(b"/DeviceRGB"))),
    ("/Filter", PdfArray([Name(PdfName(b"/DCTDecode"))])),
  ])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    JPEG(bytes, _) => assert_eq(bytes.length(), 3)
    _ => fail("expected JPEG image")
  }
}

///|
test "get_image_24bpp rejects flate filter" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let raw = @pdfio.bytes_of_list([1, 2, 3])
  let encoded = @pdfcodec.PdfCodec::new().encode_flate(raw)
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", Name(PdfName(b"/DeviceRGB"))),
    ("/Filter", Name(PdfName(b"/FlateDecode"))),
  ])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(encoded))))
  assert_is_err(
    try @pdfimage.Image::get_image_24bpp(pdf, resources, stream) |> Ok catch {
      e => Err(e)
    },
  )
}

///|
test "get_image_24bpp indexed 8bpp rgb" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let colorspace = make_indexed_colorspace(Name(PdfName(b"/DeviceRGB")), 1, [
    0, 0, 0, 255, 0, 0,
  ])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(2)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", colorspace),
  ])
  let data = @pdfio.bytes_of_list([0, 1])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    Raw(_, _, _, bytes) => {
      assert_eq(bytes.length(), 6)
      assert_eq(bytes[0].to_int(), 0)
      assert_eq(bytes[3].to_int(), 255)
    }
    _ => fail("expected raw indexed image")
  }
}

///|
test "get_image_24bpp indexed 8bpp cmyk" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let colorspace = make_indexed_colorspace(Name(PdfName(b"/DeviceCMYK")), 0, [
    0, 0, 0, 0,
  ])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", colorspace),
  ])
  let data = @pdfio.bytes_of_list([0])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    Raw(_, _, _, bytes) => {
      assert_eq(bytes.length(), 3)
      assert_eq(bytes[0].to_int(), 255)
      assert_eq(bytes[1].to_int(), 255)
    }
    _ => fail("expected raw cmyk indexed image")
  }
}

///|
test "get_image_24bpp indexed 4bpp rgb" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let colorspace = make_indexed_colorspace(Name(PdfName(b"/DeviceRGB")), 1, [
    0, 0, 0, 255, 0, 0,
  ])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(2)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(4)),
    ("/ColorSpace", colorspace),
  ])
  let data = @pdfio.bytes_of_list([0x01])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    Raw(_, _, _, bytes) => {
      assert_eq(bytes.length(), 6)
      assert_eq(bytes[0].to_int(), 0)
      assert_eq(bytes[3].to_int(), 255)
    }
    _ => fail("expected raw indexed image")
  }
}

///|
test "get_image_24bpp indexed 4bpp cmyk" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let colorspace = make_indexed_colorspace(Name(PdfName(b"/DeviceCMYK")), 0, [
    0, 0, 0, 0,
  ])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(2)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(4)),
    ("/ColorSpace", colorspace),
  ])
  let data = @pdfio.bytes_of_list([0x00])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    Raw(_, _, _, bytes) => {
      assert_eq(bytes.length(), 6)
      assert_eq(bytes[0].to_int(), 255)
      assert_eq(bytes[3].to_int(), 255)
    }
    _ => fail("expected raw indexed image")
  }
}

///|
test "get_image_24bpp indexed 4bpp rejects missing entry" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let colorspace = make_indexed_colorspace(Name(PdfName(b"/DeviceRGB")), 1, [
    0, 0, 0, 255, 0, 0,
  ])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(2)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(4)),
    ("/ColorSpace", colorspace),
  ])
  let data = @pdfio.bytes_of_list([0x20])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  assert_is_err(
    try @pdfimage.Image::get_image_24bpp(pdf, resources, stream) |> Ok catch {
      e => Err(e)
    },
  )
}

///|
test "get_image_24bpp 4bpp gray decode no-op" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(2)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(4)),
    ("/ColorSpace", Name(PdfName(b"/DeviceGray"))),
    ("/Decode", PdfArray([Real(1.0), Real(0.0)])),
  ])
  let data = @pdfio.bytes_of_list([0x0f])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    Raw(_, _, _, bytes) => {
      assert_eq(bytes.length(), 6)
      assert_eq(bytes[0].to_int(), 0)
      assert_eq(bytes[3].to_int(), 255)
    }
    _ => fail("expected raw gray image")
  }
}

///|
test "get_image_24bpp rejects odd decode length" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", Name(PdfName(b"/DeviceRGB"))),
    ("/Decode", PdfArray([Real(0.0)])),
  ])
  let data = @pdfio.bytes_of_list([0, 0, 0])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  assert_is_err(
    try @pdfimage.Image::get_image_24bpp(pdf, resources, stream) |> Ok catch {
      e => Err(e)
    },
  )
}

///|
test "get_image_24bpp decode defaults to none without colorspace" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/Filter", Name(PdfName(b"/DCTDecode"))),
  ])
  let data = @pdfio.bytes_of_list([1, 2, 3])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    JPEG(_, decode) => assert_true(decode is None)
    _ => fail("expected JPEG image")
  }
}

///|
test "get_image_24bpp keeps decode when colorspace missing" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/Filter", Name(PdfName(b"/DCTDecode"))),
    ("/Decode", PdfArray([Real(0.0), Real(1.0)])),
  ])
  let data = @pdfio.bytes_of_list([1, 2, 3])
  let stream : @pdf.PdfObject = Stream(Ref((dict, Got(data))))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    JPEG(_, Some(decode)) => assert_eq(decode.length(), 2)
    _ => fail("expected JPEG image")
  }
}
