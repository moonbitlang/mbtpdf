///|
/// Helpers for converting between raw bytes (`Bytes`) and the historical
/// "bytes-in-String" representation used throughout this codebase.
///
/// The conversion is byte-wise and does *not* perform any Unicode decoding.
/// Each `Char` code unit is truncated to its low 8 bits (0..255).
pub fn bytes_of_string_bytes(value : String) -> Bytes {
  Bytes::from_array(@pdfio.bytes_of_string(value)[:])
}

///|
/// Convert raw bytes into the historical "bytes-in-String" representation.
pub fn string_bytes_of_bytes(bytes : Bytes) -> String {
  @pdfio.string_of_bytes(bytes.to_array())
}
