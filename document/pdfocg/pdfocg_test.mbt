///|
test "read_ocg returns none without ocproperties" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  match OcgProperties::read(pdf) {
    None => ()
    _ => fail("expected no ocproperties")
  }
}

///|
test "read_ocg parses ocproperties" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let ocg_obj : @pdf.PdfObject = Dictionary([
    ("/Name", PdfString("Layer 1")),
    ("/Intent", PdfArray([Name(PdfName(b"/View")), Integer(0)])),
  ])
  let ocg_ref = pdf.addobj(ocg_obj)
  let default_config : @pdf.PdfObject = Dictionary([
    ("/Name", PdfString("Default")),
    ("/Creator", PdfString("tester")),
    ("/BaseState", Name(PdfName(b"/OFF"))),
    ("/ON", PdfArray([Indirect(ocg_ref), Integer(99)])),
    ("/OFF", PdfArray([Indirect(ocg_ref)])),
    ("/Intent", PdfArray([Name(PdfName(b"/View")), Integer(0)])),
    ("/AS", PdfArray([Dictionary([])])),
    ("/ListMode", Name(PdfName(b"/VisiblePages"))),
    ("/Locked", PdfArray([Indirect(ocg_ref), Integer(0)])),
  ])
  let alt_config : @pdf.PdfObject = Dictionary([
    ("/BaseState", Name(PdfName(b"/Unchanged"))),
    ("/Intent", Name(PdfName(b"/Design"))),
  ])
  let ocprops : @pdf.PdfObject = Dictionary([
    ("/OCGs", PdfArray([Indirect(ocg_ref)])),
    ("/D", default_config),
    ("/Configs", PdfArray([alt_config])),
  ])
  let root = pdf.lookup_obj(pdf.root)
  let updated_root = root.add_entry("/OCProperties", ocprops)
  pdf.addobj_given_num((pdf.root, updated_root))
  let props = match OcgProperties::read(pdf) {
    Some(result) => result
    None => fail("expected ocproperties")
  }
  assert_eq(props.ocgs.length(), 1)
  let (num, ocg) = props.ocgs[0]
  assert_eq(num, ocg_ref)
  assert_eq(ocg.ocg_name, "Layer 1")
  assert_eq(ocg.ocg_intent.length(), 1)
  assert_eq(ocg.ocg_intent[0], "/View")
  assert_eq(props.ocg_default_config.ocgconfig_name, Some("Default"))
  assert_eq(props.ocg_default_config.ocgconfig_creator, Some("tester"))
  match props.ocg_default_config.ocgconfig_basestate {
    Off => ()
    _ => fail("expected Off basestate")
  }
  match props.ocg_default_config.ocgconfig_on {
    Some(values) => {
      assert_eq(values.length(), 2)
      assert_eq(values[0], ocg_ref)
      assert_eq(values[1], 0)
    }
    None => fail("expected ON list")
  }
  match props.ocg_default_config.ocgconfig_off {
    Some(values) => {
      assert_eq(values.length(), 1)
      assert_eq(values[0], ocg_ref)
    }
    None => fail("expected OFF list")
  }
  assert_eq(props.ocg_default_config.ocgconfig_intent.length(), 2)
  assert_eq(props.ocg_default_config.ocgconfig_intent[0], "/View")
  assert_eq(props.ocg_default_config.ocgconfig_intent[1], "")
  match props.ocg_default_config.ocgconfig_usage_application_dictionaries {
    Some(values) => assert_eq(values.length(), 1)
    None => fail("expected AS list")
  }
  match props.ocg_default_config.ocgconfig_listmode {
    VisiblePages => ()
    _ => fail("expected VisiblePages list mode")
  }
  assert_eq(props.ocg_default_config.ocgconfig_locked.length(), 2)
  assert_eq(props.ocg_default_config.ocgconfig_locked[0], 0)
  assert_eq(props.ocg_default_config.ocgconfig_locked[1], 0)
  assert_eq(props.ocg_configs.length(), 1)
  match props.ocg_configs[0].ocgconfig_basestate {
    Unchanged => ()
    _ => fail("expected Unchanged basestate")
  }
  assert_eq(props.ocg_configs[0].ocgconfig_intent.length(), 1)
  assert_eq(props.ocg_configs[0].ocgconfig_intent[0], "/Design")
}

///|
test "read_ocg raises without root" {
  let pdf = @pdf.Pdf::empty()
  let res : Result[@pdfocg.OcgProperties?, Error] = try? OcgProperties::read(
    pdf,
  )
  match res {
    Err(_) => ()
    _ => fail("expected missing /Root error")
  }
}

///|
test "read_ocg raises when ocg is missing name" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let ocg_obj : @pdf.PdfObject = Dictionary([])
  let ocg_ref = pdf.addobj(ocg_obj)
  let ocprops : @pdf.PdfObject = Dictionary([
    ("/OCGs", PdfArray([Indirect(ocg_ref)])),
    ("/D", Dictionary([])),
  ])
  let root = pdf.lookup_obj(pdf.root)
  let updated_root = root.add_entry("/OCProperties", ocprops)
  pdf.addobj_given_num((pdf.root, updated_root))
  let res : Result[@pdfocg.OcgProperties?, Error] = try? OcgProperties::read(
    pdf,
  )
  match res {
    Err(_) => ()
    _ => fail("expected missing /Name error")
  }
}

