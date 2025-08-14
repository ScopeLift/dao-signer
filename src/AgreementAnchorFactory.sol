// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AgreementAnchor} from "src/AgreementAnchor.sol";
import {IAgreementAnchorFactory} from "src/interfaces/IAgreementAnchorFactory.sol";

/// @title AgreementAnchorFactory
/// @notice Factory for creating AgreementAnchors for some party `signer`
/// @dev This factory is used by some fixed partyA (e.g. a DAO) to create AgreementAnchors for
/// content hash <-> counterparty pairs.
contract AgreementAnchorFactory is IAgreementAnchorFactory {
  /// @notice The EAS AgreementResolver that deployed this factory.
  address public immutable resolver;

  /// @notice The principal signer for the created AgreementAnchors.
  address public immutable signer;

  /// @inheritdoc IAgreementAnchorFactory
  mapping(address => bool) public isFactoryDeployed;

  /// @notice Constructor for the AgreementFactory.
  /// @param _resolver The EAS resolver that deployed this factory.
  /// @param _signer The principal signer for the AgreementAnchors.
  constructor(address _resolver, address _signer) {
    resolver = _resolver;
    signer = _signer;
  }

  /// @inheritdoc IAgreementAnchorFactory
  function createAgreementAnchor(bytes32 _contentHash, address _counterSigner)
    external
    returns (AgreementAnchor)
  {
    AgreementAnchor agreementAnchor =
      new AgreementAnchor(_contentHash, signer, _counterSigner, resolver);
    isFactoryDeployed[address(agreementAnchor)] = true;
    emit AgreementCreated(address(agreementAnchor), _contentHash, signer, _counterSigner);
    return agreementAnchor;
  }
}
