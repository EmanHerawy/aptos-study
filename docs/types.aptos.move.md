# Types 
## Complete Move Type Hierarchy

Move's type system is carefully designed to ensure safety and resource management:


```
Move Type System
├── Primitive Types
│   ├── Built-in Types
│   │   ├── Integers: u8, u16, u32, u64, u128, u256 (UNSIGNED ONLY)
│   │   │   └── Abilities: copy, drop, store
│   │   ├── bool
│   │   │   └── Abilities: copy, drop, store
│   │   └── address
│   │       └── Abilities: copy, drop, store
│   │
│   └── Special Built-in Types
│       ├── signer
│       │   └── Abilities: drop (ONLY - no copy, no store, no key)
│       ├── vector<T>
│       │   └── Abilities: depends on T (never has key)
│       └── struct
│           ├── Resource Structs (has key)
│           │   ├── Can be stored in global storage
│           │   └── All fields must have store ability
│           ├── Value Structs (no key)
│           │   ├── Can have copy, drop, store
│           │   └── Cannot be stored as top-level resources
│           └── Phantom Structs
│               └── Type parameters not used in fields
│
├── Reference Types
│   ├── Immutable Reference &T
│   │   └── Abilities: copy, drop (NO store, NO key)
│   └── Mutable Reference &mut T
│       └── Abilities: copy, drop (NO store, NO key)
│
└── Generic Types
    ├── Type Parameters <T, U, V>
    ├── Constraints <T: copy + drop>
    ├── Phantom Parameters <phantom T>
    └── Conditional Abilities
```

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                            MOVE TYPE SYSTEM HIERARCHY                              │
└─────────────────────────────────────────────────────────────────────────────────────┘
                                        │
                        ┌───────────────┼───────────────┐
                        │               │               │
                        ▼               ▼               ▼
            ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
            │ Built-in Types  │ │Special Built-in │ │   REFERENCE     │
            │                 │ │    TYPES        │ │     TYPES       │
            └─────────────────┘ └─────────────────┘ └─────────────────┘
                     │                   │                   │
        ┌────────────┼────────────┐     │          ┌────────┼────────┐
        │            │            │     │          │                 │
        ▼            ▼            ▼     ▼          ▼                 ▼
┌──────────┐ ┌──────────┐ ┌──────────┐ │  ┌──────────────┐ ┌──────────────┐
│ NUMERIC  │ │ BOOLEAN  │ │ ADDRESS  │ │  │ IMMUTABLE    │ │   MUTABLE    │
│          │ │          │ │          │ │  │ REFERENCE    │ │  REFERENCE   │
│ u8, u16  │ │   bool   │ │ address  │ │  │     &T       │ │    &mut T    │
│ u32, u64 │ │          │ │          │ │  └──────────────┘ └──────────────┘
│u128,u256 │ │          │ │          │ │
└──────────┘ └──────────┘ └──────────┘ │
                                        │
                        ┌───────────────┼───────────────┐
                        │               │               │
                        ▼               ▼               ▼
            ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
            │    VECTORS      │ │    STRUCTS      │ │    GENERICS     │
            │                 │ │                 │ │                 │
            │  vector<T>      │ │  struct Name    │ │  Container<T>   │
            │                 │ │  { fields }     │ │  Option<T>      │
            └─────────────────┘ └─────────────────┘ └─────────────────┘
