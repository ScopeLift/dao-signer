// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {
  EAS,
  IEAS,
  AttestationRequest,
  AttestationRequestData,
  RevocationRequest,
  RevocationRequestData
} from "eas-contracts/EAS.sol";
import {SchemaRegistry, ISchemaRegistry} from "eas-contracts/SchemaRegistry.sol";
import {AgreementResolver} from "src/AgreementResolver.sol";
import {AgreementAnchor} from "src/AgreementAnchor.sol";
import {ISchemaResolver} from "eas-contracts/resolver/ISchemaResolver.sol";

contract AgreementResolverTest is Test {
  EAS eas;
  SchemaRegistry schemaRegistry;
  AgreementResolver resolver;
  AgreementAnchor anchor;

  address partyA = makeAddr("partyA");
  address partyB = makeAddr("partyB");
  address other = makeAddr("other");

  bytes32 contentHash = keccak256("agreement content");
  bytes32 schemaUID;

  function setUp() public virtual {
    vm.label(partyA, "Party A");
    vm.label(partyB, "Party B");
    vm.label(other, "Other");

    schemaRegistry = new SchemaRegistry();
    eas = new EAS(ISchemaRegistry(address(schemaRegistry)));
    resolver = new AgreementResolver(IEAS(address(eas)), partyA);
    anchor = new AgreementAnchor(contentHash, partyA, partyB, address(resolver));

    // Register a schema that uses our resolver
    schemaUID =
      schemaRegistry.register("bytes32 contentHash", ISchemaResolver(address(resolver)), true);
  }

  function _buildAttestationRequest(address _recipient, bytes32 _data)
    internal
    view
    returns (AttestationRequest memory)
  {
    return AttestationRequest({
      schema: schemaUID,
      data: AttestationRequestData({
        recipient: _recipient,
        expirationTime: 0,
        revocable: true,
        refUID: bytes32(0),
        data: abi.encode(_data),
        value: 0
      })
    });
  }
}

contract OnAttest is AgreementResolverTest {
  function testFuzz_SuccessfullyAttestsForPartyA(bytes32 _contentHash) public {
    anchor = new AgreementAnchor(_contentHash, partyA, partyB, address(resolver));
    AttestationRequest memory request = _buildAttestationRequest(address(anchor), _contentHash);

    vm.prank(partyA);
    bytes32 uid = eas.attest(request);

    assertEq(anchor.partyA_attestationUID(), uid);
  }

  function testFuzz_SuccessfullyAttestsForPartyB(bytes32 _contentHash) public {
    anchor = new AgreementAnchor(_contentHash, partyA, partyB, address(resolver));
    AttestationRequest memory request = _buildAttestationRequest(address(anchor), _contentHash);

    vm.prank(partyB);
    bytes32 uid = eas.attest(request);

    assertEq(anchor.partyB_attestationUID(), uid);
  }

  function testFuzz_RevertIf_AttesterIsNotAParty(address _attester, bytes32 _contentHash) public {
    vm.assume(_attester != partyA && _attester != partyB);
    anchor = new AgreementAnchor(_contentHash, partyA, partyB, address(resolver));
    AttestationRequest memory request = _buildAttestationRequest(address(anchor), _contentHash);

    vm.prank(_attester);
    vm.expectRevert("Not a party to this agreement");
    eas.attest(request);
  }

  function testFuzz_RevertIf_ContentHashMismatches(
    bytes32 _contentHash,
    bytes32 _wrongContentHash,
    bool _isPartyA
  ) public {
    vm.assume(_contentHash != _wrongContentHash);

    anchor = new AgreementAnchor(_contentHash, partyA, partyB, address(resolver));
    AttestationRequest memory request = _buildAttestationRequest(address(anchor), _wrongContentHash);

    vm.prank(_isPartyA ? partyA : partyB);
    vm.expectRevert("Attestation data does not match the anchor");
    eas.attest(request);
  }

  function testFuzz_RevertIf_RecipientIsNotAnAnchor(
    address _recipient,
    bytes32 _contentHash,
    bool _isPartyA
  ) public {
    vm.assume(_recipient != address(anchor));
    anchor = new AgreementAnchor(_contentHash, partyA, partyB, address(resolver));
    AttestationRequest memory request = _buildAttestationRequest(_recipient, _contentHash);

    vm.prank(_isPartyA ? partyA : partyB);
    vm.expectRevert();
    eas.attest(request);
  }
}

contract OnRevoke is AgreementResolverTest {
  bytes32 partyA_uid;

  function setUp() public override {
    super.setUp();
    AttestationRequest memory request = _buildAttestationRequest(address(anchor), contentHash);
    vm.prank(partyA);
    partyA_uid = eas.attest(request);
  }

  function _buildRevocationRequest(bytes32 _uid) internal view returns (RevocationRequest memory) {
    return
      RevocationRequest({schema: schemaUID, data: RevocationRequestData({uid: _uid, value: 0})});
  }

  function test_SuccessfullyRevokesAnchorWhenLatestUIDIsRevoked() public {
    RevocationRequest memory request = _buildRevocationRequest(partyA_uid);

    vm.prank(partyA);
    eas.revoke(request);

    assertTrue(anchor.isRevoked());
  }

  function test_DoesNotRevokeAnchorIfRevokedUIDIsNotTheLatest() public {
    // partyA makes a second, later attestation. This UID will be stored in the anchor.
    AttestationRequest memory secondRequest = _buildAttestationRequest(address(anchor), contentHash);
    vm.prank(partyA);
    bytes32 partyA_second_uid = eas.attest(secondRequest);

    // Now, revoke the first attestation.
    // The resolver should allow this, but not mark the anchor as revoked.
    RevocationRequest memory firstRevocationRequest = _buildRevocationRequest(partyA_uid);
    vm.prank(partyA);
    eas.revoke(firstRevocationRequest);

    // The anchor should NOT be revoked because partyA_uid is not the latest attestation.
    assertFalse(anchor.isRevoked(), "Anchor should not be revoked for an old UID");

    // Now, revoke the latest one.
    RevocationRequest memory secondRevocationRequest = _buildRevocationRequest(partyA_second_uid);
    vm.prank(partyA);
    eas.revoke(secondRevocationRequest);

    // The anchor SHOULD now be revoked.
    assertTrue(anchor.isRevoked(), "Anchor should be revoked for the latest UID");
  }

  function test_RevertIf_RevokerIsNotAParty() public {
    RevocationRequest memory request = _buildRevocationRequest(partyA_uid);

    vm.prank(other);
    vm.expectRevert();
    eas.revoke(request);
  }
}
