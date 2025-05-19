// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/NFTMarket.sol";
import "../src/MyNFT.sol";
import "../src/MyToken.sol";

contract NFTMarketTest is Test {
    NFTMarket market;
    MyNFT nft;
    MyToken token;
    
    address seller = address(0x1);
    address buyer = address(0x2);
    uint256 tokenId = 1;
    uint256 price = 100;
    
    function setUp() public {
        // 部署合约
        token = new MyToken();
        nft = new MyNFT(address(this));
        market = new NFTMarket(address(token), address(nft));
        
        // 为卖家铸造并授权 NFT
        nft.safeMint(seller, tokenId, "testURI");
        vm.prank(seller);
        nft.approve(address(market), tokenId);
        
        
    }

    function testListNFT() public {
        // 测试上架成功
        vm.startPrank(seller);
        market.listNFT(tokenId, price);
        
        assertTrue(market.isListed(tokenId));
        assertEq(market.getPrice(tokenId), price);
        assertEq(nft.ownerOf(tokenId), address(market));
        
        vm.stopPrank();
        
        // 测试价格为0上架失败
        uint256 newTokenId = 2;
        nft.safeMint(seller, newTokenId, "testURI2");
        vm.startPrank(seller);
        nft.approve(address(market), newTokenId);
        vm.expectRevert("Price must be greater than 0");
        market.listNFT(newTokenId, 0);
        vm.stopPrank();
        
        // 测试未授权上架失败
        uint256 tokenId3 = 3;
        nft.safeMint(seller, tokenId3, "testURI3");
        vm.startPrank(seller);
        vm.expectRevert("Market not approved");
        market.listNFT(tokenId3, price);
        vm.stopPrank();
    }

    function testBuyNFT() public {

        vm.prank(address(this));
        token.transfer(buyer, 999999999);
        // 上架NFT
        vm.prank(seller);
        market.listNFT(tokenId, price);
        
        // 测试购买成功
        vm.startPrank(buyer);
        
        token.approve(address(market), price);
        market.buyNFT(tokenId);
        
        assertEq(nft.ownerOf(tokenId), buyer);
        assertFalse(market.isListed(tokenId));
        assertEq(token.balanceOf(seller), price);
        vm.stopPrank();
        
        // 测试购买不存在的NFT
        vm.expectRevert("NFT not listed");
        market.buyNFT(999);
        
        // 测试购买自己的NFT
        uint256 newTokenId = 2;
        nft.safeMint(buyer, newTokenId, "testURI2");
        vm.startPrank(buyer);
        nft.approve(address(market), newTokenId);
        market.listNFT(newTokenId, price);
        
        vm.expectRevert("Cannot buy your own NFT");
        market.buyNFT(newTokenId);
        vm.stopPrank();
    }

    function testFuzzBuyNFT(uint256 fuzzPrice) public {
        // 限制价格范围在 0.01-10000 token
        vm.assume(fuzzPrice >= 1  && fuzzPrice <= 10000 );
        
        // 上架NFT
        vm.startPrank(seller);
        market.listNFT(tokenId, fuzzPrice);
        vm.stopPrank();
        
        // 确保买家有足够的代币
        token.transfer(buyer, fuzzPrice);
        
        // 购买NFT
        vm.startPrank(buyer);
        token.approve(address(market), fuzzPrice);
        market.buyNFT(tokenId);
        
        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), fuzzPrice);
        vm.stopPrank();
    }

    

}