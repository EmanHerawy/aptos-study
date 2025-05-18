# Aptos Fungible Asset (FA) Standard - Study Notes

## Overview

The Aptos Fungible Asset (FA) standard provides a type-safe, flexible way to represent fungible assets in the Move ecosystem. Built on the foundation of AIP-73 (Dispatchable Token Standard), it offers significant advantages over the legacy coin module through enhanced customization capabilities and Move object integration.

## Key Concepts

### Foundation: AIP-73 Dispatchable Token Standard

- **Purpose**: Enables token creators to inject custom logic during token operations
- **Technical Approach**: Uses dispatch functions to customize token behavior
- **Innovation**: Simulates runtime function pointers via `function_info.move`
- **Security**: Runtime checks prevent re-entrancy while enabling custom behavior

### Core Components (Move Objects)

1. **Object\<Metadata>**
   - Represents asset details (name, symbol, decimals)
   - Owned by the FA creator

2. **Object\<FungibleStore>**
   - Stores token balances owned by an account
   - References the Metadata Object 
   - Accounts can have multiple stores per FA (advanced cases)

### Advantages Over Coin Standard

- More customizable via smart contract hooks
- Automatic tracking of asset ownership
- Recipients don't need to register separate stores

## Creating a Fungible Asset

### Step 1: Create Non-deletable Object

```move
// Create a named object
let constructor_ref = &object::create_named_object(caller_address, b"TOKEN_NAME");
// Alternatively: object::create_sticky_object(caller_address)
```

### Step 2: Generate Metadata

```move
// Create with primary store enabled for automatic store creation
primary_fungible_store::create_primary_store_enabled_fungible_asset(
    constructor_ref,
    option::some(1000000000),    // Optional maximum supply
    string::utf8(b"My Token"),   // Name
    string::utf8(b"MTK"),        // Symbol
    8,                           // Decimals
    string::utf8(b"https://example.com/icon.png"), // Icon URI
    string::utf8(b"https://example.com")           // Project URI
);
```

### Step 3: Generate Capability References

```move
// Generate capability references during object creation
let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);

// Store refs in a resource
move_to(creator, TokenAdmin { mint_ref, burn_ref, transfer_ref });
```

## Basic Operations

### For Token Holders

#### 1. Withdraw
```move
// Extract tokens from your account
public entry fun withdraw<T: key>(
    owner: &signer,
    metadata_address: address,
    amount: u64
) {
    let metadata = object::address_to_object<T>(metadata_address);
    let fa = primary_fungible_store::withdraw(owner, metadata, amount);
    // Do something with the withdrawn FA...
}
```

#### 2. Deposit
```move
// Add tokens to an account
public entry fun deposit_fa(recipient: address, fa: FungibleAsset) {
    primary_fungible_store::deposit(recipient, fa);
}
```

#### 3. Transfer
```move
// Move tokens between accounts
public entry fun transfer<T: key>(
    sender: &signer,
    metadata_address: address,
    recipient: address,
    amount: u64
) {
    let metadata = object::address_to_object<T>(metadata_address);
    primary_fungible_store::transfer(sender, metadata, recipient, amount);
}
```

#### 4. Check Balance
```move
// View function to get account balance
#[view]
public fun get_balance<T: key>(account: address, metadata_address: address): u64 {
    let metadata = object::address_to_object<T>(metadata_address);
    primary_fungible_store::balance(account, metadata)
}
```

#### 5. Check Frozen Status
```move
// Check if account is frozen
#[view]
public fun check_frozen<T: key>(account: address, metadata_address: address): bool {
    let metadata = object::address_to_object<T>(metadata_address);
    primary_fungible_store::is_frozen(account, metadata)
}
```

### For Token Creators

#### Reading Metadata
```move
// Get basic token information
#[view]
public fun get_metadata_info<T: key>(metadata_address: address): (String, String, u8) {
    let metadata = object::address_to_object<T>(metadata_address);
    
    let name = fungible_asset::name(metadata);
    let symbol = fungible_asset::symbol(metadata);
    let decimals = fungible_asset::decimals(metadata);
    
    (name, symbol, decimals)
}

// Get supply information
#[view]
public fun get_supply_info<T: key>(metadata_address: address): (u128, u128, Option<u128>) {
    let metadata = object::address_to_object<T>(metadata_address);
    
    let supply = fungible_asset::supply(metadata);
    let current_supply = option::none();
    
    if (fungible_asset::has_supply_info(metadata)) {
        current_supply = option::some(fungible_asset::current_supply(metadata));
    }
    
    let maximum_supply = fungible_asset::maximum_supply(metadata);
    
    (supply, option::get_with_default(current_supply, 0), maximum_supply)
}
```

