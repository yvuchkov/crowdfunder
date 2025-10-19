// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Crowdfunding
 * @dev A decentralized crowdfunding platform smart contract
 * @notice This contract allows users to create campaigns, contribute to them, and withdraw funds
 */
contract Crowdfunding is ReentrancyGuard {
    error Crowdfunding__GoalMustBeLargerThanZero();
    error Crowdfunding__DeadlineMustBeInTheFuture();
    error Crowdfunding__CampaignDoesNotExist();
    error Crowdfunding__CampaignDeadlineHasPassed();
    error Crowdfunding__ContributionMustBeGreaterThanZero();

    enum CampaignState {
        ACTIVE,
        SUCCESSFUL,
        FAILED,
        WITHDRAWN
    }

    struct Campaign {
        uint256 id;
        address creator;
        string title;
        string description;
        uint256 goal;
        uint256 deadline;
        uint256 amountRaised;
        bool withdrawn;
        bool refunded;
    }

    uint256 private s_campaignCounter;
    mapping(uint256 => Campaign) public s_campaigns;
    // from campaignId -> contributor address, and then -> contribution amount
    mapping(uint256 => mapping(address => uint256)) public s_contributions;

    /**
     * @dev Modifier to check if a campaign exists
     * @param campaignId The ID of the campaign to check
     */
    modifier campaignExists(uint256 campaignId) {
        if (campaignId >= s_campaignCounter) {
            revert Crowdfunding__CampaignDoesNotExist();
        }
        _;
    }

    /**
     * @dev Modifier to check if the current time is before the campaign deadline
     * @param campaignId The ID of the campaign to check
     */
    modifier beforeDeadline(uint256 campaignId) {
        if (block.timestamp >= s_campaigns[campaignId].deadline) {
            revert Crowdfunding__CampaignDeadlineHasPassed();
        }
        _;
    }

    /**
     * @dev Modifier to check if the current time is after or at the campaign deadline
     * @param campaignId The ID of the campaign to check
     */
    modifier afterDeadline(uint256 campaignId) {
        if (block.timestamp < s_campaigns[campaignId].deadline) {
            revert Crowdfunding__CampaignDeadlineHasPassed();
        }
        _;
    }

    // Events
    /**
     * @dev Emitted when a new campaign is created
     * @param campaignId The ID of the newly created campaign
     * @param creator The address of the campaign creator
     * @param title The title of the campaign
     * @param goal The funding goal in wei
     * @param deadline The campaign deadline timestamp
     */
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        uint256 goal,
        uint256 deadline
    );

    /**
     * @dev Emitted when a contribution is made to a campaign
     * @param campaignId The ID of the campaign
     * @param contributor The address of the contributor
     * @param amount The amount contributed in wei
     * @param totalRaised The total amount raised for the campaign after this contribution
     */
    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount,
        uint256 totalRaised
    );

    /**
     * @dev Contract constructor
     * @notice Initializes the crowdfunding contract
     */
    constructor() {
        s_campaignCounter = 0;
    }

    /**
     * @dev Creates a new crowdfunding campaign
     * @param title The title of the campaign
     * @param description A detailed description of the campaign
     * @param goal The funding goal in wei (must be greater than 0)
     * @param deadline The campaign deadline as a Unix timestamp (must be in the future)
     * @return campaignId The ID of the newly created campaign
     */
    function createCampaign(
        string memory title,
        string memory description,
        uint256 goal,
        uint256 deadline
    ) external returns (uint256) {
        if (goal <= 0) {
            revert Crowdfunding__GoalMustBeLargerThanZero();
        }
        if (deadline <= block.timestamp) {
            revert Crowdfunding__DeadlineMustBeInTheFuture();
        }

        uint256 campaignId = s_campaignCounter;

        s_campaigns[campaignId] = Campaign({
            id: campaignId,
            creator: msg.sender,
            title: title,
            description: description,
            goal: goal,
            deadline: deadline,
            amountRaised: 0,
            withdrawn: false,
            refunded: false
        });

        s_campaignCounter++;

        emit CampaignCreated(campaignId, msg.sender, title, goal, deadline);

        return campaignId;
    }

    /**
     * @dev Contribute ETH to a specific campaign
     * @param campaignId The ID of the campaign to contribute to
     * @notice The contribution amount is sent as msg.value
     */
    function contribute(
        uint256 campaignId
    ) external payable campaignExists(campaignId) beforeDeadline(campaignId) {
        if (msg.value == 0) {
            revert Crowdfunding__ContributionMustBeGreaterThanZero();
        }

        Campaign storage campaign = s_campaigns[campaignId];

        s_contributions[campaignId][msg.sender] += msg.value;

        campaign.amountRaised += msg.value;

        emit ContributionMade(
            campaignId,
            msg.sender,
            msg.value,
            campaign.amountRaised
        );
    }

    /**
     * @dev Returns the current state of a campaign
     * @param campaignId The ID of the campaign
     * @return The current CampaignState
     */
    function getCampaignState(
        uint256 campaignId
    ) public view campaignExists(campaignId) returns (CampaignState) {
        Campaign storage campaign = s_campaigns[campaignId];

        if (campaign.withdrawn) {
            return CampaignState.WITHDRAWN;
        }

        if (block.timestamp >= campaign.deadline) {
            if (campaign.amountRaised >= campaign.goal) {
                return CampaignState.SUCCESSFUL;
            } else {
                return CampaignState.FAILED;
            }
        }

        return CampaignState.ACTIVE;
    }
}
