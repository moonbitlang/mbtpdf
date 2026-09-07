///|
/// Encryption methods.
pub(all) enum EncryptionMethod {
  PDF40bit
  PDF128bit
  AES128bit(Bool)
  AES256bit(Bool)
  AES256bitISO(Bool)
  AlreadyEncrypted
} derive(Debug)

// Explicit method promotion for derived/implemented traits.
// (Previously implicit; see warning [0079] implicit_impl_as_method.)

///|
pub extend EncryptionMethod with Debug::{to_repr}
