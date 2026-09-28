// Property-based tests for the crypto primitives (MD5, SHA-2, ARC4, AES).
//
// Reference digests / ciphertexts were produced by independent
// implementations (Python `hashlib` and `openssl enc`) for the deterministic
// message family `pattern_msg(n)`; the lengths cover every padding boundary
// of the 64-byte (MD5, SHA-256) and 128-byte (SHA-384/512) block functions.

///|
fn pattern_msg(n : Int) -> Array[Byte] {
  Array::makei(n, i => ((i * 31 + n * 7 + 13) & 0xff).to_byte())
}

///|
fn to_hex(bytes : Array[Byte]) -> String {
  let digits = "0123456789abcdef"
  let sb = StringBuilder()
  for b in bytes {
    let v = b.to_int()
    sb.write_char(digits[v >> 4].unsafe_to_char())
    sb.write_char(digits[v & 0xf].unsafe_to_char())
  }
  sb.to_string()
}

///|
fn hex_prefix(bytes : Array[Byte], n : Int) -> String {
  to_hex(bytes[:n].to_owned())
}

///|
let prims : @pdfcryptprimitives.PdfCryptPrimitives = @pdfcryptprimitives.PdfCryptPrimitives::new()

///|
/// A message length in `0..=150`, biased towards block-padding boundaries.
priv struct MsgLen(Int) derive(Debug)

///|
impl @quickcheck.Arbitrary for MsgLen with fn arbitrary(size, rs) {
  let boundary = @quickcheck.elements([
    0, 1, 55, 56, 57, 63, 64, 65, 111, 112, 113, 119, 120, 127, 128, 129, 150,
  ])
  let any = @quickcheck.int_range(0, 151)
  MsgLen(@quickcheck.frequency([(1, boundary), (2, any)]).run(size, rs))
}

///|
impl @quickcheck.Shrink for MsgLen

///|
/// Arbitrary binary payload: mostly short, sometimes several AES blocks, with
/// block-aligned lengths over-represented.
priv struct Payload(Array[Byte]) derive(Debug)

///|
fn gen_bytes(len : Int, rs : @quickcheck.RandomState) -> Array[Byte] {
  Array::makei(len, _ => rs.next_uint(limit=256).reinterpret_as_int().to_byte())
}

///|
impl @quickcheck.Arbitrary for Payload with fn arbitrary(size, rs) {
  let len = @quickcheck.frequency([
    (3, @quickcheck.int_range(0, 40)),
    (1, @quickcheck.int_range(0, 6).map(k => k * 16)),
    (1, @quickcheck.int_range(40, 200)),
  ]).run(size, rs)
  Payload(gen_bytes(len, rs))
}

///|
impl @quickcheck.Shrink for Payload with fn shrink(self) {
  let Payload(bytes) = self
  @quickcheck.Shrink::shrink(bytes).map(b => Payload(b))
}

///|
/// An AES key: `nk` 32-bit words (4, 6 or 8) of random key bytes, plus an IV.
priv struct AesKey {
  nk : Int
  key : Array[Int]
  iv : Array[Int]
} derive(Debug)

///|
impl @quickcheck.Arbitrary for AesKey with fn arbitrary(size, rs) {
  let nk = @quickcheck.elements([4, 6, 8]).run(size, rs)
  let key = Array::makei(nk * 4, _ => {
    rs.next_uint(limit=256).reinterpret_as_int()
  })
  let iv = Array::makei(16, _ => rs.next_uint(limit=256).reinterpret_as_int())
  { nk, key, iv, }
}

///|
impl @quickcheck.Shrink for AesKey

///|
fn str_bytes(s : String) -> Array[Byte] {
  @pdfio.bytes_of_string(s)
}

///|
test "prop: MD5/SHA-256/SHA-384/SHA-512 agree with hashlib on all padding boundaries" {
  @quickcheck.check(
    (l : MsgLen) => {
      let MsgLen(n) = l
      let msg = pattern_msg(n)
      let md5 = hex_prefix(prims.md5(msg), 4)
      let s256 = hex_prefix(
        str_bytes(prims.sha256(@pdfio.Input::of_bytes(msg))),
        4,
      )
      let s384 = hex_prefix(
        str_bytes(prims.sha384(@pdfio.Input::of_bytes(msg))),
        4,
      )
      let s512 = hex_prefix(
        str_bytes(prims.sha512(@pdfio.Input::of_bytes(msg))),
        4,
      )
      md5 == ref_md5_prefix[n] &&
      s256 == ref_sha256_prefix[n] &&
      s384 == ref_sha384_prefix[n] &&
      s512 == ref_sha512_prefix[n]
    },
    observe=l => {
      let MsgLen(n) = l
      [
        @quickcheck.classify(n % 64 >= 55 && n % 64 <= 56, "64-byte pad edge"),
        @quickcheck.classify(
          n % 128 >= 111 && n % 128 <= 112,
          "128-byte pad edge",
        ),
        @quickcheck.classify(n > 128, "multi-block"),
      ]
    },
    count=300,
    seed=0x5ea1,
  )
}

