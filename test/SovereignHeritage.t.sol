// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/SovereignHeritage.sol";

contract MockVault is SovereignHeritage {
    address public owner;

    constructor(address _owner, address _beneficiary, uint256 _days) {
        owner = _owner;
        __SovereignHeritage_init(_beneficiary, _days);
    }

    function _getOwner() internal view override returns (address) {
        return owner;
    }

    function withdraw() external renewHeartbeat {
        // Mock withdraw logic
    }

    receive() external payable {}
}

contract SovereignHeritageTest is Test {
    MockVault vault;
    address owner = address(1);
    address beneficiary = address(2);
    uint256 timeoutDays = 30;

    function setUp() public {
        vault = new MockVault(owner, beneficiary, timeoutDays);
        vm.deal(address(vault), 10 ether);
    }

    function test_CannotReleaseEarly() public {
        vm.warp(block.timestamp + 10 days);
        vm.expectRevert(SovereignHeritage.Heritage__StillAlive.selector);
        vault.releaseHeritage();
    }

    function test_HeartbeatResetsTimer() public {
        vm.warp(block.timestamp + 20 days);
        vm.prank(owner);
        vault.withdraw(); 

        vm.warp(block.timestamp + 20 days);
        vm.expectRevert(SovereignHeritage.Heritage__StillAlive.selector);
        vault.releaseHeritage();
    }

    function test_ReleaseAfterTimeout() public {
        vm.warp(block.timestamp + 31 days);
        uint256 initialBalance = beneficiary.balance;
        
        vault.releaseHeritage();
        
        assertEq(beneficiary.balance, initialBalance + 10 ether);
        assertEq(address(vault).balance, 0);
    }
}
