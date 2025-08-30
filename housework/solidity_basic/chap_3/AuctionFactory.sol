// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
import "./MyNFT.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// D:\Develop\workspace\smart_contract\solidity_contract\hardhat_test\auction\node_modules\@chainlink\contracts\src\v0.8\shared\interfaces\AggregatorV3Interface.sol
contract AuctionFactory {

    mapping (uint256 tokenId=> address auction) private auctions;
    address myNFTAddress;
    MyNFT myNFT;

    constructor(address NFTAddress) {
        myNFTAddress = NFTAddress;
        myNFT = MyNFT(NFTAddress);
    }

    function createAuction(uint256 tokenId) public {
        address existing = auctions[tokenId];
        // 检查是否有当前tokenId正在进行的拍卖
        if (existing != address(0)) {
            MyAuction oldAuction = MyAuction(existing);
            require(oldAuction.isOver() == true, "Previous auction not ended");
        }
        MyAuction auction = new MyAuction(tokenId, 0, 80 seconds, myNFTAddress);
        myNFT.transferFrom(myNFT.ownerOf(tokenId), address(auction), tokenId);
        auctions[tokenId] = address(auction);
    }

    function getAuction(uint256 tokenId) external view returns (address) {
        return auctions[tokenId];
    }
    
}

contract MyAuction {

    struct Auction {
        uint256 tokenId;
        uint256 startPrice;
        uint256 startTime;
        uint256 endTime;
        uint256 duration;
        address payable owner;
        address highestBidder;
        uint256 highestBid;
        bool isActive;
    }

    struct bidInfo {
        uint256 value;
        address tokenAddress;
    }

    Auction private _auction;
    mapping(address => bidInfo) private pendingReturns;
    mapping (address => AggregatorV3Interface) private aggregators;
    MyNFT myNFT;

    constructor(uint256 tokenId, uint256 startPrice, uint256 duration, address myNFTAddress) {
        myNFT = MyNFT(myNFTAddress);
        _auction.tokenId = tokenId;
        _auction.startPrice = startPrice;
        _auction.startTime = block.timestamp;
        _auction.duration = duration;
        _auction.owner = payable(myNFT.ownerOf(tokenId));
        _auction.highestBidder = myNFT.ownerOf(tokenId);
        _auction.highestBid = startPrice;
        _auction.isActive = true;
        // LINK/USD
        aggregators[0x779877A7B0D9E8603169DdbD7836e478b4624789] = AggregatorV3Interface(0xc59E3633BAAC79493d908e63626716e204A45EdF);
        // ETH/USD
        aggregators[address(0)] = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
    }

    function bid() public payable {
        require(isOver() == false, "auction has ended");
        require(msg.sender != address(0), "Invalid address");
        uint256 biddingUSD = (getUSD(msg.value, address(0)) * 10**18);
        console.log("biddingUSD is:", biddingUSD);
        require(biddingUSD > _auction.highestBid, "Bid not high enough");
        pendingReturns[msg.sender] = bidInfo(
            {
                value: msg.value,
                tokenAddress: address(0)
            }
        );
        _auction.highestBid = biddingUSD;
        _auction.highestBidder = msg.sender;
    }



    function bidToken(uint256 amount, address tokenAddress) public payable {
        require(isOver() == false, "auction has ended");
        require(msg.sender != address(0), "Invalid address");
        uint256 biddingUSD = getUSD(amount, tokenAddress);
        require(biddingUSD > _auction.highestBid, "Bid not high enough");

        // 检查代币类型
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        pendingReturns[msg.sender] = bidInfo(
            {
                value: amount,
                tokenAddress: tokenAddress
            }
        );
        _auction.highestBid = biddingUSD;
        _auction.highestBidder = msg.sender;
    }

    function getUSD(uint256 amount, address tokenAddress) public view returns (uint256) {
        AggregatorV3Interface priceFeed = aggregators[tokenAddress];
        (
            uint80 roundID,
            int256 price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return (amount * uint256(price)) / 10**8;
    }

    function withdraw() external {
        require(isOver(), "auction not ended");
        transfer(msg.sender);

    }

    function isOver() public view returns (bool) {
        return block.timestamp > _auction.startTime + _auction.duration;
    }

    function finalizeAuction() public  {
        require(_auction.isActive, "Auction has already been finalized");
        require(isOver(), "Auction is still ongoing");
        _auction.isActive = false;
        myNFT.transferFrom(address(this), _auction.highestBidder, _auction.tokenId);
        transfer(_auction.highestBidder);

    }

    function transfer(address to) private {
        uint256 amount = pendingReturns[to].value;
        address tokenAddress = pendingReturns[to].tokenAddress;
        require(amount > 0, "No fund to withdraw");
        pendingReturns[to].value = 0;
        if (tokenAddress == address(0)) {
            payable(to).transfer(amount);
        } else {
            IERC20(tokenAddress).transfer(to, amount);
        }
    }

    function getHighestBid() public view returns (uint256) {
        return _auction.highestBid;
    }

    function checkPendingReturns() public view returns (uint256) {
        return pendingReturns[msg.sender].value;
    }
        
}