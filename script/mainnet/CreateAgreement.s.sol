// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {CreateAgreements} from "script/script-base/CreateAgreements.sol";

contract MainnetCreateAgreement is CreateAgreements {
  address FACTORY_ADDRESS = address(0x5Ef3cCf9eC7E0af61E1767b2EEbB50e052b5Df47);

  uint256 public constant N_AGREEMENTS = 1;

  // UF agreement
  address public constant PARTY_B_0 = 0xe571dC7A558bb6D68FfE264c3d7BB98B0C6C73fC;
  bytes32 public constant CONTENT_HASH_0 =
    0x6dd5ee280fe12c69425c9d4b137d8f64578f5e67b76904e994687644f7511516;

  Agreement[] public agreements;

  function config() internal virtual override returns (Config memory) {
    require(FACTORY_ADDRESS != address(0), "FACTORY_ADDRESS not set");

    agreements.push(Agreement({partyB: PARTY_B_0, contentHash: CONTENT_HASH_0}));

    require(agreements.length == N_AGREEMENTS, "agreements.length != N_AGREEMENTS");

    return Config({agreementAnchorFactory: FACTORY_ADDRESS, agreements: agreements});
  }

  function run() public override returns (address[] memory agreementAnchors) {
    agreementAnchors = super.run();
  }
}
