// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {AgreementAnchorFactory, IAgreementAnchorFactory} from "src/AgreementAnchorFactory.sol";
import {AgreementAnchor} from "src/AgreementAnchor.sol";

contract AgreementAnchorFactoryTest is Test {
  AgreementAnchorFactory factory;

  address resolver = makeAddr("resolver");
  address signer = makeAddr("signer");

  function setUp() public virtual {
    vm.label(resolver, "Resolver");
    vm.label(signer, "Signer");
    factory = new AgreementAnchorFactory(resolver, signer);
    vm.label(address(factory), "AgreementAnchorFactory");
  }
}

contract Constructor is AgreementAnchorFactoryTest {
  function testFuzz_SetsInitialState(address _resolver, address _signer) public {
    AgreementAnchorFactory _factory = new AgreementAnchorFactory(_resolver, _signer);

    assertEq(_factory.resolver(), _resolver);
    assertEq(_factory.signer(), _signer);
  }
}

contract CreateAgreementAnchor is AgreementAnchorFactoryTest {
  function testFuzz_CreatesAndReturnsAgreementAnchorWithCorrectParameters(
    bytes32 _contentHash,
    address _counterSigner
  ) public {
    AgreementAnchor anchor = factory.createAgreementAnchor(_contentHash, _counterSigner);

    assertEq(anchor.contentHash(), _contentHash);
    assertEq(anchor.partyA(), signer);
    assertEq(anchor.partyB(), _counterSigner);
    assertEq(anchor.resolver(), resolver);
  }

  function testFuzz_EmitsAgreementCreatedEvent(bytes32 _contentHash, address _counterSigner) public {
    vm.assume(_counterSigner != address(0));

    address anchorAddress = computeCreateAddress(address(factory), 1);
    vm.expectEmit();
    emit IAgreementAnchorFactory.AgreementCreated(
      anchorAddress, _contentHash, signer, _counterSigner
    );
    factory.createAgreementAnchor(_contentHash, _counterSigner);
  }
}
