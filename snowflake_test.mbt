///|
/// Blackbox tests for the snowflake ID generator.

// ─── Helpers ──────────────────────────────────────────────────────────

///|
/// Create a `Node` or abort.
fn node(id : Int64) -> Node {
  match Node::new_default(id) {
    Some(n) => n
    None => abort("node(\{id})")
  }
}

///|
/// Create a `Snowflake` from a raw `Int64`.
fn sf(v : Int64) -> Snowflake {
  Snowflake::new(v)
}

// ─── Node creation ───────────────────────────────────────────────────

///|
test "Node creation with valid node ID" {
  assert_true(Node::new_default(1L) is Some(_))
}

///|
test "Node creation with invalid node ID" {
  assert_true(Node::new_default(-1L) is None)
  assert_true(Node::new_default(2048L) is None)
}

///|
test "Node creation with custom epoch" {
  assert_true(Node::new(1L, 1704067200000L) is Some(_))
}

// ─── ID generation ────────────────────────────────────────────────────

///|
test "Generate unique IDs" {
  let n = node(1L)
  assert_true(n.generate() != n.generate())
}

///|
test "IDs are monotonically increasing" {
  let n = node(1L)
  let a = n.generate()
  let b = n.generate()
  let c = n.generate()
  assert_true(a < b && b < c)
}

///|
test "Different nodes produce different IDs" {
  assert_true(node(1L).generate() != node(2L).generate())
}

// ─── ID field extraction ──────────────────────────────────────────────

///|
test "Extract node from ID" {
  let id = node(42L).generate()
  assert_eq(id.node_id(), 42L)
}

///|
test "Extract step from sequential IDs" {
  let n = node(1L)
  let step1 = n.generate().step()
  let step2 = n.generate().step()
  assert_true(step2 >= step1)
}

// ─── String round-trips ───────────────────────────────────────────────

///|
test "Round-trip string conversion" {
  let id = node(1L).generate()
  let parsed = Snowflake::from_string(id.to_string())
  assert_eq(parsed, Some(id))
}

///|
test "Invalid string returns None" {
  assert_true(Snowflake::from_string("not-a-number") is None)
  assert_true(Snowflake::from_string("") is None)
}

///|
test "Base2 round-trip" {
  let id = node(1L).generate()
  let parsed = Snowflake::from_base2(id.to_base2())
  assert_eq(parsed, Some(id))
}

///|
test "Base32 round-trip" {
  let id = node(1L).generate()
  let parsed = Snowflake::from_base32(id.to_base32())
  assert_eq(parsed, Some(id))
}

///|
test "Base32 zero value" {
  let id = sf(0L)
  assert_eq(Snowflake::from_base32(id.to_base32()), Some(id))
}

///|
test "Base36 round-trip" {
  let id = node(1L).generate()
  let parsed = Snowflake::from_base36(id.to_base36())
  assert_eq(parsed, Some(id))
}

///|
test "Base58 round-trip" {
  let id = node(1L).generate()
  let parsed = Snowflake::from_base58(id.to_base58())
  assert_eq(parsed, Some(id))
}

///|
test "Base58 zero value" {
  let id = sf(0L)
  assert_eq(Snowflake::from_base58(id.to_base58()), Some(id))
}

///|
test "Base64 round-trip" {
  let id = node(1L).generate()
  let parsed = Snowflake::from_base64(id.to_base64())
  assert_eq(parsed, Some(id))
}

///|
test "Big-endian bytes round-trip" {
  let id = node(1L).generate()
  let parsed = Snowflake::from_int_bytes(id.to_int_bytes())
  assert_eq(parsed, Some(id))
}

///|
test "Bytes round-trip" {
  let id = node(1L).generate()
  let parsed = Snowflake::from_bytes(id.to_bytes())
  assert_eq(parsed, Some(id))
}

///|
test "Int64 round-trip" {
  let id = sf(1234567890123456789L)
  assert_eq(Snowflake::from_string(id.to_string()), Some(id))
}

