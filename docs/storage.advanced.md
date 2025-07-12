# Advanced Storage Patterns on Aptos Move

Move enables sophisticated storage patterns for complex applications on the Aptos blockchain. This guide covers the key patterns essential for mastering Move development.

## Core Storage Patterns

### Pattern 1: Storage Polymorphism

The ability to index into global storage via a type parameter chosen at runtime is a powerful Move feature known as storage polymorphism.

```move
// ✅ CORRECT IMPLEMENTATION
module 0x42::registry {
    use std::signer;

    struct Container<T: store> has key {
        data: T,
    }

    // Generic storage operation
    public fun store<T: store>(account: &signer, data: T) {
        move_to<Container<T>>(account, Container { data });
    }

    // Generic retrieval operation
    public fun retrieve<T: store>(addr: address): T 
        acquires Container {
        let Container { data } = move_from<Container<T>>(addr);
        data
    }

    // ✅ IMPORTANT: Functions that access global storage must declare 'acquires'
    public fun read<T: store>(addr: address): &T 
        acquires Container {
        &borrow_global<Container<T>>(addr).data
    }

    // Usage examples:
    // store<UserProfile>(account, profile);
    // store<GameState>(account, state);
    // let profile = retrieve<UserProfile>(user_addr);
}
```

**Key Learning Points:**
- Functions must use `acquires` annotations when accessing global storage with `move_from`, `borrow_global`, or `borrow_global_mut`
- Storage polymorphism allows writing generic functions that work with any storable type
- The type parameter `T` must have appropriate abilities (`store` for data, `key` for resources)

### Pattern 2: Capability-Based Access Control

```move
module 0x42::vault {
    use std::vector;
    use std::signer;

    // ✅ CORRECTED: Resources for capabilities
    struct Vault<T: store> has key {
        assets: vector<T>,
    }

    // Capability resources - these grant permissions
    struct AdminCap has key, store, drop {}
    struct DepositCap has key, store, drop {}
    struct WithdrawCap has key, store, drop {}

    // Only admin can initialize the vault
    public fun initialize<T: store>(admin: &signer) {
        move_to(admin, Vault<T> { assets: vector::empty() });
        move_to(admin, AdminCap {});
    }

    // Admin can create deposit capabilities
    public fun create_deposit_cap(_: &AdminCap): DepositCap {
        DepositCap {}
    }

    // Admin can create withdraw capabilities  
    public fun create_withdraw_cap(_: &AdminCap): WithdrawCap {
        WithdrawCap {}
    }

    // Anyone with deposit capability can deposit
    public fun deposit<T: store>(
        _cap: &DepositCap,
        vault_addr: address,
        asset: T
    ) acquires Vault {
        let vault = borrow_global_mut<Vault<T>>(vault_addr);
        vector::push_back(&mut vault.assets, asset);
    }

    // Anyone with withdraw capability can withdraw
    public fun withdraw<T: store>(
        _cap: &WithdrawCap,
        vault_addr: address,
    ): T acquires Vault {
        let vault = borrow_global_mut<Vault<T>>(vault_addr);
        vector::pop_back(&mut vault.assets)
    }
}
```

**Educational Notes:**
- Capabilities are resources that signify permission to do something. Only the module that defines a capability can create it.
- This pattern is more secure than address-based access control
- Capabilities can be transferred, stored, or destroyed as needed

### Pattern 3: Event-Driven Architecture

