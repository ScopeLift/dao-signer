// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title AgreementAnchor
/// @notice An anchor for an agreement between two parties.
/// @dev This anchor is used to store the content hash of the agreement and the UIDs of the
/// attestations for each party.
/// @dev This anchor is used in the recipient field of an EAS attestation.
contract AgreementAnchor {
  /// @notice The content hash of the agreement.
  bytes32 public immutable CONTENT_HASH;
  /// @notice The address of partyA.
  address public immutable PARTY_A;
  /// @notice The address of partyB.
  address public immutable PARTY_B;
  /// @notice The address of the EAS resolver.
  address public immutable RESOLVER;

  /// @notice The UID of the latest attestation for partyA.
  bytes32 public partyA_attestationUID;
  /// @notice The UID of the latest attestation for partyB.
  bytes32 public partyB_attestationUID;

  /// @notice Thrown when a party attests on this anchor but has already attested.
  error AgreementAnchor__AlreadyAttested();
  /// @notice Thrown when a party attests on this anchor but is not a party to the agreement.
  error AgreementAnchor__NotAParty();

  modifier onlyResolver() {
    require(msg.sender == RESOLVER, "Only the EAS resolver can update state");
    _;
  }

  /// @notice Constructor for the `AgreementAnchor`.
  /// @param _contentHash The content hash of the agreement.
  /// @param _partyA The address of partyA.
  /// @param _partyB The address of partyB.
  /// @param _resolver The address of the EAS resolver.
  constructor(bytes32 _contentHash, address _partyA, address _partyB, address _resolver) {
    CONTENT_HASH = _contentHash;
    PARTY_A = _partyA;
    PARTY_B = _partyB;
    RESOLVER = _resolver;
  }

  /// @notice Called by the resolver to set an attestation UID for a party.
  /// @param party The party that is being attested to.
  /// @param uid The UID of the attestation.
  function onAttest(address party, bytes32 uid) external onlyResolver {
    if (party == PARTY_A) {
      if (partyA_attestationUID != 0x0) revert AgreementAnchor__AlreadyAttested();
      partyA_attestationUID = uid;
    } else if (party == PARTY_B) {
      if (partyB_attestationUID != 0x0) revert AgreementAnchor__AlreadyAttested();
      partyB_attestationUID = uid;
    } else {
      // should never get here, as resolver has already checked
      revert AgreementAnchor__NotAParty();
    }
  }
}
