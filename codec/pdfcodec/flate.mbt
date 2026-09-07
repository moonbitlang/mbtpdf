///|
/// Decode data in FlateDecode.
pub fn PdfCodec::decode_flate(
  _self : PdfCodec,
  data : Array[Byte],
) -> Array[Byte] raise CodecError {
  let mut pos = 0
  let input = (buf : Array[Byte]) => {
    let remaining = data.length() - pos
    if remaining <= 0 {
      0
    } else {
      let n = if remaining < buf.length() { remaining } else { buf.length() }
      data[pos:pos + n].blit_to(buf)
      pos = pos + n
      n
    }
  }
  let out : Array[Byte] = Array()
  let output = (buf : Array[Byte], length : Int) => out.append(buf[:length])
  try {
    @pdfflate.PdfFlate::new().uncompress(header=true, input, output)
    out
  } catch {
    Error(stage, msg) => raise CouldntDecodeStream("\{stage}: \{msg}")
  }
}

///|
/// Encode a PDF stream with an encoding.
pub fn PdfCodec::encode_pdfstream(
  self : PdfCodec,
  pdf : @pdf.Pdf,
  encoding : Encoding,
  obj : @pdf.PdfObject,
  im? : String,
  only_if_smaller? : Bool = false,
  predictor? : Predictor,
  predictor_columns? : Int,
) -> Unit raise CodecError {
  let _ = im
  let predictor_columns = match predictor_columns {
    Some(value) => value
    None => 1
  }
  let encoding_name = match encoding {
    ASCIIHex => "/ASCIIHexDecode"
    ASCII85 => "/ASCII85Decode"
    RunLength => "/RunLengthDecode"
    LZW(_) => "/LZWDecode"
    Flate => "/FlateDecode"
    CCITT(_, _) | CCITTG4(_, _) => "/CCITTFaxDecode"
  }
  let encoding_pdf_name = @pdf.PdfName::of_string(encoding_name)
  fn update_filter(dict : @pdf.PdfObject) -> @pdf.PdfObject raise CodecError {
    let filter_obj : @pdf.PdfObject = match pdf.lookup_direct("/Filter", dict) {
      None => Name(encoding_pdf_name)
      Some(Name(name)) => PdfArray([Name(encoding_pdf_name), Name(name)])
      Some(PdfArray(filters)) => {
        let updated = Array(capacity=filters.length() + 1)
        updated.push(@pdf.PdfObject::Name(encoding_pdf_name))
        for f in filters {
          updated.push(f)
        }
        PdfArray(updated)
      }
      Some(_) => raise CouldntDecodeStream("malformed /Filter")
    }
    set_dict_entry(dict, "/Filter", filter_obj)
  }

  fn process_prediction(
    dict : @pdf.PdfObject,
    data : Array[Byte],
  ) -> (@pdf.PdfObject, Array[Byte]) raise CodecError {
    match predictor {
      Some(pred) => {
        let (pred_value, colors, bpc) = match pred {
          TIFF2 => (2, 1, 8)
          PNGNone => (10, 1, 8)
          PNGSub => (11, 1, 8)
          PNGUp => (12, 1, 8)
          PNGAverage => (13, 1, 8)
          PNGPaeth => (14, 1, 8)
          PNGOptimum => (15, 1, 8)
        }
        let predicted = encode_predictor(
          pred_value, colors, bpc, predictor_columns, data,
        )
        let decodeparms = @pdf.PdfObject::Dictionary([
          ("/Columns", Integer(predictor_columns)),
          ("/Predictor", Integer(pred_value)),
          ("/Colors", Integer(colors)),
          ("/BitsPerComponent", Integer(bpc)),
        ])
        let dict_with_parms = set_dict_entry(dict, "/DecodeParms", decodeparms)
        (dict_with_parms, predicted)
      }
      None => (dict, data)
    }
  }

  fn encode_stream(
    dict : @pdf.PdfObject,
    data : Array[Byte],
  ) -> (@pdf.PdfObject, Array[Byte]) raise CodecError {
    let (predicted_dict, predicted_data) = process_prediction(dict, data)
    let encoded = match encoding {
      ASCIIHex => encode_asciihex(predicted_data)
      ASCII85 => encode_ascii85(predicted_data)
      RunLength => encode_runlength(predicted_data)
      LZW(early) => encode_lzw(early, predicted_data)
      Flate => self.encode_flate(predicted_data)
      CCITT(columns, rows) => encode_ccitt(columns, rows, predicted_data)
      CCITTG4(columns, rows) =>
        encode_ccittg4(columns, rows, predicted_data, im?)
    }
    let dict_with_filter = update_filter(predicted_dict)
    let dict_with_length = set_dict_entry(
      dict_with_filter,
      "/Length",
      Integer(@pdfio.bytes_size(encoded)),
    )
    (dict_with_length, encoded)
  }

  match (obj : @pdf.PdfObject) {
    Stream(r) => {
      map_pdf_error("getstream", fn() raise { obj.getstream() })
      let (dict, stream_data) = r.val
      let data = match (stream_data : @pdf.Stream) {
        Got(bytes) => bytes
        _ => raise CouldntDecodeStream("stream data not available")
      }
      let (new_dict, new_data) = encode_stream(dict, data)
      if !only_if_smaller ||
        @pdfio.bytes_size(new_data) + 20 < @pdfio.bytes_size(data) {
        r.val = (new_dict, Got(new_data))
      }
    }
    Indirect(i) =>
      self.encode_pdfstream(
        pdf,
        encoding,
        pdf.direct(Indirect(i)),
        im?,
        only_if_smaller~,
        predictor?,
        predictor_columns~,
      )
    _ => raise CouldntDecodeStream("malformed stream")
  }
}

