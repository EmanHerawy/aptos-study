module game_token::message {
    use std::account;
    use std::event;
    use std::fungible_asset::{Self, BurnRef, Metadata, MintRef, TransferRef};
    use std::object::{Self, ExtendRef, Object, TransferRef as ObjectTransferRef};
    use std::option::{Option};
    use std::primary_fungible_store;
    use std::signer;
    use std::string::{Self, String};
    use game_token::access_control::{Self,AccessControlListState};
    use game_token::pausable::{Self, PausableState};
        #[test_only]
    use std::debug;
    //:!:>resource

        const TOKEN_STATE_SEED: vector<u8> = b"my_token::game_token::token_state";

    /* Why keep both?
            Because:

            TokenState manages the ownership and structure of the token project (like who controls minting rights, the asset metadata, etc.).

            TokenMetadataRefs manages the functional interfaces to the token itself, like minting, burning, and transferring.

            Think of it this way:

            ObjectTransferRef: "Can I move the whole token project to a new owner?"

            TransferRef: "Can I send 10 LINK tokens to someone?"
*/
    struct TokenState has key {
        // here we will save metadata 
        extend_ref: ExtendRef,
        transfer_ref: ObjectTransferRef,
        ownable_state: AccessControlListState,
        allowed_minters: AccessControlListState,
        allowed_burners: AccessControlListState,
        pausable_state : PausableState,
        token: Object<Metadata>

    }
    struct TokenMetadataRefs{
     // here we will save ref 
     mint_ref: MintRef,
    burn_ref: BurnRef,
    transfer_ref: TransferRef,
    extend_ref: ExtendRef,
    }
        #[event]
    struct Initialize has drop, store {
        publisher: address,
        token: Object<Metadata>,
        max_supply: Option<u128>,
        decimals: u8,
        icon: String,
        project: String
    }

    #[event]
    struct Mint has drop, store {
        minter: address,
        to: address,
        amount: u64
    }

    #[event]
    struct Burn has drop, store {
        burner: address,
        from: address,
        amount: u64
    }

    const E_NOT_PUBLISHER: u64 = 1;
    const E_NOT_ALLOWED_MINTER: u64 = 2;
    const E_NOT_ALLOWED_BURNER: u64 = 3;
    const E_TOKEN_NOT_INITIALIZED: u64 = 4;
    const E_TOKEN_ALREADY_INITIALIZED: u64 = 5;
    const E_TOKEN_STATE_DEPLOYMENT_ALREADY_INITIALIZED: u64 = 6;

    #[view]
    public fun type_and_version(): String {
        string::utf8(b"GameToken 1.0.0")
    }
    
    //<:!:resource



}
