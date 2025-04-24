# Move Security Guidelines - Study Notes
## some info based on wokring with code 
- In Move, you can only return references that are derived from function parameters, not from global storage. This is a safety mechanism to prevent dangling references and ensure memory safety. 
example : 
``` move 
/*
error: cannot return a reference derived from struct `aptos_fighters::Game` since it is not based on a parameter
    ┌─ C:\Users\EmanELHerawy\out\aptos-study-notes\demos\aptos_fighters\sources\aptos_fighters.move:479:9
    │
478 │         let game = borrow_global_mut<Game>(signer::address_of(&resource_signer));
    │                    ------------------------------------------------------------- struct `aptos_fighters::Game` previously mutably borrowed here
479 │         game
    │         ^^^^ return attempted here
*/
fun get_game_mut():&mut Game acquires ModuleData, Game {
    let module_addr = @aptos_fighters_address;
    
    // Get the resource signer using the stored capability
    let module_data = borrow_global<ModuleData>(module_addr);
    let resource_signer = account::create_signer_with_capability(&module_data.signer_cap);
    
    let game = borrow_global_mut<Game>(signer::address_of(&resource_signer));
    game
}
```
## Access Control

### Object Ownership Check
- **Issue**: `Object<T>` can be accessed by anyone, even non-owners
- **Solution**: Always verify the signer is the rightful owner
- **Secure Pattern**:
  ```move
  assert!(object::owner(&obj) == address_of(user), ENOT_OWNER);
  ```

### Global Storage Access Control
- **Issue**: Accepting `&signer` alone doesn't ensure proper access control
- **Solution**: Use global storage operations tied to signer's address
- **Insecure Pattern**:
  ```move
  public fun delete(user: &signer, obj: Object) {
    let Object { data } = obj;
  }
  ```
- **Secure Pattern**:
  ```move
  public fun delete(user: &signer) {
    let Object { data } = move_from<Object>(signer::address_of(user));
  }
  ```

### Function Visibility
- **Principle**: Use least privilege
- **Visibility Levels**:
  | Visibility | Module itself | Other Modules | Aptos CLI/SDK |
  |------------|--------------|--------------|---------------|
  | private | ✅ | ⛔ | ⛔ |
  | public(friend) | ✅ | ✅ if friend | ⛔ |
  | public | ✅ | ✅ | ⛔ |
  | entry | ✅ | ⛔ | ✅ |
- Can combine entry with public or public(friend)

## Types and Data Structures

### Generics Type Check
- **Issue**: Unchecked generics can lead to type confusion and exploits
- **Solution**: Use phantom type parameters to ensure type safety
- **Insecure Pattern**:
  ```move
  struct Receipt {
    amount: u64
  }
  
  public fun repay_flash_loan<T>(rec: Receipt, coins: Coin<T>) {
    // No guarantee that T matches the originally loaned coin type
  }
  ```
- **Secure Pattern**:
  ```move
  struct Receipt<phantom T> {
    amount: u64
  }
  
  public fun repay_flash_loan<T>(rec: Receipt<T>, coins: Coin<T>) {
    // T must match the type in Receipt
  }
  ```

### Resource Management and Unbounded Execution
- **Issue**: Iterating over unbounded public structures risks DoS attacks
- **Recommendations**:
  - Store user-specific assets in individual accounts
  - Keep module data in Objects separate from user data 
  - Use efficient data structures (e.g., SmartTable instead of vectors)
- **Insecure Pattern**:
  ```move
  // O(n) operation on a global vector anyone can add to
  public fun get_order_by_id(order_id: u64): Option<Order> acquires OrderStore {
    let order_store = borrow_global_mut<OrderStore>(@admin);
    // Iterate through potentially unlimited vector
    while (i < vector::length(&order_store.orders)) { ... }
  }
  ```