## Implementing Approvals

Unlike ERC-20, Aptos FA doesn't have built-in approvals. There are three implementation approaches:

### 1. Signature-Based Approvals (Recommended)

```move
// Define approval structure
struct Approval has drop {
    owner: address,      // Token owner
    to: address,         // Destination address
    nonce: u64,          // Prevents replay attacks
    chain_id: u8,        // Prevents cross-chain replay
    spender: address,    // Authorized spender
    amount: u64          // Spending amount
}

// Implement transfer_from with signatures
public fun transfer_from(
    spender: &signer,             // Who is spending
    proof: vector<u8>,            // Owner's signature
    from: address,                // Owner's address
    from_account_scheme: u8,      // Signing scheme
    from_public_key: vector<u8>,  // Owner's public key
    to: address,                  // Recipient
    amount: u64                   // Amount to send
) {
    // Create the message that owner should have signed
    let expected_message = Approval {
        owner: from,
        to,
        nonce: account::get_sequence_number(from),
        chain_id: chain_id::get(),
        spender: signer::address_of(spender),
        amount,
    };
    
    // Verify signature matches
    account::verify_signed_message(
        from, 
        from_account_scheme, 
        from_public_key, 
        proof, 
        expected_message
    );
    
    // Perform the transfer
    let transfer_ref = &borrow_global<Management>(token_address()).transfer_ref;
    primary_fungible_store::transfer_with_ref(transfer_ref, from, to, amount);
}
```

### 2. Resource-Based Approvals

```move
// Resource to track allowances
struct Allowances has key {
    values: Table<address, u64>  // spender -> amount
}

// Approve a spender
public entry fun approve(
    owner: &signer,
    spender: address,
    amount: u64
) {
    let owner_addr = signer::address_of(owner);
    
    // Initialize allowances if needed
    if (!exists<Allowances>(owner_addr)) {
        move_to(owner, Allowances { values: table::new() });
    };
    
    // Update allowance
    let allowances = borrow_global_mut<Allowances>(owner_addr);
    if (table::contains(&allowances.values, spender)) {
        *table::borrow_mut(&mut allowances.values, spender) = amount;
    } else {
        table::add(&mut allowances.values, spender, amount);
    }
}

// Transfer on behalf of another account
public entry fun transfer_from(
    spender: &signer,
    owner: address,
    recipient: address,
    amount: u64
) acquires Allowances, Management {
    let spender_addr = signer::address_of(spender);
    
    // Check and update allowance
    assert!(exists<Allowances>(owner), ERROR_NO_ALLOWANCE);
    let allowances = borrow_global_mut<Allowances>(owner);
    assert!(table::contains(&allowances.values, spender_addr), ERROR_NOT_APPROVED);
    
    let allowance = table::borrow_mut(&mut allowances.values, spender_addr);
    assert!(*allowance >= amount, ERROR_INSUFFICIENT_ALLOWANCE);
    *allowance = *allowance - amount;
    
    // Perform transfer
    let transfer_ref = &borrow_global<Management>(token_address()).transfer_ref;
    primary_fungible_store::transfer_with_ref(transfer_ref, owner, recipient, amount);
}
```

### 3. Dispatchable Function Approvals

```move
// Resource to track approvals
struct TokenApprovals has key {
    token_address: address,
    approvals: Table<address, Table<address, u64>> // owner -> (spender -> amount)
}

// Custom withdraw that checks approvals
public fun withdraw<T: key>(
    store: Object<T>,
    amount: u64,
    transfer_ref: &TransferRef,
): FungibleAsset {
    let owner = object::owner(store);
    let caller = tx_context::sender();
    
    // Normal withdrawal (owner withdrawing their own tokens)
    if (owner == caller) {
        return fungible_asset::withdraw_with_ref(transfer_ref, store, amount);
    };
    
    // Check approvals for delegated withdrawal
    if (exists<TokenApprovals>(@token_module)) {
        let approvals = borrow_global<TokenApprovals>(@token_module);
        
        if (table::contains(&approvals.approvals, owner) && 
            table::contains(table::borrow(&approvals.approvals, owner), caller)) {
            
            let allowance = table::borrow_mut(
                table::borrow_mut(&mut approvals.approvals, owner),
                caller
            );
            
            assert!(*allowance >= amount, EINSUFFICIENT_ALLOWANCE);
            *allowance = *allowance - amount;
            
            return fungible_asset::withdraw_with_ref(transfer_ref, store, amount);
        };
    };
    
    abort EUNAUTHORIZED
}
```

