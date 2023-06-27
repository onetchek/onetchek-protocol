//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/metatx/MinimalForwarder.sol";
import {
    ERC2771Context
} from "@gelatonetwork/relay-context/contracts/vendor/ERC2771Context.sol";


interface ILendingPool {
  function supply(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) external;

  function withdraw(
    address asset,
    uint256 amount,
    address to
  ) external returns (uint256);

  function borrow(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    uint16 referralCode,
    address onBehalfOf
  ) external;

  function repay(
    address asset,
    uint256 amount,
    uint256 rateMode,
    address onBehalfOf
  ) external returns (uint256);
}


contract StableMarketGasless is ERC2771Context, ReentrancyGuard {
      
    using SafeMath for uint256;

    //External Protocol 
    IUniswapV2Router02 public uniswapRouter = IUniswapV2Router02(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);
    ILendingPool       public lendingPool   = ILendingPool(0xE43e60736b1cb4a75ad25240E2f9a62Bff65c0C0);

    //Wallet manager
    address public owner;
    address public masterTax;
    bool    public isPause = false;

    //Token address
    address private MATIC_ADDRESS = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270; // USDT mainnet address
    address private AAVE_USDT_ADDRESS = 0x6ab707Aca953eDAeFBc4fD23bA73294241490620; // USDT mainnet address
    IERC20  public validStablecoin;


   //Enum
    enum TradeStatus { Created, Taken, Paid, Paused, Closed, Canceled, Locked }
    enum TradeType { Bid, Ask }


    //Access control
    mapping(address => bool) public admins;
    mapping(address => bool) public managers;
    mapping(address => bool) public assistants;

    //Fee management
    mapping(address => uint256) public membersFee;
    mapping(address => uint256) public sellersFee;
    mapping(address => uint256) public affilliatesReward;

    // USD reserve
    uint256 public reserve;

    //Fees 
    uint256 public buyerFee = 3;
    uint256 public sellerFee = 3;
    uint256 public affiliateFee =  10;

     uint256 public exchangeFee = 200000;
     uint256 public withdrawFee = 100000;

     uint256 public cancelBidFee = 50000;
     uint256 public cancelAskFee = 1000000;


    

    struct AcceptStable {
        address  addr;
        uint256 reserve;
    }

     struct History {
        uint256  id;
        address  user;
        uint256   date;
        uint256  amount;
        TradeType tradeType;
    }

    struct Trade {
        uint256 idTr;
        uint id;
        address  owner;
        uint256 amount;
        uint256 initAmount;
        uint256 rate;
        bool isActive;
        TradeStatus status;
        string history;
        TradeType tradeType;
        address stable;

    }

    Trade[] public trades;

    History[] public histories;


    mapping(address => AcceptStable) public acceptStables;



    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  

    constructor(address _validStablecoin,address trustedForwarder) ERC2771Context(address(trustedForwarder)){
       
        owner = _msgSender();
        admins[owner] = true;
        managers[owner] = true;
        assistants[owner] = true;
        membersFee[owner] = 0;
        sellersFee[owner] = 0;

        masterTax = owner;
   

        validStablecoin = IERC20(_validStablecoin);
    }

    
     ///////////////////////////////////////////Modifiers///////////////////////////////////////////////////////////////////////////////////////////////////////////
  
    modifier onlyOwner {
        require(_msgSender() == owner, "Only contract owner can call this function");
        _;
    }
    
    modifier onlyAdmin() {
        require(admins[_msgSender()], "Only admins can call this function");
        _;
    }

    modifier onlyManager() {
        require(managers[_msgSender()], "Only manager can call this function");
        _;
    }

    modifier onlyAssistant() {
        require(assistants[_msgSender()], "Only assistant can call this function");
        _;
    }

    modifier whenNotPaused()  {
        require(isPause == false, "Contract has been pause");
        _;
    }

    modifier whenPaused() {
        require(isPause == true, "Contract has been unpause");
        _;
    }

    
    /////////////////////////////////////////////////Local Stablecoin management/////////////////////////////////////////////////////////////////////////////////////////////////////
  

    function addStable(address _stable) public onlyOwner {
        acceptStables[_stable] = AcceptStable({addr:_stable, reserve:0});
    }

    function removeStable( address _stable) public onlyOwner {
       delete acceptStables[_stable];
    }


    ////////////////////////////////////////////////////Roles management//////////////////////////////////////////////////////////////////////////////////////////////////

    function addAdmin(address _admin) public onlyOwner {
        admins[_admin] = true;
    }

    function removeAdmin(address _admin) public onlyOwner {
       delete admins[_admin];
    }


    function addManager(address _manager) public onlyOwner onlyAdmin {
        managers[_manager] = true;
    }

    function removeManager(address _manager) public onlyOwner onlyAdmin{
       delete managers[_manager];
    }


    function addAssistant(address _assistant) public onlyOwner onlyAdmin {
        assistants[_assistant] = true;
    }

    function removeAssistant(address _assistant) public onlyOwner onlyAdmin{
       delete assistants[_assistant];
    }


  ////////////////////////////////////////////////////Fees management//////////////////////////////////////////////////////////////////////////////////////////////////


    function setMemberFee(address _member, uint256 _fee) public onlyOwner onlyAdmin onlyManager {
        if(_fee>0){
        membersFee[_member] = _fee;
        }else{
          delete membersFee[_member];  
        }
    }

    function setSellerFee(address _seller, uint256 _fee) public onlyOwner onlyAdmin onlyManager {
        sellersFee[_seller] = _fee;
        if(_fee>0){
         sellersFee[_seller] = _fee;
        }else{
          delete  sellersFee[_seller];  
        }
    }

    function setAffilliatesReward(address _affialte, uint256 _reward) public onlyOwner onlyAdmin onlyManager {
        if(_reward>0){
         affilliatesReward[_affialte] = _reward;
        }else{
          delete  affilliatesReward[_affialte];  
        }
    }


    /////////////////////////////////////////External protocol management/////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function changeLendingPool(address lendingPool_) public onlyOwner returns (bool) {
        lendingPool = ILendingPool(lendingPool_);
        return true;
    }

     function changeUniswapRouter(address router_) public onlyOwner returns (bool) {
        uniswapRouter = IUniswapV2Router02(router_);
        return true;
    }

   
    /////////////////////////////////////////Tax management/////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function changeOfferFee(uint256 _percent) public onlyOwner onlyAdmin returns (bool) {
        require(_percent >=0 && _percent <=10 , "percent  can't be less than null");
        buyerFee = _percent;
        return true;
    }

    function changeTaxAff(uint256 _affiliateFee) public onlyOwner onlyAdmin returns (bool) {
        require(affiliateFee >=0 && affiliateFee <=20, "percent  can't be less than null");
        affiliateFee = _affiliateFee;
        return true;
    }

   
    function changeMasterTaxAddress(address _masterTax) public onlyOwner returns (bool) {
        require(_masterTax != address(0) , "TAX ADDRESS can't be null");
        masterTax = _masterTax;
        return true;
    }

    function changeExhangeTax(uint256 _exchangeFee) public onlyOwner returns (bool) {
        require(_exchangeFee >= 0 && _exchangeFee <= 1000000 , "TAX most be more or equal to  0USDT and less or equal to 1USDT ");
        exchangeFee = _exchangeFee;
        return true;
    }

    function changewithdrawFee(uint256 _withdrawFee) public onlyOwner returns (bool) {
        require(_withdrawFee >= 0 && _withdrawFee <= 500000 , "TAX most be more or equal to  0USDT and less or equal to 0.5 USDT ");
        withdrawFee = _withdrawFee;
        return true;
    }


    ///////////////////////////////////////Mecanist to stop///////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function pause() public onlyOwner onlyAdmin {
        isPause = true;
    }

    function unpause() public onlyOwner onlyAdmin {
         isPause = false;
    }

 
    ///////////////////////////////////////////Stable Market modules///////////////////////////////////////////////////////////////////////////////////////////////////////////

    function bidOffer(
        uint256 idTr,
        uint256 _amount,
        uint256 _rate,
        address _stable
    ) public whenNotPaused nonReentrant returns(bool) {

        Trade memory tradeCheck = getOneTrade(idTr);
      
        if(tradeCheck.rate>0){
            return false;
        }

        uint count = trades.length;
       
        require(_rate > 0 , "Rate is not correct");
        require(_amount > 0 , "Amount is not correct");
    
        uint256 allowance = validStablecoin.allowance(_msgSender(), address(this));
        uint256 balance = validStablecoin.balanceOf(_msgSender());

        require(allowance >= _amount, "Check the token allowance");
        require(balance >= _amount, "Check the token balance");
      

        validStablecoin.transferFrom(_msgSender(), address(this), _amount);

        reserve = reserve.add(_amount);
        
       
        trades.push(
            Trade({
                idTr: idTr,
                id: count,
                owner:  _msgSender(),
                amount: _amount,
                initAmount: _amount,
                rate: _rate,
                isActive: true,
                status: TradeStatus.Created,
                history: "",
                tradeType:TradeType.Bid,
                stable:_stable
            })
        );

        return true;
    }


    function askOffer(
        uint256 idTr,
        uint256 _amount,
        uint256 _rate,
        address _stable
    ) public whenNotPaused nonReentrant returns(bool) {

        Trade memory tradeCheck = getOneTrade(idTr);
      
        if(tradeCheck.rate>0){
            return false;
        }

        uint count = trades.length;
       
        require(_rate > 0 , "Rate is not correct");
        require(_amount > 0 , "Amount is not correct");
    
        uint256 allowance = IERC20(_stable).allowance(_msgSender(), address(this));
        uint256 balance = IERC20(_stable).balanceOf(_msgSender());

        require(allowance >= _amount, "Check the token allowance");
        require(balance >= _amount, "Check the token balance");
      

        IERC20(_stable).transferFrom(_msgSender(), address(this), _amount);

        acceptStables[_stable].reserve = acceptStables[_stable].reserve.add(_amount);
        
       
        trades.push(
            Trade({
                idTr: idTr,
                id: count,
                owner: _msgSender(),
                amount: _amount,
                initAmount: _amount,
                rate: _rate,
                isActive: true,
                status: TradeStatus.Created,
                history: "",
                tradeType:TradeType.Ask,
                stable:_stable
            })
        );

        return true;
    }

    function updateBidOffer(uint256 _tradeId,  uint256 _rate) public whenNotPaused {
        Trade memory trade = getOneTrade(_tradeId);
        

        require(trade.owner == _msgSender(), "Trade can update only by owner");
        require(trade.tradeType == TradeType.Bid, "Trade not an BID");
        require(trade.isActive == true, "Trade is not active");
        require(_tradeId >= 0, "Trade Id is not correct");
        require(_rate > 0 , "Rate is not correct");
        require(trade.status == TradeStatus.Created, "Trade has already been acted upon");

        trades[trade.id].rate = _rate;
        trades[trade.id].amount = trades[trade.id].amount - 50000;
    }

    function addUsdtBidOffer(uint256 _tradeId,  uint256 _amount) public whenNotPaused nonReentrant returns(bool){

        require(_tradeId >= 0, "Trade Id is not correct");

        Trade memory trade = getOneTrade(_tradeId);
    
        require(_amount > 0 , "Aount can not be null");
        require(trade.owner == _msgSender(), "Trade can update only by owner");
        require(trade.tradeType == TradeType.Bid, "Trade not an BID");
        require(trade.isActive == true, "Trade is not active");
        require(trade.status == TradeStatus.Created, "Trade has already been acted upon");


        uint256 allowance = validStablecoin.allowance(_msgSender(), address(this));
        uint256 balance = validStablecoin.balanceOf(_msgSender());

        require(allowance >= _amount, "Check the token allowance");
        require(balance >= _amount, "Check the token balance");
      

        validStablecoin.transferFrom(_msgSender(), address(this), _amount);

        reserve = reserve.add(_amount);

        trades[trade.id].amount = trades[trade.id].amount.add(_amount);
        trades[trade.id].initAmount = trades[trade.id].initAmount.add(_amount);

        return true;
    }

    function updateAskOffer(uint256 _tradeId,  uint256 _rate) public whenNotPaused{
        Trade memory trade = getOneTrade(_tradeId);
        
        require(trade.owner == _msgSender(), "Trade can update only by owner");
        require(trade.tradeType == TradeType.Ask, "Trade not an ASK");
        require(trade.isActive == true, "Trade is not active");
        require(_tradeId >= 0, "Trade Id is not correct");
        require(_rate > 0 , "Rate is not correct");
        require(trade.status == TradeStatus.Created, "Trade has already been acted upon");

        trades[trade.id].rate = _rate;
        trades[trade.id].amount = trades[trade.id].amount - 1000000;
    }
    
    function addStableAskOffer(uint256 _tradeId,  uint256 _amount) public whenNotPaused nonReentrant returns(bool){

        require(_tradeId >= 0, "Trade Id is not correct");

        Trade memory trade = getOneTrade(_tradeId);
    
        require(_amount > 0 , "Aount can not be null");
        require(trade.owner == _msgSender(), "Trade can update only by owner");
        require(trade.tradeType == TradeType.Ask, "Trade not an BID");
        require(trade.isActive == true, "Trade is not active");
        require(trade.status == TradeStatus.Created, "Trade has already been acted upon");


        uint256 allowance = IERC20(trade.stable).allowance(_msgSender(), address(this));
        uint256 balance = IERC20(trade.stable).balanceOf(_msgSender());

        require(allowance >= _amount, "Check the token allowance");
        require(balance >= _amount, "Check the token balance");
      

        IERC20(trade.stable).transferFrom(_msgSender(), address(this), _amount);

        acceptStables[trade.stable].reserve = acceptStables[trade.stable].reserve.add(_amount);
        

        trades[trade.id].amount = trades[trade.id].amount.add(_amount);
        trades[trade.id].initAmount = trades[trade.id].initAmount.add(_amount);

        return true;
    }
    
    function takeBidOffer(uint256 _tradeId, uint256 _amount, address sponsor) public   whenNotPaused returns(bool){

        Trade memory trade = getOneTrade(_tradeId);
        require(_tradeId >= 0, "Trade Id is not correct");
        require(trade.rate >= 0, "Trade Id is not correct");


        AcceptStable storage stable = acceptStables[trade.stable];

        require(stable.addr!= address(0), "Stable not validated");

        require(trade.stable==stable.addr, "Stable not match with offer one");
  
        require(_amount > 0 && _amount <= trade.amount, "Amount is not correct");
      
        require(trade.isActive == true, "Trade is not active");
        
      
        uint256 allowance = IERC20(trade.stable).allowance(_msgSender(), address(this));
        uint256 balance = IERC20(trade.stable).balanceOf(_msgSender());

        uint256 amountStable = _amount.mul(trade.rate);

        require(allowance >= amountStable, "Check the token allowance");
        require(balance >= amountStable, "Check the token balance");
      

       
        if(reserve < _amount){
            uint256 balanceLending = IERC20(AAVE_USDT_ADDRESS).balanceOf(address(this));
            if(balanceLending>=_amount){
                lendingPool.withdraw(address(validStablecoin), _amount, address(this));
            }
        }


        IERC20(trade.stable).transferFrom(_msgSender(), address(this), amountStable);

        if (membersFee[_msgSender()]>0 && membersFee[_msgSender()]< 99 ) {
            buyerFee = membersFee[_msgSender()];
        }


        if (sellersFee[_msgSender()]>0 && sellersFee[_msgSender()]< 99 ) {
            sellerFee = sellersFee[_msgSender()];
        }


        if ( affilliatesReward[sponsor]>0 && affilliatesReward[sponsor]< 99) {
            affiliateFee = affilliatesReward[sponsor];
        }


        if(buyerFee > 0){

            uint256 tax = _amount.mul(buyerFee).div(100);
            uint256 afterTax = _amount.sub(tax);  

            uint256 stableTax = amountStable.mul(sellerFee).div(100);
            uint256 afterStableTax = amountStable.sub(stableTax);    
            
            
           
            uint256 reward = tax.mul(affiliateFee).div(100);
            tax = tax.sub(reward);

            uint256 rewardStable = stableTax.mul(affiliateFee).div(100);
            stableTax = stableTax.sub(rewardStable);
            



            reserve = reserve.sub(_amount);
           
            trades[trade.id].amount = trade.amount.sub(_amount);
 
            validStablecoin.transfer(_msgSender(), afterTax);
            validStablecoin.transfer(masterTax, tax);
            validStablecoin.transfer(sponsor, reward);


            IERC20(trade.stable).transfer(trade.owner, afterStableTax);
            IERC20(trade.stable).transfer(masterTax, stableTax);
            IERC20(trade.stable).transfer(sponsor, rewardStable);


        }else{

            reserve = reserve.sub(_amount);

            trade.amount = trade.amount.sub(_amount);

            validStablecoin.transfer(_msgSender(), _amount);

            IERC20(trade.stable).transfer(trade.owner, amountStable);
       
        }

       
        histories.push(History({
                id:trade.idTr,
                user:_msgSender(),
                date: block.timestamp,
                amount: _amount,
                tradeType:TradeType.Bid
        }));

        if(trades[trade.id].amount==0){
            trades[trade.id].isActive = false;
            trades[trade.id].status = TradeStatus.Paid;
        }

        return true;
       
    }

    function takeAskOffer(uint256 _tradeId, uint256 _amount, address sponsor) public   whenNotPaused returns(bool){

        Trade memory trade = getOneTrade(_tradeId);
        require(_tradeId >= 0, "Trade Id is not correct");
        require(trade.rate >= 0, "Trade Id is not correct");


        AcceptStable storage stable = acceptStables[trade.stable];

        require(stable.addr!= address(0), "Stable not validated");

        require(trade.stable==stable.addr, "Stable not match with offer one");
  
        require(_amount > 0 && _amount <= trade.amount, "Amount is not correct");
      
        require(trade.isActive == true, "Trade is not active");
        
      
        uint256 allowance = validStablecoin.allowance(_msgSender(), address(this));
        uint256 balance = validStablecoin.balanceOf(_msgSender());

        uint256 amountStable = _amount.mul(trade.rate);

        require(amountStable <= trade.amount, "USD amount is too much");

        require(allowance >= _amount, "Check the token allowance");
        require(balance >= _amount, "Check the token balance");
      


        validStablecoin.transferFrom(_msgSender(), address(this), _amount);
        

        if (membersFee[_msgSender()]>0  ) {
            buyerFee = membersFee[_msgSender()];
        }


        if (sellersFee[_msgSender()]>0  ) {
            sellerFee = sellersFee[_msgSender()];
        }


        if ( affilliatesReward[sponsor]>0 ) {
            affiliateFee = affilliatesReward[sponsor];
        }


        if(buyerFee > 0){

            uint256 tax = _amount.mul(buyerFee).div(100);
            uint256 afterTax = _amount.sub(tax);  

            uint256 stableTax = amountStable.mul(sellerFee).div(100);
            uint256 afterStableTax = amountStable.sub(stableTax);    
            
            uint256 reward = tax.mul(affiliateFee).div(100);
            tax = tax.sub(reward);

            uint256 rewardStable = stableTax.mul(affiliateFee).div(100);
            stableTax = stableTax.sub(rewardStable);
            

            acceptStables[trade.stable].reserve = acceptStables[trade.stable].reserve.sub(amountStable);
        
           
            trades[trade.id].amount = trade.amount.sub(amountStable);
 
            IERC20(trade.stable).transfer(_msgSender(), afterStableTax);
            IERC20(trade.stable).transfer(masterTax, stableTax);
            IERC20(trade.stable).transfer(sponsor, rewardStable);


            validStablecoin.transfer(trade.owner, afterTax);
            validStablecoin.transfer(masterTax, tax);
            validStablecoin.transfer(sponsor, reward);


        }else{

            acceptStables[trade.stable].reserve = acceptStables[trade.stable].reserve.sub(amountStable);
        
            trade.amount = trade.amount.sub(amountStable);

            IERC20(trade.stable).transfer(_msgSender(), amountStable);

            validStablecoin.transfer(trade.owner, _amount);
       
        }


        histories.push(History({
                id:trade.idTr,
                user:_msgSender(),
                date: block.timestamp,
                amount: amountStable,
                tradeType:TradeType.Ask
        }));

        if(trades[trade.id].amount==0){
            trades[trade.id].isActive = false;
            trades[trade.id].status = TradeStatus.Paid;
        }

        return true;
       
    }

    function cancelOffer(uint256 _tradeId)  public whenNotPaused nonReentrant{
       Trade memory trade = getOneTrade(_tradeId);

        require(trade.isActive == true, "Trade must be active to withdraw funds");
        require(trade.status == TradeStatus.Created, "Funds can only be withdrawn for created trades");
        require(_msgSender() == trade.owner ||  managers[_msgSender()] ||  admins[_msgSender()] || _msgSender() == owner, "Only the seller or manager can withdraw funds");
    
        trades[trade.id].isActive = false;
        trades[trade.id].status = TradeStatus.Canceled;
        
        

        if(trade.tradeType==TradeType.Bid) {

            trade.amount = trade.amount - cancelBidFee;
            validStablecoin.transfer(trade.owner, trade.amount);
            reserve = reserve.sub(trade.amount);

            histories.push(History({
                id:trade.idTr,
                user:_msgSender(),
                date: block.timestamp,
                amount: trade.amount,
                tradeType:TradeType.Bid
            }));

        }else if(trade.tradeType==TradeType.Ask){

            trade.amount = trade.amount - cancelAskFee;
            IERC20(trade.stable).transfer(trade.owner, trade.amount);
            acceptStables[trade.stable].reserve = acceptStables[trade.stable].reserve.sub(trade.amount);

            histories.push(History({
                id:trade.idTr,
                user:_msgSender(),
                date: block.timestamp,
                amount: trade.amount,
                tradeType:TradeType.Ask
            }));
        }
      
       histories.push(History({
            id:trade.idTr,
            user:_msgSender(),
            date: block.timestamp,
            amount: trade.amount,
            tradeType:TradeType.Bid
        }));

        trades[trade.id].amount = 0;
        trades[trade.id].isActive = false;
        trades[trade.id].status = TradeStatus.Canceled;
    }
  
    function withdrawBid911(bool all, uint256 _amount) onlyOwner nonReentrant public {
      
         require(_amount >= 0, "Check the token balance");
         require(_amount <= reserve, "Check the token balance");

        if(all==true){
            validStablecoin.transfer(owner, reserve);
            reserve = 0;
        }else{
            validStablecoin.transfer(owner, _amount);
            reserve = reserve.sub(_amount);
        }

    }

    function withdrawAsk911(address _stable, bool all, uint256 _amount) onlyOwner nonReentrant public {
      
        require(_amount >= 0, "Check the token balance");
        require(_amount <= acceptStables[_stable].reserve, "Check the token balance");

        if(all==true){
            IERC20(_stable).transfer(owner, acceptStables[_stable].reserve);
            acceptStables[_stable].reserve = 0;
        }else{

            IERC20(_stable).transfer(owner, _amount);
            acceptStables[_stable].reserve = acceptStables[_stable].reserve.sub(_amount);
        }

    }

    function withdrawAny(address token, uint256 _amount) onlyOwner nonReentrant public {
      
         require(IERC20(token) != validStablecoin, "Check the token balance");

         uint256 balance = IERC20(token).balanceOf(address(this));
         require(_amount >= 0, "Check the token balance");
         require(balance >= 0, "Check the token balance");
         require(_amount <= balance, "Check the token amount to withdraw");

         IERC20(token).transfer(owner, _amount);
    }

    ////////////////////////////////////////Lending modules//////////////////////////////////////////////////////////////////////////////////////////////////////////////

 
    function lendingDepositStable(uint256 amount) public onlyOwner returns(bool){

        uint256 allowance = validStablecoin.allowance(_msgSender(), address(this));
        uint256 balance = validStablecoin.balanceOf(_msgSender());

        require(allowance >= amount, "Check the token allowance");
        require(balance >= amount, "Check the token balance");


        validStablecoin.transferFrom(_msgSender(), address(this), amount);
        
        //Allow Aave to use the amount of usd
        validStablecoin.approve(address(lendingPool), amount);

        lendingPool.supply(address(validStablecoin), amount, _msgSender(), 0);
        
        return true;

    }

    function lendingWithdrawStable(uint256 amount) public  onlyOwner returns(bool){

        uint256 allowance = IERC20(AAVE_USDT_ADDRESS).allowance(_msgSender(), address(this));
        uint256 balance   = IERC20(AAVE_USDT_ADDRESS).balanceOf(_msgSender());

        require(allowance >= amount, "Check the token allowance");
        require(balance >= amount, "Check the token balance");


        IERC20(AAVE_USDT_ADDRESS).transferFrom(_msgSender(), address(this), amount);
        
        lendingPool.withdraw(address(validStablecoin), amount, _msgSender());

        return true;
        
    }

    //////////////////////////////////Swap modules////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function swapEstimation(address[] memory path,  uint256 amount) public view returns(uint[] memory amounts){
        return uniswapRouter.getAmountsOut(amount, path);
    }

    function swapUSDTToTOKEN(address token, uint256 amount) external {
        uint256 allowance = validStablecoin.allowance(_msgSender(), address(this));
        uint256 balance = validStablecoin.balanceOf(_msgSender());

        require(allowance >= amount, "Check the token allowance");
        require(balance >= amount, "Check the token balance");


        validStablecoin.transferFrom(_msgSender(), address(this), amount);

        amount = amount.sub(exchangeFee);

        if(exchangeFee>0){
            validStablecoin.transfer(masterTax, exchangeFee);
        }

        validStablecoin.approve(address(uniswapRouter), amount);

        if(MATIC_ADDRESS==token){
            address[] memory path = new address[](2);
            path[0] = address(validStablecoin);
            path[1] = MATIC_ADDRESS;

            uniswapRouter.swapExactTokensForTokens(
                amount,
                0, // Accept any amount of WBTC
                path,
                _msgSender(),
                block.timestamp + 15 // Deadline
            );

        }else{
            address[] memory path = new address[](3);
            path[0] = address(validStablecoin);
            path[1] = MATIC_ADDRESS;
            path[2] = token;

            uniswapRouter.swapExactTokensForTokens(
                amount,
                0, // Accept any amount of WBTC
                path,
                _msgSender(),
                block.timestamp + 15 // Deadline
            );
        }
    }

    function swapTokenToUSDT(address token, uint256 amount) external {
        uint256 allowance = IERC20(token).allowance(_msgSender(), address(this));
        uint256 balance = IERC20(token).balanceOf(_msgSender());

        require(allowance >= amount, "Check the token allowance");
        require(balance >= amount, "Check the token balance");

        IERC20(token).transferFrom(_msgSender(), address(this), amount);
      

        if(MATIC_ADDRESS==token){
            address[] memory path = new address[](2);
            path[0] = MATIC_ADDRESS;
            path[1] = address(validStablecoin);


            address[] memory pathEstimate = new address[](2);
            pathEstimate[0] = address(validStablecoin); 
            pathEstimate[1] = MATIC_ADDRESS;

            if(exchangeFee>0){

                uint256[] memory taxEstimate =  uniswapRouter.getAmountsOut(exchangeFee, pathEstimate);

                uint256 taxEstimateAmount = taxEstimate[1];

                amount = amount.sub(taxEstimateAmount);

                IERC20(token).transfer(masterTax, taxEstimateAmount);

            }
          
            IERC20(token).approve(address(uniswapRouter), amount);
            uniswapRouter.swapExactTokensForTokens(
                amount,
                0, // Accept any amount of USDT
                path,
                _msgSender(),
                block.timestamp + 15 // Deadline
            );


           

        }else{
            address[] memory path = new address[](3);
            path[0] = token;
            path[1] = MATIC_ADDRESS;
            path[2] = address(validStablecoin);

            //Tax estimation 
            address[] memory pathEstimate = new address[](3);
            pathEstimate[0] = address(validStablecoin); 
            pathEstimate[1] = MATIC_ADDRESS;
            pathEstimate[2] = token;

            if(exchangeFee>0){
                uint256[] memory taxEstimate =  uniswapRouter.getAmountsOut(exchangeFee, pathEstimate);

                uint256 taxEstimateAmount = taxEstimate[2];
                
                amount = amount.sub(taxEstimateAmount);


                IERC20(token).transfer(masterTax, taxEstimateAmount);
            }

            IERC20(token).approve(address(uniswapRouter), amount);
            uniswapRouter.swapExactTokensForTokens(
                amount,
                0, // Accept any amount of USDT
                path,
                _msgSender(),
                block.timestamp + 15 // Deadline
            );


          
        }
    }

    function swapTokenToToken(address token, address token2, uint256 amount) external {
        uint256 allowance = IERC20(token).allowance(_msgSender(), address(this));
        uint256 balance = IERC20(token).balanceOf(_msgSender());

        require(allowance >= amount, "Check the token allowance");
        require(balance >= amount, "Check the token balance");


        IERC20(token).transferFrom(_msgSender(), address(this), amount);
      

        address[] memory path = new address[](3);
        path[0] = token;
        path[1] = MATIC_ADDRESS;
        path[2] = token2;


        //Tax estimation 
        address[] memory pathEstimate = new address[](3);
        pathEstimate[0] = address(validStablecoin); 
        pathEstimate[1] = MATIC_ADDRESS;
        pathEstimate[2] = token;

        uint256[] memory taxEstimate =  uniswapRouter.getAmountsOut(exchangeFee, pathEstimate);

        uint256 taxEstimateAmount = taxEstimate[2];

        amount = amount.sub(taxEstimateAmount);


        IERC20(token).approve(address(uniswapRouter), amount);
        uniswapRouter.swapExactTokensForTokens(
            amount,
            0, // Accept any amount of USDT
            path,
            _msgSender(),
            block.timestamp + 15 // Deadline
        );

        IERC20(token).transfer(masterTax, taxEstimateAmount);
          
    }


    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


    function getOneTrade(uint idTr) public view returns (Trade memory) {
       Trade[] memory result = new Trade[](1);
        for (uint256 i = 0; i < trades.length; i++) {
            if (trades[i].idTr == idTr) {
              result[0] = trades[i] ;
            }
        }
      return result[0];
    }

    function getAllTrades() public view returns (Trade[] memory) {
       
        Trade[] memory result = new Trade[](trades.length);
     
        for (uint256 i = 0; i < trades.length; i++) {
            result[i] = trades[i];
        }

        return result;
    }

    function getMyTrades(address user) public view returns (Trade[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < trades.length; i++) {
            if ( trades[i].owner == user) {
                count++;
            }
        }
        Trade[] memory result = new Trade[](count);
        count = 0;
        for (uint256 i = 0; i < trades.length; i++) {
            if (trades[i].owner == user) {
                result[count] = trades[i];
                count++;
            }
        }
        return result;
    }

    function getTradesCount() external view returns (uint256) {
        return trades.length;
    }


}