```

DETAILED TYPE CHARACTERISTICS:
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              PRIMITIVE TYPES                                       │
├─────────────┬─────────────┬─────────────┬─────────────┬────────────────────────────┤
│    TYPE     │    SIZE     │  ABILITIES  │   RANGE     │         USAGE              │
├─────────────┼─────────────┼─────────────┼─────────────┼────────────────────────────┤
│     u8      │   1 byte    │copy,drop,   │   0-255     │Small counters, flags       │
│             │             │store        │             │                            │
├─────────────┼─────────────┼─────────────┼─────────────┼────────────────────────────┤
│    u16      │   2 bytes   │copy,drop,   │  0-65535    │Medium numbers, IDs         │
│             │             │store        │             │                            │
├─────────────┼─────────────┼─────────────┼─────────────┼────────────────────────────┤
│    u32      │   4 bytes   │copy,drop,   │    0-4B     │Large numbers, timestamps   │
│             │             │store        │             │                            │
├─────────────┼─────────────┼─────────────┼─────────────┼────────────────────────────┤
│    u64      │   8 bytes   │copy,drop,   │   0-18Q     │Token amounts, prices       │
│             │             │store        │             │                            │
├─────────────┼─────────────┼─────────────┼─────────────┼────────────────────────────┤
│   u128      │  16 bytes   │copy,drop,   │    0-340U   │Very large numbers          │
│             │             │store        │             │                            │
├─────────────┼─────────────┼─────────────┼─────────────┼────────────────────────────┤
│   u256      │  32 bytes   │copy,drop,   │ 0-115Q...   │Cryptographic operations    │
│             │             │store        │             │                            │
├─────────────┼─────────────┼─────────────┼─────────────┼────────────────────────────┤
│    bool     │   1 byte    │copy,drop,   │ true/false  │Flags, conditions           │
│             │             │store        │             │                            │
├─────────────┼─────────────┼─────────────┼─────────────┼────────────────────────────┤
│  address    │  32 bytes   │copy,drop,   │ 0x0-0xFF... │Account addresses           │
│             │             │store        │             │                            │
├─────────────┼─────────────┼─────────────┼─────────────┼────────────────────────────┤
│   signer    │  32 bytes   │   drop      │  N/A        │Transaction authorization   │
│             │             │(no copy,    │             │                            │
│             │             │no store)    │             │                            │
└─────────────┴─────────────┴─────────────┴─────────────┴────────────────────────────┘

REFERENCE TYPE DETAILS:
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              REFERENCE TYPES                                       │
├─────────────────┬─────────────────┬─────────────────┬─────────────────────────────┤
│      TYPE       │    ABILITIES    │   OPERATIONS    │            NOTES            │
├─────────────────┼─────────────────┼─────────────────┼─────────────────────────────┤
│       &T        │   copy, drop    │   Read only     │Cannot modify referenced     │
│  (immutable)    │  (no store)     │   Dereference   │value. Can be copied.        │
├─────────────────┼─────────────────┼─────────────────┼─────────────────────────────┤
│     &mut T      │   copy, drop    │   Read/Write    │Can modify referenced value. │
│   (mutable)     │  (no store)     │   Dereference   │Cannot be stored globally.   │
├─────────────────┼─────────────────┼─────────────────┼─────────────────────────────┤
│  Global Refs    │       N/A       │ Cannot return   │Function cannot return       │
│                 │                 │ from functions  │global storage references    │
└─────────────────┴─────────────────┴─────────────────┴─────────────────────────────┘
```


### Detailed Type Breakdown

#### 1. Primitive Types - Built-in

The fundamental types built into the Move language:

**Integers (u8, u16, u32, u64, u128, u256) - Unsigned Only**
```
Integer Type Details:
┌─────────┬─────────────┬───────────────────────────────────┐
│ Type    │ Size (bits) │ Range                             │
├─────────┼─────────────┼───────────────────────────────────┤
│ u8      │ 8           │ 0 to 255                          │
│ u16     │ 16          │ 0 to 65,535                       │
│ u32     │ 32          │ 0 to 4,294,967,295                │
│ u64     │ 64          │ 0 to 18,446,744,073,709,551,615   │
│ u128    │ 128         │ 0 to 2^128 - 1                    │
│ u256    │ 256         │ 0 to 2^256 - 1                    │
└─────────┴─────────────┴───────────────────────────────────┘

❌ NOTE: Move does NOT support signed integers (i8, i16, i32, etc.)
✅ Only unsigned integers are available
❌ NOTE: Move does not support overflow/underflow; an operation that results in a value outside the range of the type will raise a runtime error
❌ nteger types of one size can be cast to integer types of another size. Casting aborts if the result is too large for the specified type

Operations:
• Arithmetic: +, -, *, /, %
• Comparison: <, >, <=, >=, ==, !=
• Bitwise: &, |, ^, <<, >>
• Casting: as (between integer types)
• Abilities: copy, drop, store
```