## Implementing Custom Token Logic (AIP-73)

### Create Custom Hook Functions

```move
// Example: Deflation token with 1% fee on withdrawals
public fun withdraw<T: key>(
    store: Object<T>,
    amount: u64,
    transfer_ref: &TransferRef,
): FungibleAsset {
    // Calculate burn amount (1% fee)
    let burn_amount = amount / 100;
    
    // Withdraw the full amount
    let total_fa = fungible_asset::withdraw_with_ref(transfer_ref, store, amount);
    
    // Apply fee logic
    if (burn_amount > 0) {
        let burn_ref = get_burn_ref();
        let burn_fa = fungible_asset::extract(&mut total_fa, burn_amount);
        fungible_asset::burn(burn_ref, burn_fa);
    }
    
    // Return remaining tokens
    total_fa
}
```

### Register Hook Functions

```move
public fun create_token_with_hooks(creator: &signer) {
    // Create token metadata object
    let constructor_ref = &object::create_named_object(creator, b"MY_TOKEN");
    
    // Set up token with standard parameters
    primary_fungible_store::create_primary_store_enabled_fungible_asset(
        constructor_ref,
        option::none(),                  // No supply limit
        string::utf8(b"My Custom Token"),
        string::utf8(b"MCT"),
        8,
        string::utf8(b"https://example.com/logo.png"),
        string::utf8(b"https://example.com")
    );
    
    // Create FunctionInfo for custom functions
    let withdraw_func = function_info::new_function_info(
        creator,
        string::utf8(b"my_token_module"),
        string::utf8(b"withdraw")
    );
    
    let deposit_func = function_info::new_function_info(
        creator,
        string::utf8(b"my_token_module"),
        string::utf8(b"deposit")
    );
    
    // Register custom functions with the token
    dispatchable_fungible_asset::register_dispatch_functions(
        constructor_ref,
        option::some(withdraw_func),    // Custom withdraw
        option::some(deposit_func),     // Custom deposit
        option::none()                  // Default balance calculation
    );
    
    // Generate and store capability references
    let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
    let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
    let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);
    
    move_to(creator, TokenAuthority { mint_ref, burn_ref, transfer_ref });
}
```

## Store Management

# Understanding Secondary Stores in Aptos Fungible Assets

Secondary stores are an advanced feature of the Aptos Fungible Asset standard that provide more flexibility in managing token balances. Let me explain them in detail:

## Primary vs. Secondary Stores

### Primary Store
- Each account has exactly **one primary store** per fungible asset type
- Created automatically when tokens are first received
- Has a deterministic address (predictable based on owner address and token metadata)
- Cannot be deleted (always available)
- Most users will only ever interact with their primary store

### Secondary Store
- An account can have **multiple secondary stores** for the same asset type
- Must be explicitly created (not automatic)
- Has a non-deterministic address (created wherever you specify)
- Can be deleted when empty
- Used primarily for advanced use cases

## Why Use Secondary Stores?

Secondary stores are useful in several scenarios:

1. **Smart Contract-Managed Assets**: When a contract needs to manage multiple distinct pools of the same token

2. **Escrow and Vesting**: Holding tokens in separate buckets with different withdrawal rules

3. **Protocol-Owned Liquidity**: When a protocol needs to segregate funds for different purposes

4. **Complex DeFi Applications**: Like lending protocols that need to track supplied vs. borrowed tokens separately

5. **Delegation**: When you want to allow another entity to manage some (but not all) of your tokens

## How to Create a Secondary Store

Creating a secondary store requires creating an object to own the store:

```move
// First create an object to own your secondary store
let constructor_ref = object::create_object(owner);

// Then create a fungible store owned by this object
let store = fungible_asset::create_store(
    &constructor_ref, 
    metadata_object
);
```

## Example Use Case: A Simple Escrow

Here's a simplified example showing how secondary stores might be used in an escrow:

## Key Points About Secondary Stores

1. **Ownership Structure**: Secondary stores are owned by objects, not directly by accounts. This allows for more complex ownership patterns.

2. **Lifecycle Management**: Unlike primary stores, secondary stores can be deleted when empty, which helps manage blockchain storage.

3. **Addressing Challenge**: The non-deterministic nature of secondary store addresses means your contract needs to track and manage these addresses.

