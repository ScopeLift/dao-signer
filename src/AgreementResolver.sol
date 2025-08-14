// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SchemaResolver} from "eas-contracts/resolver/SchemaResolver.sol";
import {IEAS, Attestation} from "eas-contracts/IEAS.sol";
import {AgreementAnchor} from "src/AgreementAnchor.sol";
import {AgreementFactory} from "src/AgreementFactory.sol";

contract AgreementResolver is SchemaResolver {
  AgreementFactory public immutable factory;

  /// @notice Constructor for the AgreementResolver.
  /// @param eas The EAS instance to use for attestation storage.
  /// @param _signer The principal signer for the created AgreementAnchors.
  constructor(IEAS eas, address _signer) SchemaResolver(eas) {
    factory = new AgreementFactory(address(this), _signer);
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

    // The anchor must have been deployed by this factory
    require(factory.isFactoryDeployed(address(anchor)), "Not a factory-deployed anchor");

    // The attester must be one of the two parties defined in the anchor
    require(
      attester == anchor.partyA() || attester == anchor.partyB(), "Not a party to this agreement"
    );

    // Attestation content hash must match anchor content hash
    require(
      abi.decode(attestation.data, (bytes32)) == anchor.contentHash(),
      "Attestation data does not match the anchor"
    );

    // Optionally enforce attestation expiration = 0, etc
  }

  /// @notice This hook is called from EAS when an attestation for this schema is revoked.
  /// @param attestation The attestation to be revoked.
  /// @return True if the attestation is revoked, false otherwise.
  function onRevoke(Attestation calldata attestation, uint256 /* value */ )
    internal
    override
    returns (bool)
  {
    AgreementAnchor _anchor = AgreementAnchor(attestation.recipient);

    // Because the resolver has already checked that the attester is a party to the agreement,
    // we can assume that:
    // 1. The anchor is factory-deployed
    // 2. The attester is either partyA or partyB

    // Parties can revoke any attestation they've made, but we'll only mark the anchor as revoked if
    // the attestation is the latest one for that party.
    if (
      attestation.uid == _anchor.partyA_attestationUID()
        || attestation.uid == _anchor.partyB_attestationUID()
    ) _anchor.onRevoke();

    return true;
  }
}
