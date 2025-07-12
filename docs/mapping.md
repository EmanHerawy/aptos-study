 There are several data structure options in Aptos Move for implementing mappings, each with different trade-offs. Let me break down the key differences:

### 2. Table Storage Ecosystem

Move provides several table-based storage solutions, with SmartTable deprecated in favor of BigOrderedMap for better performance and features.

## **Complete Table Storage Architecture**

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                        MOVE TABLE STORAGE EVOLUTION                                │
└─────────────────────────────────────────────────────────────────────────────────────┘

DEPRECATED COLLECTIONS:
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ ❌ SimpleMap    → Replaced with OrderedMap                                          │
│ ❌ SmartTable   → Replaced with BigOrderedMap                                       │
└─────────────────────────────────────────────────────────────────────────────────────┘

CURRENT TABLE ECOSYSTEM:
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                     │
│ ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐          │
│ │    Table    │    │Table w/Len  │    │ OrderedMap  │    │BigOrderedMap│          │
│ │             │    │             │    │             │    │             │          │
│ │• Basic K/V  │    │• With length│    │• Sorted     │    │• B+ Tree    │          │
│ │• Separate   │    │• tracking   │    │• Single     │    │• Multi-slot │          │
│ │  storage    │    │             │    │  resource   │    │• Scalable   │          │
│ │• Native     │    │             │    │• Vector-    │    │• Parallel   │          │
│ │  functions  │    │             │    │  based      │    │  execution  │          │
│ └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘          │
│        │                  │                  │                  │                │
│        ▼                  ▼                  ▼                  ▼                │
│ Each item is      Adds counter     Stored within    Spans multiple              │
│ separate global   for efficiency   parent resource  resources as               │
│ state item                         (limited size)   needed                     │
└─────────────────────────────────────────────────────────────────────────────────────┘

DETAILED STORAGE COMPARISON:
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              TABLE STORAGE                                         │
├─────────────┬─────────────┬─────────────┬─────────────┬────────────────────────────┤
│    TYPE     │  STORAGE    │   SIZE      │ PARALLELISM │        BEST FOR            │
├─────────────┼─────────────┼─────────────┼─────────────┼────────────────────────────┤
│   Table     │ Separate    │ Unlimited   │    Full     │ Large datasets, no         │
│             │ items       │             │             │ ordering needed            │
├─────────────┼─────────────┼─────────────┼─────────────┼────────────────────────────┤
│TableWithLen │ Separate    │ Unlimited   │    Full     │ Table + count tracking     │
│             │ items       │             │             │                            │
├─────────────┼─────────────┼─────────────┼─────────────┼────────────────────────────┤
│ OrderedMap  │ Single      │ Limited by  │   Limited   │ Small-medium sorted data   │
│             │ resource    │ resource    │             │ (< 1000 items)            │
├─────────────┼─────────────┼─────────────┼─────────────┼────────────────────────────┤
│BigOrderedMap│ Multi-      │ Unlimited   │   Partial   │ Large sorted data,         │
│             │ resource    │             │             │ complex queries            │
└─────────────┴─────────────┴─────────────┴─────────────┴────────────────────────────┘

BIGORDEREDMAP INTERNAL STRUCTURE:
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           B+ TREE IMPLEMENTATION                                   │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                              ROOT NODE                                             │
│ ┌─────────────────────────────────────────────────────────────────────────────────┐ │
│ │ Address: 0x123::BigOrderedMap                                                   │ │
│ │ ┌─────────────────────────────────────────────────────────────────────────────┐ │ │
│ │ │ TreeNode {                                                                  │ │ │
│ │ │   keys: [100, 500, 1000],                                                  │ │ │
│ │ │   children: [Child1, Child2, Child3, Child4],                              │ │ │
│ │ │   is_leaf: false,                                                           │ │ │
│ │ │   size: 4                                                                   │ │ │
│ │ │ }                                                                           │ │ │
│ │ └─────────────────────────────────────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────────────────────────────────┘ │
│                                      │                                             │
│                 ┌────────────────────┼────────────────────┐                       │
│                 │                    │                    │                       │
│                 ▼                    ▼                    ▼                       │
│ ┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐     │
│ │   LEAF NODE 1       │    │   LEAF NODE 2       │    │   LEAF NODE 3       │     │
│ │ Address: 0x456...   │    │ Address: 0x789...   │    │ Address: 0xABC...   │     │
│ │ ┌─────────────────┐ │    │ ┌─────────────────┐ │    │ ┌─────────────────┐ │     │
│ │ │ Keys: [1,5,10]  │ │    │ │ Keys:[101,250]  │ │    │ │ Keys:[501,750]  │ │     │
│ │ │ Values: [...]   │ │    │ │ Values: [...]   │ │    │ │ Values: [...]   │ │     │
│ │ │ is_leaf: true   │ │    │ │ is_leaf: true   │ │    │ │ is_leaf: true   │ │     │
│ │ └─────────────────┘ │    │ └─────────────────┘ │    │ └─────────────────┘ │     │
│ └─────────────────────┘    └─────────────────────┘    └─────────────────────┘     │
│                                                                                     │
│ CHARACTERISTICS:                                                                   │
│ ├─ inner_max_degree: Maximum children per inner node                              │
│ ├─ leaf_max_degree: Maximum key-value pairs per leaf                              │
│ ├─ Dynamic Growth: Splits nodes when they exceed capacity                         │
│ └─ Efficient Range Queries: O(log n) + result size                               │
└─────────────────────────────────────────────────────────────────────────────────────┘

