module aptos_fighters_address::aptos_fighters {
    use std::error;
    use std::signer;
    use std::vector;
    use aptos_std::string_utils;
    use std::bcs;
    use aptos_framework::object::{Self};
    use aptos_framework::fungible_asset::{Metadata};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::timestamp;
    use aptos_framework::event;
    use aptos_framework::account;

    // Chainlink imports
    use data_feeds::router::get_benchmarks;
    use data_feeds::registry::{Benchmark, get_benchmark_value, get_benchmark_timestamp};
    use std::option::{Self, Option};    
    
    #[test_only]
    use std::debug;

    const ASSET1_DEFAULT_BALANCE: u64 = 10000000;
    const ASSET2_DEFAULT_BALANCE: u64 = 1000000000000;
    const OCTAS_PER_APTOS: u64 = 100000000;

    /// Error codes
    const EINVALID_ADDRESS: u64 = 1;
    const EINVALID_AMOUNT: u64 = 2;
    const EINVALID_DURATION: u64 = 3;
    const EINVALID_ARRAY_LENGTH: u64 = 4;
    const EGAME_IS_FULL: u64 = 5;
    const ENOT_AUTHORIZED: u64 = 6;
    const EGAME_IN_PROGRESS: u64 = 7;
    const EGAME_NOT_STARTED: u64 = 8;
    const EGAME_ENDED: u64 = 9;
    const EGAME_NOT_ENDED: u64 = 10;
    const EINSUFFICIENT_BALANCE: u64 = 11;
    const EPRICE_ORACLE_EXPIRED: u64 = 12;
    const EPRICE_ORACLE_INVALID: u64 = 13;
    const EREWARD_ALREADY_CLAIMED: u64 = 14;
    const ETRANSFER_FAILED: u64 = 15;
    const EINVALID_GAME_STATUS: u64 = 16;
    const EINVALID_GAME_START_TIME: u64 = 17;
    const EPLAYER_NOT_FOUND: u64 = 18;
    const E_PRICE_TOO_STALE: u64 = 19;

    /// Resource account pattern
    struct ModuleData has key {
        signer_cap: account::SignerCapability,
    }

    struct GameRules has store, drop, copy {
        game_staking_amount: u64,
        game_duration: u64,
        game_start_time: u64,
        reward_amount: u64,
        assets: vector<address>,
        asset_amounts: vector<u64>,
    }



    struct AssetBalance has store, drop {
        player: address,
        balance: u64,
    }

    struct Game has key, store, drop {
        player1: address,
        player2: address,
        data_feed: vector<u8>, // Price feed ID
        player1_reward_claimed: bool,
        player2_reward_claimed: bool,
        game_token: address, // Token used for staking and rewards
        user_asset1_balance: vector<AssetBalance>,
        user_asset2_balance: vector<AssetBalance>,
        game_rules: GameRules,
        max_staleness: u64,
    }

    #[event]
    struct AssetTraded has drop, store {
        player: address,
        price: u64,
        asset_amount: u64,
        is_buy: bool,
    }

    #[event]
    struct PlayerEnrolled has drop, store {
        player: address
    }

    #[event]
    struct GameStarted has drop, store {
        start_time: u64, 
        duration: u64, 
    }

    #[event]
    struct GameWinner has drop, store {
        winner: address
    }

    #[event]
    struct RewardClaimed has drop, store {
        account: address,
        amount: u64,
        is_winner: bool,
    }

    /// Modifiers 
    fun only_players(player1: address, player2: address, caller: address) {
        assert!(player1 == caller || player2 == caller, 
            error::invalid_argument(ENOT_AUTHORIZED));
    }

    /// Initialize the module
    fun init_module(deployer: &signer) {
        let seed = b"aptos_fighters";
        let (resource_signer, resource_signer_cap) = account::create_resource_account(deployer, seed);
        
        move_to(deployer, ModuleData {
            signer_cap: resource_signer_cap,
        });
    }

