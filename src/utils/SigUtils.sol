// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract SigUtils {
    bytes32 internal DOMAIN_TYPEHASH;

    constructor(bytes32 _DOMAIN_TYPEHASH) {
        DOMAIN_TYPEHASH = _DOMAIN_TYPEHASH;
    }

    bytes32 public constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    struct Delegation {
        address delegatee;
        uint nonce;
        uint expiry;
    }

    // computes the hash of a permit
    function getStructHash(Delegation memory _delegation)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    DELEGATION_TYPEHASH,
                    _delegation.delegatee,
                    _delegation.nonce,
                    _delegation.expiry
                )
            );
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getTypedDataHash(Delegation memory _delegation)
        public
        view
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_TYPEHASH,
                    getStructHash(_delegation)
                )
            );
    }
}