///|
test "prop: digests have the fixed output size" {
  @quickcheck.check(
    (p : Payload) => {
      let Payload(msg) = p
      prims.md5(msg).length() == 16 &&
      prims.sha256(@pdfio.Input::of_bytes(msg)).length() == 32 &&
      prims.sha384(@pdfio.Input::of_bytes(msg)).length() == 48 &&
      prims.sha512(@pdfio.Input::of_bytes(msg)).length() == 64
    },
    count=100,
    seed=0xd16e,
  )
}

///|
test "prop: AES-CBC encryption matches openssl (PKCS#7, explicit IV)" {
  let key128 = Array::makei(16, i => i)
  let key256 = Array::makei(32, i => (i * 7 + 3) & 0xff)
  let iv = Array::makei(16, i => (0xa0 + i) & 0xff)
  @quickcheck.check(
    (l : MsgLen) => {
      let MsgLen(n0) = l
      let n = n0 % 49
      let msg = pattern_msg(n)
      let c128 = prims.aes_encrypt_data(4, key128, msg, firstblock=iv)
      let c256 = prims.aes_encrypt_data(8, key256, msg, firstblock=iv)
      let last = (c : Array[Byte]) => to_hex(c[c.length() - 16:].to_owned())
      last(c128) == ref_aes128_cbc_last_block[n] &&
      last(c256) == ref_aes256_cbc_last_block[n]
    },
    count=150,
    seed=0xae5,
  )
}

///|
test "prop: AES-CBC decrypt inverts encrypt for every key size and length" {
  @quickcheck.check(
    (input : (AesKey, Payload)) => {
      let (k, Payload(msg)) = input
      let enc = prims.aes_encrypt_data(k.nk, k.key, msg, firstblock=k.iv)
      prims.aes_decrypt_data(k.nk, k.key, enc) == msg
    },
    observe=input => {
      let (k, Payload(msg)) = input
      [
        @quickcheck.collect(k.nk),
        @quickcheck.classify(msg.length() % 16 == 0, "block aligned"),
        @quickcheck.classify(msg.length() == 0, "empty"),
      ]
    },
    count=300,
    seed=0xcbc,
  )
}

///|
test "prop: AES-CBC ciphertext is IV followed by PKCS#7-padded blocks" {
  @quickcheck.check(
    (input : (AesKey, Payload)) => {
      let (k, Payload(msg)) = input
      let enc = prims.aes_encrypt_data(k.nk, k.key, msg, firstblock=k.iv)
      enc.length() == 16 + 16 * (msg.length() / 16 + 1) &&
      @pdfio.int_array_of_bytes(enc[:16].to_owned()) == k.iv &&
      prims.aes_decrypt_data(k.nk, k.key, enc, remove_padding=false).length() ==
      enc.length() - 16
    },
    count=200,
    seed=0x1f,
  )
}

///|
test "prop: AES-ECB decrypt inverts encrypt on block-aligned data" {
  @quickcheck.check(
    (input : (AesKey, Payload)) => {
      let (k, Payload(raw)) = input
      let msg = raw[:raw.length() - raw.length() % 16].to_owned()
      let enc = prims.aes_encrypt_data_ecb(k.nk, k.key, msg)
      enc.length() == msg.length() &&
      prims.aes_decrypt_data_ecb(k.nk, k.key, enc, remove_padding=false) == msg
    },
    count=200,
    seed=0xecb,
  )
}