    /// Initialize a new game contract
    public entry fun init_contract(
        deployer: &signer,
        game_token_add: address, 
        price_id: vector<u8>,
        game_staking_amount: u64,
        game_duration: u64,
        game_start_time: u64,
        reward_amount: u64,
        assets: vector<address>,
        asset_amounts: vector<u64>,
        max_staleness: u64,
    ) {
        // Check input data
        assert!(game_duration > 0, error::invalid_argument(EINVALID_DURATION));
        assert!(game_staking_amount > 0, error::invalid_argument(EINVALID_AMOUNT));
        assert!(reward_amount > 0, error::invalid_argument(EINVALID_AMOUNT));
        assert!(game_start_time > timestamp::now_seconds(), error::invalid_argument(EINVALID_GAME_START_TIME));
        
        let assets_length = vector::length(&assets);
        let amounts_length = vector::length(&asset_amounts);
        
        assert!(assets_length == amounts_length, error::invalid_argument(EINVALID_ARRAY_LENGTH));

        let game_rules = GameRules {
            game_staking_amount,
            game_duration,
            game_start_time,
            reward_amount,
            assets,
            asset_amounts
        };
        
        let game = Game {
            data_feed: price_id,
            max_staleness,
            player1_reward_claimed: false,
            player2_reward_claimed: false,
            game_token: game_token_add,
            game_rules,
            player1: @0x0,
            player2: @0x0,
            user_asset1_balance: vector::empty<AssetBalance>(),
            user_asset2_balance: vector::empty<AssetBalance>()
        };

        let obj_hold_add = object::create_named_object(
            deployer, construct_seed(1)
        );
        let obj_add = object::generate_signer(&obj_hold_add);
        
        move_to(&obj_add, game);
    }

    /// Enroll a player in the game
    public entry fun enroll_player(player: &signer, deployer: address) acquires Game {
        let game = borrow_global_mut<Game>(get_game_address(deployer, 1));
        let player_addr = signer::address_of(player);
        
        assert!(game.game_rules.game_start_time > timestamp::now_seconds(), 
            error::invalid_argument(EGAME_IN_PROGRESS));
        
        assert!(game.player1 == @0x0 || game.player2 == @0x0, 
            error::invalid_argument(EGAME_IS_FULL));
        
        assert!(game.player1 != player_addr && game.player2 != player_addr, 
            error::invalid_argument(ENOT_AUTHORIZED));
        
        stake(player, game.game_token, game.game_rules.game_staking_amount);
        
        let i = 0;
        let length = vector::length(&game.game_rules.assets);
        
        while (i < length) {
            let asset = vector::borrow(&game.game_rules.assets, i);
            let amount = vector::borrow(&game.game_rules.asset_amounts, i);
            
            let asset_metadata = object::address_to_object<Metadata>(*asset);
            assert!(primary_fungible_store::balance(player_addr, asset_metadata) >= *amount, 
                error::invalid_argument(EINSUFFICIENT_BALANCE));
            
            i = i + 1;
        };
        
        if (game.player1 == @0x0) {
            game.player1 = player_addr;
        } else {
            game.player2 = player_addr;
        };
        
        let asset1_balance = AssetBalance {
            player: player_addr,
            balance: ASSET1_DEFAULT_BALANCE,
        };
        let asset2_balance = AssetBalance {
            player: player_addr,
            balance: ASSET2_DEFAULT_BALANCE,
        };
        
        vector::push_back(&mut game.user_asset1_balance, asset1_balance);
        vector::push_back(&mut game.user_asset2_balance, asset2_balance);
        
        event::emit(PlayerEnrolled { player: player_addr });
        
        if (game.player1 != @0x0 && game.player2 != @0x0) {
            if (timestamp::now_seconds() >= game.game_rules.game_start_time) {
                event::emit(GameStarted {
                    start_time: game.game_rules.game_start_time, 
                    duration: game.game_rules.game_duration,
                });
            };
        };
    }

    /// Buy APT tokens using the game's asset
    public entry fun buy_apt(player: &signer, amount: u64, deployer: address) acquires Game {
        let game = borrow_global_mut<Game>(get_game_address(deployer, 1));
        let player_add = signer::address_of(player);
        
        only_players(game.player1, game.player2, player_add);
        
        assert!(timestamp::now_seconds() < game.game_rules.game_start_time + game.game_rules.game_duration, 
            error::invalid_argument(EGAME_ENDED));
        
        if (amount == 0) {
            return
        };

        // Fixed: Convert amount to u256 for price calculation
        let price = fetch_price(player, game.data_feed, game.max_staleness);
        let cost = (price * (amount as u256) as u64); // Convert back to u64 for balance operations
        
        let asset2_balance = get_user_asset_balance_mut(&mut game.user_asset2_balance, player_add);
        assert!(asset2_balance.balance >= cost, EINSUFFICIENT_BALANCE);
        
        let asset1_balance = get_user_asset_balance_mut(&mut game.user_asset1_balance, player_add);
        asset1_balance.balance = asset1_balance.balance + amount;
        asset2_balance.balance = asset2_balance.balance - cost;
        
        event::emit(AssetTraded {
            player: player_add,
            price: cost,
            asset_amount: amount,
            is_buy: true,
        });
    }