///|
/// Decode just one stage of a PDF stream.
pub fn PdfCodec::decode_pdfstream_onestage(
  self : PdfCodec,
  pdf : @pdf.Pdf,
  obj : @pdf.PdfObject,
  jbig2dec? : String,
) -> Unit raise CodecError {
  match (obj : @pdf.PdfObject) {
    Stream(r) => {
      let (dict, _stream) = r.val
      let (filter_key, filter_opt) = match dict.lookup_immediate("/Filter") {
        Some(_) => ("/Filter", pdf.lookup_direct("/Filter", dict))
        None =>
          match dict.lookup_immediate("/F") {
            Some(_) => ("/F", pdf.lookup_direct("/F", dict))
            None => ("/Filter", None)
          }
      }
      let (parms_key, parms) = match dict.lookup_immediate("/DecodeParms") {
        Some(_) => ("/DecodeParms", pdf.lookup_direct("/DecodeParms", dict))
        None =>
          match dict.lookup_immediate("/DP") {
            Some(_) => ("/DP", pdf.lookup_direct("/DP", dict))
            None => ("/DecodeParms", None)
          }
      }
      match filter_opt {
        None => raise DecodeNotSupported("no filter")
        Some(filter_obj) => {
          let (filter_name, remaining_filters) : (
            @pdf.PdfName,
            Array[@pdf.PdfObject]?,
          ) = match (filter_obj : @pdf.PdfObject) {
            Name(name) => (name, None)
            PdfArray([]) => raise DecodeNotSupported("empty filter array")
            PdfArray([Name(name), .. rest]) => (name, Some(rest.to_owned()))
            PdfArray(_) => raise DecodeNotSupported("invalid filter entry")
            _ => raise DecodeNotSupported("invalid filter")
          }
          map_pdf_error("getstream", fn() raise { obj.getstream() })
          let data = match r.val {
            (_, Got(bytes)) => bytes
            _ => raise CouldntDecodeStream("stream data not available")
          }
          let parms_first = match parms {
            Some(PdfArray(arr)) =>
              if arr.length() > 0 {
                Some(arr[0])
              } else {
                None
              }
            Some(Null) => None
            Some(other) => Some(other)
            None => None
          }
          let decoded = PdfFilterNameDecode::decode_stage(
            filter_name, self, pdf, parms_first, data, jbig2dec,
          )
          let mut new_dict = dict
          new_dict = match remaining_filters {
            None =>
              map_pdf_error("remove filter", fn() raise {
                new_dict.remove_entry(filter_key)
              })
            Some(rest) =>
              if rest.length() == 0 {
                map_pdf_error("remove filter", fn() raise {
                  new_dict.remove_entry(filter_key)
                })
              } else {
                map_pdf_error("replace filter", fn() raise {
                  new_dict.replace_entry(filter_key, PdfArray(rest))
                })
              }
          }
          new_dict = match parms {
            None => new_dict
            Some(PdfArray(arr)) =>
              if arr.length() == 0 {
                map_pdf_error("remove decode parms", fn() raise {
                  new_dict.remove_entry(parms_key)
                })
              } else {
                let rest = arr[1:].to_owned()
                if rest.length() == 0 {
                  map_pdf_error("remove decode parms", fn() raise {
                    new_dict.remove_entry(parms_key)
                  })
                } else {
                  map_pdf_error("replace decode parms", fn() raise {
                    new_dict.replace_entry(parms_key, PdfArray(rest))
                  })
                }
              }
            Some(_) =>
              map_pdf_error("remove decode parms", fn() raise {
                new_dict.remove_entry(parms_key)
              })
          }
          new_dict = set_dict_entry(
            new_dict,
            "/Length",
            Integer(@pdfio.bytes_size(decoded)),
          )
          r.val = (new_dict, Got(decoded))
        }
      }
    }
    _ => raise DecodeNotSupported("not a stream")
  }
}

