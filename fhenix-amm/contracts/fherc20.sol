// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { FHE, euint8, inEuint8 } from "@fhenixprotocol/contracts/FHE.sol";
import { Permissioned, Permission } from "@fhenixprotocol/contracts/access/Permissioned.sol";
import { IFHERC20 } from "./IFHERC20.sol";

error EToken__ErrorInsufficientFunds();
error EToken__ERC20InvalidApprover(address);
error EToken__ERC20InvalidSpender(address);
error EToken__NotZeroAddress();
error EToken__BurnAmountExceedsBalance();
error EToken__AmountMustBeGreaterThanZero();

//test contract with euint8 balances, to avoid timeouts / long processing times

contract MyFHERC20 is IFHERC20, ERC20, Permissioned {

    // A mapping from address to an encrypted balance.
    mapping(address => euint8) internal _encBalances;
    // A mapping from address (owner) to a mapping of address (spender) to an encrypted amount.
    mapping(address => mapping(address => euint8)) private _allowed;
    euint8 private totalEncryptedSupply = FHE.asEuint8(0);

    constructor(
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        _mint(msg.sender, 255);
        wrap(255);
    }

    function _allowanceEncrypted(address owner, address spender) public view virtual returns (euint8) {
        return _allowed[owner][spender];
    }
    function allowanceEncrypted(
        address spender,
        Permission calldata permission
    ) public view virtual onlySender(permission) returns (bytes memory) {
        return FHE.sealoutput(_allowanceEncrypted(msg.sender, spender), permission.publicKey);
    }

    function approveEncrypted(address spender, inEuint8 calldata value) public virtual returns (bool) {
        _approve(msg.sender, spender, FHE.asEuint8(value));
        return true;
    }

    function _approve(address owner, address spender, euint8 value) internal {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowed[owner][spender] = value;
    }

    function _spendAllowance(address owner, address spender, euint8 value) internal virtual returns (euint8) {
        euint8 currentAllowance = _allowanceEncrypted(owner, spender);
        euint8 spent = FHE.min(currentAllowance, value);
        _approve(owner, spender, (currentAllowance - spent));

        return spent;
    }

    function transferFromEncrypted(address from, address to, euint8 value) public virtual returns (euint8) {
        euint8 val = value;
        euint8 spent = _spendAllowance(from, msg.sender, val);
        _transferImpl(from, to, spent);
        return spent;
    }

    function transferFromEncrypted(address from, address to, inEuint8 calldata value) public virtual returns (euint8) {
        euint8 val = FHE.asEuint8(value);
        euint8 spent = _spendAllowance(from, msg.sender, val);
        _transferImpl(from, to, spent);
        return spent;
    }

    function wrap(uint8 amount) public {
        if (balanceOf(msg.sender) < amount) {
            revert EToken__ErrorInsufficientFunds();
        }

        _burn(msg.sender, amount);
        euint8 eAmount = FHE.asEuint8(amount);
        _encBalances[msg.sender] = _encBalances[msg.sender] + eAmount;
        totalEncryptedSupply = totalEncryptedSupply + eAmount;
    }

    function unwrap(uint8 amount) public {
        euint8 encAmount = FHE.asEuint8(amount);

        euint8 amountToUnwrap = FHE.select(_encBalances[msg.sender].gt(encAmount), FHE.asEuint8(0), encAmount);

        _encBalances[msg.sender] = _encBalances[msg.sender] - amountToUnwrap;
        totalEncryptedSupply = totalEncryptedSupply - amountToUnwrap;

        _mint(msg.sender, FHE.decrypt(amountToUnwrap));
    }

//    function mint(uint256 amount) public {
//        _mint(msg.sender, amount);
//    }

    function _mintEncrypted(address to, inEuint8 memory encryptedAmount) internal {
        euint8 amount = FHE.asEuint8(encryptedAmount);
        _encBalances[to] = _encBalances[to] + amount;
        totalEncryptedSupply = totalEncryptedSupply + amount;
    }

    function transferEncrypted(address to, inEuint8 calldata encryptedAmount) public returns (euint8) {
        return transferEncrypted(to, FHE.asEuint8(encryptedAmount));
    }

    // Transfers an amount from the message sender address to the `to` address.
    function transferEncrypted(address to, euint8 amount) public returns (euint8) {
        return _transferImpl(msg.sender, to, amount);
    }

    // Transfers an encrypted amount.
    function _transferImpl(address from, address to, euint8 amount) internal returns (euint8) {
        // Make sure the sender has enough tokens.
        euint8 amountToSend = FHE.select(amount.lt(_encBalances[from]), amount, FHE.asEuint8(0));

        // Add to the balance of `to` and subract from the balance of `from`.
        _encBalances[to] = _encBalances[to] + amountToSend;
        _encBalances[from] = _encBalances[from] - amountToSend;

        return amountToSend;
    }

    function balanceOfEncrypted(
        address account, Permission memory auth
    ) virtual public view onlyPermitted(auth, account) returns (bytes memory) {
        return _encBalances[account].seal(auth.publicKey);
    }

    function burn(uint256 _amount) public {
        if(_amount <= 0) {
            revert EToken__AmountMustBeGreaterThanZero();
        }
        if(balanceOf(msg.sender) < _amount) {
            revert EToken__BurnAmountExceedsBalance();
        }
        _burn(msg.sender, _amount);
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

    //    // Returns the total supply of tokens, sealed and encrypted for the caller.
    //    // todo: add a permission check for total supply readers
    //    function getEncryptedTotalSupply(
    //        Permission calldata permission
    //    ) public view onlySender(permission) returns (bytes memory) {
    //        return totalEncryptedSupply.seal(permission.publicKey);
    //    }
}