    /// Sell APT tokens to get the game's asset
    public entry fun sell_apt(player: &signer, amount: u64, deployer: address) acquires Game {
        let game = borrow_global_mut<Game>(get_game_address(deployer, 1));
        let player_add = signer::address_of(player);
        
        only_players(game.player1, game.player2, player_add);
        
        assert!(timestamp::now_seconds() < game.game_rules.game_start_time + game.game_rules.game_duration, 
            error::invalid_argument(EGAME_ENDED));
        
        if (amount == 0) {
            return
        };
        
        let price = fetch_price(player, game.data_feed, game.max_staleness);
        let revenue = (price * (amount as u256) as u64); // Convert price calculation to u64
        
        let asset1_balance = get_user_asset_balance_mut(&mut game.user_asset1_balance, player_add);
        assert!(asset1_balance.balance >= amount, EINSUFFICIENT_BALANCE);
        
        let asset2_balance = get_user_asset_balance_mut(&mut game.user_asset2_balance, player_add);
        
        asset1_balance.balance = asset1_balance.balance - amount;
        asset2_balance.balance = asset2_balance.balance + revenue;
        
        event::emit(AssetTraded {
            player: player_add,
            price: revenue,
            asset_amount: amount,
            is_buy: false,
        });
    }

    /// Withdraw staked tokens and rewards if applicable
    public entry fun withdraw(player: &signer, deployer: address) acquires Game, ModuleData {
        let game = borrow_global_mut<Game>(get_game_address(deployer, 1));
        let player_add = signer::address_of(player);
        
        only_players(game.player1, game.player2, player_add);
        
        assert!(timestamp::now_seconds() > game.game_rules.game_start_time + game.game_rules.game_duration, 
            error::invalid_argument(EGAME_NOT_ENDED));
        
        let is_player1 = (player_add == game.player1);
        
        if (is_player1) {
            assert!(!game.player1_reward_claimed, error::invalid_argument(EREWARD_ALREADY_CLAIMED));
            game.player1_reward_claimed = true;
        } else {
            assert!(!game.player2_reward_claimed, error::invalid_argument(EREWARD_ALREADY_CLAIMED));
            game.player2_reward_claimed = true;
        };
        
        let amount_to_withdraw = game.game_rules.game_staking_amount;
        
        let (winner, _) = get_winner_fun(game);
        
        if (winner == player_add) {
            amount_to_withdraw = amount_to_withdraw + game.game_rules.reward_amount;
        };
        
        transfer_from_contract(player_add, game.game_token, amount_to_withdraw);
        
        event::emit(RewardClaimed {
            account: player_add,
            amount: amount_to_withdraw,
            is_winner: winner == player_add,
        });
    }

    /// Transfer tokens from the contract to a player
    fun transfer_from_contract(
        player_add: address, 
        game_token: address, 
        amount_to_withdraw: u64
    ) acquires ModuleData {
        let module_addr = @aptos_fighters_address;
        let module_data = borrow_global<ModuleData>(module_addr);
        let resource_signer = account::create_signer_with_capability(&module_data.signer_cap);
        
        let metadata = object::address_to_object<Metadata>(game_token);
        primary_fungible_store::transfer(&resource_signer, metadata, player_add, amount_to_withdraw);
    }

    /// Stake tokens from a player to the contract
    fun stake(player: &signer, game_token: address, amount: u64) {
        let module_addr = @aptos_fighters_address;
        let metadata = object::address_to_object<Metadata>(game_token);
        primary_fungible_store::transfer(player, metadata, module_addr, amount);
    }

    /// Fetch price with validation - Fixed return type
    public fun fetch_price(account: &signer, feed_id: vector<u8>, max_staleness: u64): u256 {
        let feed_ids = vector[feed_id];
        let billing_data = vector[];
        let benchmarks: vector<Benchmark> = get_benchmarks(account, feed_ids, billing_data);
        let benchmark = vector::pop_back(&mut benchmarks);
        let price: u256 = get_benchmark_value(&benchmark);
        let oracle_timestamp: u256 = get_benchmark_timestamp(&benchmark);
        let current_time = (timestamp::now_seconds() as u256);

        let price_age = current_time - oracle_timestamp;
        assert!(price_age <= (max_staleness as u256), E_PRICE_TOO_STALE);
        price
    }

    /// View functions 
    #[view]
    public fun get_winner(deployer: address): (address, u64) acquires Game {
        let game = borrow_global<Game>(get_game_address(deployer, 1));
        assert!(timestamp::now_seconds() > game.game_rules.game_start_time + game.game_rules.game_duration, 
            error::invalid_argument(EGAME_NOT_ENDED));
        
        get_winner_fun(game)
    }