///|
test "prop: AES decryption never aborts on arbitrary (malformed) ciphertext" {
  // Ciphertext comes straight from untrusted PDF strings/streams, /OE and /UE
  // entries, so any length must be tolerated.
  @quickcheck.check(
    (input : (AesKey, Payload)) => {
      let (k, Payload(data)) = input
      let cbc = prims.aes_decrypt_data(k.nk, k.key, data)
      let cbc_raw = prims.aes_decrypt_data(
        k.nk,
        k.key,
        data,
        remove_padding=false,
      )
      let ecb = prims.aes_decrypt_data_ecb(k.nk, k.key, data)
      cbc.length() <= data.length() &&
      cbc_raw.length() <= data.length() &&
      ecb.length() <= data.length()
    },
    observe=input => {
      let (_, Payload(data)) = input
      [@quickcheck.classify(data.length() % 16 != 0, "not block aligned")]
    },
    count=300,
    seed=0xbad,
  )
}

///|
test "regression: AES-CBC decrypt of a partial trailing block" {
  // IV + 4 bytes: previously indexed past the end of the input and aborted.
  let key = Array::makei(16, i => i)
  let data = Array::makei(20, i => i.to_byte())
  inspect(prims.aes_decrypt_data(4, key, data).length(), content="0")
  // IV + one full block + 5 stray bytes: the stray tail is ignored.
  let enc = prims.aes_encrypt_data(4, key, str_bytes("hello"), firstblock=[
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  ])
  let tampered = enc.copy()
  tampered.append([b'\x01', b'\x02', b'\x03', b'\x04', b'\x05'])
  inspect(
    @pdfio.string_of_bytes(prims.aes_decrypt_data(4, key, tampered)),
    content="hello",
  )
  inspect(
    prims.aes_decrypt_data_ecb(4, key, data[:7].to_owned()).length(),
    content="0",
  )
}

///|
test "AES-192/256 FIPS-197 appendix C vectors" {
  let plain = @pdfio.bytes_of_list([
    0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xaa, 0xbb, 0xcc,
    0xdd, 0xee, 0xff,
  ])
  let c192 = prims.aes_encrypt_data_ecb(6, Array::makei(24, i => i), plain)
  inspect(to_hex(c192), content="dda97ca4864cdfe06eaf70a0ec0d7191")
  let c256 = prims.aes_encrypt_data_ecb(8, Array::makei(32, i => i), plain)
  inspect(to_hex(c256), content="8ea2b7ca516745bfeafc49904b496089")
}

///|
test "ARC4 known vectors" {
  let rc4 = (key : String, text : String) => {
    to_hex(prims.crypt(@pdfio.int_array_of_string(key), str_bytes(text)))
  }
  inspect(rc4("Wiki", "pedia"), content="1021bf0420")
  inspect(
    rc4("Secret", "Attack at dawn"),
    content="45a01f645fc35b383552544b9bf5",
  )
}

///|
/// ARC4 key: 1..=32 bytes (PDF uses 5..=16).
priv struct Arc4Key(Array[Int]) derive(Debug)

///|
impl @quickcheck.Arbitrary for Arc4Key with fn arbitrary(size, rs) {
  let len = @quickcheck.int_range(1, 33).run(size, rs)
  Arc4Key(Array::makei(len, _ => rs.next_uint(limit=256).reinterpret_as_int()))
}

///|
impl @quickcheck.Shrink for Arc4Key

///|
test "prop: ARC4 is an involution and preserves length" {
  @quickcheck.check(
    (input : (Arc4Key, Payload)) => {
      let (Arc4Key(key), Payload(msg)) = input
      let enc = prims.crypt(key, msg)
      enc.length() == msg.length() && prims.crypt(key, enc) == msg
    },
    count=200,
    seed=0x4c4,
  )
}

///|
test "prop: ARC4 keystream does not depend on the plaintext" {
  // c = p XOR ks(key), so c XOR p must equal the encryption of all zeros.
  @quickcheck.check(
    (input : (Arc4Key, Payload)) => {
      let (Arc4Key(key), Payload(msg)) = input
      let enc = prims.crypt(key, msg)
      let ks = prims.crypt(key, Array::make(msg.length(), b'\x00'))
      Array::makei(msg.length(), i => enc[i] ^ msg[i]) == ks
    },
    count=200,
    seed=0x5eed,
  )
}

///|
/// Parameters for PDF Algorithm 1 (per-object key derivation).
priv struct ObjKeyParams {
  aes : Bool
  obj : Int
  gen : Int
  key : Array[Int]
  keylength : Int
} derive(Debug)

