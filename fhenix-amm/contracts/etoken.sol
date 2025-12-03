// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

import { FHERC20 } from "@fhenixprotocol/contracts/experimental/token/FHERC20/FHERC20.sol";

contract EToken is FHERC20 {

    error EToken__NotZeroAddress();
    error EToken__BurnAmountExceedsBalance();
    error EToken__AmountMustBeGreaterThanZero();

    constructor(
        string memory name,
        string memory symbol
    ) FHERC20(name, symbol) {}

    function burn(uint256 _amount) public {
        if(_amount <= 0) {
            revert EToken__AmountMustBeGreaterThanZero();
        }
        if(balanceOf(msg.sender) < _amount) {
            revert EToken__BurnAmountExceedsBalance();
        }
        burn(_amount);
    }

    function mint(address _to, uint256 _amount) external returns(bool) {
        if(_to == address(0)) {
            revert EToken__NotZeroAddress();
        }
        if(_amount <= 0) {
            revert EToken__AmountMustBeGreaterThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}