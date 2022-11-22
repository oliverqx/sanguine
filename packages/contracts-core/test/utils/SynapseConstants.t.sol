// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract SynapseConstants {
    // ============ Domains ============
    uint256 internal constant DOMAINS = 3;
    uint32 internal constant DOMAIN_LOCAL = 1000;
    uint32 internal constant DOMAIN_REMOTE = 1500;
    // TODO: replace placeholder value
    uint32 internal constant DOMAIN_SYNAPSE = 4269;
    // ============ Actors ============
    uint256 internal constant NOTARIES_PER_CHAIN = 4;
    uint256 internal constant GUARDS = 4;
    // ============ App ============
    uint32 internal constant APP_OPTIMISTIC_SECONDS = 60;
    // ============ Merkle ============
    uint256 internal constant TREE_DEPTH = 32;
}