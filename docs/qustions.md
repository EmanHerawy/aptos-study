# About 
This document should have list of questions i have during my learning journey 

## Double check my understanding 

## Security related 
- In the tutorial mentioned 
> When we create the Dutch auction Object, we include a TransferRef to let us transfer the NFT without requiring the original owner’s signature. This is especially helpful for finalizing a sale when a bid is placed.

    - if i'm a malicious dev, i can develop my contract that way and transfer user's tokens without their permission ??

## Wondering why/how
 - how can do fork testing? 
 - how to run node in fork testing 
 - how can i run tests against running local network
 - it seems fuzzing is not supported , right ?
 - what are the tools u recommend to use for testing , dev and audit ?
 - i got some wired issue with error code , although it was correctly implemented , wondering why  i got different error code that the one i defined , check reedme for ref to the error 
 
- How can I implement a secure  transaction in an Aptos dApp that requires authorization from two distinct signers? Specifically, I want to call a function like the mint_two example below, which expects both a sender and a recipient signer. What are the security implications of this pattern, and what safeguards should I implement in both the Move module and client application?
```move
module 0x42::example {
  #[resource_group(scope = global)]
  struct ObjectGroup { }
 
  #[resource_group_member(group = 0x42::example::ObjectGroup)]
  struct Monkey has store, key { }
 
  #[resource_group_member(group = 0x42::example::ObjectGroup)]
  struct Toad has store, key { }
 
  fun mint_two(sender: &signer, recipient: &signer) {
    let sender_address = signer::address_of(sender);
 
    let constructor_ref_monkey = &object::create_object(sender_address);
    let constructor_ref_toad = &object::create_object(sender_address);
    let object_signer_monkey = object::generate_signer(&constructor_ref_monkey);
    let object_signer_toad = object::generate_signer(&constructor_ref_toad);
 
    move_to(object_signer_monkey, Monkey{});
    move_to(object_signer_toad, Toad{});
 
    let object_address_monkey = signer::address_of(&object_signer_monkey);
 
    let monkey_object: Object<Monkey> = object::address_to_object<Monkey>(object_address_monkey);
    object::transfer<Monkey>(sender, monkey_object, signer::address_of(recipient));
  }
}


```

- transfer from contract address 
here's what i get from ai , wondering if there's another way 

``text
The issue here is that you're trying to transfer tokens from the contract address back to a player, but you don't have a signer for the contract address.

For tokens that are owned by a contract address, you need to use a resource account pattern to properly manage transfers. Here's how to accomplish this:

1. First, set up a resource account during module initialization:

```rust
struct ModuleData has key {
    signer_cap: account::SignerCapability,
    // other module data
}

fun init_module(deployer: &signer) {
    let seed = b"aptos_fighters";
    let (resource_signer, resource_signer_cap) = account::create_resource_account(deployer, seed);
    
    // Store the signer capability
    move_to(deployer, ModuleData {
        signer_cap: resource_signer_cap,
        // other fields
    });
}
```

2. Then create a function to transfer tokens from the contract to a player:

```rust
public fun transfer_reward_to_player(
    player_add: address, 
    game_token: address, 
    amount_to_withdraw: u64
) acquires ModuleData {
    // Get module address - this should be the same as @aptos_fighters_address
    let module_addr = @aptos_fighters_address;
    
    // Get the resource signer using the stored capability
    let module_data = borrow_global<ModuleData>(module_addr);
    let resource_signer = account::create_signer_with_capability(&module_data.signer_cap);
    
    // Get the token metadata
    let metadata = object::address_to_object<Metadata>(game_token);
    
    // Transfer tokens from the contract to the player
    primary_fungible_store::transfer(&resource_signer, metadata, player_add, amount_to_withdraw);
}
```

3. Use this function in your reward distribution logic:

```rust
public entry fun claim_reward(
    player: &signer,
    game_address: address
) acquires Game, ModuleData {
    let player_add = signer::address_of(player);
    let game = borrow_global_mut<Game>(game_address);
    
    // Game logic to verify the player is eligible for reward
    assert!(player_add == game.player1 || player_add == game.player2, ENOT_A_PLAYER);
    
    let amount_reward = game.game_rules.reward_amount;
    
    // Transfer the reward from contract to player
    transfer_reward_to_player(player_add, game.game_token, amount_reward);
    
    // Update game state
    if (player_add == game.player1) {
        game.player1_reward_claimed = true;
    } else {
        game.player2_reward_claimed = true;
    };
}
```

This approach uses a resource account pattern which is a common approach in Aptos for modules that need to manage assets. The resource account acts as a separate account controlled by your module, and the SignerCapability allows your module to authorize transactions on behalf of that account.
