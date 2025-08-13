// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SchemaResolver} from "eas-contracts/resolver/SchemaResolver.sol";
import {IEAS, Attestation} from "eas-contracts/IEAS.sol";
import {AgreementAnchor} from "src/AgreementAnchor.sol";
import {AgreementFactory} from "src/AgreementFactory.sol";

contract AgreementResolver is SchemaResolver {
  AgreementFactory public immutable factory;

  constructor(IEAS eas, address _signer) SchemaResolver(eas) {
    factory = new AgreementFactory(_signer, address(this));
  }

  // This hook runs every time an attestation with this resolver is made
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

  function _enforceAttestationRules(Attestation calldata attestation)
    internal
    view
    returns (address attester, AgreementAnchor anchor)
  {
    attester = attestation.attester;
    anchor = AgreementAnchor(attestation.recipient);

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
    AgreementAnchor _anchor = AgreementAnchor(attestation.recipient);
    // The attester must be one of the two parties defined in the anchor
    require(
      attester == _anchor.partyA() || attester == _anchor.partyB(), "Not a party to this agreement"
    );
    // Parties can revoke any attestation they've made, but we'll only mark the anchor as revoked if
    // the attestation is the latest one for that party

    if (
      attestation.uid == _anchor.partyA_attestationUID()
        || attestation.uid == _anchor.partyB_attestationUID()
    ) _anchor.onRevoke();

    return true;
  }
}