PERFORMANCE COMPARISON (1M Elements):
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           OPERATION PERFORMANCE                                    │
├─────────────────┬─────────────────┬─────────────────┬─────────────────────────────┤
│   OPERATION     │   SmartTable    │  BigOrderedMap  │          NOTES              │
├─────────────────┼─────────────────┼─────────────────┼─────────────────────────────┤
│ Insert          │ O(1) avg        │ O(log n)        │ BigOrderedMap more          │
│                 │ O(n) worst      │                 │ predictable                 │
├─────────────────┼─────────────────┼─────────────────┼─────────────────────────────┤
│ Lookup          │ O(1) avg        │ O(log n)        │ Similar for most sizes      │
│                 │ O(n) worst      │                 │                             │
├─────────────────┼─────────────────┼─────────────────┼─────────────────────────────┤
│ Range Query     │ Not supported   │ O(log n + k)    │ k = result size             │
├─────────────────┼─────────────────┼─────────────────┼─────────────────────────────┤
│ Storage Eff.    │ Hash overhead   │ Tree structure  │ BigOrderedMap more          │
│                 │                 │ only            │ storage efficient           │
├─────────────────┼─────────────────┼─────────────────┼─────────────────────────────┤
│ Parallelism     │ Sequential only │ Partial support │ BigOrderedMap allows        │
│                 │                 │                 │ some parallelism            │
└─────────────────┴─────────────────┴─────────────────┴─────────────────────────────┘
```

### **Table Storage Code Examples:**

```move
module AdvancedStorage::TableExamples {
    use aptos_std::table::{Self, Table};
    use aptos_std::table_with_length::{Self, TableWithLength};
    use aptos_std::ordered_map::{Self, OrderedMap};
    use aptos_std::big_ordered_map::{Self, BigOrderedMap};
    
    struct UserRegistry has key {
        // Basic table - separate storage items
        user_profiles: Table<address, UserProfile>,
        
        // Table with length tracking
        user_scores: TableWithLength<address, u64>,
        
        // Ordered map - sorted, single resource
        leaderboard: OrderedMap<u64, address>, // score -> user
        
        // Big ordered map - scalable sorted storage
        transaction_history: BigOrderedMap<u64, Transaction>, // timestamp -> tx
    }
    
    struct UserProfile has store {
        name: vector<u8>,
        level: u64,
        reputation: u64,
    }
    
    struct Transaction has store {
        from: address,
        to: address,
        amount: u64,
        timestamp: u64,
    }
    
    // Initialize all storage types
    public fun create_registry(admin: &signer) {
        move_to(admin, UserRegistry {
            user_profiles: table::new(),
            user_scores: table_with_length::new(),
            leaderboard: ordered_map::new(),
            transaction_history: big_ordered_map::new(),
        });
    }
    
    // Table operations
    public fun register_user(
        admin: &signer,
        user_addr: address,
        name: vector<u8>
    ) acquires UserRegistry {
        let registry = borrow_global_mut<UserRegistry>(signer::address_of(admin));
        
        // Add to table
        table::add(&mut registry.user_profiles, user_addr, UserProfile {
            name,
            level: 1,
            reputation: 0,
        });
        
        // Add to table with length
        table_with_length::add(&mut registry.user_scores, user_addr, 0);
    }
    
