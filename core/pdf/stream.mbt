///|
/// Stream descriptor when bytes are not yet materialized.
pub(all) struct ToGet {
  input : @pdfio.Input
  position : Int
  length : Int
  crypt : ToGetCrypt
} derive(Debug(ignore=@pdfio.Input))

///|
pub fn ToGet::new(
  input : @pdfio.Input,
  position : Int,
  length : Int,
  crypt? : ToGetCrypt = NoChange,
) -> ToGet {
  { input, position, length, crypt, }
}

///|
pub fn ToGet::length(self : ToGet) -> Int {
  self.length
}

///|
/// Stream payload, either in memory or deferred.
pub(all) enum Stream {
  Got(Array[Byte])
  ToGet(ToGet)
} derive(Debug)

///|
/// Get a stream from disk if it hasn't already been got.
fn process_deferred_cryption(
  crypt : ToGetCrypt,
  data : Array[Byte],
) -> Array[Byte] raise {
  match crypt {
    NoChange => data
    ToDecrypt(saved) =>
      @pdfcryptprimitives.PdfCryptPrimitives::new().decrypt_stream_data(
        saved.crypt_type,
        false,
        saved.file_encryption_key,
        saved.obj,
        saved.gen,
        saved.key,
        saved.keylength,
        saved.r,
        data,
      )
  }
}

///|
/// Get a stream from disk if it hasn't already been got.
pub fn PdfObject::getstream(self : PdfObject) -> Unit raise {
  match self {
    Stream(r) =>
      match r.val {
        (dict, ToGet(toget)) => {
          let data = try {
            let raw = toget.input.bytes_of_input(toget.position, toget.length)
            process_deferred_cryption(toget.crypt, raw)
          } catch {
            _ => raise PdfError::Msg("getstream: can't read stream")
          }
          let dict_updated = match dict {
            Dictionary(_) =>
              dict.replace_entry("/Length", Integer(@pdfio.bytes_size(data)))
            _ => dict
          }
          r.val = (dict_updated, Got(data))
        }
        _ => ()
      }
    _ => raise PdfError::Msg("getstream: not a stream")
  }
}

///|
/// Find the contents of a stream as bytes.
pub fn PdfObject::bigarray_of_stream(self : PdfObject) -> Array[Byte] raise {
  self.getstream()
  match self {
    Stream(r) =>
      match r.val {
        (_, Got(bytes)) => bytes
        _ => raise PdfError::Msg("couldn't extract raw stream")
      }
    _ => raise PdfError::Msg("couldn't extract raw stream")
  }
}

// Explicit method promotion for derived/implemented traits.
// (Previously implicit; see warning [0079] implicit_impl_as_method.)

///|
pub extend Stream with Debug::{to_repr}

///|
pub extend ToGet with Debug::{to_repr}
