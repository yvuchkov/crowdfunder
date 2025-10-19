// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Crowdfunding} from "../src/Crowdfunding.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateCampaign is Script {
    uint256 constant SEND_VALUE = 0.01 ether;

    function createCampaign(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        Crowdfunding(mostRecentlyDeployed).createCampaign(
            "Test Campaign",
            "This is a test campaign created via script",
            1 ether,
            block.timestamp + 30 days
        );
        vm.stopBroadcast();
        console.log("Campaign created on contract:", mostRecentlyDeployed);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Crowdfunding",
            block.chainid
        );
        createCampaign(mostRecentlyDeployed);
    }
}

contract ContributeToCampaign is Script {
    function contribute(
        address mostRecentlyDeployed,
        uint256 campaignId
    ) public {
        vm.startBroadcast();
        Crowdfunding(mostRecentlyDeployed).contribute{value: 0.1 ether}(
            campaignId
        );
        vm.stopBroadcast();
        console.log("Contributed to campaign:", campaignId);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Crowdfunding",
            block.chainid
        );
        contribute(mostRecentlyDeployed, 0);
    }
}

contract WithdrawFunds is Script {
    function withdraw(address mostRecentlyDeployed, uint256 campaignId) public {
        vm.startBroadcast();
        Crowdfunding(mostRecentlyDeployed).withdrawFunds(campaignId);
        vm.stopBroadcast();
        console.log("Withdrew funds from campaign:", campaignId);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Crowdfunding",
            block.chainid
        );
        withdraw(mostRecentlyDeployed, 0);
    }
}

contract GetCampaignDetails is Script {
    function getCampaignDetails(
        address mostRecentlyDeployed,
        uint256 campaignId
    ) public view {
        (
            uint256 id,
            address creator,
            string memory title,
            string memory description,
            uint256 goal,
            uint256 deadline,
            uint256 amountRaised,
            bool withdrawn,
            bool refunded,
            bool cancelled
        ) = Crowdfunding(mostRecentlyDeployed).getCampaignDetails(campaignId);

        console.log("=== Campaign Details ===");
        console.log("ID:", id);
        console.log("Creator:", creator);
        console.log("Title:", title);
        console.log("Description:", description);
        console.log("Goal (wei):", goal);
        console.log("Deadline:", deadline);
        console.log("Amount Raised (wei):", amountRaised);
        console.log("Withdrawn:", withdrawn);
        console.log("Refunded:", refunded);
        console.log("Cancelled:", cancelled);
    }

    function run() external view {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Crowdfunding",
            block.chainid
        );
        getCampaignDetails(mostRecentlyDeployed, 0);
    }
}