    /// Internal function to determine winner
    fun get_winner_fun(game: &Game): (address, u64) {
        let player1 = game.player1;
        let player2 = game.player2;
        
        let player1_asset1_balance = get_user_asset_balance(&game.user_asset1_balance, player1);
        let player1_asset2_balance = get_user_asset_balance(&game.user_asset2_balance, player1);
        let player2_asset1_balance = get_user_asset_balance(&game.user_asset1_balance, player2);
        let player2_asset2_balance = get_user_asset_balance(&game.user_asset2_balance, player2);
        
        let player1_total_val = player1_asset1_balance.balance + player1_asset2_balance.balance;
        let player2_total_val = player2_asset1_balance.balance + player2_asset2_balance.balance;
        
        if (player1_total_val > player2_total_val) {
            (player1, player1_total_val)
        } else {
            (player2, player2_total_val)
        }
    }
    
    /// Get asset balance for a user (read-only)
    public fun get_user_asset_balance(
        asset_balances: &vector<AssetBalance>,
        user_address: address
    ): &AssetBalance {
        let i = 0;
        let len = vector::length(asset_balances);
        
        while (i < len) {
            let balance = vector::borrow(asset_balances, i);
            if (balance.player == user_address) {
                return balance
            };
            i = i + 1;
        };
        
        abort error::not_found(EPLAYER_NOT_FOUND)
    }

    /// Get asset balance for a user (mutable)
    fun get_user_asset_balance_mut(
        asset_balances: &mut vector<AssetBalance>,
        user_address: address
    ): &mut AssetBalance {
        let i = 0;
        let len = vector::length(asset_balances);
        
        while (i < len) {
            let balance = vector::borrow_mut(asset_balances, i);
            if (balance.player == user_address) {
                return balance
            };
            i = i + 1;
        };
        
        abort error::not_found(EPLAYER_NOT_FOUND)
    }

    /// Get game rules
    #[view]
    public fun get_game_rules(deployer_address: address): GameRules acquires Game {
        let game = borrow_global<Game>(get_game_address(deployer_address, 1));
        game.game_rules
    }

    /// Construct a seed for object creation
    #[view]
    public fun construct_seed(seed: u64): vector<u8> {
        bcs::to_bytes(&string_utils::format2(&b"{}_{}", @aptos_fighters_address, seed))
    }

    /// Get game address from deployer and seed
    #[view]
    public fun get_game_address(deployer: address, seed: u64): address {
        object::create_object_address(&deployer, construct_seed(seed))
    }

    // ============== TEST FUNCTIONS ==============
    
    #[test_only]
    const GAME_STAKING_AMOUNT: u64 = 100;
    #[test_only]
    const GAME_DURATION: u64 = 86400; // 1 day in seconds
    #[test_only]
    const REWARD_AMOUNT: u64 = 500;
    
    #[test_only]
    const DEPLOYER: address = @0x123;
    #[test_only]
    const PLAYER1: address = @0x456;
    #[test_only]
    const PLAYER2: address = @0x789;
    #[test_only]
    const GAME_TOKEN: address = @0xABC;

    /// Helper function to check if Game exists at an address
    #[test_only]
    public fun exists_at(addr: address): bool {
        exists<Game>(addr)
    }

    /// Test for successful contract initialization
    #[test(aptos_framework = @aptos_framework)]
    public fun test_init_contract_success(aptos_framework: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        let deployer = account::create_account_for_test(DEPLOYER);
        let game_token_add = GAME_TOKEN;
        account::create_account_for_test(game_token_add);
        
        let current_time = timestamp::now_seconds();
        
        let price_id = b"ETH/USD";
        let game_staking_amount = GAME_STAKING_AMOUNT;
        let game_duration = GAME_DURATION;
        let game_start_time = current_time + 1000;
        let reward_amount = REWARD_AMOUNT;
        let max_staleness = 3600; // 1 hour
        
        let assets = vector::empty<address>();
        let asset_amounts = vector::empty<u64>();
        
        vector::push_back(&mut assets, @0xA1);
        vector::push_back(&mut assets, @0xA2);
        vector::push_back(&mut asset_amounts, 10);
        vector::push_back(&mut asset_amounts, 20);
        
        init_contract(
            &deployer,
            game_token_add,
            price_id,
            game_staking_amount,
            game_duration,
            game_start_time,
            reward_amount,
            assets,
            asset_amounts,
            max_staleness
        );

        let deployer_address = signer::address_of(&deployer);
        let game_address = get_game_address(deployer_address, 1);
        
        assert!(exists_at(game_address), 0);
    }

