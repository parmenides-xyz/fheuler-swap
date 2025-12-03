// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.13 <0.9.0;

import {Permissioned, Permission} from "@fhenixprotocol/contracts/access/Permissioned.sol";
import {IFHERC20} from "./IFHERC20.sol";
import {FHE, inEuint32, euint32, inEuint8, euint8, inEbool, ebool} from "@fhenixprotocol/contracts/FHE.sol";

contract AMM is Permissioned {

    IFHERC20 public immutable i_token0;
    IFHERC20 public immutable i_token1;

    euint8 public s_totalShares;
    mapping(address => euint8) public s_userLiquidityShares;

    euint8 public s_liquidity0;
    euint8 public s_liquidity1;

    //constants used throughout contract
    euint8 private immutable ZERO = FHE.asEuint8(0);
    euint8 private immutable ONE = FHE.asEuint8(1);
    euint8 private immutable TWO = FHE.asEuint8(2);
    euint8 private immutable THREE = FHE.asEuint8(3);

    constructor(address tokenAddress0, address tokenAddress1) {
        i_token0 = IFHERC20(tokenAddress0);
        i_token1 = IFHERC20(tokenAddress1);
    }

    function swap(
        bool zeroForOneIn,   //not sure how to encrypt calldata ebool yet, using regular bool for now
        inEuint8 calldata sellAmountIn
    ) external {
        ebool zeroForOne = FHE.asEbool(zeroForOneIn);
        euint8 sellAmount = FHE.asEuint8(sellAmountIn);

        //even if token0 is not being deposited, transfer 0 tokens to contract to obscure the trade direction
        euint8 token0Amount = FHE.select(zeroForOne, sellAmount, ZERO); //bad practice to use 'ZERO' in multiple places without re-encrypting?
        euint8 token1Amount = FHE.select(zeroForOne, ZERO, sellAmount);
        euint8 sellReserve = FHE.select(zeroForOne, s_liquidity0, s_liquidity1);
        euint8 buyReserve = FHE.select(zeroForOne, s_liquidity1, s_liquidity0);

        i_token0.transferFromEncrypted(
            msg.sender,
            address(this),
            token0Amount
        );

        i_token1.transferFromEncrypted(
            msg.sender,
            address(this),
            token1Amount
        );

        euint8 amountOut = (buyReserve * sellAmount) / (sellReserve + sellAmount);

        settleLiquidity(zeroForOne, sellAmount, amountOut);

        //swap token amounts now for withdrawal of bought tokens
        //even if 0 tokens are withdrawm, still update balance by 0 to obscure trade direction
        i_token0.transferEncrypted(msg.sender, token1Amount);
        i_token1.transferEncrypted(msg.sender, token0Amount);
    }
    
    //max amount of each side user is willing to deposit
    //pool with calculate the optimal amount of each token to deposit based on 'xy = k' formula
    function addLiquidity(
        inEuint8 calldata maxAmountIn0,
        inEuint8 calldata maxAmountIn1    
    ) external {
        euint8 maxAmount0 = FHE.asEuint8(maxAmountIn0);
        euint8 maxAmount1 = FHE.asEuint8(maxAmountIn1);

        euint8 optAmount0;
        euint8 optAmount1;

        ebool liquidity0Zero = FHE.eq(s_liquidity0, ZERO);
        ebool liquidity1Zero = FHE.eq(s_liquidity1, ZERO);

        ebool liquidity0or1Zero = FHE.or(liquidity0Zero, liquidity1Zero);

        (euint8 tempOptAmount0, euint8 tempOptAmount1) = calculateCPLiquidityReq(
            maxAmount0,
            maxAmount1
        );

        optAmount0 = FHE.select(liquidity0or1Zero, maxAmount0, tempOptAmount0); 
        i_token0.transferFromEncrypted(msg.sender, address(this), optAmount0);

        optAmount1 = FHE.select(liquidity0or1Zero, maxAmount1, tempOptAmount1); 
        i_token1.transferFromEncrypted(msg.sender, address(this), optAmount1);

        ebool totalSharesZero = FHE.eq(s_totalShares, ZERO);

        euint8 poolShares = FHE.select(totalSharesZero, _sqrt(optAmount0 * optAmount1), calculateTotalSharesNonZeroLiquidity(optAmount0, optAmount1));

        s_liquidity0 = s_liquidity0 + optAmount0;
        s_liquidity1 = s_liquidity1 + optAmount1;

        s_totalShares = s_totalShares + poolShares;
        s_userLiquidityShares[msg.sender] = s_userLiquidityShares[msg.sender] + poolShares;
    }

    // function withdrawLiquidity(
    //     euint32 poolShares
    // ) external returns (euint32 amount0, euint32 amount1) {

    //     amount0 = (poolShares * s_liquidity0) / s_totalShares;
    //     amount1 = (poolShares * s_liquidity1) / s_totalShares;

    //     s_userLiquidityShares[msg.sender] = s_userLiquidityShares[msg.sender] - poolShares;
    //     s_totalShares = s_totalShares - poolShares;

    //     s_liquidity0 = s_liquidity0 - amount0;
    //     s_liquidity1 = s_liquidity1 - amount1;

    //     i_token0.transferEncrypted(msg.sender, amount0);
    //     i_token1.transferEncrypted(msg.sender, amount1);
    // }

    function settleLiquidity(
        ebool zeroForOne,
        euint8 sellAmount,
        euint8 buyAmount
    ) private {
        s_liquidity0 = FHE.select(zeroForOne, s_liquidity0 + sellAmount, s_liquidity0 - buyAmount);
        s_liquidity1 = FHE.select(zeroForOne, s_liquidity1 - buyAmount, s_liquidity1 + sellAmount);
    }

    function calculateCPLiquidityReq(
        euint8 maxAmount0,
        euint8 maxAmount1
    ) private view returns (euint8 optAmount0, euint8 optAmount1) {
        euint8 cp0 = maxAmount0 * s_liquidity1;
        euint8 cp1 = maxAmount1 * s_liquidity0;

        ebool cp0eqcp1 = FHE.eq(cp0, cp1);

        optAmount0 = FHE.select(cp0eqcp1, maxAmount0, _checkCp0LtCp1Amount0(cp0, cp1, maxAmount0));
        optAmount1 = FHE.select(cp0eqcp1, maxAmount1, _checkCp0LtCp1Amount1(cp0, cp1, maxAmount1));
    }

    function _checkCp0LtCp1Amount0(euint8 cp0, euint8 cp1, euint8 maxAmount0) private view returns (euint8) {
        ebool cp0ltcp1 = FHE.lt(cp0, cp1);
        return FHE.select(cp0ltcp1, maxAmount0, cp1 / s_liquidity1);
    }

    function _checkCp0LtCp1Amount1(euint8 cp0, euint8 cp1, euint8 maxAmount1) private view returns (euint8) {
        ebool cp0ltcp1 = FHE.lt(cp0, cp1);
        return FHE.select(cp0ltcp1, cp0 / s_liquidity0, maxAmount1);
    }

    function calculateTotalSharesNonZeroLiquidity(euint8 optAmount0, euint8 optAmount1) private view returns (euint8 poolShares){
        euint8 shares0 = (optAmount0 * s_totalShares) / s_liquidity0;
        euint8 shares1 = (optAmount1 * s_totalShares) / s_liquidity1;

        ebool shares0ltShares1 = FHE.lt(shares0, shares1);

        poolShares = FHE.select(shares0ltShares1, shares0, shares1);
    }

    function _sqrt(euint8 ye) private pure returns(euint8){
        uint8 y = FHE.decrypt(ye);
        uint8 z;
        if (y > 3) {
            z = y;
            uint8 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
        return FHE.asEuint8(z);
    }
}