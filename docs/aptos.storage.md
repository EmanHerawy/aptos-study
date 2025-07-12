## Global Storage Structure

Move's global storage is structured as a forest of trees, where each tree is rooted at an account address. In pseudocode, the global storage looks like:


### Storage Architecture Diagram

```
Global Storage Forest
├─ Address 0x1
│  ├─ Resources
│  │  ├─ CoinStore<AptosCoin> → {coin: Coin{value: 1000}, ...}
│  │  ├─ Account → {auth_key: ..., sequence: 5}
│  │  └─ UserProfile → {name: "Alice", age: 25}
│  └─ Modules
│     ├─ coin.move → ModuleBytecode
│     └─ account.move → ModuleBytecode
│
├─ Address 0x2
│  ├─ Resources
│  │  ├─ CoinStore<MyToken> → {coin: Coin{value: 500}, ...}
│  │  └─ GameState → {level: 10, score: 2500}
│  └─ Modules
│     └─ game.move → ModuleBytecode
│
└─ Address 0x3 (Resource Account)
   ├─ Resources
   │  ├─ MintCapability<MyToken> → {...}
   │  └─ ModuleData → {admin: 0x1, signer_cap: ...}
   └─ Modules
      └─ token_factory.move → ModuleBytecode
```
### Global Storage Structure

The purpose of Move programs is to read from and write to tree-shaped persistent global storage. Programs cannot access the filesystem, network, or any other data outside of this tree.

```move
// Conceptual structure
struct GlobalStorage {
    resources: Map<(address, ResourceType), ResourceValue>,
    modules: Map<(address, ModuleName), ModuleBytecode>
}
```

**Detailed Global Storage Architecture:**

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              APTOS GLOBAL STORAGE                                  │
│                     Map<(Address, Type), ResourceValue>                            │
│                     Map<(Address, ModuleName), ModuleBytecode>                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
                                        │
                            ┌───────────▼───────────┐
                            │    ADDRESS FOREST     │
                            │  (Tree-like structure) │
                            └───────────────────────┘
                                        │
                 ┌──────────────────────┼──────────────────────┐
                 │                      │                      │
                 ▼                      ▼                      ▼
    ┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
    │   Address: 0x1      │    │   Address: 0x42     │    │  Address: 0x123     │
    │ (Standard Library)  │    │  (Module Publisher)  │    │   (End User)        │
    └─────────────────────┘    └─────────────────────┘    └─────────────────────┘
             │                           │                           │
             │                           │                           │
    ┌────────▼────────┐         ┌────────▼────────┐         ┌────────▼────────┐
    │     MODULES     │         │     MODULES     │         │     MODULES     │
    ├─────────────────┤         ├─────────────────┤         ├─────────────────┤
    │• vector::Module │         │• TokenFactory   │         │• (none)         │
    │• string::Module │         │• Profile        │         │                 │
    │• option::Module │         │• GameItems      │         │                 │
    │• signer::Module │         │                 │         │                 │
    └─────────────────┘         └─────────────────┘         └─────────────────┘
             │                           │                           │
    ┌────────▼────────┐         ┌────────▼────────┐         ┌────────▼────────┐
    │    RESOURCES    │         │    RESOURCES    │         │    RESOURCES    │
    ├─────────────────┤         ├─────────────────┤         ├─────────────────┤
    │• (none)         │         │• AdminCap       │         │• Token<USD>     │
    │                 │         │• ModuleStore    │         │• Token<EUR>     │
    │                 │         │                 │         │• Token<BTC>     │
    │                 │         │                 │         │• UserProfile    │
    │                 │         │                 │         │• GameInventory  │
    └─────────────────┘         └─────────────────┘         └─────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────┐
│                            STORAGE SLOT DETAILS                                    │
└─────────────────────────────────────────────────────────────────────────────────────┘

