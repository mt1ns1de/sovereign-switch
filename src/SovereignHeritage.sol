// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title SovereignHeritage
 * @author Roman Hubariev
 * @notice Abstract module for time-based asset inheritance. OpenZeppelin-free.
 */
abstract contract SovereignHeritage {
    address public heritageBeneficiary;
    uint256 public heritageTimeout;
    uint256 public lastHeartbeat;

    error Heritage__StillAlive();
    error Heritage__Unauthorized();
    error Heritage__TransferFailed();

    event HeartbeatUpdated(uint256 timestamp);
    event HeritageReleased(address indexed to, uint256 amount);
    event HeritageTokenReleased(address indexed token, address indexed to, uint256 amount);

    function __SovereignHeritage_init(address _beneficiary, uint256 _timeoutDays) internal {
        heritageBeneficiary = _beneficiary;
        heritageTimeout = _timeoutDays * 1 days;
        lastHeartbeat = block.timestamp;
    }

    modifier renewHeartbeat() {
        if (msg.sender == _getOwner()) {
            lastHeartbeat = block.timestamp;
            emit HeartbeatUpdated(block.timestamp);
        }
        _;
    }

    function _getOwner() internal view virtual returns (address);

    /**
     * @notice Transfer ETH balance to beneficiary if the switch is triggered.
     */
    function releaseHeritage() external virtual {
        if (block.timestamp < lastHeartbeat + heritageTimeout) revert Heritage__StillAlive();
        
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = heritageBeneficiary.call{value: balance}("");
            if (!success) revert Heritage__TransferFailed();
            emit HeritageReleased(heritageBeneficiary, balance);
        }
    }

    /**
     * @notice Transfer ERC20 tokens to beneficiary if the switch is triggered.
     * @param token The address of the ERC20 token to recover.
     */
    function releaseTokenHeritage(address token) external virtual {
        if (block.timestamp < lastHeartbeat + heritageTimeout) revert Heritage__StillAlive();
        
        uint256 tokenBalance = _getTokenBalance(token);
        if (tokenBalance == 0) return;

        // Low-level call to support non-standard ERC20s and minimize gas.
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", heritageBeneficiary, tokenBalance)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert Heritage__TransferFailed();
        
        emit HeritageTokenReleased(token, heritageBeneficiary, tokenBalance);
    }

    function _getTokenBalance(address token) internal view returns (uint256) {
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSignature("balanceOf(address)", address(this))
        );
        return success ? abi.decode(data, (uint256)) : 0;
    }
}