Boolean Type:
• Values: true, false
• Operations: &&, ||, !, ==, !=
• Abilities: copy, drop, store
• Common in conditional expressions and assertions
```

**Address**
```
Address Type:
• Size: 32 bytes (256 bits)
• Format: 0x followed by 64 hex characters
• Examples: @0x1, @0x42, @std
• Used to identify accounts and modules
• Abilities: copy, drop, store
```


#### 2. Primitive Types - Special Built-in

**Signer**
```
Signer Type:
┌─────────────────────────────────────────────────────────────┐
│ struct signer has drop {                                    │
│     a: address  // Conceptual representation               │
│ }                                                           │
│                                                             │
│ Key Properties:                                             │
│ • Cannot be created by user code                           │
│ • Only created by Move VM                                  │
│ • Represents transaction sender authority                   │
│ • Only has 'drop' ability (no copy, store, key)           │
│ • Used for authentication and authorization                 │
│                                                             │
│ Usage:                                                      │
│ public fun transfer(from: &signer, to: address, amt: u64) {│
│   let from_addr = signer::address_of(from);                │
│   // Only 'from' can authorize this operation              │
│ }                                                           │
└─────────────────────────────────────────────────────────────┘
```

**Vector<T>**
vector<T> is the only primitive collection type provided by Move. A vector<T> is a homogenous collection of T's that can grow or shrink by pushing/popping values off the "end".

```
Vector Type:
┌─────────────────────────────────────────────────────────────┐
│ Vector<T> - Dynamic array of elements of type T            │
│                                                             │
│ Abilities: Conditional on T                                 │
│ • copy if T has copy                                       │
│ • drop if T has drop                                       │
│ • store if T has store                                     │
│ • Never has key ability                                    │
│                                                             │
│ Common Operations:                                          │
│ • vector::empty<T>() - create empty vector                 │
│ • vector::push_back(&mut v, item) - add element            │
│ • vector::pop_back(&mut v) - remove last element           │
│ • vector::length(&v) - get size                            │
│ • vector::borrow(&v, i) - get reference to element         │
│                                                             │
│ Special Case: vector<u8>                                    │
│ • Represents byte arrays                                   │
│ • Can be written as literals: b"hello"                     │
│ • Used for strings and binary data                         │
└─────────────────────────────────────────────────────────────┘
```

**Struct**
Structs are by default linear and ephemeral. This means they cannot be copied or dropped.

```
Struct Types:
┌─────────────────────────────────────────────────────────────┐
│ User-defined compound data types                            │
│                                                             │
│ Resource Structs (has key):                                 │
│ struct Account has key {                                    │
│   balance: u64,                                            │
│   sequence_number: u64,                                    │
│ }                                                           │
│ • Can be stored in global storage                          │
│ • All fields must have 'store' ability                     │
│ • Unique per address per type                              │
│                                                             │
│ Value Structs (no key):                                     │
│ struct Point has copy, drop, store {                       │
│   x: u64,                                                  │
│   y: u64,                                                  │
│ }                                                           │
│ • Cannot be top-level resources                            │
│ • Can be stored inside other structs                       │
│ • More flexible ability combinations                        │
│                                                             │
│ Phantom Structs:                                            │
│ struct Currency<phantom CoinType> has store {              │
│   value: u64,                                              │
│ }                                                           │
│ • Type parameters not used in fields                       │
│ • Enable type-safe programming patterns                    │
└─────────────────────────────────────────────────────────────┘
```

#### 3. Reference Types

**Immutable References (&T)**
```
Read-Only References:
┌─────────────────────────────────────────────────────────────┐
│ &T - Immutable reference to value of type T                │
│                                                             │
│ Properties:                                                 │
│ • Can read but not modify referenced value                 │
│ • Multiple immutable references allowed                    │
│ • Abilities: copy, drop (no store - can't persist)        │
│                                                             │
│ Creation:                                                   │
│ let x = 10;                                                │
│ let x_ref = &x;        // Immutable reference              │
│ let y = *x_ref;        // Dereference (copy value)         │
│                                                             │
│ Global Storage:                                             │
│ let account_ref = borrow_global<Account>(address);         │
│ let balance = account_ref.balance;  // Read field          │
└─────────────────────────────────────────────────────────────┘
```

**Mutable References (&mut T)**
```
Read-Write References:
┌─────────────────────────────────────────────────────────────┐
│ &mut T - Mutable reference to value of type T              │
│                                                             │
│ Properties:                                                 │
│ • Can read and modify referenced value                     │
│ • Only one mutable reference allowed at a time            │
│ • Abilities: copy, drop (no store - can't persist)        │
│                                                             │
│ Creation:                                                   │
│ let mut x = 10;                                            │
│ let x_ref = &mut x;    // Mutable reference                │
│ *x_ref = 20;           // Modify through reference         │
│                                                             │
│ Global Storage:                                             │
│ let account_ref = borrow_global_mut<Account>(address);     │
│ account_ref.balance = account_ref.balance + 100;          │
│                                                             │
│ Exclusive Access:                                           │
│ // This would be an error:                                 │
│ // let ref1 = &mut x;                                      │
│ // let ref2 = &mut x;  // ERROR: Cannot have two &mut     │
└─────────────────────────────────────────────────────────────┘
```
### Reference Rules
- You can have multiple immutable references OR one mutable reference
- References cannot outlive the data they reference
- References cannot appear in global storage, hence they do not have store
#### 4. Generic Types

**Type Parameters**
```
Generic Programming:
┌─────────────────────────────────────────────────────────────┐
│ struct Container<T> {                                       │
│   data: T                                                  │
│ }                                                           │
│                                                             │
│ fun store_value<T: store>(account: &signer, value: T) {    │
│   move_to<Container<T>>(account, Container { data: value });│
│ }                                                           │
│                                                             │
│ Type Parameter Constraints:                                 │
│ • T: copy - T must have copy ability                       │
│ • T: drop - T must have drop ability                       │
│ • T: store - T must have store ability                     │
│ • T: key - T must have key ability                         │
│ • T: copy + drop + store - Multiple constraints            │
│                                                             │
│ Phantom Parameters:                                         │
│ struct TypedId<phantom T> has copy, drop, store {          │
│   id: u64                                                  │
│ }                                                           │
│ • T doesn't appear in struct body                          │
│ • Used for type-level distinctions                         │
│ • Doesn't affect ability derivation                        │
└─────────────────────────────────────────────────────────────┘
```

---

## Types and Abilities

Abilities are Move's permission system that controls what operations can be performed on types:

### Four Core Abilities

```
Ability System Architecture:
┌─────────────────────────────────────────────────────────────┐
│                        ABILITIES                            │
├─────────────┬─────────────┬─────────────┬─────────────────────┤
│    COPY     │    DROP     │    STORE    │        KEY          │
│             │             │             │                     │
│ Allows      │ Allows      │ Allows      │ Allows type to      │
│ copying     │ ignoring/   │ storage in  │ serve as key for    │
│ values      │ destroying  │ other       │ global storage      │
│             │ values      │ structs     │ operations          │
│             │             │             │                     │
│ Operations: │ Operations: │ Operations: │ Operations:         │
│ • copy x    │ • let _ = x │ • Field in  │ • move_to<T>()      │
│ • *&x       │ • Scope end │   struct    │ • borrow_global<T>()│
│             │ • Function  │ • Store in  │ • exists<T>()       │
│             │   param     │   vector    │ • move_from<T>()    │
│             │   ignore    │             │                     │
└─────────────┴─────────────┴─────────────┴─────────────────────┘
```
## **Ability System Deep Dive**

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           MOVE ABILITY SYSTEM                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│     KEY     │    │    STORE    │    │    COPY     │    │    DROP     │
│   ABILITY   │    │   ABILITY   │    │   ABILITY   │    │   ABILITY   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
      │                    │                    │                    │
      ▼                    ▼                    ▼                    ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│Global Storage│    │  Can be     │    │ Can be      │    │ Can be      │
│Operations:   │    │  nested in  │    │ duplicated  │    │ discarded   │
│• move_to     │    │  other      │    │ with copy   │    │ (go out of  │
│• move_from   │    │  structs    │    │ operator    │    │ scope)      │
│• borrow_*    │    │             │    │             │    │             │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘

ABILITY INTERACTION MATRIX:
┌─────────────────────────────────────────────────────────────────────────────────────┐
│           │    KEY    │   STORE   │   COPY    │   DROP    │      RESULT             │
├─────────────────────────────────────────────────────────────────────────────────────┤
│    ✓      │     ✓     │     -     │     -     │     -     │ Global Resource         │
│           │           │           │           │           │ (cannot copy/drop)      │
├─────────────────────────────────────────────────────────────────────────────────────┤
│    ✓      │     ✓     │     ✓     │     -     │     -     │ Transferable Resource   │
│           │           │           │           │           │ (stored in global)      │
├─────────────────────────────────────────────────────────────────────────────────────┤
│    -      │     -     │     ✓     │     ✓     │     ✓     │ Data Structure          │
│           │           │           │           │           │ (copyable, droppable)   │
├─────────────────────────────────────────────────────────────────────────────────────┤
│    -      │     -     │     ✓     │     -     │     ✓     │ Nested Data             │
│           │           │           │           │           │ (can store, can drop)   │
├─────────────────────────────────────────────────────────────────────────────────────┤
│    -      │     -     │     -     │     -     │     -     │ Linear Type             │
│           │           │           │           │           │ (must be consumed)      │
└─────────────────────────────────────────────────────────────────────────────────────┘


PRACTICAL ABILITY COMBINATIONS:
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           COMMON PATTERNS                                          │
├─────────────────────┬─────────────────┬─────────────────────────────────────────────┤
│      PATTERN        │    ABILITIES    │               PURPOSE                       │
├─────────────────────┼─────────────────┼─────────────────────────────────────────────┤
│ Digital Asset       │   key, store    │ Coins, NFTs - cannot copy/drop            │
├─────────────────────┼─────────────────┼─────────────────────────────────────────────┤
│ User Account        │      key        │ User profiles, game accounts               │
├─────────────────────┼─────────────────┼─────────────────────────────────────────────┤
│ Configuration       │ key, copy, drop │ Settings that can be copied                │
├─────────────────────┼─────────────────┼─────────────────────────────────────────────┤
│ Nested Data         │ store, copy,    │ Data stored inside resources               │
│                     │ drop            │                                             │
├─────────────────────┼─────────────────┼─────────────────────────────────────────────┤
│ Capability Token    │ key, store,     │ Admin capabilities that can be transferred │
│                     │ drop            │                                             │
├─────────────────────┼─────────────────┼─────────────────────────────────────────────┤
│ Temporary Object    │ drop            │ Computation results, temporary data        │
└─────────────────────┴─────────────────┴─────────────────────────────────────────────┘
```

### Ability Inheritance Rules

```

ABILITY PROPAGATION RULES:
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ RULE 1: If a value has COPY, all contained values must have COPY                   │
│ RULE 2: If a value has DROP, all contained values must have DROP                   │
│ RULE 3: If a value has STORE, all contained values must have STORE                 │
│ RULE 4: If a value has KEY, all contained values must have STORE (asymmetric!)    │
└─────────────────────────────────────────────────────────────────────────────────────┘

CONDITIONAL ABILITIES WITH GENERICS:
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ struct Container<T> has copy, drop, store {                                        │
│     item: T                                                                         │
│ }                                                                                   │
│                                                                                     │
│ RESULT:                                                                             │
│ • Container<u64> HAS copy, drop, store (u64 has these abilities)                  │
│ • Container<signer> HAS drop ONLY (signer lacks copy, store)                      │
│ • Container<Resource> may have different abilities based on Resource definition    │
└─────────────────────────────────────────────────────────────────────────────────────┘

Key Ability Special Rule:
┌─────────────────────────────────────────────────────────────┐
│ If struct has KEY → all fields must have STORE             │
│ This is the ONLY asymmetric ability rule                   │
│                                                             │
│ Example:                                                    │
│ struct Resource has key {                                   │
│     data: SomeStruct  // Must have 'store'                 │
│ }                                                           │
└─────────────────────────────────────────────────────────────┘
```


---

## Understanding "Finite Types" in Generic Recursion

Move prevents infinite type generation through strict recursion controls:

### The Problem

When used in combination with generic structs, recursive functions could create an infinite number of types in certain cases, adding unnecessary complexity to the compiler, VM and other language components.

### The Key Insight: Type Parameter vs Type Generation

The crucial difference is between **reusing the same type parameter** vs **generating new type combinations**.

### Example 1: Finite Types ✅
```move
fun foo<T>() { 
    foo<T>(); 
}
```

**Call Chain Analysis:**
```
foo<u64>() → foo<u64>() → foo<u64>() → foo<u64>() → ...
```

**Number of distinct types created:** **1** (just `u64`)

Even though the function calls itself recursively forever, it always uses the **same concrete type** that was originally passed in. If you call `foo<u64>()`, every recursive call is also `foo<u64>()`.

### Example 2: Finite Types ✅ 
```move
struct Container<T> {}

fun foo<T>() { 
    foo<Container<u64>>(); 
}
```

**Call Chain Analysis:**
```
foo<SomeType>() → foo<Container<u64>>() → foo<Container<u64>>() → ...
```

**Number of distinct types created:** **2** (`SomeType` and `Container<u64>`)

The recursion "converges" to always calling `foo<Container<u64>>()`, so we only ever create a finite number of type instantiations.

### Example 3: Infinite Types ❌
```move
struct Container<T> {}

fun foo<T>() { 
    foo<Container<T>>(); 
}
```

**Call Chain Analysis:**
```
foo<u64>() → foo<Container<u64>>() → foo<Container<Container<u64>>>() → foo<Container<Container<Container<u64>>>>() → ...
```

**Number of distinct types created:** **∞** (infinite!)

Each recursive call creates a new, more complex type by wrapping the previous type in another `Container`.


### Finite vs Infinite Type Examples

```
✅ ALLOWED - Finite Types:
┌─────────────────────────────────────────────────────────────┐
│ struct A<T> {}                                              │
│                                                             │
│ // Same type repeatedly - finite                            │
│ fun foo<T>() {                                              │
│     foo<T>();  // T → T → T → ... (always same T)          │
│ }                                                           │
│                                                             │
│ // Fixed concrete type - finite                             │
│ fun bar<T>() {                                              │
│     bar<A<u64>>();  // T → A<u64> → A<u64> → ...           │
│ }                                                           │
└─────────────────────────────────────────────────────────────┘

❌ FORBIDDEN - Infinite Types:
┌─────────────────────────────────────────────────────────────┐
│ struct A<T> {}                                              │
│                                                             │
│ // Growing type nesting - infinite                          │
│ fun baz<T>() {                                              │
│     baz<A<T>>();  // T → A<T> → A<A<T>> → A<A<A<T>>> → ... │
│ }                                                           │
│                                                             │
│ // Cross-module infinite recursion                          │
│ fun recursive1<T>() { recursive2<A<T>>() }                  │
│ fun recursive2<T>() { recursive1<B<T>>() }                  │
└─────────────────────────────────────────────────────────────┘
```

### Analysis Method

The check for type level recursions is based on a conservative analysis on the call sites and does NOT take control flow or runtime values into account.

```
Conservative Analysis Example:
┌─────────────────────────────────────────────────────────────┐
│ // This technically creates finite types at runtime         │
│ // but is still FORBIDDEN by Move's type system            │
│ fun conditional_recursion<T>(n: u64) {                     │
│     if (n > 0) {                                           │
│         conditional_recursion<A<T>>(n - 1);                │
│     }                                                      │
│ }                                                          │
│                                                             │
│ // Compiler cannot prove termination statically            │
│ // → Conservative rejection                                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Phantom Types in Depth

Phantom type parameters solve the problem of spurious ability annotations. Unused type parameters can be marked as phantom type parameters, which do not participate in the ability derivation for structs.

### Phantom Type Declaration

```
Phantom Type Syntax:
┌─────────────────────────────────────────────────────────────┐
│ struct Currency<phantom CoinType> has store {               │
│     value: u64  // CoinType doesn't appear here            │
│ }                                                           │
│                                                             │
│ // Usage examples:                                          │
│ struct USD {}                                               │
│ struct EUR {}                                               │
│                                                             │
│ let dollars: Currency<USD> = Currency { value: 100 };      │
│ let euros: Currency<EUR> = Currency { value: 80 };         │
│                                                             │
│ // These are different types despite same structure!        │
└─────────────────────────────────────────────────────────────┘
```

### Phantom Type Benefits

```
Type Safety Through Phantom Types:
┌─────────────────────────────────────────────────────────────┐
│                    WITHOUT PHANTOM TYPES                    │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ struct Currency has store { value: u64 }               │ │
│ │                                                         │ │
│ │ fun transfer_usd(c: Currency): Currency { c }  ❌       │ │
│ │ fun transfer_eur(c: Currency): Currency { c }  ❌       │ │
│ │                                                         │ │
│ │ // Can accidentally mix USD and EUR!                   │ │
│ │ let euros = transfer_usd(eur_currency);                │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│                     WITH PHANTOM TYPES                      │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ struct Currency<phantom T> has store { value: u64 }    │ │
│ │                                                         │ │
│ │ fun transfer_usd(c: Currency<USD>): Currency<USD>  ✅   │ │
│ │ fun transfer_eur(c: Currency<EUR>): Currency<EUR>  ✅   │ │
│ │                                                         │ │
│ │ // Compiler prevents mixing types!                     │ │
│ │ let euros = transfer_usd(eur_currency);  // ERROR!     │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Phantom Type Ability Derivation

When instantiating a struct, the arguments to phantom parameters are excluded when deriving the struct abilities.

```
Phantom Ability Example:
┌─────────────────────────────────────────────────────────────┐
│ struct S<T1, phantom T2> has copy { f: T1 }                │
│ struct NoCopy {}                                            │
│ struct HasCopy has copy {}                                  │
│                                                             │
│ // Ability derivation:                                      │
│ S<HasCopy, NoCopy>  → has copy ✅                           │
│ S<NoCopy, HasCopy>  → no copy ❌                            │
│                                                             │
│ // T2 (phantom) doesn't affect abilities                   │
│ // Only T1 (regular) affects abilities                     │
└─────────────────────────────────────────────────────────────┘
```

### Phantom Constraints

Phantom parameters can be declared with ability constraints. When instantiating a phantom type parameter with an ability constraint, the type argument has to satisfy that constraint, even though the parameter is phantom.

```
Phantom Constraints Example:
┌─────────────────────────────────────────────────────────────┐
│ struct Constrained<phantom T: copy> has store {             │
│     data: u64                                               │
│ }                                                           │
│                                                             │
│ struct CanCopy has copy {}                                  │
│ struct CannotCopy {}                                        │
│                                                             │
│ let valid: Constrained<CanCopy> = ...;     ✅              │
│ let invalid: Constrained<CannotCopy> = ...; ❌             │
│                                                             │
│ // T must satisfy 'copy' even though it's phantom          │
└─────────────────────────────────────────────────────────────┘
```

## **Phantom Types vs Regular Generics**

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                    PHANTOM vs REGULAR TYPE PARAMETERS                              │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                  REGULAR GENERIC              │            PHANTOM TYPE             │
├───────────────────────────────────────────────┼─────────────────────────────────────┤
│ struct Container<T> {                         │ struct Container<phantom T> {       │
│     data: T  // ← T is actually used         │     data: u64  // ← T not used      │
│ }                                             │ }                                   │
│                                               │                                     │
│ MEMORY IMPACT:                                │ MEMORY IMPACT:                      │
│ ├─ T affects struct size                      │ ├─ T has zero memory cost           │
│ ├─ Different T = different memory layout      │ ├─ All instances same memory layout │
│ └─ Runtime polymorphism                       │ └─ Compile-time polymorphism only   │
│                                               │                                     │
│ ABILITY DERIVATION:                           │ ABILITY DERIVATION:                 │
│ ├─ T's abilities affect Container's abilities │ ├─ T's abilities ignored            │
│ ├─ Container<NoCopy> has no copy if T lacks it│ ├─ Container<NoCopy> can have copy  │
│ └─ Strict ability propagation                 │ └─ Flexible ability assignment      │
│                                               │                                     │
│ USE CASES:                                    │ USE CASES:                          │
│ ├─ Actual generic containers                  │ ├─ Type-safe labels/markers         │
│ ├─ Vector<T>, Option<T>                       │ ├─ Currency types, state machines   │
│ └─ Data structures                            │ └─ Access control, type safety      │
└───────────────────────────────────────────────┴─────────────────────────────────────┘
```

## **Visual Explanation: Phantom Types in Action**

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           PHANTOM TYPE VISUALIZATION                               │
└─────────────────────────────────────────────────────────────────────────────────────┘

STRUCT DEFINITION:
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ struct Coin<phantom Currency> has store {                                          │
│     value: u64,  // ← This takes space in memory                                   │
│     // Currency parameter is "phantom" - exists only at compile time              │
│ }                                                                                   │
│                                                                                     │
│ struct USD {}    // ← Marker types (no data)                                       │
│ struct EUR {}                                                                       │
│ struct BTC {}                                                                       │
└─────────────────────────────────────────────────────────────────────────────────────┘

COMPILE TIME (Type Checking):
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ Coin<USD>  ←→  Different Type  ←→  Coin<EUR>  ←→  Different Type  ←→  Coin<BTC>   │
│ │                                 │                                 │              │
│ ├─ value: 100                     ├─ value: 85                     ├─ value: 1    │
│ └─ Currency: USD (phantom)        └─ Currency: EUR (phantom)       └─ Currency: BTC│
│                                                                                     │
│ ✅ Compiler ensures type safety:                                                   │
│ ├─ Cannot pass Coin<USD> to function expecting Coin<EUR>                          │
│ ├─ Cannot store Coin<BTC> in Coin<USD> variable                                   │
│ └─ Cannot mix different currency types                                             │
└─────────────────────────────────────────────────────────────────────────────────────┘

RUNTIME (Actual Memory):
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ Coin<USD>: [100]  ←  Only 8 bytes (u64)                                           │
│ Coin<EUR>: [85]   ←  Only 8 bytes (u64)                                           │
│ Coin<BTC>: [1]    ←  Only 8 bytes (u64)                                           │
│                                                                                     │
│ 💡 The Currency type parameter disappeared!                                        │
│    It was only used for compile-time type checking                                │
└─────────────────────────────────────────────────────────────────────────────────────┘
```
## What Are Tuples in Move?
Move has a **limited** tuple system that's quite different from traditional languages:
┌─────────────────────────────────────────────────────────────┐
│                    MOVE TUPLES - KEY FACTS                  │
│                                                             │
│ ❌ NOT first-class values (no runtime existence)           │
│ ❌ Cannot be stored in variables                           │
│ ❌ Cannot be stored in structs                             │
│ ❌ Cannot instantiate generics                             │
│ ✅ Used ONLY for multiple return values                    │
│ ✅ Exist only at compile time                              │
└─────────────────────────────────────────────────────────────┘

### Tuple Limitations Visualized

┌─────────────────────────────────────────────────────────────┐
│                    WHAT YOU CANNOT DO                       │
│                                                             │
│ ❌ Store in variables:                                      │
│    let tuple_var = (1, 2, 3); // ERROR!                    │
│                                                             │
│ ❌ Store in structs:                                        │
│    struct Container {                                       │
│        data: (u64, bool) // ERROR!                         │
│    }                                                        │
│                                                             │
│ ❌ Use as generic parameters:                               │
│    vector<(u64, bool)> // ERROR!                           │
│                                                             │
│ ❌ Pass around as values:                                   │
│    fun process(tuple: (u64, bool)) // ERROR!               │
│                                                             │
│ ✅ ONLY use for multiple returns:                          │
│    fun get_data(): (u64, bool) { (42, true) }              │
└─────────────────────────────────────────────────────────────┘
---
