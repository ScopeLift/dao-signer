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

    // Anchors for happy-path tests must be created via the factory.
    // The factory's signer is partyA, and the counterSigner is partyB.
    anchor = resolver.ANCHOR_FACTORY().createAgreementAnchor(contentHash, partyB);

    // Register a schema that uses our resolver
    schemaUID =
      schemaRegistry.register("bytes32 contentHash", ISchemaResolver(address(resolver)), false);
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
        revocable: false,
        refUID: bytes32(0),
        data: abi.encode(_data),
        value: 0
      })
    });
  }
}

contract Constructor is AgreementResolverTest {
  function testFuzz_DeploysAnchorFactoryWithCorrectSigner(address _signer) public {
    AgreementResolver resolver2 = new AgreementResolver(IEAS(address(eas)), _signer);
    assertEq(resolver2.ANCHOR_FACTORY().SIGNER(), _signer);
  }

  function testFuzz_StoresCorrectSchemaUID() public {
    assertEq(schemaRegistry.getSchema(schemaUID).uid, resolver.AGREEMENT_SCHEMA_UID());
    assertEq(schemaRegistry.getSchema(schemaUID).schema, resolver.AGREEMENT_SCHEMA());
  }
}

contract OnAttest is AgreementResolverTest {
  function testFuzz_SuccessfullyAttestsForPartyA(bytes32 _contentHash) public {
    anchor = resolver.ANCHOR_FACTORY().createAgreementAnchor(_contentHash, partyB);
    AttestationRequest memory request = _buildAttestationRequest(address(anchor), _contentHash);

    vm.prank(partyA);
    bytes32 uid = eas.attest(request);

    assertEq(anchor.partyA_attestationUID(), uid);
  }

  function testFuzz_SuccessfullyAttestsForPartyB(bytes32 _contentHash) public {
    anchor = resolver.ANCHOR_FACTORY().createAgreementAnchor(_contentHash, partyB);
    AttestationRequest memory request = _buildAttestationRequest(address(anchor), _contentHash);

    vm.prank(partyB);
    bytes32 uid = eas.attest(request);

    assertEq(anchor.partyB_attestationUID(), uid);
  }

  function testFuzz_RevertIf_AttesterIsNotAParty(address _attester, bytes32 _contentHash) public {
    vm.assume(_attester != partyA && _attester != partyB);
    anchor = resolver.ANCHOR_FACTORY().createAgreementAnchor(_contentHash, partyB);
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

    anchor = resolver.ANCHOR_FACTORY().createAgreementAnchor(_contentHash, partyB);
    AttestationRequest memory request = _buildAttestationRequest(address(anchor), _wrongContentHash);

    vm.prank(_isPartyA ? partyA : partyB);
    vm.expectRevert("Attestation data does not match the anchor");
    eas.attest(request);
  }

  function test_RevertIf_IncorrectSchemaUID() public {
    bytes32 incorrectSchemaUID = schemaRegistry.register(
      "bytes32 contentHash,string note", ISchemaResolver(address(resolver)), false
    );
    AttestationRequest memory request = _buildAttestationRequest(address(anchor), contentHash);
    request.schema = incorrectSchemaUID; // Use an incorrect schema UID

    vm.prank(partyA);
    vm.expectRevert("Incorrect schema UID");
    eas.attest(request);
  }

  function testFuzz_RevertIf_AttestationHasExpiration(uint64 _expirationTime) public {
    _expirationTime = uint64(bound(_expirationTime, vm.getBlockTimestamp() + 1, type(uint64).max));
    AttestationRequest memory request = _buildAttestationRequest(address(anchor), contentHash);
    request.data.expirationTime = _expirationTime; // Set a non-zero expiration time

    vm.prank(partyA);
    vm.expectRevert("Attestation must not have an expiration");
    eas.attest(request);
  }

  function test_RevertIf_AnchorNotDeployedByFactory() public {
    // Manually create an anchor, not using the factory
    AgreementAnchor nonFactoryAnchor =
      new AgreementAnchor(contentHash, partyA, partyB, address(resolver));
    vm.label(address(nonFactoryAnchor), "Non-Factory Anchor");

    AttestationRequest memory request =
      _buildAttestationRequest(address(nonFactoryAnchor), contentHash);

    vm.prank(partyA);
    vm.expectRevert("Not a factory-deployed anchor");
    eas.attest(request);
  }

  function testFuzz_RevertIf_RecipientIsNotAnAnchor(
    address _recipient,
    bytes32 _contentHash,
    bool _isPartyA
  ) public {
    vm.assume(_recipient != address(anchor));
    anchor = new AgreementAnchor(_contentHash, partyA, partyB, address(resolver.ANCHOR_FACTORY()));
    AttestationRequest memory request = _buildAttestationRequest(_recipient, _contentHash);

    vm.prank(_isPartyA ? partyA : partyB);
    // vm.expectRevert();
    vm.expectRevert("Not a factory-deployed anchor");
    eas.attest(request);
  }
}
