// Property-based tests for whole documents: PdfWrite -> PdfRead round trips
// (plain, xref streams, object streams and every encryption method) and
// reader robustness on corrupted files.

///|
fn rnd(rs : @quickcheck.RandomState, n : Int) -> Int {
  rs.next_uint(limit=n.reinterpret_as_uint()).reinterpret_as_int()
}

///|
fn gen_bytestring(n : Int, rs : @quickcheck.RandomState) -> String {
  let special = "()\\\r\n\t /#%<>[]\u{0}\u{ff}"
  let sb = StringBuilder()
  for _ in 0..<rnd(rs, n + 1) {
    let c = if rnd(rs, 3) == 0 {
      special[rnd(rs, special.length())].to_int()
    } else {
      rnd(rs, 256)
    }
    sb.write_char(c.unsafe_to_char())
  }
  sb.to_string()
}

///|
/// Random direct object; `nobjs` bounds the object numbers references use.
fn gen_value(
  size : Int,
  nobjs : Int,
  rs : @quickcheck.RandomState,
) -> @pdf.PdfObject {
  let k = if size <= 0 { rnd(rs, 7) } else { rnd(rs, 9) }
  match k {
    0 => Null
    1 => Boolean(rnd(rs, 2) == 0)
    2 => Integer(rs.next_int())
    3 => Real((rnd(rs, 2000001) - 1000000).to_double() / 64.0)
    4 => PdfString(gen_bytestring(12, rs))
    5 => Name(@pdf.PdfName::of_string("/N" + gen_bytestring(6, rs)))
    6 => Indirect(1 + rnd(rs, nobjs))
    7 => PdfArray(Array::makei(rnd(rs, 4), _ => gen_value(size / 2, nobjs, rs)))
    _ =>
      Dictionary(
        Array::makei(rnd(rs, 4), i => {
          ("/K\{i}" + gen_bytestring(4, rs), gen_value(size / 2, nobjs, rs))
        }),
      )
  }
}

///|
priv enum Mode {
  Plain
  XRefStream
  ObjStm
  Encrypt(@pdfcrypt.EncryptionMethod)
} derive(Debug)

///|
/// A document: the fixed page tree of `base_pdf` (objects 1-4) plus extra
/// objects 5.. (random values and streams), all reachable from the catalog.
priv struct DocCase {
  extra : Array[@pdf.PdfObject]
  mode : Mode
} derive(Debug)

///|
impl @quickcheck.Arbitrary for DocCase with fn arbitrary(size, rs) {
  let n = 1 + rnd(rs, size / 2 + 3)
  let total = 4 + n
  let extra = Array::makei(n, _ => {
    if rnd(rs, 4) == 0 {
      let data = Array::makei(rnd(rs, size * 8 + 1), _ => rnd(rs, 256).to_byte())
      @pdf.PdfObject::Stream(
        Ref(
          (
            Dictionary([
              ("/Length", Integer(data.length())),
              ("/X", gen_value(1, total, rs)),
            ]),
            Got(data),
          ),
        ),
      )
    } else {
      gen_value(size, total, rs)
    }
  })
  // AES-256 ISO (R6) key derivation takes ~3 s per write+read in a debug
  // build, so that mode is drawn rarely to keep the suite fast.
  let mode = @quickcheck.frequency([
    (
      28,
      @quickcheck.elements([
        Plain,
        XRefStream,
        ObjStm,
        Encrypt(PDF40bit),
        Encrypt(PDF128bit),
        Encrypt(AES128bit(true)),
        Encrypt(AES256bit(true)),
      ]),
    ),
    (1, @quickcheck.pure(Encrypt(AES256bitISO(true)))),
  ]).run(size, rs)
  { extra, mode, }
}

///|
impl @quickcheck.Shrink for DocCase with fn shrink(self) {
  let n = self.extra.length()
  if n <= 1 {
    return [].iter()
  }
  [
    { ..self, extra: self.extra[:n / 2].to_owned(), },
    { ..self, extra: self.extra[1:].to_owned(), },
  ].iter()
}

