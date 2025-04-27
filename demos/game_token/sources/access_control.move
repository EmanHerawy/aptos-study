module game_token::access_control {
    use std::error;
    use std::signer;
    use std::string::String;
    use std::account;
    use std::event::{ EventHandle};
    use aptos_framework::timestamp;

    #[test_only]
    use std::debug;

    //:!:>CONSTANTS

    
    //:!:>CONSTANTS



    enum Operation has store, drop{
        Add,
        Remove
    }

    //:!:>resource
    struct AccessControlList has store {
         role_name: String,
        is_enabled: bool,
        allowlist: vector<address>,
        allow_list_update_event: EventHandle<AccessControlListUpdated>
    }
    #[event]
    struct AccessControlListUpdated has store,drop{
        role : String,
        caller : address,
        operation:Operation,
        timeStamp:u64

    }
    //<:!:resource
    //<:!:setter functions 
    // create new 

    public fun new(event_account:&signer,  role_name: String, allowlist: vector<address>):AccessControlList{
 AccessControlList{
    role_name,
    is_enabled:true,
    allowlist,
    allow_list_update_event:account::new_event_handle(event_account),
 }
     }
    //<:!:setter functions 



    //<:!:getter functions 
    //<:!:getter functions 



}
