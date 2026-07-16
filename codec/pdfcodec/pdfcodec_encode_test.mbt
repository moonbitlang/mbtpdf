///|
let ctx : @pdfcodec.PdfCodec = PdfCodec::new()

///|
test "encode/decode flate stream" {
  let pdf = @pdf.Pdf::empty()
  let original = @pdfio.bytes_of_string("hello flate")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(original))),
  ])
  let stream_ref = Ref((dict, @pdf.Stream::Got(original)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  ctx.encode_pdfstream(pdf, Flate, stream_obj)
  let (encoded_dict, encoded_stream) = stream_ref.val
  let encoded_bytes = match (encoded_stream : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected encoded stream bytes")
  }
  match (pdf.lookup_direct("/Filter", encoded_dict) : @pdf.PdfObject?) {
    Some(Name(PdfName(b"/FlateDecode")))
    | Some(PdfArray([Name(PdfName(b"/FlateDecode")), ..])) => ()
    _ => fail("expected /Filter entry")
  }
  match (pdf.lookup_direct("/Length", encoded_dict) : @pdf.PdfObject?) {
    Some(Integer(len)) => assert_eq(len, @pdfio.bytes_size(encoded_bytes))
    _ => fail("expected /Length entry")
  }
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let (decoded_dict, decoded_stream) = stream_ref.val
  let decoded_bytes = match (decoded_stream : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_eq(
    @pdfio.string_of_bytes(decoded_bytes),
    @pdfio.string_of_bytes(original),
  )
  match decoded_dict.lookup_immediate("/Filter") {
    None => ()
    _ => fail("expected /Filter removed after decode")
  }
  match (pdf.lookup_direct("/Length", decoded_dict) : @pdf.PdfObject?) {
    Some(Integer(len)) => assert_eq(len, @pdfio.bytes_size(original))
    _ => fail("expected /Length entry")
  }
}

///|
fn roundtrip_encoding(
  encoding : Encoding,
  original : Array[Byte],
) -> Array[Byte] raise {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(original))),
  ])
  let stream_ref = Ref((dict, @pdf.Stream::Got(original)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  ctx.encode_pdfstream(pdf, encoding, stream_obj, only_if_smaller=false)
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  match (stream_ref.val : (@pdf.PdfObject, @pdf.Stream)) {
    (_, Got(bytes)) => bytes
    _ => fail("expected decoded bytes")
  }
}

///|
test "encode/decode ASCIIHex stream" {
  let original = @pdfio.bytes_of_string("hello hex")
  let decoded = roundtrip_encoding(ASCIIHex, original)
  assert_eq(@pdfio.string_of_bytes(decoded), "hello hex")
}

///|
test "encode/decode ASCII85 stream" {
  let original = @pdfio.bytes_of_string("ascii85 data")
  let decoded = roundtrip_encoding(ASCII85, original)
  assert_eq(@pdfio.string_of_bytes(decoded), "ascii85 data")
}

///|
test "encode/decode ASCII85 roundtrips short chunks (1..3 bytes)" {
  let ctx = @pdfcodec.PdfCodec::new()
  let pdf = @pdf.Pdf::empty()
  fn roundtrip(original : Array[Byte]) -> Unit raise {
    let dict : @pdf.PdfObject = Dictionary([
      ("/Length", Integer(@pdfio.bytes_size(original))),
    ])
    let stream_ref = Ref((dict, @pdf.Stream::Got(original)))
    let stream_obj : @pdf.PdfObject = Stream(stream_ref)
    ctx.encode_pdfstream(pdf, ASCII85, stream_obj, only_if_smaller=false)
    ctx.decode_pdfstream_onestage(pdf, stream_obj)
    match (stream_ref.val.1 : @pdf.Stream) {
      Got(decoded) => {
        assert_eq(@pdfio.bytes_size(decoded), @pdfio.bytes_size(original))
        for i in 0..<@pdfio.bytes_size(original) {
          assert_eq(
            @pdfio.bget_unsafe(decoded, i),
            @pdfio.bget_unsafe(original, i),
          )
        }
      }
      _ => fail("expected decoded stream bytes")
    }
  }

  roundtrip(@pdfio.bytes_of_list([1]))
  roundtrip(@pdfio.bytes_of_list([1, 2]))
  roundtrip(@pdfio.bytes_of_list([1, 2, 3]))
}

///|
test "decode_from_bytes ASCIIHex handles odd nibble" {
  let dict : @pdf.PdfObject = Dictionary([
    ("/Filter", Name(PdfName(b"/ASCIIHexDecode"))),
  ])
  let out = @pdfcodec.PdfCodec::new().decode_from_bytes(
    @pdfio.bytes_of_string("F>"),
    dict,
  )
  match out {
    Some(decoded) => {
      assert_eq(decoded.length(), 1)
      assert_eq(decoded[0], (240).to_byte())
    }
    None => fail("expected ASCIIHex decode to succeed")
  }
}

///|
test "encode ASCII85 uses z for zero tuple" {
  let pdf = @pdf.Pdf::empty()
  let zeros = @pdfio.bytes_of_list([0, 0, 0, 0])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(zeros))),
  ])
  let stream_ref = Ref((dict, @pdf.Stream::Got(zeros)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  ctx.encode_pdfstream(pdf, ASCII85, stream_obj, only_if_smaller=false)
  let encoded_bytes = match (stream_ref.val.1 : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected encoded stream bytes")
  }
  assert_true(@pdfio.string_of_bytes(encoded_bytes).contains("z"))
}

///|
test "decode_from_bytes ASCII85 handles z tuple" {
  let dict : @pdf.PdfObject = Dictionary([
    ("/Filter", Name(PdfName(b"/ASCII85Decode"))),
  ])
  let out = @pdfcodec.PdfCodec::new().decode_from_bytes(
    @pdfio.bytes_of_string("z~>"),
    dict,
  )
  match out {
    Some(decoded) => {
      assert_eq(decoded.length(), 4)
      for b in decoded {
        assert_eq(b, (0).to_byte())
      }
    }
    None => fail("expected ASCII85 decode to succeed")
  }
}

///|
test "decode_from_bytes ASCII85 flushes full groups and ignores 1-digit tail" {
  let dict : @pdf.PdfObject = Dictionary([
    ("/Filter", Name(PdfName(b"/ASCII85Decode"))),
  ])
  let out = @pdfcodec.PdfCodec::new().decode_from_bytes(
    @pdfio.bytes_of_string("!!!!!!~>"),
    dict,
  )
  match out {
    Some(decoded) => {
      assert_eq(decoded.length(), 4)
      for b in decoded {
        assert_eq(b, (0).to_byte())
      }
    }
    None => fail("expected ASCII85 decode to succeed")
  }
}

///|
test "decode_from_bytes ASCII85 returns None on invalid characters" {
  let dict : @pdf.PdfObject = Dictionary([
    ("/Filter", Name(PdfName(b"/ASCII85Decode"))),
  ])
  let out = @pdfcodec.PdfCodec::new().decode_from_bytes(
    @pdfio.bytes_of_string("v~>"),
    dict,
  )
  assert_true(out is None)
}

///|
test "encode/decode RunLength stream" {
  let original = @pdfio.bytes_of_string("runlength data")
  let decoded = roundtrip_encoding(RunLength, original)
  assert_eq(@pdfio.string_of_bytes(decoded), "runlength data")
}

///|
test "encode/decode LZW stream" {
  let original = @pdfio.bytes_of_string("TOBEORNOTTOBEORTOBEORNOT")
  let decoded = roundtrip_encoding(LZW(1), original)
  assert_eq(@pdfio.string_of_bytes(decoded), "TOBEORNOTTOBEORTOBEORNOT")
}

///|
test "encode_pdfstream prepends filter when name already set" {
  let pdf = @pdf.Pdf::empty()
  let data = @pdfio.bytes_of_string("filter chain")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/Filter", Name(PdfName(b"/ASCII85Decode"))),
  ])
  let stream_ref = Ref((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  ctx.encode_pdfstream(pdf, Flate, stream_obj)
  match (pdf.lookup_direct("/Filter", stream_ref.val.0) : @pdf.PdfObject?) {
    Some(PdfArray(filters)) => {
      assert_true(filters.length() >= 2)
      match (filters[0] : @pdf.PdfObject) {
        Name(PdfName(b"/FlateDecode")) => ()
        _ => fail("expected /FlateDecode to be first")
      }
    }
    _ => fail("expected filter array")
  }
}

///|
test "encode_pdfstream prepends filter when array already set" {
  let pdf = @pdf.Pdf::empty()
  let data = @pdfio.bytes_of_string("array filter")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/Filter", PdfArray([Name(PdfName(b"/ASCIIHexDecode"))])),
  ])
  let stream_ref = Ref((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  ctx.encode_pdfstream(pdf, Flate, stream_obj)
  match (pdf.lookup_direct("/Filter", stream_ref.val.0) : @pdf.PdfObject?) {
    Some(PdfArray(filters)) =>
      match (filters[0] : @pdf.PdfObject) {
        Name(PdfName(b"/FlateDecode")) => ()
        _ => fail("expected /FlateDecode to be first")
      }
    _ => fail("expected filter array")
  }
}

///|
test "encode_pdfstream keeps data when only_if_smaller" {
  let pdf = @pdf.Pdf::empty()
  let data = @pdfio.bytes_of_string("x")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
  ])
  let stream_ref = Ref((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  ctx.encode_pdfstream(pdf, Flate, stream_obj, only_if_smaller=true)
  match pdf.lookup_direct("/Filter", stream_ref.val.0) {
    None => ()
    _ => fail("expected no /Filter when not smaller")
  }
}

///|
test "decode_pdfstream handles filter arrays" {
  let pdf = @pdf.Pdf::empty()
  let original = @pdfio.bytes_of_string("decode chain")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(original))),
  ])
  let stream_ref = Ref((dict, @pdf.Stream::Got(original)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  ctx.encode_pdfstream(pdf, ASCII85, stream_obj, only_if_smaller=false)
  ctx.encode_pdfstream(pdf, ASCIIHex, stream_obj, only_if_smaller=false)
  ctx.decode_pdfstream(pdf, stream_obj)
  match (stream_ref.val : (@pdf.PdfObject, @pdf.Stream)) {
    (decoded_dict, Got(bytes)) => {
      assert_eq(@pdfio.string_of_bytes(bytes), "decode chain")
      match decoded_dict.lookup_immediate("/Filter") {
        None => ()
        _ => fail("expected /Filter removed")
      }
    }
    _ => fail("expected decoded bytes")
  }
}