Address 0x123 Detailed Breakdown:
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          Address: 0x123 (User Account)                             │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ STORAGE SLOT: (0x123, TokenFactory::Token<USD>)                                   │
│ ├─ Resource Value: { amount: 1000, metadata: {...} }                              │
│ ├─ Size: ~128 bytes                                                                │
│ └─ Access Pattern: High frequency (daily transactions)                            │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ STORAGE SLOT: (0x123, TokenFactory::Token<EUR>)                                   │
│ ├─ Resource Value: { amount: 750, metadata: {...} }                               │
│ ├─ Size: ~128 bytes                                                                │
│ └─ Access Pattern: Medium frequency (weekly transactions)                         │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ STORAGE SLOT: (0x123, TokenFactory::Token<BTC>)                                   │
│ ├─ Resource Value: { amount: 2, metadata: {...} }                                 │
│ ├─ Size: ~128 bytes                                                                │
│ └─ Access Pattern: Low frequency (monthly transactions)                           │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ STORAGE SLOT: (0x123, Profile::UserProfile)                                       │
│ ├─ Resource Value: { name: "Alice", age: 25, reputation: 1500, ... }              │
│ ├─ Size: ~256 bytes                                                                │
│ └─ Access Pattern: Medium frequency (profile updates)                             │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ STORAGE SLOT: (0x123, Game::Inventory)                                            │
│ ├─ Resource Value: { items: Table<u64, Item>, capacity: 100, ... }                │
│ ├─ Size: ~64 bytes (+ Table items stored separately)                              │
│ └─ Access Pattern: High frequency (gaming sessions)                               │
└─────────────────────────────────────────────────────────────────────────────────────┘

CROSS-ADDRESS RELATIONSHIPS:
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ Module at 0x42::TokenFactory ←→ Resources at 0x123                                │
│ ├─ Controls: Token<USD>, Token<EUR>, Token<BTC>                                    │
│ ├─ Operations: mint(), burn(), transfer()                                          │
│ └─ Security: Only TokenFactory can manipulate Token resources                     │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ Module at 0x42::Profile ←→ Resource at 0x123                                      │
│ ├─ Controls: UserProfile                                                           │
│ ├─ Operations: create_profile(), update_reputation()                              │
│ └─ Security: Only Profile module can manipulate UserProfile resources            │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Key Characteristics

**Forest Structure**: Global storage is a forest consisting of trees rooted at account addresses. Each address can store both resource data values and module code values.

**Address Isolation**: Each address maintains its own isolated storage space, enabling parallel execution without conflicts.

**Type Safety**: Resources are identified by their full type path: `(address, module_name, struct_name, type_parameters)`

---

## Two Storage Rules

Move enforces two fundamental storage rules that ensure safety and prevent common blockchain vulnerabilities:

### Rule 1: Module Authority
Each type T must be declared in the current module. This ensures that a resource can only be manipulated via the API exposed by its defining module.

### Rule 2: Reference Safety
A function cannot return a reference that points into global storage. Move must enforce this restriction to guarantee absence of dangling references to global storage.

### Storage Rules Visualization

```
Module Authority Rule:
┌─────────────────────────────────────────┐
│ module 0x42::bank {                     │
│   struct Account has key { balance: u64 }│
│                                         │
│   ✅ ALLOWED: Manipulate Account here   │
│   public fun deposit(acc: &signer, ...) │
│   public fun withdraw(acc: &signer, ...)│
│ }                                       │
└─────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ module 0x43::hacker {                   │
│   ❌ FORBIDDEN: Cannot directly access  │
│   // borrow_global<0x42::bank::Account> │
│   // move_from<0x42::bank::Account>     │
│                                         │
│   ✅ ALLOWED: Use public API only       │
│   0x42::bank::deposit(&signer, amount)  │
│ }                                       │
└─────────────────────────────────────────┘

Reference Safety Rule:
┌─────────────────────────────────────────┐
│ ❌ FORBIDDEN:                           │
│ fun get_balance_ref(addr: address):     │
│     &u64 acquires Account {             │
│   &borrow_global<Account>(addr).balance │
│ }                                       │
│                                         │
│ ✅ ALLOWED:                             │
│ fun get_balance(addr: address):         │
│     u64 acquires Account {              │
│   borrow_global<Account>(addr).balance  │
│ }                                       │
└─────────────────────────────────────────┘
```

---

## Storage Slot Details

Each storage slot in Aptos is uniquely identified by the combination of:

1. **Account Address** (32 bytes)
2. **Resource Type** (includes module path and type parameters)

### Storage Slot Identification

```
Storage Slot Key = (Address, ResourceType)

Examples:
(0x1, 0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>)
(0x2, 0x42::game::PlayerState)
(0x3, 0x1::account::Account)
```

### Storage Slot Properties

- **Uniqueness**: Each address can only hold ONE instance of each resource type
- **Type Parameters**: Different type parameters create different storage slots
- **Proof Size**: Each storage slot requires a 32 * LogN bytes proof in the Merkle tree, where N is total storage slots

