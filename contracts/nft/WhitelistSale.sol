pragma solidity ^0.6.0;

import "@openzeppelin/contracts/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
//游戏道具
contract WhitelistSale is ERC721, Ownable {
    bytes32 public merkleRoot;
    uint256 public nextTokenId;
    mapping(uint256 => bool) public claimed;

    event Minted(
        uint256[] ids,
        uint256[] txId,
        address to
    );
    event Burned(
        uint256 id,
        uint256 txId,
        address to
    );
    constructor() public ERC721("NFT", "NFT") {
        // merkleRoot = _merkleRoot;
    }

    function setRoot(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function mint(bytes32[] calldata merkleProof, uint256[] memory txIds) public payable {
        require(claimed[txIds[0]] == false, "already claimed");
        require(MerkleProof.verify(merkleProof, merkleRoot, keccak256(abi.encodePacked(msg.sender, txIds.length))), "invalid merkle proof");
        uint256[] memory ids = new uint256[](txIds.length);
        for (uint256 i = 0; i < txIds.length; i++) {
            nextTokenId++;
            _mint(msg.sender, nextTokenId);
            ids[i] = nextTokenId;
            claimed[txIds[i]] = true;
        }

        emit Minted(ids, txIds, msg.sender);
    }


    function burn(uint256 tokenId, uint256 id) public {

        address owner = ERC721.ownerOf(tokenId);
        require(_msgSender() == owner, "caller is not the token owner");
        _burn(tokenId);

        emit Burned(tokenId, id, msg.sender);
    }

}