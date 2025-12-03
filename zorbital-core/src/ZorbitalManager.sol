// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import "./ZorbitalPool.sol";
import "./libraries/OrbitalMath.sol";
import "./interfaces/IERC20.sol";

contract ZorbitalManager {
    struct CallbackData {
        address pool;
        address payer;
    }

    struct MintParams {
        address poolAddress;
        int24 tick;
        uint256[] amountsDesired; // Desired amounts for each token
        uint256[] amountsMin;     // Minimum amounts for slippage protection
    }

    error SlippageCheckFailed(uint256[] amounts);

    function mint(MintParams calldata params)
        public
        returns (uint256[] memory amounts)
    {
        // Calculate radius from desired amounts (like Uniswap V3's getLiquidityForAmounts)
        uint128 radius = OrbitalMath.calcRadiusForAmounts(params.amountsDesired);

        amounts = ZorbitalPool(params.poolAddress).mint(
            msg.sender,
            params.tick,
            radius,
            abi.encode(CallbackData({pool: params.poolAddress, payer: msg.sender}))
        );

        // Slippage check: ensure amounts are at least the minimums
        for (uint256 i = 0; i < amounts.length; i++) {
            if (amounts[i] < params.amountsMin[i])
                revert SlippageCheckFailed(amounts);
        }
    }

    function swap(
        address poolAddress,
        uint256 tokenInIndex,
        uint256 tokenOutIndex,
        uint256 amountSpecified,
        uint128 sumReservesLimit
    ) public returns (int256 amountIn, int256 amountOut) {
        (amountIn, amountOut) = ZorbitalPool(poolAddress).swap(
            msg.sender,
            tokenInIndex,
            tokenOutIndex,
            amountSpecified,
            sumReservesLimit,
            abi.encode(CallbackData({pool: poolAddress, payer: msg.sender}))
        );
    }

    function zorbitalMintCallback(
        uint256[] memory amounts,
        bytes calldata data
    ) public {
        CallbackData memory extra = abi.decode(data, (CallbackData));
        ZorbitalPool pool = ZorbitalPool(extra.pool);

        for (uint256 i = 0; i < amounts.length; i++) {
            IERC20(pool.tokens(i)).transferFrom(
                extra.payer,
                msg.sender,
                amounts[i]
            );
        }
    }

    function zorbitalSwapCallback(
        uint256 tokenInIndex,
        uint256 /* tokenOutIndex */,
        int256 amountIn,
        int256 /* amountOut */,
        bytes calldata data
    ) public {
        CallbackData memory extra = abi.decode(data, (CallbackData));
        ZorbitalPool pool = ZorbitalPool(extra.pool);

        if (amountIn > 0) {
            IERC20(pool.tokens(tokenInIndex)).transferFrom(
                extra.payer,
                msg.sender,
                uint256(amountIn)
            );
        }
    }
}
