// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Crowdfunding} from "../src/Crowdfunding.sol";

contract DeployCrowdfunding is Script {
    function deployCrowdfunding()
        public
        returns (Crowdfunding, HelperConfig)
    {
        HelperConfig helperConfig = new HelperConfig();
        address platformFeeRecipient = helperConfig
            .getConfigByChainId(block.chainid)
            .platformFeeRecipient;

        vm.startBroadcast();
        Crowdfunding crowdfunding = new Crowdfunding(platformFeeRecipient);
        vm.stopBroadcast();

        return (crowdfunding, helperConfig);
    }

    function run() external returns (Crowdfunding, HelperConfig) {
        return deployCrowdfunding();
    }
}