4. **Access Control**: You need to maintain the appropriate permissions (through ExtendRef and object signers) to interact with secondary stores.

5. **Use Cases**: Secondary stores shine in use cases where you need isolation of funds or more complex token management:
   - Staking pools
   - Escrow services
   - Liquidity pools
   - Token vesting contracts
   - Multi-signature wallets

## Practical Differences

Here's a practical comparison:

| Feature | Primary Store | Secondary Store |
|---------|--------------|----------------|
| Creation | Automatic | Manual |
| Address | Deterministic | Non-deterministic |
| Quantity | One per token type | Unlimited |
| Deletion | Not possible | Possible when empty |
| Typical use | Personal wallets | Smart contracts |
| Access | Direct via account | Via object with ExtendRef |

## When to Use Which Store Type

- **Use Primary Store** for: Regular user balances, simple token transfers, basic token operations
- **Use Secondary Store** for: Protocol-owned liquidity, escrow services, complex DeFi applications, fund isolation

In most cases, regular users will only ever interact with their primary stores, while secondary stores are more commonly used within smart contracts for advanced token management scenarios.
## Migration from Coin to FA

- No modifications needed for contracts using coin module
- Automatic creation of paired FA when required
- Use `paired_metadata<CoinType>()` to get metadata for paired FA

```move
// Check total balance across coin and FA
#[view]
public fun get_total_balance<CoinType>(user: address): u64 {
    // Get coin balance
    let coin_balance = coin::balance<CoinType>(user);
    
    // Get paired FA balance if exists
    let fa_balance = if (coin::paired_metadata<CoinType>().is_some()) {
        let metadata = option::extract(&mut coin::paired_metadata<CoinType>());
        primary_fungible_store::balance(user, metadata)
    } else {
        0
    };
    
    coin_balance + fa_balance
}
```
# Deep Dive: Comparing Fungible Asset Withdrawal Methods

Let's thoroughly analyze the differences between these two withdrawal approaches:

```move
let fa = fungible_asset::withdraw(&escrow_signer, escrow.token_metadata, amount);
```

versus 

```move
let fa = primary_fungible_store::withdraw(owner, token_metadata, amount);
```

## Fundamental Differences

### 1. Module Namespace & Function Location

- **fungible_asset::withdraw**: Operates directly on any FungibleStore (primary or secondary)
- **primary_fungible_store::withdraw**: Specifically targets only primary stores (a convenience wrapper)

### 2. Parameter Types & Signatures

Let's look at the actual function signatures (simplified):

```move
// fungible_asset.move
public fun withdraw<T>(
    owner: &signer,
    metadata: Object<T>,
    amount: u64
): FungibleAsset

// primary_fungible_store.move
public fun withdraw<T>(
    owner: &signer,
    metadata: Object<T>,
    amount: u64
): FungibleAsset
```

While they initially appear similar, they operate very differently:

### 3. Store Location & Derivation

- **fungible_asset::withdraw**: 
  - Requires the signer to be the direct owner of the specific FungibleStore (which could be any store)
  - Operates on any arbitrary store for which you have the signer
  
- **primary_fungible_store::withdraw**: 
  - Automatically determines the primary store address using a deterministic formula
  - Works only with the one primary store associated with an owner-metadata pair
  - Formula: `sha3_256(32-byte account address | 32-byte metadata object address | 0xFC)`

### 4. Store Creation & Management

- **fungible_asset::withdraw**: 
  - Assumes the store already exists
  - Doesn't handle store creation

- **primary_fungible_store::withdraw**:
  - May auto-create the primary store if it doesn't exist (in some implementations)
  - Manages the "one primary store per account per token" constraint

### 5. Underlying Implementation

When you call `primary_fungible_store::withdraw`, it:

1. Calculates the deterministic address of your primary store
2. Creates it if needed (depending on implementation)
3. Ultimately calls `fungible_asset::withdraw` under the hood

The `fungible_asset::withdraw` function is more primitive and expects you to:

1. Know exactly which store you're targeting
2. Have the appropriate permissions (signer) for that specific store

## Practical Implications

### For the Escrow Example

```move
// Using direct fungible_asset::withdraw with a secondary store
let fa = fungible_asset::withdraw(&escrow_signer, escrow.token_metadata, amount);
```

Here:
- `escrow_signer` is generated from the ExtendRef, allowing the escrow object to act as a signer
- This withdrawal occurs from the secondary store owned by the escrow object
- We're directly accessing a specific store at a non-deterministic address

