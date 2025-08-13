// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AgreementAnchor} from "src/AgreementAnchor.sol";

/// @title AgreementFactory
/// @notice Factory for creating AgreementAnchors
/// @dev This factory is used by some fixed partyA (e.g. a DAO) to create AgreementAnchors for
/// content hash/counterparty pairs.
contract AgreementFactory {
  address public immutable resolver;
  address public immutable signer;

  event AgreementCreated(
    address indexed agreement,
    bytes32 indexed contentHash,
    address signer,
    address indexed counterSigner
  );

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
    emit AgreementCreated(address(agreementAnchor), _contentHash, signer, _counterSigner);
    return agreementAnchor;
  }
}