///|
/// Trait-based filter dispatch.
///
/// This keeps the set of supported filter names and their parameter handling
/// in one place, while leaving higher-level `/Filter` array trimming and
/// dictionary mutation to `decode_pdfstream_onestage`.
pub impl PdfFilterNameDecode for @pdf.PdfName with fn decode_stage(
  filter_name : @pdf.PdfName,
  ctx : PdfCodec,
  pdf : @pdf.Pdf,
  parms : @pdf.PdfObject?,
  data : Array[Byte],
  jbig2dec : String?,
) -> Array[Byte] raise CodecError {
  if filter_name is PdfName(b"/FlateDecode" | b"/Fl") {
    let mut decoded = ctx.decode_flate(data)
    match parms {
      Some(Dictionary(_)) => {
        let predictor = get_int_param(pdf, parms, "/Predictor", 1)
        if predictor != 1 {
          let colors = get_int_param(pdf, parms, "/Colors", 1)
          let bpc = get_int_param(pdf, parms, "/BitsPerComponent", 8)
          let columns = get_int_param(pdf, parms, "/Columns", 1)
          decoded = decode_predictor(predictor, colors, bpc, columns, decoded)
        }
      }
      _ => ()
    }
    decoded
  } else if filter_name is PdfName(b"/ASCIIHexDecode" | b"/AHx") {
    decode_asciihex(@pdfio.Input::of_bytes(data, source="asciihex"))
  } else if filter_name is PdfName(b"/ASCII85Decode" | b"/A85") {
    decode_ascii85(@pdfio.Input::of_bytes(data, source="ascii85"))
  } else if filter_name is PdfName(b"/RunLengthDecode" | b"/RL") {
    decode_runlength(@pdfio.Input::of_bytes(data, source="runlength"))
  } else if filter_name is PdfName(b"/LZWDecode" | b"/LZW") {
    let early = get_int_param(pdf, parms, "/EarlyChange", 1)
    decode_lzw(early, @pdfio.Input::of_bytes(data, source="lzw"))
  } else if filter_name is PdfName(b"/Crypt") {
    data
  } else if filter_name is PdfName(b"/JBIG2Decode") {
    let _ = jbig2dec
    raise DecodeNotSupported("JBIG2Decode requires decode_pdfstream_async")
  } else if filter_name is PdfName(b"/CCITTFaxDecode" | b"/CCF") {
    let k = get_int_param(pdf, parms, "/K", 0)
    let eol = get_bool_param(pdf, parms, "/EndOfLine", false)
    let eba = get_bool_param(pdf, parms, "/EncodedByteAlign", false)
    let columns = get_int_param(pdf, parms, "/Columns", 1728)
    let rows = get_int_param(pdf, parms, "/Rows", 0)
    let eob = get_bool_param(pdf, parms, "/EndOfBlock", true)
    let bone = get_bool_param(pdf, parms, "/BlackIs1", false)
    let dra = get_int_param(pdf, parms, "/DamagedRowsBeforeError", 0)
    decode_ccittfax(
      k,
      eol,
      eba,
      columns,
      rows,
      eob,
      bone,
      dra,
      @pdfio.Input::of_bytes(data, source="ccitt"),
    )
  } else {
    raise DecodeNotSupported(
      "filter not supported: \{filter_name.to_string_bytes()}",
    )
  }
}

///|
/// Decode bytes using filters in dict; returns None when decoder unsupported.
pub fn PdfCodec::decode_from_bytes(
  self : PdfCodec,
  bytes : Array[Byte],
  dict : @pdf.PdfObject,
) -> Array[Byte]? {
  let pdf = @pdf.Pdf::empty()
  let filter_opt = pdf.lookup_direct_orelse("/F", "/Filter", dict)
  let parms_opt = pdf.lookup_direct_orelse("/DP", "/DecodeParms", dict)
  fn parms_at(index : Int) -> @pdf.PdfObject? {
    match parms_opt {
      Some(PdfArray(arr)) =>
        if index < arr.length() {
          Some(arr[index])
        } else {
          None
        }
      Some(Null) => None
      Some(other) => if index == 0 { Some(other) } else { None }
      None => None
    }
  }

  fn decode_stage(
    bytes : Array[Byte],
    filter_name : @pdf.PdfName,
    parms : @pdf.PdfObject?,
  ) -> Array[Byte]? {
    let decoded_result : Result[Array[Byte], Error] = try
      PdfFilterNameDecode::decode_stage(
        filter_name,
        self,
        pdf,
        parms,
        bytes,
        None,
      )
      |> Ok
    catch {
      e => Err(e)
    }
    match decoded_result {
      Ok(decoded) => Some(decoded)
      Err(_) => None
    }
  }

  match filter_opt {
    Some(Name(name)) => decode_stage(bytes, name, parms_at(0))
    Some(PdfArray(filters)) => {
      if filters.length() == 0 {
        return None
      }
      let mut current = bytes
      for i in 0..<filters.length() {
        let filter_name = match (filters[i] : @pdf.PdfObject) {
          Name(name) => name
          _ => return None
        }
        match decode_stage(current, filter_name, parms_at(i)) {
          Some(decoded) => current = decoded
          None => return None
        }
      }
      Some(current)
    }
    _ => None
  }
}
