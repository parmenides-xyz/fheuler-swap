// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IOrbital} from "../interfaces/IOrbital.sol";
import {FHE, euint128, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

library OrbitalCtxLib {
    struct State {
        uint128[] reserves;
        uint256 sumReserves;          // Σxᵢ
        uint256 sumSquaredReserves;   // Σxᵢ²
        uint32 status;                // 0 = unactivated, 1 = unlocked, 2 = locked
        mapping(address manager => bool installed) managers;
    }

    struct FHEState {
        euint128[] eReserves;
        euint128 eSumReserves;
        euint128 eSumSquaredReserves;
        bool initialized;
    }

    // keccak256("orbital.state") - 1
    bytes32 internal constant CtxStateLocation = 0xe4d840ffe0e97e0104d990e946b4a66a2d9f5089c6bc2e68ebaba4504784a623;

    // keccak256("orbital.fheState") - 1
    bytes32 internal constant CtxFHEStateLocation = 0xfb319883ea60d0c39306caeb675bdcb552b15d3c0d216a2161799c6352c2f406;

    function getState() internal pure returns (State storage s) {
        assembly {
            s.slot := CtxStateLocation
        }
    }

    function getFHEState() internal pure returns (FHEState storage s) {
        assembly {
            s.slot := CtxFHEStateLocation
        }
    }

    /// @notice Initialize FHE state from plaintext reserves
    function initializeFHEState() internal {
        State storage ps = getState();
        FHEState storage fs = getFHEState();
        require(!fs.initialized, "FHE state already initialized");

        uint256 n = ps.reserves.length;
        for (uint256 i = 0; i < n; i++) {
            fs.eReserves.push(FHE.asEuint128(ps.reserves[i]));
            FHE.allowThis(fs.eReserves[i]);
        }

        fs.eSumReserves = FHE.asEuint128(uint128(ps.sumReserves));
        fs.eSumSquaredReserves = FHE.asEuint128(uint128(ps.sumSquaredReserves));

        FHE.allowThis(fs.eSumReserves);
        FHE.allowThis(fs.eSumSquaredReserves);

        fs.initialized = true;
    }

    /// @notice Update FHE reserves after a swap
    function updateFHEReserves(
        uint256 assetIndex,
        euint128 newReserve,
        euint128 newSumReserves,
        euint128 newSumSquaredReserves
    ) internal {
        FHEState storage fs = getFHEState();

        fs.eReserves[assetIndex] = newReserve;
        fs.eSumReserves = newSumReserves;
        fs.eSumSquaredReserves = newSumSquaredReserves;

        FHE.allowThis(fs.eReserves[assetIndex]);
        FHE.allowThis(fs.eSumReserves);
        FHE.allowThis(fs.eSumSquaredReserves);
    }

    // keccak256("orbital.dynamicParams") - 1
    bytes32 internal constant CtxDynamicParamsLocation = 0xe44f882f891f0041884f117c042eecf95b3ef449fbbff011f8b9fb80e1ba7492;

    function writeDynamicParamsToStorage(IOrbital.DynamicParams memory dParams) internal {
        IOrbital.DynamicParams storage s;

        assembly {
            s.slot := CtxDynamicParamsLocation
        }

        s.rInt = dParams.rInt;
        s.rBound = dParams.rBound;
        s.kBound = dParams.kBound;
        s.closestInteriorK = dParams.closestInteriorK;
        s.closestBoundaryK = dParams.closestBoundaryK;
        s.fee = dParams.fee;
        s.protocolFee = dParams.protocolFee;
        s.expiration = dParams.expiration;
    }

    function getDynamicParams() internal pure returns (IOrbital.DynamicParams memory) {
        IOrbital.DynamicParams storage s;

        assembly {
            s.slot := CtxDynamicParamsLocation
        }

        return s;
    }

    error InsufficientCalldata();

    /// @dev Unpacks encoded StaticParams from trailing calldata.
    function getStaticParams() internal pure returns (IOrbital.StaticParams memory p) {
        uint256 dataLength = msg.data.length;
        require(dataLength >= 64, InsufficientCalldata());
        return abi.decode(msg.data[msg.data.length - _getStaticParamsSize():], (IOrbital.StaticParams));
    }

    function _getStaticParamsSize() private pure returns (uint256) {
        return 96;
    }

    /// @notice Get number of assets in the pool
    function getNumAssets() internal view returns (uint256) {
        return getState().reserves.length;
    }

    /// @notice Get current alpha (mean reserve)
    function getAlpha() internal view returns (uint128) {
        State storage s = getState();
        uint256 n = s.reserves.length;
        if (n == 0) return 0;
        return uint128(s.sumReserves / n);
    }
}