```move
module 0x42::marketplace {
    use aptos_framework::event;
    use aptos_framework::timestamp;
    use aptos_framework::object::Object;
    use std::signer;

    // ✅ CORRECTED: Modern Aptos event system
    struct MarketplaceState has key {
        next_listing_id: u64,
    }

    // ✅ IMPORTANT: Events must have 'drop' and 'store' abilities
    #[event]
    struct ListEvent has drop, store {
        listing_id: u64,
        seller: address,
        price: u64,
        timestamp: u64,
    }

    #[event]
    struct PurchaseEvent has drop, store {
        listing_id: u64,
        buyer: address,
        seller: address,
        price: u64,
        timestamp: u64,
    }

    public fun list_item(
        seller: &signer,
        price: u64
    ) acquires MarketplaceState {
        let state = borrow_global_mut<MarketplaceState>(
            @marketplace
        );
        let listing_id = state.next_listing_id;
        
        // ✅ CORRECTED: Modern event emission
        event::emit(ListEvent {
            listing_id,
            seller: signer::address_of(seller),
            price,
            timestamp: timestamp::now_seconds(),
        });
        
        state.next_listing_id = listing_id + 1;
    }
}
```

**Key Updates:**
- Modern Aptos uses `#[event]` attribute and `event::emit()` instead of event handles
- Events must have `drop` and `store` abilities
- No need for explicit event handles in resources

### Pattern 4: Modular Resource Composition

```move
module 0x42::profile {
    use std::string::String;
    use std::signer;

    struct UserProfile has key {
        basic_info: BasicInfo,
        preferences: UserPreferences,
        social_data: SocialData,
    }

    struct BasicInfo has store {
        name: String,
        email: String,
        created_at: u64,
    }

    struct UserPreferences has store {
        theme: u8,
        language: String,
        notifications: bool,
    }

    struct SocialData has store {
        followers: u64,
        following: u64,
        posts_count: u64,
    }

    // Modular update functions
    public fun update_basic_info(
        user: &signer,
        name: String,
        email: String
    ) acquires UserProfile {
        let profile = borrow_global_mut<UserProfile>(
            signer::address_of(user)
        );
        profile.basic_info.name = name;
        profile.basic_info.email = email;
    }

    public fun update_preferences(
        user: &signer,
        theme: u8,
        language: String,
        notifications: bool
    ) acquires UserProfile {
        let profile = borrow_global_mut<UserProfile>(
            signer::address_of(user)
        );
        profile.preferences = UserPreferences {
            theme,
            language,
            notifications,
        };
    }
}
```

---

## Resource Groups (AIP-9)

Resource Groups are a feature (AIP-9) to support storing multiple distinct Move resources together into a single storage slot

### Understanding the Storage Problem

```
Storage Efficiency Problem:
┌─────────────────────────────────────────────────────────────┐
│                      WITHOUT RESOURCE GROUPS               │
│                                                             │
│ Account Address: 0x42                                       │
│ ├─ Storage Slot 1: UserProfile → ~680 bytes                │
│ ├─ Storage Slot 2: UserPreferences → ~680 bytes            │
│ ├─ Storage Slot 3: UserStats → ~680 bytes                  │
│ ├─ Storage Slot 4: UserBadges → ~680 bytes                 │
│ └─ Storage Slot 5: UserSettings → ~680 bytes               │
│                                                             │
│ Total Storage: 5 × 680 = 3,400 bytes                       │
│ Actual Data: ~200 bytes                                    │
│ Overhead: ~94% (Merkle proofs)                             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                       WITH RESOURCE GROUPS                 │
│                                                             │
│ Account Address: 0x42                                       │
│ └─ Storage Slot 1: UserResourceGroup → ~880 bytes          │
│    ├─ UserProfile: 40 bytes                                │
│    ├─ UserPreferences: 30 bytes                            │
│    ├─ UserStats: 50 bytes                                  │
│    ├─ UserBadges: 60 bytes                                 │
│    └─ UserSettings: 20 bytes                               │
│                                                             │
│ Total Storage: 880 bytes                                   │
│ Actual Data: 200 bytes                                     │
│ Overhead: ~77% (Better efficiency!)                        │
└─────────────────────────────────────────────────────────────┘
```

### Resource Groups Implementation

