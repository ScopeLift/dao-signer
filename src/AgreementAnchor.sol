// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract AgreementAnchor {
  bytes32 public immutable contentHash;
  address public immutable partyA;
  address public immutable partyB;
  address public immutable resolver; // This anchor only trusts one resolver

  bytes32 public partyA_attestationUID;
  bytes32 public partyB_attestationUID;
  bool public didEitherPartyRevoke;

  error AgreementRevoked();
  error AgreementAlreadyAttested();
  error NotAParty();

  modifier onlyResolver() {
    require(msg.sender == resolver, "Only the EAS resolver can update state");
    _;
  }

  /// @notice Constructor for the AgreementAnchor.
  /// @param _contentHash The content hash of the agreement.
  /// @param _partyA The address of partyA.
  /// @param _partyB The address of partyB.
  /// @param _resolver The address of the EAS resolver.
  constructor(bytes32 _contentHash, address _partyA, address _partyB, address _resolver) {
    contentHash = _contentHash;
    partyA = _partyA;
    partyB = _partyB;
    resolver = _resolver;
  }

  /// @notice Called by the resolver to set an attestation UID for a party.
  /// @param party The party that is being attested to.
  /// @param uid The UID of the attestation.
  function onAttest(address party, bytes32 uid) external onlyResolver {
    if (didEitherPartyRevoke) revert AgreementRevoked();
    if (partyA_attestationUID != 0x0 && partyB_attestationUID != 0x0) {
      revert AgreementAlreadyAttested();
    }
    if (party == partyA) partyA_attestationUID = uid;
    else if (party == partyB) partyB_attestationUID = uid;
    // should never get here, as resolver has already checked
    else revert NotAParty();
  }

  /// @notice Called by the resolver to mark the anchor as revoked.
  function onRevoke() external onlyResolver {
    didEitherPartyRevoke = true;
  }
}
