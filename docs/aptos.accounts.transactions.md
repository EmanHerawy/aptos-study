## Account & Transactions

### Accounts Basics
- Accounts are identified by a 32-byte address
- Format: `0x00000000000000000000000000000000` (preferred with leading zeros and 0x)
- ⚠️ Accounts on Aptos are explicit and need to be created before they can execute transactions
- Authentication uses key rotation capability
- Every account has:
  - Resources (including coin storage AND smart contracts called "modules")
  - Increasing sequence number to prevent replay attacks
  - Authentication key
  - Event handles
- Smart Contracts live inside the Account that deployed it, and are referenced like `0x00000000000000000000000000000001::module_name::function_name`

### Account Creation
```python
# Creating an account
from aptos_sdk.account import Account
new_account = Account.generate()
```

### Address Standards
- Three representations:
  - Full form with 0x: `0x00000000000000000000000000000001` (preferred)
  - Short form: `0x1`
  - No 0x prefix: `00000000000000000000000000000001`
- ⚠️ Addresses in the range from 0x0 to 0xf (inclusive) are special addresses that can use short form representation

---

## Transaction Handling

### Transaction Basics
- Transactions encoded in Binary Canonical Serialization (BCS)
- Contains: sender address, authentication, operation, gas limit/price
- Each transaction has a unique version number
- Transaction success is indicated by `success` and `vm_status` fields

### Transaction Types
1. **Entry Function** - Call to module entry function
2. **Move Script** - Execute custom Move code

### Transaction Flow
1. Submit transaction
2. Pre-execution validation in Mempool
3. Transmission between Mempool nodes
4. Inclusion in consensus proposal
5. Final pre-execution validation
6. Execution and commit to storage

### Transaction Status and Simulation
- Check status: `/transactions/by_hash/{hash}`
- Simulate transactions: `/transactions/simulate`
- Recommended poll interval: 30-60 seconds

### Example Transaction Flow
```typescript
// Example using TS-SDK
import { Aptos, Ed25519Account, Ed25519PrivateKey } from "@aptos-labs/ts-sdk";

const aptos = new Aptos();
const account = new Ed25519Account({privateKey: new Ed25519PrivateKey("private key")})
const transaction = await aptos.transferCoinTransaction({
    sender: account.accountAddress, 
    recipient: "receiver address", 
    amount: 100000000
})
const pendingTransaction = await aptos.transaction.signAndSubmitTransaction({
    signer: account, 
    transaction
})
const committedTransaction = await aptos.waitForTransaction({
    transactionHash: pendingTransaction.hash
});
```

---

## Asset Standards

### Two Asset Standards
1. **Coin Standard** (legacy)
   - Similar to ERC-20
   - Uses `0x1::coin::CoinStore<CoinType>` for storage
   - ⚠️ Legacy coin modules go into maintenance mode; FA‑only docs published

2. **Fungible Asset Standard** (current/preferred)
   - More featured and advanced, replacing the legacy Coin resource model
   - Uses `fungible_asset::FungibleStore` objects
   - More composable and developer-friendly compared to legacy Coins

### APT Token
- Native token of Aptos
- ⚠️  APT will be migrated starting on June 30, 2025
- All tokens on Aptos will begin migrating automatically from Coin v1 to the FA standard. No action is required from users
- Subunit: octa (1 APT = 100,000,000 octas)

### Key Differences: Coin vs Fungible Asset

| Feature | Coin Standard | Fungible Asset Standard |
|---------|---------------|-------------------------|
| Storage | `CoinStore<CoinType>` resource per account | `FungibleStore` objects |
| Type Definition | Compile-time generics (CoinType) | Runtime metadata objects |
| Extensibility | Limited by struct constraints | More customizable via Move Objects |
| Account Registration | Manual registration required | Automatically handles tracking balances |
| Status | Legacy/Maintenance | Current/Preferred |

### Checking Balances

