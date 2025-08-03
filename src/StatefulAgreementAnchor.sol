// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract StatefulAgreementAnchor {
  bytes32 public immutable contentHash;
  address public immutable partyA;
  address public immutable partyB;
  address public immutable resolver; // This anchor only trusts one resolver

  bytes32 public partyA_attestationUID;
  bytes32 public partyB_attestationUID;
  bool public isRevoked;

  modifier onlyResolver() {
    require(msg.sender == resolver, "Only the resolver can update state");
    _;
  }

  constructor(bytes32 _contentHash, address _partyA, address _partyB, address _resolver) {
    contentHash = _contentHash;
    partyA = _partyA;
    partyB = _partyB;
    resolver = _resolver;
  }

  // Called by the resolver to update the latest attestation UID for a party
  function updateAttestation(address party, bytes32 uid) external onlyResolver {
    // TODO: if both parties have attested, revert on update?
    // TODO: if counterparty attestation is revoked, revert?
    if (party == partyA) partyA_attestationUID = uid;
    else if (party == partyB) partyB_attestationUID = uid;
  }

  function revoke() external onlyResolver {
    isRevoked = true;
  }
}
