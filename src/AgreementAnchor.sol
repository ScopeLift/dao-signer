// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title AgreementAnchor
/// @notice An anchor for an agreement between two parties.
/// @dev This anchor is used to store the content hash of the agreement and the UIDs of the latest
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
  /// @notice Whether either party has revoked the agreement.
  bool public didEitherPartyRevoke;

  /// @notice Emitted when a party has revoked their attestation.
  event PartyRevoked(address indexed party, bytes32 indexed uid);

  /// @notice Thrown when either party has revoked the agreement, and another attestation is made.
  error AgreementAnchor__AgreementRevoked();
  /// @notice Thrown when both parties have attested to the agreement, and another attestation is
  /// made.
  error AgreementAnchor__AgreementAlreadyAttested();
  /// @notice Thrown when a party attests with this anchor but is not a party to the agreement.
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
    if (didEitherPartyRevoke) revert AgreementAnchor__AgreementRevoked();
    if (partyA_attestationUID != 0x0 && partyB_attestationUID != 0x0) {
      revert AgreementAnchor__AgreementAlreadyAttested();
    }
    if (party == PARTY_A) partyA_attestationUID = uid;
    else if (party == PARTY_B) partyB_attestationUID = uid;
    // should never get here, as resolver has already checked
    else revert AgreementAnchor__NotAParty();
  }

  /// @notice Called by the resolver to mark the anchor as revoked.
  function onRevoke(address _party, bytes32 _uid) external onlyResolver {
    didEitherPartyRevoke = true;
    emit PartyRevoked(_party, _uid);
  }
}
