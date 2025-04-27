# Aptos Chainlink Shadowing: Questions, Thinking and Investigations 

Reference: https://github.com/smartcontractkit/chainlink-aptos

## Token 

- Using `create_object_address` in `token_state_address_internal`

> Here's Claude's reply:

# Create Object Address in Move (Aptos)

In the Move programming language used by Aptos, `create_object_address` is a crucial function for creating unique addresses for objects in Aptos's object model.

## Object Model Basics

Aptos extends Move with an object model where each object:
- Has a globally unique address
- Can be referenced by this address
- Contains data stored at this address
- May have abilities (store, key, copy, drop)

## The `create_object_address` Function

The `create_object_address` function is part of the Aptos framework and is used to deterministically generate an address for a new object. It's defined in the `aptos_framework::object` module.

### Function Signature

```move
public fun create_object_address(source: &address, seed: vector<u8>): address
```

### Parameters

- `source`: Reference to the creator's address
- `seed`: A byte vector used as a unique seed to generate the object address

### How It Works

1. The function combines the source address and seed
2. It applies a one-way hash function to create a unique, deterministic address
3. This ensures objects with the same creator and seed will have the same address

### Usage Example

```move
use aptos_framework::object;

public fun create_new_object(creator: &signer, seed: vector<u8>) {
    let creator_address = signer::address_of(creator);
    let object_address = object::create_object_address(&creator_address, seed);
    
    // Use this address to create or access the object
    let constructor_ref = object::create_named_object(creator, seed);
    // Additional object setup...
}
```

## Related Object Functions

- `create_named_object`: Creates a new named object using a seed
- `create_object_from_account`: Creates an object from an account
- `object_address_from_constructor_ref`: Gets the address from a constructor reference
- `address_to_object`: Converts an address to an object handle

## Use Cases

- NFT collections where each token needs a unique address
- DeFi applications for unique financial instruments
- Game assets with distinct identifiers
- Object-oriented programming patterns in Move

When `create_object_address` is called multiple times with the same source address and seed, it does not revert - it will always return the same address. This is deterministic by design.

The key distinction between `create_object_address` and `create_named_object` is:

- `create_object_address` is a **pure function** that only computes and returns an address. It doesn't modify any state or create anything on-chain. You can call it any number of times with the same inputs, and it will always return the same address without any side effects.

- `create_named_object` actually **creates the object** at that address. When called again with the same inputs, it will revert with an error (typically "object already exists") because it attempts to initialize an object at an address that's already occupied.

This behavior enables some useful patterns:

1. You can use `create_object_address` to pre-compute or verify addresses without creating objects
2. You can check if an object exists at the computed address before attempting to create it
3. You can recover an object's address even if you don't have a direct reference to it

Example code demonstrating this difference:

```move
use aptos_framework::object::{Self, Object};
use std::signer;

public fun calculate_address(creator: address, seed: vector<u8>): address {
    // This can be called multiple times with no issue
    object::create_object_address(&creator, seed)
}

public fun create_object(creator: &signer, seed: vector<u8>) {
    // This will succeed the first time
    // But revert with "object already exists" on subsequent calls
    let constructor_ref = object::create_named_object(creator, seed);
    
    // Further object initialization...
}

public fun get_or_create_object(creator: &signer, seed: vector<u8>): Object<MyModule> {
    let addr = object::create_object_address(&signer::address_of(creator), seed);
    
    // Check if object exists first
    if (exists<MyType>(addr)) {
        object::address_to_object<MyModule>(addr)
    } else {
        // Create it if not
        let constructor_ref = object::create_named_object(creator, seed);
        // Initialize...
        object::object_from_constructor_ref<MyModule>(&constructor_ref)
    }
}
```

This distinction is important for building robust applications on Aptos, as it allows for predictable object addressing without requiring transactions to fail when objects already exist.

## Events

- Why are they defining events that way? `allowlist_add_events: EventHandle<AllowlistAdd>` and had to create and destroy although they define it with `#[event]` and `struct` which has `drop`? Why do they do it like this?
` I guess it is because they are creating new allowlest per each role, so they want to have event for each as well 
> Here's Claude's answer:

Great question about the different approaches to events in Aptos!

There are two primary ways to define events in Aptos Move:

## 1. Using Event Handles (as shown in your code)

```move
public fun new_with_name(
    event_account: &signer,
    allowlist: vector<address>, 
    allowlist_name: String
): AllowlistState {
    AllowlistState {
        // ...other fields...
        allowlist_add_events: account::new_event_handle(event_account),
        allowlist_remove_events: account::new_event_handle(event_account)
    }
}
```

With this approach:
- You explicitly create event handles using `account::new_event_handle`
- Each handle is tied to a specific signer account
- You emit events using `event::emit_event<T>(&mut event_handle, event_data)`
- These events are stored in a dedicated event store associated with the account

## 2. Using #[event] Tag (Newer Approach)

```move
#[event]
struct AllowlistAddEvent {
    address: address,
    timestamp: u64,
}
```

With this approach:
- You simply define a struct with the `#[event]` attribute
- You emit events using `aptos_framework::event::emit(event_data)`
- No explicit handle creation or signer association is needed
- Events are still indexed and queryable

