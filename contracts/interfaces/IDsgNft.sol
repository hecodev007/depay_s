// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
interface IDsgNft is IERC721 {
    function burn(uint256 tokenId) external;

    function getPower(uint256 tokenId) external view returns (uint256);

    function getLevel(uint256 tokenId) external view returns (uint256);
}