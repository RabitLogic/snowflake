///|
/// Whitebox tests: validate internal constants and invariants.
test "Node internal constants" {
  let node = match Node::new_default(1L) {
    Some(n) => n
    None => abort("failed to create node")
  }
  assert_eq(node.node_max, 1023L)
  assert_eq(node.step_mask, 4095L)
  assert_eq(node.time_shift, 22)
  assert_eq(node.node_shift, 12)
  assert_eq(node.node_mask, 1023L << 12)
}

///|
test "Custom bit widths via whitebox" {
  let node = match Node::new(1L, default_epoch, nb=8, sb=14) {
    Some(n) => n
    None => abort("failed to create node")
  }
  assert_eq(node.node_max, 255L)
  assert_eq(node.step_mask, 16383L)
  assert_eq(node.time_shift, 22)
  assert_eq(node.node_shift, 14)
}

///|
test "Multiple IDs in same millisecond increment step" {
  let node = match Node::new_default(1L) {
    Some(n) => n
    None => abort("failed to create node")
  }
  let id1 = node.generate()
  let id2 = node.generate()
  let id3 = node.generate()
  assert_true(id1 != id2 && id2 != id3 && id1 != id3)
}

///|
test "ID Eq and Compare" {
  let a = Snowflake::new(42L)
  let b = Snowflake::new(42L)
  let c = Snowflake::new(100L)
  assert_eq(a, b)
  assert_true(a != c)
  assert_true(a < c)
  assert_true(c > b)
}