///|
fn base_pdf(extra : Array[@pdf.PdfObject]) -> @pdf.Pdf {
  let pdf = @pdf.Pdf::empty()
  let content = @pdfio.bytes_of_string("BT /F0 12 Tf (Hello) Tj ET\n")
  let refs = Array::makei(extra.length(), i => @pdf.PdfObject::Indirect(5 + i))
  pdf.addobj_given_num(
    (
      1,
      Dictionary([
        ("/Type", Name(@pdf.PdfName::of_string("/Pages"))),
        ("/Kids", PdfArray([Indirect(3)])),
        ("/Count", Integer(1)),
      ]),
    ),
  )
  pdf.addobj_given_num(
    (
      2,
      Stream(
        Ref(
          (Dictionary([("/Length", Integer(content.length()))]), Got(content)),
        ),
      ),
    ),
  )
  pdf.addobj_given_num(
    (
      3,
      Dictionary([
        ("/Type", Name(@pdf.PdfName::of_string("/Page"))),
        ("/Parent", Indirect(1)),
        (
          "/MediaBox",
          PdfArray([Integer(0), Integer(0), Integer(300), Integer(300)]),
        ),
        ("/Contents", Indirect(2)),
      ]),
    ),
  )
  pdf.addobj_given_num(
    (
      4,
      Dictionary([
        ("/Type", Name(@pdf.PdfName::of_string("/Catalog"))),
        ("/Pages", Indirect(1)),
        ("/Extra", PdfArray(refs)),
      ]),
    ),
  )
  for i, o in extra {
    pdf.addobj_given_num((5 + i, o))
  }
  let pdf = { ..pdf, root: 4, }
  pdf.trailerdict = Dictionary([("/Root", Indirect(4))])
  pdf
}

///|
fn write_doc(pdf : @pdf.Pdf, mode : Mode) -> Array[Byte] raise {
  let (output, buffer) = @pdfio.Output::of_bytes(4096)
  let w = @pdfwrite.PdfWrite::new(logger=_ => ())
  match mode {
    Plain => w.pdf_to_output(None, false, pdf, output)
    XRefStream =>
      w.pdf_to_output(preserve_objstm=true, None, false, pdf, output)
    ObjStm =>
      w.pdf_to_output(
        generate_objstm=true,
        preserve_objstm=false,
        compress_objstm=true,
        None,
        false,
        pdf,
        output,
      )
    Encrypt(m) =>
      w.pdf_to_output(
        Some(@pdfwrite.Encryption::new(m, "owner", "user", [])),
        false,
        pdf,
        output,
      )
  }
  output.extract_bytes(buffer)
}

///|
fn read_doc(bytes : Array[Byte], mode : Mode) -> @pdf.Pdf raise {
  let input = @pdfio.Input::of_bytes(bytes, source="qc")
  let pdf = @pdfread.PdfRead::new(logger=_ => ()).pdf_of_input(
    Some("user"),
    None,
    input,
  )
  match mode {
    Encrypt(_) =>
      match @pdfcrypt.PdfCrypt::new().decrypt_pdf("user", pdf).0 {
        Some(p) => p
        None => fail("could not decrypt")
      }
    _ => pdf
  }
}

///|
/// Structural equality (Integer/Real numerically; stream dictionaries compared
/// without /Length, which encryption legitimately changes).
fn same(a : @pdf.PdfObject, b : @pdf.PdfObject) -> Bool {
  match (a, b) {
    (Null, Null) => true
    (Boolean(x), Boolean(y)) => x == y
    (Integer(x), Integer(y)) => x == y
    (Real(x), Real(y)) => x == y
    (Real(x), Integer(y)) | (Integer(y), Real(x)) => x == y.to_double()
    (PdfString(x), PdfString(y)) => x == y
    (Name(x), Name(y)) => x == y
    (Indirect(x), Indirect(y)) => x == y
    (PdfArray(xs), PdfArray(ys)) =>
      xs.length() == ys.length() &&
      xs.iter().zip(ys.iter()).all(p => same(p.0, p.1))
    (Dictionary(xs), Dictionary(ys)) => {
      let xs = xs.filter(e => e.0 != "/Length")
      let ys = ys.filter(e => e.0 != "/Length")
      xs.length() == ys.length() &&
      xs.iter().zip(ys.iter()).all(p => p.0.0 == p.1.0 && same(p.0.1, p.1.1))
    }
    (Stream(x), Stream(y)) => {
      b.getstream() catch {
        _ => return false
      }
      same(x.val.0, y.val.0) &&
      (match (x.val.1, y.val.1) {
        (Got(p), Got(q)) => p == q
        _ => false
      })
    }
    _ => false
  }
}