#### Coin Balance (Legacy)
```typescript
// Check coin balance
const [balanceStr] = await aptos.view<[string]>({
  payload: {
    function: "0x1::coin::balance",
    typeArguments: [coinType],
    functionArguments: [account]
  }
});
```

#### Fungible Asset Balance (Current)
```typescript
// Check fungible asset balance
const [balanceStr] = await aptos.view<[string]>({
  payload: {
    function: "0x1::primary_fungible_store::balance",
    typeArguments: ["0x1::object::ObjectCore"],
    functionArguments: [account, faMetadataAddress]
  }
});
```

### Tracking Balance Changes
- Monitor events and changes in transactions:
  - `0x1::coin::WithdrawEvent` (legacy)
  - `0x1::coin::DepositEvent` (legacy)
  - `0x1::fungible_asset::Withdraw` (current)
  - `0x1::fungible_asset::Deposit` (current)
- Gas fees only tracked for APT token 

### Transferring Assets

#### Coin Transfer (Legacy)
```typescript
// Legacy method for transferring coins
0x1::aptos_account::transfer_coins<CoinType>(receiver address, amount)
```

#### Fungible Asset Transfer (Current)
```typescript
// Current method for transferring fungible assets
0x1::primary_fungible_store::transfer<0x1::object::ObjectCore>(receiver address, amount)
```

---

## Multisig Accounts
If you're coming from Ethereum/Solidity, note that Aptos handles multisig accounts differently. Aptos implements multisig directly at the protocol level, allowing accounts to require multiple signatures without deploying additional smart contracts.

### Multisig Concept
- Protocol-level multisig (not smart contract-based)
- Configurable K-of-N signature scheme
- Uses `MultiPublicKey` and `MultiSignature`

### Multisig Transaction Flow
1. Create transaction with multisig address as sender
2. Collect K signatures from authorized signers
3. Combine signatures into a multisig authenticator
4. Submit signed transaction

## Exchange Integration

### Infrastructure Recommendations
- Run your own full node
- Use Indexer for efficient data queries

### Balance Tracking
- Query balances using appropriate view functions
- Monitor events for balance changes
- ⚠️ **IMPORTANT**: Handle both Coin and Fungible Asset standards during migration period

### Deposit/Withdrawal Handling
1. **Monitor Events**:
   - `0x1::coin::DepositEvent` for coin deposits (legacy)
   - `0x1::coin::WithdrawEvent` for coin withdrawals (legacy)
   - `0x1::fungible_asset::Deposit` for FA deposits (current)
   - `0x1::fungible_asset::Withdraw` for FA withdrawals (current)

2. **Process Transactions**:
   - Monitor transaction versions for ordering
   - Validate transaction success: `success: true`
   - Calculate gas costs for APT transactions

### Popular Stablecoins
- USDt (Tether): `0x357b0b74bc833e95a115ad22604854d6b0fca151cecd94111770e5d6ffc9dc2b`
- USDC: `0xbae207659db88bea0cbead6da0ed00aac12edcdda169e591cd41c94180b46f3b`
- USDY (Ondo): `0xcfea864b32833f157f042618bd845145256b1bf4c0da34a7013b76e42daa53cc::usdy::USDY`

## Transaction Management

### Sequence Number Management
- Each account has a strictly increasing sequence number
- **Maximum 100 uncommitted transactions per account**
- Check on-chain sequence number to synchronize

### Sequence Number Allocation Strategy
1. Query blockchain for current sequence number
2. Allow up to 100 transactions in flight
3. If 100 transactions in flight, query network for current state
4. Handle expired transactions by resetting sequence numbers

### Transaction Failures
- **Submission failures**: Network issues or validation errors
- **Pre-execution failures**: Detected after timeout expiration
- **Execution failures**: On-chain state issues, committed to blockchain

### Scaling Transaction Throughput
- Use worker accounts sharing a resource account
- Use `SignerCap` for shared account control
- Be aware of read/write conflicts that limit parallelization !!

### Worker-Leader Pattern
- Resource account as shared identity
- Worker accounts with access to resource account's SignerCap
- Application-specific capabilities for each worker

