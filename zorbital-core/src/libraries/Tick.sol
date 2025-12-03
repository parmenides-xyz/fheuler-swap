// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

/// @title Tick library for Orbital AMM
/// @notice In Orbital, ticks are nested boundaries around the equal-price point.
/// Unlike Uniswap V3 where ticks have lower/upper pairs, Orbital ticks have a single
/// boundary at distance k from the equal-price point.
///
/// Key concepts from Orbital.md:
/// - Interior tick: α^norm < k^norm (reserves inside boundary, contributes to r_int)
/// - Boundary tick: α^norm = k^norm (reserves pinned at plane, contributes to s_bound)
/// - When α increases past k^norm: interior → boundary, subtract r from r_int
/// - When α decreases below k^norm: boundary → interior, add r to r_int
library Tick {
    struct Info {
        bool initialized;
        // Total radius at this tick (for flip detection, like liquidityGross)
        uint128 rGross;
        // Radius to add/subtract when crossing (always positive in Orbital)
        // Direction of crossing determines whether to add or subtract
        uint128 rNet;
    }

    function update(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        uint128 rDelta
    ) internal returns (bool flipped) {
        Tick.Info storage tickInfo = self[tick];
        uint128 rGrossBefore = tickInfo.rGross;
        uint128 rGrossAfter = rGrossBefore + rDelta;

        flipped = (rGrossAfter == 0) != (rGrossBefore == 0);

        if (rGrossBefore == 0) {
            tickInfo.initialized = true;
        }

        tickInfo.rGross = rGrossAfter;
        // In Orbital with nested ticks, rNet simply accumulates the radius
        // (always positive - direction determines add/subtract when crossing)
        tickInfo.rNet = tickInfo.rNet + rDelta;
    }

    /// @notice Returns the radius to add/subtract when crossing this tick
    /// @dev In Orbital, the returned value is always positive.
    /// The caller determines whether to add or subtract based on swap direction:
    /// - Moving toward equal-price (α decreasing): add rNet (tick becomes interior)
    /// - Moving away from equal-price (α increasing): subtract rNet (tick becomes boundary)
    function cross(
        mapping(int24 => Tick.Info) storage self,
        int24 tick
    ) internal view returns (uint128 rNet) {
        Tick.Info storage info = self[tick];
        rNet = info.rNet;
    }
}
