
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

---