### **Understanding Merkle Tree Proof Size**

```
Merkle Tree Structure for Blockchain State:
┌─────────────────────────────────────────────────────────────┐
│                    ROOT HASH                                │
│                  (32 bytes)                                 │
├─────────────────────┬───────────────────────────────────────┤
│    LEVEL 1          │          LEVEL 1                      │
│  (32 bytes)         │        (32 bytes)                     │
├─────────┬───────────┼───────────┬───────────────────────────┤
│ LEVEL 2 │ LEVEL 2   │ LEVEL 2   │ LEVEL 2                   │
│(32 bytes│(32 bytes) │(32 bytes) │(32 bytes)                 │
├─────┬───┼───┬───────┼───┬───────┼───┬───────────────────────┤
│ L3  │L3 │L3 │ L3    │L3 │ L3    │L3 │ L3                    │
│     │   │   │       │   │       │   │                       │
└─────┴───┴───┴───────┴───┴───────┴───┴───────────────────────┘
  ↑     ↑   ↑     ↑     ↑     ↑     ↑     ↑
Storage Storage Storage ...              Storage
Slot 1  Slot 2  Slot 3                   Slot N

To prove ANY storage slot exists and has specific value:
• Need hash from each level on path to root
• Tree height = log₂(N) where N = total slots
• Each hash = 32 bytes
• Total proof size = 32 * log₂(N) bytes
```

### **Why This Matters for Storage Costs**

```
Proof Size Growth Example:
┌─────────────────┬──────────────┬─────────────────────────────┐
│ Total Slots (N) │ Tree Height  │ Proof Size per Slot        │
├─────────────────┼──────────────┼─────────────────────────────┤
│ 1,000           │ ~10 levels   │ 32 * 10 = 320 bytes        │
│ 10,000          │ ~13 levels   │ 32 * 13 = 416 bytes        │
│ 100,000         │ ~17 levels   │ 32 * 17 = 544 bytes        │
│ 1,000,000       │ ~20 levels   │ 32 * 20 = 640 bytes        │
│ 10,000,000      │ ~23 levels   │ 32 * 23 = 736 bytes        │
└─────────────────┴──────────────┴─────────────────────────────┘

Real Example from AIP-9:
"At N = 1,000,000, this results in a 640 byte proof. 
With 1,000,000 storage slots in use, adding even a new 
resource that contains only an event handle uses 
approximately 680 bytes, where the event handle 
requires only 40 bytes."

Breakdown:
• Actual data: 40 bytes (event handle)
• Merkle proof: 640 bytes  
• Total cost: 680 bytes
• Overhead: 94%! 😱
```

### **How Merkle Proofs Work**

```
Step-by-Step Proof Verification:
┌─────────────────────────────────────────────────────────────┐
│ 1. CLIENT REQUESTS: "Prove storage slot X has value V"     │
│                                                             │
│ 2. NODE PROVIDES PROOF:                                    │
│    • Value V at slot X                                     │
│    • Hash₁ (sibling at level 1)                           │
│    • Hash₂ (sibling at level 2)                           │
│    • Hash₃ (sibling at level 3)                           │
│    • ... (one hash per level up to root)                  │
│                                                             │
│ 3. CLIENT VERIFIES:                                        │
│    • Hash(V) with Hash₁ → get Level₁ hash                 │
│    • Hash(Level₁) with Hash₂ → get Level₂ hash            │
│    • Hash(Level₂) with Hash₃ → get Level₃ hash            │
│    • ... continue until root                              │
│    • Check if computed root matches known state root      │
│                                                             │
│ 4. SECURITY GUARANTEE:                                     │
│    • If proof verifies → data is authentic                │
│    • If proof fails → data was tampered with              │
│    • Cryptographically impossible to forge valid proof    │
└─────────────────────────────────────────────────────────────┘
```

### **Resource Groups Solution**
This AIP proposes resource groups to support storing multiple distinct Move resources together into a single storage slot.

**What are Resource Groups?**
Multiple resources stored in a single storage slot to optimize gas and storage costs.

