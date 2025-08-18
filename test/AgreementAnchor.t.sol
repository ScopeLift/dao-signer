// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {AgreementAnchor} from "src/AgreementAnchor.sol";

contract AgreementAnchorTest is Test {
  AgreementAnchor anchor;

  address partyA = makeAddr("partyA");
  address partyB = makeAddr("partyB");
  address resolver = makeAddr("resolver");
  address other = makeAddr("other");
  bytes32 contentHash = keccak256("agreement content");

  function setUp() public virtual {
    vm.label(partyA, "Party A");
    vm.label(partyB, "Party B");
    vm.label(resolver, "Resolver");
    vm.label(other, "Other");
  }

  function _deployAnchor(bytes32 _contentHash, address _partyA, address _partyB, address _resolver)
    internal
  {
    anchor = new AgreementAnchor(_contentHash, _partyA, _partyB, _resolver);
    vm.label(address(anchor), "AgreementAnchor");
  }
}

contract Constructor is AgreementAnchorTest {
  function testFuzz_SetsInitialState(
    bytes32 _contentHash,
    address _partyA,
    address _partyB,
    address _resolver
  ) public {
    _deployAnchor(_contentHash, _partyA, _partyB, _resolver);

    assertEq(anchor.CONTENT_HASH(), _contentHash);
    assertEq(anchor.PARTY_A(), _partyA);
    assertEq(anchor.PARTY_B(), _partyB);
    assertEq(anchor.RESOLVER(), _resolver);
    assertEq(anchor.partyA_attestationUID(), bytes32(0));
    assertEq(anchor.partyB_attestationUID(), bytes32(0));
    assertFalse(anchor.didEitherPartyRevoke());
  }
}

contract OnAttest is AgreementAnchorTest {
  function setUp() public override {
    super.setUp();
    _deployAnchor(contentHash, partyA, partyB, resolver);
  }

  function testFuzz_ResolverCanUpdatePartyAAttestationUID(bytes32 _uid) public {
    vm.prank(resolver);
    anchor.onAttest(partyA, _uid);
    assertEq(anchor.partyA_attestationUID(), _uid);
  }

  function testFuzz_ResolverCanUpdatePartyBAttestationUID(bytes32 _uid) public {
    vm.prank(resolver);
    anchor.onAttest(partyB, _uid);
    assertEq(anchor.partyB_attestationUID(), _uid);
  }

  function testFuzz_RevertIf_AttestationForNonParty(address _notParty, bytes32 _uid) public {
    vm.assume(_notParty != partyA && _notParty != partyB);
    vm.prank(resolver);
    vm.expectRevert(AgreementAnchor.AgreementAnchor__NotAParty.selector);
    anchor.onAttest(_notParty, _uid);
  }

  function testFuzz_RevertIf_SenderIsNotResolver(address _sender, address _party, bytes32 _uid)
    public
  {
    vm.assume(_sender != resolver);

    vm.prank(_sender);
    vm.expectRevert("Only the EAS resolver can update state");
    anchor.onAttest(_party, _uid);
  }

  function testFuzz_RevertIf_AgreementIsRevoked(address _party, bytes32 _uid) public {
    vm.prank(resolver);
    anchor.onRevoke(partyA, bytes32(0));

    vm.prank(resolver);
    vm.expectRevert(AgreementAnchor.AgreementAnchor__AgreementRevoked.selector);
    anchor.onAttest(_party, _uid);
  }

  function testFuzz_RevertIf_AlreadyFullyAttested(bytes32 _uid1, bytes32 _uid2, bytes32 _uid3)
    public
  {
    vm.assume(_uid1 != 0x0 && _uid2 != 0x0 && _uid3 != 0x0);
    vm.prank(resolver);
    anchor.onAttest(partyA, _uid1);

    vm.prank(resolver);
    anchor.onAttest(partyB, _uid2);

    vm.prank(resolver);
    vm.expectRevert(AgreementAnchor.AgreementAnchor__AgreementAlreadyAttested.selector);
    anchor.onAttest(partyA, _uid3);
  }
}

contract OnRevoke is AgreementAnchorTest {
  function setUp() public override {
    super.setUp();
    _deployAnchor(contentHash, partyA, partyB, resolver);
  }

  function testFuzz_SetsDidEitherPartyRevoke(bytes32 _uid) public {
    vm.prank(resolver);
    anchor.onRevoke(partyA, _uid);
    assertTrue(anchor.didEitherPartyRevoke());
  }

  function test_RevertIf_SenderIsNotResolver(address _sender, bytes32 _uid) public {
    vm.assume(_sender != resolver);

    vm.prank(_sender);
    vm.expectRevert("Only the EAS resolver can update state");
    anchor.onRevoke(partyA, _uid);
  }
}
