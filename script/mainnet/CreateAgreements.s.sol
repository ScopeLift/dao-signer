// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {CreateAgreements} from "script/script-base/CreateAgreements.sol";

contract MainnetCreateAgreements is CreateAgreements {
  address FACTORY_ADDRESS = address(0x5Ef3cCf9eC7E0af61E1767b2EEbB50e052b5Df47);

  uint256 public constant N_AGREEMENTS = 3;

  // Solo agreement
  address public constant PARTY_B_0 = address(0);
  bytes32 public constant CONTENT_HASH_0 =
    0xe8c79f54b28f0f008fc23ae671265b2c915d0c4328733162967f85578ea36748;

  // Cowrie agreement
  address public constant PARTY_B_1 = 0x96855185279B526D7ad7e4A21B3f8d4f8Ca859da;
  bytes32 public constant CONTENT_HASH_1 =
    0x1e9a075250e3bb62dec90c499ff00a8def24f4e9be7984daf11936d57dca2f76;

  // UF agreement
  address public constant PARTY_B_2 = 0xe571dC7A558bb6D68FfE264c3d7BB98B0C6C73fC;
  bytes32 public constant CONTENT_HASH_2 =
    0xa2fd33dd87091d25c15d94c0097395c08f2689efe6a2f8c53a1194222e442dd5;

  Agreement[] public agreements;

  function config() internal virtual override returns (Config memory) {
    require(FACTORY_ADDRESS != address(0), "FACTORY_ADDRESS not set");

    agreements.push(Agreement({partyB: PARTY_B_0, contentHash: CONTENT_HASH_0}));
    agreements.push(Agreement({partyB: PARTY_B_1, contentHash: CONTENT_HASH_1}));
    agreements.push(Agreement({partyB: PARTY_B_2, contentHash: CONTENT_HASH_2}));

    require(agreements.length == N_AGREEMENTS, "agreements.length != N_AGREEMENTS");

    return Config({agreementAnchorFactory: FACTORY_ADDRESS, agreements: agreements});
  }

  function run() public override returns (address[] memory agreementAnchors) {
    agreementAnchors = super.run();
  }
}
