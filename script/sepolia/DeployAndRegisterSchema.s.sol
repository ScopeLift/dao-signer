// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DeployAndRegisterSchema} from "script/script-base/DeployAndRegisterSchema.sol";

contract SepoliaConfig is DeployAndRegisterSchema {
  // DAO-related config
  string public constant SCHEMA_NAME = "Agreement with Ed";
  address public constant PRIMARY_SIGNER = 0xaecd4410c9b69E34F4365bc2FBd489675F739d83;

  // EAS-related config
  address public constant EAS_ADDRESS = 0xC2679fBD37d54388Ce493F1DB75320D236e1815e;
  address public constant SCHEMA_REGISTRY = 0x0a7E2Ff54e76B8E6659aedc9103FB21c038050D0;
  bytes32 public constant NAMING_UID =
    0x44d562ac1d7cd77e232978687fea027ace48f719cf1d58c7888e509663bb87fc;

  function config() internal pure override returns (Config memory) {
    return Config({
      eas: EAS_ADDRESS,
      schemaRegistry: SCHEMA_REGISTRY,
      schemaName: SCHEMA_NAME,
      namingUID: NAMING_UID,
      primarySigner: PRIMARY_SIGNER
    });
  }

  function run() public override {
    super.run();
  }
}
