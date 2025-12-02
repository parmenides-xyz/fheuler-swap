// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {UnsafeMath, Math} from "../math/UnsafeMath.sol";
import {FullMath} from "../math/FullMath.sol";
import {Sqrt} from "../math/Sqrt.sol";
import {IOrbital} from "../interfaces/IOrbital.sol";

/// @title OrbitalCurveLib
/// @notice Curve math for n-dimensional AMM
library OrbitalCurveLib {
    using UnsafeMath for uint256;
    using FullMath for uint256;
    using Sqrt for uint256;

    uint256 internal constant PRECISION = 1e18;

    /// @notice Compute α_total
    function computeAlpha(uint256 sumReserves, uint256 n) internal pure returns (uint256 alpha) {
        // α = (1/√n) * Σxᵢ = Σxᵢ / √n
        // We compute √n with PRECISION scaling
        uint256 sqrtN = n.sqrt();
        alpha = sumReserves.mulDiv(PRECISION, sqrtN);
    }

    /// @notice Compute rightmost term
    function computeWSquared(
        uint256 sumReserves,
        uint256 sumSquaredReserves,
        uint256 n
    ) internal pure returns (uint256 wSquared) {
        uint256 sumSquared = sumReserves * sumReserves;
        uint256 correction = sumSquared / n;
        wSquared = sumSquaredReserves - correction;
    }

    /// @notice Compute s_bound = √(r_bound² - (k_bound - r_bound√n)²)
    function computeSBound(
        uint256 rBound,
        uint256 kBound,
        uint256 n
    ) internal pure returns (uint256 sBound) {
        // s_bound = √(r_bound² - (k_bound - r_bound√n)²)
        uint256 sqrtN = n.sqrt();
        uint256 rBoundSqrtN = rBound * sqrtN;

        uint256 diff;
        if (kBound >= rBoundSqrtN) {
            diff = kBound - rBoundSqrtN;
        } else {
            diff = rBoundSqrtN - kBound;
        }

        uint256 rBoundSquared = rBound * rBound;
        uint256 diffSquared = diff * diff;

        if (rBoundSquared >= diffSquared) {
            sBound = (rBoundSquared - diffSquared).sqrt();
        } else {
            sBound = 0;
        }
    }

    /// @notice Verify that reserves satisfy invariant
    function verify(
        IOrbital.DynamicParams memory p,
        uint256 sumReserves,
        uint256 sumSquaredReserves,
        uint256 n
    ) internal pure returns (bool) {
        uint256 sqrtN = n.sqrt();

        // Compute α_total = (1/√n)Σxᵢ
        uint256 alphaTotal = sumReserves / sqrtN;

        // Compute α_int = α_total - k_bound
        uint256 alphaInt;
        if (alphaTotal >= p.kBound) {
            alphaInt = alphaTotal - p.kBound;
        } else {
            // This shouldn't happen in normal operation
            return false;
        }

        // Compute ||w_total||² = Σxᵢ² - (1/n)(Σxᵢ)²
        uint256 wTotalSquared = computeWSquared(sumReserves, sumSquaredReserves, n);
        uint256 wTotal = wTotalSquared.sqrt();

        // Compute s_bound = √(r_bound² - (k_bound - r_bound√n)²)
        uint256 sBound = computeSBound(p.rBound, p.kBound, n);

        // Compute ||w_int|| = ||w_total|| - s_bound
        uint256 wInt;
        if (wTotal >= sBound) {
            wInt = wTotal - sBound;
        } else {
            wInt = 0;
        }

        // Compute LHS
        uint256 rIntSquared = uint256(p.rInt) * uint256(p.rInt);

        // Compute RHS
        uint256 rIntSqrtN = uint256(p.rInt) * sqrtN;
        uint256 term1;
        if (alphaInt >= rIntSqrtN) {
            term1 = alphaInt - rIntSqrtN;
        } else {
            term1 = rIntSqrtN - alphaInt;
        }
        uint256 term1Squared = term1 * term1;
        uint256 wIntSquared = wInt * wInt;
        uint256 rhs = term1Squared + wIntSquared;

        // Allow small tolerance for rounding errors (0.1%)
        uint256 tolerance = rIntSquared / 1000;
        if (rhs > rIntSquared) {
            return (rhs - rIntSquared) <= tolerance;
        } else {
            return (rIntSquared - rhs) <= tolerance;
        }
    }

    /// @notice Compute the output amount for a swap using Newton's method
    function computeSwapOutput(
        IOrbital.DynamicParams memory p,
        uint128[] memory reserves,
        IOrbital.RunningSums memory sums,
        uint256 indexIn,
        uint256 indexOut,
        uint256 amountIn
    ) internal pure returns (uint256 amountOut) {
        uint256 n = reserves.length;
        uint256 reserveIn = reserves[indexIn];
        uint256 reserveOut = reserves[indexOut];

        // New input reserve
        uint256 newReserveIn = reserveIn + amountIn;

        // Update running sums for input change
        uint256 newSumReserves = sums.sumReserves - reserveIn + newReserveIn;
        uint256 newSumSquared = sums.sumSquaredReserves
            - (reserveIn * reserveIn)
            + (newReserveIn * newReserveIn);

        // Binary search for amountOut that satisfies the invariant
        // This is a quartic equation, but binary search is simpler and gas-efficient
        uint256 low = 0;
        uint256 high = reserveOut - 1;

        while (low < high) {
            uint256 mid = (low + high + 1) / 2;
            uint256 newReserveOut = reserveOut - mid;

            // Update sums for this candidate output
            uint256 candidateSumReserves = newSumReserves - reserveOut + newReserveOut;
            uint256 candidateSumSquared = newSumSquared
                - (reserveOut * reserveOut)
                + (newReserveOut * newReserveOut);

            if (verify(p, candidateSumReserves, candidateSumSquared, n)) {
                low = mid;
            } else {
                high = mid - 1;
            }
        }

        amountOut = low;
    }

    /// @notice Update running sums after changing one reserve
    function updateSums(
        IOrbital.RunningSums memory sums,
        uint256 oldReserve,
        uint256 newReserve
    ) internal pure returns (IOrbital.RunningSums memory) {
        sums.sumReserves = sums.sumReserves - oldReserve + newReserve;
        sums.sumSquaredReserves = sums.sumSquaredReserves
            - (oldReserve * oldReserve)
            + (newReserve * newReserve);
        return sums;
    }

    /// @notice Compute the equal price point reserve value
    function computeEqualPriceReserve(uint256 r, uint256 n) internal pure returns (uint256 q) {
        // q = r(1 - 1/√n)
        uint256 sqrtN = n.sqrt();
        q = r - (r / sqrtN);
    }

    /// @notice Compute instantaneous price of token j in terms of token i
    function computePrice(
        uint256 r,
        uint256 reserveI,
        uint256 reserveJ
    ) internal pure returns (uint256 price) {
        uint256 diffJ = r - reserveJ;
        uint256 diffI = r - reserveI;
        price = diffJ.mulDiv(PRECISION, diffI);
    }
}
