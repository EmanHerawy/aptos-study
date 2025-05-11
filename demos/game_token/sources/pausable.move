module game_token::pausable {
    use std::account;
    use std::event::{Self, EventHandle};
    use aptos_framework::timestamp;

    #[test_only]
    use std::debug;

    //:!:>CONSTANTS

    //:!:>CONSTANTS

 
    //:!:>resource
    struct PausableState has store {
        is_paused: bool,
        paused_event: EventHandle<Pause>,
        unpaused_event: EventHandle<UnPause>

        }

    #[event]
    struct Pause has store, drop {
        account: address,
        timeStamp: u64

    }
    #[event]
    struct UnPause has store, drop {
        account: address,
        timeStamp: u64

    }

    //<:!:resource
    //<:!:setter functions
    // create new

    public fun new(
        event_account: &signer ): PausableState {
        PausableState {
            is_paused: false,
            paused_event: account::new_event_handle(event_account),
            unpaused_event: account::new_event_handle(event_account)
        }
    }

    public fun set_pause_enabled(
        state: &mut PausableState,account: address
    ) {
        assert!(state.is_paused==false);
        state.is_paused = true;
           event::emit_event(
                    &mut state.paused_event,
                    Pause {
                        account: account,
                        timeStamp: timestamp::now_seconds()
                    }
                );
    }

    public fun set_unpause_enabled(
        state: &mut PausableState,  account: address
    ) {
        assert!(state.is_paused==true);
        state.is_paused = false;
           event::emit_event(
                    &mut state.unpaused_event,
                    UnPause {
                        account: account,
                        timeStamp: timestamp::now_seconds()
                    }
                );
    }



    //<:!:setter functions

    //<:!:getter functions

    public fun get_pause_status(state: &PausableState): bool {
        state.is_paused
    }

   
    //<:!:getter functions
}
