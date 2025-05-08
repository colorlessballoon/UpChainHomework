// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NFTMarket{

    IERC20 public token;
    IERC721 public nft;

    struct Order{
        address seller;
        uint256 tokenId;
        uint256 price;
    }

    mapping(uint256 => Order) public ordersOfId;
    Order[] public orders;
    mapping(uint256 => uint256) public ordersOfIndex;

    event Deal(
        address indexed buyer,
        address indexed seller,
        uint256 tokenId,
        uint256 price
    );

    event NewOrder(
        address indexed seller,
        uint256 tokenId,
        uint256 price
    );

    event PriceChanged(
        address indexed seller,
        uint256 tokenId,
        uint256 oldPrice,
        uint256 newPrice
    );
    event OrderCanceled(
        address indexed seller,
        uint256 tokenId
    );

    constructor(address _token, address _nft){
        require(_token != address(0), "Token address cannot be zero");
        require(_nft != address(0), "NFT address cannot be zero");
        token = IERC20(_token);
        nft = IERC721(_nft);
    }

    function buyNFT(uint256 _tokenId) public{
        address seller = ordersOfId[_tokenId].seller;
        address buyer = msg.sender;
        uint256 price = ordersOfId[_tokenId].price;

        require(token.transferFrom(buyer, seller, price), "Transfer failed");
        nft.safeTransferFrom(address(0), buyer, _tokenId);
        removeOrder(_tokenId);
        emit Deal(buyer, seller, _tokenId, price);
    }

    function cancelOrder(uint256 _tokenId) external{
        address seller = ordersOfId[_tokenId].seller;
        require(msg.sender == seller, "Only seller can cancel order");
        nft.safeTransferFrom(address(0), seller, _tokenId);
        removeOrder(_tokenId);
        emit OrderCanceled(seller, _tokenId);
    }

    function changePrice(uint256 _tokenId, uint256 _price)external{
        address seller = ordersOfId[_tokenId].seller;
        require(msg.sender == seller, "Only seller can change price");
        uint256 oldPrice = ordersOfId[_tokenId].price;
        ordersOfId[_tokenId].price = _price;
        Order storage order = orders[ordersOfIndex[_tokenId]];
        order.price = _price;
        emit PriceChanged(seller, _tokenId, oldPrice, _price);
    }

    function list(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4) {
        uint256 price = toUint256(data, 0);
        require(price > 0, "Price must be greater than zero");
        require(operator == from, "Seller must be the operator");
        orders.push(Order({
            seller: from,
            tokenId: tokenId,
            price: price
        }));
        ordersOfId[tokenId] = orders[orders.length - 1];
        ordersOfIndex[tokenId] = orders.length - 1;
        emit NewOrder(from, tokenId, price);
        return this.list.selector;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        uint256 price = toUint256(data, 0);
        require(price > 0, "Price must be greater than zero");
        require(operator == from, "Seller must be the operator");
        orders.push(Order({
            seller: from,
            tokenId: tokenId,
            price: price
        }));
        ordersOfId[tokenId] = orders[orders.length - 1];
        ordersOfIndex[tokenId] = orders.length - 1;
        emit NewOrder(from, tokenId, price);
        return this.onERC721Received.selector;
    }

    function removeOrder(uint256 _tokenId) internal{
        uint256 index = ordersOfIndex[_tokenId];
        uint256 lastIndex = orders.length - 1;
        if (index != lastIndex) {
            Order storage lastOrder = orders[lastIndex];
            orders[index] = lastOrder;
            ordersOfIndex[lastOrder.tokenId] = index;
        }
        orders.pop();
        delete ordersOfId[_tokenId];
        delete ordersOfIndex[_tokenId];
    }

    function toUint256(bytes memory _bytes, uint256 _start) internal pure returns (uint256) {
        require(_start + 32 >= _start, "toUint256: overflow");
        require(_bytes.length >= _start + 32, "toUint256: out of bounds");
        uint256 tempUint;
        assembly {
            tempUint := mload(add(_bytes, add(0x20, _start)))
        }
        return tempUint;
    }

    function getOrderLength() external view returns (uint256) {
        return orders.length;
    }

    function getAllNFTs() external view returns (Order[] memory) {
        return orders;
    }

    function isListed(uint256 _tokenId) external view returns (bool) {
        return ordersOfId[_tokenId].seller != address(0);
    }

    function tokensReceived(address _buyer, uint256 amount, bytes memory data) external returns (bool) {
        require(msg.sender == address(token), "Only token contract can call this function");
        (uint256 _tokenId) = abi.decode(data, (uint256));
        require(amount >= ordersOfId[_tokenId].price, "Insufficient amount");
        address seller = ordersOfId[_tokenId].seller;
        address buyer = _buyer;
        uint256 price = ordersOfId[_tokenId].price;

        require(token.transferFrom(buyer, seller, price), "Transfer failed");
        nft.safeTransferFrom(address(0), buyer, _tokenId);
        removeOrder(_tokenId);
        emit Deal(buyer, seller, _tokenId, price);
        return true;
    }
    

}