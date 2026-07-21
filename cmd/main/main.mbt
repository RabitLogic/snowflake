///|
/// Demo: Snowflake ID generator.
/// Run with `moon run cmd/main` from the project root.
fn main {
  let node = match @snowflake.Node::new_default(1L) {
    Some(n) => n
    None => abort("failed to create node")
  }

  println("=== Snowflake ID Generator Demo ===")
  println("Node ID      : 1")
  println("Epoch        : \{@snowflake.default_epoch} (2024-09-01)")
  println("Node bits    : \{@snowflake.node_bits}")
  println("Step bits    : \{@snowflake.step_bits}")
  println("")

  println("── Generated IDs ──")
  for i = 0; i < 5; i = i + 1 {
    let id = node.generate()
    println("[\{i}] \{id}")
    println(
      "    time = \{id.time()}  node = \{id.node_id()}  step = \{id.step()}",
    )
    println("    base2 = \{id.to_base2()}")
    println("    base36= \{id.to_base36()}")
    println("    base58= \{id.to_base58()}")
    println("    base64= \{id.to_base64()}")
    println("")
  }

  println("── Encoding Round-Trips ──")
  let id = node.generate()
  println("Original       : \{id}")

  match @snowflake.Snowflake::from_string(id.to_string()) {
    Some(v) => println("string -> parse : \{v}")
    None => println("string -> parse : FAILED")
  }

  match @snowflake.Snowflake::from_base32(id.to_base32()) {
    Some(v) => println("base32 -> parse : \{v}  (was \{id.to_base32()})")
    None => println("base32 -> parse : FAILED")
  }

  match @snowflake.Snowflake::from_base58(id.to_base58()) {
    Some(v) => println("base58 -> parse : \{v}  (was \{id.to_base58()})")
    None => println("base58 -> parse : FAILED")
  }

  match @snowflake.Snowflake::from_int_bytes(id.to_int_bytes()) {
    Some(v) => println("int-bytes -> parse : \{v}")
    None => println("int-bytes -> parse : FAILED")
  }

  let nid = node.extract_node_id(id)
  let step = node.extract_step(id)
  let tm = node.extract_time(id)
  println("Node.extract: node=\{nid} step=\{step} time=\{tm}")
}
