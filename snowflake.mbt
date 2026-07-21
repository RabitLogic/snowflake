///|
/// Snowflake ID generator for MoonBit.
///
/// The generated IDs are 64-bit integers with the following layout:
/// ```
/// 0 | 41 bits timestamp | 10 bits node | 12 bits sequence
/// ```

// ─── Defaults ─────────────────────────────────────────────────────────

///|
/// Default epoch: January 1, 2026 00:00:00 UTC (in milliseconds).
///
/// The 41-bit timestamp field provides ≈69 years of ID space.
///
///   2026-01-01 → ≈2095  ← IDs remain unique until roughly here
///
/// You can pick any epoch via `Node::new(node_id, your_epoch)` — for example:
///
/// | Epoch | Value (ms) | Expires | Use case |
/// |-------|-----------|---------|---------|
/// | 2026-01-01 | 1767225600000 | 2095-09 | default |
/// | 2025-01-01 | 1735689600000 | 2094-09 | alternative |
/// | 2010-11-04 (Twitter) | 1288834974657 | 2080-07 | interop |
pub let default_epoch : Int64 = 1767225600000L

///|
/// Number of bits allocated for the node ID.
pub let node_bits : Int = 10

///|
/// Number of bits allocated for the sequence number.
pub let step_bits : Int = 12

// ─── Snowflake type ───────────────────────────────────────────────────

///|
/// A snowflake ID — a 63-bit positive integer with embedded timestamp,
/// node ID, and sequence number.
pub struct Snowflake {
  val : Int64
} derive(Debug)

///|
/// Create a `Snowflake` from a raw `Int64`.
pub fn Snowflake::new(val : Int64) -> Self {
  { val, }
}

///|
/// Convert to a raw `Int64`.
pub fn Snowflake::to_int64(self : Self) -> Int64 {
  self.val
}

// ─── Eq / Compare for Snowflake ───────────────────────────────────────

///|
pub impl Eq for Snowflake with fn equal(self, other) {
  self.val == other.val
}

///|
pub impl Compare for Snowflake with fn compare(self, other) {
  self.val.compare(other.val)
}

///|
pub impl Hash for Snowflake with fn hash_combine(self, hasher) {
  self.val.hash_combine(hasher)
}

///|
pub impl Show for Snowflake with fn to_string(self) {
  self.val.to_string()
}

///|
/// Serialise as a JSON number string (e.g. `"67817059108864"`).
pub impl ToJson for Snowflake with fn to_json(self) {
  self.val.to_string().to_json()
}

///|
/// Deserialise from a JSON number string.
pub impl FromJson for Snowflake with fn from_json(json, path) {
  guard json is String(str) else {
    raise @json.JsonDecodeError::JsonDecodeError(
      (path, "snowflake: expected string"),
    )
  }
  let v = @string.parse_int64(str) catch {
    _ =>
      raise @json.JsonDecodeError::JsonDecodeError(
        (path, "snowflake: invalid number"),
      )
  }
  { val: v }
}

// ─── Snowflake encoding (instance methods) ───────────────────────────

///|
/// Return a binary (base‑2) string.
pub fn Snowflake::to_base2(self : Self) -> String {
  self.val.to_string(radix=2)
}

///|
/// Return a [z‑base‑32] string.
pub fn Snowflake::to_base32(self : Self) -> String {
  encode_base(self.val, 32L, base32_alphabet)
}

///|
/// Return a base‑36 string.
pub fn Snowflake::to_base36(self : Self) -> String {
  self.val.to_string(radix=36)
}

///|
/// Return a [Bitcoin Base‑58] string.
pub fn Snowflake::to_base58(self : Self) -> String {
  encode_base(self.val, 58L, base58_alphabet)
}

///|
/// Return a base‑64 string.
pub fn Snowflake::to_base64(self : Self) -> String {
  @base64.encode(@utf8.encode(self.val.to_string().view()).view())
}

///|
/// Return the decimal string as UTF‑8 bytes.
pub fn Snowflake::to_bytes(self : Self) -> Bytes {
  @utf8.encode(self.val.to_string().view())
}

///|
/// Return an 8‑byte big‑endian encoding.
pub fn Snowflake::to_int_bytes(self : Self) -> Bytes {
  self.val.reinterpret_as_uint64().to_be_bytes()
}

// ─── Snowflake field extraction (default layout) ─────────────────────

