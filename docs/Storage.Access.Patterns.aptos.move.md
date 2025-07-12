
### Storage Access Patterns
Objects (including resources) on Aptos are owned by both: The account where the object is stored. The module that defines the object

# Storage Access Patterns - Simplified Guide

```
Storage Access Control Matrix:
┌─────────────────────────────────────────────────────────────┐
│ Operation          │ Standard │ Protocol │ Resource │ Other  │
│                    │ Account  │ Module   │ Account  │ Module │
├────────────────────┼──────────┼──────────┼──────────┼────────┤
│ Read own resources │    ✅    │    ✅    │    ✅    │   ❌   │
│ Write own resources│    ✅    │    ✅    │    ✅    │   ❌   │
│ Read others' res   │    ❌    │    🔒    │    🔒    │   🔒   │
│ Write others' res  │    ❌    │    🔒    │    🔒    │   🔒   │
│ Create resources   │    ✅    │    ✅    │    ✅    │   ❌   │
│ Remove resources   │    ✅    │    ✅    │    ✅    │   ❌   │
│ Module operations  │    ❌    │    ✅    │    ❌    │   ❌   │
│ Cross-module calls │    ✅    │    ✅    │    ✅    │   ✅   │
└────────────────────┴──────────┴──────────┴──────────┴────────┘

Legend:
✅ = Always allowed
❌ = Never allowed  
🔒 = Allowed only through module's public API
```

## What This Matrix Really Means

### **Think of Move Like a Bank Building**

Imagine each account is like a **safety deposit box** in a bank, and each module is like a **bank department** with specific rules and procedures.

### **The Four Types of "Actors"**

**1. Standard Account** 🏠  
*A regular user with their own safety deposit box*
- Can freely access their own box (read/write own resources)
- Cannot touch other people's boxes directly (❌ on others' resources)
- Must ask bank staff to help with others' boxes (🔒 through APIs)

**2. Protocol Module** 🏛️  
*A bank department with special procedures*
- Can manage resources under their department's control
- Can help customers access other boxes, but only through official procedures (🔒)
- Has authority to create new services and procedures

**3. Resource Account** 🤖  
*A special automated box controlled by smart contracts*
- Like a vault controlled by computer programs, not humans
- Can store resources but access is controlled by the program logic
- Other accounts can interact with it only through the controlling program's rules

**4. Other Module** 🏢  
*A different bank department*
- Cannot directly access resources from other departments
- Must coordinate through official inter-department procedures
- Can only call public functions, never directly manipulate resources

---

## **The Two Key Rules of Move Security**

### **Rule 1: You Own Your Stuff** 🔐
```move
// ✅ Alice can manage her own balance
public fun withdraw(user: &signer, amount: u64) {
    let user_addr = signer::address_of(user);
    let balance = borrow_global_mut<Balance>(user_addr); // OK - own resource
    balance.amount = balance.amount - amount;
}
```

### **Rule 2: Others' Stuff Requires Permission** 🚪
```move
// ❌ This will NEVER compile - cannot directly access others' resources
public fun steal_money(victim: address) {
    let balance = move_from<Balance>(victim); // ERROR! Not your resource
}

// ✅ This works - goes through proper API with authorization
public fun transfer_with_permission(from: &signer, to: address, amount: u64) {
    bank::transfer(from, to, amount); // Uses bank's official procedure
}
```

---

## **Why the 🔒 Symbol Matters**

When you see 🔒, it means **"Yes, but with strict conditions"**:

### **What 🔒 Actually Means**
- You **cannot** directly grab someone else's resources
- You **can** ask the resource's controlling module to help you
- The module will **check if you're authorized** before doing anything
- The module **controls exactly what operations are allowed**

### **Real Example: Token Transfer**
```move
// The token module defines the rules
module token {
    struct Coin has key { value: u64 }
    
    // ✅ Public API - anyone can call, but with built-in security
    public fun transfer(from: &signer, to: address, amount: u64) {
        // Module checks: Does 'from' actually own this account?
        // Module checks: Does 'from' have enough balance?
        // Module performs: Safe transfer with all validations
    }
}

// Other modules can use the API
module defi_app {
    public fun swap_tokens(user: &signer) {
        // ✅ Uses the official API - safe and authorized
        token::transfer(user, @swap_pool, 100);
    }
}
```
## Key Principle: Module Authority vs Account Ownership

### Resources are NOT "controlled by modules" - they're **controlled by accounts**
**Resources are owned by accounts, but can only be manipulated by their defining module.**


## 1. Resource Ownership vs Module Authority

```move
// Module published at address 0x42
module 0x42::TokenA {
    struct Token has key { amount: u64 }
    
    public fun mint(account: &signer, amount: u64) {
        move_to(account, Token { amount });
    }
    
    public fun transfer(from: &signer, to: address, amount: u64) acquires Token {
        // This module can manipulate Token resources
        let token = move_from<Token>(signer::address_of(from));
        // ... transfer logic ...
        move_to_address(to, token);
    }
}

// Different module at address 0x123  
module 0x123::TokenB {
    struct Token has key { amount: u64 }  // Different type!
    
    // This module CANNOT manipulate 0x42::TokenA::Token
    // Even if both are stored at the same account address
}
```

