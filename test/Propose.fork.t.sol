// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, stdStorage, StdStorage, console} from "forge-std/Test.sol";

// Import the scripts we need to run
import {CreateProposal as CreateProposalScript} from "script/mainnet/CreateProposal.s.sol";

// Import contracts and interfaces needed for setup and interaction
import {AgreementAnchor} from "src/AgreementAnchor.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IGovernorBravo} from "script/mainnet/CreateProposal.s.sol";

interface IUni is IERC20 {
  function delegate(address delegatee) external;
  function getPriorVotes(address account, uint256 blockNumber) external view returns (uint256);
}

/// @title ProposalForkTest
/// @notice A mainnet fork test for the Uniswap governance proposal creation.
/// @dev This test simulates the following workflow:
///      1. Creates the calldata for the Uniswap governance proposal.
///      2. Simulates the proposal passing, being queued, and executed.
///      3. Verifies attestations were made and funds were transferred.
/// @dev It assumes that the AgreementResolver, its Factory, and the three
///      AgreementAnchor contracts have already been deployed and configured.
contract ProposalForkTest is Test {
  using stdStorage for StdStorage;
  // =============================================================
  //      State Variables for Scripts and Actors
  // =============================================================

  CreateProposalScript internal createProposalScript;

  address internal proposer = makeAddr("proposer");
  IUni internal constant UNI_TOKEN = IUni(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
  IGovernorBravo internal constant GOVERNOR_BRAVO =
    IGovernorBravo(0x408ED6354d4973f66138C91495F2f2FCbd8724C3);

  function setUp() public {
    // Fork from Mainnet
    string memory rpcURL = vm.envString("MAINNET_RPC_URL");
    vm.createSelectFork(rpcURL, 23_248_773);

    // Instantiate the script contract
    createProposalScript = new CreateProposalScript();
  }

  function test_ProposalCreationAndExecution() public {
    // =============================================================
    //      Step 1: Create the Governance Proposal
    // =============================================================
    console.log("\nStep 1: Generating Governance Proposal Calldata...");

    vm.mockCall(
      address(UNI_TOKEN),
      abi.encodeWithSelector(IUni.getPriorVotes.selector, address(createProposalScript)),
      abi.encode(50_000_000 * 1e18)
    );

    // =============================================================
    //      Step 2: Propose, Vote, Queue, and Execute
    // =============================================================

    // save balances of cowrie wallet and DUNI safe
    uint256 cowrieBalanceBefore = UNI_TOKEN.balanceOf(createProposalScript.COWRIE_RECIPIENT());
    uint256 duniSafeBalanceBefore = UNI_TOKEN.balanceOf(createProposalScript.DUNI_SAFE());

    // Propose
    vm.startPrank(proposer);
    uint256 proposalId = createProposalScript.run();
    vm.stopPrank();

    // Vote
    vm.roll(block.number + GOVERNOR_BRAVO.votingDelay() + 1);
    vm.prank(address(createProposalScript));
    GOVERNOR_BRAVO.castVote(proposalId, 1);

    // Queue
    vm.roll(block.number + GOVERNOR_BRAVO.votingPeriod() + 1);
    GOVERNOR_BRAVO.queue(proposalId);

    // Execute
    skip(2 days + 100);
    GOVERNOR_BRAVO.execute(proposalId);

    // now assert balance changes, attestation UIDs on anchors
    address[] memory agreementAnchors = new address[](3);
    agreementAnchors[0] = createProposalScript.SOLO_AGREEMENT_ANCHOR();
    agreementAnchors[1] = createProposalScript.COWRIE_AGREEMENT_ANCHOR();
    agreementAnchors[2] = createProposalScript.UF_AGREEMENT_ANCHOR();

    // assert attestation UIDs on anchors
    assertTrue(AgreementAnchor(agreementAnchors[0]).partyA_attestationUID() != bytes32(0));
    assertTrue(AgreementAnchor(agreementAnchors[1]).partyA_attestationUID() != bytes32(0));
    assertTrue(AgreementAnchor(agreementAnchors[2]).partyA_attestationUID() != bytes32(0));

    // assert balances
    assertEq(
      UNI_TOKEN.balanceOf(createProposalScript.DUNI_SAFE()),
      duniSafeBalanceBefore + createProposalScript.UNI_AMOUNT_DUNI_SAFE()
    );
    assertEq(
      UNI_TOKEN.balanceOf(createProposalScript.COWRIE_RECIPIENT()),
      cowrieBalanceBefore + createProposalScript.UNI_AMOUNT_COWRIE()
    );

    console.log("End-to-end simulation complete. Proposal calldata logged above.");
  }
}
