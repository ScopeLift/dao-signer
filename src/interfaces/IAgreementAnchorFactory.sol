// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AgreementAnchor} from "src/AgreementAnchor.sol";

interface IAgreementAnchorFactory {
  /// @notice Emitted when a new AgreementAnchor is created.
  /// @param agreement The address of the AgreementAnchor.
  /// @param contentHash The content hash for the agreement.
  /// @param signer The principal signer for the agreement.
  /// @param counterSigner The counterparty signer for the agreement.
  event AgreementCreated(
    address indexed agreement,
    bytes32 indexed contentHash,
    address signer,
    address indexed counterSigner
  );

  /// @notice Checks if an AgreementAnchor was deployed by this factory.
  /// @param _agreementAnchor The address of the AgreementAnchor to check.
  /// @return True if the AgreementAnchor was deployed by this factory, false otherwise.
  function isFactoryDeployed(address _agreementAnchor) external view returns (bool);

  /// @notice Creates a new AgreementAnchor for a given content hash and counterparty.
  /// @param _contentHash The content hash for the agreement.
  /// @param _counterSigner The address of the counterparty.
  /// @return The new AgreementAnchor.
  function createAgreementAnchor(bytes32 _contentHash, address _counterSigner)
    external
    returns (AgreementAnchor);
}
