pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "../interfaces/INFT20Pair.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../interfaces/IFlashLoanReceiver.sol";

import "hardhat/console.sol";

contract NFTFlashloan is IFlashLoanReceiver, IERC721Receiver {
    IERC721 public constant HASHMASK =
        IERC721(0xC2C747E0F7004F9E8817Db2ca4997657a7746928);
    INFT20Pair public constant MASK20 =
        INFT20Pair(0xc2BdE1A2fA26890c8E6AcB10C91CC6D9c11F4a73);

    constructor() public {
        HASHMASK.setApprovalForAll(address(MASK20), true); //must approve nft20 pair contract for spending
    }

    function executeOperation(
        uint256[] calldata _ids,
        uint256[] calldata _amounts,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        console.log("here");
        // Do stuff with the tokens nft ids
        for (uint256 i = 0; i < _ids.length; i++) {
            //   do something with nfts but you must return them to the same amount of nfts to contract after

            console.log(_ids[i]);
        }
        return true;
    }

    function onERC721Received(
        address operator,
        address,
        uint256,
        bytes memory data
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
