// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IEAS, AttestationRequest, AttestationRequestData} from "eas-contracts/IEAS.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {AgreementAnchor} from "src/AgreementAnchor.sol";
import {AgreementResolver} from "src/AgreementResolver.sol";

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
  //      Proposal TODOs
  // =============================================================

  // TODO: VERIFY the correct recipient address for Cowrie.
  address public constant COWRIE_RECIPIENT = 0x96855185279B526D7ad7e4A21B3f8d4f8Ca859da;
  address public constant DUNI_SAFE = 0x2D994F6BCB8165eEE9e711af3eA9e92863E35a7A;

  // TODO: Update these values with the final UNI amounts calculated on Sunday.
  // Represents $75k worth of UNI.
  uint256 public constant UNI_AMOUNT_COWRIE = 7623.54 * 1e18;
  // Represents $16.5m worth of UNI.
  uint256 public constant UNI_AMOUNT_DUNI_SAFE = 1_677_178 * 1e18;

  // TODO: Confirm proposal description
  string internal constant PROPOSAL_DESCRIPTION =
    "# Establish Uniswap Governance as \"DUNI,\" a Wyoming DUNA\n\n" "## Summary\n\n"
    "The Uniswap Foundation (\"UF\") proposes that Uniswap Governance adopt a Wyoming-registered "
    "Decentralized Unincorporated Nonprofit Association (\"DUNA\") as the legal structure for the "
    "Uniswap Governance Protocol. This new legal entity, called \"DUNI\", will be purpose-built to "
    "preserve Uniswap's decentralized governance structure while enabling engagement with the offchain "
    "world (e.g., entering into contracts, retaining service providers, and fulfilling any potential "
    "regulatory and tax responsibilities).\n\n"
    "If adopted, DUNI will be a legal entity for Uniswap Governance that recognizes the binding "
    "validity of onchain Governance Proposals with the intention of providing certainty regarding its "
    "legal structure and intended liability protections for members of DUNI. Adopting DUNI does not, "
    "in any way, alter the Uniswap Protocol, the UNI token, or the core mechanics of onchain governance. "
    "Rather, it represents a significant step in equipping Uniswap Governance for the future.\n\n"
    "Importantly, establishing Uniswap Governance as a DUNA would bolster critical limited liability "
    "protections for governance participants. This step is intended to protect governance participants "
    "from potential personal exposure to possible legal or tax liabilities stemming from the collective "
    "action taken by Uniswap Governance. This is a critical step in de-risking engagement in Uniswap "
    "Governance without compromising decentralization.\n\n" "## Background & Motivation\n\n"
    "In the Uniswap Unleashed roadmap, we described a vision for evolving Uniswap Governance. In this "
    "vision, Governance can turn on the protocol fee, fund innovation, form partnerships, and navigate "
    "legal obligations with confidence. While onchain governance is integral to Uniswap's credible "
    "neutrality, it has historically lacked the corresponding infrastructure for basic offchain "
    "coordination and formalized protection for its collective actions. To execute on our vision, we "
    "need something more.\n\n"
    "To that end, over the past two years, the Uniswap Foundation has explored options for establishing "
    "a legal structure that is intended to:\n\n"
    "- Provide more clarity regarding liability protection for Uniswap Governance participants;\n"
    "- Maintain the primary authority of the Uniswap Governance protocol; and\n"
    "- Enable execution of offchain operations without introducing centralized points of control.\n\n"
    "After significant research, legal consultation, and community engagement, the Wyoming DUNA (passed "
    "into law in 2024) emerged as a credibly neutral and transparent option. It has been explicitly "
    "designed for decentralized protocol governance systems to gain legal legitimacy without "
    "compromising their core ethos.\n\n"
    "In our research, we have worked closely with a firm called Cowrie, founded by David Kerr. Based in "
    "Cheyenne, Wyoming, Cowrie is composed of a team of regulatory and technical experts that provides "
    "legal, financial, and administrative support to decentralized protocols. David was instrumental in "
    "writing Wyoming's DUNA statute, and has worked directly with legislators to educate them on the "
    "intricacies of the DUNA, what it enables DAOs to accomplish, what DAOs are, why decentralization is "
    "important, etc. Cowrie's role in the context of DUNI is to act as an Administrator of DUNI - "
    "facilitating regulatory and tax compliance, tax filings, informational reporting, and operational "
    "infrastructure within the constructs of its authorizations.\n\n" "## Specification\n\n"
    "If this proposal passes, the resulting onchain transaction will adopt a DUNA for Uniswap Governance. "
    "Specifically, it will:\n\n"
    "- Ratify the DUNA's Association Agreement establishing the rules of DUNI;\n"
    "- Execute a Ministerial Agent Agreement with the Uniswap Foundation; and\n"
    "- Execute an Administrator Agreement with Cowrie - Administrator Services; This includes the "
    "execution of a separate Administrator Agreement with David Kerr (CEO of Cowrie) for specific "
    "authorizations.\n\n"
    "Additionally, the transaction will execute two transfers of UNI from the treasury, specifically:\n\n"
    "- $16.5m worth of UNI to a DUNI-owned wallet to prefund a legal defense budget and a tax compliance budget;\n"
    "- $75k worth of UNI to Cowrie for their services as compliance administrator.\n\n"
    "All supporting documentation can be found on the [UF's website here](https://www.uniswapfoundation.org/duni).";

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
  address public SOLO_AGREEMENT_ANCHOR = address(0xe4b69D68341abBdd08023cD39bAe9a0D5360B6c1);
  address public COWRIE_AGREEMENT_ANCHOR = address(0x22005982Ae6BD2E90167F34a4604FfD59AFa7E9d);
  address public UF_AGREEMENT_ANCHOR = address(0x5267b6C862D3e8826717Eba42936e310425C02FA);

  bytes32 public AGREEMENT_SCHEMA_UID = SOLO_AGREEMENT_ANCHOR.code.length == 0
    ? bytes32(0)
    : AgreementResolver(payable(AgreementAnchor(SOLO_AGREEMENT_ANCHOR).RESOLVER()))
      .AGREEMENT_SCHEMA_UID();

  // Content hashes
  bytes32 constant SOLO_CONTENT_HASH =
    0xe8c79f54b28f0f008fc23ae671265b2c915d0c4328733162967f85578ea36748;
  bytes32 constant COWRIE_CONTENT_HASH =
    0x1e9a075250e3bb62dec90c499ff00a8def24f4e9be7984daf11936d57dca2f76;
  bytes32 constant UF_CONTENT_HASH =
    0x6dd5ee280fe12c69425c9d4b137d8f64578f5e67b76904e994687644f7511516;

  function run() public returns (uint256 proposalId) {
    // --- Proposal Actions Setup ---
    address[] memory targets = new address[](5);
    uint256[] memory values = new uint256[](5);
    string[] memory signatures = new string[](5);
    bytes[] memory calldatas = new bytes[](5);
    string memory description = PROPOSAL_DESCRIPTION;

    // --- Action 1: Attest to the Solo Agreement ---
    targets[0] = address(EAS);
    values[0] = 0;
    signatures[0] = "";
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

    console.log("Calldata details:");
    for (uint256 i = 0; i < calldatas.length; i++) {
      console.log("Target", i);
      console.log(targets[i]);
      console.log("Value", i);
      console.log(values[i]);
      console.log("Signature", i);
      console.log(signatures[i]);
      console.log("Calldata", i);
      console.logBytes(calldatas[i]);
      console.log("--------------------------------");
    }

    console.log("Description:");
    console.log(description);

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
