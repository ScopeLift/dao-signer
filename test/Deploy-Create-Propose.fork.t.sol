// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, stdStorage, StdStorage, console} from "forge-std/Test.sol";

// Import the scripts we need to run
import {MainnetConfig as DeployAndRegisterScript} from
  "script/mainnet/DeployAndRegisterSchema.s.sol";
import {MainnetCreateAgreements as CreateAgreementsScript} from
  "script/mainnet/CreateAgreements.s.sol";
import {CreateProposal as CreateProposalScript} from "script/mainnet/CreateProposal.s.sol";

// Import contracts and interfaces needed for setup and interaction
import {AgreementResolver} from "src/AgreementResolver.sol";
import {AgreementAnchor} from "src/AgreementAnchor.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IGovernorBravo} from "script/mainnet/CreateProposal.s.sol";

interface IUni is IERC20 {
  function delegate(address delegatee) external;
  function getPriorVotes(address account, uint256 blockNumber) external view returns (uint256);
}

/// @title ProposalForkTest
/// @notice An end-to-end integration test on a mainnet fork.
/// @dev This test simulates the entire workflow:
///      1. Deploys the AgreementResolver, its Factory, and registers the EAS Schema.
///      2. Creates the three required AgreementAnchor contracts.
///      3. Generates the calldata for the Uniswap governance proposal.
contract ProposalForkTest is Test {
  using stdStorage for StdStorage;
  // =============================================================
  //      State Variables for Scripts and Actors
  // =============================================================

  DeployAndRegisterScript internal deployAndRegisterScript;
  CreateProposalScript internal createProposalScript;

  // We will use "patched" scripts to dynamically inject addresses
  // that are returned from previous steps.
  PatchedCreateAgreementsScript internal patchedCreateAgreementsScript;
  PatchedCreateProposalScript internal patchedCreateProposalScript;

  address internal proposer = makeAddr("proposer");
  IUni internal constant UNI_TOKEN = IUni(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
  IGovernorBravo internal constant GOVERNOR_BRAVO =
    IGovernorBravo(0x408ED6354d4973f66138C91495F2f2FCbd8724C3);

  function setUp() public {
    // Fork from Mainnet
    string memory rpcURL = vm.envString("MAINNET_RPC_URL");
    vm.createSelectFork(rpcURL, 23_234_810);

    // Instantiate the script contracts
    deployAndRegisterScript = new DeployAndRegisterScript();
  }

  function test_EndToEndProposalCreation() public {
    // No longer needed, but keeping this here for reference
    vm.skip(true);
    // =============================================================
    //      Step 1: Deploy Resolver and Register Schema
    // =============================================================
    console.log("Step 1: Deploying Resolver and registering schema...");
    (AgreementResolver resolver, bytes32 schemaUID) = deployAndRegisterScript.run();
    console.log("  -> Resolver deployed at:", address(resolver));
    console.log("  -> Schema UID registered:", vm.toString(schemaUID));

    // =============================================================
    //      Step 2: Create Agreement Anchors
    // =============================================================
    console.log("\nStep 2: Creating Agreement Anchors...");
    address factoryAddress = address(resolver.ANCHOR_FACTORY());
    console.log("  -> Using factory at:", factoryAddress);

    // We use a "patched" script to inject the dynamically deployed factory address
    patchedCreateAgreementsScript = new PatchedCreateAgreementsScript(factoryAddress);
    address[] memory agreementAnchors = patchedCreateAgreementsScript.run();

    // Assert that the anchors were created successfully
    console.log("  -> Solo Anchor:", agreementAnchors[0]);
    console.log("  -> Cowrie Anchor:", agreementAnchors[1]);
    console.log("  -> UF Ministerial Anchor:", agreementAnchors[2]);

    // =============================================================
    //      Step 3: Create the Governance Proposal
    // =============================================================
    console.log("\nStep 3: Generating Governance Proposal Calldata...");

    // We use another "patched" script to inject the dynamically created anchor addresses and schema
    // UID
    patchedCreateProposalScript = new PatchedCreateProposalScript(agreementAnchors, schemaUID);

    vm.mockCall(
      address(UNI_TOKEN),
      abi.encodeWithSelector(IUni.getPriorVotes.selector, address(patchedCreateProposalScript)),
      abi.encode(50_000_000 * 1e18)
    );

    // =============================================================
    //      Step 4: Propose, Vote, Queue, and Execute
    // =============================================================

    // save balances of cowrie wallet and DUNI safe
    uint256 cowrieBalanceBefore =
      UNI_TOKEN.balanceOf(patchedCreateProposalScript.COWRIE_RECIPIENT());
    uint256 duniSafeBalanceBefore = UNI_TOKEN.balanceOf(patchedCreateProposalScript.DUNI_SAFE());

    // Propose
    vm.startPrank(proposer);
    uint256 proposalId = patchedCreateProposalScript.run();
    vm.stopPrank();

    // Vote
    vm.roll(block.number + GOVERNOR_BRAVO.votingDelay() + 1);
    vm.prank(address(patchedCreateProposalScript));
    GOVERNOR_BRAVO.castVote(proposalId, 1);

    // Queue
    vm.roll(block.number + GOVERNOR_BRAVO.votingPeriod() + 1);
    GOVERNOR_BRAVO.queue(proposalId);

    // Execute
    skip(2 days + 100);
    GOVERNOR_BRAVO.execute(proposalId);

    // now assert balance changes, attestation UIDs on anchors

    // assert attestation UIDs on anchors
    assertTrue(AgreementAnchor(agreementAnchors[0]).partyA_attestationUID() != bytes32(0));
    assertTrue(AgreementAnchor(agreementAnchors[1]).partyA_attestationUID() != bytes32(0));
    assertTrue(AgreementAnchor(agreementAnchors[2]).partyA_attestationUID() != bytes32(0));

    // assert balances
    assertEq(
      UNI_TOKEN.balanceOf(patchedCreateProposalScript.DUNI_SAFE()),
      duniSafeBalanceBefore + patchedCreateProposalScript.UNI_AMOUNT_DUNI_SAFE()
    );
    assertEq(
      UNI_TOKEN.balanceOf(patchedCreateProposalScript.COWRIE_RECIPIENT()),
      cowrieBalanceBefore + patchedCreateProposalScript.UNI_AMOUNT_COWRIE()
    );

    console.log("End-to-end simulation complete. Proposal calldata logged above.");
  }
}

// =================================================================================================
//      Helper Contracts for Patching Scripts
// =================================================================================================

/// @notice A patched version of the CreateAgreements script that allows injecting the factory
/// address.
contract PatchedCreateAgreementsScript is CreateAgreementsScript {
  constructor(address _factoryAddress) {
    FACTORY_ADDRESS = _factoryAddress;
  }
}

/// @notice A patched version of the CreateProposal script that allows injecting dynamic addresses.
contract PatchedCreateProposalScript is CreateProposalScript {
  constructor(address[] memory agreementAnchors, bytes32 schemaUID) {
    require(agreementAnchors.length == 3, "Must provide 3 anchor addresses");
    // Override with the dynamically generated values
    SOLO_AGREEMENT_ANCHOR = agreementAnchors[0];
    COWRIE_AGREEMENT_ANCHOR = agreementAnchors[1];
    UF_AGREEMENT_ANCHOR = agreementAnchors[2];
    AGREEMENT_SCHEMA_UID = schemaUID;
  }
}