///|
test "read_ocg uses config defaults" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let ocg_obj : @pdf.PdfObject = Dictionary([
    ("/Name", PdfString("Layer 2")),
    ("/Intent", Name(PdfName(b"/Design"))),
  ])
  let ocg_ref = pdf.addobj(ocg_obj)
  let default_config : @pdf.PdfObject = Dictionary([])
  let ocprops : @pdf.PdfObject = Dictionary([
    ("/OCGs", PdfArray([Indirect(ocg_ref)])),
    ("/D", default_config),
  ])
  let root = pdf.lookup_obj(pdf.root)
  let updated_root = root.add_entry("/OCProperties", ocprops)
  pdf.addobj_given_num((pdf.root, updated_root))
  let props = match OcgProperties::read(pdf) {
    Some(result) => result
    None => fail("expected ocproperties")
  }
  assert_eq(props.ocg_default_config.ocgconfig_intent.length(), 1)
  assert_eq(props.ocg_default_config.ocgconfig_intent[0], "/View")
  match props.ocg_default_config.ocgconfig_listmode {
    AllPages => ()
    _ => fail("expected AllPages list mode")
  }
  assert_true(props.ocg_default_config.ocgconfig_on is None)
  assert_true(props.ocg_default_config.ocgconfig_off is None)
  assert_eq(props.ocg_default_config.ocgconfig_locked.length(), 0)
}

///|
test "read_ocg parses ocg intent name" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let ocg_obj : @pdf.PdfObject = Dictionary([
    ("/Name", PdfString("Layer 3")),
    ("/Intent", Name(PdfName(b"/Design"))),
  ])
  let ocg_ref = pdf.addobj(ocg_obj)
  let ocprops : @pdf.PdfObject = Dictionary([
    ("/OCGs", PdfArray([Indirect(ocg_ref)])),
    ("/D", Dictionary([])),
  ])
  let root = pdf.lookup_obj(pdf.root)
  let updated_root = root.add_entry("/OCProperties", ocprops)
  pdf.addobj_given_num((pdf.root, updated_root))
  let props = match OcgProperties::read(pdf) {
    Some(result) => result
    None => fail("expected ocproperties")
  }
  assert_eq(props.ocgs.length(), 1)
  let (_, ocg) = props.ocgs[0]
  assert_eq(ocg.ocg_intent.length(), 1)
  assert_eq(ocg.ocg_intent[0], "/Design")
}

///|
test "print_document_ocg handles missing ocg" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  @pdfutil.with_quiet(true, fn() { PdfOcg::new(pdf).print_document() })
}

///|
test "print_document_ocg prints ocgs and configs" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let ocg_obj : @pdf.PdfObject = Dictionary([
    ("/Name", PdfString("Layer Print")),
    ("/Intent", Name(PdfName(b"/View"))),
  ])
  let ocg_ref = pdf.addobj(ocg_obj)
  let default_config : @pdf.PdfObject = Dictionary([
    ("/Name", PdfString("Default")),
    ("/Locked", PdfArray([Indirect(ocg_ref)])),
    ("/Intent", PdfArray([Name(PdfName(b"/View"))])),
  ])
  let alt_config : @pdf.PdfObject = Dictionary([
    ("/BaseState", Name(PdfName(b"/ON"))),
  ])
  let ocprops : @pdf.PdfObject = Dictionary([
    ("/OCGs", PdfArray([Indirect(ocg_ref)])),
    ("/D", default_config),
    ("/Configs", PdfArray([alt_config])),
  ])
  let root = pdf.lookup_obj(pdf.root)
  let updated_root = root.add_entry("/OCProperties", ocprops)
  pdf.addobj_given_num((pdf.root, updated_root))
  let ctx = PdfOcg::new(pdf)
  @pdfutil.with_quiet(true, fn() { ctx.print_document() })
  match ctx.read() {
    None => fail("expected ocproperties")
    Some(props) => ctx.write(props)
  }
}

///|
test "read_ocg handles direct ocgs and usage defaults" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let ocg_obj : @pdf.PdfObject = Dictionary([
    ("/Name", PdfString("Layer 4")),
    ("/Usage", Dictionary([])),
  ])
  let default_config : @pdf.PdfObject = Dictionary([
    ("/BaseState", Name(PdfName(b"/ON"))),
    ("/OFF", PdfArray([Integer(12), Name(PdfName(b"/Bad"))])),
    ("/Locked", PdfArray([Integer(1)])),
  ])
  let ocprops : @pdf.PdfObject = Dictionary([
    ("/OCGs", PdfArray([ocg_obj])),
    ("/D", default_config),
  ])
  let root = pdf.lookup_obj(pdf.root)
  let updated_root = root.add_entry("/OCProperties", ocprops)
  pdf.addobj_given_num((pdf.root, updated_root))
  let props = match OcgProperties::read(pdf) {
    Some(result) => result
    None => fail("expected ocproperties")
  }
  assert_eq(props.ocgs.length(), 1)
  let (num, ocg) = props.ocgs[0]
  assert_eq(num, 0)
  assert_eq(ocg.ocg_name, "Layer 4")
  assert_eq(ocg.ocg_intent.length(), 1)
  assert_eq(ocg.ocg_intent[0], "/View")
  assert_true(ocg.ocg_usage is None)
  match props.ocg_default_config.ocgconfig_basestate {
    On => ()
    _ => fail("expected On basestate")
  }
  match props.ocg_default_config.ocgconfig_off {
    Some(values) => {
      assert_eq(values.length(), 2)
      assert_eq(values[0], 0)
      assert_eq(values[1], 0)
    }
    None => fail("expected OFF list")
  }
}

///|
test "read_ocg raises without default config" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let ocprops : @pdf.PdfObject = Dictionary([
    ("/OCGs", Name(PdfName(b"/NotArray"))),
  ])
  let root = pdf.lookup_obj(pdf.root)
  let updated_root = root.add_entry("/OCProperties", ocprops)
  pdf.addobj_given_num((pdf.root, updated_root))
  let res : Result[@pdfocg.OcgProperties?, Error] = try? OcgProperties::read(
    pdf,
  )
  assert_true(res is Err(_))
}
