// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AgreementAnchor} from "src/AgreementAnchor.sol";

interface IAgreementFactory {
  event AgreementCreated(
    address indexed agreement,
    bytes32 indexed contentHash,
    address signer,
    address indexed counterSigner
  );

  function createAgreementAnchor(bytes32 _contentHash, address _counterSigner)
    external
    returns (AgreementAnchor);
}
