// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AgreementAnchor} from "src/AgreementAnchor.sol";
import {IAgreementFactory} from "src/interfaces/IAgreementFactory.sol";

/// @title AgreementFactory
/// @notice Factory for creating AgreementAnchors
/// @dev This factory is used by some fixed partyA (e.g. a DAO) to create AgreementAnchors for
/// content hash <-> counterparty pairs.
contract AgreementFactory is IAgreementFactory {
  address public immutable resolver;
  address public immutable signer;
  mapping(address => bool) public isAgreementAnchor;

  constructor(address _resolver, address _signer) {
    resolver = _resolver;
    signer = _signer;
  }

  function createAgreementAnchor(bytes32 _contentHash, address _counterSigner)
    external
    returns (AgreementAnchor)
  {
    AgreementAnchor agreementAnchor =
      new AgreementAnchor(_contentHash, signer, _counterSigner, resolver);
    isAgreementAnchor[address(agreementAnchor)] = true;
    emit AgreementCreated(address(agreementAnchor), _contentHash, signer, _counterSigner);
    return agreementAnchor;
  }
}
