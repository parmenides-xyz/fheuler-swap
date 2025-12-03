// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IZorbitalFlashCallback {
    function zorbitalFlashCallback(bytes calldata data) external;
}
