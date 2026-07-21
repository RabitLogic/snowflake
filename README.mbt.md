# RabitLogic/snowflake

A [Snowflake ID](https://en.wikipedia.org/wiki/Snowflake_ID) generator library for MoonBit.

## ID Structure

```
 0 | 41 bits timestamp | 10 bits node | 12 bits sequence
```

| Field       | Size  | Description                                         |
|-------------|-------|-----------------------------------------------------|
| Unused      | 1 bit | MSB, always 0 (ensures a positive Int64)            |
| Timestamp   | 41 bits | Milliseconds since a custom epoch (≈69 years)     |
| Node ID     | 10 bits | Worker/node identifier (0–1023)                   |
| Sequence    | 12 bits | Monotonic sequence within the same ms (0–4095)    |

> Customise bit allocation via `Node::new(node, epoch, nb=?, sb=?)` as long as `nb + sb ≤ 22`.

## Quick Start

```moonbit nocheck
///|
let node = Node::new_default(1L).unwrap()

///|
let id : Snowflake = node.generate()

///|
println(id)                  // 67817059108864
println(id.to_base36())      // 1w7p0bgwwb28
```

## API Reference

### Types

| Type | Description |
|------|-------------|
| `Node` | ID generator — call `.generate()` to produce IDs |
| `Snowflake` | A snowflake ID value — supports encoding, decoding, field extraction |

### Generator — `Node`

| Function | Description |
|----------|-------------|
| `Node::new(node, epoch, nb?, sb?)` | Custom epoch (`2026-01-01` default) & bit widths |
| `Node::new_default(node)` | Create with default epoch (`2026-01-01`) |
| `node.generate()` → `Snowflake` | Generate a new monotonically increasing ID |
| `node.extract_time(id)` → `Int64` | Extract timestamp using this node's epoch & layout |
| `node.extract_node_id(id)` → `Int64` | Extract node ID using this node's bit layout |
| `node.extract_step(id)` → `Int64` | Extract sequence using this node's bit layout |

> **Thread safety**: `Node` is **not** `Send`/`Sync`. Wrap in `Mutex(Node)` for shared access.

### ID value — `Snowflake`

**Construction**:

```moonbit nocheck
///|
let id = Snowflake::new(67817059108864L) // from raw Int64
```

**Field extraction** (uses default 10‑node / 12‑step layout):

| Method | Returns |
|--------|---------|
| `id.time()` | Unix‑ms timestamp (`Int64`) |
| `id.node_id()` | Node/worker ID (`Int64`) |
| `id.step()` | Sequence number (`Int64`) |

For custom bit widths, use `node.extract_*(id)` instead.

**Encoding** (instance methods):

| Format | Method |
|--------|--------|
| Binary (base‑2) | `id.to_base2()` |
| [z‑base‑32] | `id.to_base32()` |
| Base‑36 | `id.to_base36()` |
| [Bitcoin Base‑58] | `id.to_base58()` |
| Base‑64 | `id.to_base64()` |
| UTF‑8 bytes (decimal) | `id.to_bytes()` |
| Big‑endian 8‑bytes | `id.to_int_bytes()` |

**Parsing** (static methods, return `Snowflake?`):

| Format | Method |
|--------|--------|
| Decimal string | `Snowflake::from_string(s)` |
| Binary | `Snowflake::from_base2(s)` |
| z‑base‑32 | `Snowflake::from_base32(s)` |
| Base‑36 | `Snowflake::from_base36(s)` |
| Base‑58 | `Snowflake::from_base58(s)` |
| Base‑64 | `Snowflake::from_base64(s)` |
| UTF‑8 bytes | `Snowflake::from_bytes(b)` |
| 8‑byte big‑endian | `Snowflake::from_int_bytes(b)` |

**Conversions**:

```moonbit nocheck
///|
let raw : Int64 = id.to_int64()

///|
let id2 = Snowflake::new(raw)
```

**Traits**:

| Trait | Behaviour |
|-------|-----------|
| `Eq` / `Compare` | Compares by numeric value — supports `==`, `<`, `>`, etc. |
| `Hash` | Usable in `HashSet` / `HashMap` |
| `Show` | `\{id}` → decimal string |
| `ToJson` / `FromJson` | Serialises as JSON string (e.g. `"67817059108864"`) |

### Constants

```moonbit nocheck
///|
default_epoch  // 1767225600000L  (2026-01-01 00:00:00 UTC)

///|
node_bits      // 10

///|
step_bits      // 12
```

## Complete Example

```moonbit nocheck
///|
fn run {
  let node = Node::new_default(1L).unwrap()
  let id = node.generate()
  let id2 = node.generate()

  // Field extraction (default layout)
  println("\{id.time()} \{id.node_id()} \{id.step()}")

  // Field extraction (custom layout)
  println(
    "\{node.extract_time(id)} \{node.extract_node_id(id)} \{node.extract_step(id)}",
  )

  // Encoding
  println(id.to_base36())
  println(id.to_base58())

  // Parsing
  let parsed = Snowflake::from_base36(id.to_base36())
  println(parsed == Some(id)) // true

  // JSON serialisation
  let json_str = id.to_json().stringify()
  println(json_str) // "67817059108864"
}
```

## Production Guide

### Node ID management

Each `Node` must have a **unique node ID** (0–1023 for the default 10-bit layout).
If two `Node` instances share the same node ID and timestamp, they will produce
duplicate IDs. Strategies for assigning node IDs:

- **Static config**: assign a unique ID per process at deployment time.
- **Database sequence**: use an `AUTO_INCREMENT` column or Redis `INCR`.
- **Consensus**: use etcd or ZooKeeper for automatic allocation.

### Clock accuracy

The generator uses `@env.now()` (wall‑clock time). A backward NTP adjustment
**may** cause a brief stall while the clock catches up (the library waits for
time to recover). To minimise risk:

- Use `ntpd` or `chronyd` with `minpoll` no smaller than `6` (64 s).
- Avoid manual `date` commands or large step adjustments.
- Monitor system clock synchronisation in your observability pipeline.

> **Note**: Unlike libraries that use an OS monotonic clock, this library **will**
> pause briefly if the clock jumps backwards. This is a deliberate trade‑off for
> portability across all MoonBit targets (Wasm, JS, native).

### Thread safety

`Node` is **not** `Send`/`Sync`. For concurrent access, wrap it:

```moonbit nocheck
///|
let node = Mutex(Node::new_default(1L).unwrap())

///|
let id = node.lock().generate()
```

### Bit width planning

The default layout (10‑node / 12‑step) supports 1024 nodes × 4096 IDs/ms.
For different workloads, use `Node::new(…, nb=?, sb=?)`:

| `nb` | `sb` | Max nodes | Max IDs/ms | Use case              |
|------|------|-----------|------------|-----------------------|
| 10   | 12   | 1 024     | 4 096      | General purpose       |
| 7    | 15   | 128       | 32 768     | Many IDs, few nodes   |
| 13   | 9    | 8 192     | 512        | Many nodes, few IDs   |
| 6    | 16   | 64        | 65 536     | High‑throughput       |

### Epoch planning

The default epoch (2026-01-01) gives **~69 years** of ID space (until ≈ 2095).
If you need IDs beyond that, shift the epoch forward:

```moonbit nocheck
///|
let node = Node::new(1L, 1893456000000L).unwrap() // 2030-01-01
```

## Limitations

- **Clock monotonicity**: see [Clock accuracy](#clock-accuracy) above.
- **Max timestamp**: 41‑bit field + epoch (2026-01-01) → space lasts
  until **≈ 2095** (~69 years). Adjust the epoch to shift the window.

## Development

```bash
# Run all tests (40 tests)
moon test

# Update snapshots (if any)
moon test --update

# Run the demo
moon run cmd/main

# Check coverage
moon coverage analyze > uncovered.log
```

## Test Coverage

| Category                 | Tests |
|--------------------------|------:|
| Node creation            |     4 |
| ID generation            |     5 |
| Extraction (default)     |     3 |
| Extraction (Node-based)  |     2 |
| String / Base2 / Base36  |     4 |
| Base32 (z-base-32)       |     3 |
| Base58                   |     3 |
| Base64                   |     2 |
| Big-endian bytes         |     2 |
| Bytes (UTF-8)            |     1 |
| Stress (10k IDs)         |     1 |
| Boundary & edge cases    |     5 |
| Overflow & validation    |     4 |
| Custom bit widths        |     2 |
| **Total**                | **40** |

## License

Apache 2.0