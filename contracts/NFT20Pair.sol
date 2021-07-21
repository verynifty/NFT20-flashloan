pragma solidity ^0.8.0;

// ERC721
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// ERC1155
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./ERC20.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface IFactory {
    function fee() external view returns (uint256);

    function sellTokens() external;

    function flashLoansEnabled() external view returns (bool);
}

interface IFlashLoanReceiver {
    function executeOperation(
        uint256[] calldata _ids,
        uint256[] calldata _amounts,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

contract NFT20Pair is ERC20, IERC721Receiver, ERC1155Receiver {
    address public factory;
    address public nftAddress;
    uint256 public nftType;
    uint256 public nftValue;

    using SafeMath for uint256;
    mapping(uint256 => uint256) public track1155;

    // this is from old store, don't remove
    using EnumerableSet for EnumerableSet.UintSet;
    EnumerableSet.UintSet lockedNfts;

    event Withdraw(uint256[] indexed _tokenIds, uint256[] indexed amounts);

    // create new token
    constructor() public {}

    function init(
        string memory _name,
        string memory _symbol,
        address _nftAddress,
        uint256 _nftType
    ) public payable {
        require(factory == address(0));
        factory = msg.sender;
        nftType = _nftType;
        name = _name;
        symbol = _symbol;
        decimals = 18;
        nftAddress = _nftAddress;
        nftValue = 100 * 10**18;
    }

    modifier flashloansEnabled() {
        require(
            IFactory(factory).flashLoansEnabled(),
            "flashloans not allowed"
        );
        _;
    }

    function getInfos()
        public
        view
        returns (
            uint256 _type,
            string memory _name,
            string memory _symbol,
            uint256 _supply
        )
    {
        _type = nftType;
        _name = name;
        _symbol = symbol;
        _supply = totalSupply.div(nftValue);
    }

    // withdraw nft and burn tokens
    function withdraw(
        uint256[] calldata _tokenIds,
        uint256[] calldata amounts,
        address recipient
    ) external {
        if (nftType == 1155) {
            if (_tokenIds.length == 1) {
                _burn(msg.sender, nftValue.mul(amounts[0]));
                _withdraw1155(
                    address(this),
                    recipient,
                    _tokenIds[0],
                    amounts[0]
                );
            } else {
                _batchWithdraw1155(
                    address(this),
                    recipient,
                    _tokenIds,
                    amounts
                );
            }
        } else if (nftType == 721) {
            _burn(msg.sender, nftValue.mul(_tokenIds.length));
            for (uint256 i = 0; i < _tokenIds.length; i++) {
                _withdraw721(address(this), recipient, _tokenIds[i]);
            }
        }

        emit Withdraw(_tokenIds, amounts);
    }

    function _withdraw1155(
        address _from,
        address _to,
        uint256 _tokenId,
        uint256 value
    ) internal {
        IERC1155(nftAddress).safeTransferFrom(_from, _to, _tokenId, value, "");
    }

    function _batchWithdraw1155(
        address _from,
        address _to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal {
        uint256 qty = 0;
        for (uint256 i = 0; i < ids.length; i++) {
            qty = qty + amounts[i];
        }
        // burn tokens
        _burn(msg.sender, nftValue.mul(qty));

        IERC1155(nftAddress).safeBatchTransferFrom(
            _from,
            _to,
            ids,
            amounts,
            "0x0"
        );
    }

    // WARNING: will be deleted in next update
    function multi721Deposit(uint256[] memory _ids, address _referral) public {
        multi721Deposit(_ids, msg.sender, _referral);
    }

    function multi721Deposit(
        uint256[] memory _ids,
        address _receipient,
        address _referral
    ) public {
        uint256 fee = IFactory(factory).fee();

        for (uint256 i = 0; i < _ids.length; i++) {
            IERC721(nftAddress).transferFrom(
                msg.sender,
                address(this),
                _ids[i]
            );
        }

        address referral = _referral == address(0x0) ? factory : _referral;

        // If referral, give 3% to dao and 2% to referral
        if (
            referral != factory &&
            referral != 0xA42f6cADa809Bcf417DeefbdD69C5C5A909249C0
        ) {
            _mint(factory, (nftValue.mul(_ids.length)).mul(3).div(100));
            _mint(referral, (nftValue.mul(_ids.length)).mul(2).div(100));
        } else {
            _mint(referral, (nftValue.mul(_ids.length)).mul(fee).div(100));
        }

        _mint(
            _receipient,
            (nftValue.mul(_ids.length)).mul(uint256(100).sub(fee)).div(100)
        );
    }

    function swap721(
        uint256 _in,
        uint256 _out,
        address _receipient
    ) external {
        // sell tokens from factory
        IFactory(factory).sellTokens();

        IERC721(nftAddress).transferFrom(msg.sender, address(this), _in);
        IERC721(nftAddress).safeTransferFrom(address(this), _receipient, _out);
    }

    function swap1155(
        uint256[] calldata in_ids,
        uint256[] calldata in_amounts,
        uint256[] calldata out_ids,
        uint256[] calldata out_amounts,
        address _receipient
    ) external {
        IFactory(factory).sellTokens();

        uint256 ins;
        uint256 outs;

        for (uint256 i = 0; i < out_ids.length; i++) {
            ins = ins.add(in_amounts[i]);
            outs = outs.add(out_amounts[i]);
        }

        require(ins == outs, "Need to swap same amount of NFTs");

        IERC1155(nftAddress).safeBatchTransferFrom(
            address(this),
            _receipient,
            out_ids,
            out_amounts,
            "0x0"
        );
        IERC1155(nftAddress).safeBatchTransferFrom(
            msg.sender,
            address(this),
            in_ids,
            in_amounts,
            "INTERNAL"
        );
    }

    function _withdraw721(
        address _from,
        address _to,
        uint256 _tokenId
    ) internal {
        IERC721(nftAddress).safeTransferFrom(_from, _to, _tokenId);
    }

    function onERC721Received(
        address operator,
        address,
        uint256,
        bytes memory data
    ) public virtual override returns (bytes4) {
        require(nftAddress == msg.sender, "forbidden");
        uint256 fee = IFactory(factory).fee();

        (address referral, address recipient) = decodeParams(data, operator);

        if (
            referral != factory &&
            referral != 0xA42f6cADa809Bcf417DeefbdD69C5C5A909249C0
        ) {
            _mint(factory, nftValue.mul(3).div(100));
            _mint(referral, nftValue.mul(2).div(100));
        } else {
            _mint(referral, nftValue.mul(fee).div(100));
        }

        _mint(recipient, nftValue.mul(uint256(100).sub(fee)).div(100));
        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address operator,
        address,
        uint256,
        uint256 value,
        bytes memory data
    ) public virtual override returns (bytes4) {
        require(nftAddress == msg.sender, "forbidden");
        if (keccak256(data) != keccak256("INTERNAL")) {
            uint256 fee = IFactory(factory).fee();

            (address referral, address recipient) = decodeParams(
                data,
                operator
            );

            if (
                referral != factory &&
                referral != 0xA42f6cADa809Bcf417DeefbdD69C5C5A909249C0
            ) {
                _mint(factory, (nftValue.mul(value)).mul(3).div(100));
                _mint(referral, (nftValue.mul(value)).mul(2).div(100));
            } else {
                _mint(referral, (nftValue.mul(value)).mul(fee).div(100));
            }

            _mint(
                recipient,
                (nftValue.mul(value)).mul(uint256(100).sub(fee)).div(100)
            );
        }
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public virtual override returns (bytes4) {
        require(nftAddress == msg.sender, "forbidden");
        if (keccak256(data) != keccak256("INTERNAL")) {
            uint256 qty = 0;

            for (uint256 i = 0; i < ids.length; i++) {
                qty = qty + values[i];
            }
            uint256 fee = IFactory(factory).fee();

            (address referral, address recipient) = decodeParams(
                data,
                operator
            );

            if (
                referral != factory &&
                referral != 0xA42f6cADa809Bcf417DeefbdD69C5C5A909249C0
            ) {
                _mint(factory, (nftValue.mul(qty)).mul(3).div(100));
                _mint(referral, (nftValue.mul(qty)).mul(2).div(100));
            } else {
                _mint(referral, (nftValue.mul(qty)).mul(fee).div(100));
            }
            _mint(
                recipient,
                (nftValue.mul(qty)).mul(uint256(100).sub(fee)).div(100)
            );
        }
        return this.onERC1155BatchReceived.selector;
    }

    // set new params
    function setParams(
        uint256 _nftType,
        string calldata _name,
        string calldata _symbol,
        uint256 _nftValue
    ) external {
        require(msg.sender == factory, "!authorized");
        nftType = _nftType;
        name = _name;
        symbol = _symbol;
        nftValue = _nftValue;
    }

    function bytesToAddress(bytes memory data)
        private
        pure
        returns (address addr)
    {
        bytes memory b = data;
        assembly {
            addr := mload(add(b, 20))
        }
    }

    function toAddress(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (address)
    {
        address tempAddress;

        assembly {
            tempAddress := div(
                mload(add(add(_bytes, 0x20), _start)),
                0x1000000000000000000000000
            )
        }

        return tempAddress;
    }

    function decodeParams(bytes memory data, address defaultRecipient)
        public
        view
        returns (address, address)
    {
        uint256 n = data.length;
        address referal = factory;
        address recipient = defaultRecipient;

        if (n >= 20) {
            referal = toAddress(data, 0);
        }
        if (n >= 40) {
            recipient = toAddress(data, 20);
        }
        return (referal, recipient);
    }

    function flashLoan(
        uint256[] calldata _ids,
        uint256[] calldata _amounts,
        address _operator,
        bytes calldata _params
    ) external flashloansEnabled() {
        require(_ids.length < 80, "To many NFTs");

        if (nftType == 1155) {
            IERC1155(nftAddress).safeBatchTransferFrom(
                address(this),
                _operator,
                _ids,
                _amounts,
                "0x0"
            );
        } else {
            for (uint8 index; index < _ids.length; index++) {
                IERC721(nftAddress).safeTransferFrom(
                    address(this),
                    _operator,
                    _ids[index]
                );
            }
        }
        require(
            IFlashLoanReceiver(_operator).executeOperation(
                _ids,
                _amounts,
                msg.sender,
                _params
            ),
            "Execution Failed"
        );

        if (nftType == 1155) {
            IERC1155(nftAddress).safeBatchTransferFrom(
                _operator,
                address(this),
                _ids,
                _amounts,
                "INTERNAL"
            );
        } else {
            for (uint8 index; index < _ids.length; index++) {
                IERC721(nftAddress).transferFrom(
                    _operator,
                    address(this),
                    _ids[index]
                );
            }
        }
    }
}
