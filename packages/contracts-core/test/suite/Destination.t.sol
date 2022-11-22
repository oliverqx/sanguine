// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../tools/DestinationTools.t.sol";

// solhint-disable func-name-mixedcase
contract DestinationTest is DestinationTools {
    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                   TESTS: CONSTRUCTOR & INITIALIZER                   ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_initialize() public {
        DestinationHarness destination = new DestinationHarness(DOMAIN_LOCAL);
        vm.prank(owner);
        destination.initialize();
        assertEq(destination.owner(), owner, "!owner");
    }

    function test_initializedCorrectly() public {
        for (uint256 d = 0; d < DOMAINS; ++d) {
            uint32 domain = domains[d];
            DestinationHarness destination = suiteDestination(domain);
            // Check local domain
            assertEq(destination.localDomain(), domain, "!localDomain");
            // Check owner
            assertEq(destination.owner(), owner, "!owner");
            // Check contract addresses
            assertEq(
                address(destination.systemRouter()),
                address(suiteSystemRouter(domain)),
                "!systemRouter"
            );
            // Check global notaries
            for (uint256 i = 0; i < DOMAINS; ++i) {
                uint32 _domain = domains[i];
                for (uint256 j = 0; j < NOTARIES_PER_CHAIN; ++j) {
                    // Destination should know about notaries from all other chains
                    assertEq(
                        destination.isNotary(_domain, suiteNotary(_domain, j)),
                        _domain != domain,
                        string.concat("!notary", getActorSuffix(j))
                    );
                }
            }
            // Check global guards
            assertEq(destination.guardsAmount(), GUARDS, "!guardsAmount");
            for (uint256 i = 0; i < GUARDS; ++i) {
                assertTrue(
                    destination.isGuard(suiteGuard(i)),
                    string.concat("!guard", getActorSuffix(i))
                );
            }
        }
    }

    function test_initialize_revert_onlyOnce() public {
        expectRevertAlreadyInitialized();
        suiteDestination(DOMAIN_LOCAL).initialize();
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                  TESTS: RESTRICTED ACCESS (REVERTS)                  ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_setNotary_revert_notOwner(address caller) public {
        vm.assume(caller != owner);
        DestinationHarness destination = suiteDestination(DOMAIN_LOCAL);
        expectRevertNotOwner();
        vm.prank(caller);
        // setNotary has onlyOwner modifier
        destination.setNotary({ _domain: DOMAIN_REMOTE, _notary: attacker });
    }

    function test_setConfirmation_revert_notOwner(address caller) public {
        vm.assume(caller != owner);
        DestinationHarness destination = suiteDestination(DOMAIN_LOCAL);
        expectRevertNotOwner();
        vm.prank(caller);
        // setConfirmation has onlyOwner modifier
        destination.setConfirmation(DOMAIN_REMOTE, "fake root", 0);
    }

    function test_onlySystemRouter_revert_rejectOthers() public {
        DestinationHarness destination = suiteDestination(DOMAIN_LOCAL);
        vm.expectRevert("!systemRouter");
        vm.prank(owner);
        // setSensitiveValue has onlySystemRouter modifier
        destination.setSensitiveValue(1337, 0, 0, 0);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                       TESTS: RESTRICTED ACCESS                       ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_setNotary() public {
        DestinationHarness destination = suiteDestination(DOMAIN_LOCAL);
        // Take one of agents that was never registered as Notary
        address notary = owner;
        assertFalse(destination.isNotary(DOMAIN_REMOTE, notary), "WTF: already a Notary");
        vm.prank(owner);
        destination.setNotary(DOMAIN_REMOTE, notary);
        assertTrue(destination.isNotary(DOMAIN_REMOTE, notary), "Failed to add a new Notary");
    }

    function test_setConfirmation() public {
        attestationOrigin = DOMAIN_REMOTE;
        attestationRoot = "test root";
        vm.startPrank(owner);
        // Sanity check
        assertEq(destinationSubmittedAt(DOMAIN_LOCAL), 0, "WTF: test root already known");
        // Test: set confirmation from zero to non-zero
        expectSetConfirmation({ prevConfirmAt: 0, newConfirmAt: 1 });
        destinationSetConfirmAt({ domain: DOMAIN_LOCAL, newConfirmAt: 1 });
        assertEq(destinationSubmittedAt(DOMAIN_LOCAL), 1, "Failed to change timestamp");
        // Test: set confirmation from non-zero to non-zero
        expectSetConfirmation({ prevConfirmAt: 1, newConfirmAt: 2 });
        destinationSetConfirmAt({ domain: DOMAIN_LOCAL, newConfirmAt: 2 });
        assertEq(destinationSubmittedAt(DOMAIN_LOCAL), 2, "Failed to change timestamp");
        // Test: set confirmation from non-zero to zero
        expectSetConfirmation({ prevConfirmAt: 2, newConfirmAt: 0 });
        destinationSetConfirmAt({ domain: DOMAIN_LOCAL, newConfirmAt: 0 });
        assertEq(destinationSubmittedAt(DOMAIN_LOCAL), 0, "Failed to change timestamp");
        vm.stopPrank();
    }

    function test_onlySystemRouter() public {
        DestinationHarness destination = suiteDestination(DOMAIN_LOCAL);
        SystemRouterHarness systemRouter = suiteSystemRouter(DOMAIN_LOCAL);
        vm.expectEmit(true, true, true, true);
        emit LogSystemCall(1, 2, 3);
        vm.prank(address(systemRouter));
        // Should emit corresponding event and change sensitive value
        destination.setSensitiveValue(1337, 1, 2, 3);
        assertEq(destination.sensitiveValue(), 1337);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                 TESTS: SUBMIT ATTESTATION (REVERTS)                  ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_submitAttestation_revert_fakeNotary() public {
        createAttestationMock({
            origin: DOMAIN_REMOTE,
            destination: DOMAIN_LOCAL,
            signer: attacker
        });
        // Should reject attestation signed by not a Notary
        destinationSubmitAttestation(DOMAIN_LOCAL, "Signer is not a notary");
    }

    function test_submitAttestation_revert_emptyRoot() public {
        createAttestation({
            origin: DOMAIN_REMOTE,
            destination: DOMAIN_LOCAL,
            nonce: 1,
            root: bytes32(0)
        });
        // Should reject attestations with empty merkle root (even a Notary's one)
        destinationSubmitAttestation(DOMAIN_LOCAL, "Empty root");
    }

    function test_submitAttestation_revert_fromLocalDomain() public {
        DestinationHarness destination = suiteDestination(DOMAIN_LOCAL);
        // By default Destination doesn't have info about local notaries, let's add one
        destination.addNotary(DOMAIN_LOCAL, attacker);
        createAttestationMock({
            origin: DOMAIN_LOCAL,
            destination: DOMAIN_REMOTE,
            signer: attacker
        });
        // Should reject attestations with origin = local domain
        destinationSubmitAttestation(DOMAIN_LOCAL, "!attestationOrigin: local");
    }

    function test_submitAttestation_revert_notForLocalDomain() public {
        createAttestationMock({ origin: DOMAIN_REMOTE, destination: DOMAIN_SYNAPSE });
        // Should reject attestations with destination != local domain
        destinationSubmitAttestation(DOMAIN_LOCAL, "!attestationDestination: !local");
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                      TESTS: SUBMIT ATTESTATION                       ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_submitAttestation() public {
        // Create messages sent from remote domain and prepare attestation
        createMessages({ context: userRemoteToLocal, recipient: address(suiteApp(DOMAIN_LOCAL)) });
        createSuggestedAttestation({ origin: DOMAIN_REMOTE, destination: DOMAIN_LOCAL });
        expectAttestationAccepted();
        // Should emit corresponding event and mark root submission time
        destinationSubmitAttestation({ domain: DOMAIN_LOCAL, returnValue: true });
        assertEq(destinationSubmittedAt(DOMAIN_LOCAL), block.timestamp, "!rootSubmittedAt");
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                    TESTS: SUBMIT REPORT (REVERTS)                    ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_submitReport_revert_validFlag() public {
        createAttestationMock({ origin: DOMAIN_REMOTE, destination: DOMAIN_LOCAL });
        createReport(Report.Flag.Valid);
        // Destination should reject Reports with a Valid flag (they serve no purpose)
        destinationSubmitReport(DOMAIN_LOCAL, "Not a fraud report");
    }

    function test_submitReport_revert_notNotary() public {
        createAttestationMock({
            origin: DOMAIN_REMOTE,
            destination: DOMAIN_LOCAL,
            signer: attacker
        });
        createReport(Report.Flag.Fraud);
        // Destination should reject Reports with Attestation signed by not a Notary
        destinationSubmitReport(DOMAIN_LOCAL, "Signer is not a notary");
    }

    function test_submitReport_revert_notGuard() public {
        createAttestationMock({ origin: DOMAIN_REMOTE, destination: DOMAIN_LOCAL });
        createReport({ flag: Report.Flag.Fraud, signer: attacker });
        // Destination should reject Reports signed by not a Guard
        destinationSubmitReport(DOMAIN_LOCAL, "Signer is not a guard");
    }

    function test_submitReport_revert_alreadyBlacklisted() public {
        test_submitReport();
        createAttestation({
            origin: DOMAIN_REMOTE,
            destination: DOMAIN_LOCAL,
            nonce: 123,
            root: "another fake root"
        });
        createReport(Report.Flag.Fraud);
        // Destination should reject Reports for already blacklisted Notary
        destinationSubmitReport(DOMAIN_LOCAL, "Signer is not a notary");
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                         TESTS: SUBMIT REPORT                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_submitReport() public {
        // Submit attestation and wait enough time for root to become valid
        test_acceptableRoot();
        // Save notary's valid root for later check
        bytes32 validRoot = attestationRoot;
        // Force the same notary to sign a fraud attestation
        createAttestation({
            origin: DOMAIN_REMOTE,
            destination: DOMAIN_LOCAL,
            nonce: 420,
            root: "clearly fake root"
        });
        createReport(Report.Flag.Fraud);
        expectNotaryBlacklisted();
        destinationSubmitReport(DOMAIN_LOCAL, true);
        assertFalse(
            suiteDestination(DOMAIN_LOCAL).isNotary(DOMAIN_REMOTE, suiteNotary(DOMAIN_REMOTE)),
            "Notary not blacklisted"
        );
        // Check previously valid root
        attestationRoot = validRoot;
        // Even a valid root signed by fraud Notary should be blacklisted
        destinationAcceptableRoot(DOMAIN_LOCAL, "Inactive notary");
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                   TESTS: ACCEPTABLE ROOT (REVERTS)                   ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_acceptableRoot_revert_invalidRoot() public {
        // Create attestation, but don't submit it to Destination
        createAttestationMock({ origin: DOMAIN_REMOTE, destination: DOMAIN_LOCAL });
        skip(APP_OPTIMISTIC_SECONDS);
        // Root is unknown, as it wasn't submitted in the attestation
        destinationAcceptableRoot({ domain: DOMAIN_LOCAL, revertMessage: "Invalid root" });
    }

    function test_acceptableRoot_revert_inactiveNotary() public {
        test_submitAttestation();
        // Remove Notary who signed a valid root
        suiteDestination(DOMAIN_LOCAL).removeNotary(DOMAIN_REMOTE, suiteNotary(DOMAIN_REMOTE));
        skip(APP_OPTIMISTIC_SECONDS);
        // Previously singed root should become invalid, as Notary is not active anymore
        destinationAcceptableRoot({ domain: DOMAIN_LOCAL, revertMessage: "Inactive notary" });
    }

    function test_acceptableRoot_revert_periodNotOver() public {
        test_submitAttestation();
        skip(APP_OPTIMISTIC_SECONDS - 1);
        // Should reject root 1 second before its optimistic period passes
        destinationAcceptableRoot({ domain: DOMAIN_LOCAL, revertMessage: "!optimisticSeconds" });
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                        TESTS: ACCEPTABLE ROOT                        ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_acceptableRoot() public {
        test_submitAttestation();
        skip(APP_OPTIMISTIC_SECONDS);
        assertTrue(destinationAcceptableRoot(DOMAIN_LOCAL), "!acceptableRoot");
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                       TESTS: EXECUTE (REVERTS)                       ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_execute_revert_wrongDomain() public {
        createMessages({ context: userRemoteToLocal, recipient: address(suiteApp(DOMAIN_LOCAL)) });
        destinationExecute({ domain: DOMAIN_REMOTE, index: 0, revertMessage: "!destination" });
        destinationExecute({ domain: DOMAIN_SYNAPSE, index: 0, revertMessage: "!destination" });
    }

    function test_execute_revert_mirrorNotActive() public {
        createMessages({ context: userRemoteToLocal, recipient: address(suiteApp(DOMAIN_LOCAL)) });
        destinationExecute({ domain: DOMAIN_LOCAL, index: 0, revertMessage: "Mirror not active" });
    }

    function test_execute_revert_reentrant() public {
        reentrantApp = new ReentrantApp();
        chains[DOMAIN_LOCAL].app = AppHarness(address(reentrantApp));
        // This will create messages sent to reentrant app
        test_submitAttestation();
        skip(APP_OPTIMISTIC_SECONDS);
        // Details for executing message with index = 1
        reentrantApp.prepare({
            _message: rawMessages[1],
            _proof: proofGen.getProof({ _index: 1 }),
            _index: 1
        });
        // This will cause reentrancy
        destinationExecute({ domain: DOMAIN_LOCAL, index: 0, revertMessage: "!reentrant" });
    }

    function test_execute_revert_alreadyExecuted() public {
        test_execute();
        for (uint256 index = 0; index < MESSAGES; ++index) {
            destinationExecute({
                domain: DOMAIN_LOCAL,
                index: index,
                revertMessage: "!MessageStatus.None"
            });
        }
    }

    function test_execute_revert_periodNotOver() public {
        test_submitAttestation();
        skip(APP_OPTIMISTIC_SECONDS - 1);
        for (uint32 i = 0; i < MESSAGES; ++i) {
            // Should not execute if root optimistic period is not over
            destinationExecute({
                domain: DOMAIN_LOCAL,
                index: i,
                revertMessage: "!optimisticSeconds"
            });
        }
    }

    function test_execute_revert_periodTooSmall() public {
        AppHarness app = new AppHarness(APP_OPTIMISTIC_SECONDS + 1);
        chains[DOMAIN_LOCAL].app = app;
        test_submitAttestation();
        skip(APP_OPTIMISTIC_SECONDS);
        // Messages are sent with APP_OPTIMISTIC_SECONDS, but app is
        // now setup for APP_OPTIMISTIC_SECONDS + 1.
        // Things are OK from Destination point of view (as message optimistic period is over)
        // But app should reject such messages (as app enforced optimistic period is not over)
        for (uint32 i = 0; i < MESSAGES; ++i) {
            // Note that destination does not revert, app does
            destinationExecute({
                domain: DOMAIN_LOCAL,
                index: i,
                revertMessage: "app: !optimisticSeconds"
            });
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            TESTS: EXECUTE                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_execute() public {
        AppHarness app = suiteApp(DOMAIN_LOCAL);
        test_submitAttestation();
        skip(APP_OPTIMISTIC_SECONDS);
        // Should be able to execute all messages once optimistic period is over
        for (uint32 i = 0; i < MESSAGES; ++i) {
            checkMessageExecution({ context: userRemoteToLocal, app: app, index: i });
        }
    }

    function test_execute_reverseOrder() public {
        AppHarness app = suiteApp(DOMAIN_LOCAL);
        test_submitAttestation();
        skip(APP_OPTIMISTIC_SECONDS);
        // nonce order is not enforced, so this is also possible
        for (uint32 i = MESSAGES - 1; ; --i) {
            checkMessageExecution({ context: userRemoteToLocal, app: app, index: i });
            if (i == 0) break;
        }
    }
}