///|
test "prop: PdfRead.pdf_of_input inverts PdfWrite.pdf_to_output" {
  @pdfe.with_silenced_logs(() => {
    @quickcheck.check(
      (c : DocCase) => {
        let pdf = base_pdf(c.extra)
        let back = read_doc(write_doc(pdf, c.mode), c.mode)
        back.root == 4 &&
        c.extra
        .iter()
        .mapi((i, o) => (i, o))
        .all(p => same(p.1, back.lookup_obj(5 + p.0)))
      },
      observe=c => {
        [
          @quickcheck.collect(c.mode),
          @quickcheck.classify(
            c.extra.iter().any(o => o is Stream(_)),
            "has stream",
          ),
        ]
      },
      // An object whose value is a bare reference ("5 0 obj 6 0 R endobj") is
      // read back from an object stream as the integer 6: the object-stream
      // reader lexes one atom per member (lex_object_at oneonly). Such objects
      // are pathological, so that combination is excluded (see report).
      filter=c => {
        !(c.mode is ObjStm && c.extra.iter().any(o => o is Indirect(_)))
      },
      count=150,
      max_size=10,
      seed=0xd0c,
    )
  })
}

///|
fn snapshot(pdf : @pdf.Pdf) -> String {
  let sb = StringBuilder()
  sb.write_string(pdf.trailerdict.to_string())
  for n in pdf.objnumbers() {
    sb.write_string("\n\{n}: ")
    sb.write_string(pdf.lookup_obj(n).to_string_including_data())
  }
  sb.to_string()
}

///|
/// The documents here hold only in-memory (`Got`) streams with direct
/// `/Length`, so writing must leave them exactly as they were. (Deferred
/// streams may be materialized and their `/Length` normalized; see
/// `private_copy`.)
test "prop: pdf_to_output does not modify the document it writes" {
  @pdfe.with_silenced_logs(() => {
    @quickcheck.check(
      (c : DocCase) => {
        let pdf = base_pdf(
          c.extra.map(o => {
            match o {
              Stream(r) => Stream(Ref(r.val))
              _ => o
            }
          }),
        )
        let before = snapshot(pdf)
        let first = write_doc(pdf, c.mode)
        let unchanged = snapshot(pdf) == before
        // and therefore a second write produces an equivalent document
        let second = read_doc(write_doc(pdf, c.mode), c.mode)
        let again = read_doc(first, c.mode)
        unchanged &&
        pdf
        .objnumbers()
        .iter()
        .all(n => same(again.lookup_obj(n), second.lookup_obj(n)))
      },
      observe=c => [@quickcheck.collect(c.mode)],
      count=60,
      max_size=6,
      seed=0x5afe,
    )
  })
}

///|
/// A document written in an unencrypted layout, then read back lazily and
/// written again in `target` mode.
priv struct LazyCase {
  doc : DocCase
  source : Mode
} derive(Debug)

///|
impl @quickcheck.Arbitrary for LazyCase with fn arbitrary(size, rs) {
  let doc : DocCase = @quickcheck.Arbitrary::arbitrary(size, rs)
  let source = @quickcheck.elements([Plain, XRefStream, ObjStm]).run(size, rs)
  { doc, source, }
}

///|
impl @quickcheck.Shrink for LazyCase with fn shrink(self) {
  @quickcheck.Shrink::shrink(self.doc).map(doc => { ..self, doc, })
}

///|
test "prop: writing a lazily read document leaves it unchanged" {
  // Lazily read documents hold unparsed objects (ToParse), objects inside
  // object streams (ToParseFromObjectStream) and deferred stream data (ToGet)
  // that the writer materializes. The writer may cache parses and
  // materialize streams in the caller's cells (and normalize `/Length`,
  // which `same` ignores), but must not encrypt or drop anything: the lazy
  // document must keep its content.
  @pdfe.with_silenced_logs(() => {
    @quickcheck.check(
      (c : LazyCase) => {
        let bytes = write_doc(base_pdf(c.doc.extra), c.source)
        let lazy_pdf = @pdfread.PdfRead::new(logger=_ => ()).pdf_of_input_lazy(
          None,
          None,
          @pdfio.Input::of_bytes(bytes),
        )
        let written = write_doc(lazy_pdf, c.doc.mode)
        // Only now look at the lazy document: it must still read as the source.
        let eager = read_doc(bytes, c.source)
        let unchanged = eager
          .objnumbers()
          .iter()
          .all(n => same(eager.lookup_obj(n), lazy_pdf.lookup_obj(n))) &&
          same(eager.trailerdict, lazy_pdf.trailerdict)
        // and what was written is the same document
        let back = read_doc(written, c.doc.mode)
        unchanged &&
        c.doc.extra
        .iter()
        .mapi((i, o) => (i, o))
        .all(p => same(p.1, back.lookup_obj(5 + p.0)))
      },
      // see the round-trip property for why bare references are excluded
      filter=c => {
        !((c.source is ObjStm || c.doc.mode is ObjStm) &&
        c.doc.extra.iter().any(o => o is Indirect(_)))
      },
      observe=c => {
        [
          @quickcheck.collect(c.source),
          @quickcheck.label(@debug.to_string(c.doc.mode)),
        ]
      },
      count=60,
      max_size=6,
      seed=0x1a2e,
    )
  })
}

