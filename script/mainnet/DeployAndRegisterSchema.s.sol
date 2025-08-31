// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {
  DeployAndRegisterSchema,
  AgreementResolver
} from "script/script-base/DeployAndRegisterSchema.sol";

contract MainnetConfig is DeployAndRegisterSchema {
  // DAO-related config
  string public constant SCHEMA_NAME = "DUNI Agreements";
  address public constant PRIMARY_SIGNER = 0x1a9C8182C09F50C8318d769245beA52c32BE35BC; // Uniswap
    // Timelock

  // EAS-related config
  address public constant EAS_ADDRESS = 0xA1207F3BBa224E2c9c3c6D5aF63D0eb1582Ce587;
  address public constant SCHEMA_REGISTRY = 0xA7b39296258348C78294F95B872b282326A97BDF;
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

  function run() public override returns (AgreementResolver resolver, bytes32 schemaHash) {
    (resolver, schemaHash) = super.run();
  }
}
