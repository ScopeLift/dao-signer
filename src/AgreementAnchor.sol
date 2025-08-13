// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract AgreementAnchor {
  bytes32 public immutable contentHash;
  address public immutable partyA;
  address public immutable partyB;
  address public immutable resolver; // This anchor only trusts one resolver

  bytes32 public partyA_attestationUID;
  bytes32 public partyB_attestationUID;
  bool public isRevoked;

  error AgreementRevoked();
  error AgreementAlreadyAttested();

  modifier onlyResolver() {
    require(msg.sender == resolver, "Only the EAS resolver can update state");
    _;
  }

  constructor(bytes32 _contentHash, address _partyA, address _partyB, address _resolver) {
    contentHash = _contentHash;
    partyA = _partyA;
    partyB = _partyB;
    resolver = _resolver;
  }

  // Called by the resolver to update the latest attestation UID for a party
  function onAttest(address party, bytes32 uid) external onlyResolver {
    if (isRevoked) revert AgreementRevoked();
    if (partyA_attestationUID != 0x0 && partyB_attestationUID != 0x0) {
      revert AgreementAlreadyAttested();
    }
    if (party == partyA) partyA_attestationUID = uid;
    else if (party == partyB) partyB_attestationUID = uid;
  }

  function onRevoke() external onlyResolver {
    isRevoked = true;
  }
}