- **Secure Pattern**:
  ```move
  // O(1) operation using appropriate data structure
  public fun get_order_by_id(user: &signer, order_id: u64): Option<Order> acquires OrderStore {
    let order_store = borrow_global_mut<OrderStore>(signer::address_of(user));
    if (smart_table::contains(&order_store.orders, order_id)) {
      let order = smart_table::borrow(&order_store.orders, order_id);
      option::some(*order)
    } else {
      option::none<Order>()
    }
  }
  ```

## Move Abilities
- **key abilities**:
  - `copy`: Permits duplicating values
  - `drop`: Allows values to be discarded
  - `store`: Enables data storage in global storage
  - `key`: Allows data to serve as key in global storage

- **Security Concerns**:
  - Inappropriate `copy` on tokens could enable double-spending
  - `drop` on resources like FlashLoan could permit loan evasion

## Arithmetic Operations

### Division Precision
- **Issue**: Integer division truncates (rounds down), potentially allowing users to bypass fees
- **Solutions**:
  1. Set minimum thresholds: `MIN_ORDER_SIZE: u64 = 10000 / PROTOCOL_FEE_BPS + 1`
  2. Validate results: `assert!(fee > 0, 0)`

### Integer Operations
- Addition (`+`) and multiplication (`*`): Abort on overflow
- Subtraction (`-`): Aborts if result < 0
- Division (`/`): Aborts if divisor = 0
- Left shift (`<<`): Does NOT abort on overflow (unique case)

## Aptos Objects

### ConstructorRef Leak
- **Issue**: Exposing ConstructorRef allows manipulation of object
- **Solution**: Never return ConstructorRef from public functions

### Object Accounts
- **Issue**: Multiple resources in one object account can lead to unintended transfers
- **Solution**: Store objects at separate object accounts
- **Insecure Pattern**:
  ```move
  // Both Monkey and Toad in same object account
  let constructor_ref = &object::create_object_from_account(sender);
  move_to(sender_object_signer, Monkey{});
  move_to(sender_object_signer, Toad{});
  // Transferring Monkey will transfer all resources
  ```
- **Secure Pattern**:
  ```move
  // Create separate object accounts
  let constructor_ref_monkey = &object::create_object(sender_address);
  let constructor_ref_toad = &object::create_object(sender_address);
  ```

## Business Logic

### Front-running
- **Issue**: Attackers can observe pending transactions and act on future information
- **Solution**: Combine operations into a single transaction
- **Secure Pattern**:
  ```move
  public fun finalize_lottery(admin: &signer, winning_number: u64) {
    set_winner_number(admin, winning_number);
    evaluate_bets_and_determine_winners(admin);
  }
  ```

### Price Oracle Manipulation
- **Issue**: Single-source oracles can be manipulated
- **Solution**: Use multiple oracles with tiered design

### Token Identifier Collision
- **Issue**: Naive token identification can lead to collisions
- **Solution**: Use unique object addresses rather than symbols/names
- **Secure Pattern**:
  ```move
  // Use object addresses for uniqueness
  vector::append(&mut seeds, bcs::to_bytes(&object::object_address(&token_1)));
  ```

## Operations

### Pausing Functionality
- **Recommendation**: Implement pause mechanism for emergency situations
- **Pattern**:
  ```move
  public entry fun pause_protocol(admin: &signer) {
    assert!(signer::address_of(admin)==@protocol_address, ERR_NOT_ADMIN);
    let state = borrow_global_mut<State>(@protocol_address);
    state.is_paused = true;
  }
  ```

## Randomness Security

### Test-and-Abort Attacks
- **Issue**: Public functions with randomness allow repeated attempts
- **Solution**: Use `private` `entry` functions with `#[randomness]` attribute

### Undergasing Attacks
- **Issue**: Different execution paths consume different gas
- **Solutions**:
  1. Ensure better outcomes use more gas
  2. Limit randomness API to admin addresses
  3. Separate randomness generation from actions