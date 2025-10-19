// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Crowdfunding} from "../src/Crowdfunding.sol";

contract CrowdfundingTest is Test {
    Crowdfunding public crowdfunding;

    address public creator = makeAddr("creator");
    address public contributor1 = makeAddr("contributor1");
    address public contributor2 = makeAddr("contributor2");

    uint256 constant INITIAL_BALANCE = 10 ether;
    uint256 constant CAMPAIGN_GOAL = 5 ether;
    uint256 constant CAMPAIGN_DURATION = 30 days;

    string constant CAMPAIGN_TITLE = "test campaign";
    string constant CAMPAIGN_DESCRIPTION =
        "this is a test campaign for my crowdfunding platform!";

    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        uint256 goal,
        uint256 deadline
    );

    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount,
        uint256 totalRaised
    );

    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount
    );

    function setUp() public {
        crowdfunding = new Crowdfunding();

        vm.deal(creator, INITIAL_BALANCE);
        vm.deal(contributor1, INITIAL_BALANCE);
        vm.deal(contributor2, INITIAL_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                        CAMPAIGN CREATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CreatingCampaign() public {
        vm.startPrank(creator);

        uint256 deadline = block.timestamp + CAMPAIGN_DURATION;

        vm.expectEmit(true, true, false, true);
        emit CampaignCreated(
            0,
            creator,
            CAMPAIGN_TITLE,
            CAMPAIGN_GOAL,
            deadline
        );

        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            deadline
        );

        vm.stopPrank();

        assertEq(campaignId, 0);

        (
            uint256 id,
            address campaignCreator,
            string memory title,
            string memory description,
            uint256 goal,
            uint256 campaignDeadline,
            uint256 amountRaised,
            bool withdrawn,
            bool refunded
        ) = crowdfunding.s_campaigns(campaignId);

        assertEq(id, 0);
        assertEq(campaignCreator, creator);
        assertEq(title, CAMPAIGN_TITLE);
        assertEq(description, CAMPAIGN_DESCRIPTION);
        assertEq(goal, CAMPAIGN_GOAL);
        assertEq(campaignDeadline, deadline);
        assertEq(amountRaised, 0);
        assertEq(withdrawn, false);
        assertEq(refunded, false);
    }

    function test_CreateMultipleCampaigns() public {
        uint256 deadline = block.timestamp + CAMPAIGN_DURATION;

        vm.startPrank(creator);
        uint256 campaignId1 = crowdfunding.createCampaign(
            "campaign 1",
            "test desc",
            1 ether,
            deadline
        );
        uint256 campaignId2 = crowdfunding.createCampaign(
            "campaign 2",
            "test desc",
            2 ether,
            deadline + 1 days
        );
        vm.stopPrank();

        assertEq(campaignId1, 0);
        assertEq(campaignId2, 1);
    }

    function test_RevertWhen_GoalIsZero() public {
        vm.startPrank(creator);

        vm.expectRevert(
            Crowdfunding.Crowdfunding__GoalMustBeLargerThanZero.selector
        );
        crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            0,
            block.timestamp + CAMPAIGN_DURATION
        );

        vm.stopPrank();
    }

    function test_RevertWhen_DeadlineIsInThePast() public {
        vm.warp(30 days);

        vm.startPrank(creator);
        vm.expectRevert(
            Crowdfunding.Crowdfunding__DeadlineMustBeInTheFuture.selector
        );
        crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp - 1 days
        );
        vm.stopPrank();
    }

    function test_RevertWhen_DeadlineIsNow() public {
        vm.startPrank(creator);
        vm.expectRevert(
            Crowdfunding.Crowdfunding__DeadlineMustBeInTheFuture.selector
        );
        crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp
        );
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        CONTRIBUTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Contribute() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        uint256 contributionAmount = 1 ether;
        vm.startPrank(contributor1);

        vm.expectEmit(true, true, false, true);
        emit ContributionMade(
            campaignId,
            contributor1,
            contributionAmount,
            contributionAmount
        );

        crowdfunding.contribute{value: contributionAmount}(campaignId);
        vm.stopPrank();

        assertEq(
            crowdfunding.s_contributions(campaignId, contributor1),
            contributionAmount
        );

        (, , , , , , uint256 amountRaised, , ) = crowdfunding.s_campaigns(
            campaignId
        );
        assertEq(amountRaised, contributionAmount);

        assertEq(address(crowdfunding).balance, contributionAmount);
    }

    function test_MultipleContributionsFromSameAddress() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        uint256 contribution1 = 1 ether;
        uint256 contribution2 = 0.5 ether;

        vm.startPrank(contributor1);
        crowdfunding.contribute{value: contribution1}(campaignId);
        crowdfunding.contribute{value: contribution2}(campaignId);
        vm.stopPrank();

        assertEq(
            crowdfunding.s_contributions(campaignId, contributor1),
            contribution1 + contribution2
        );

        (, , , , , , uint256 amountRaised, , ) = crowdfunding.s_campaigns(
            campaignId
        );
        assertEq(amountRaised, contribution1 + contribution2);
    }

    function test_MultipleContributorsToSameCampaign() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        uint256 contribution1 = 1 ether;
        uint256 contribution2 = 2 ether;

        vm.prank(contributor1);
        crowdfunding.contribute{value: contribution1}(campaignId);

        vm.prank(contributor2);
        crowdfunding.contribute{value: contribution2}(campaignId);

        assertEq(
            crowdfunding.s_contributions(campaignId, contributor1),
            contribution1
        );
        assertEq(
            crowdfunding.s_contributions(campaignId, contributor2),
            contribution2
        );

        (, , , , , , uint256 amountRaised, , ) = crowdfunding.s_campaigns(
            campaignId
        );
        assertEq(amountRaised, contribution1 + contribution2);
    }

    function test_RevertWhen_ContributionIsZero() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        vm.prank(contributor1);
        vm.expectRevert(
            Crowdfunding
                .Crowdfunding__ContributionMustBeGreaterThanZero
                .selector
        );
        crowdfunding.contribute{value: 0}(campaignId);
    }

    function test_RevertWhen_CampaignDoesNotExist() public {
        uint256 nonExistentCampaignId = 999;

        vm.prank(contributor1);
        vm.expectRevert(
            Crowdfunding.Crowdfunding__CampaignDoesNotExist.selector
        );
        crowdfunding.contribute{value: 1 ether}(nonExistentCampaignId);
    }

    function test_RevertWhen_DeadlineHasPassed() public {
        uint256 deadline = block.timestamp + CAMPAIGN_DURATION;

        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            deadline
        );

        vm.warp(deadline + 1);

        vm.prank(contributor1);
        vm.expectRevert(
            Crowdfunding.Crowdfunding__CampaignDeadlineHasPassed.selector
        );
        crowdfunding.contribute{value: 1 ether}(campaignId);
    }

    function test_ContributeExactlyAtDeadline() public {
        uint256 deadline = block.timestamp + CAMPAIGN_DURATION;

        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            deadline
        );

        vm.warp(deadline);

        vm.prank(contributor1);
        vm.expectRevert(
            Crowdfunding.Crowdfunding__CampaignDeadlineHasPassed.selector
        );
        crowdfunding.contribute{value: 1 ether}(campaignId);
    }

    function test_ContributeOneSecondBeforeDeadline() public {
        uint256 deadline = block.timestamp + CAMPAIGN_DURATION;

        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            deadline
        );

        vm.warp(deadline - 1);

        vm.prank(contributor1);
        crowdfunding.contribute{value: 1 ether}(campaignId);

        assertEq(
            crowdfunding.s_contributions(campaignId, contributor1),
            1 ether
        );
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_CreateCampaign(
        uint256 goal,
        uint256 durationFromNow
    ) public {
        goal = bound(goal, 1, type(uint128).max);
        durationFromNow = bound(durationFromNow, 1, 365 days);

        uint256 deadline = block.timestamp + durationFromNow;

        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            goal,
            deadline
        );

        (, , , , uint256 campaignGoal, , , , ) = crowdfunding.s_campaigns(
            campaignId
        );
        assertEq(campaignGoal, goal);
    }

    function testFuzz_Contribute(uint96 contributionAmount) public {
        vm.assume(contributionAmount > 0);

        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        vm.deal(contributor1, contributionAmount);

        vm.prank(contributor1);
        crowdfunding.contribute{value: contributionAmount}(campaignId);

        assertEq(
            crowdfunding.s_contributions(campaignId, contributor1),
            contributionAmount
        );
    }

    /*//////////////////////////////////////////////////////////////
                    CAMPAIGN STATE MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetCampaignState_Active() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        Crowdfunding.CampaignState state = crowdfunding.getCampaignState(
            campaignId
        );
        assertEq(uint256(state), uint256(Crowdfunding.CampaignState.ACTIVE));
    }

    function test_GetCampaignState_Successful() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        vm.prank(contributor1);
        crowdfunding.contribute{value: CAMPAIGN_GOAL}(campaignId);

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);

        Crowdfunding.CampaignState state = crowdfunding.getCampaignState(
            campaignId
        );
        assertEq(
            uint256(state),
            uint256(Crowdfunding.CampaignState.SUCCESSFUL)
        );
    }

    function test_GetCampaignState_Failed() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        vm.prank(contributor1);
        crowdfunding.contribute{value: 1 ether}(campaignId);

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);

        Crowdfunding.CampaignState state = crowdfunding.getCampaignState(
            campaignId
        );
        assertEq(uint256(state), uint256(Crowdfunding.CampaignState.FAILED));
    }

    function test_GetCampaignState_RevertWhen_CampaignDoesNotExist() public {
        vm.expectRevert(
            Crowdfunding.Crowdfunding__CampaignDoesNotExist.selector
        );
        crowdfunding.getCampaignState(999);
    }

    function test_CampaignState_ActiveToSuccessful() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        assertEq(
            uint256(crowdfunding.getCampaignState(campaignId)),
            uint256(Crowdfunding.CampaignState.ACTIVE)
        );

        vm.prank(contributor1);
        crowdfunding.contribute{value: CAMPAIGN_GOAL}(campaignId);

        assertEq(
            uint256(crowdfunding.getCampaignState(campaignId)),
            uint256(Crowdfunding.CampaignState.ACTIVE)
        );

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);
        assertEq(
            uint256(crowdfunding.getCampaignState(campaignId)),
            uint256(Crowdfunding.CampaignState.SUCCESSFUL)
        );
    }

    function test_CampaignState_ActiveToFailed() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        assertEq(
            uint256(crowdfunding.getCampaignState(campaignId)),
            uint256(Crowdfunding.CampaignState.ACTIVE)
        );

        vm.prank(contributor1);
        crowdfunding.contribute{value: 1 ether}(campaignId);

        assertEq(
            uint256(crowdfunding.getCampaignState(campaignId)),
            uint256(Crowdfunding.CampaignState.ACTIVE)
        );

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);
        assertEq(
            uint256(crowdfunding.getCampaignState(campaignId)),
            uint256(Crowdfunding.CampaignState.FAILED)
        );
    }

    function test_CampaignState_ExactGoalIsSuccessful() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        vm.prank(contributor1);
        crowdfunding.contribute{value: CAMPAIGN_GOAL}(campaignId);

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);
        assertEq(
            uint256(crowdfunding.getCampaignState(campaignId)),
            uint256(Crowdfunding.CampaignState.SUCCESSFUL)
        );
    }

    function test_CampaignState_OverfundedIsSuccessful() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        vm.prank(contributor1);
        crowdfunding.contribute{value: CAMPAIGN_GOAL + 2 ether}(campaignId);

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);
        assertEq(
            uint256(crowdfunding.getCampaignState(campaignId)),
            uint256(Crowdfunding.CampaignState.SUCCESSFUL)
        );
    }

    /*//////////////////////////////////////////////////////////////
                        WITHDRAWAL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_WithdrawFunds_Success() public {
        // Create campaign
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        // Contribute to meet goal
        vm.prank(contributor1);
        crowdfunding.contribute{value: CAMPAIGN_GOAL}(campaignId);

        // Fast forward past deadline
        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);

        // Record creator balance before withdrawal
        uint256 creatorBalanceBefore = creator.balance;

        // Withdraw funds
        vm.prank(creator);
        vm.expectEmit(true, true, false, true);
        emit FundsWithdrawn(campaignId, creator, CAMPAIGN_GOAL);
        crowdfunding.withdrawFunds(campaignId);

        // Verify creator received funds
        assertEq(creator.balance, creatorBalanceBefore + CAMPAIGN_GOAL);

        // Verify contract balance decreased
        assertEq(address(crowdfunding).balance, 0);

        // Verify campaign marked as withdrawn
        (, , , , , , , bool withdrawn, ) = crowdfunding.s_campaigns(campaignId);
        assertEq(withdrawn, true);

        // Verify state is WITHDRAWN
        assertEq(uint256(crowdfunding.getCampaignState(campaignId)), uint256(Crowdfunding.CampaignState.WITHDRAWN));
    }

    function test_WithdrawFunds_Overfunded() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        // Contribute more than goal
        uint256 totalContributed = CAMPAIGN_GOAL + 2 ether;
        vm.prank(contributor1);
        crowdfunding.contribute{value: totalContributed}(campaignId);

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);

        uint256 creatorBalanceBefore = creator.balance;

        vm.prank(creator);
        crowdfunding.withdrawFunds(campaignId);

        // Should receive all contributed funds, not just the goal
        assertEq(creator.balance, creatorBalanceBefore + totalContributed);
    }

    function test_RevertWhen_NonCreatorTriesToWithdraw() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        vm.prank(contributor1);
        crowdfunding.contribute{value: CAMPAIGN_GOAL}(campaignId);

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);

        // Try to withdraw as non-creator
        vm.prank(contributor1);
        vm.expectRevert(Crowdfunding.Crowdfunding__OnlyCreatorCanWithdraw.selector);
        crowdfunding.withdrawFunds(campaignId);
    }

    function test_RevertWhen_WithdrawBeforeDeadline() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        vm.prank(contributor1);
        crowdfunding.contribute{value: CAMPAIGN_GOAL}(campaignId);

        // Try to withdraw before deadline
        vm.prank(creator);
        vm.expectRevert(Crowdfunding.Crowdfunding__CampaignDeadlineHasPassed.selector);
        crowdfunding.withdrawFunds(campaignId);
    }

    function test_RevertWhen_GoalNotReached() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        // Contribute less than goal
        vm.prank(contributor1);
        crowdfunding.contribute{value: 1 ether}(campaignId);

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);

        // Try to withdraw when goal not reached
        vm.prank(creator);
        vm.expectRevert(Crowdfunding.Crowdfunding__GoalNotReached.selector);
        crowdfunding.withdrawFunds(campaignId);
    }

    function test_RevertWhen_FundsAlreadyWithdrawn() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        vm.prank(contributor1);
        crowdfunding.contribute{value: CAMPAIGN_GOAL}(campaignId);

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);

        // Withdraw funds first time
        vm.prank(creator);
        crowdfunding.withdrawFunds(campaignId);

        // Try to withdraw again
        vm.prank(creator);
        vm.expectRevert(Crowdfunding.Crowdfunding__FundsAlreadyWithdrawn.selector);
        crowdfunding.withdrawFunds(campaignId);
    }

    function test_RevertWhen_WithdrawFromNonexistentCampaign() public {
        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);

        vm.prank(creator);
        vm.expectRevert(Crowdfunding.Crowdfunding__CampaignDoesNotExist.selector);
        crowdfunding.withdrawFunds(999);
    }

    function test_WithdrawFunds_ExactlyAtGoal() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        // Contribute exactly the goal amount
        vm.prank(contributor1);
        crowdfunding.contribute{value: CAMPAIGN_GOAL}(campaignId);

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);

        uint256 creatorBalanceBefore = creator.balance;

        vm.prank(creator);
        crowdfunding.withdrawFunds(campaignId);

        assertEq(creator.balance, creatorBalanceBefore + CAMPAIGN_GOAL);
    }
}