## Key Differences

1. **Simplicity**: The `#[event]` approach requires less code and is more straightforward

2. **Resource Management**: 
   - Event handles require explicit storage and management
   - `#[event]` handles resource management automatically

3. **Ownership Model**:
   - Event handles are explicitly tied to an account (the signer)
   - `#[event]` events are associated with the module that emits them

4. **Backward Compatibility**:
   - Event handles were the original pattern in Move
   - `#[event]` is a newer pattern that simplifies event emission

5. **Event Filtering**:
   - Event handles allow filtering events by account owner
   - `#[event]` events can be filtered by type but not by explicit owner

The `#[event]` pattern is generally preferred for new development as it's simpler and requires less boilerplate, though the event handle approach gives you more explicit control over event ownership.

I understand your confusion. Let me clarify the two event patterns in Aptos and provide guidance on when to use each:

## Traditional Event Handle Pattern

```move
// In struct definition
struct AllowlistState {
    // ...other fields
    allowlist_add_events: EventHandle<AllowlistAddEvent>,
}

// Creation
new_event_handle(signer)

// Emission
emit_event(&mut event_handle, event_data)

// Destruction
destroy_handle(event_handle)
```

**Use this pattern when:**
- You need account-based filtering and indexing
- You want explicit control over when events can be emitted
- You need to disable event emission at some point
- You're building complex systems where event ownership matters
- Backwards compatibility with existing indexers is important

## #[event] Tag Pattern

```move
#[event]
struct AllowlistAddEvent has drop {
    address: address,
    timestamp: u64,
}

// Emission (much simpler)
aptos_framework::event::emit(event_data)
```

**Use this pattern when:**
- You want simpler, cleaner code with less boilerplate
- Account ownership is less important than the event type itself
- You're building new modules without complex event management needs
- You don't need to disable event emission functionality

## Recommendation

For most new development, especially simpler contracts:
- **Use the #[event] tag pattern** - it's cleaner, simpler, and the recommended approach going forward

For more complex systems, especially when you need:
- Fine-grained control over event emission permissions
- Strong account-based indexing
- Ability to explicitly disable events
- Then the traditional event handle approach may be more appropriate

If you're not sure, the #[event] tag pattern is generally the better default for new code in Aptos, unless you have specific requirements for the control that event handles provide.

Looking at the full code example you shared, I see now that it uses **both event approaches simultaneously**! This is quite interesting and explains your confusion.

In this implementation:

1. The event structs are defined with the `#[event]` tag:
```move
#[event]
struct AllowlistRemove has store, drop {
    allowlist_name: String,
    sender: address
}

#[event]
struct AllowlistAdd has store, drop {
    allowlist_name: String,
    sender: address
}
```

2. The AllowlistState struct maintains traditional event handles:
```move
struct AllowlistState has store {
    // ...other fields
    allowlist_add_events: EventHandle<AllowlistAdd>,
    allowlist_remove_events: EventHandle<AllowlistRemove>
}
```

3. When applying updates, **both** event emission approaches are used:
```move
// Using the #[event] approach
event::emit(
    AllowlistAdd {
        allowlist_name: state.allowlist_name,
        sender: add_address
    }
);

// Using the traditional event handle approach
event::emit_event(
    &mut state.allowlist_add_events,
    AllowlistAdd {
        allowlist_name: state.allowlist_name,
        sender: add_address
    }
);
```

This pattern is actually emitting **two events for each add/remove operation** - one through the modern `emit()` approach and one through the traditional `emit_event()` approach.

This dual approach gives you the benefits of both:
- The simplicity of the #[event] tag pattern
- The account-specific indexing and lifecycle control of the event handle pattern

However, it also doubles the gas cost of event emission and could potentially confuse indexers or users who might see duplicate events.

In most cases, you would choose one approach or the other, not both. This seems to be deliberately implementing both patterns, perhaps for backward compatibility while transitioning to the newer pattern.