    // OrderedMap operations (for small, sorted data)
    public fun update_leaderboard(
        admin: &signer,
        user_addr: address,
        new_score: u64
    ) acquires UserRegistry {
        let registry = borrow_global_mut<UserRegistry>(signer::address_of(admin));
        
        // Remove old score if exists
        if (ordered_map::contains(&registry.leaderboard, &new_score)) {
            ordered_map::remove(&mut registry.leaderboard, &new_score);
        };
        
        // Add new score
        ordered_map::add(&mut registry.leaderboard, new_score, user_addr);
    }
    
    // BigOrderedMap operations (for large, sorted data)
    public fun record_transaction(
        admin: &signer,
        from: address,
        to: address,
        amount: u64
    ) acquires UserRegistry {
        let registry = borrow_global_mut<UserRegistry>(signer::address_of(admin));
        let timestamp = timestamp::now_seconds();
        
        big_ordered_map::add(&mut registry.transaction_history, timestamp, Transaction {
            from,
            to,
            amount,
            timestamp,
        });
    }
    
    // Range query with BigOrderedMap
    public fun get_transactions_in_range(
        registry_addr: address,
        start_time: u64,
        end_time: u64
    ): vector<Transaction> acquires UserRegistry {
        let registry = borrow_global<UserRegistry>(registry_addr);
        let transactions = vector::empty<Transaction>();
        
        // Efficient range query
        let iter = big_ordered_map::iter(&registry.transaction_history, 
                                         option::some(start_time), 
                                         option::some(end_time));
        
        while (big_ordered_map::iter_has_next(&iter)) {
            let (_, tx) = big_ordered_map::iter_next(&mut iter);
            vector::push_back(&mut transactions, *tx);
        };
        
        transactions
    }
    
    // Batch operations for efficiency
    public fun batch_update_scores(
        admin: &signer,
        users: vector<address>,
        scores: vector<u64>
    ) acquires UserRegistry {
        let registry = borrow_global_mut<UserRegistry>(signer::address_of(admin));
        
        // Single borrow for all operations
        let i = 0;
        let len = vector::length(&users);
        while (i < len) {
            let user = *vector::borrow(&users, i);
            let score = *vector::borrow(&scores, i);
            
            if (table_with_length::contains(&registry.user_scores, user)) {
                *table_with_length::borrow_mut(&mut registry.user_scores, user) = score;
            } else {
                table_with_length::add(&mut registry.user_scores, user, score);
            };
            
            i = i + 1;
        }
    }
}
```

## 1. `table::Table`

```move
use aptos_std::table::{Self, Table};

struct MyStruct has key {
    mapping: Table<address, u64>
}
```

**Characteristics:**
- **Storage**: Off-chain storage (more gas efficient)
- **Size tracking**: No automatic size tracking
- **Iteration**: Cannot iterate over entries
- **Gas cost**: Lower for individual operations

## 2. `table_with_length::TableWithLength`

```move
use aptos_std::table_with_length::{Self, TableWithLength};

struct MyStruct has key {
    mapping: TableWithLength<address, u64>
}
```

**Characteristics:**
- **Storage**: Off-chain storage (gas efficient)
- **Size tracking**: ✅ Automatic length tracking
- **Iteration**: Cannot iterate over entries
- **Gas cost**: Slightly higher than Table (due to length tracking)
- **Extra functionality**: `length()`, `empty()` functions

## 3. `smart_table::SmartTable`

```move
use aptos_std::smart_table::{Self, SmartTable};

struct MyStruct has key {
    mapping: SmartTable<address, u64>
}
```

**Characteristics:**
- **Storage**: Hybrid (small tables on-chain, large tables off-chain)
- **Size tracking**: ✅ Automatic length tracking
- **Iteration**: ✅ Can iterate with `for_each`, `map_ref`, etc.
- **Gas cost**: Dynamic based on size
- **Performance**: Optimized for both small and large datasets

## 4. `simple_map::SimpleMap`

```move
use aptos_std::simple_map::{Self, SimpleMap};