///|
impl @quickcheck.Arbitrary for ObjKeyParams with fn arbitrary(size, rs) {
  let keylength = @quickcheck.elements([40, 56, 64, 88, 96, 128]).run(size, rs)
  let key = Array::makei(keylength / 8, _ => {
    rs.next_uint(limit=256).reinterpret_as_int()
  })
  {
    aes: rs.next_uint(limit=2) == 1,
    obj: @quickcheck.int_range(0, 0x1000000).run(size, rs),
    gen: @quickcheck.int_range(0, 0x10000).run(size, rs),
    key,
    keylength,
  }
}

///|
impl @quickcheck.Shrink for ObjKeyParams

///|
test "prop: find_hash implements PDF Algorithm 1" {
  @quickcheck.check(
    (p : ObjKeyParams) => {
      let crypt_type : @pdfcryptprimitives.Encryption = if p.aes {
        AESV2
      } else {
        ARC4(p.keylength, 3)
      }
      let got = prims.find_hash(crypt_type, p.obj, p.gen, p.key, p.keylength)
      let input : Array[Int] = []
      input.append(p.key)
      input.append([
        p.obj & 0xff,
        (p.obj >> 8) & 0xff,
        (p.obj >> 16) & 0xff,
        p.gen & 0xff,
        (p.gen >> 8) & 0xff,
      ])
      if p.aes {
        input.append([0x73, 0x41, 0x6c, 0x54])
      }
      let digest = @pdfio.int_array_of_bytes(
        prims.md5(@pdfio.bytes_of_int_array(input)),
      )
      let n = if p.keylength / 8 + 5 > 16 { 16 } else { p.keylength / 8 + 5 }
      got == digest[:n].to_owned()
    },
    count=200,
    seed=0xa1,
  )
}

///|
test "prop: decrypt_stream_data(encrypt=false) inverts encrypt=true" {
  @quickcheck.check(
    (input : (ObjKeyParams, Payload, Int)) => {
      let (p, Payload(msg), mode) = input
      let (crypt_type, r, file_key) : (
        @pdfcryptprimitives.Encryption,
        Int,
        String?,
      ) = match mode.abs() % 4 {
        0 => (ARC4(p.keylength, 3), 3, None)
        1 => (AESV2, 4, None)
        2 =>
          (
            AESV3(false),
            5,
            Some(
              @pdfio.string_of_int_array(
                Array::makei(32, i => (i * 13 + p.obj) & 0xff),
              ),
            ),
          )
        _ =>
          (
            AESV3(true),
            6,
            Some(
              @pdfio.string_of_int_array(
                Array::makei(32, i => (i * 5 + p.gen) & 0xff),
              ),
            ),
          )
      }
      let run = (encrypt : Bool, data : Array[Byte]) => {
        prims.decrypt_stream_data(
          crypt_type,
          encrypt,
          file_key,
          p.obj,
          p.gen,
          p.key,
          p.keylength,
          r,
          data,
        )
      }
      run(false, run(true, msg)) == msg
    },
    count=200,
    seed=0xdec,
  )
}