## Address vs Signer vs Account vs Resource Account

Understanding these core concepts is fundamental to Move mastery:

### Conceptual Differences

```
Address vs Signer vs Account vs Resource Account:
┌─────────────────┬─────────────────────────────────────────────┐
│ Concept         │ Description                                 │
├─────────────────┼─────────────────────────────────────────────┤
│ Address         │ 32-byte identifier, like a postal address  │
│                 │ Can be created by anyone                    │
│                 │ Just a number - no inherent authority      │
│                 │                                             │
│ Signer          │ Capability to act on behalf of address     │
│                 │ Can only be created by VM                  │
│                 │ Represents authenticated user               │
│                 │                                             │
│ Account         │ Storage container at an address             │
│                 │ Contains resources and modules              │
│                 │ Must be explicitly created                  │
│                 │                                             │
│ Resource Acc    │ Autonomous account without private key      │
│                 │ Controlled by smart contracts               │
│                 │ Used for protocol-owned resources           │
└─────────────────┴─────────────────────────────────────────────┘
```

### Type Definitions and Usage

```
Type System Representation:
┌─────────────────────────────────────────────────────────────┐
│ Address Type:                                               │
│ • Primitive type with copy, drop, store abilities          │
│ • Can be created from literals: @0x1, @0x42                │
│ • Used for referencing locations                           │
│                                                             │
│ let addr: address = @0x42;                                  │
│ let addr2: address = signer::address_of(&signer);          │
│                                                             │
│ Signer Type:                                                │
│ • ⚠️  Built-in resource type with DROP ONLY               │
│ • Cannot be created directly - only by VM                  │
│ • Represents authenticated account authority                │
│ • ⚠️  NOT copyable - cannot use copy operator              │
│                                                             │
│ struct signer has drop { a: address }  // Conceptual       │
│                                                             │
│ // Usage in functions:                                      │
│ public fun deposit(account: &signer, amount: u64) {        │
│   let addr = signer::address_of(account);                  │
│   // Now can perform operations at addr                    │
│ }                                                           │
└─────────────────────────────────────────────────────────────┘
```

### The Complete Four-Layer Model

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         COMPLETE IDENTITY SYSTEM                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ 1. 👤 HUMAN SIGNER                                                         │
│    • Real person with private key                                          │
│    • Signs transactions manually                                           │
│    • Used for: personal accounts, admin actions                            │
│                                                                             │
│ 2. 🤖 RESOURCE ACCOUNT SIGNER                                              │
│    • Programmatic account with no private key                              │
│    • Controlled entirely by smart contract code                            │
│    • Used for: protocol accounts, trustless systems                        │
│                                                                             │
│ 3. 📍 ADDRESS                                                              │
│    • 256-bit identifier for both human and resource accounts               │
│    • Locates storage in global state                                       │
│                                                                             │
│ 4. 🗄️ ACCOUNT STORAGE                                                      │
│    • Contains resources and modules                                         │
│    • Same structure for both account types                                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

### The Problem with Traditional Admin Keys

```
❌ Traditional DeFi:
Protocol → Owned by Admin → Admin has private key → Single point of failure
                                     ↓
                            🚨 Admin can rug pull users
```

### The Resource Account Solution

```
✅ Resource Account DeFi:
Protocol → Owned by Resource Account → No private key → Controlled by code/governance
                                              ↓
                                    🛡️ Trustless operation
```

### Creating Resource Accounts

```move
use aptos_framework::resource_account;

public fun create_protocol(admin: &signer) {
    // Create resource account with no private key
    let (resource_signer, resource_cap) = 
        resource_account::create_resource_account(admin, b"protocol_seed");
    
    // Deploy protocol to resource account
    move_to(&resource_signer, ProtocolConfig {
        admin: signer::address_of(admin),
        paused: false,
    });
    
    // Store the capability for future governance
    move_to(admin, ProtocolCapability { 
        cap: resource_cap 
    });
}
```

### Account Types Detailed