    /// Test for failure when game duration is invalid
    #[test(aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = 65539)] // EINVALID_DURATION
    public fun test_init_contract_invalid_duration(aptos_framework: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        let deployer = account::create_account_for_test(DEPLOYER);
        let game_token_add = GAME_TOKEN;
        account::create_account_for_test(game_token_add);
        
        let current_time = timestamp::now_seconds();
        
        let price_id = b"ETH/USD";
        let game_staking_amount = GAME_STAKING_AMOUNT;
        let game_duration = 0; // Invalid duration
        let game_start_time = current_time + 1000;
        let reward_amount = REWARD_AMOUNT;
        let max_staleness = 3600;
        
        let assets = vector::empty<address>();
        let asset_amounts = vector::empty<u64>();
        
        init_contract(
            &deployer,
            game_token_add,
            price_id,
            game_staking_amount,
            game_duration,
            game_start_time,
            reward_amount,
            assets,
            asset_amounts,
            max_staleness
        );
    }

    /// Test for failure when arrays have mismatched lengths
    #[test(aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = 65540)] // EINVALID_ARRAY_LENGTH
    public fun test_init_contract_mismatched_arrays(aptos_framework: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        let deployer = account::create_account_for_test(DEPLOYER);
        let game_token_add = GAME_TOKEN;
        account::create_account_for_test(game_token_add);
        
        let current_time = timestamp::now_seconds();
        
        let price_id = b"ETH/USD";
        let game_staking_amount = GAME_STAKING_AMOUNT;
        let game_duration = GAME_DURATION;
        let game_start_time = current_time + 1000;
        let reward_amount = REWARD_AMOUNT;
        let max_staleness = 3600;
        
        let assets = vector::empty<address>();
        let asset_amounts = vector::empty<u64>();
        
        vector::push_back(&mut assets, @0xA1);
        vector::push_back(&mut assets, @0xA2);
        vector::push_back(&mut asset_amounts, 10);
        // Missing second amount - mismatched arrays
        
        init_contract(
            &deployer,
            game_token_add,
            price_id,
            game_staking_amount,
            game_duration,
            game_start_time,
            reward_amount,
            assets,
            asset_amounts,
            max_staleness
        );
    }

    /// Test asset balance functions
    #[test]
    public fun test_asset_balance_functions() {
        let balances = vector::empty<AssetBalance>();
        let player1_addr = PLAYER1;
        let player2_addr = PLAYER2;
        
        let balance1 = AssetBalance {
            player: player1_addr,
            balance: 1000,
        };
        
        let balance2 = AssetBalance {
            player: player2_addr,
            balance: 2000,
        };
        
        vector::push_back(&mut balances, balance1);
        vector::push_back(&mut balances, balance2);
        
        let player1_balance = get_user_asset_balance(&balances, player1_addr);
        let player2_balance = get_user_asset_balance(&balances, player2_addr);
        
        assert!(player1_balance.balance == 1000, 1);
        assert!(player2_balance.balance == 2000, 2);
    }

    /// Test winner determination
    #[test]
    public fun test_winner_determination() {
        let user_asset1_balance = vector::empty<AssetBalance>();
        let user_asset2_balance = vector::empty<AssetBalance>();
        
        // Player1 has more total value
        vector::push_back(&mut user_asset1_balance, AssetBalance {
            player: PLAYER1,
            balance: 2000,
        });
        vector::push_back(&mut user_asset1_balance, AssetBalance {
            player: PLAYER2,
            balance: 1000,
        });
        
        vector::push_back(&mut user_asset2_balance, AssetBalance {
            player: PLAYER1,
            balance: 3000,
        });
        vector::push_back(&mut user_asset2_balance, AssetBalance {
            player: PLAYER2,
            balance: 2000,
        });
        
        let game = Game {
            player1: PLAYER1,
            player2: PLAYER2,
            data_feed: b"ETH/USD",
            player1_reward_claimed: false,
            player2_reward_claimed: false,
            game_token: GAME_TOKEN,
            user_asset1_balance,
            user_asset2_balance,
            game_rules: GameRules {
                game_staking_amount: GAME_STAKING_AMOUNT,
                game_duration: GAME_DURATION,
                game_start_time: 0,
                reward_amount: REWARD_AMOUNT,
                assets: vector::empty<address>(),
                asset_amounts: vector::empty<u64>(),
            },
            max_staleness: 3600,
        };
        
        let (winner, total_value) = get_winner_fun(&game);
        
        assert!(winner == PLAYER1, 1);
        assert!(total_value == 5000, 2); // 2000 + 3000
    }
}