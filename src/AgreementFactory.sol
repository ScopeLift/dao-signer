// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AgreementAnchor} from "src/AgreementAnchor.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

/// @title AgreementFactory
/// @notice Factory for creating AgreementAnchors
/// @dev This factory is used by some fixed partyA (e.g. a DAO) to create AgreementAnchors for a
/// given content hash and countersigner.
contract AgreementFactory {
  address public immutable resolver;
  address public immutable signer;
  AgreementAnchor public immutable agreementAnchor;

  event AgreementCreated(
    address indexed agreement,
    bytes32 indexed contentHash,
    address signer,
    address indexed counterSigner
  );

  constructor(address _resolver, address _signer) {
    resolver = _resolver;
    signer = _signer;
    agreementAnchor = new AgreementAnchor(0x0, address(0), address(0), address(0));
  }

  function createAgreement(bytes32 _contentHash, address _counterSigner)
    external
    returns (AgreementAnchor)
  {
    address agreement = Clones.cloneDeterministicWithImmutableArgs(
      address(agreementAnchor),
      abi.encode(signer, _counterSigner, resolver),
      keccak256(abi.encode(_contentHash, signer, _counterSigner))
    );
    emit AgreementCreated(agreement, _contentHash, signer, _counterSigner);
    return AgreementAnchor(agreement);
  }

  function predictAgreementAddress(bytes32 _contentHash, address _counterSigner)
    external
    view
    returns (address)
  {
    return Clones.predictDeterministicAddressWithImmutableArgs(
      address(agreementAnchor),
      abi.encode(signer, _counterSigner, resolver),
      keccak256(abi.encode(_contentHash, signer, _counterSigner)),
      address(this)
    );
  }
}
