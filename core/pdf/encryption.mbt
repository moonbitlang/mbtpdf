///|
/// Snapshot of encryption settings used for re-encryption.
pub type EncryptionValues = (
  @pdfcryptprimitives.Encryption,
  String,
  String,
  Int,
  String,
  String?,
  String?,
)

///|
/// Saved encryption metadata used by recrypt helpers.
pub(all) struct SavedEncryption {
  from_get_encryption_values : EncryptionValues
  encrypt_metadata : Bool
  perms : String
}

///|
/// Deferred crypt settings for stream materialization.
pub(all) struct DeferredEncryption {
  crypt_type : @pdfcryptprimitives.Encryption
  file_encryption_key : String?
  obj : Int
  gen : Int
  key : Array[Int]
  keylength : Int
  r : Int
} derive(Debug)

///|
/// Indicates whether a stream needs decryption when materialized.
pub(all) enum ToGetCrypt {
  NoChange
  ToDecrypt(DeferredEncryption)
} derive(Debug)

// Explicit method promotion for derived/implemented traits.
// (Previously implicit; see warning [0079] implicit_impl_as_method.)

///|
pub extend DeferredEncryption with Debug::{to_repr}

///|
pub extend ToGetCrypt with Debug::{to_repr}
