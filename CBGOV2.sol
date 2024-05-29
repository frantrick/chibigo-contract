// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "erc721a-upgradeable/contracts/ERC721AUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

error IncorrectPrice(uint256 expected, uint256 actual);
error ContractPaused();
error WrongPaperAddress();

contract CBGOV2 is ERC721AUpgradeable, OwnableUpgradeable, ERC2981Upgradeable {
    using Address for address payable;
    address public constant TREASURY_MARKETPLACE_ADDRESS =
        0x307c1118E09f77EE2460E2C828d404b87414739A;
    uint256 public edition;
    uint256 private totalMinted;
    uint256 private currentId;
    bool public paused;
    address public _treasuryAddress;
    string internal cUri;

    mapping(uint16 => uint256) public offers;

    event _SendToCycle(
        uint256 edition,
        uint256 quantity,
        uint256 currentId,
        address wallet
    );

    event _OfferUpgraded(uint16[] quantities, uint256[] prices);
    event _AirdropToCycle(
        uint256 edition,
        uint256 currentId,
        address[] recipients,
        uint16[] quantities
    );

    function initialize() public initializerERC721A initializer {
        edition = 1;
        paused = false;
        _treasuryAddress = 0xe2bfccfe63737c3B6258B06E5d90585dc73ed63F;
        __ERC721A_init("CBGOV2", "CBGO");
        __Ownable_init();
        _setDefaultRoyalty(TREASURY_MARKETPLACE_ADDRESS, 500);
        totalMinted = 0;
        cUri = "";
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier checkPrice(uint16 _quantity) {
        require(offers[_quantity] > 0, "offer not found");
        if (msg.value != offers[_quantity])
            revert IncorrectPrice(msg.value, offers[_quantity]);
        _;
    }

    function sendToCycle(
        uint256 currentEdition,
        uint256 quantity,
        address _wallet
    ) private {
        emit _SendToCycle(currentEdition, quantity, currentId, _wallet);
    }

    function airdropCycle(
        uint256 specialEdition,
        address[] calldata recipients,
        uint16[] calldata quantities
    ) private {
        emit _AirdropToCycle(specialEdition, currentId, recipients, quantities);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC721AUpgradeable, ERC2981Upgradeable)
        returns (bool)
    {
        return
            ERC721AUpgradeable.supportsInterface(interfaceId) ||
            ERC2981Upgradeable.supportsInterface(interfaceId);
    }

    function updateCurrentId(uint256 _quantity) private {
        currentId = _totalMinted() + _quantity;
    }

    function mint(
        address to,
        uint8 quantity
    ) public payable whenNotPaused checkPrice(quantity) {
        updateCurrentId(quantity);
        _mint(to, quantity);
        (bool success, ) = _treasuryAddress.call{value: msg.value}("");
        require(success, "Transfer failed");

        sendToCycle(edition, quantity, to);
    }

    function adminMint(
        uint256 quantity,
        uint256 adminEdition
    ) external onlyOwner {
        updateCurrentId(quantity);
        _mint(msg.sender, quantity);
        sendToCycle(adminEdition, quantity, _msgSender());
    }

    function getTotalMinted() external onlyOwner returns (uint256) {
        totalMinted = _totalMinted();
        return totalMinted;
    }

    function setPaused(bool _state) external onlyOwner {
        paused = _state;
    }

    function setEdition(uint256 _edition) external onlyOwner {
        edition = _edition;
    }

    function setTreasuryAddress(
        address treasuryAddress
    ) public virtual onlyOwner {
        _treasuryAddress = treasuryAddress;
    }

    function setOffers(
        uint16[] memory quantities,
        uint256[] memory prices
    ) public onlyOwner {
        require(quantities.length == prices.length, "invalid number of items");

        for (uint i = 0; i < quantities.length; i++) {
            offers[quantities[i]] = prices[i];
        }

        emit _OfferUpgraded(quantities, prices);
    }

    function transferGas() public payable {
        (bool sent, ) = _treasuryAddress.call{value: msg.value}("");
        require(sent, "Failed to send Token");
    }

    function setContractURI(string memory _contractURI) public onlyOwner {
        cUri = _contractURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return cUri;
    }

    function airdrop(
        address[] calldata recipients,
        uint16[] calldata quantities,
        uint256 specialEdition
    ) public onlyOwner {
        require(
            recipients.length == quantities.length,
            "both arrays must be equals"
        );
        for (uint256 i = 0; i < recipients.length; i++) {
            updateCurrentId(quantities[i]);
            _mint(recipients[i], quantities[i]);
        }
        airdropCycle(specialEdition, recipients, quantities);
    }
}
