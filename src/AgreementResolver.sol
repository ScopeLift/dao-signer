// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SchemaResolver} from "eas-contracts/resolver/SchemaResolver.sol";
import {IEAS, Attestation} from "eas-contracts/IEAS.sol";
import {AgreementAnchor} from "src/AgreementAnchor.sol";
import {AgreementAnchorFactory} from "src/AgreementAnchorFactory.sol";

/// @title AgreementResolver
/// @notice An EAS resolver for AgreementAnchors. These hooks are called from EAS when an
/// attestation or revocation is made. They ensure that the attestation is from a party to the
/// agreement, and that the content hash matches the anchor.
/// @dev This resolver is used to create AgreementAnchors for some party `signer`
/// @dev This resolver is used by some fixed partyA (e.g. a DAO) to create AgreementAnchors for
/// content hash <-> counterparty pairs. It is deployed with a fixed signer, and then used to
/// create AgreementAnchors for different counterparty addresses.
contract AgreementResolver is SchemaResolver {
  /// @notice The factory that will be used to create AgreementAnchors for this resolver.
  AgreementAnchorFactory public immutable ANCHOR_FACTORY;

  /// @notice The UID of the Agreement schema.
  bytes32 public immutable AGREEMENT_SCHEMA_UID;

  /// @notice The schema for the Agreement.
  string public constant AGREEMENT_SCHEMA = "bytes32 contentHash";

  /// @notice Constructor for the AgreementResolver.
  /// @param eas The EAS instance to use for attestation storage.
  /// @param _signer The principal signer for the created AgreementAnchors.
  constructor(IEAS eas, address _signer) SchemaResolver(eas) {
    ANCHOR_FACTORY = new AgreementAnchorFactory(address(this), _signer);
    AGREEMENT_SCHEMA_UID = _getUID();
  }

  /// @dev Calculates a UID for the Agreement schema.
  /// @return schema UID.
  function _getUID() private view returns (bytes32) {
    return keccak256(abi.encodePacked(AGREEMENT_SCHEMA, address(this), false));
  }

  /// @notice This hook is called from EAS when an attestation for this schema is made. It
  /// does checks to make sure the attestations are from the correct parties and that the content
  /// hash matches the anchor.
  /// @param attestation The attestation to be checked.
  /// @return True if the attestation is valid, false otherwise.
  function onAttest(Attestation calldata attestation, uint256 /* value */ )
    internal
    override
    returns (bool)
  {
    (address _attester, AgreementAnchor _anchor) = _enforceAttestationRules(attestation);

    // If rules pass, update the anchor with the new attestation UID
    _anchor.onAttest(_attester, attestation.uid);
    return true;
  }

  /// @notice Enforces the attestation rules for the given attestation.
  /// @param attestation The attestation to be checked.
  /// @return attester The address of the attester.
  /// @return anchor The AgreementAnchor that the attestation is for.
  function _enforceAttestationRules(Attestation calldata attestation)
    internal
    view
    returns (address attester, AgreementAnchor anchor)
  {
    attester = attestation.attester;
    anchor = AgreementAnchor(attestation.recipient);

    // The attestation must be for the correct schema
    require(attestation.schema == AGREEMENT_SCHEMA_UID, "Incorrect schema UID");

    // The anchor must have been deployed by this factory
    require(ANCHOR_FACTORY.isFactoryDeployed(address(anchor)), "Not a factory-deployed anchor");

    // The attester must be one of the two parties defined in the anchor
    require(
      attester == anchor.PARTY_A() || attester == anchor.PARTY_B(), "Not a party to this agreement"
    );

    // Attestation content hash must match anchor content hash
    require(
      abi.decode(attestation.data, (bytes32)) == anchor.CONTENT_HASH(),
      "Attestation data does not match the anchor"
    );

    // Attestation expiration must be 0
    require(attestation.expirationTime == 0, "Attestation must not have an expiration");

    // Optionally enforce attestation must have an empty refUID
  }

  /// @notice This hook is called from EAS when an attestation for this schema is revoked.
  /// @dev This is meant to be used by a schema that does not allow revocation.
  /// @return False, as revocations are not supported.
  function onRevoke(Attestation calldata, /* attestation */ uint256 /* value */ )
    internal
    pure
    override
    returns (bool)
  {
    return false;
  }
}