```move
module StorageOptimization::Groups {
    use aptos_framework::object;
    
    // Define a resource group
    #[resource_group(scope = global)]
    struct GameDataGroup {}
    
    // Resources that belong to the same group
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct PlayerStats has store, key {
        level: u64,
        experience: u64,
        health: u64,
    }
    
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]  
    struct PlayerInventory has store, key {
        items: vector<GameItem>,
        capacity: u64,
    }
    
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct PlayerAchievements has store, key {
        completed: vector<u64>,
        total_score: u64,
    }
    
    // All these resources can be stored together efficiently!
}
```
### Resource Groups Benefits and Trade-offs

```
Resource Groups Analysis:
┌─────────────────────────────────────────────────────────────┐
│ BENEFITS:                                                   │
│ ✅ Reduced storage overhead (fewer Merkle proofs)           │
│ ✅ Better cache locality for related resources              │
│ ✅ More idiomatic Move (co-located resources)              │
│ ✅ Easier protocol upgrades (add new group members)        │
│ ✅ Lower gas costs for multi-resource operations            │
│                                                             │
│ TRADE-OFFS:                                                 │
│ ⚠️ Nested reading (read group → read specific resource)     │
│ ⚠️ Potential write amplification (update entire group)     │
│ ⚠️ More complex indexing for off-chain applications        │
│ ⚠️ Group design decisions become permanent                  │
│ ⚠️ Possible contention if many resources in same group     │
└─────────────────────────────────────────────────────────────┘
```

### Resource Groups vs Individual Resources

```
Performance Comparison:
┌─────────────────────────────────────────────────────────────┐
│ Operation               │ Individual │ Resource │ Improvement │
│                        │ Resources  │ Groups   │             │
├────────────────────────┼────────────┼──────────┼─────────────┤
│ Single resource read   │    Fast    │   Fast   │    Same     │
│ Multi-resource read    │   Slower   │  Faster  │   30-50%    │
│ Storage proof size     │   Large    │  Smaller │   20-40%    │
│ Cache efficiency       │    Poor    │   Good   │   2-3x      │
│ Indexer complexity     │   Simple   │ Complex  │   Higher    │
│ Migration difficulty   │     -      │   High   │     -       │
└────────────────────────┴────────────┴──────────┴─────────────┘
```


```
Problem Solved by Resource Groups:
┌─────────────────────────────────────────────────────────────┐
│ WITHOUT Resource Groups (5 separate resources):            │
│ ├─ UserProfile → 680 bytes (40 data + 640 proof)          │
│ ├─ UserPrefs → 680 bytes (30 data + 640 proof)            │
│ ├─ UserStats → 680 bytes (50 data + 640 proof)            │
│ ├─ UserBadges → 680 bytes (60 data + 640 proof)           │
│ └─ UserSettings → 680 bytes (20 data + 640 proof)         │
│ TOTAL: 5 × 680 = 3,400 bytes (200 data + 3,200 proofs)   │
│                                                             │
│ WITH Resource Groups (1 grouped resource):                 │
│ └─ UserResourceGroup → 840 bytes (200 data + 640 proof)   │
│ TOTAL: 840 bytes                                           │
│                                                             │
│ SAVINGS: 3,400 - 840 = 2,560 bytes (75% reduction!)      │
└─────────────────────────────────────────────────────────────┘
```

### **Why 32 Bytes Per Hash?**

```
Hash Function Properties:
┌─────────────────────────────────────────────────────────────┐
│ Aptos uses SHA-3 (Keccak) hash function:                   │
│ • Output size: 256 bits = 32 bytes                         │
│ • Cryptographically secure                                 │
│ • Collision resistant                                      │
│ • Avalanche effect (small input change → big output change)│
│                                                             │
│ Why 32 bytes is necessary:                                  │
│ • Security level: 2^128 (considered quantum-safe)          │
│ • Collision probability: ~2^-256 (astronomically small)    │
│ • Cannot be reduced without compromising security           │
│                                                             │
│ Alternative hash sizes would be:                            │
│ • 16 bytes: Not secure enough                              │
│ • 64 bytes: Unnecessarily large, double the storage cost   │
│ • 32 bytes: Perfect balance of security and efficiency     │
└─────────────────────────────────────────────────────────────┘
```


## Storage Hierarchy Visualization

The complete storage hierarchy shows how all components interact:

### Global Storage Tree Structure

