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
    error Crowdfunding__OnlyCreatorCanWithdraw();
    error Crowdfunding__GoalNotReached();
    error Crowdfunding__FundsAlreadyWithdrawn();
    error Crowdfunding__WithdrawalFailed();
    error Crowdfunding__NoContributionToRefund();
    error Crowdfunding__CampaignWasSuccessful();
    error Crowdfunding__RefundFailed();
    error Crowdfunding__OnlyCreatorCanCancel();
    error Crowdfunding__CampaignAlreadyEnded();
    error Crowdfunding__CampaignIsCancelled();

    enum CampaignState {
        ACTIVE,
        SUCCESSFUL,
        FAILED,
        WITHDRAWN,
        CANCELLED
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
        bool cancelled;
    }

    uint256 private s_campaignCounter;
    mapping(uint256 => Campaign) public s_campaigns;
    // Nested mapping: campaignId => contributor address => contribution amount
    mapping(uint256 => mapping(address => uint256)) public s_contributions;

    uint256 private constant PLATFORM_FEE_BPS = 200;
    uint256 private constant BPS_DENOMINATOR = 10000;
    address private immutable i_platformFeeRecipient;
    uint256 private s_collectedFees;

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
     * @dev Emitted when funds are withdrawn from a successful campaign
     * @param campaignId The ID of the campaign
     * @param creator The address of the campaign creator
     * @param amount The amount withdrawn in wei
     */
    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount
    );

    /**
     * @dev Emitted when a contributor claims a refund from a failed campaign
     * @param campaignId The ID of the campaign
     * @param contributor The address of the contributor
     * @param amount The amount refunded in wei
     */
    event RefundClaimed(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    /**
     * @dev Emitted when a campaign is cancelled by its creator
     * @param campaignId The ID of the campaign
     * @param creator The address of the campaign creator
     */
    event CampaignCancelled(
        uint256 indexed campaignId,
        address indexed creator
    );

    /**
     * @dev Contract constructor
     * @notice Initializes the crowdfunding contract
     * @param platformFeeRecipient Address that will receive platform fees
     */
    constructor(address platformFeeRecipient) {
        i_platformFeeRecipient = platformFeeRecipient;
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
            refunded: false,
            cancelled: false
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

        if (campaign.cancelled) {
            revert Crowdfunding__CampaignIsCancelled();
        }

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

        if (campaign.cancelled) {
            return CampaignState.CANCELLED;
        }

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

    /**
     * @dev Allows campaign creator to withdraw funds from a successful campaign
     * @param campaignId The ID of the campaign to withdraw from
     * @notice Campaign must be successful (goal reached and deadline passed)
     * @notice Uses ReentrancyGuard and checks-effects-interactions pattern
     */
    function withdrawFunds(
        uint256 campaignId
    )
        external
        nonReentrant
        campaignExists(campaignId)
        afterDeadline(campaignId)
    {
        Campaign storage campaign = s_campaigns[campaignId];

        if (msg.sender != campaign.creator) {
            revert Crowdfunding__OnlyCreatorCanWithdraw();
        }

        if (campaign.amountRaised < campaign.goal) {
            revert Crowdfunding__GoalNotReached();
        }

        if (campaign.withdrawn) {
            revert Crowdfunding__FundsAlreadyWithdrawn();
        }

        campaign.withdrawn = true;

        uint256 totalAmount = campaign.amountRaised;

        uint256 platformFee = (totalAmount * PLATFORM_FEE_BPS) /
            BPS_DENOMINATOR;
        uint256 creatorAmount = totalAmount - platformFee;

        s_collectedFees += platformFee;

        (bool success, ) = payable(campaign.creator).call{value: creatorAmount}(
            ""
        );
        if (!success) {
            revert Crowdfunding__WithdrawalFailed();
        }

        emit FundsWithdrawn(campaignId, campaign.creator, creatorAmount);
    }

    /**
     * @dev Allows contributors to claim refunds from failed or cancelled campaigns
     * @param campaignId The ID of the campaign to claim refund from
     * @notice Campaign must have failed (deadline passed and goal not reached) OR been cancelled
     * @notice Uses ReentrancyGuard and checks-effects-interactions pattern
     */
    function claimRefund(
        uint256 campaignId
    ) external nonReentrant campaignExists(campaignId) {
        Campaign storage campaign = s_campaigns[campaignId];

        bool isCancelled = campaign.cancelled;
        bool isFailed = (block.timestamp >= campaign.deadline &&
            campaign.amountRaised < campaign.goal);

        if (!isCancelled && !isFailed) {
            revert Crowdfunding__CampaignWasSuccessful();
        }

        uint256 contributionAmount = s_contributions[campaignId][msg.sender];

        if (contributionAmount == 0) {
            revert Crowdfunding__NoContributionToRefund();
        }

        s_contributions[campaignId][msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: contributionAmount}(
            ""
        );
        if (!success) {
            revert Crowdfunding__RefundFailed();
        }

        emit RefundClaimed(campaignId, msg.sender, contributionAmount);
    }

    /**
     * @dev Allows campaign creator to cancel a campaign before the deadline
     * @param campaignId The ID of the campaign to cancel
     * @notice Only creator can cancel, and only before deadline
     * @notice Contributors can claim refunds after cancellation
     */
    function cancelCampaign(
        uint256 campaignId
    ) external campaignExists(campaignId) beforeDeadline(campaignId) {
        Campaign storage campaign = s_campaigns[campaignId];

        if (msg.sender != campaign.creator) {
            revert Crowdfunding__OnlyCreatorCanCancel();
        }

        campaign.cancelled = true;

        emit CampaignCancelled(campaignId, campaign.creator);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Returns complete details of a campaign
     * @param campaignId The ID of the campaign
     * @return id Campaign ID
     * @return creator Campaign creator address
     * @return title Campaign title
     * @return description Campaign description
     * @return goal Funding goal in wei
     * @return deadline Campaign deadline timestamp
     * @return amountRaised Total amount raised in wei
     * @return withdrawn Whether funds have been withdrawn
     * @return refunded Whether refunds have been processed (unused for now)
     * @return cancelled Whether the campaign has been cancelled
     */
    function getCampaignDetails(
        uint256 campaignId
    )
        external
        view
        campaignExists(campaignId)
        returns (
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
        )
    {
        Campaign storage campaign = s_campaigns[campaignId];
        return (
            campaign.id,
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.goal,
            campaign.deadline,
            campaign.amountRaised,
            campaign.withdrawn,
            campaign.refunded,
            campaign.cancelled
        );
    }

    /**
     * @dev Returns the contribution amount for a specific contributor to a campaign
     * @param campaignId The ID of the campaign
     * @param contributor The address of the contributor
     * @return The amount contributed in wei
     */
    function getContribution(
        uint256 campaignId,
        address contributor
    ) external view campaignExists(campaignId) returns (uint256) {
        return s_contributions[campaignId][contributor];
    }

    /**
     * @dev Returns an array of all campaign IDs
     * @return An array of all campaign IDs
     */
    function getAllCampaignIds() external view returns (uint256[] memory) {
        uint256[] memory campaignIds = new uint256[](s_campaignCounter);
        for (uint256 i = 0; i < s_campaignCounter; i++) {
            campaignIds[i] = i;
        }
        return campaignIds;
    }

    /**
     * @dev Checks if a campaign has reached its funding goal
     * @param campaignId The ID of the campaign
     * @return True if goal is reached, false otherwise
     */
    function isGoalReached(
        uint256 campaignId
    ) external view campaignExists(campaignId) returns (bool) {
        return
            s_campaigns[campaignId].amountRaised >=
            s_campaigns[campaignId].goal;
    }

    /**
     * @dev Returns the time remaining until the campaign deadline
     * @param campaignId The ID of the campaign
     * @return Time remaining in seconds (0 if deadline has passed)
     */
    function getTimeRemaining(
        uint256 campaignId
    ) external view campaignExists(campaignId) returns (uint256) {
        Campaign storage campaign = s_campaigns[campaignId];
        if (block.timestamp >= campaign.deadline) {
            return 0;
        }
        return campaign.deadline - block.timestamp;
    }

    /**
     * @dev Returns the total number of campaigns created
     * @return The total number of campaigns
     */
    function getTotalCampaigns() external view returns (uint256) {
        return s_campaignCounter;
    }
}