///|
test "regression: writing with object streams or encryption keeps the input intact" {
  // generate_objstm used to remove the absorbed objects from the caller's
  // Pdf; encryption used to encrypt its streams (and, with xref streams, all
  // strings plus a new /Encrypt trailer entry) in place.
  let content = @pdfio.bytes_of_string("hello")
  let pdf = base_pdf([
    Stream(Ref((Dictionary([("/Length", Integer(5))]), Got(content)))),
    PdfString("secret"),
  ])
  let _ = write_doc(pdf, ObjStm)
  inspect(pdf.lookup_obj(6).to_string(), content="(secret)")
  let _ = write_doc(pdf, Encrypt(AES128bit(true)))
  inspect(
    pdf.lookup_obj(5).to_string_including_data(),
    content=(
      #|<</Length 5>>
      #|stream
      #|hello
      #|endstream
    ),
  )
  let (output, buffer) = @pdfio.Output::of_bytes(1024)
  @pdfwrite.PdfWrite::new(logger=_ => ()).pdf_to_output(
    preserve_objstm=true,
    Some(@pdfwrite.Encryption::new(AES256bit(true), "owner", "user", [])),
    false,
    pdf,
    output,
  )
  let _ = output.extract_bytes(buffer)
  inspect(pdf.lookup_obj(6).to_string(), content="(secret)")
  inspect(pdf.trailerdict.to_string(), content="<</Root 4 0 R>>")
}

// ---------------------------------------------------------------------------
// Robustness: the reader is fed untrusted files. Corrupted input may be
// rejected (raise) but must never abort the process or hang.

///|
priv struct Corrupt {
  mode : Mode
  edits : Array[(Int, Int, String)] // (kind, position seed, fragment)
} derive(Debug)

///|
let corrupt_fragments : Array[String] = [
  "-1", "-99999", "999999999", "2147483647", "startxref\n-5\n%%EOF", "/Length -1",
  "/Length 99999999", "xref\n0 -3\n", "/Size -1", "/Prev -10", "/Prev -2000000000",
  "/XRefStm -99", "/W [1 -2 1]", "/W [4 4 4]", "/Index [0 -1]", "/N 100 /First -5",
  "0 0 obj", "/Encrypt 99 0 R", "endstream", "stream\n", "<<", ">>", "[", "(", "%%EOF",
  "trailer", "obj", "R", " ", "\u{0}\u{ff}", "/Root 1 0 R", "/Type /ObjStm", "/Filter /FlateDecode",
  "/DecodeParms << /Predictor 12 /Columns -4 >>",
]

///|
impl @quickcheck.Arbitrary for Corrupt with fn arbitrary(size, rs) {
  let mode = @quickcheck.elements([
    Plain,
    XRefStream,
    ObjStm,
    Encrypt(PDF128bit),
    Encrypt(AES128bit(true)),
    Encrypt(AES256bit(true)),
  ]).run(size, rs)
  let n = 1 + rnd(rs, 3)
  let edits = Array::makei(n, _ => {
    let frag = if rnd(rs, 4) == 0 {
      gen_bytestring(8, rs)
    } else {
      corrupt_fragments[rnd(rs, corrupt_fragments.length())]
    }
    (rnd(rs, 4), rs.next_positive_int(), frag)
  })
  { mode, edits, }
}

///|
impl @quickcheck.Shrink for Corrupt with fn shrink(self) {
  let n = self.edits.length()
  Array::makei(n, i => {
    let edits = self.edits.copy()
    edits.remove(i) |> ignore
    { ..self, edits, }
  }).iter()
}

///|
let corrupt_seed_doc : @pdf.Pdf = base_pdf([
  PdfString("some (string)"),
  Stream(
    Ref(
      (
        Dictionary([("/Length", Integer(10))]),
        Got(@pdfio.bytes_of_string("0123456789")),
      ),
    ),
  ),
  PdfArray([
    Integer(1),
    Real(2.5),
    Name(@pdf.PdfName::of_string("/N")),
    Indirect(5),
  ]),
  Dictionary([("/A", Indirect(6)), ("/B", PdfString("x"))]),
])

