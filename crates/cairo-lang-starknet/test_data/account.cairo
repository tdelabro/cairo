use serde::Serde;
use starknet::ContractAddress;
use array::ArrayTrait;
use array::SpanTrait;
use option::OptionTrait;

#[contract]
mod Account {
    use array::ArrayTrait;
    use array::SpanTrait;
    use box::BoxTrait;
    use ecdsa::check_ecdsa_signature;
    use option::OptionTrait;
    use starknet::ContractAddress;
    use zeroable::Zeroable;
    use serde::ArraySerde;

    #[starknet::storage]
    struct Storage {
        public_key: felt252
    }

    #[constructor]
    fn constructor(ref self: Storage, public_key_: felt252) {
        self.public_key.write(public_key_);
    }

    trait StorageTrait {
        fn validate_transaction(self: @Storage) -> felt252;
    }
    impl StorageImpl of StorageTrait {
        fn validate_transaction(self: @Storage) -> felt252 {
            let tx_info = starknet::get_tx_info().unbox();
            let signature = tx_info.signature;
            assert(signature.len() == 2_u32, 'INVALID_SIGNATURE_LENGTH');
            assert(
                check_ecdsa_signature(
                    message_hash: tx_info.transaction_hash,
                    public_key: self.public_key.read(),
                    signature_r: *signature[0_u32],
                    signature_s: *signature[1_u32],
                ),
                'INVALID_SIGNATURE',
            );

            starknet::VALIDATED
        }
    }


    #[external]
    fn __validate_deploy__(
        self: @Storage, class_hash: felt252, contract_address_salt: felt252, public_key_: felt252
    ) -> felt252 {
        self.validate_transaction()
    }

    #[external]
    impl AccountContractImpl of starknet::account::AccountContract<Storage> {
        fn __validate_declare__(self: @Storage, class_hash: felt252) -> felt252 {
            self.validate_transaction()
        }

        fn __validate__(
            ref self: Storage,
            contract_address: ContractAddress,
            entry_point_selector: felt252,
            calldata: Array<felt252>
        ) -> felt252 {
            self.validate_transaction()
        }

        #[raw_output]
        fn __execute__(
            ref self: Storage, mut calls: Array<starknet::account::Call>
        ) -> Span<felt252> {
            // Validate caller.
            assert(starknet::get_caller_address().is_zero(), 'INVALID_CALLER');

            // Check the tx version here, since version 0 transaction skip the __validate__ function.
            let tx_info = starknet::get_tx_info().unbox();
            assert(tx_info.version != 0, 'INVALID_TX_VERSION');

            // TODO(ilya): Implement multi call.
            assert(calls.len() == 1_u32, 'MULTI_CALL_NOT_SUPPORTED');
            let Call{to, selector, calldata } = calls.pop_front().unwrap();

            starknet::call_contract_syscall(
                address: to, entry_point_selector: selector, calldata: calldata.span()
            )
                .unwrap_syscall()
        }
    }
}
