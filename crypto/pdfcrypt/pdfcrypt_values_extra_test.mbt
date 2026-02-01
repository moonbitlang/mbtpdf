///|
fn bytes_string(len : Int, value : Int) -> String {
  @pdfio.string_of_int_array(Array::make(len, value))
}

///|
fn add_id(pdf : @pdf.Pdf) -> Unit raise {
  let id : @pdf.PdfObject = Array([String("id"), String("id")])
  pdf.trailerdict = pdf.trailerdict.add_entry("/ID", id)
}

///|
fn attach_encrypt(pdf : @pdf.Pdf, encrypt_dict : @pdf.PdfObject) -> Unit raise {
  pdf.trailerdict = pdf.trailerdict.add_entry("/Encrypt", encrypt_dict)
}

///|
test "get_encryption_values handles V2 without length" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  add_id(pdf)
  let encrypt_dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.n("/Filter"), Name(PdfName("/Standard"))),
    (@pdf.n("/V"), Integer(2)),
    (@pdf.n("/R"), Integer(3)),
    (@pdf.n("/O"), String(bytes_string(32, 65))),
    (@pdf.n("/U"), String(bytes_string(32, 66))),
    (@pdf.n("/P"), Integer(-4)),
  ])
  attach_encrypt(pdf, encrypt_dict)
  let (crypt_type, _, _, _, _, _, _) = @pdfcrypt.PdfCrypt::new().get_encryption_values(
    pdf,
  )
  match crypt_type {
    ARC4(40, 3) => ()
    _ => fail("expected ARC4 40 r3")
  }
}

///|
test "get_encryption_values rejects invalid length" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  add_id(pdf)
  let encrypt_dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.n("/Filter"), Name(PdfName("/Standard"))),
    (@pdf.n("/V"), Integer(2)),
    (@pdf.n("/R"), Integer(3)),
    (@pdf.n("/Length"), Integer(42)),
    (@pdf.n("/O"), String(bytes_string(32, 65))),
    (@pdf.n("/U"), String(bytes_string(32, 66))),
    (@pdf.n("/P"), Integer(-4)),
  ])
  attach_encrypt(pdf, encrypt_dict)
  let result = try? @pdfcrypt.PdfCrypt::new().get_encryption_values(pdf)
  assert_true(result is Err(_))
}

///|
test "get_encryption_values handles V4 CF V2 length" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  add_id(pdf)
  let encrypt_dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.n("/Filter"), Name(PdfName("/Standard"))),
    (@pdf.n("/V"), Integer(4)),
    (@pdf.n("/R"), Integer(4)),
    (@pdf.n("/Length"), Integer(64)),
    (
      @pdf.n("/CF"),
      @pdf.PdfObject::Dictionary([
        (
          @pdf.n("/StdCF"),
          @pdf.PdfObject::Dictionary([(@pdf.n("/CFM"), Name(PdfName("/V2")))]),
        ),
      ]),
    ),
    (@pdf.n("/O"), String(bytes_string(32, 65))),
    (@pdf.n("/U"), String(bytes_string(32, 66))),
    (@pdf.n("/P"), Integer(-4)),
  ])
  attach_encrypt(pdf, encrypt_dict)
  let (crypt_type, _, _, _, _, _, _) = @pdfcrypt.PdfCrypt::new().get_encryption_values(
    pdf,
  )
  match crypt_type {
    ARC4(64, 4) => ()
    _ => fail("expected ARC4 64 r4")
  }
}

///|
test "get_encryption_values falls back to /CF /Length for V4 V2" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  add_id(pdf)
  let encrypt_dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.n("/Filter"), Name(PdfName("/Standard"))),
    (@pdf.n("/V"), Integer(4)),
    (@pdf.n("/R"), Integer(4)),
    // Non-integer /Length triggers the fallback to /CF /Length.
    (@pdf.n("/Length"), Name(PdfName("/NotAnInt"))),
    (
      @pdf.n("/CF"),
      @pdf.PdfObject::Dictionary([
        (@pdf.n("/Length"), Integer(128)),
        (
          @pdf.n("/StdCF"),
          @pdf.PdfObject::Dictionary([(@pdf.n("/CFM"), Name(PdfName("/V2")))]),
        ),
      ]),
    ),
    (@pdf.n("/O"), String(bytes_string(32, 65))),
    (@pdf.n("/U"), String(bytes_string(32, 66))),
    (@pdf.n("/P"), Integer(-4)),
  ])
  attach_encrypt(pdf, encrypt_dict)
  let (crypt_type, _, _, _, _, _, _) = @pdfcrypt.PdfCrypt::new().get_encryption_values(
    pdf,
  )
  match crypt_type {
    ARC4(128, 4) => ()
    _ => fail("expected ARC4 128 r4 via /CF /Length")
  }
}

