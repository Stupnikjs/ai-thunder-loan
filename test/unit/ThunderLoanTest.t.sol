// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { BaseTest, ThunderLoan } from "./BaseTest.t.sol";
import { AssetToken } from "../../src/protocol/AssetToken.sol";
import { MockFlashLoanReceiver } from "../mocks/MockFlashLoanReceiver.sol";

contract ThunderLoanTest is BaseTest {
    uint256 constant AMOUNT = 10e18;
    uint256 constant DEPOSIT_AMOUNT = AMOUNT * 100;
    address liquidityProvider = address(123);
    address user = address(456);
    MockFlashLoanReceiver mockFlashLoanReceiver;

    function setUp() public override {
        super.setUp();
        vm.prank(user);
        mockFlashLoanReceiver = new MockFlashLoanReceiver(address(thunderLoan));
    }

    function testInitializationOwner() public {
        assertEq(thunderLoan.owner(), address(this));
    }

    function testSetAllowedTokens() public {
        vm.prank(thunderLoan.owner());
        thunderLoan.setAllowedToken(tokenA, true);
        assertEq(thunderLoan.isAllowedToken(tokenA), true);
    }

    function testOnlyOwnerCanSetTokens() public {
        vm.prank(liquidityProvider);
        vm.expectRevert();
        thunderLoan.setAllowedToken(tokenA, true);
    }

    function testSettingTokenCreatesAsset() public {
        vm.prank(thunderLoan.owner());
        AssetToken assetToken = thunderLoan.setAllowedToken(tokenA, true);
        assertEq(address(thunderLoan.getAssetFromToken(tokenA)), address(assetToken));
    }

    function testCantDepositUnapprovedTokens() public {
        tokenA.mint(liquidityProvider, AMOUNT);
        tokenA.approve(address(thunderLoan), AMOUNT);
        vm.expectRevert(abi.encodeWithSelector(ThunderLoan.ThunderLoan__NotAllowedToken.selector, address(tokenA)));
        thunderLoan.deposit(tokenA, AMOUNT);
    }

    modifier setAllowedToken() {
        vm.prank(thunderLoan.owner());
        thunderLoan.setAllowedToken(tokenA, true);
        _;
    }

    function testDepositMintsAssetAndUpdatesBalance() public setAllowedToken {
        tokenA.mint(liquidityProvider, AMOUNT);

        vm.startPrank(liquidityProvider);
        tokenA.approve(address(thunderLoan), AMOUNT);
        thunderLoan.deposit(tokenA, AMOUNT);
        vm.stopPrank();

        AssetToken asset = thunderLoan.getAssetFromToken(tokenA);
        assertEq(tokenA.balanceOf(address(asset)), AMOUNT);
        assertEq(asset.balanceOf(liquidityProvider), AMOUNT);
    }

    modifier hasDeposits() {
        vm.startPrank(liquidityProvider);
        tokenA.mint(liquidityProvider, DEPOSIT_AMOUNT);
        tokenA.approve(address(thunderLoan), DEPOSIT_AMOUNT);
        thunderLoan.deposit(tokenA, DEPOSIT_AMOUNT);
        vm.stopPrank();
        _;
    }
    function testFuzz_DepositThenReedem(uint256 _amount) public setAllowedToken {
        _amount = bound(_amount, 1000, 1e18);
        vm.startPrank(liquidityProvider);
        tokenA.mint(liquidityProvider, _amount);
        tokenA.approve(address(thunderLoan), _amount);
        thunderLoan.deposit(tokenA, _amount);
        bool isAllowed = thunderLoan.isAllowedToken(tokenA);
        uint256 balanceBefore = tokenA.balanceOf(liquidityProvider);
        assertEq(balanceBefore, 0);
        assertTrue(isAllowed);
        thunderLoan.redeem(tokenA, _amount);
        uint256 balance = tokenA.balanceOf(liquidityProvider);
        assertEq(balance, _amount);
        vm.stopPrank();
    }


    function testFlashLoan() public setAllowedToken hasDeposits {
        uint256 amountToBorrow = AMOUNT * 10;
        uint256 calculatedFee = thunderLoan.getCalculatedFee(tokenA, amountToBorrow);
        vm.startPrank(user);
        tokenA.mint(address(mockFlashLoanReceiver), AMOUNT);
        thunderLoan.flashloan(address(mockFlashLoanReceiver), tokenA, amountToBorrow, "");
        vm.stopPrank();

        assertEq(mockFlashLoanReceiver.getbalanceDuring(), amountToBorrow + AMOUNT);
        assertEq(mockFlashLoanReceiver.getBalanceAfter(), AMOUNT - calculatedFee);
    }
    function testFlashLoanSmallAMOUNT() public setAllowedToken hasDeposits {
        uint256 minAmount = 1e18 / uint256(3e15) + 1;

        uint256 amountToBorrow = minAmount;
        uint256 calculatedFee = thunderLoan.getCalculatedFee(tokenA, amountToBorrow);
        assertNotEq(0, calculatedFee); 
        
        vm.startPrank(user);
        tokenA.mint(address(mockFlashLoanReceiver), minAmount);
        thunderLoan.flashloan(address(mockFlashLoanReceiver), tokenA, amountToBorrow, "");
        
        vm.stopPrank();

        assertEq(mockFlashLoanReceiver.getbalanceDuring(), amountToBorrow + minAmount);
        assertEq(mockFlashLoanReceiver.getBalanceAfter(), minAmount - calculatedFee);
    }

    function testFeeForSmallAMOUNT() public setAllowedToken hasDeposits {
        // 333 doesnt work 334 does 
        uint256 minAmount = 1e18 / uint256(3e15) + 1;
        uint256 calculatedFee = thunderLoan.getCalculatedFee(tokenA, minAmount);
       assertNotEq(calculatedFee, 0); 
       
    }

   

 function testFuzz_NonZeroAmountShouldAlwaysHaveFee(uint256 amount) public {
    amount = bound(amount, 1, 1e18);

    uint256 fee = thunderLoan.getCalculatedFee(tokenA, amount);

    // Economic invariant that SHOULD hold
    assertGt(fee, 0, "Non-zero deposit resulted in zero fee");
}
}
