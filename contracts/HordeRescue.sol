// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract HordeRescue is Ownable, ERC721Enumerable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    using Strings for uint256;

    address public horde;
    address public pool;
    uint256 public price;
    uint256 public acLimit;
    uint256 public totalLimit;

    bool private PAUSE = true;

    Counters.Counter private _tokenIdTracker;

    string public baseTokenURI;

    bool public META_REVEAL = false;
    uint256 public HIDE_FROM = 1;
    uint256 public HIDE_TO = 5000;
    string public sampleTokenURI;

    uint256 private royaltiesFees;

    event PauseEvent(bool pause);
    event welcomeToHordeRescue(uint256 indexed id);
    event NewPriceEvent(uint256 prices);
    event NewLimitEvent(uint256 limits);
    event NewHordeEvent(address horde);
    event NewPoolEvent(address pool);

    constructor(string memory baseURI) ERC721("HordeRescue", "RESCUE") {
        setBaseURI(baseURI);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    modifier saleIsOpen() {
        require(totalToken() < totalLimit, "Soldout!");
        require(!PAUSE, "Sales not open");
        _;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    function setSampleURI(string memory sampleURI) public onlyOwner {
        sampleTokenURI = sampleURI;
    }

    function totalToken() public view returns (uint256) {
        return _tokenIdTracker.current();
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (!META_REVEAL && tokenId >= HIDE_FROM && tokenId <= HIDE_TO)
            return sampleTokenURI;

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json"))
                : "";
    }

    function mint() 
        public 
        saleIsOpen
    {
        require(IERC20(horde).balanceOf(msg.sender) >= price, "Not enough balance!");
        require(balanceOf(msg.sender) < acLimit, "Out of limit!");
        IERC20(horde).transferFrom(msg.sender, pool, price);
        
        _tokenIdTracker.increment();
        uint256 tokenId = totalToken();
        _safeMint(msg.sender, tokenId);
        emit welcomeToHordeRescue(tokenId);
    }

     /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address to,
        uint256 tokenId
    ) public {
        require(balanceOf(to) < acLimit, "Out of limit!");
        super.transferFrom(msg.sender, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address to,
        uint256 tokenId
    ) public {
        require(balanceOf(to) < acLimit, "Out of limit!");
        super.safeTransferFrom(msg.sender, to, tokenId, "");
    }

    function walletOfOwner(address _owner)
        external
        view
        returns (uint256[] memory)
    {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return tokensId;
    }

    function setPause(bool _pause) public onlyOwner {
        PAUSE = _pause;
        emit PauseEvent(PAUSE);
    }

    function setPrice(uint256 _price) public onlyOwner {
        price = _price;
        emit NewPriceEvent(price);
    }

    function setAccountLimit(uint256 _acLimit) public onlyOwner {
        acLimit = _acLimit;
        emit NewLimitEvent(acLimit);        
    }

    function setTotalLimit(uint256 _totalLimit) public onlyOwner {
        totalLimit = _totalLimit;
        emit NewLimitEvent(totalLimit);        
    }

    function setHorde(address _horde) public onlyOwner {
        horde = _horde;
        emit NewHordeEvent(horde);
    }

    function setPool(address _pool) public onlyOwner {
        pool = _pool;
        emit NewPoolEvent(pool);
    }

    function setMetaReveal(
        bool _reveal,
        uint256 _from,
        uint256 _to
    ) public onlyOwner {
        META_REVEAL = _reveal;
        HIDE_FROM = _from;
        HIDE_TO = _to;
    }
}