```move
// Using primary_fungible_store::withdraw
let fa = primary_fungible_store::withdraw(owner, token_metadata, amount);
```

Here:
- `owner` is the user's signer
- This withdrawal happens from the owner's primary store for this token
- We don't need to know the store's address - it's derived automatically

### Implementation Deep Dive

Let's examine how these might be implemented (simplified):

```move
// How primary_fungible_store::withdraw likely works under the hood
public fun withdraw<T: key>(owner: &signer, metadata: Object<T>, amount: u64): FungibleAsset {
    let owner_addr = signer::address_of(owner);
    
    // Calculate the deterministic address of the primary store
    let store_addr = calculate_primary_store_address(owner_addr, object::object_address(&metadata));
    
    // Get or create the store
    if (!exists<FungibleStore>(store_addr)) {
        create_primary_store(owner_addr, metadata);
    }
    
    // Get a reference to the store
    let store = object::address_to_object<FungibleStore>(store_addr);
    
    // Now call the base withdraw function
    fungible_asset::withdraw_internal(owner, store, amount)
}

// How fungible_asset::withdraw might work
public fun withdraw<T: key>(owner: &signer, metadata: Object<T>, amount: u64): FungibleAsset {
    let owner_addr = signer::address_of(owner);
    
    // You must provide the correct signer that directly owns the store
    // No automatic derivation of which store to use
    let store = get_fungible_store(owner_addr, metadata);
    
    // Direct withdrawal from the specified store
    withdraw_internal(owner, store, amount)
}
```

## Critical Differences in Use Cases

### When to Use `fungible_asset::withdraw`:

1. **Smart Contract Architectures**: When you need a contract to control funds in a store it owns
2. **Complex Store Management**: When managing multiple stores for the same token
3. **Custom Permission Models**: When implementing custom withdrawal permissions
4. **Protocol-Owned Liquidity**: When a protocol needs direct control over its funds
5. **When Working with Object Signers**: Like in the escrow example where the store is owned by an object

### When to Use `primary_fungible_store::withdraw`:

1. **User Wallets**: For standard user operations with their own tokens
2. **Simplified Applications**: When you only need the default primary store behavior
3. **User Interactions**: When users are directly signing transactions to withdraw their tokens
4. **Single Store per Token**: When you follow the simple one-store-per-token model
5. **When Working with User Signers**: Like in standard token transfers where users move their own tokens

## Security Implications

The distinction also has security implications:

- **fungible_asset::withdraw** requires precise control over signers and store addresses, introducing more potential for errors if mismanaged
- **primary_fungible_store::withdraw** has built-in safeguards as it only accesses the primary store of the signing account

## Real-World Context

In production DeFi applications:

- **DEXes** often use secondary stores to manage liquidity pools
- **Lending protocols** might use secondary stores to segregate collateral from borrowed assets
- **User wallets** typically interact only with primary stores
- **DAO treasuries** might use secondary stores to isolate funds for different purposes

By understanding these nuances, you can make architectural decisions that best suit your application's needs while maintaining security and clarity in your token management approach.


## Security Best Practices

### 1. Preventing Re-entrancy

```move
// SAFE pattern: Complete all local computation first
public fun secure_withdraw<T: key>(
    store: Object<T>,
    amount: u64,
    transfer_ref: &TransferRef
): FungibleAsset {
    // Do all state checking before making calls
    let is_valid = check_some_condition();
    assert!(is_valid, EINVALID_CONDITION);
    
    // Then perform external calls
    fungible_asset::withdraw_with_ref(transfer_ref, store, amount)
}
```

### 2. Token Creator Best Practices

- Store sensitive Refs (MintRef, BurnRef) in secure resources
- Use non-deletable objects for Metadata
- Set maximum_supply when appropriate
- Implement proper access control for admin operations

### 3. Dispatchable Token Developer Best Practices

- Use only `with_ref` APIs in custom hooks
- Never create cycles in the call graph
- Always check frozen status in custom withdraw logic
- Handle potential arithmetic overflows/underflows

### 4. DApp Developer Integration Best Practices

- Check if a token uses dispatchable functionality
- Be aware that tokens may implement custom transfer logic
- Always check frozen status before transfers
- Test with edge cases (zero amount, very large amount)

I understand the confusion. Let me rewrite the explanation with clearer, side-by-side code examples to show exactly when and how to use each module.

# `fungible_asset` vs `primary_fungible_store`

## Core Differences

