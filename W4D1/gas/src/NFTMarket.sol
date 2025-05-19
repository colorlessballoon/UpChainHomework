// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
contract NFTMarket is IERC721Receiver {
    // 状态变量
    IERC20 public immutable token;  // 支付代币
    IERC721 public immutable nft;   // NFT合约

    // 订单结构
    struct Order {
        address seller;    // 卖家地址
        uint256 price;    // 售价
    }

    // 订单映射: tokenId => Order
    mapping(uint256 => Order) public orders;

    // 事件
    event Listed(address indexed seller, uint256 tokenId, uint256 price);
    event Sold(address indexed buyer, address indexed seller, uint256 tokenId, uint256 price);

    // 构造函数
    constructor(address _token, address _nft) {
        require(_token != address(0), "Invalid token address");
        require(_nft != address(0), "Invalid NFT address");
        token = IERC20(_token);
        nft = IERC721(_nft);
    }

    // 上架NFT
    function listNFT(uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than 0");
        require(nft.ownerOf(tokenId) == msg.sender, "Not NFT owner");
        require(nft.getApproved(tokenId) == address(this), "Market not approved");

        // 转移NFT到市场合约
        nft.transferFrom(msg.sender, address(this), tokenId);
        
        // 创建订单
        orders[tokenId] = Order({
            seller: msg.sender,
            price: price
        });

        emit Listed(msg.sender, tokenId, price);
    }

    // 购买NFT
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

        emit Sold(msg.sender, order.seller, tokenId, order.price);
    }

    // 查询NFT是否在售
    function isListed(uint256 tokenId) external view returns (bool) {
        return orders[tokenId].seller != address(0);
    }

    // 查询NFT价格
    function getPrice(uint256 tokenId) external view returns (uint256) {
        require(orders[tokenId].seller != address(0), "NFT not listed");
        return orders[tokenId].price;
    }

    // 实现 IERC721Receiver 接口
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        // 验证调用者是否为 NFT 合约
        require(msg.sender == address(nft), "Only accept NFT contract");
        require(operator == from, "Operator must be the sender");
        // 如果有 data，解析价格并创建订单
        if (data.length > 0) {
            uint256 price = abi.decode(data, (uint256));
            require(price > 0, "Price must be greater than 0");
            
            // 创建订单
            orders[tokenId] = Order({
                seller: from,
                price: price
            });

            emit Listed(from, tokenId, price);
        }
        
        return IERC721Receiver.onERC721Received.selector;
    }

    function tokensReceived(
        address _buyer,
        uint256 price,
        bytes memory data
    ) external returns (bool) {
        // 验证调用者是否为支付代币合约
        require(msg.sender == address(token), "Only token contract can call this function");
        
        // 解码参数获取 tokenId
        uint256 _tokenId = abi.decode(data, (uint256));
        
        // 获取订单信息
        Order memory order = orders[_tokenId];
        require(order.seller != address(0), "NFT not listed");
        require(order.seller != _buyer, "Cannot buy your own NFT");
        require(order.price == price, "Incorrect payment amount");
        
        // 转移 NFT 给买家
        nft.transferFrom(address(this), _buyer, _tokenId);
        
        // 删除订单
        delete orders[_tokenId];
        
        // 触发销售事件
        emit Sold(_buyer, order.seller, _tokenId, price);
        
        return true;
    }
}