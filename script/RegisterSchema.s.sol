// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {IEAS, AttestationRequest, AttestationRequestData} from "eas-contracts/IEAS.sol";
import {ISchemaRegistry} from "eas-contracts/ISchemaRegistry.sol";
import {AgreementResolver} from "src/AgreementResolver.sol";

abstract contract DeployAndRegisterSchema is Script {
  struct Config {
    string schemaName;
    address primarySigner;
    address eas;
    address schemaRegistry;
    bytes32 namingUID;
  }

  function config() internal virtual returns (Config memory);

  function run() public {
    vm.startBroadcast();

    IEAS eas = IEAS(config().eas);
    ISchemaRegistry schemaRegistry = ISchemaRegistry(config().schemaRegistry);

    // Deploy resolver (and factory)
    AgreementResolver resolver = new AgreementResolver(eas, config().primarySigner);

    // Deploy the schema
    string memory schema = "bytes32 hashOfDocument,string note";
    bytes32 schemaHash = schemaRegistry.register(schema, resolver, true);

    AttestationRequest memory nameAttestation = AttestationRequest({
      schema: config().namingUID,
      data: AttestationRequestData({
        recipient: address(0),
        expirationTime: 0,
        revocable: true,
        refUID: bytes32(0),
        data: abi.encode(schemaHash, config().schemaName),
        value: 0
      })
    });

    // Name the schema
    eas.attest(nameAttestation);

    vm.stopBroadcast();
  }
}
