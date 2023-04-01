// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
// ══════════════════════════════ LIBRARY IMPORTS ══════════════════════════════

import {SystemEntity} from "../libs/Structures.sol";
// ═════════════════════════════ INTERNAL IMPORTS ══════════════════════════════
import {DomainContext} from "../context/DomainContext.sol";
import {ISystemContract} from "../interfaces/ISystemContract.sol";
import {InterfaceSystemRouter} from "../interfaces/InterfaceSystemRouter.sol";
import {Versioned} from "../Version.sol";
// ═════════════════════════════ EXTERNAL IMPORTS ══════════════════════════════
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @notice Shared utilities between Synapse System Contracts: Origin, Destination, etc.
 */
abstract contract SystemContract is DomainContext, Versioned, OwnableUpgradeable, ISystemContract {
    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              CONSTANTS                               ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    // domain of the Synapse Chain
    // For MVP this is Optimism chainId
    // TODO: replace the placeholder with actual value
    uint32 public constant SYNAPSE_DOMAIN = 10;

    uint256 internal constant ORIGIN = 1 << uint8(SystemEntity.Origin);
    uint256 internal constant DESTINATION = 1 << uint8(SystemEntity.Destination);
    uint256 internal constant AGENT_MANAGER = 1 << uint8(SystemEntity.AgentManager);

    // TODO: reevaluate optimistic period for staking/unstaking bonds
    uint32 internal constant BONDING_OPTIMISTIC_PERIOD = 1 days;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                               STORAGE                                ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    InterfaceSystemRouter public systemRouter;

    /// @dev gap for upgrade safety
    uint256[49] private __GAP; // solhint-disable-line var-name-mixedcase

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              MODIFIERS                               ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @dev Modifier for functions that are supposed to be called only from
     * System Contracts on all chains (either local or remote).
     * Note: any function protected by this modifier should have last three params:
     * - uint32 callOrigin
     * - SystemEntity systemCaller
     * - uint256 rootSubmittedAt
     * Make sure to check domain/caller, if a function should be only called
     * from a given domain / by a given caller.
     * Make sure to check that a needed amount of time has passed since
     * root submission for the cross-chain calls.
     */
    modifier onlySystemRouter() {
        _assertSystemRouter();
        _;
    }

    /**
     * @dev Modifier for functions that are supposed to be called only from
     * System Contracts on Synapse chain.
     * Note: has to be used alongside with `onlySystemRouter`
     * See `onlySystemRouter` for details about the functions protected by such modifiers.
     */
    modifier onlySynapseChain(uint32 callOrigin) {
        _assertSynapseChain(callOrigin);
        _;
    }

    /**
     * @dev Modifier for functions that are supposed to be called only from
     * a set of System Contracts on any chain.
     * Note: has to be used alongside with `onlySystemRouter`
     * See `onlySystemRouter` for details about the functions protected by such modifiers.
     * Note: check constants section for existing mask constants
     * E.g. to restrict the set of callers to three allowed system callers:
     *  onlyCallers(MASK_0 | MASK_1 | MASK_2, systemCaller)
     */
    modifier onlyCallers(uint256 allowedMask, SystemEntity systemCaller) {
        _assertEntityAllowed(allowedMask, systemCaller);
        _;
    }

    /**
     * @dev Modifier for functions that are supposed to be called only from
     * AgentManager on Synapse Chain.
     * Note: has to be used alongside with `onlySystemRouter`
     * See `onlySystemRouter` for details about the functions protected by such modifiers.
     */
    modifier onlySynapseChainAgentManager(uint32 callOrigin, SystemEntity systemCaller) {
        _assertSynapseChain(callOrigin);
        _assertEntityAllowed(AGENT_MANAGER, systemCaller);
        _;
    }

    /**
     * @dev Modifier for functions that are supposed to be called only from
     * System Contracts on remote chain with a defined minimum optimistic period.
     * Note: has to be used alongside with `onlySystemRouter`
     * See `onlySystemRouter` for details about the functions protected by such modifiers.
     * Note: message could be sent with a period lower than that, but will be executed
     * only when `optimisticSeconds` have passed.
     * Note: optimisticSeconds=0 will allow calls from a local chain as well
     */
    modifier onlyOptimisticPeriodOver(uint256 rootSubmittedAt, uint256 optimisticSeconds) {
        _assertOptimisticPeriodOver(rootSubmittedAt, optimisticSeconds);
        _;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              OWNER ONLY                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    // solhint-disable-next-line ordering
    function setSystemRouter(InterfaceSystemRouter systemRouter_) external onlyOwner {
        systemRouter = systemRouter_;
    }

    /**
     * @dev Should be impossible to renounce ownership;
     * we override OpenZeppelin OwnableUpgradeable's
     * implementation of renounceOwnership to make it a no-op
     */
    function renounceOwnership() public override onlyOwner {} //solhint-disable-line no-empty-blocks

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                        SYSTEM CALL SHORTCUTS                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Perform a System Call to a AgentManager on a given domain
    /// with the given optimistic period and data.
    function _callAgentManager(uint32 domain, uint32 optimisticSeconds, bytes memory payload) internal {
        systemRouter.systemCall({
            destination: domain,
            optimisticSeconds: optimisticSeconds,
            recipient: SystemEntity.AgentManager,
            payload: payload
        });
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                 INTERNAL VIEWS: SECURITY ASSERTIONS                  ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _onSynapseChain() internal view returns (bool) {
        return localDomain == SYNAPSE_DOMAIN;
    }

    function _assertSystemRouter() internal view {
        require(msg.sender == address(systemRouter), "!systemRouter");
    }

    function _assertOptimisticPeriodOver(uint256 rootSubmittedAt, uint256 optimisticSeconds) internal view {
        require(block.timestamp >= rootSubmittedAt + optimisticSeconds, "!optimisticPeriod");
    }

    function _assertEntityAllowed(uint256 allowedMask, SystemEntity caller) internal pure {
        require(_entityAllowed(allowedMask, caller), "!allowedCaller");
    }

    function _assertSynapseChain(uint32 domain) internal pure {
        require(domain == SYNAPSE_DOMAIN, "!synapseDomain");
    }

    /**
     * @notice Checks if a given entity is allowed to call a function using a systemMask
     * @param systemMask  a mask of allowed entities
     * @param entity  a system entity to check
     * @return true if entity is allowed to call a function
     *
     * @dev this function works by converting the enum value to a non-zero bit mask
     * we then use a bitwise AND operation to check if permission bits allow the entity
     * to perform this operation, more details can be found here:
     * https://en.wikipedia.org/wiki/Bitwise_operation#AND
     */
    function _entityAllowed(uint256 systemMask, SystemEntity entity) internal pure returns (bool) {
        return systemMask & _getSystemMask(entity) != 0;
    }

    /**
     * @notice Returns a mask for a given system entity
     * @param entity  System entity
     * @return a non-zero mask for a given system entity
     *
     * Converts an enum value into a non-zero bit mask used for a bitwise AND check
     * E.g. for Origin (0) returns 1, for Destination (1) returns 2
     */
    function _getSystemMask(SystemEntity entity) internal pure returns (uint256) {
        return 1 << uint8(entity);
    }
}