///|
/// First 4 bytes (hex) of `MD5(pattern_msg(n))` for n = 0..=150, computed with
/// Python hashlib (independent reference implementation).
let ref_md5_prefix : Array[String] = [
  "d41d8cd9", "15f41a2e", "de69e493", "642856d5", "bf519a92", "7070762f", "a3d705fc",
  "5e554ff0", "a698f348", "209089a4", "af0bec20", "36e6bf5c", "93161f24", "d9bff12e",
  "96a80b67", "f843dd10", "47cb4eb4", "5b1307ef", "4a7df684", "d7846613", "31a157a6",
  "2e59e44d", "1146e2ff", "8ab46fc5", "59c4e994", "b99e9d4b", "db5d8f5f", "3a7ae8a2",
  "7b7f7093", "2599cd52", "0e9ab201", "baf5b7a1", "627703b0", "081eb8ad", "f55dfd15",
  "a13a2a11", "e050be9c", "01988c44", "e7d42a00", "b5e7c5ff", "04c498d7", "d36bd2a5",
  "1da106fb", "1fce2c9d", "b811431d", "53d09fe1", "9509f8fc", "30d2adee", "da675e73",
  "699416bb", "2849ed5d", "4aec8f2d", "060e86d3", "1a8c7d9a", "764aac0f", "735cdff4",
  "dc921697", "a8e1c6c7", "d868559c", "84ab756d", "ad1c859d", "ee17d51f", "b5d3e41c",
  "36534279", "36ae0004", "51233772", "91d3d7c5", "3684f2c0", "0da291f6", "149c1ffa",
  "382d50ad", "718b1ca2", "0e40a39f", "2a3b8b2a", "1112a53a", "fa51c7f7", "6d55974e",
  "ac0f3e47", "08d0f176", "728f41d1", "b923efcc", "57f0b09e", "c205b77d", "6b3d157f",
  "93a0686f", "25ff41cc", "581b72c3", "2ce4e1c1", "62aa1d36", "0cf18aef", "72a05a8d",
  "88cb3efc", "285d4845", "fc560930", "db3cd74c", "ba2452e0", "0156efff", "b00c5438",
  "3418cd39", "ab1c1053", "4b392c3f", "88ced407", "5f1df387", "8b5f1ce1", "36c7ec70",
  "3d9d3b2f", "af39e418", "74dc52e8", "ca971f1e", "ef2aeb17", "dc3d6da5", "cd81a048",
  "f4b3e347", "db9f085a", "2eeeee98", "15605721", "621c4c56", "b5b6e288", "6bc7ff89",
  "9fd910bc", "c88dcf59", "d2e14d18", "8fa374cb", "53f4e701", "64e8e4ce", "47e64f4e",
  "1f9d778d", "04ce700e", "8fa8ef0b", "c3faa41a", "468dd966", "2e3f7ca7", "7bc38663",
  "8d20a93b", "075a6af6", "83d44544", "6124dcbd", "8968f9c6", "99cd3a54", "41c23d20",
  "ed6e05b0", "06b8f346", "aac64ea3", "b37a4159", "7e2ff4eb", "be2194bb", "f78efa69",
  "214353a1", "1be2598d", "292384c1", "f96025ef",
]

///|
/// First 4 bytes (hex) of `SHA-256(pattern_msg(n))` for n = 0..=150, computed with
/// Python hashlib (independent reference implementation).
let ref_sha256_prefix : Array[String] = [
  "e3b0c442", "83891d7f", "4d0fdfad", "4f5864d5", "87ff99fb", "8e5b5d87", "90f2e221",
  "68687217", "415f2ec5", "8eb87f7b", "572c5870", "7add0f9b", "5188d77f", "14957c2b",
  "33e96b46", "965c1936", "75881a71", "b43faacc", "c28cb1e6", "60a23d83", "da848301",
  "149331b5", "a88cded0", "4fca5657", "01c068ab", "e9534296", "187f4179", "72e4711b",
  "a2ef44e2", "1882227c", "571452e8", "f39ceb39", "fa3cd0ac", "5df64905", "c6bc113f",
  "e088ab18", "d5165693", "19fec0e5", "f314486c", "e23ce9bc", "4a5dc7af", "043978ef",
  "c5e91bff", "02c4e5cf", "cfa1e7df", "d7dfee54", "b8336782", "e20958e4", "706d07c4",
  "61e19c63", "00fe302b", "2f395124", "2bc3804e", "3c8f492c", "8e7961c2", "75f106e1",
  "aa1cd1e8", "5d0db615", "1c681e45", "762f97d2", "91de9b4d", "43af9f3e", "f5743a1e",
  "d1aaaf84", "6aa9530a", "93b61d71", "fcdf9369", "812bf10f", "72c51585", "e366699e",
  "e094498c", "c354b6f1", "0225f9cd", "6756e785", "54a14b22", "ae8c8fea", "ea2eb06b",
  "56a8cfa9", "7f6a8a10", "795afdf8", "7326f720", "da661e4d", "104d8ffa", "df0a4988",
  "58cb3332", "71c30a00", "dda61b33", "b4c245c7", "febbc72f", "d05d47f6", "50ae45e5",
  "29950ab3", "9166a143", "d2883ef7", "c1dc570f", "936b2b42", "bd46de3d", "6a6d45c0",
  "fd270f0b", "d4120999", "ebe89d15", "d6cc20a1", "396dbd30", "793f0f10", "d9416c28",
  "38c41621", "b2c72e55", "c1886c66", "6ecb6b8c", "c600c48e", "fca6e4a5", "af192406",
  "ec0dc9c6", "31cc2be2", "bbeb39c6", "a24aa989", "b2490cbd", "959457e2", "0b6ab233",
  "619e06c1", "ee6c5435", "96c9833b", "84fb27e0", "1f93fb9d", "83b40d72", "f614816e",
  "15955c65", "6ed452ea", "1774d7a1", "048401af", "dce73e0f", "a6117130", "5ed30b67",
  "c3acafa4", "3c7d6521", "54bc7927", "7e50c196", "3f262b5e", "e31d97e7", "2fcd8acc",
  "f86456bb", "7c8e68dd", "173c4f1c", "2ae7bd76", "b4064a19", "5293a9c9", "f5ff168f",
  "bbf77267", "8aa7d9d0", "43415c07", "75f3cf72",
]