///|
/// Extract the Unix‑ms timestamp.  Uses the default 10‑bit node / 12‑bit step layout.
pub fn Snowflake::time(self : Self) -> Int64 {
  (self.val >> (node_bits + step_bits)) + default_epoch
}

///|
/// Extract the node/worker ID.  Uses the default 10‑bit node / 12‑bit step layout.
pub fn Snowflake::node_id(self : Self) -> Int64 {
  let n_max = -1L ^ (-1L << node_bits)
  (self.val & (n_max << step_bits)) >> step_bits
}

///|
/// Extract the sequence number.  Uses the default 12‑bit step layout.
pub fn Snowflake::step(self : Self) -> Int64 {
  self.val & (-1L ^ (-1L << step_bits))
}

// ─── Snowflake parsing (static methods) ──────────────────────────────

///|
/// Parse from a decimal string.
pub fn Snowflake::from_string(s : String) -> Self? {
  parse_opt(s, 10).map(fn(v) { { val: v } })
}

///|
/// Parse from a binary string.
pub fn Snowflake::from_base2(s : String) -> Self? {
  parse_opt(s, 2).map(fn(v) { { val: v } })
}

///|
/// Parse from a [z‑base‑32] string.
pub fn Snowflake::from_base32(s : String) -> Self? {
  parse_base_idx(s, 32L, base32_decode).map(fn(v) { { val: v } })
}

///|
/// Parse from a base‑36 string.
pub fn Snowflake::from_base36(s : String) -> Self? {
  parse_opt(s, 36).map(fn(v) { { val: v } })
}

///|
/// Parse from a [Bitcoin Base‑58] string.
pub fn Snowflake::from_base58(s : String) -> Self? {
  parse_base_idx(s, 58L, base58_decode).map(fn(v) { { val: v } })
}

///|
/// Parse from a base‑64 string.
pub fn Snowflake::from_base64(s : String) -> Self? {
  let decoded = try @base64.decode(s.view()) catch {
    _ => return None
  } noraise {
    b => b
  }
  Snowflake::from_string(@utf8.decode_lossy(decoded.view()))
}

///|
/// Parse from UTF‑8 bytes containing a decimal number.
pub fn Snowflake::from_bytes(bytes : Bytes) -> Self? {
  Snowflake::from_string(@utf8.decode_lossy(bytes.view()))
}

///|
/// Parse from an 8‑byte big‑endian byte array.
/// Returns `None` if `bytes` is not exactly 8 bytes.
pub fn Snowflake::from_int_bytes(bytes : Bytes) -> Self? {
  if bytes.length() != 8 {
    return None
  }
  let mut result = 0UL
  for i = 0; i < 8; i = i + 1 {
    result = (result << 8) | bytes[i].to_uint64()
  }
  Some({ val: result.reinterpret_as_int64() })
}

// ─── Node (generator) ─────────────────────────────────────────────────

///|
/// A generator that produces unique, time‑sorted `Snowflake` IDs.
pub struct Node {
  mut step : Int64
  mut last_time : Int64
  node : Int64
  epoch : Int64
  node_max : Int64
  node_mask : Int64
  step_mask : Int64
  time_shift : Int
  node_shift : Int
}

///|
/// Create a new `Node`.
///
/// Parameters:
/// - `node`    : Worker ID (0 … node_max).
/// - `epoch`   : Custom epoch in ms since Unix epoch.
/// - `nb`      : Bits for the node field (default 10).
/// - `sb`      : Bits for the sequence field (default 12).
///
/// Returns `None` if parameters are out of range.
pub fn Node::new(
  node : Int64,
  epoch : Int64,
  nb? : Int = node_bits,
  sb? : Int = step_bits,
) -> Self? {
  if nb + sb > 22 {
    return None
  }
  let n_max = -1L ^ (-1L << nb)
  if node < 0L || node > n_max {
    return None
  }
  Some({
    step: 0L,
    last_time: 0L,
    node,
    epoch,
    node_max: n_max,
    node_mask: n_max << sb,
    step_mask: -1L ^ (-1L << sb),
    time_shift: nb + sb,
    node_shift: sb,
  })
}

///|
/// Create a `Node` with the default epoch and default bit widths.
pub fn Node::new_default(node : Int64) -> Self? {
  Node::new(node, default_epoch)
}