| `fungible_asset` | `primary_fungible_store` |
|------------------|--------------------------|
| Works directly with token objects and stores | Works with accounts and automates store management |
| Lower-level, more control | Higher-level, more convenience |
| Requires explicit store references | Automatically finds/creates stores |
| Used for token creation and advanced operations | Used for everyday token operations |

## Side-by-Side Examples

Let me show you concrete examples of the same operations using both modules:

### 1. Reading Token Metadata

Both modules can access metadata, but in different ways:

```move
// Using fungible_asset (requires metadata object)
public fun get_metadata_info_1(metadata: Object<Metadata>): (String, String, u8) {
    let name = fungible_asset::name(metadata);
    let symbol = fungible_asset::symbol(metadata);
    let decimals = fungible_asset::decimals(metadata);
    
    (name, symbol, decimals)
}

// Using primary_fungible_store (same approach, it doesn't add abstraction for metadata)
public fun get_metadata_info_2<T: key>(metadata_address: address): (String, String, u8) {
    let metadata = object::address_to_object<T>(metadata_address);
    
    // Still uses fungible_asset for metadata access
    let name = fungible_asset::name(metadata);
    let symbol = fungible_asset::symbol(metadata);
    let decimals = fungible_asset::decimals(metadata);
    
    (name, symbol, decimals)
}
```

### 2. Transferring Tokens

This is where we see a major difference in how the modules operate:

```move
// Using fungible_asset (requires explicit store objects and transfer_ref)
public fun transfer_tokens_1(
    from_store: Object<FungibleStore>,
    to_store: Object<FungibleStore>,
    amount: u64,
    transfer_ref: &TransferRef
) {
    // First withdraw from source store
    let fa = fungible_asset::withdraw_with_ref(
        transfer_ref,
        from_store,
        amount
    );
    
    // Then deposit to destination store
    fungible_asset::deposit_with_ref(
        transfer_ref,
        to_store,
        fa
    );
}

// Using primary_fungible_store (just need accounts and metadata)
public fun transfer_tokens_2(
    sender: &signer,
    metadata: Object<Metadata>,
    recipient: address,
    amount: u64
) {
    // One simple call handles everything:
    // - Finding sender's store
    // - Creating recipient's store if needed
    // - Withdrawing tokens
    // - Depositing tokens
    primary_fungible_store::transfer(
        sender,
        metadata,
        recipient,
        amount
    );
}
```

### 3. Checking a Balance

```move
// Using fungible_asset (requires store object)
public fun check_balance_1(store: Object<FungibleStore>): u64 {
    fungible_asset::balance(store)
}

// Using primary_fungible_store (just need account and metadata)
public fun check_balance_2(account: address, metadata: Object<Metadata>): u64 {
    primary_fungible_store::balance(account, metadata)
}
```

### 4. Withdrawing Tokens

```move
// Using fungible_asset (needs store and transfer_ref)
public fun withdraw_tokens_1(
    store: Object<FungibleStore>,
    amount: u64,
    transfer_ref: &TransferRef
): FungibleAsset {
    fungible_asset::withdraw_with_ref(
        transfer_ref,
        store,
        amount
    )
}

// Using primary_fungible_store (just needs owner and metadata)
public fun withdraw_tokens_2(
    owner: &signer,
    metadata: Object<Metadata>,
    amount: u64
): FungibleAsset {
    primary_fungible_store::withdraw(
        owner,
        metadata,
        amount
    )
}
```

### 5. Creating a Token (Only with fungible_asset)

This operation can only be done with `fungible_asset`:

```move
public fun create_token(
    creator: &signer,
    maximum_supply: Option<u128>,
    name: String,
    symbol: String,
    decimals: u8,
    icon_uri: String,
    project_uri: String
): (Object<Metadata>, MintRef, TransferRef, BurnRef) {
    // Create object
    let constructor_ref = object::create_named_object(creator, b"MY_TOKEN");
    
    // Initialize metadata
    fungible_asset::create_metadata(
        &constructor_ref,
        name,
        symbol,
        decimals,
        icon_uri,
        project_uri
    );
    
    // Configure for primary store usage
    primary_fungible_store::create_primary_store_enabled_fungible_asset(
        &constructor_ref,
        maximum_supply,
        name,
        symbol,
        decimals,
        icon_uri,
        project_uri
    );
    
    // Generate capability references
    let mint_ref = fungible_asset::generate_mint_ref(&constructor_ref);
    let transfer_ref = fungible_asset::generate_transfer_ref(&constructor_ref);
    let burn_ref = fungible_asset::generate_burn_ref(&constructor_ref);
    
    // Return metadata object and capability references
    (object::object_from_constructor_ref<Metadata>(&constructor_ref), 
     mint_ref, transfer_ref, burn_ref)
}
```