///|
/// First 4 bytes (hex) of `SHA-384(pattern_msg(n))` for n = 0..=150, computed with
/// Python hashlib (independent reference implementation).
let ref_sha384_prefix : Array[String] = [
  "38b060a7", "b55dc259", "b1e0b4bf", "ad84832a", "dfcfc012", "ac10ee42", "6161658e",
  "058b48a6", "47fd40b8", "202eace2", "c4c8e18a", "9631f8c2", "67ca104d", "e2af9d82",
  "e5ac820c", "d4a3d8d3", "8a482846", "3a46ae42", "112c774e", "4fd1482c", "cd15ecc2",
  "7cf0a212", "05ec17ee", "d17b905b", "fd2a9549", "3c6a6044", "5e9cf014", "d0afd790",
  "22c782b0", "f8012c44", "e506bea6", "fe144eed", "4581b227", "28f5c36a", "6f276402",
  "874765f7", "d95bbeff", "b584751a", "bbf63df0", "0f643a78", "fa76d1b8", "dd2cc40b",
  "c59bd1a6", "74b8bdb8", "b84fc987", "082d7736", "1d5e000e", "6bd2ddff", "4ea2e45b",
  "e3cd8ecd", "228a2f37", "ec5213f5", "e85317f4", "47a1ca43", "fe62bdd3", "6f7f0b47",
  "23bb059f", "2a2e049f", "4b67b9f6", "dc6666db", "d70a748d", "fe6d59c5", "2ebf88fd",
  "8709767a", "576c6f74", "c60521df", "5efc0dbb", "01ccea70", "a6b90473", "d7037a4e",
  "b687d02a", "86d10ea0", "c30b94aa", "30de8bf5", "3a0849cd", "cc388d05", "1cbb0881",
  "fb5c65db", "8c9e80f2", "6570b013", "372973e0", "c4c02d43", "c1d469ea", "7122c2f3",
  "fc66093c", "7b15b407", "f57e7603", "06075585", "215df2b8", "9b054fb7", "0a0b78e4",
  "ab0dcb7f", "33b57d0b", "82bac4e7", "2dba2ba4", "72de9480", "fbd92840", "050b5fbd",
  "759a9ebc", "cdcfe5ea", "568fb8e2", "6bcc57aa", "e40aff1c", "d45cbf25", "dfd706f5",
  "1941c3b5", "7929f428", "9d96c900", "e61bf50b", "eed42c33", "f9df7be6", "c99a99b2",
  "1f809a36", "021f0862", "361e08df", "c400b2b7", "0b53a100", "17e2226a", "0bdd2751",
  "90f5b8d3", "d2eb30b7", "d5d86c3e", "3d559d47", "d5856be3", "56dd35c4", "4e97a469",
  "2f2d2d75", "b1bf5c97", "35941606", "48cddab2", "c68bbac4", "acd70772", "38884cbc",
  "e4f7c4a8", "ec8aaa23", "2bdf36b9", "26243921", "676a3def", "35e07424", "4b57d95d",
  "89d9b071", "8463567e", "4dc71d85", "8f8f7b62", "dc61e6c8", "07c5505c", "e8ab8946",
  "5912d1d8", "b21b248b", "87033db3", "9ef2873b",
]