///|
test "get_encryption_values rejects V4 without CF dictionary" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  add_id(pdf)
  let encrypt_dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.n("/Filter"), Name(PdfName("/Standard"))),
    (@pdf.n("/V"), Integer(4)),
    (@pdf.n("/R"), Integer(4)),
    (@pdf.n("/Length"), Integer(64)),
    (@pdf.n("/O"), String(bytes_string(32, 65))),
    (@pdf.n("/U"), String(bytes_string(32, 66))),
    (@pdf.n("/P"), Integer(-4)),
  ])
  attach_encrypt(pdf, encrypt_dict)
  let result = try? @pdfcrypt.PdfCrypt::new().get_encryption_values(pdf)
  assert_true(result is Err(_))
}

///|
test "get_encryption_values rejects nonstandard V in encryption dictionary" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  add_id(pdf)
  let encrypt_dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.n("/Filter"), Name(PdfName("/Standard"))),
    (@pdf.n("/V"), Integer(3)),
    (@pdf.n("/R"), Integer(3)),
    (@pdf.n("/O"), String(bytes_string(32, 65))),
    (@pdf.n("/U"), String(bytes_string(32, 66))),
    (@pdf.n("/P"), Integer(-4)),
  ])
  attach_encrypt(pdf, encrypt_dict)
  let result = try? @pdfcrypt.PdfCrypt::new().get_encryption_values(pdf)
  assert_true(result is Err(_))
}

///|
test "get_encryption_values rejects V4 V2 when /CF /Length is not an integer" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  add_id(pdf)
  let encrypt_dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.n("/Filter"), Name(PdfName("/Standard"))),
    (@pdf.n("/V"), Integer(4)),
    (@pdf.n("/R"), Integer(4)),
    // Non-integer /Length triggers the /CF fallback.
    (@pdf.n("/Length"), Name(PdfName("/NotAnInt"))),
    (
      @pdf.n("/CF"),
      @pdf.PdfObject::Dictionary([
        // Non-integer /CF /Length should fail ARC4 length extraction.
        (@pdf.n("/Length"), Name(PdfName("/AlsoNotInt"))),
        (
          @pdf.n("/StdCF"),
          @pdf.PdfObject::Dictionary([(@pdf.n("/CFM"), Name(PdfName("/V2")))]),
        ),
      ]),
    ),
    (@pdf.n("/O"), String(bytes_string(32, 65))),
    (@pdf.n("/U"), String(bytes_string(32, 66))),
    (@pdf.n("/P"), Integer(-4)),
  ])
  attach_encrypt(pdf, encrypt_dict)
  let result = try? @pdfcrypt.PdfCrypt::new().get_encryption_values(pdf)
  assert_true(result is Err(_))
}

///|
test "get_encryption_values rejects unknown encryption filter" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  add_id(pdf)
  let encrypt_dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.n("/Filter"), Name(PdfName("/NotStandard"))),
    (@pdf.n("/V"), Integer(2)),
    (@pdf.n("/R"), Integer(3)),
    (@pdf.n("/O"), String(bytes_string(32, 65))),
    (@pdf.n("/U"), String(bytes_string(32, 66))),
    (@pdf.n("/P"), Integer(-4)),
  ])
  attach_encrypt(pdf, encrypt_dict)
  let result = try? @pdfcrypt.PdfCrypt::new().get_encryption_values(pdf)
  assert_true(result is Err(_))
}

