///|
/// Permissions for PDF encryption.
pub(all) enum Permission {
  NoEdit
  NoPrint
  NoCopy
  NoAnnot
  NoForms
  NoExtract
  NoAssemble
  NoHqPrint
} derive(Eq, Debug)

///|
fn contains_perm(perms : Array[Permission], perm : Permission) -> Bool {
  perms[:].contains(perm)
}

///|
fn p_of_banlist(toban : Array[Permission]) -> Int {
  let mut p = 0
  let setbit = fn(n : Int, allow : Bool) -> Unit {
    if allow {
      p = Int::lor(p, 1 << (n - 1))
    }
  }
  let notin = fn(perm : Permission) -> Bool { !contains_perm(toban, perm) }
  setbit(3, notin(NoPrint))
  setbit(4, notin(NoEdit))
  setbit(5, notin(NoCopy))
  setbit(6, notin(NoAnnot))
  setbit(7, true)
  setbit(8, true)
  setbit(9, notin(NoForms))
  setbit(10, notin(NoExtract))
  setbit(11, notin(NoAssemble))
  setbit(12, notin(NoHqPrint))
  let mut n = 13
  while n <= 32 {
    setbit(n, true)
    n = n + 1
  }
  p
}

///|
/// Parse a /P value, giving the permissions.
pub fn PdfCrypt::banlist_of_p(_self : PdfCrypt, p : Int) -> Array[Permission] {
  // Maximum of 8 permission flags.
  let out = Array(capacity=8)
  let bitset = fn(n : Int) -> Bool { Int::land(p >> (n - 1), 1) == 0 }
  if bitset(3) {
    out.push(Permission::NoPrint)
  }
  if bitset(4) {
    out.push(NoEdit)
  }
  if bitset(5) {
    out.push(NoCopy)
  }
  if bitset(6) {
    out.push(NoAnnot)
  }
  if bitset(9) {
    out.push(NoForms)
  }
  if bitset(10) {
    out.push(NoExtract)
  }
  if bitset(11) {
    out.push(NoAssemble)
  }
  if bitset(12) {
    out.push(NoHqPrint)
  }
  out
}

// Explicit method promotion for derived/implemented traits.
// (Previously implicit; see warning [0079] implicit_impl_as_method.)

///|
pub extend Permission with Debug::{to_repr}

///|
pub extend Permission with Eq::{not_equal, equal}
