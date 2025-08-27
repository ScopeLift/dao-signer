// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {AgreementAnchorFactory} from "src/AgreementAnchorFactory.sol";

abstract contract CreateAgreements is Script {
  struct Agreement {
    address partyB;
    bytes32 contentHash;
  }

  struct Config {
    address agreementAnchorFactory;
    Agreement[] agreements;
  }

  function config() internal virtual returns (Config memory);

  function run() public virtual returns (address[] memory agreementAnchors) {
    Config memory cfg = config();
    vm.startBroadcast();

    AgreementAnchorFactory factory = AgreementAnchorFactory(cfg.agreementAnchorFactory);
    agreementAnchors = new address[](cfg.agreements.length);
    for (uint256 i = 0; i < cfg.agreements.length; i++) {
      agreementAnchors[i] = address(
        factory.createAgreementAnchor(cfg.agreements[i].contentHash, cfg.agreements[i].partyB)
      );
    }

    vm.stopBroadcast();
  }
}