## When to Use Each Module

### Use `fungible_asset` when:
1. **Creating tokens**: Initial setup, generating capability references
2. **Advanced use cases**: Working with multiple stores per user
3. **Direct store manipulation**: When you have store objects directly
4. **Custom token logic**: Implementing hooks via AIP-73

### Use `primary_fungible_store` when:
1. **Standard user operations**: Transfers, deposits, withdrawals
2. **DApp integration**: Simpler interfaces for common operations
3. **Account-level operations**: Working with user addresses, not stores
4. **Automatic store management**: Want stores to be created as needed

## Practical Example: Creating and Using a Token

```move
// Module that creates and manages a token
module example::my_token {
    use std::string;
    use std::signer;
    use std::option::{Self, Option};
    use aptos_framework::object::{Self, Object, ConstructorRef};
    use aptos_framework::fungible_asset::{Self, Metadata, FungibleAsset, MintRef, TransferRef, BurnRef};
    use aptos_framework::primary_fungible_store;
    
    // Resources to store capability references
    struct TokenAdmin has key {
        mint_ref: MintRef,
        burn_ref: BurnRef,
        transfer_ref: TransferRef,
    }
    
    // Store metadata object address for easy reference
    struct TokenInfo has key {
        metadata: Object<Metadata>,
    }
    
    // Initialize the token (using fungible_asset)
    public entry fun initialize(admin: &signer) {
        let constructor_ref = object::create_named_object(admin, b"MY_TOKEN");
        
        // Create metadata and enable primary store
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            &constructor_ref,
            option::some(1000000000), // 1 billion max supply
            string::utf8(b"My Token"),
            string::utf8(b"MTK"),
            8, // 8 decimals
            string::utf8(b"https://example.com/icon.png"),
            string::utf8(b"https://example.com")
        );
        
        // Generate references using fungible_asset
        let mint_ref = fungible_asset::generate_mint_ref(&constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(&constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(&constructor_ref);
        
        let metadata = object::object_from_constructor_ref<Metadata>(&constructor_ref);
        
        // Store references for admin use
        move_to(admin, TokenAdmin { 
            mint_ref, 
            burn_ref, 
            transfer_ref 
        });
        
        // Store metadata info for easy access
        move_to(admin, TokenInfo {
            metadata
        });
    }
    
    // Mint tokens (admin only, using fungible_asset)
    public entry fun mint(
        admin: &signer,
        recipient: address,
        amount: u64
    ) acquires TokenAdmin {
        // Get mint reference
        let admin_addr = signer::address_of(admin);
        let token_admin = borrow_global<TokenAdmin>(admin_addr);
        
        // Mint tokens using fungible_asset
        let tokens = fungible_asset::mint(&token_admin.mint_ref, amount);
        
        // Deposit to recipient using primary_fungible_store
        primary_fungible_store::deposit(recipient, tokens);
    }
    
    // Transfer tokens (user operation, using primary_fungible_store)
    public entry fun transfer(
        sender: &signer,
        recipient: address,
        amount: u64
    ) acquires TokenInfo {
        // Get metadata
        let token_info = borrow_global<TokenInfo>(@example);
        
        // Transfer using primary_fungible_store (simpler API)
        primary_fungible_store::transfer(
            sender,
            token_info.metadata,
            recipient,
            amount
        );
    }
    
    // Freeze an account (admin only, direct use of transfer_ref)
    public entry fun freeze_account(
        admin: &signer,
        account: address
    ) acquires TokenAdmin, TokenInfo {
        let admin_addr = signer::address_of(admin);
        let token_admin = borrow_global<TokenAdmin>(admin_addr);
        let token_info = borrow_global<TokenInfo>(@example);
        
        // Get the user's store
        let store = primary_fungible_store::ensure_primary_store_exists(
            account,
            token_info.metadata
        );
        
        // Freeze using fungible_asset (requires store and transfer_ref)
        fungible_asset::set_frozen_flag(&token_admin.transfer_ref, store, true);
    }
}
```

This distinction is crucial for building applications on Aptos:
- `fungible_asset` gives you direct control but requires more parameters
- `primary_fungible_store` simplifies common operations by handling store management automatically


## Why Store the Refs?

When you create a fungible asset, the references (mint_ref, transfer_ref, burn_ref) are critical because they contain the permissions to control your token. These refs are essentially your "admin keys" that let you:

