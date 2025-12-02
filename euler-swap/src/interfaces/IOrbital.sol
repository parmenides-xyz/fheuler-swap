// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IOrbital {
    /// @dev Constant pool parameters, loaded from trailing calldata.
    struct StaticParams {
        address[] tokens;       // Token addresses
        address feeRecipient;   // Protocol fee recipient
    }

    /// @dev Reconfigurable pool parameters, loaded from storage.
    /// @dev Based on sphere AMM: ||r - x||² = r²
    struct DynamicParams {
        // Consolidated tick radii
        uint128 rInt;                   // Interior tick radius (sum of all interior tick radii)
        uint128 rBound;                 // Boundary tick radius (consolidated)

        // Boundary tick plane constant
        uint128 kBound;                 // Plane constant k where x·v = k defines boundary

        // Tick boundaries for trade segmentation (normalized: k/r for each tick)
        uint128 closestInteriorK;       // k of closest interior tick to becoming boundary
        uint128 closestBoundaryK;       // k of closest boundary tick to becoming interior

        // Fee parameters (basis points, e.g., 30 = 0.30%)
        uint16 fee;
        uint16 protocolFee;

        // Expiration (0 = no expiration)
        uint48 expiration;
    }

    /// @dev Starting configuration of pool reserves.
    struct InitialState {
        uint128[] reserves;  // Initial reserve for each asset
    }

    /// @dev Running sums for O(1) trade computation.
    struct RunningSums {
        uint256 sumReserves;          // Σxᵢ
        uint256 sumSquaredReserves;   // Σxᵢ²
    }

    /// @notice Performs initial activation setup.
    function activate(DynamicParams calldata dynamicParams, InitialState calldata initialState) external;

    /// @notice Installs or uninstalls a manager.
    function setManager(address manager, bool installed) external;

    /// @notice Check if an address is a manager.
    function managers(address manager) external view returns (bool installed);

    /// @notice Reconfigure the pool's parameters.
    function reconfigure(DynamicParams calldata dParams, InitialState calldata initialState) external;

    /// @notice Retrieves the pool's static parameters.
    function getStaticParams() external view returns (StaticParams memory);

    /// @notice Retrieves the pool's dynamic parameters.
    function getDynamicParams() external view returns (DynamicParams memory);

    /// @notice Retrieves the underlying assets supported by this pool.
    function getAssets() external view returns (address[] memory tokens);

    /// @notice Retrieves the current reserves and running sums.
    function getReserves() external view returns (
        uint128[] memory reserves,
        RunningSums memory sums,
        uint32 status
    );

    /// @notice Get current alpha (mean reserve).
    function getAlpha() external view returns (uint128 alpha);

    /// @notice Generates a quote for a swap.
    function computeQuote(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        bool exactIn
    ) external view returns (uint256);

    /// @notice Upper-bounds on swap amounts.
    function getLimits(
        address tokenIn,
        address tokenOut
    ) external view returns (uint256 limitIn, uint256 limitOut);

    /// @notice Execute a swap.
    function swap(uint256[] calldata amountsOut, address to, bytes calldata data) external;

    /// @notice Verify that reserves satisfy the torus invariant.
    function verifyInvariant(uint128[] calldata reserves) external view returns (bool valid);
}