```
Account Type Comparison:
┌─────────────────────────────────────────────────────────────┐
│                     STANDARD ACCOUNT                        │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ • Has public/private key pair                          │ │
│ │ • User controls via wallet                             │ │
│ │ • Can sign transactions                                │ │
│ │ • Can hold coins, NFTs, resources                      │ │
│ │ • Authentication key can be rotated                    │ │
│ │                                                         │ │
│ │ Creation:                                               │ │
│ │ 1. Generate key pair                                   │ │
│ │ 2. Derive address from public key                      │ │
│ │ 3. Send transaction or receive funds                   │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│                    RESOURCE ACCOUNT                         │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ • No private key - controlled by code                  │ │
│ │ • Deterministic address generation from SHA3-256       │ │
│ │ • Created via create_resource_account()                │ │
│ │ • Signer capability stored for access                  │ │
│ │ • Used for autonomous protocols                        │ │
│ │ • ⚠️  Can only be created ONCE per source+seed        │ │
│ │                                                         │ │
│ │ Creation:                                               │ │
│ │ 1. Source account calls create_resource_account()      │ │
│ │ 2. VM generates deterministic address via hash         │ │
│ │ 3. Returns SignerCapability for future access         │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Resource Account Pattern (Corrected)

```move
module 0x42::protocol {
    use aptos_framework::resource_account;
    use aptos_framework::account::SignerCapability;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::aptos_coin::AptosCoin;

    struct ProtocolData has key {
        admin: address,
        signer_cap: SignerCapability,  // Control resource acc
        treasury: Coin<AptosCoin>,
    }

    fun init_module(deployer: &signer) {
        // Create resource account
        let (resource_signer, signer_cap) =
            resource_account::create_resource_account(
                deployer,
                b"protocol_seed"
            );

        // Store control capability
        move_to(&resource_signer, ProtocolData {
            admin: signer::address_of(deployer),
            signer_cap,
            treasury: coin::zero<AptosCoin>(),
        });
    }

    public fun protocol_operation() acquires ProtocolData {
        let protocol_addr = @0x42; // Your protocol address
        let data = borrow_global_mut<ProtocolData>(protocol_addr);
        let resource_signer = account::create_signer_with_capability(
            &data.signer_cap
        );
        // Use resource_signer for operations
    }
}
```

## When to Use Resource Accounts

| Use Case | Traditional Account | Resource Account |
|----------|-------------------|------------------|
| User data storage | ✅ Perfect | ❌ Overkill |
| Personal wallets | ✅ Perfect | ❌ Wrong tool |
| Protocol contracts | ❌ Centralized | ✅ Perfect |
| DAO treasuries | ❌ Risky | ✅ Perfect |
| Multi-sig protocols | ❌ Complex | ✅ Clean |
| Upgradeable systems | ❌ Difficult | ✅ Elegant |

## ⚠️ Key Updates & Corrections Made:

### **Major Asset Standard Changes:**
1. **Fungible Asset Migration**: APT and all tokens are migrating from Coin to Fungible Asset standard starting June 30, 2025
2. **Legacy Status**: Coin standard is now in maintenance mode; all new development should use Fungible Asset standard
3. **Automatic Migration**: Users don't need to take action - migration happens automatically

### **Technical Corrections:**
1. **Account Creation**: Explicitly noted that accounts must be created before they can execute transactions
2. **Address Standards**: Updated with special address rules (0x0 to 0xf can use short form)
3. **BCS Encoding**: Confirmed transactions are encoded in Binary Canonical Serialization
4. **Sequence Numbers**: Confirmed 100 transaction limit and strict ordering requirements

### **Integration Updates:**
1. **Exchange Integration**: Must handle both Coin and Fungible Asset standards during migration
2. **Event Monitoring**: Updated to include both legacy coin events and new FA events
3. **Balance Checking**: Provided both legacy and current methods

The core concepts in your original document were excellent - these corrections ensure you're up to date with the latest Aptos developments, particularly the major shift from Coin to Fungible Asset standard.