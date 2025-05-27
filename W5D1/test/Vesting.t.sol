// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {MyToken} from "../src/MyToken.sol";
import {Vesting} from "../src/Vesting.sol";

contract VestingTest is Test {
    MyToken public token;
    Vesting public vesting;
    address public beneficiary = address(0x1);
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18; // 100万个代币

    function setUp() public {
        // 部署ERC20代币
        token = new MyToken();
        
        // 部署Vesting合约
        vesting = new Vesting(beneficiary);
        
        // 将代币转入Vesting合约
        token.transfer(address(vesting), INITIAL_SUPPLY);
    }

    function testInitialState() public view{
        assertEq(token.balanceOf(address(vesting)), INITIAL_SUPPLY);
        assertEq(vesting.beneficiary(), beneficiary);
    }

    function testCliffPeriod() public {
        // 在cliff期间尝试释放代币
        vm.warp(block.timestamp + 11 * 30 days); // 第11个月
        vesting.release(address(token));
        assertEq(token.balanceOf(beneficiary), 0);
    }

    function testFirstRelease() public {
        // 在cliff结束后立即释放（第13个月）
        vm.warp(block.timestamp + 13 * 30 days);
        vesting.release(address(token));
        
        // 计算应该释放的代币数量（1个月的线性释放量）
        uint256 expectedAmount = (INITIAL_SUPPLY * 30 days) / (24 * 30 days);
        assertApproxEqAbs(token.balanceOf(beneficiary), expectedAmount, 1);
    }

    function testMidVesting() public {
        // 在24个月时释放（线性释放中期）
        vm.warp(block.timestamp + 24 * 30 days);
        vesting.release(address(token));
        
        // 计算应该释放的代币数量（12个月的线性释放量）
        uint256 expectedAmount = (INITIAL_SUPPLY * 12 * 30 days) / (24 * 30 days);
        assertApproxEqAbs(token.balanceOf(beneficiary), expectedAmount, 1);
    }

    function testCompleteVesting() public {
        // 在36个月后释放（完全归属）
        vm.warp(block.timestamp + 37 * 30 days);
        vesting.release(address(token));
        
        // 应该释放所有代币
        assertEq(token.balanceOf(beneficiary), INITIAL_SUPPLY);
    }

    function testMultipleReleases() public {
        // 测试多次释放
        vm.warp(block.timestamp + 13 * 30 days);
        vesting.release(address(token));
        uint256 firstRelease = token.balanceOf(beneficiary);
        
        vm.warp(block.timestamp + 1 * 30 days);
        vesting.release(address(token));
        uint256 secondRelease = token.balanceOf(beneficiary) - firstRelease;
        
        // 允许1个wei的误差
        assertApproxEqAbs(firstRelease, secondRelease, 1);
    }
} 