```move
// ⚠️ NOTE: Resource Groups are still in proposal/discussion phase
// This is conceptual syntax based on AIP-9

#[resource_group]
struct UserGroup {
    // Marker struct - defines the group
}

#[resource_group_member(group = UserGroup)]
struct UserProfile has key {
    name: String,
    email: String,
}

#[resource_group_member(group = UserGroup)]  
struct UserPreferences has key {
    theme: u8,
    language: String,
}

#[resource_group_member(group = UserGroup)]
struct UserStats has key {
    login_count: u64,
    last_login: u64,
}

// Usage remains the same as regular resources:
// move_to<UserProfile>(account, profile);
// move_to<UserPreferences>(account, preferences);
// borrow_global<UserStats>(address);
```

### Resource Groups Trade-offs

```
Benefits vs Trade-offs:
┌─────────────────────────────────────────────────────────────┐
│ ✅ BENEFITS:                                                │
│ • Reduced storage overhead (fewer Merkle proofs)            │
│ • Better cache locality for related resources               │
│ • More idiomatic Move (co-located resources)               │
│ • Easier protocol upgrades (add new group members)         │
│ • Lower gas costs for multi-resource operations             │
│                                                             │
│ ⚠️ TRADE-OFFS:                                              │
│ • Nested reading (read group → read specific resource)      │
│ • Potential write amplification (update entire group)      │
│ • More complex indexing for off-chain applications         │
│ • Group design decisions become permanent                   │
│ • Possible contention if many resources in same group      │
└─────────────────────────────────────────────────────────────┘
```

---

## Fungible Asset Standard: Primary vs Secondary Stores

The Fungible Asset Standard uses a sophisticated storage model with Primary and Secondary stores to manage how asset balances are stored on each account. This system solves the fundamental problem of where to store tokens when sending them to any account.

### The Core Storage Challenge

The FA standard needs to manage how asset balances are stored on each account. The solution uses two types of stores to address different use cases:

```
Storage Challenge:
┌─────────────────────────────────────────────────────────────┐
│ When Alice sends FA to Bob:                                 │
│ ├─ Where exactly should tokens be stored?                   │
│ ├─ What if Bob doesn't have a store yet?                    │
│ ├─ How can we make addressing predictable?                  │
│ └─ How to support advanced DeFi use cases?                  │
└─────────────────────────────────────────────────────────────┘

FA Storage Solution:
┌─────────────────────────────────────────────────────────────┐
│ ✅ PRIMARY STORE: One per account per token (deterministic) │
│ ✅ AUTO-CREATION: Created automatically when needed         │
│ ✅ SECONDARY STORES: Multiple stores for advanced use cases │
│ ✅ FLEXIBILITY: Support both simple and complex scenarios   │
└─────────────────────────────────────────────────────────────┘
```

### Technical Implementation

**Primary Store Address Formula:**
```
sha3_256(32-byte account address | 32-byte metadata object address | 0xFC)
```

**Store Architecture:**
```
┌─────────────────────────────────────────────────────────────┐
│                    FUNGIBLE ASSET STORAGE                  │
└─────────────────────────────────────────────────────────────┘

ACCOUNT: 0x123 (Alice)
┌─────────────────────────────────────────────────────────────┐
│                        PRIMARY STORE                        │
│ Address: sha3_256(0x123 | USDC_metadata | 0xFC)            │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Object<FungibleStore> {                                 │ │
│ │   metadata: Object<Metadata>, // Points to USDC        │ │
│ │   balance: 5000,              // Alice's USDC balance  │ │
│ │   frozen: false               // Transfer status       │ │
│ │ }                                                       │ │
│ └─────────────────────────────────────────────────────────┘ │
│ • Deterministic address (calculable by anyone)             │
│ • Auto-created when FA deposited                           │
│ • Non-deletable (permanent)                                │
│                                                             │
│                      SECONDARY STORES                       │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ DEX Liquidity Pool Store                                │ │
│ │ Address: 0xABC... (Object GUID-based, non-deterministic│ │
│ │ ┌─────────────────────────────────────────────────────┐ │ │
│ │ │ Object<FungibleStore> {                             │ │ │
│ │ │   metadata: Object<Metadata>, // Same USDC metadata │ │ │
│ │ │   balance: 2000,              // Pool's USDC        │ │ │
│ │ │   frozen: false                                     │ │ │
│ │ │ }                                                   │ │ │
│ │ └─────────────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────────┘ │
│ • Created via Object constructor                            │
│ • Deletable when empty                                      │
│ • Multiple stores possible per token type                  │
└─────────────────────────────────────────────────────────────┘
```

