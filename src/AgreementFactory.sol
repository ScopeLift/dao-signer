// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IEAS} from "eas-contracts/IEAS.sol";
import {AgreementAnchor} from "./AgreementAnchor.sol";

/// @title AgreementFactory
/// @notice Factory for creating AgreementAnchors
/// @dev This factory is used by some fixed partyA (e.g. a DAO) to create AgreementAnchors for a
/// given content hash and countersigner.
contract AgreementFactory {
  address public immutable resolver;
  address public immutable primarySigner;

  constructor(address _resolver, address _primarySigner) {
    resolver = _resolver;
    primarySigner = _primarySigner;
  }

  function createAgreement(bytes32 _contentHash, address _counterSigner)
    external
    returns (AgreementAnchor)
  {
    // TODO: use clones (preferably with deterministic address so that we can createAndAttest)
    return new AgreementAnchor(_contentHash, primarySigner, _counterSigner, resolver);
  }
}
