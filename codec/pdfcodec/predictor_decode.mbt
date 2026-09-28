///|
/// Decode predictor (placeholder).
fn decode_predictor(
  _pred : Int,
  _colors : Int,
  _bpc : Int,
  _columns : Int,
  _stream : Array[Byte],
) -> Array[Byte] raise CodecError {
  let pred = _pred
  let colors = _colors
  let bpc = _bpc
  let columns = _columns
  let stream = _stream
  // /Colors, /BitsPerComponent and /Columns come from untrusted
  // /DecodeParms. Validate them before any arithmetic can overflow: a
  // negative or wrapped-around width aborts in `Array::make` or indexes out
  // of bounds, and a huge one allocates per-row buffers far larger than the
  // data. A scanline (or a single pixel) wider than the whole decoded data is
  // inconsistent, so it is rejected. Zero keeps its existing meaning (empty
  // scanlines), and there is nothing to un-predict in empty data.
  if colors < 0 || bpc < 0 || columns < 0 {
    raise CouldntDecodeStream(
      "predictor: invalid /Colors \{colors}, /BitsPerComponent \{bpc} or /Columns \{columns}",
    )
  }
  if stream.length() == 0 {
    return []
  }
  let max_bits = stream.length().to_int64() * 8L
  // Both factors are < 2^31, so this cannot overflow Int64.
  let pixel_bits = colors.to_int64() * bpc.to_int64()
  if pixel_bits > max_bits ||
    (pixel_bits > 0L && columns.to_int64() > max_bits / pixel_bits) {
    raise CouldntDecodeStream(
      "predictor: scanline of \{columns} x \{colors} x \{bpc} bits exceeds the data",
    )
  }
  // Both are now <= stream.length(), so they fit in an Int.
  let scanline_width = ((pixel_bits * columns.to_int64() + 7L) / 8L).to_int()
  let bytes_per_pixel = ((pixel_bits + 7L) / 8L).to_int()
  if pred == 2 {
    decode_tiff_predictor(colors, bpc, scanline_width, stream)
  } else {
    decode_png_predictor(bpc, scanline_width, bytes_per_pixel, stream)
  }
}

///|
fn decode_tiff_predictor(
  colors : Int,
  bpc : Int,
  scanline_width : Int,
  stream : Array[Byte],
) -> Array[Byte] raise CodecError {
  if bpc != 8 {
    raise DecodeNotSupported("TIFF predictor only supports 8bpc")
  }
  let out = stream.copy()
  let lines = if scanline_width == 0 {
    0
  } else {
    out.length() / scanline_width
  }
  for line in 0..<lines {
    let line_start = line * scanline_width
    for p in colors..<scanline_width {
      let val = (
          out[line_start + p - colors].to_int() + out[line_start + p].to_int()
        ) %
        256
      out[line_start + p] = val.to_byte()
    }
  }
  out
}

///|
fn decode_png_predictor(
  bpc : Int,
  scanline_width : Int,
  bytes_per_pixel : Int,
  stream : Array[Byte],
) -> Array[Byte] raise CodecError {
  if bpc != 8 {
    raise DecodeNotSupported("PNG predictor only supports 8bpc")
  }
  let mut pos = 0
  let prev_decoded = Array::make(scanline_width, 0)
  // Output is always <= input length (predictor bytes are dropped).
  let output : Array[Byte] = Array(capacity=stream.length())
  while pos < stream.length() {
    let predictor = stream[pos].to_int()
    pos = pos + 1
    let curr = Array::make(scanline_width, 0)
    let mut i = 0
    while i < scanline_width && pos < stream.length() {
      curr[i] = stream[pos].to_int()
      pos = pos + 1
      i = i + 1
    }
    let decoded = decode_scanline_pair(
      prev_decoded, curr, predictor, bytes_per_pixel,
    )
    for v in decoded {
      output.push(v.to_byte())
    }
    for i in 0..<scanline_width {
      prev_decoded[i] = decoded[i]
    }
    if i < scanline_width {
      break
    }
  }
  output
}