///|
test "decrypt_pdf AESV3 errors when /Perms is missing" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  add_id(pdf)
  let encrypt_dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.n("/Filter"), Name(PdfName("/Standard"))),
    (@pdf.n("/V"), Integer(5)),
    (@pdf.n("/R"), Integer(6)),
    (
      @pdf.n("/CF"),
      @pdf.PdfObject::Dictionary([
        (
          @pdf.n("/StdCF"),
          @pdf.PdfObject::Dictionary([(@pdf.n("/CFM"), Name(PdfName("/AESV3")))]),
        ),
      ]),
    ),
    (@pdf.n("/O"), String(bytes_string(48, 65))),
    (@pdf.n("/U"), String(bytes_string(48, 66))),
    (@pdf.n("/OE"), String("x")),
    (@pdf.n("/UE"), String("y")),
    (@pdf.n("/P"), Integer(-4)),
  ])
  attach_encrypt(pdf, encrypt_dict)
  let result = try? @pdfcrypt.PdfCrypt::new().decrypt_pdf("pw", pdf)
  assert_true(result is Err(_))
}

///|
test "get_encryption_values rejects missing stdcf" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  add_id(pdf)
  let encrypt_dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.n("/Filter"), Name(PdfName("/Standard"))),
    (@pdf.n("/V"), Integer(4)),
    (@pdf.n("/R"), Integer(4)),
    (
      @pdf.n("/CF"),
      @pdf.PdfObject::Dictionary([
        (@pdf.n("/Other"), @pdf.PdfObject::Dictionary([])),
      ]),
    ),
    (@pdf.n("/O"), String(bytes_string(32, 65))),
    (@pdf.n("/U"), String(bytes_string(32, 66))),
    (@pdf.n("/P"), Integer(-4)),
  ])
  attach_encrypt(pdf, encrypt_dict)
  let result = try? @pdfcrypt.PdfCrypt::new().get_encryption_values(pdf)
  assert_true(result is Err(_))
}

///|
test "get_encryption_values rejects unknown cfm" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  add_id(pdf)
  let encrypt_dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.n("/Filter"), Name(PdfName("/Standard"))),
    (@pdf.n("/V"), Integer(4)),
    (@pdf.n("/R"), Integer(4)),
    (
      @pdf.n("/CF"),
      @pdf.PdfObject::Dictionary([
        (
          @pdf.n("/StdCF"),
          @pdf.PdfObject::Dictionary([
            (@pdf.n("/CFM"), Name(PdfName("/Unknown"))),
          ]),
        ),
      ]),
    ),
    (@pdf.n("/O"), String(bytes_string(32, 65))),
    (@pdf.n("/U"), String(bytes_string(32, 66))),
    (@pdf.n("/P"), Integer(-4)),
  ])
  attach_encrypt(pdf, encrypt_dict)
  let result = try? @pdfcrypt.PdfCrypt::new().get_encryption_values(pdf)
  assert_true(result is Err(_))
}

///|
test "get_encryption_values rejects missing id entry" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let encrypt_dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.n("/Filter"), Name(PdfName("/Standard"))),
    (@pdf.n("/V"), Integer(2)),
    (@pdf.n("/R"), Integer(3)),
    (@pdf.n("/O"), String(bytes_string(32, 65))),
    (@pdf.n("/U"), String(bytes_string(32, 66))),
    (@pdf.n("/P"), Integer(-4)),
  ])
  attach_encrypt(pdf, encrypt_dict)
  let result = try? @pdfcrypt.PdfCrypt::new().get_encryption_values(pdf)
  assert_true(result is Err(_))
}

