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

    event RefundClaimed(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    event CampaignCancelled(
        uint256 indexed campaignId,
        address indexed creator
    );

    function setUp() public {
        address platformFeeRecipient = makeAddr("platformFeeRecipient");
        crowdfunding = new Crowdfunding(platformFeeRecipient);

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
            bool refunded,
            bool cancelled
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
        assertEq(cancelled, false);
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

        (, , , , , , uint256 amountRaised, , , ) = crowdfunding.s_campaigns(
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

        (, , , , , , uint256 amountRaised, , , ) = crowdfunding.s_campaigns(
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

        (, , , , , , uint256 amountRaised, , , ) = crowdfunding.s_campaigns(
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

        (, , , , uint256 campaignGoal, , , , , ) = crowdfunding.s_campaigns(
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

        uint256 creatorBalanceBefore = creator.balance;

        uint256 platformFee = (CAMPAIGN_GOAL * 200) / 10000;
        uint256 creatorAmount = CAMPAIGN_GOAL - platformFee;

        vm.prank(creator);
        vm.expectEmit(true, true, false, true);
        emit FundsWithdrawn(campaignId, creator, creatorAmount);
        crowdfunding.withdrawFunds(campaignId);

        assertEq(creator.balance, creatorBalanceBefore + creatorAmount);

        assertEq(address(crowdfunding).balance, platformFee);

        (, , , , , , , bool withdrawn, , ) = crowdfunding.s_campaigns(
            campaignId
        );
        assertEq(withdrawn, true);

        assertEq(
            uint256(crowdfunding.getCampaignState(campaignId)),
            uint256(Crowdfunding.CampaignState.WITHDRAWN)
        );
    }

    function test_WithdrawFunds_Overfunded() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        uint256 totalContributed = CAMPAIGN_GOAL + 2 ether;
        vm.prank(contributor1);
        crowdfunding.contribute{value: totalContributed}(campaignId);

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);

        uint256 creatorBalanceBefore = creator.balance;

        uint256 platformFee = (totalContributed * 200) / 10000;
        uint256 creatorAmount = totalContributed - platformFee;

        vm.prank(creator);
        crowdfunding.withdrawFunds(campaignId);

        assertEq(creator.balance, creatorBalanceBefore + creatorAmount);
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

        vm.prank(contributor1);
        vm.expectRevert(
            Crowdfunding.Crowdfunding__OnlyCreatorCanWithdraw.selector
        );
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

        vm.prank(creator);
        vm.expectRevert(
            Crowdfunding.Crowdfunding__CampaignDeadlineHasPassed.selector
        );
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

        vm.prank(contributor1);
        crowdfunding.contribute{value: 1 ether}(campaignId);

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);

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

        vm.prank(creator);
        crowdfunding.withdrawFunds(campaignId);

        vm.prank(creator);
        vm.expectRevert(
            Crowdfunding.Crowdfunding__FundsAlreadyWithdrawn.selector
        );
        crowdfunding.withdrawFunds(campaignId);
    }

    function test_RevertWhen_WithdrawFromNonexistentCampaign() public {
        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);

        vm.prank(creator);
        vm.expectRevert(
            Crowdfunding.Crowdfunding__CampaignDoesNotExist.selector
        );
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

        vm.prank(contributor1);
        crowdfunding.contribute{value: CAMPAIGN_GOAL}(campaignId);

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);

        uint256 creatorBalanceBefore = creator.balance;

        uint256 platformFee = (CAMPAIGN_GOAL * 200) / 10000;
        uint256 creatorAmount = CAMPAIGN_GOAL - platformFee;

        vm.prank(creator);
        crowdfunding.withdrawFunds(campaignId);

        assertEq(creator.balance, creatorBalanceBefore + creatorAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            REFUND TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ClaimRefund_Success() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        uint256 contributionAmount = 1 ether;
        vm.prank(contributor1);
        crowdfunding.contribute{value: contributionAmount}(campaignId);

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);

        uint256 contributor1BalanceBefore = contributor1.balance;

        vm.prank(contributor1);
        vm.expectEmit(true, true, false, true);
        emit RefundClaimed(campaignId, contributor1, contributionAmount);
        crowdfunding.claimRefund(campaignId);

        assertEq(
            contributor1.balance,
            contributor1BalanceBefore + contributionAmount
        );

        assertEq(crowdfunding.s_contributions(campaignId, contributor1), 0);

        assertEq(address(crowdfunding).balance, 0);
    }

    function test_ClaimRefund_MultipleContributors() public {
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

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);

        uint256 contributor1BalanceBefore = contributor1.balance;
        uint256 contributor2BalanceBefore = contributor2.balance;

        vm.prank(contributor1);
        crowdfunding.claimRefund(campaignId);

        vm.prank(contributor2);
        crowdfunding.claimRefund(campaignId);

        assertEq(
            contributor1.balance,
            contributor1BalanceBefore + contribution1
        );
        assertEq(
            contributor2.balance,
            contributor2BalanceBefore + contribution2
        );

        assertEq(address(crowdfunding).balance, 0);
    }

    function test_RevertWhen_ClaimRefundBeforeDeadline() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        vm.prank(contributor1);
        crowdfunding.contribute{value: 1 ether}(campaignId);

        vm.prank(contributor1);
        vm.expectRevert(
            Crowdfunding.Crowdfunding__CampaignWasSuccessful.selector
        );
        crowdfunding.claimRefund(campaignId);
    }

    function test_RevertWhen_ClaimRefundFromSuccessfulCampaign() public {
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

        vm.prank(contributor1);
        vm.expectRevert(
            Crowdfunding.Crowdfunding__CampaignWasSuccessful.selector
        );
        crowdfunding.claimRefund(campaignId);
    }

    function test_RevertWhen_ClaimRefundWithNoContribution() public {
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

        vm.prank(contributor2);
        vm.expectRevert(
            Crowdfunding.Crowdfunding__NoContributionToRefund.selector
        );
        crowdfunding.claimRefund(campaignId);
    }

    function test_RevertWhen_ClaimRefundTwice() public {
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

        vm.prank(contributor1);
        crowdfunding.claimRefund(campaignId);

        vm.prank(contributor1);
        vm.expectRevert(
            Crowdfunding.Crowdfunding__NoContributionToRefund.selector
        );
        crowdfunding.claimRefund(campaignId);
    }

    function test_ClaimRefund_PartialContributions() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        vm.prank(contributor1);
        crowdfunding.contribute{value: 0.5 ether}(campaignId);

        vm.prank(contributor1);
        crowdfunding.contribute{value: 0.3 ether}(campaignId);

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);

        uint256 balanceBefore = contributor1.balance;

        vm.prank(contributor1);
        crowdfunding.claimRefund(campaignId);

        assertEq(contributor1.balance, balanceBefore + 0.8 ether);
    }

    function test_RevertWhen_ClaimRefundFromNonexistentCampaign() public {
        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);

        vm.prank(contributor1);
        vm.expectRevert(
            Crowdfunding.Crowdfunding__CampaignDoesNotExist.selector
        );
        crowdfunding.claimRefund(999);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetCampaignDetails() public {
        uint256 deadline = block.timestamp + CAMPAIGN_DURATION;

        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            deadline
        );

        (
            uint256 id,
            address campaignCreator,
            string memory title,
            string memory description,
            uint256 goal,
            uint256 campaignDeadline,
            uint256 amountRaised,
            bool withdrawn,
            bool refunded,
            bool cancelled
        ) = crowdfunding.getCampaignDetails(campaignId);

        assertEq(id, 0);
        assertEq(campaignCreator, creator);
        assertEq(title, CAMPAIGN_TITLE);
        assertEq(description, CAMPAIGN_DESCRIPTION);
        assertEq(goal, CAMPAIGN_GOAL);
        assertEq(campaignDeadline, deadline);
        assertEq(amountRaised, 0);
        assertEq(withdrawn, false);
        assertEq(refunded, false);
        assertEq(cancelled, false);
    }

    function test_GetContribution() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        uint256 contributionAmount = 2 ether;
        vm.prank(contributor1);
        crowdfunding.contribute{value: contributionAmount}(campaignId);

        uint256 contribution = crowdfunding.getContribution(
            campaignId,
            contributor1
        );
        assertEq(contribution, contributionAmount);

        uint256 noContribution = crowdfunding.getContribution(
            campaignId,
            contributor2
        );
        assertEq(noContribution, 0);
    }

    function test_GetAllCampaignIds() public {
        vm.startPrank(creator);
        crowdfunding.createCampaign(
            "Campaign 1",
            "Desc 1",
            1 ether,
            block.timestamp + CAMPAIGN_DURATION
        );
        crowdfunding.createCampaign(
            "Campaign 2",
            "Desc 2",
            2 ether,
            block.timestamp + CAMPAIGN_DURATION
        );
        crowdfunding.createCampaign(
            "Campaign 3",
            "Desc 3",
            3 ether,
            block.timestamp + CAMPAIGN_DURATION
        );
        vm.stopPrank();

        uint256[] memory campaignIds = crowdfunding.getAllCampaignIds();

        assertEq(campaignIds.length, 3);
        assertEq(campaignIds[0], 0);
        assertEq(campaignIds[1], 1);
        assertEq(campaignIds[2], 2);
    }

    function test_GetAllCampaignIds_Empty() public view {
        uint256[] memory campaignIds = crowdfunding.getAllCampaignIds();
        assertEq(campaignIds.length, 0);
    }

    function test_IsGoalReached_True() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        vm.prank(contributor1);
        crowdfunding.contribute{value: CAMPAIGN_GOAL}(campaignId);

        bool goalReached = crowdfunding.isGoalReached(campaignId);
        assertTrue(goalReached);
    }

    function test_IsGoalReached_False() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        vm.prank(contributor1);
        crowdfunding.contribute{value: 1 ether}(campaignId);

        bool goalReached = crowdfunding.isGoalReached(campaignId);
        assertFalse(goalReached);
    }

    function test_IsGoalReached_NoContributions() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        bool goalReached = crowdfunding.isGoalReached(campaignId);
        assertFalse(goalReached);
    }

    function test_GetTimeRemaining() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        uint256 timeRemaining = crowdfunding.getTimeRemaining(campaignId);
        assertEq(timeRemaining, CAMPAIGN_DURATION);
    }

    function test_GetTimeRemaining_AfterDeadline() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);

        uint256 timeRemaining = crowdfunding.getTimeRemaining(campaignId);
        assertEq(timeRemaining, 0);
    }

    function test_GetTimeRemaining_PartialTime() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        vm.warp(block.timestamp + (CAMPAIGN_DURATION / 2));

        uint256 timeRemaining = crowdfunding.getTimeRemaining(campaignId);
        assertEq(timeRemaining, CAMPAIGN_DURATION / 2);
    }

    function test_GetTotalCampaigns() public {
        assertEq(crowdfunding.getTotalCampaigns(), 0);

        vm.startPrank(creator);
        crowdfunding.createCampaign(
            "Campaign 1",
            "Desc 1",
            1 ether,
            block.timestamp + CAMPAIGN_DURATION
        );
        assertEq(crowdfunding.getTotalCampaigns(), 1);

        crowdfunding.createCampaign(
            "Campaign 2",
            "Desc 2",
            2 ether,
            block.timestamp + CAMPAIGN_DURATION
        );
        assertEq(crowdfunding.getTotalCampaigns(), 2);

        crowdfunding.createCampaign(
            "Campaign 3",
            "Desc 3",
            3 ether,
            block.timestamp + CAMPAIGN_DURATION
        );
        assertEq(crowdfunding.getTotalCampaigns(), 3);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    CANCELLATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CancelCampaign_Success() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        vm.prank(creator);
        vm.expectEmit(true, true, false, false);
        emit CampaignCancelled(campaignId, creator);
        crowdfunding.cancelCampaign(campaignId);

        (, , , , , , , , , bool cancelled) = crowdfunding.s_campaigns(
            campaignId
        );
        assertEq(cancelled, true);

        assertEq(
            uint256(crowdfunding.getCampaignState(campaignId)),
            uint256(Crowdfunding.CampaignState.CANCELLED)
        );
    }

    function test_RevertWhen_NonCreatorTriesToCancel() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        vm.prank(contributor1);
        vm.expectRevert(
            Crowdfunding.Crowdfunding__OnlyCreatorCanCancel.selector
        );
        crowdfunding.cancelCampaign(campaignId);
    }

    function test_RevertWhen_CancelAfterDeadline() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        vm.warp(block.timestamp + CAMPAIGN_DURATION + 1);

        vm.prank(creator);
        vm.expectRevert(
            Crowdfunding.Crowdfunding__CampaignDeadlineHasPassed.selector
        );
        crowdfunding.cancelCampaign(campaignId);
    }

    function test_RevertWhen_ContributeToCancelledCampaign() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        vm.prank(creator);
        crowdfunding.cancelCampaign(campaignId);

        vm.prank(contributor1);
        vm.expectRevert(
            Crowdfunding.Crowdfunding__CampaignIsCancelled.selector
        );
        crowdfunding.contribute{value: 1 ether}(campaignId);
    }

    function test_ClaimRefund_FromCancelledCampaign() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        uint256 contributionAmount = 5 ether;
        vm.prank(contributor1);
        crowdfunding.contribute{value: contributionAmount}(campaignId);

        vm.prank(creator);
        crowdfunding.cancelCampaign(campaignId);

        uint256 contributor1BalanceBefore = contributor1.balance;

        vm.prank(contributor1);
        vm.expectEmit(true, true, false, true);
        emit RefundClaimed(campaignId, contributor1, contributionAmount);
        crowdfunding.claimRefund(campaignId);

        assertEq(
            contributor1.balance,
            contributor1BalanceBefore + contributionAmount
        );
        assertEq(crowdfunding.getContribution(campaignId, contributor1), 0);
    }

    function test_ClaimRefund_MultipleContributorsFromCancelledCampaign()
        public
    {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            CAMPAIGN_TITLE,
            CAMPAIGN_DESCRIPTION,
            CAMPAIGN_GOAL,
            block.timestamp + CAMPAIGN_DURATION
        );

        uint256 contribution1 = 3 ether;
        uint256 contribution2 = 7 ether;

        vm.prank(contributor1);
        crowdfunding.contribute{value: contribution1}(campaignId);

        vm.prank(contributor2);
        crowdfunding.contribute{value: contribution2}(campaignId);

        vm.prank(creator);
        crowdfunding.cancelCampaign(campaignId);

        uint256 contributor1BalanceBefore = contributor1.balance;
        uint256 contributor2BalanceBefore = contributor2.balance;

        vm.prank(contributor1);
        crowdfunding.claimRefund(campaignId);

        vm.prank(contributor2);
        crowdfunding.claimRefund(campaignId);

        assertEq(
            contributor1.balance,
            contributor1BalanceBefore + contribution1
        );
        assertEq(
            contributor2.balance,
            contributor2BalanceBefore + contribution2
        );
    }

    function test_PlatformFee_CorrectCalculation() public {
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

        uint256 contractBalanceBefore = address(crowdfunding).balance;
        assertEq(contractBalanceBefore, CAMPAIGN_GOAL);

        vm.prank(creator);
        crowdfunding.withdrawFunds(campaignId);

        uint256 expectedPlatformFee = (CAMPAIGN_GOAL * 200) / 10000;
        assertEq(address(crowdfunding).balance, expectedPlatformFee);
    }
}