///|
/// Generate a new unique `Snowflake`.
///
/// To guarantee uniqueness:
/// - Keep accurate system time.
/// - Never run multiple nodes with the same node ID.
pub fn Node::generate(self : Self) -> Snowflake {
  let now = @env.now().reinterpret_as_int64()
  let mut elapsed = now - self.epoch

  // ── Clock backward jump guard ────────────────────────────────────
  // If the system clock jumps backwards, `elapsed` will be less than
  // `self.last_time`.  In that case we wait until real time catches up
  // rather than reusing a past timestamp, which would risk duplicates.
  if elapsed < self.last_time {
    while elapsed < self.last_time {
      let n = @env.now().reinterpret_as_int64()
      elapsed = n - self.epoch
    }
    // Time has caught up — treat as a normal tick.
    self.step = 0L
  } else if elapsed == self.last_time {
    self.step = (self.step + 1L) & self.step_mask
    if self.step == 0L {
      while elapsed <= self.last_time {
        let n = @env.now().reinterpret_as_int64()
        elapsed = n - self.epoch
      }
    }
  } else {
    self.step = 0L
  }

  self.last_time = elapsed
  {
    val: (elapsed << self.time_shift) |
    (self.node << self.node_shift) |
    self.step,
  }
}

///|
/// Extract the Unix‑ms timestamp from a `Snowflake` using this node's
/// epoch and bit layout.
pub fn Node::extract_time(self : Self, id : Snowflake) -> Int64 {
  (id.val >> self.time_shift) + self.epoch
}

///|
/// Extract the node/worker ID from a `Snowflake` using this node's
/// bit layout.
pub fn Node::extract_node_id(self : Self, id : Snowflake) -> Int64 {
  (id.val & self.node_mask) >> self.node_shift
}

///|
/// Extract the sequence number from a `Snowflake` using this node's
/// bit layout.
pub fn Node::extract_step(self : Self, id : Snowflake) -> Int64 {
  id.val & self.step_mask
}

// ─── Internal helpers ─────────────────────────────────────────────────

///|
/// z-base-32 alphabet.
let base32_alphabet : String = "ybndrfg8ejkmcpqxot1uwisza345h769"

///|
/// Bitcoin Base‑58 alphabet.
let base58_alphabet : String = "123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ"

///|
/// Precomputed lookup: character codepoint → value (-1 = invalid).
let base32_decode : Array[Int] = {
  let table = Array::make(128, -1)
  for i = 0; i < base32_alphabet.char_length(); i = i + 1 {
    let c = base32_alphabet.get_char(i).unwrap()
    table[c.to_int()] = i
  }
  table
}

///|
/// Precomputed lookup: character codepoint → value (-1 = invalid).
let base58_decode : Array[Int] = {
  let table = Array::make(128, -1)
  for i = 0; i < base58_alphabet.char_length(); i = i + 1 {
    let c = base58_alphabet.get_char(i).unwrap()
    table[c.to_int()] = i
  }
  table
}

///|
/// Encode `n` in the given `base` with the supplied `alphabet`.
fn encode_base(n : Int64, base : Int64, alphabet : String) -> String {
  if n == 0L {
    alphabet.get_char(0).unwrap().to_string()
  } else {
    let mut m = n
    let mut len = 0
    let mut t = m
    while t > 0L {
      len = len + 1
      t /= base
    }
    let sb = StringBuilder()
    let buf : Array[Char] = Array::make(len, '\u{0}')
    while m > 0L {
      let idx = (m % base).to_int()
      len = len - 1
      buf[len] = alphabet.get_char(idx).unwrap()
      m /= base
    }
    for i = 0; i < buf.length(); i = i + 1 {
      sb.write_char(buf[i])
    }
    sb.to_string()
  }
}

///|
/// Parse a decimal/base2/base36 string via `@string.parse_int64`.
fn parse_opt(s : String, base : Int) -> Int64? {
  try @string.parse_int64(s, base~) catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
/// Parse a custom‑alphabet string (base32 / base58) using a lookup table.
fn parse_base_idx(s : String, base : Int64, table : Array[Int]) -> Int64? {
  if s.is_empty() {
    return None
  }
  let max_safe = if base == 32L {
    288230376151711743L
  } else {
    158526706883441459L
  }
  let mut id = 0L
  for ch in s {
    let code = ch.to_int()
    if code >= 128 {
      return None
    }
    let v = table[code]
    if v == -1 {
      return None
    }
    if id > max_safe {
      return None
    }
    id = id * base + v.to_int64()
  }
  Some(id)
}