### Primary vs Secondary Store Detailed Comparison

```
┌─────────────────────────────────────────────────────────────┐
│                  PRIMARY vs SECONDARY STORES               │
├─────────────────────────────────────────────────────────────┤
│             PRIMARY STORE          │      SECONDARY STORE   │
├─────────────────────────────────────┼─────────────────────────┤
│ 🎯 PURPOSE & USE CASES              │                         │
│ • Default storage for all users     │ • Advanced DeFi apps    │
│ • Standard token transfers          │ • Smart contract mgmt   │
│ • Predictable addressing            │ • Multiple token pools  │
│ • Auto-recipient handling           │ • Specialized logic     │
│                                     │                         │
│ 📍 ADDRESS CHARACTERISTICS          │                         │
│ • Deterministic calculation         │ • Non-deterministic     │
│ • sha3_256(owner|meta|0xFC)         │ • Object GUID-based     │
│ • Anyone can compute address        │ • Must track/store addr │
│ • Same formula across network       │ • Created via Objects   │
│                                     │                         │
│ 🔢 QUANTITY & CREATION              │                         │
│ • Exactly ONE per token per account │ • Unlimited per token   │
│ • Auto-created on first deposit     │ • Explicit creation only│
│ • Cannot create duplicates          │ • Developer controlled  │
│ • Permissionless system creation    │ • Custom creation logic │
│                                     │                         │
│ 🗑️ LIFECYCLE MANAGEMENT             │                         │
│ • Non-deletable (permanent)         │ • Deletable when empty  │
│ • Always available for deposits     │ • Can be cleaned up     │
│ • No maintenance required           │ • Requires management   │
│                                     │                         │
│ ⚡ PERFORMANCE CONSIDERATIONS        │                         │
│ • SHA-256 hash computation cost     │ • Direct address access │
│ • Slight overhead per access        │ • More efficient lookup │
│ • Standard network behavior         │ • Optimized for speed   │
│                                     │                         │
│ 🔧 ACCESSING THE STORE              │                         │
│ • primary_store<T>(owner, metadata) │ • Direct Object<Store>  │
│ • primary_fungible_store API        │ • fungible_asset API    │
│ • Built-in helper functions         │ • Manual management     │
└─────────────────────────────────────┴─────────────────────────┘
```

### When to Use Each Store Type

**Official Guidance:** "In the vast majority of circumstances, users will store all FA balances in their Primary FungibleStore. Sometimes though, additional Secondary Stores can be created for advanced DeFi applications."

```
PRIMARY STORE - DEFAULT CHOICE:
┌─────────────────────────────────────────────────────────────┐
│ ✅ Standard user-to-user transfers                          │
│ ✅ Exchange deposits and withdrawals                         │
│ ✅ Wallet integration and balance display                    │
│ ✅ Simple dApp token operations                              │
│ ✅ Any time you need predictable addressing                  │
│ ✅ When recipients may not have stores yet                   │
│ ✅ Default token storage for any account                     │
└─────────────────────────────────────────────────────────────┘

SECONDARY STORE - ADVANCED CASES:
┌─────────────────────────────────────────────────────────────┐
│ ✅ Asset pools managing multiple FA types                    │
│ ✅ DeFi protocols (DEX, lending, staking)                   │
│ ✅ Smart contracts needing separate token balances          │
│ ✅ Liquidity pools (each token needs own store)             │
│ ✅ Escrow services holding multiple assets                   │
│ ✅ Gaming: inventory systems with item separation           │
│ ✅ When you need multiple stores of the same token type     │
└─────────────────────────────────────────────────────────────┘
```

