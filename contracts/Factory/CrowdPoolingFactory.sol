/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;

import {InitializableOwnable} from "../lib/InitializableOwnable.sol";
import {ICloneFactory} from "../lib/CloneFactory.sol";
import {ICP} from "../CrowdPooling/intf/ICP.sol";
import {SafeMath} from "../lib/SafeMath.sol";
import {IERC20} from "../intf/IERC20.sol";
import {DecimalMath} from "../lib/DecimalMath.sol";

contract CrowdPoolingFactory is InitializableOwnable {
    using SafeMath for uint256;
    // ============ Templates ============

    address public immutable _CLONE_FACTORY_;
    address public immutable _CP_TEMPLATE_;
    address public immutable _UNOWNED_DVM_FACTORY_;
    address public immutable _FEE_RATE_MODEL_TEMPLATE_;

    address public immutable _DEFAULT_MAINTAINER_;
    address public immutable _DEFAULT_MT_FEE_RATE_MODEL_;
    address public immutable _DEFAULT_PERMISSION_MANAGER_;
    address public immutable _DEFAULT_GAS_PRICE_SOURCE_;

    uint256 public _X_ = 50; //default
    uint256 public _Y_ = 0; //default
    // ============ Registry ============

    // base -> quote -> CP address list
    mapping(address => mapping(address => address[])) public _REGISTRY_;
    // creator -> CP address list
    mapping(address => address[]) public _USER_REGISTRY_;

    // ============ modifiers ===========
    modifier valueCheck(
        address cpAddress,
        address baseToken,
        uint256[] memory timeLine,
        uint256[] memory valueList)
    {
        require(timeLine[2] == 0,"CP_FACTORY : PHASE_CALM_DURATION_ZERO_ONLY");
        require(timeLine[4] == 0,"CP_FACTORY : VEST_DURATION_ZERO_ONLY");
        require(valueList[1] == 0,"CP_FACTORY : K_ZERO_ONLY");
        require(valueList[3] == DecimalMath.ONE,"CP_FACTORY : CLIFF_RATE_DECIMAL_MATH_ONE_ONLY");

        uint256 baseTokenBalance = IERC20(baseToken).balanceOf(cpAddress);
        require(valueList[0].mul(100) <= baseTokenBalance.mul(valueList[2]).div(10**18).mul(_X_),"CP_FACTORY : QUOTE_CAPE_INVALID");
        require(timeLine[3]>= _Y_,"CP_FACTORY : FREEZE_DURATION_INVALID");
        _;
    }

    // ============ Events ============

    event NewCP(
        address baseToken,
        address quoteToken,
        address creator,
        address cp
    );

    // ============ Functions ============

    constructor(
        address cloneFactory,
        address cpTemplate,
        address unOwnedDvmFactory,
        address feeRateModelTemplate,
        address defaultMaintainer,
        address defaultMtFeeRateModel,
        address defaultPermissionManager,
        address defaultGasPriceSource
    ) public {
        _CLONE_FACTORY_ = cloneFactory;
        _CP_TEMPLATE_ = cpTemplate;
        _UNOWNED_DVM_FACTORY_ = unOwnedDvmFactory;
        _FEE_RATE_MODEL_TEMPLATE_ = feeRateModelTemplate;
        _DEFAULT_MAINTAINER_ = defaultMaintainer;
        _DEFAULT_MT_FEE_RATE_MODEL_ = defaultMtFeeRateModel;
        _DEFAULT_PERMISSION_MANAGER_ = defaultPermissionManager;
        _DEFAULT_GAS_PRICE_SOURCE_ = defaultGasPriceSource;
        _X_ = 50;
        _Y_ = 30 days;
    }

    function createCrowdPooling() external returns (address newCrowdPooling) {
        newCrowdPooling = ICloneFactory(_CLONE_FACTORY_).clone(_CP_TEMPLATE_);
    }

    function initCrowdPooling(
        address cpAddress,
        address creator,
        address baseToken,
        address quoteToken,
        uint256[] memory timeLine,
        uint256[] memory valueList
    ) external valueCheck(cpAddress,baseToken,timeLine,valueList) {
        {
        address[] memory addressList = new address[](7);
        addressList[0] = creator;
        addressList[1] = _DEFAULT_MAINTAINER_;
        addressList[2] = baseToken;
        addressList[3] = quoteToken;
        addressList[4] = _DEFAULT_PERMISSION_MANAGER_;
        addressList[5] = _DEFAULT_MT_FEE_RATE_MODEL_;
        addressList[6] = _UNOWNED_DVM_FACTORY_;

        ICP(cpAddress).init(
            addressList,
            timeLine,
            valueList
        );
        }

        _REGISTRY_[baseToken][quoteToken].push(cpAddress);
        _USER_REGISTRY_[creator].push(cpAddress);

        emit NewCP(baseToken, quoteToken, creator, cpAddress);

        //TODO: 初始存入资金，用于settle补贴
    }

    // ============ View Functions ============

    function getCrowdPooling(address baseToken, address quoteToken)
        external
        view
        returns (address[] memory pools)
    {
        return _REGISTRY_[baseToken][quoteToken];
    }

    function getCrowdPoolingBidirection(address token0, address token1)
        external
        view
        returns (address[] memory baseToken0Pools, address[] memory baseToken1Pools)
    {
        return (_REGISTRY_[token0][token1], _REGISTRY_[token1][token0]);
    }

    function getCrowdPoolingByUser(address user)
        external
        view
        returns (address[] memory pools)
    {
        return _USER_REGISTRY_[user];
    }

    // ============ Owner Functions ============
    function setXY(uint256 x,uint256 y) public onlyOwner {
        require(x>0&&x<=100,"CP_FACTORY : INVALID_X");
        _X_=x;
        _Y_=y;
    }
}