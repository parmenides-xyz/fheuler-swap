// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

contract ZorbitalPool {
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    // Pool tokens, immutable
    address public immutable token0;
    address public immutable token1;

    struct Slot0 {
        // Current plane constant
        uint160 alpha;
        // Current tick
        int24 tick;
    }
    Slot0 public slot0;

    // Analogue for liquidity, r.
    uint128 public r;

    // Ticks info
    mapping(int24 => Tick.Info) public ticks;
    // Positions info
    mapping(bytes32 => Position.Info) public positions;
}