### Creating and Managing Stores

#### Primary Store Operations

```move
// Look up primary store (auto-creates if needed)
public fun primary_store<T: key>(
    owner: address, 
    metadata: Object<T>
): Object<FungibleStore>

// Manually create primary store
public fun create_primary_store<T: key>(
    owner_addr: address, 
    metadata: Object<T>
): Object<FungibleStore>

// Standard operations (auto-handle store creation)
public entry fun transfer<T: key>(
    sender: &signer,
    metadata: Object<T>,
    recipient: address,
    amount: u64
)
```

#### Secondary Store Creation

```move
// Step 1: Create an Object to get ConstructorRef
let constructor_ref = object::create_object(creator_addr);

// Step 2: Create secondary store 
public fun create_store<T: key>(
    constructor_ref: &ConstructorRef,
    metadata: Object<T>
): Object<FungibleStore>

// The newly created Object becomes a FungibleStore
// Can be reused: metadata object can store its own FA type
// Example: liquidity pool object can store LP tokens
```

### Real-World Implementation Examples

```
PRACTICAL SCENARIOS:
┌─────────────────────────────────────────────────────────────┐
│ PRIMARY STORE EXAMPLES:                                     │
│ ├─ Alice sends 100 USDC to Bob → Bob's primary USDC store  │
│ ├─ Wallet shows balance → reads from primary store         │
│ ├─ DEX withdrawal → deposits to user's primary store       │
│ └─ Cross-chain bridge → auto-creates primary store         │
│                                                             │
│ SECONDARY STORE EXAMPLES:                                   │
│ ├─ Uniswap pool → secondary stores for USDC + APT          │
│ ├─ Lending protocol → separate store for supplied tokens   │
│ ├─ Staking contract → dedicated store for staked assets    │
│ ├─ Game inventory → separate stores for different items    │
│ └─ Multi-sig vault → organized stores for different funds  │
└─────────────────────────────────────────────────────────────┘
```

### Important Technical Considerations

1. **Store Ownership**: "It is crucial to set the correct owner of a FungibleStore object for managing the FA stored inside. By default, the owner of a newly created object is the creator whose signer is passed into the creation function."

2. **Smart Contract Management**: "For FungibleStore objects managed by smart contract itself, the owner should usually be an Object address controlled by the contract. For those cases, those objects should keep their ExtendRef at the proper place to create signer as needed."

3. **Address Complexity**: "There is a caveat that addressing secondary stores on-chain may be more complex" since they don't have deterministic addresses.

4. **Reusability**: "Sometimes an object can be reused as a store. For example, a metadata object can also be a store to hold some FA of its own type or a liquidity pool object can be a store of the issued liquidity pool's coin."

### Migration and Balance Tracking

When migrating from Coin to FA, accounts may have both coin balances and FA balances. Applications should:

- **Sum both balances**: Display the total of CoinStore + PrimaryFungibleStore balances
- **Event handling**: Listen for both coin and FA events during migration period
- **Indexer support**: Use `current_fungible_asset_balances` table for aggregated balance queries

#### Primary Store Operations

```move
module FungibleAssets::PrimaryStoreExample {
    use aptos_framework::fungible_asset::{Self, FungibleAsset, Metadata};
    use aptos_framework::object::Object;
    use aptos_framework::primary_fungible_store;
    
    // ✅ Get user's primary store balance
    public fun get_primary_balance<T: key>(
        user_addr: address,
        metadata: Object<T>
    ): u64 {
        primary_fungible_store::balance(user_addr, metadata)
    }
    
    // ✅ Transfer using primary stores
    public entry fun transfer_primary<T: key>(
        sender: &signer,
        metadata: Object<T>,
        recipient: address,
        amount: u64
    ) {
        // Primary store is created automatically if it doesn't exist
        primary_fungible_store::transfer(sender, metadata, recipient, amount);
    }
    
    // ✅ Deposit to primary store
    public fun deposit_to_primary<T: key>(
        recipient: address,
        fa: FungibleAsset
    ) {
        // Auto-creates primary store if needed
        primary_fungible_store::deposit(recipient, fa);
    }
}
```

