// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {SchemaResolver} from "eas-contracts/resolver/SchemaResolver.sol";
import {IEAS, Attestation} from "eas-contracts/IEAS.sol";
import {StatefulAgreementAnchor} from "./StatefulAgreementAnchor.sol";

contract AgreementResolver is SchemaResolver {
  constructor(IEAS eas) SchemaResolver(eas) {}

  // This hook runs every time an attestation with this resolver is made
  function onAttest(Attestation calldata attestation, uint256 /* value */ )
    internal
    override
    returns (bool)
  {
    (address _attester, StatefulAgreementAnchor _anchor) = _enforceAttestationRules(attestation);

    // If rules pass, update the anchor with the new attestation UID
    _anchor.updateAttestation(_attester, attestation.uid);

    return true;
  }

  function _enforceAttestationRules(Attestation calldata attestation)
    internal
    view
    returns (address attester, StatefulAgreementAnchor anchor)
  {
    attester = attestation.attester;
    anchor = StatefulAgreementAnchor(attestation.recipient);

    // The attester must be one of the two parties defined in the anchor
    require(
      attester == anchor.partyA() || attester == anchor.partyB(), "Not a party to this agreement"
    );

    // Attestation content hash must match anchor content hash
    require(
      abi.decode(attestation.data, (bytes32)) == anchor.contentHash(),
      "Attestation data does not match the anchor"
    );

    // Optionally enforce attestation expiration = 0, or other stuff
  }

  // This hook runs on revocation
  function onRevoke(Attestation calldata attestation, uint256 /* value */ )
    internal
    override
    returns (bool)
  {
    address attester = attestation.attester;
    StatefulAgreementAnchor _anchor = StatefulAgreementAnchor(attestation.recipient);
    // The attester must be one of the two parties defined in the anchor
    require(
      attester == _anchor.partyA() || attester == _anchor.partyB(), "Not a party to this agreement"
    );
    // Revoke the anchor
    _anchor.revoke();
    return true;
  }
}