///|
/// First 4 bytes (hex) of `SHA-512(pattern_msg(n))` for n = 0..=150, computed with
/// Python hashlib (independent reference implementation).
let ref_sha512_prefix : Array[String] = [
  "cf83e135", "de9dac39", "70460fbf", "afe00ad5", "33966d7e", "47867215", "c7892c99",
  "5bfa9a43", "dbede7ad", "86dff41b", "4c10306d", "cd33b4a3", "7188106a", "543bf2ca",
  "aea2982e", "97915c7e", "e3e3cf23", "0d2c7913", "99331db5", "0f1e1c8f", "9abf45ec",
  "c0f196b5", "3f2c5c3b", "6be0cd74", "0ff4dc09", "0c2e12d9", "ca3cde6e", "6a78919c",
  "b031fbe9", "8af623a4", "18f8d2a6", "98a5c3c2", "a82a97d2", "b520c5e6", "02b405f1",
  "ce50cb1f", "772c263c", "d276be12", "c2a795cc", "ff0ad5a1", "2b770563", "e6c877a6",
  "9b925a3c", "ad3bf8fc", "03d702cf", "99688799", "6c73bf80", "5cbec550", "ae5ad174",
  "760999b3", "50046289", "2f2d53b6", "ef200b6f", "d3cb7231", "27dacfd2", "9f264908",
  "d08e56cf", "eb1913e3", "5992645f", "f686cc97", "607bf581", "a572031c", "b9aa6546",
  "0002f2b1", "608c29c4", "011a6338", "4f0bd851", "bc79afa5", "3398bfad", "6fda4311",
  "621de94e", "3972b3c0", "6a3217b1", "aa502df3", "6e154d2e", "9b7b656b", "9dd08e69",
  "96609a42", "c24f4c84", "c635806b", "57f01969", "17812c7d", "4865cf84", "a2cf7e05",
  "3b85994c", "8f40aa28", "7d36909e", "697bf4c8", "6a473803", "485416f6", "9803c6ed",
  "2471a53f", "a1278099", "bcfca1f5", "52e3573e", "1f062586", "05b889dd", "954224c3",
  "48d562c9", "3abab92c", "94d114a2", "1fa47827", "cc6fac81", "e6445bf8", "edaa481d",
  "014ec3c4", "0ec1f551", "0e5ae052", "ada2dc2c", "811536f3", "7658e21f", "d6c32f0c",
  "40bc91c6", "34363c48", "09989a96", "a7a48360", "3b8bff48", "7d57599f", "a61be6cb",
  "1ca116b1", "8058e33e", "8d3437ea", "e6b2c5d0", "d73553e3", "1c3ec4f4", "6401d34f",
  "37d1fd4a", "623672f3", "c3573f4e", "88d934b5", "4ac11d94", "c51e92e9", "f056a627",
  "be2c3e31", "3187ad9e", "82f37be9", "1c3364b7", "2c99c5b6", "21e25315", "7998d1c5",
  "734a2601", "a6b4807e", "185ceb3b", "c1b2d69d", "7dcfc565", "199a1a80", "d040189e",
  "cd69341b", "67d32e10", "c21ff282", "0501f90d",
]

///|
/// Last ciphertext block (hex) of AES-128-CBC/PKCS#7 of `pattern_msg(n)` for
/// n = 0..=48, computed with `openssl enc` (key 000102030405060708090a0b0c0d0e0f, IV `ref_iv`).
let ref_aes128_cbc_last_block : Array[String] = [
  "e315209ed0e7c94f74a65c99f6eadc1e", "90ea34c4fc4e4b0446bf944a0050b22b", "90410b5fd4b4425c62ea789a2f756ae6",
  "641bf2ce023383fdb5394b17a6a4f89d", "465313fd0cd4125c114b5e21faa8e305", "30e1fee83723eaf9a080996772c029b0",
  "04bc28adacfb23819c8e37a42ef2e883", "38f35ae25bffdd71313da1f111648f93", "c295c21899aac6368cdb2dfaf26bd4ab",
  "a75d50bed0d5f3d5914c76eb83f4e642", "77ddeee9abd988c2a685100cbaf9d64e", "d3445effd6c015642a45ba8f5b4778f8",
  "8f625631d56c9d698bce4e27180ae8d3", "6442667844cb65fd0b7fbaeb2133299c", "dec88a82f7bf1300f5fc700a484efadc",
  "cb3ef899320101f8fb4dd7ca9a503001", "78434ced2226fbc43b2adf07ceacff01", "944e861aa8ff29bb664385b48fc49ca5",
  "52c547672ced731aed9eda2a5d4e40d0", "7098e0957b4476a1fc105c3afbcba8e5", "3bdb581091a8ba348f43306a621d9501",
  "94647b8d6b42cc03e16b0cf62e717c6a", "69103532a452a58e4750b03276802a51", "e89d6e21f452699c7152f9b3b969557b",
  "400738ed0b9d6b7d5c7dc31ac3dc8c9c", "40924f21af5671df87c74f836b4709ba", "01e7e856ec1dcf0388c8914b5b696d4a",
  "a22b29cd0e74d7304baae50b21fd9649", "c1331fe5d70032aaac75e35150d2db87", "80658dfc5bcc60bb7fadf026176cc075",
  "39175b99f1440c3595cb288b5e857a27", "5994539d0b13625a2dc0f43fdc492995", "6da45514d34a31a64244f6fcfcf180f6",
  "af17496592cd28c2b1f31de374299ba0", "a0940811646e8de39d15c8c43da83099", "4cf919a70024885b7ab7ee0bc873207c",
  "da93f51fa723016a6b2a75b6d54e0677", "2808a3b9d0ed14d50b77cc2306758947", "4ed044f169d5f5a6ed0038e385c7deaf",
  "46458450f26c85d4111bf0db03d1b847", "069db808868c7f7b955b9a3a955bcfba", "4eded84131bee81e39df645efc21b2e6",
  "c546eab78b184ad770a6242936e0d2f0", "4828fba4817a9acb5094b776b1e30b39", "2cae809d1f13d11999743fc60c527812",
  "190b90dcfb2b4dcc603b581812c3c69c", "68bb3613b13865a79123d62c8549b1ee", "24efb33500033b77105fab47ab2d152a",
  "b6b1cfc1c504c56736a5535087cee43f",
]

