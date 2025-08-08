// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DeployAndRegisterSchema} from "../RegisterSchema.s.sol";

contract MainnetConfig is DeployAndRegisterSchema {
  // DAO-related config
  string public constant SCHEMA_NAME = "Guinea Pig DAO Agreement";
  // TODO: Guinea Pig DAO address
  address public constant PRIMARY_SIGNER = 0x0000000000000000000000000000000000000000;

  // EAS-related config
  address public constant EAS_ADDRESS = 0xA1207F3BBa224E2c9c3c6D5aF63D0eb1582Ce587;
  address public constant SCHEMA_REGISTRY = 0xA7b39296258348C78294F95B872b282326A97BDF;
  bytes32 public constant NAMING_UID =
    0x44d562ac1d7cd77e232978687fea027ace48f719cf1d58c7888e509663bb87fc;

  function config() public pure override returns (Config memory) {
    return Config({
      eas: EAS_ADDRESS,
      schemaRegistry: SCHEMA_REGISTRY,
      schemaName: SCHEMA_NAME,
      namingUID: NAMING_UID,
      primarySigner: PRIMARY_SIGNER
    });
  }
}
