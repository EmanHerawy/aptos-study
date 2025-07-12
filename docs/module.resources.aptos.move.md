
# Module vs Resource

Understanding the distinction between modules and resources is crucial for Move mastery:

### Fundamental Differences

```
Module vs Resource Characteristics:
┌─────────────────┬──────────────────┬──────────────────────┐
│ Aspect          │ Module           │ Resource             │
├─────────────────┼──────────────────┼──────────────────────┤
│ Contains        │ Code & Logic     │ Data & State         │
│ Mutability      │ Immutable*       │ Mutable              │
│ Upgradability   │ Via packages     │ Not applicable       │
│ Access Control  │ Public/Private   │ Ability-based        │
│ Storage         │ At address       │ Within accounts      │
│ Uniqueness      │ One per address  │ One per type per acc │
│ References      │ Not applicable   │ Can be borrowed      │
│ Transfer        │ Not transferable │ Via move semantics   │
└─────────────────┴──────────────────┴──────────────────────┘
```

### Module Architecture

```
Module Structure:
┌─────────────────────────────────────────────────────────────┐
│ module 0x42::example {                                      │
│   ├── Imports                                               │
│   │   use std::signer;                                      │
│   │   use aptos_framework::coin;                            │
│   │                                                         │
│   ├── Constants                                             │
│   │   const ENOT_AUTHORIZED: u64 = 1;                      │
│   │                                                         │
│   ├── Struct Definitions                                    │
│   │   struct MyResource has key { value: u64 }             │
│   │                                                         │
│   ├── Functions                                             │
│   │   ├── init_module() // Called once at publish          │
│   │   ├── public entry functions                           │
│   │   ├── public functions                                 │
│   │   └── private functions                                │
│   │                                                         │
│   └── Tests (in #[test_only] sections)                     │
│       #[test] fun test_functionality() { ... }             │
│ }                                                           │
└─────────────────────────────────────────────────────────────┘
```

### Resource Architecture

Move resources contain data but no code. Every resource value has a type that is declared in a module published on the Aptos blockchain.

```
Resource Lifecycle:
┌─────────────────────────────────────────────────────────────┐
│                    RESOURCE OPERATIONS                      │
│                                                             │
│ 1. CREATION                                                 │
│    let resource = MyResource { value: 100 };               │
│                                                             │
│ 2. STORAGE                                                  │
│    move_to<MyResource>(&signer, resource);                 │
│                                                             │
│ 3. ACCESS                                                   │
│    let resource_ref = borrow_global<MyResource>(address);  │
│    let mut_ref = borrow_global_mut<MyResource>(address);   │
│                                                             │
│ 4. MODIFICATION                                             │
│    mut_ref.value = 200;                                    │
│                                                             │
│ 5. REMOVAL                                                  │
│    let MyResource { value } = move_from<MyResource>(addr); │
│                                                             │
│ 6. DESTRUCTION                                              │
│    // value goes out of scope and is dropped               │
└─────────────────────────────────────────────────────────────┘
```

---


## Resource Lifecycle

Understanding the complete lifecycle of resources is crucial for proper Move development:

### Resource State Transitions

```
Resource Lifecycle State Machine:
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  ┌──────────────┐    create/pack     ┌──────────────┐       │
│  │   NOT        │ ─────────────────▶ │   CREATED    │       │
│  │  CREATED     │                    │  (in memory) │       │
│  │              │                    │              │       │
│  └──────────────┘                    └──────┬───────┘       │
│                                             │               │
│                                    move_to  │               │
│                                             ▼               │
│  ┌──────────────┐                    ┌──────────────┐       │
│  │  DESTROYED   │                    │    STORED    │       │
│  │ (unpacked)   │                    │ (in global)  │       │
│  │              │                    │              │       │
│  └──────▲───────┘                    └──────┬───────┘       │
│         │                                   │               │
│         │ unpack/destroy                    │ move_from     │
│         │                                   ▼               │
│  ┌──────────────┐   ◀───────────────  ┌──────────────┐       │
│  │   REMOVED    │                     │   BORROWED   │       │
│  │ (in memory)  │                     │ (referenced) │       │
│  │              │                     │              │       │
│  └──────────────┘                     └──────────────┘       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Detailed Lifecycle Operations

```
Resource Lifecycle with Examples:
┌─────────────────────────────────────────────────────────────┐
│ 1. CREATION PHASE                                           │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ let coin = Coin { value: 100 };                        │ │
│ │ // Resource exists in local memory                     │ │
│ │ // Must be explicitly handled before function ends    │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ 2. STORAGE PHASE                                            │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ move_to<CoinStore>(&signer, CoinStore { coin });       │ │
│ │ // Resource now in global storage                      │ │
│ │ // Accessible via borrow_global operations             │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ 3. ACCESS PHASE                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ // Read-only access                                    │ │
│ │ let store_ref = borrow_global<CoinStore>(address);     │ │
│ │ let balance = store_ref.coin.value;                    │ │
│ │                                                         │ │
│ │ // Mutable access                                      │ │
│ │ let store_mut = borrow_global_mut<CoinStore>(address); │ │
│ │ store_mut.coin.value = store_mut.coin.value + 50;     │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ 4. REMOVAL PHASE                                            │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ let CoinStore { coin } = move_from<CoinStore>(address); │ │
│ │ // Resource removed from global storage                │ │
│ │ // Now exists in local memory again                    │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ 5. DESTRUCTION PHASE                                        │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ let Coin { value } = coin;                             │ │
│ │ // Resource unpacked and destroyed                     │ │
│ │ // Individual fields can be used or dropped            │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Resource Safety Guarantees

```
Move's Resource Safety Rules:
┌─────────────────────────────────────────────────────────────┐
│ SAFETY GUARANTEE #1: No Resource Duplication               │
│ • Resources cannot be copied (unless has copy ability)     │
│ • Move semantics ensure single ownership                   │
│ • Prevents double-spending and resource inflation          │
│                                                             │
│ SAFETY GUARANTEE #2: No Resource Loss                      │
│ • Resources cannot be dropped (unless has drop ability)   │
│ • Must be explicitly handled in all code paths            │
│ • Prevents accidental resource destruction                 │
│                                                             │
│ SAFETY GUARANTEE #3: Reference Safety                      │
│ • Cannot return references to global storage               │
│ • Prevents dangling references after resource removal     │
│ • Acquires annotation prevents concurrent access issues    │
│                                                             │
│ SAFETY GUARANTEE #4: Module Authority                      │
│ • Only defining module can directly manipulate resources   │
│ • Public API controls all external access                 │
│ • Prevents unauthorized resource modification              │
└─────────────────────────────────────────────────────────────┘
```

---
