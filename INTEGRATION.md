# Sovereign Switch Integration

Minimalist guide to implementing time-based inheritance.

## Implementation

1. Copy `src/SovereignHeritage.sol` to your project.
2. Inherit and link your ownership logic.

```solidity
import "./SovereignHeritage.sol";

contract Vault is SovereignHeritage {
    address public owner;

    constructor(address _beneficiary, uint256 _days) {
        owner = msg.sender;
        __SovereignHeritage_init(_beneficiary, _days);
    }

    function _getOwner() internal view override returns (address) {
        return owner;
    }

    function act() external renewHeartbeat {
        // Resets timer on every call
    }
}