#### Secondary Store Operations

```move
module FungibleAssets::SecondaryStoreExample {
    use aptos_framework::fungible_asset::{Self, FungibleAsset, FungibleStore};
    use aptos_framework::object::{Self, Object, ConstructorRef};
    use aptos_framework::primary_fungible_store;
    use std::signer;
    
    struct LiquidityPool has key {
        token_a_store: Object<FungibleStore>,
        token_b_store: Object<FungibleStore>,
    }
    
    // ✅ Create secondary stores for a DEX pool
    public fun create_liquidity_pool<A: key, B: key>(
        creator: &signer,
        token_a_metadata: Object<A>,
        token_b_metadata: Object<B>
    ): address {
        // Create object for the pool
        let constructor_ref = object::create_object(
            signer::address_of(creator)
        );
        let pool_signer = object::generate_signer(&constructor_ref);
        let pool_addr = object::address_from_constructor_ref(
            &constructor_ref
        );
        
        // Create secondary stores for each token
        let token_a_store = fungible_asset::create_store(
            &constructor_ref, 
            token_a_metadata
        );
        let token_b_store = fungible_asset::create_store(
            &constructor_ref, 
            token_b_metadata
        );
        
        // Store pool configuration
        move_to(&pool_signer, LiquidityPool {
            token_a_store,
            token_b_store,
        });
        
        pool_addr
    }
    
    // ✅ Add liquidity using both store types
    public fun add_liquidity<A: key, B: key>(
        user: &signer,
        pool_addr: address,
        token_a_metadata: Object<A>,
        token_b_metadata: Object<B>,
        token_a_amount: u64,
        token_b_amount: u64
    ) acquires LiquidityPool {
        let pool = borrow_global_mut<LiquidityPool>(pool_addr);
        
        // Withdraw from user's primary stores
        let token_a = primary_fungible_store::withdraw(
            user, 
            token_a_metadata, 
            token_a_amount
        );
        let token_b = primary_fungible_store::withdraw(
            user, 
            token_b_metadata, 
            token_b_amount
        );
        
        // Deposit to pool's secondary stores
        fungible_asset::deposit(pool.token_a_store, token_a);
        fungible_asset::deposit(pool.token_b_store, token_b);
    }
}
```

### When to Use Which Store Type

```
USE PRIMARY STORE WHEN:
┌─────────────────────────────────────────────────────────────┐
│ ✅ You need predictable, deterministic addresses            │
│ ✅ Sending tokens to accounts (auto-creation needed)        │
│ ✅ User-to-user transfers                                    │
│ ✅ Exchange deposits/withdrawals                             │
│ ✅ Simple account-based token operations                     │
│ ✅ Default token storage for any account                     │
└─────────────────────────────────────────────────────────────┘

USE SECONDARY STORE WHEN:
┌─────────────────────────────────────────────────────────────┐
│ ✅ Building DeFi protocols (DEX, lending, staking)          │
│ ✅ Smart contracts managing multiple token balances         │
│ ✅ Separating different types of balances                   │
│ ✅ Liquidity pools (separate stores for each token)         │
│ ✅ Escrow or custody services                               │
│ ✅ Gaming applications (inventory management)               │
│ ✅ Complex multi-token operations                           │
└─────────────────────────────────────────────────────────────┘
```


### Best Practices

- Always use `acquires` annotations for global storage access
- Prefer capabilities over address-based access control
- Use events for important state changes
- Choose the right store type for your use case
- Design for upgradability with modular patterns
