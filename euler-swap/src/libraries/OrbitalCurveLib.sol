// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {UnsafeMath, Math} from "../math/UnsafeMath.sol";
import {FullMath} from "../math/FullMath.sol";
import {Sqrt} from "../math/Sqrt.sol";
import {IOrbital} from "../interfaces/IOrbital.sol";

/// @title OrbitalCurveLib
/// @notice Pure curve math for n-dimensional sphere AMM (following StableMath pattern)
/// @dev Implements the torus invariant from Paradigm's Orbital paper:
///      r_int² = (α_int - r_int√n)² + ||w_int||²
library OrbitalCurveLib {
    using UnsafeMath for uint256;
    using FullMath for uint256;
    using Sqrt for uint256;

    uint256 internal constant PRECISION = 1e18;

    /// @notice The iterations to calculate the balance didn't converge
    error OrbitalComputeBalanceDidNotConverge();

    // ============ Core Invariant Functions ============

    /// @notice Verify that reserves satisfy the torus invariant
    /// @param p Dynamic parameters (rInt, rBound, kBound)
    /// @param sumReserves Σxᵢ
    /// @param sumSquaredReserves Σxᵢ²
    /// @param n Number of tokens
    /// @return valid True if invariant is satisfied within tolerance
    function verify(
        IOrbital.DynamicParams memory p,
        uint256 sumReserves,
        uint256 sumSquaredReserves,
        uint256 n
    ) internal pure returns (bool valid) {
        uint256 sqrtN = n.sqrt();

        // α_total = (1/√n)Σxᵢ
        uint256 alphaTotal = sumReserves.mulDiv(PRECISION, sqrtN);

        // α_int = α_total - k_bound
        if (alphaTotal < p.kBound) return false;
        uint256 alphaInt = alphaTotal - p.kBound;

        // ||w_total||² = Σxᵢ² - (1/n)(Σxᵢ)²
        uint256 wTotalSquared = computeWSquared(sumReserves, sumSquaredReserves, n);
        uint256 wTotal = wTotalSquared.sqrt();

        // s_bound = √(r_bound² - (k_bound - r_bound√n)²)
        uint256 sBound = computeSBound(p.rBound, p.kBound, n);

        // ||w_int|| = max(0, ||w_total|| - s_bound)
        uint256 wInt = wTotal > sBound ? wTotal - sBound : 0;

        // LHS = r_int²
        uint256 rIntSquared = uint256(p.rInt) * uint256(p.rInt);

        // RHS = (α_int - r_int√n)² + ||w_int||²
        uint256 rIntSqrtN = uint256(p.rInt) * sqrtN / PRECISION;
        uint256 term1 = alphaInt > rIntSqrtN ? alphaInt - rIntSqrtN : rIntSqrtN - alphaInt;
        uint256 rhs = (term1 * term1) + (wInt * wInt);

        // Allow small tolerance for rounding errors (0.1%)
        uint256 tolerance = rIntSquared / 1000;
        if (rhs > rIntSquared) {
            return (rhs - rIntSquared) <= tolerance;
        } else {
            return (rIntSquared - rhs) <= tolerance;
        }
    }

    // ============ Swap Computation (StableMath Pattern) ============

    /// @notice Computes the required amountOut for a given amountIn
    /// @dev Uses Newton-Raphson iteration following Balancer's StableMath pattern
    /// @param p Dynamic parameters
    /// @param balances Current reserve balances
    /// @param sums Current running sums
    /// @param tokenIndexIn Index of input token
    /// @param tokenIndexOut Index of output token
    /// @param amountIn Exact amount of input token
    /// @return amountOut The calculated output amount
    function computeOutGivenExactIn(
        IOrbital.DynamicParams memory p,
        uint128[] memory balances,
        IOrbital.RunningSums memory sums,
        uint256 tokenIndexIn,
        uint256 tokenIndexOut,
        uint256 amountIn
    ) internal pure returns (uint256 amountOut) {
        uint256 n = balances.length;

        // Update balances with input
        uint256 oldBalanceIn = balances[tokenIndexIn];
        uint256 newBalanceIn = oldBalanceIn + amountIn;

        // Update running sums for input change
        uint256 newSumReserves = sums.sumReserves - oldBalanceIn + newBalanceIn;
        uint256 newSumSquared = sums.sumSquaredReserves
            - (oldBalanceIn * oldBalanceIn)
            + (newBalanceIn * newBalanceIn);

        // Find new balance for output token that satisfies invariant
        uint256 newBalanceOut = computeBalance(
            p,
            balances,
            newSumReserves,
            newSumSquared,
            tokenIndexOut,
            n
        );

        // Amount out is the decrease in output balance (round down for protocol safety)
        uint256 oldBalanceOut = balances[tokenIndexOut];
        amountOut = oldBalanceOut > newBalanceOut ? oldBalanceOut - newBalanceOut - 1 : 0;
    }

    /// @notice Computes the required amountIn for a given amountOut
    /// @dev Uses Newton-Raphson iteration following Balancer's StableMath pattern
    /// @param p Dynamic parameters
    /// @param balances Current reserve balances
    /// @param sums Current running sums
    /// @param tokenIndexIn Index of input token
    /// @param tokenIndexOut Index of output token
    /// @param amountOut Exact amount of output token desired
    /// @return amountIn The calculated input amount required
    function computeInGivenExactOut(
        IOrbital.DynamicParams memory p,
        uint128[] memory balances,
        IOrbital.RunningSums memory sums,
        uint256 tokenIndexIn,
        uint256 tokenIndexOut,
        uint256 amountOut
    ) internal pure returns (uint256 amountIn) {
        uint256 n = balances.length;

        // Update balances with output
        uint256 oldBalanceOut = balances[tokenIndexOut];
        require(amountOut < oldBalanceOut, "Insufficient reserve");
        uint256 newBalanceOut = oldBalanceOut - amountOut;

        // Update running sums for output change
        uint256 newSumReserves = sums.sumReserves - oldBalanceOut + newBalanceOut;
        uint256 newSumSquared = sums.sumSquaredReserves
            - (oldBalanceOut * oldBalanceOut)
            + (newBalanceOut * newBalanceOut);

        // Find new balance for input token that satisfies invariant
        uint256 newBalanceIn = computeBalance(
            p,
            balances,
            newSumReserves,
            newSumSquared,
            tokenIndexIn,
            n
        );

        // Amount in is the increase in input balance (round up for protocol safety)
        uint256 oldBalanceIn = balances[tokenIndexIn];
        amountIn = newBalanceIn > oldBalanceIn ? newBalanceIn - oldBalanceIn + 1 : 0;
    }

    /// @notice Calculate the balance of a given token that satisfies the invariant
    /// @dev Uses Newton-Raphson iteration. Rounds up overall.
    /// @param p Dynamic parameters
    /// @param balances Current balances (will use all except tokenIndex)
    /// @param sumReserves Current sum after other balance changes
    /// @param sumSquared Current sum of squares after other balance changes
    /// @param tokenIndex Index of token to solve for
    /// @param n Number of tokens
    /// @return balance The balance that satisfies the invariant
    function computeBalance(
        IOrbital.DynamicParams memory p,
        uint128[] memory balances,
        uint256 sumReserves,
        uint256 sumSquared,
        uint256 tokenIndex,
        uint256 n
    ) internal pure returns (uint256 balance) {
        uint256 oldBalance = balances[tokenIndex];

        // Remove old balance contribution from sums
        uint256 sumOthers = sumReserves - oldBalance;
        uint256 sumSquaredOthers = sumSquared - (oldBalance * oldBalance);

        // Pre-compute constants
        uint256 sqrtN = n.sqrt();
        uint256 sBound = computeSBound(p.rBound, p.kBound, n);
        uint256 rIntSquared = uint256(p.rInt) * uint256(p.rInt);

        // Initial guess: start with old balance
        balance = oldBalance;

        // Newton-Raphson iteration (max 255 iterations like Balancer)
        for (uint256 i = 0; i < 255; ++i) {
            uint256 prevBalance = balance;

            // Compute sums with current guess
            uint256 currentSum = sumOthers + balance;
            uint256 currentSumSquared = sumSquaredOthers + (balance * balance);

            // Compute invariant error and derivative
            (int256 f, int256 fPrime) = _computeFAndDerivative(
                p, currentSum, currentSumSquared, balance, n, sqrtN, sBound, rIntSquared
            );

            // Newton step: balance_new = balance - f / f'
            if (fPrime == 0) break;

            // Apply Newton step with care for signs
            int256 step = f / fPrime;
            if (step > 0 && uint256(step) >= balance) {
                balance = 1; // Don't go below 1
            } else if (step > 0) {
                balance = balance - uint256(step);
            } else {
                balance = balance + uint256(-step);
            }

            // Check convergence
            unchecked {
                if (balance > prevBalance) {
                    if (balance - prevBalance <= 1) return balance;
                } else if (prevBalance - balance <= 1) {
                    return balance;
                }
            }
        }

        revert OrbitalComputeBalanceDidNotConverge();
    }

    // ============ Helper Functions ============

    /// @notice Compute α_total = (1/√n) * Σxᵢ
    function computeAlpha(uint256 sumReserves, uint256 n) internal pure returns (uint256 alpha) {
        uint256 sqrtN = n.sqrt();
        alpha = sumReserves.mulDiv(PRECISION, sqrtN);
    }

    /// @notice Compute ||w||² = Σxᵢ² - (1/n)(Σxᵢ)²
    function computeWSquared(
        uint256 sumReserves,
        uint256 sumSquaredReserves,
        uint256 n
    ) internal pure returns (uint256 wSquared) {
        uint256 sumSquared = sumReserves * sumReserves;
        uint256 correction = sumSquared / n;
        wSquared = sumSquaredReserves > correction ? sumSquaredReserves - correction : 0;
    }

    /// @notice Compute s_bound = √(r_bound² - (k_bound - r_bound√n)²)
    function computeSBound(
        uint256 rBound,
        uint256 kBound,
        uint256 n
    ) internal pure returns (uint256 sBound) {
        uint256 sqrtN = n.sqrt();
        uint256 rBoundSqrtN = rBound * sqrtN / PRECISION;

        uint256 diff = kBound > rBoundSqrtN ? kBound - rBoundSqrtN : rBoundSqrtN - kBound;

        uint256 rBoundSquared = rBound * rBound;
        uint256 diffSquared = diff * diff;

        sBound = rBoundSquared > diffSquared ? (rBoundSquared - diffSquared).sqrt() : 0;
    }

    /// @notice Compute instantaneous price of token j in terms of token i
    /// @dev Price = (r - xⱼ) / (r - xᵢ) for sphere AMM
    function computePrice(
        uint256 r,
        uint256 reserveI,
        uint256 reserveJ
    ) internal pure returns (uint256 price) {
        uint256 diffJ = r > reserveJ ? r - reserveJ : 0;
        uint256 diffI = r > reserveI ? r - reserveI : 1; // Avoid division by zero
        price = diffJ.mulDiv(PRECISION, diffI);
    }

    // ============ Internal Functions ============

    /// @notice Compute f(balance) and f'(balance) for Newton's method
    /// @dev f(x) = (α_int - r_int√n)² + ||w_int||² - r_int² = 0
    function _computeFAndDerivative(
        IOrbital.DynamicParams memory p,
        uint256 currentSum,
        uint256 currentSumSquared,
        uint256 balance,
        uint256 n,
        uint256 sqrtN,
        uint256 sBound,
        uint256 rIntSquared
    ) private pure returns (int256 f, int256 fPrime) {
        // α_total = Σxᵢ / √n
        uint256 alphaTotal = currentSum.mulDiv(PRECISION, sqrtN);

        // α_int = α_total - k_bound (can be negative conceptually, but we handle signs)
        int256 alphaInt;
        if (alphaTotal >= p.kBound) {
            alphaInt = int256(alphaTotal - p.kBound);
        } else {
            alphaInt = -int256(p.kBound - alphaTotal);
        }

        // ||w_total||² and ||w_total||
        uint256 wTotalSquared = computeWSquared(currentSum, currentSumSquared, n);
        uint256 wTotal = wTotalSquared.sqrt();

        // ||w_int|| = max(0, ||w_total|| - s_bound)
        uint256 wInt = wTotal > sBound ? wTotal - sBound : 0;

        // term1 = α_int - r_int * √n
        int256 rIntSqrtN = int256(uint256(p.rInt) * sqrtN / PRECISION);
        int256 term1 = alphaInt - rIntSqrtN;

        // f = term1² + wInt² - rInt²
        int256 term1Squared = term1 * term1;
        int256 wIntSquared = int256(wInt * wInt);
        f = term1Squared + wIntSquared - int256(rIntSquared);

        // f' = d/dx[term1² + wInt²]
        // d(term1)/dx = d(α_int)/dx = d(Σxᵢ/√n)/dx = 1/√n
        // d(term1²)/dx = 2 * term1 * (1/√n)
        int256 dTerm1 = int256(PRECISION / sqrtN);
        int256 dTerm1Squared = 2 * term1 * dTerm1 / int256(PRECISION);

        // d(wInt²)/dx requires chain rule through sqrt
        // ||w||² = Σxᵢ² - (Σxᵢ)²/n
        // d(||w||²)/dx = 2x - 2(Σxᵢ)/n = 2(x - Σxᵢ/n) = 2(x - mean)
        int256 dWIntSquared = 0;
        if (wTotal > 0 && wTotal > sBound) {
            int256 mean = int256(currentSum / n);
            int256 dWSq = 2 * (int256(balance) - mean);
            // d(wInt²)/dx = 2*wInt * (d(||w||)/dx) = 2*wInt * (d(||w||²)/dx / (2*||w||))
            //             = wInt * d(||w||²)/dx / ||w||
            dWIntSquared = int256(wInt) * dWSq / int256(wTotal);
        }

        fPrime = dTerm1Squared + dWIntSquared;
    }
}