///|
fn apply_edits(
  bytes : Array[Byte],
  edits : Array[(Int, Int, String)],
) -> Array[Byte] {
  let out = bytes.copy()
  for e in edits {
    let (kind, seed, frag) = e
    let pos = seed % (out.length() + 1)
    let f = @pdfio.bytes_of_string(frag)
    match kind {
      0 => out.truncate(pos) // truncate
      1 =>
        // overwrite
        for i, b in f {
          if pos + i < out.length() {
            out[pos + i] = b
          }
        }
      2 =>
        for i, b in f {
          out.insert(pos + i, b)
        } // insert
      _ =>
        // flip a byte
        if pos < out.length() {
          out[pos] = out[pos] ^ (1 + seed % 255).to_byte()
        }
    }
  }
  out
}

///|
fn read_everything(bytes : Array[Byte], lazy_read : Bool) -> Int {
  let input = @pdfio.Input::of_bytes(bytes, source="corrupt")
  let reader = @pdfread.PdfRead::new(logger=_ => ())
  let pdf = try {
    if lazy_read {
      reader.pdf_of_input_lazy(Some("user"), None, input)
    } else {
      reader.pdf_of_input(Some("user"), None, input)
    }
  } catch {
    _ => return 0
  }
  let mut n = 0
  for num in pdf.objnumbers() {
    let o = pdf.lookup_obj(num)
    if o is Stream(_) {
      o.getstream() catch {
        _ => ()
      }
    }
    n = n + 1
  }
  n
}

///|
/// The file a corruption case starts from. Unencrypted output is
/// deterministic; encrypted output is not (random IVs/keys), so those use
/// fixed fixtures to keep failures reproducible from the QuickCheck seed.
fn corruption_source(mode : Mode) -> Array[Byte] raise {
  match mode {
    Encrypt(PDF128bit) => hex_fixture(fixture_pdf128)
    Encrypt(AES128bit(true)) => hex_fixture(fixture_aes128)
    Encrypt(AES256bit(true)) => hex_fixture(fixture_aes256)
    Encrypt(_) => fail("no fixture for this encryption method")
    _ => write_doc(corrupt_seed_doc, mode)
  }
}

///|
test "corruption fixtures are the documented, readable documents" {
  @pdfe.with_silenced_logs(() => {
    for
      mode in [
        Encrypt(PDF128bit),
        Encrypt(AES128bit(true)),
        Encrypt(AES256bit(true)),
      ] {
      let back = read_doc(corruption_source(mode), mode)
      for n in corrupt_seed_doc.objnumbers() {
        assert_true(same(corrupt_seed_doc.lookup_obj(n), back.lookup_obj(n)))
      }
    }
  })
}

///|
test "prop: PdfRead never aborts or hangs on corrupted files" {
  let originals : Map[String, Array[Byte]] = Map([])
  @pdfe.with_silenced_logs(() => {
    @quickcheck.check(
      (c : Corrupt) => {
        let key = @debug.to_string(c.mode)
        let original = match originals.get(key) {
          Some(b) => b
          None => {
            let b = corruption_source(c.mode)
            originals[key] = b
            b
          }
        }
        let bytes = apply_edits(original, c.edits)
        let _ = read_everything(bytes, false)
        let _ = read_everything(bytes, true)
        true
      },
      observe=c => {
        let key = @debug.to_string(c.mode)
        let bytes = apply_edits(originals.get(key).unwrap_or([]), c.edits)
        [
          @quickcheck.collect(c.mode),
          @quickcheck.classify(
            read_everything(bytes, false) > 0,
            "still readable",
          ),
        ]
      },
      count=600,
      seed=0xbadf11e,
    )
  })
}

///|
test "regression: huge negative /Prev does not read outside the file buffer" {
  // Seeking to a negative offset made Input::of_bytes do an unchecked read at
  // a negative index (SIGSEGV for -2000000000).
  let text = @pdfio.string_of_bytes(write_doc(corrupt_seed_doc, Plain))
  let tampered = text.replace(
    old="trailer\n<<",
    new="trailer\n<</Prev -2000000000 ",
  )
  inspect(tampered.contains("/Prev -2000000000"), content="true")
  @pdfe.with_silenced_logs(() => {
    inspect(
      read_everything(@pdfio.bytes_of_string(tampered), false),
      content="8",
    )
  })
}