struct MyStruct has key {
    mapping: SimpleMap<address, u64>
}
```

**Characteristics:**
- **Storage**: On-chain (vector-based)
- **Size tracking**: ✅ Automatic length tracking
- **Iteration**: ✅ Full iteration support
- **Gas cost**: Higher for large datasets
- **Performance**: Good for small datasets (< 100 entries)

## Comparison Table

| Feature | Table | TableWithLength | SmartTable | SimpleMap |
|---------|-------|-----------------|------------|-----------|
| **Storage** | Off-chain | Off-chain | Hybrid | On-chain |
| **Length tracking** | ❌ | ✅ | ✅ | ✅ |
| **Iteration** | ❌ | ❌ | ✅ | ✅ |
| **Gas (small)** | Low | Low | Medium | Medium |
| **Gas (large)** | Low | Low | Low | High |
| **Best for** | Simple KV | KV + size | General use | Small datasets |

## When to Use Each

### Use `Table` when:
- Simple key-value storage
- Don't need size information
- Don't need iteration
- Want lowest gas costs

```move
// Example: User balances
struct Balances has key {
    balances: Table<address, u64>  // Just lookup by address
}
```

### Use `TableWithLength` when:
- Need to track number of entries
- Don't need iteration
- Want gas efficiency

```move
// Example: Tracking number of holders
struct TokenHolders has key {
    holders: TableWithLength<address, u64>,
    // Can call table_with_length::length(&holders) to get count
}
```

### Use `SmartTable` when:
- Need iteration capabilities
- Want best of both worlds (gas + features)
- General-purpose mapping

```move
// Example: Complex operations
struct Marketplace has key {
    listings: SmartTable<u64, ListingInfo>  // Can iterate through all listings
}

public fun get_all_listings(): vector<ListingInfo> {
    let result = vector::empty();
    smart_table::for_each_ref(&marketplace.listings, |_key, listing| {
        vector::push_back(&mut result, *listing);
    });
    result
}
```

### Use `SimpleMap` when:
- Small datasets (< 100 entries)
- Need full iteration
- Don't mind higher gas for large datasets

```move
// Example: User permissions (limited number)
struct Permissions has key {
    user_roles: SimpleMap<address, Role>  // Small set of admin users
}
```

## Performance Considerations

### Gas Costs (Approximate):
```
Insert/Update/Delete:
Table < TableWithLength < SmartTable < SimpleMap (for large datasets)

Iteration:
SimpleMap ≈ SmartTable (Table/TableWithLength: impossible)

Size queries:
TableWithLength ≈ SmartTable ≈ SimpleMap (Table: impossible)
```

### Memory Usage:
```
Off-chain: Table, TableWithLength, SmartTable (large)
On-chain: SimpleMap, SmartTable (small)
```

## Recommendation

For most use cases, **`SmartTable`** is the best choice because:
- Automatically optimizes based on size
- Provides all features (length, iteration)
- Good gas efficiency
- Future-proof design

Use the others only when you have specific constraints or performance requirements.

Great question! Let me clarify what "off-chain" and "on-chain" storage mean in the context of Aptos Move data structures.

## Important Clarification

When I said "off-chain storage" for Tables, I was **imprecise**. Let me correct that:

**All data in Aptos Move is stored on-chain**. The difference is in **how the data is organized and accessed** within the blockchain state.

## The Real Difference: Storage Layout

### "On-chain" (Direct Resource Storage)
```move
// SimpleMap example
struct MyData has key {
    map: SimpleMap<address, u64>  // Data stored directly in the resource
}
```

**How it works:**
- All key-value pairs are stored **directly in the resource**
- When you read the resource, you get **all the data at once**
- Data is serialized as part of the resource

**Storage visualization:**
```
Resource at 0x123: {
  map: {
    data: [
      (0xaaa, 100),
      (0xbbb, 200), 
      (0xccc, 300)
    ]
  }
}
```

### "Off-chain" (Table/Handle-based Storage)
```move
// Table example  
struct MyData has key {
    map: Table<address, u64>  // Only stores a "handle" in the resource
}
```

**How it works:**
- The resource only stores a **handle/pointer** to the table
- Individual key-value pairs are stored **separately** in the state tree
- Each entry has its own storage location

**Storage visualization:**
```
Resource at 0x123: {
  map: Handle(12345)  // Just a pointer
}