///|
test "get_encryption_values rejects missing or malformed O/U/P entries" {
  let pdf_o = @pdfpage.PdfPageDoc::minimum_valid()
  add_id(pdf_o)
  attach_encrypt(
    pdf_o,
    @pdf.PdfObject::Dictionary([
      (@pdf.n("/Filter"), Name(PdfName("/Standard"))),
      (@pdf.n("/V"), Integer(2)),
      (@pdf.n("/R"), Integer(3)),
      (@pdf.n("/U"), String(bytes_string(32, 66))),
      (@pdf.n("/P"), Integer(-4)),
    ]),
  )
  let o_res = try? @pdfcrypt.PdfCrypt::new().get_encryption_values(pdf_o)
  assert_true(o_res is Err(_))
  let pdf_u = @pdfpage.PdfPageDoc::minimum_valid()
  add_id(pdf_u)
  attach_encrypt(
    pdf_u,
    @pdf.PdfObject::Dictionary([
      (@pdf.n("/Filter"), Name(PdfName("/Standard"))),
      (@pdf.n("/V"), Integer(2)),
      (@pdf.n("/R"), Integer(3)),
      (@pdf.n("/O"), String(bytes_string(32, 65))),
      (@pdf.n("/P"), Integer(-4)),
    ]),
  )
  let u_res = try? @pdfcrypt.PdfCrypt::new().get_encryption_values(pdf_u)
  assert_true(u_res is Err(_))
  let pdf_p = @pdfpage.PdfPageDoc::minimum_valid()
  add_id(pdf_p)
  attach_encrypt(
    pdf_p,
    @pdf.PdfObject::Dictionary([
      (@pdf.n("/Filter"), Name(PdfName("/Standard"))),
      (@pdf.n("/V"), Integer(2)),
      (@pdf.n("/R"), Integer(3)),
      (@pdf.n("/O"), String(bytes_string(32, 65))),
      (@pdf.n("/U"), String(bytes_string(32, 66))),
    ]),
  )
  let p_res = try? @pdfcrypt.PdfCrypt::new().get_encryption_values(pdf_p)
  assert_true(p_res is Err(_))
  let pdf_bad_types = @pdfpage.PdfPageDoc::minimum_valid()
  add_id(pdf_bad_types)
  attach_encrypt(
    pdf_bad_types,
    @pdf.PdfObject::Dictionary([
      (@pdf.n("/Filter"), Name(PdfName("/Standard"))),
      (@pdf.n("/V"), Integer(2)),
      (@pdf.n("/R"), Integer(3)),
      (@pdf.n("/O"), Integer(0)),
      (@pdf.n("/U"), Integer(0)),
      (@pdf.n("/P"), String("x")),
    ]),
  )
  let bad_types_res = try? @pdfcrypt.PdfCrypt::new().get_encryption_values(
    pdf_bad_types,
  )
  assert_true(bad_types_res is Err(_))
}

///|
test "get_encryption_values rejects too-short O/U strings" {
  let pdf_short = @pdfpage.PdfPageDoc::minimum_valid()
  add_id(pdf_short)
  attach_encrypt(
    pdf_short,
    @pdf.PdfObject::Dictionary([
      (@pdf.n("/Filter"), Name(PdfName("/Standard"))),
      (@pdf.n("/V"), Integer(2)),
      (@pdf.n("/R"), Integer(3)),
      (@pdf.n("/O"), String("x")),
      (@pdf.n("/U"), String(bytes_string(32, 66))),
      (@pdf.n("/P"), Integer(-4)),
    ]),
  )
  let short_res = try? @pdfcrypt.PdfCrypt::new().get_encryption_values(
    pdf_short,
  )
  assert_true(short_res is Err(_))
}

///|
test "encrypt AES V2 without metadata and AES256 with long passwords" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let enc = @pdfcrypt.PdfCrypt::new().encrypt_pdf_AES(
    false,
    "user",
    "owner",
    [],
    pdf,
  )
  let (dec, _) = @pdfcrypt.PdfCrypt::new().decrypt_pdf("user", enc.deep_copy())
  assert_true(dec is Some(_))
  let string_obj : @pdf.PdfObject = String("secret")
  pdf.addobj_given_num((10, string_obj))
  let stream_dict : @pdf.PdfObject = @pdf.PdfObject::Dictionary([
    (@pdf.n("/Length"), Integer(4)),
  ])
  let got_stream : @pdf.PdfObject = Stream(
    Ref::new((stream_dict, Got(@pdfio.bytes_of_string("data")))),
  )
  pdf.addobj_given_num((11, got_stream))
  let input = @pdfio.Input::of_string("data", source="stream")
  let toget = @pdf.ToGet::new(input, 0, 4)
  let toget_stream : @pdf.PdfObject = Stream(
    Ref::new((stream_dict, ToGet(toget))),
  )
  pdf.addobj_given_num((12, toget_stream))
  let long_pw = "a".repeat(130)
  let enc256 = @pdfcrypt.PdfCrypt::new().encrypt_pdf_AES256(
    true,
    long_pw,
    long_pw,
    [],
    pdf,
  )
  let (dec256, _) = @pdfcrypt.PdfCrypt::new().decrypt_pdf(
    long_pw,
    enc256.deep_copy(),
  )
  assert_true(dec256 is Some(_))
}
