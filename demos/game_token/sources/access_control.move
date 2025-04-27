module game_token::access_control {
    use std::error;
    use std::signer;
    use std::string::String;
    use std::account;
    use std::event::{Self, EventHandle};
    use aptos_framework::timestamp;

    #[test_only]
    use std::debug;

    //:!:>CONSTANTS

    //:!:>CONSTANTS

    enum Operation has store, drop {
        Add,
        Remove
    }

    //:!:>resource
    struct AccessControlListState has store {
        role_name: String,
        is_enabled: bool,
        allowlist: vector<address>,
        allow_list_update_event: EventHandle<AccessControlListStateUpdated>
    }

    #[event]
    struct AccessControlListStateUpdated has store, drop {
        role: String,
        account: address,
        operation: Operation,
        timeStamp: u64

    }

    //<:!:resource
    //<:!:setter functions
    // create new

    public fun new(
        event_account: &signer, role_name: String, allowlist: vector<address>
    ): AccessControlListState {
        AccessControlListState {
            role_name,
            is_enabled: true,
            allowlist,
            allow_list_update_event: account::new_event_handle(event_account)
        }
    }

    public fun set_allowlist_enabled(
        state: &mut AccessControlListState, status: bool
    ) {
        state.is_enabled = status;
    }

    public fun add_to_role(
        state: &mut AccessControlListState, account: address
    ) {
        // check if it's already added
        if (state.allowlist.contains(&account)) {
            // revert

        } else {
            state.allowlist.push_back(account);

            event::emit_event(
                &mut state.allow_list_update_event,
                AccessControlListStateUpdated {
                    role: state.role_name,
                    account: account,
                    operation: Operation::Add,
                    timeStamp: timestamp::now_seconds()

                }
            );
        };
    }

    public fun remove_from_role(
        state: &mut AccessControlListState, account: address
    ) {
        // check if it not added
        if (!state.allowlist.contains(&account)) {
            // revert

        } else {
            let (found, i) = state.allowlist.index_of(&account);
            if (found) {
                state.allowlist.swap_remove(i);

                event::emit_event(
                    &mut state.allow_list_update_event,
                    AccessControlListStateUpdated {
                        role: state.role_name,
                        account: account,
                        operation: Operation::Remove,
                        timeStamp: timestamp::now_seconds()
                    }
                );
            };
        };
    }

    //<:!:setter functions

    //<:!:getter functions

    public fun get_allowlist_status(state: &AccessControlListState): bool {
        state.is_enabled
    }

    public fun get_allowlist(state: &AccessControlListState): vector<address> {
        state.allowlist
    }

    public fun is_allowed(
        state: &AccessControlListState, sender: address
    ): bool {
        if (!state.is_enabled) {
            return true
        };

        state.allowlist.contains(&sender)
    }
    //<:!:getter functions
}