## Resource Ownership & Cross-Module Transfer

Move's ownership model ensures secure and controlled resource transfers:

### Ownership Rules

Each type T must be declared in the current module. This ensures that a resource can only be manipulated via the API exposed by its defining module.

```
Ownership Control Flow:
┌─────────────────────────────────────────────────────────────┐
│                   MODULE AUTHORITY                          │
│                                                             │
│ module 0x42::bank {                                         │
│   struct Account has key {                                  │
│     balance: u64                                            │
│   }                                                         │
│                                                             │
│   ✅ CAN DO:                                                │
│   • move_to<Account>(&signer, account)                     │
│   • borrow_global<Account>(address)                        │
│   • move_from<Account>(address)                            │
│   • Modify account.balance through references              │
│                                                             │
│   ❌ CANNOT DO (from other modules):                        │
│   • Direct global storage operations on Account            │
│   • Create Account instances outside this module           │
│   • Access private fields directly                         │
│ }                                                           │
└─────────────────────────────────────────────────────────────┘
```

### Cross-Module Transfer Pattern

```
Safe Cross-Module Transfer:
┌─────────────────────────────────────────────────────────────┐
│ module 0x42::token {                                        │
│   struct Token has store {                                  │
│     value: u64                                              │
│   }                                                         │
│                                                             │
│   public fun create(value: u64): Token {                   │
│     Token { value }                                         │
│   }                                                         │
│                                                             │
│   public fun transfer(token: Token, to: &signer) {         │
│     // Token ownership transferred to this function        │
│     // Module controls transfer logic                      │
│     move_to(to, token);                                     │
│   }                                                         │
│ }                                                           │
│                                                             │
│ module 0x43::exchange {                                     │
│   use 0x42::token;                                          │
│                                                             │
│   public fun trade(user: &signer, amount: u64) {           │
│     let token = token::create(amount);  // Get token        │
│     token::transfer(token, user);       // Transfer safely │
│   }                                                         │
│ }                                                           │
└─────────────────────────────────────────────────────────────┘
```

### Resource Ownership vs Module Authority

```
Authority Layers:
┌─────────────────────────────────────────────────────────────┐
│                     AUTHORITY HIERARCHY                     │
│                                                             │
│ Level 1: Account Ownership                                  │
│ ├─ Account controls: Which resources stored at address     │
│ ├─ Signer authority: Who can modify account resources      │
│ └─ Private key: Ultimate control over account              │
│                                                             │
│ Level 2: Module Authority                                   │
│ ├─ Module controls: How resources are created/destroyed    │
│ ├─ Public API: Which operations are allowed                │
│ └─ Business logic: What state transitions are valid        │
│                                                             │
│ Level 3: Type System Authority                              │
│ ├─ Abilities control: What operations are possible         │
│ ├─ Reference safety: Prevents dangling references          │
│ └─ Resource safety: Prevents duplication/loss              │
│                                                             │
│ Level 4: VM Authority                                       │
│ ├─ Bytecode verification: Ensures type safety              │
│ ├─ Gas metering: Prevents infinite loops                   │
│ └─ Execution isolation: Prevents cross-transaction issues  │
└─────────────────────────────────────────────────────────────┘
```
### Resource Storage Reality:
```
Account 0x999 owns:
├── 0x42::TokenA::Token { amount: 100 }   ← Only 0x42::TokenA can manipulate
├── 0x123::TokenB::Token { amount: 50 }   ← Only 0x123::TokenB can manipulate  
└── 0x456::Profile::UserData { ... }     ← Only 0x456::Profile can manipulate
```
```
Address 0x42 publishes TokenModule
├── Code is permanently tied to 0x42
├── Only 0x42 can upgrade this module  
├── All Token resources are controlled by this module
└── No other module can manipulate Token resources
```
## 2. Can Resources Move Between Modules? **NO** (directly)

**You cannot transfer module authority over a resource type.** Once a resource type is defined in a module, only that module can manipulate instances of that type.

### What you CAN'T do:
```move
// ❌ This is impossible
module 0x123::Thief {
    public fun steal_token(victim: address) {
        // ERROR: Cannot manipulate 0x42::TokenA::Token from this module
        let stolen = move_from<0x42::TokenA::Token>(victim);
    }
}
```

### What you CAN do:
```move
// ✅ Cross-module cooperation through public APIs
module 0x42::TokenA {
    struct Token has key { amount: u64 }
    
    public fun transfer_to_module_b(
        from: &signer, 
        to: address, 
        amount: u64
    ) acquires Token {
        // TokenA removes its resource
        let token = move_from<Token>(signer::address_of(from));
        
        // Call TokenB to create equivalent resource
        0x123::TokenB::mint_equivalent(to, token.amount);
        
        // Destroy TokenA resource
        let Token { amount: _ } = token;
    }
}

module 0x123::TokenB {
    struct Token has key { amount: u64 }
    
    public fun mint_equivalent(account: address, amount: u64) {
        move_to_address(account, Token { amount });
    }
}
```