///|
/// Last ciphertext block (hex) of AES-256-CBC/PKCS#7 of `pattern_msg(n)` for
/// n = 0..=48, computed with `openssl enc` (key 030a11181f262d343b424950575e656c737a81888f969da4abb2b9c0c7ced5dc, IV `ref_iv`).
let ref_aes256_cbc_last_block : Array[String] = [
  "a2aacdfab2a302d352e7284656e6dbca", "13f0f506bc166375fecda79fcca4da14", "9db63a7c715ecee5015fbd5657be3d43",
  "eed59e6195fc15a7b0c9d1e57d7ebe7d", "c2797aec1ed95d902c6cbac011b4a451", "3d449e46ed17278960612dd010ec343f",
  "6876747ff2b8c6ca5ed76321404db41a", "3f688b873f89b3de50b11fe4181496e3", "0fe0e0b8ca3796958f5c1a8d281bc817",
  "8ba303dc53e7f6a86596a16e85922f6b", "3d2f1f58f244defa3d94b245fbb2f219", "d8054973ad9a5eb48345a361655c10fe",
  "4bf5b71211b335e622d75e3a1bc06601", "79debc909ade392b2bc50884f27f19fe", "14b103849deb8a9ea438889bd036cac7",
  "6fe91ff9d89c43e5b3cb82403cc3b6e4", "4cad6cccfcb156dff590f54e7b004ec3", "b9dbad10234e74df4c7c209810dfb33d",
  "40794c0facbfb3faa715d5988c93ad92", "bc39938d2792dac61f980b0b72d80707", "d5f9d96a0197ba20590c0814b6034ff3",
  "b3a133e89517d4addaa69b56e2d2eae7", "ee27bcc64b2d02c00aac1700f801a64e", "dd8a65511c0d16e923d67c6c0c48e1a5",
  "972ebe4f8b6f3f6cb2fa5fb8a471563e", "1889214f2ce62bea671ea320060bec7e", "adbf65da0e9a5bbef8ecbe8f07b5522a",
  "c0c2b7d4a35a66191b8fd133e4ca21de", "485683594d9820f51c576f93760f3654", "d30b08beefedf60c7ea6e635d41bfbdd",
  "a02faa89a1d474a89260333ef7c85380", "796a2156eadfca34c131e6519c283ead", "ec5293ee4b23f532c13ceec79d97a7bf",
  "d736078080f359913203e4738ab600d1", "96120923f0fe496cfae7b4e40381c4cf", "685dbc31572c166b0a7554dc2ad9829f",
  "d5f980f3e8d6d72bc21ec73beade1579", "18d4dcbc2e2e5aeaf6224d277ea38986", "b343d83f6eadb1f82a91d3fbd89c5a37",
  "11dc6daf016d302d74ce15d430ed11c8", "bfcb73e177536e51126dd015b1f89568", "3e9b03c50e62394255065f92de731c5d",
  "7bacbc602ba061c60dfdba37dc22aa8b", "42933b28116da71265b5c95440006e82", "d0630b6c8c67c68271c7bbeb5c5ca7e7",
  "1ec7feda9c55c34c5d7f945b1c671c6c", "45c7a8f599431305347d62f5d5031f53", "e5f3b9c82fcca7c1d67d9e52a46261ce",
  "da41b9e4cfb702ea981dd86ad397c69c",
]
