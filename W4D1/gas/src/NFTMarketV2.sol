// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract NFTMarketV2 is IERC721Receiver {
    // 状态变量 - 使用更紧凑的布局
    IERC721 public immutable nft;   // NFT合约
    IERC20 public immutable token;  // 支付代币

    // 订单结构 - 优化存储布局
    struct Order {
        uint128 price;    // 使用uint128而不是uint256，因为价格通常不会超过2^128
        address seller;   // 将address放在uint128后面，可以节省一个存储槽
    }

    // 订单映射: tokenId => Order
    mapping(uint256 => Order) public orders;

    // 事件 - 优化事件参数顺序，将indexed参数放在前面
    event Listed(uint256 indexed tokenId, address indexed seller, uint128 price);
    event Sold(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint128 price);

    // 常量 - 使用immutable减少gas
    bytes4 private constant ERC721_RECEIVED = IERC721Receiver.onERC721Received.selector;

    constructor(address _token, address _nft) {
        require(_token != address(0) && _nft != address(0), "Invalid address");
        token = IERC20(_token);
        nft = IERC721(_nft);
    }

    // 上架NFT - 优化gas
    function listNFT(uint256 tokenId, uint128 price) external {
        require(price > 0, "Price must be greater than 0");
        require(nft.ownerOf(tokenId) == msg.sender, "Not NFT owner");
        require(nft.getApproved(tokenId) == address(this), "Market not approved");

        // 转移NFT到市场合约
        nft.transferFrom(msg.sender, address(this), tokenId);
        
        // 创建订单 - 使用更紧凑的结构
        orders[tokenId] = Order(price, msg.sender);

        emit Listed(tokenId, msg.sender, price);
    }

    // 购买NFT - 优化gas
    function buyNFT(uint256 tokenId) external {
        Order memory order = orders[tokenId];
        require(order.seller != address(0), "NFT not listed");
        require(order.seller != msg.sender, "Cannot buy your own NFT");

        // 处理支付
        require(token.transferFrom(msg.sender, order.seller, order.price), "Payment failed");
        
        // 转移NFT
        nft.transferFrom(address(this), msg.sender, tokenId);
        
        // 删除订单
        delete orders[tokenId];

        emit Sold(tokenId, msg.sender, order.seller, order.price);
    }

    // 查询NFT是否在售 - 优化gas
    function isListed(uint256 tokenId) external view returns (bool) {
        return orders[tokenId].seller != address(0);
    }

    // 查询NFT价格 - 优化gas
    function getPrice(uint256 tokenId) external view returns (uint128) {
        require(orders[tokenId].seller != address(0), "NFT not listed");
        return orders[tokenId].price;
    }

    // 实现 IERC721Receiver 接口 - 优化gas
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        require(msg.sender == address(nft), "Only accept NFT contract");
        require(operator == from, "Operator must be the sender");
        
        if (data.length > 0) {
            uint128 price = abi.decode(data, (uint128));
            require(price > 0, "Price must be greater than 0");
            
            orders[tokenId] = Order(price, from);
            emit Listed(tokenId, from, price);
        }
        
        return ERC721_RECEIVED;
    }

    // 优化tokensReceived函数
    function tokensReceived(
        address _buyer,
        uint128 price,
        bytes memory data
    ) external returns (bool) {
        require(msg.sender == address(token), "Only token contract can call this function");
        
        uint256 _tokenId = abi.decode(data, (uint256));
        Order memory order = orders[_tokenId];
        
        require(order.seller != address(0), "NFT not listed");
        require(order.seller != _buyer, "Cannot buy your own NFT");
        require(order.price == price, "Incorrect payment amount");
        
        nft.transferFrom(address(this), _buyer, _tokenId);
        delete orders[_tokenId];
        
        emit Sold(_tokenId, _buyer, order.seller, price);
        
        return true;
    }
} 