## 3. Why This Restriction Exists

A resource can never be copied, double spent or implicitly discarded, only moved between program storage locations. These safety guarantees are enforced statically by Move's type system.

### Security Benefits:
1. **Module Encapsulation**: Only the defining module can manipulate its resources
2. **Type Safety**: No confusion about which module controls which data
3. **Audit Trail**: Clear ownership and manipulation patterns
4. **Prevention of Unauthorized Access**: Modules can't steal each other's resources

## 4. Practical Patterns for Cross-Module Resource Movement

### Pattern 1: Wrapper/Bridge Pattern
```move
module 0x42::Bridge {
    use 0x123::TokenA;
    use 0x456::TokenB;
    
    public fun swap_a_for_b(
        user: &signer, 
        amount: u64
    ) {
        // Remove TokenA (only TokenA module can do this)
        TokenA::burn(user, amount);
        
        // Create TokenB (only TokenB module can do this)  
        TokenB::mint(user, amount * 2);  // 1:2 exchange rate
    }
}
```

### Pattern 2: Resource Account Pattern
```move
module 0x42::TokenFactory {
    struct Token<phantom CoinType> has key { amount: u64 }
    
    struct USD {}
    struct EUR {}
    
    public fun convert_usd_to_eur(
        user: &signer,
        usd_amount: u64
    ) acquires Token {
        // Same module can manipulate both types
        let usd_token = move_from<Token<USD>>(signer::address_of(user));
        assert!(usd_token.amount >= usd_amount, 1);
        
        // Convert and create EUR token
        let eur_amount = usd_amount * 85 / 100;  // Exchange rate
        move_to(user, Token<EUR> { amount: eur_amount });
        
        // Return remaining USD
        if (usd_token.amount > usd_amount) {
            move_to(user, Token<USD> { 
                amount: usd_token.amount - usd_amount 
            });
        };
        
        let Token { amount: _ } = usd_token;
    }
}
```

### Pattern 3: Object-Based Transfer (Aptos Objects)
Objects have their own address and can own resources similar to an account. They can be transferred as complete packages instead of one resource at a time.

```move
module 0x42::ObjectExample {
    struct GameItem has key {
        power: u64,
        durability: u64,
    }
    
    public fun transfer_item_object(
        from: &signer,
        to: address,
        item_address: address
    ) {
        // Transfer entire object (including all resources)
        object::transfer(from, object::address_to_object<GameItem>(item_address), to);
    }
}
```

## 5. Module Deployment and Code Ownership

In MOVE ecosystem, because of the unique data storage structure defined by Aptos MOVE, the code is published directly under an address, and the address cannot be changed after deployment.


## 6. Summary: What You CAN and CAN'T Do

### ❌ What's Impossible:
- Transfer module authority over a resource type
- Have one module directly manipulate another module's resources
- Change which module controls a resource type after deployment

### ✅ What's Possible:
- Cross-module coordination through public APIs
- Converting between different resource types (burn + mint)
- Transferring resource instances between accounts (within same module)
- Using wrapper modules to coordinate multiple resource types
- Using Objects to group and transfer multiple resources together


---

## **Quick Mental Model**

**For any operation, ask yourself:**

1. **"Who owns this resource?"**
   - If it's yours → ✅ (direct access)
   - If it's others' → Need to use their module's API

2. **"Am I going through the proper API?"**
   - Direct resource access → Only allowed for your own resources
   - API calls → Allowed, but the API will check authorization

3. **"Does the API allow what I want to do?"**
   - The module author decides what operations are safe
   - Authorization is built into the API functions

---

## **Common Beginner Mistakes**

❌ **Thinking you can access any resource if you know the address**
```move
// This thinking comes from other blockchains - doesn't work in Move!
let someone_balance = borrow_global<Balance>(@some_address); // ERROR!
```

✅ **Understanding you must use the module's API**
```move
// This is the Move way - safe and authorized
let balance = bank::get_balance(@some_address); // OK if API allows it
```

❌ **Forgetting that APIs have built-in authorization**
```move
// You can't bypass security by calling the API
bank::transfer(&fake_signer, @victim, 1000); // Won't work - signer verification
```

✅ **Working with the authorization model**
```move
// Proper way - use your own authorization
bank::transfer(&my_signer, @recipient, 100); // Works - you own my_signer
```

---

## **Key Takeaway**

**Move's storage access is like a well-designed building:**
- Everyone has their own private office (own resources) ✅
- You need permission and proper procedures to enter others' offices (API access) 🔒  
- Security guards (the Move VM) prevent unauthorized access ❌
- Building management (module authors) control the access rules

**Resources are owned by accounts, but governed by modules. The module that defines a resource type has permanent, exclusive authority over all instances of that type, regardless of which accounts own those instances.**

This design ensures security and prevents modules from interfering with each other's data, while still allowing sophisticated cross-module interactions through well-defined public APIs.