```
Global Storage Hierarchy:
┌─────────────────────────────────────────────────────────────┐
│                    APTOS BLOCKCHAIN STATE                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ ┌─ Standard Account 0x1 (Alice)                             │
│ │  ├─ Resources/                                            │
│ │  │  ├─ 0x1::account::Account                              │
│ │  │  │  ├─ authentication_key: 0x1abc...                  │
│ │  │  │  ├─ sequence_number: 42                             │
│ │  │  │  └─ guid_creation_num: 15                           │
│ │  │  │                                                     │
│ │  │  ├─ 0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>   │
│ │  │  │  ├─ coin: Coin { value: 1000000 }                  │
│ │  │  │  ├─ frozen: false                                   │
│ │  │  │  ├─ deposit_events: EventHandle                     │
│ │  │  │  └─ withdraw_events: EventHandle                    │
│ │  │  │                                                     │
│ │  │  └─ 0x42::nft::TokenStore                              │
│ │  │     ├─ tokens: Table<TokenId, Token>                  │
│ │  │     └─ collection_count: 5                             │
│ │  │                                                         │
│ │  └─ Modules/ (None - regular user)                        │
│ │                                                            │
│ ├─ Protocol Account 0x42 (DEX Smart Contract)               │
│ │  ├─ Resources/                                            │
│ │  │  ├─ 0x1::account::Account                              │
│ │  │  ├─ 0x42::dex::PoolRegistry                            │
│ │  │  │  ├─ pools: Table<PoolKey, Pool>                    │
│ │  │  │  └─ admin: address                                  │
│ │  │  │                                                     │
│ │  │  └─ 0x42::dex::FeeConfig                               │
│ │  │     ├─ trading_fee: u64                                │
│ │  │     └─ protocol_fee: u64                               │
│ │  │                                                         │
│ │  └─ Modules/                                              │
│ │     ├─ 0x42::dex (DEX logic)                              │
│ │     ├─ 0x42::pool (Pool management)                       │
│ │     └─ 0x42::math (Mathematical operations)               │
│ │                                                            │
│ └─ Resource Account 0x3abc... (DEX Treasury)                │
│    ├─ Resources/                                            │
│    │  ├─ 0x1::account::Account                              │
│    │  ├─ 0x42::dex::TreasuryData                            │
│    │  │  ├─ admin: 0x42                                     │
│    │  │  ├─ signer_cap: SignerCapability                   │
│    │  │  └─ treasury_events: EventHandle                    │
│    │  │                                                     │
│    │  ├─ 0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>   │
│    │  │  └─ coin: Coin { value: 50000000 }                 │
│    │  │                                                     │
│    │  └─ 0x42::dex::MintCapability<0x42::token::DEXToken>   │
│    │     ├─ mint_cap: MintCapability                        │
│    │     └─ burn_cap: BurnCapability                        │
│    │                                                         │
│    └─ Modules/ (None - resource account)                    │
└─────────────────────────────────────────────────────────────┘
```

### Storage Hierarchy Visualization

```
┌─────────────────────────────────────────────────────────────────┐
│                    Global Storage                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                Account Storage                          │   │
│  │  ┌─────────────────────────────────────────────────┐   │   │
│  │  │            Resource (has key)                   │   │   │
│  │  │  ┌─────────────────────────────────────────┐   │   │   │
│  │  │  │        Field (has store)                │   │   │   │
│  │  │  │  ┌─────────────────────────────────┐   │   │   │   │
│  │  │  │  │    Primitive Value              │   │   │   │   │
│  │  │  │  └─────────────────────────────────┘   │   │   │   │
│  │  │  └─────────────────────────────────────────┘   │   │   │
│  │  └─────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```
---
## **Modern Index Notation**

Instead of verbose function calls, you can use modern index notation:

| Index Syntax | Storage Operation |
|---|---|
| `&T[address]` | `borrow_global<T>(address)` |
| `&mut T[address]` | `borrow_global_mut<T>(address)` |
| `T[address] = x` | `*borrow_global_mut<T>(address) = x` |

```move
public fun modern_update(addr: address, new_age: u8) acquires UserProfile {
    UserProfile[addr].age = new_age;  // Clean and concise!
}
```

## **The `acquires` Annotation**

A Move function must be annotated with `acquires T` if and only if: The body contains a `move_from<T>`, `borrow_global_mut<T>`, or `borrow_global<T>` instruction, or The body invokes a function declared in the same module that is annotated with `acquires`

```move
public fun get_profile_age(addr: address): u8 acquires UserProfile {
    borrow_global<UserProfile>(addr).age
    // ^^^ This function accesses global storage, so needs `acquires`
}
```

