// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IEAS, AttestationRequest, AttestationRequestData} from "eas-contracts/IEAS.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

interface IGovernorBravo {
  function propose(
    address[] memory targets,
    uint256[] memory values,
    string[] memory signatures,
    bytes[] memory calldatas,
    string memory description
  ) external returns (uint256);

  function queue(uint256 proposalId) external;

  function execute(uint256 proposalId) external;

  function castVote(uint256 proposalId, uint8 support) external;

  function votingPeriod() external view returns (uint256);

  function votingDelay() external view returns (uint256);
}

/// @title CreateProposal
/// @notice This script generates the calldata for a Uniswap governance proposal.
/// @dev The proposal will execute five actions:
///      1. Attest to the Solo DUNA Agreement.
///      2. Attest to the Administrator Agreement with Cowrie.
///      3. Attest to the Ministerial Agent Agreement with the Uniswap Foundation.
///      4. Transfer UNI tokens to Cowrie.
///      5. Transfer UNI tokens to the DUNI Safe.
/// @dev This script assumes that the `CreateAgreements.s.sol` script has already been executed,
///      and the resulting AgreementAnchor addresses are known and provided as constants.
contract CreateProposal is Script {
  // =============================================================
  //      Protocol & Governance Constants
  // =============================================================
  IGovernorBravo internal constant GOVERNOR_BRAVO =
    IGovernorBravo(0x408ED6354d4973f66138C91495F2f2FCbd8724C3);
  IERC20 internal constant UNI_TOKEN = IERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
  IEAS internal constant EAS = IEAS(0xA1207F3BBa224E2c9c3c6D5aF63D0eb1582Ce587);

  // =============================================================
  //      Agreement Anchor Constants
  // =============================================================
  // TODO: Replace these placeholder addresses with the actual addresses of the deployed
  // AgreementAnchors.
  address SOLO_AGREEMENT_ANCHOR = address(0x0000000000000000000000000000000000000001);
  address COWRIE_AGREEMENT_ANCHOR = address(0x0000000000000000000000000000000000000002);
  address UF_AGREEMENT_ANCHOR = address(0x0000000000000000000000000000000000000003);

  // TODO: Replace with the UID of the schema registered by `DeployAndRegisterSchema.s.sol`.
  bytes32 AGREEMENT_SCHEMA_UID =
    bytes32(0x0000000000000000000000000000000000000000000000000000000000000004);

  // Content hashes
  bytes32 constant SOLO_CONTENT_HASH =
    0xe8c79f54b28f0f008fc23ae671265b2c915d0c4328733162967f85578ea36748;
  bytes32 constant COWRIE_CONTENT_HASH =
    0x1e9a075250e3bb62dec90c499ff00a8def24f4e9be7984daf11936d57dca2f76;
  bytes32 constant UF_CONTENT_HASH =
    0xa2fd33dd87091d25c15d94c0097395c08f2689efe6a2f8c53a1194222e442dd5;

  // =============================================================
  //      Financial & Recipient Constants
  // =============================================================
  // TODO: Replace with the correct recipient address for Cowrie.
  address public constant COWRIE_RECIPIENT = address(bytes20("cowrie"));
  address public constant DUNI_SAFE = 0x2D994F6BCB8165eEE9e711af3eA9e92863E35a7A;

  // TODO: Update these values with the final UNI amounts calculated on Sunday.
  // Represents $75k worth of UNI.
  uint256 public constant UNI_AMOUNT_COWRIE = 10_000 * 1e18;
  // Represents $16.5m worth of UNI.
  uint256 public constant UNI_AMOUNT_DUNI_SAFE = 2_000_000 * 1e18;

  function run() public returns (uint256 proposalId) {
    // --- Proposal Actions Setup ---
    address[] memory targets = new address[](5);
    uint256[] memory values = new uint256[](5);
    string[] memory signatures = new string[](5);
    bytes[] memory calldatas = new bytes[](5);
    string memory description =
      "Proposal to Finalize DUNI Service Provider Agreements and Fund Operations";

    // --- Action 1: Attest to the Solo Agreement ---
    targets[0] = address(EAS);
    values[0] = 0;
    signatures[0] = ""; // GovernorBravo allows empty signatures when calldata has selector
    AttestationRequest memory soloAttestationRequest =
      _buildAttestationRequest(SOLO_AGREEMENT_ANCHOR, SOLO_CONTENT_HASH);
    calldatas[0] = abi.encodeCall(IEAS.attest, (soloAttestationRequest));

    // --- Action 2: Attest to the Administrator Agreement with Cowrie ---
    targets[1] = address(EAS);
    values[1] = 0;
    signatures[1] = "";
    AttestationRequest memory cowrieAttestationRequest =
      _buildAttestationRequest(COWRIE_AGREEMENT_ANCHOR, COWRIE_CONTENT_HASH);
    calldatas[1] = abi.encodeCall(IEAS.attest, (cowrieAttestationRequest));

    // --- Action 3: Attest to the Ministerial Agent Agreement with UF ---
    targets[2] = address(EAS);
    values[2] = 0;
    signatures[2] = "";
    AttestationRequest memory ufAttestationRequest =
      _buildAttestationRequest(UF_AGREEMENT_ANCHOR, UF_CONTENT_HASH);
    calldatas[2] = abi.encodeCall(IEAS.attest, (ufAttestationRequest));

    // --- Action 4: Transfer UNI to Cowrie ---
    targets[3] = address(UNI_TOKEN);
    values[3] = 0;
    signatures[3] = "";
    calldatas[3] = abi.encodeCall(IERC20.transfer, (COWRIE_RECIPIENT, UNI_AMOUNT_COWRIE));

    // --- Action 5: Transfer UNI to DUNI Safe ---
    targets[4] = address(UNI_TOKEN);
    values[4] = 0;
    signatures[4] = "";
    calldatas[4] = abi.encodeCall(IERC20.transfer, (DUNI_SAFE, UNI_AMOUNT_DUNI_SAFE));

    // --- Encode the final propose call ---
    bytes memory proposalCalldata =
      abi.encodeCall(IGovernorBravo.propose, (targets, values, signatures, calldatas, description));

    console.log("GovernorBravo.propose() Calldata:");
    console.logBytes(proposalCalldata);

    proposalId = GOVERNOR_BRAVO.propose(targets, values, signatures, calldatas, description);
  }

  /// @dev Helper function to construct a standardized AttestationRequest struct.
  function _buildAttestationRequest(address recipientAnchor, bytes32 contentHash)
    internal
    view
    returns (AttestationRequest memory)
  {
    return AttestationRequest({
      schema: AGREEMENT_SCHEMA_UID,
      data: AttestationRequestData({
        recipient: recipientAnchor,
        expirationTime: 0,
        revocable: false,
        refUID: bytes32(0),
        data: abi.encode(contentHash),
        value: 0
      })
    });
  }
}