///|
test "Known ID encoding" {
  let id = sf(0x00015F3C6D3A2B1EL)
  assert_eq(Snowflake::from_base36(id.to_base36()), Some(id))
}

// ─── Node-based extraction ────────────────────────────────────────────

///|
test "Node-based extraction with default bits" {
  let n = node(42L)
  let id = n.generate()
  assert_eq(n.extract_node_id(id), 42L)
  assert_true(n.extract_step(id) <= 4095L)
}

///|
test "Node-based extraction with custom bits" {
  let n = match Node::new(7L, default_epoch, nb=6, sb=16) {
    Some(x) => x
    None => abort("Node::new")
  }
  let id = n.generate()
  assert_eq(n.extract_node_id(id), 7L)
  assert_true(n.extract_step(id) >= 0L && n.extract_step(id) <= 65535L)
}

// ─── Custom bit widths ────────────────────────────────────────────────

///|
test "Custom node/step bits" {
  let n = match Node::new(1L, default_epoch, nb=6, sb=16) {
    Some(x) => x
    None => abort("Node::new")
  }
  assert_eq(n.node_max, 63L)
  assert_eq(n.step_mask, 65535L)
  assert_eq(n.time_shift, 22)
  assert_eq(n.node_shift, 16)
  let generated = n.generate()
  assert_true(generated > Snowflake::new(0L))
  assert_eq(generated.val & n.step_mask, 0L)
}

///|
test "Node bits + step bits > 22 returns None" {
  assert_true(Node::new(1L, default_epoch, nb=12, sb=12) is None)
}

///|
test "nb + sb == 22 is valid" {
  let n = match Node::new(1L, default_epoch, nb=10, sb=12) {
    Some(x) => x
    None => abort("should be valid")
  }
  assert_eq(n.time_shift, 22)
  assert_true(n.generate() > Snowflake::new(0L))
}

// ─── Boundary values ──────────────────────────────────────────────────

///|
test "Node ID 0 is valid" {
  assert_eq(node(0L).generate().node_id(), 0L)
}

///|
test "Node ID max (1023) is valid" {
  assert_eq(node(1023L).generate().node_id(), 1023L)
}

// ─── Conversion tests ─────────────────────────────────────────────────

///|
test "to_int64 round-trip" {
  let id = node(1L).generate()
  assert_eq(Snowflake::new(id.to_int64()), id)
}

// ─── Invalid input ────────────────────────────────────────────────────

///|
test "Invalid base32 returns None" {
  assert_true(Snowflake::from_base32("!!!invalid!!!") is None)
}

///|
test "Invalid base58 returns None" {
  assert_true(Snowflake::from_base58("0OIl") is None)
}

///|
test "Invalid base64 returns None" {
  assert_true(Snowflake::from_base64("!!!not-base64!!!") is None)
}

///|
test "Int bytes invalid length returns None" {
  assert_true(Snowflake::from_int_bytes([1, 2, 3]) is None)
  assert_true(Snowflake::from_int_bytes([1, 2, 3, 4, 5, 6, 7, 8, 9]) is None)
}

///|
test "Base32 overflow returns None" {
  assert_true(Snowflake::from_base32("zzzzzzzzzzzzz") is None)
}

///|
test "Base58 overflow returns None" {
  assert_true(Snowflake::from_base58("zzzzzzzzzzzzzzzzzzzz") is None)
}

///|
test "Empty strings return None" {
  assert_true(Snowflake::from_base32("") is None)
  assert_true(Snowflake::from_base58("") is None)
  assert_true(Snowflake::from_string("") is None)
  assert_true(Snowflake::from_base2("") is None)
}

// ─── Stress test ──────────────────────────────────────────────────────

///|
test "Generate 10 000 IDs without duplicates" {
  let n = node(1L)
  let seen = @hashset.HashSet([], capacity=10000)
  for i = 0; i < 10000; i = i + 1 {
    let id = n.generate()
    assert_true(!seen.contains(id), msg="duplicate at index \{i}")
    seen.add(id)
  }
}
