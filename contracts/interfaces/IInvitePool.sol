// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

//import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IInvitePool {
    function getOneUpper(address user) external view returns (address);

    function getOneLevelLists(address addr) external view returns (address[] memory);

    function getFiveAllLists(address addr) external view returns (address[] memory);

    function addRecommend(address _self, address _recommend) external returns (bool);

    function getUppers(address user) external view returns (address[] memory);
}