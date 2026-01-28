// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/SovereignHeritage.sol";

// Простой ERC20 для тестов
contract MockToken {
    mapping(address => uint256) public balanceOf;
    function mint(address to, uint256 amount) public { balanceOf[to] += amount; }
    function transfer(address to, uint256 amount) public returns (bool) {
        if (balanceOf[msg.sender] < amount) return false;
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract MockVault is SovereignHeritage {
    address public owner;
    constructor(address _owner, address _beneficiary, uint256 _days) {
        owner = _owner;
        __SovereignHeritage_init(_beneficiary, _days);
    }
    function _getOwner() internal view override returns (address) { return owner; }
    function withdraw() external renewHeartbeat {}
    receive() external payable {}
}

contract SovereignHeritageTest is Test {
    MockVault vault;
    MockToken tokenA;
    MockToken tokenB;
    address owner = address(1);
    address beneficiary = address(2);
    uint256 timeoutDays = 30;

    function setUp() public {
        vault = new MockVault(owner, beneficiary, timeoutDays);
        tokenA = new MockToken();
        tokenB = new MockToken();
        
        vm.deal(address(vault), 10 ether);
        tokenA.mint(address(vault), 500e18);
        tokenB.mint(address(vault), 1000e18);
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

    function test_BatchReleaseTokens() public {
        vm.warp(block.timestamp + 31 days);
        
        address[] memory tokens = new address[](2);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);

        vault.batchReleaseTokens(tokens);

        assertEq(tokenA.balanceOf(beneficiary), 500e18);
        assertEq(tokenB.balanceOf(beneficiary), 1000e18);
        assertEq(tokenA.balanceOf(address(vault)), 0);
        assertEq(tokenB.balanceOf(address(vault)), 0);
    }

    function test_ReleaseETHAfterTimeout() public {
        vm.warp(block.timestamp + 31 days);
        uint256 initialBalance = beneficiary.balance;
        vault.releaseHeritage();
        assertEq(beneficiary.balance, initialBalance + 10 ether);
    }
}