1. **Mint new tokens** (using mint_ref)
2. **Freeze/unfreeze transfers** (using transfer_ref)
3. **Burn tokens** (using burn_ref)

### If You Don't Store Them:

If you generate these refs but don't store them anywhere, they'll be **destroyed at the end of the transaction**. This would mean:

- You could never mint more tokens after initialization
- You could never burn tokens
- You could never use the transfer control features

Essentially, your token would still exist, but you'd lose all administrative control over it.

### How Storage Works:

In the complete example I provided, the refs are stored in a resource called `AdminCapability`:

```move
// Struct to hold admin capabilities
struct AdminCapability has key {
    mint_ref: MintRef,
    burn_ref: BurnRef,
    transfer_ref: TransferRef,
    extend_ref: ExtendRef,
}

// Later in the code...
// 5. Store admin capabilities
move_to(admin, AdminCapability {
    mint_ref,
    burn_ref,
    transfer_ref,
    extend_ref,
});
```

This creates a resource at the admin's address that contains all the refs. Then, when you want to perform admin actions like minting, you access these stored refs:

```move
// In the mint function
let admin_cap = borrow_global<AdminCapability>(admin_addr);
let fa = fungible_asset::mint(&admin_cap.mint_ref, amount);
```

## Use Cases for Different Storage Approaches:

1. **Store on admin account**: Most straightforward - the account that deploys the contract holds all admin powers.

2. **Store in a multi-sig account**: For projects requiring multiple approvals for minting/burning.

3. **Store partially**: You might choose to only store the mint_ref but destroy the burn_ref if you want tokens that can never be burned.

4. **Destroy all refs**: In rare cases, you might want a fixed supply token where no one (not even you) can change the supply - then you'd intentionally not store the refs.

5. **Store in smart contract**: For advanced use cases, you might store the refs in a smart contract that controls when and how tokens are minted/burned based on code logic rather than direct human action.

Great follow-up question! The `extend_ref: ExtendRef` is a bit more advanced but very useful for certain token scenarios. Let me explain:

## Why You Need an ExtendRef

The `ExtendRef` allows you to "extend" your Move Object with additional functionality and resources after it's been created. This is different from the token-specific refs (mint_ref, burn_ref, transfer_ref).

### Key Use Cases for ExtendRef:

1. **Adding Custom Properties Later**
   
   If you want to add new features or properties to your token's metadata object after it's created, you need the ExtendRef. For example, you might want to add:
   - New token attributes
   - Additional functionality
   - Integration with other protocols

2. **Creating a Signer from an Object**

   The ExtendRef allows you to generate a "signer" for your object, which means the object itself can perform actions as if it were an account. This is powerful for:
   - Having an object (like your token metadata) control resources
   - Creating autonomous objects that can manage their own state
   - Building more complex DeFi applications where the token itself has agency

3. **Managing Secondary Stores**

   For advanced use cases where your token needs to manage multiple fungible stores:
   - The object might need to act as its own entity
   - Control resources at its own address
   - Manage secondary stores that it owns

4. **Upgradeability**

   For projects that might need to evolve over time:
   - Add new features to your token
   - Update token behavior within the constraints of Move
   - Integrate with new standards that emerge

### Example Use of ExtendRef

Here's a simple example of how you might use the ExtendRef:

```move
// Adding a new feature to your token later
public entry fun add_feature(admin: &signer) acquires AdminCapability {
    let admin_addr = signer::address_of(admin);
    let admin_cap = borrow_global<AdminCapability>(admin_addr);
    
    // Generate a signer for the object using extend_ref
    let metadata_signer = object::generate_signer_for_extending(&admin_cap.extend_ref);
    
    // Now you can add resources to the metadata object
    // For example, adding a new feature like staking capabilities
    move_to(&metadata_signer, NewFeature { ... });
}
```

### When You Might Not Need ExtendRef

You might not need to store the ExtendRef if:

1. Your token is completely immutable after creation
2. You have no plans to add new features or capabilities
3. Your token doesn't need to interact with other protocols in complex ways

However, even in these cases, it's often good practice to store it anyway. Having it available gives you flexibility for the future without any real downsides.

### In Summary

The ExtendRef provides future-proofing and flexibility to your token. While the MintRef, BurnRef, and TransferRef control the core token functions, the ExtendRef allows your token to evolve and adapt over time. This is particularly important in blockchain development where future use cases may emerge that weren't initially planned for.