Separate table entries:
Handle(12345) + hash(0xaaa) -> 100
Handle(12345) + hash(0xbbb) -> 200  
Handle(12345) + hash(0xccc) -> 300
```

## Why This Matters

### Gas Efficiency Differences

**SimpleMap (Direct Storage):**
```move
// Reading the resource loads ALL data
let resource = borrow_global<MyData>(addr);  // Loads entire map
let value = simple_map::borrow(&resource.map, &key);
```
- ❌ Must load entire map even to access one value
- ❌ Gas cost grows with map size

**Table (Handle-based Storage):**
```move
// Reading only loads the specific entry
let resource = borrow_global<MyData>(addr);  // Loads only the handle
let value = table::borrow(&resource.map, key);  // Loads only this entry
```
- ✅ Only loads the specific key-value pair
- ✅ Constant gas cost regardless of table size

### Performance Implications

**Large Dataset Example:**
```move
// 10,000 entries

// SimpleMap: Must load all 10,000 entries to access one value
// Gas: High (proportional to total size)

// Table: Loads only the requested entry  
// Gas: Low (constant)
```

## Technical Implementation

### Table Handle System
```move
struct Table<K, V> has store {
    handle: address,  // Points to table data in state tree
}
```

**Under the hood:**
1. Table gets a unique handle (address)
2. Each key-value pair stored at: `handle + hash(key)`
3. Only requested entries are loaded from storage

### SimpleMap Vector System
```move
struct SimpleMap<K, V> has store {
    data: vector<Element<K, V>>,  // All data stored here
}
```

**Under the hood:**
1. All entries stored in a single vector
2. Entire vector must be loaded to access any element
3. Linear search through vector for lookups

## SmartTable: Hybrid Approach

```move
struct SmartTable<K, V> has store {
    inline_table: vector<Element<K, V>>,  // Small data stored directly
    table: Table<K, V>,                   // Large data uses handle system
    level: u8,                            // Determines when to switch
}
```

**Behavior:**
- **Small datasets** (< threshold): Uses direct storage like SimpleMap
- **Large datasets** (> threshold): Automatically switches to handle-based storage
- **Best of both worlds**: Fast for small, efficient for large

## Summary

| Type | Storage Method | Load Behavior | Best For |
|------|----------------|---------------|----------|
| **SimpleMap** | Direct in resource | Loads all data | Small datasets |
| **Table** | Handle-based | Loads only requested entry | Large datasets |
| **SmartTable** | Hybrid | Adapts based on size | General use |

Excellent question! Let me break down the differences in each operation across the different data structures:

## 1. **Storing/Inserting** New Entries

### SimpleMap
```move
simple_map::add(&mut map, key, value);
```
**Performance:** O(n) - must check for duplicates by scanning entire vector
**Gas:** Increases with map size
**Behavior:** Appends to vector, but first scans to prevent duplicates

### Table
```move
table::add(&mut table, key, value);
```
**Performance:** O(1) - direct hash-based insertion
**Gas:** Constant regardless of table size
**Behavior:** Directly stores at computed address

### TableWithLength
```move
table_with_length::add(&mut table, key, value);
```
**Performance:** O(1) + length increment
**Gas:** Constant + small overhead for length tracking
**Behavior:** Same as Table + increments counter

### SmartTable
```move
smart_table::add(&mut table, key, value);
```
**Performance:** O(1) for large tables, O(n) for small inline tables
**Gas:** Adaptive based on current storage mode
**Behavior:** May trigger migration from inline to handle-based storage

## 2. **Reading/Accessing** Entries

### SimpleMap
```move
let value = simple_map::borrow(&map, &key);
```
**Performance:** O(n) - linear search through vector
**Gas:** Proportional to map size (loads entire vector)
**Behavior:** Must load and scan entire data structure

### Table
```move
let value = table::borrow(&table, key);
```
**Performance:** O(1) - direct hash lookup
**Gas:** Constant (loads only specific entry)
**Behavior:** Computes storage address and loads single entry

### TableWithLength
```move
let value = table_with_length::borrow(&table, key);
```
**Performance:** O(1) - same as Table
**Gas:** Constant (loads only specific entry)
**Behavior:** Identical to Table for reads

### SmartTable
```move
let value = smart_table::borrow(&table, key);
```
**Performance:** O(1) for large tables, O(n) for small inline tables
**Gas:** Constant for large, proportional for small
**Behavior:** Uses appropriate method based on current storage mode

## 3. **Updating** Existing Entries

### SimpleMap
```move
let value_ref = simple_map::borrow_mut(&mut map, &key);
*value_ref = new_value;
```
**Performance:** O(n) to find entry + O(1) to update
**Gas:** Must load entire map, then write back entire map
**Behavior:** Finds entry in vector, modifies in place, writes entire vector

### Table
```move
let value_ref = table::borrow_mut(&mut table, key);
*value_ref = new_value;
```
**Performance:** O(1) - direct access and update
**Gas:** Constant (loads and writes only specific entry)
**Behavior:** Direct modification of single storage location

### TableWithLength
```move
let value_ref = table_with_length::borrow_mut(&mut table, key);
*value_ref = new_value;
```
**Performance:** O(1) - same as Table
**Gas:** Constant (loads and writes only specific entry)
**Behavior:** Identical to Table for updates

### SmartTable
```move
let value_ref = smart_table::borrow_mut(&mut table, key);
*value_ref = new_value;
```
**Performance:** O(1) for large, O(n) for small
**Gas:** Constant for large, proportional for small
**Behavior:** Updates using appropriate method

## 4. **Deleting** Entries

### SimpleMap
```move
let (key, value) = simple_map::remove(&mut map, &key);
```
**Performance:** O(n) - find entry + O(n) - shift remaining elements
**Gas:** High (loads entire map, modifies, writes back)
**Behavior:** Finds entry, removes it, shifts vector elements to fill gap

### Table
```move
let value = table::remove(&mut table, key);
```
**Performance:** O(1) - direct removal
**Gas:** Constant (removes only specific entry)
**Behavior:** Directly deletes storage location

### TableWithLength
```move
let value = table_with_length::remove(&mut table, key);
```
**Performance:** O(1) + length decrement
**Gas:** Constant + small overhead for length tracking
**Behavior:** Same as Table + decrements counter

### SmartTable
```move
let value = smart_table::remove(&mut table, key);
```
**Performance:** O(1) for large, O(n) for small
**Gas:** Adaptive, may trigger migration back to inline storage
**Behavior:** May reorganize storage method if size threshold crossed

## 5. **Size Queries**

### SimpleMap
```move
let size = simple_map::length(&map);
```
**Performance:** O(1) - stored as vector length
**Gas:** Low (just reads length field)

### Table
```move
// ❌ Not supported!
```
**Performance:** N/A
**Gas:** N/A

### TableWithLength
```move
let size = table_with_length::length(&table);
```
**Performance:** O(1) - counter maintained
**Gas:** Very low (single field read)

### SmartTable
```move
let size = smart_table::length(&table);
```
**Performance:** O(1) - counter maintained
**Gas:** Very low (single field read)

## 6. **Iteration**

### SimpleMap
```move
simple_map::for_each_ref(&map, |k, v| {
    // Process each entry
});
```
**Performance:** O(n) - iterate through vector
**Gas:** High (loads entire map)
**Behavior:** Direct vector iteration

### Table
```move
// ❌ Not supported!
```
**Performance:** N/A (impossible to iterate)
**Gas:** N/A

### TableWithLength
```move
// ❌ Not supported!
```
**Performance:** N/A (impossible to iterate)
**Gas:** N/A

### SmartTable
```move
smart_table::for_each_ref(&table, |k, v| {
    // Process each entry
});
```
**Performance:** O(n) - must visit all entries
**Gas:** Variable (efficient iteration implementation)
**Behavior:** Optimized iteration over both storage types

## Performance Summary

| Operation | SimpleMap | Table | TableWithLength | SmartTable |
|-----------|-----------|-------|-----------------|------------|
| **Insert** | O(n), High Gas | O(1), Low Gas | O(1), Low Gas | O(1)/O(n), Adaptive |
| **Read** | O(n), High Gas | O(1), Low Gas | O(1), Low Gas | O(1)/O(n), Adaptive |
| **Update** | O(n), High Gas | O(1), Low Gas | O(1), Low Gas | O(1)/O(n), Adaptive |
| **Delete** | O(n), High Gas | O(1), Low Gas | O(1), Low Gas | O(1)/O(n), Adaptive |
| **Size** | O(1), Low Gas | ❌ | O(1), Very Low | O(1), Very Low |
| **Iterate** | O(n), High Gas | ❌ | ❌ | O(n), Variable |

## Recommendation by Use Case

- **Small, frequently accessed maps (< 50 entries)**: SimpleMap
- **Large, simple key-value storage**: Table
- **Large storage with size tracking**: TableWithLength  
- **General purpose, unknown size**: SmartTable (most versatile)

The key insight is that **handle-based storage** (Table, TableWithLength) provides much better gas efficiency for large datasets because you only pay for the data you actually access, while **direct storage** (SimpleMap) loads everything at once.