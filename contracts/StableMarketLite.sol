//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/metatx/MinimalForwarder.sol";
import {
    ERC2771Context
} from "@gelatonetwork/relay-context/contracts/vendor/ERC2771Context.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";



contract StableMarketGasless is ERC2771Context, ReentrancyGuard {
      
    using SafeMath for uint256;

    IUniswapV2Router02 public uniswapRouter = IUniswapV2Router02(0xE43e60736b1cb4a75ad25240E2f9a62Bff65c0C0);

    // address private USD_ADDRESS = 0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83; // 
    address private XDAI_ADDRESS = 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d; //

    //Wallet manager
    address public owner;
    address public masterTax;
    bool    public isPause = false;

    //Token address
    IERC20  public validStablecoin;

   //Enum
    enum TradeStatus { Created, Taken, Updated, Canceled, Closed }
    enum TransferType { Sent, Swapped}
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

    //0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83 USD
    //0x758887C1C014F9e83F9FCE800012d00AbCA6Ec1A HTG
    //0xd8253782c45a12053594b9deB72d8e8aB2Fca54c Relay
    struct AcceptStable {
        address  addr;
        uint256 reserve;
    }

     struct History {
        uint256  id;
        address  user;
        uint256   date;
        uint256  amount;
        uint256  rate;
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



    /// @notice An event thats emitted when the place Offer
    event placeAnOffer(
        uint256 indexed idTr,
        uint id,
        address indexed user,
        uint256 amount,
        uint256 initAmount,
        uint256 rate,
        bool isActive,
        TradeStatus status,
        TradeType tradeType,
        address indexed stable
    );


    /// @notice An event thats emitted when an user take an offer
    event historyOffer(
        uint256 indexed idTr, 
        address indexed user, 
        uint256 date, 
        uint256 amount,
        uint256 rate,
        TradeType indexed tradeType,
        TradeStatus status
    );

    /// @notice An event thats emitted when an user send token
    event historyTransfer(
        address indexed from, 
        address indexed to, 
        uint256 date, 
        uint256 amount,
        TransferType indexed transferType,
        address token
    );


 


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



    function changeRouter(address _router) public onlyOwner returns (bool) {
         uniswapRouter = IUniswapV2Router02(_router);
        return true;
    }


    ///////////////////////////////////////Mecanist to stop///////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function pause() public onlyOwner onlyAdmin {
        isPause = true;
    }

    function unpause() public onlyOwner onlyAdmin {
         isPause = false;
    }

 
    ///////////////////////////////////////////Offer///////////////////////////////////////////////////////////////////////////////////////////////////////////


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
        emit placeAnOffer(
            idTr,
            count,
            _msgSender(),
            _amount,
            _amount,
            _rate,
            true,
            TradeStatus.Created,
            TradeType.Bid,
            _stable);
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

        emit placeAnOffer(
            idTr,
            count,
            _msgSender(),
            _amount,
            _amount,
            _rate,
            true,
            TradeStatus.Created,
            TradeType.Ask,
            _stable);
        return true;
    }

    ////////////////////////////////////////////////update////////////////////////////////////////////////////////////////////////////////////////////////////


    function updateBidOffer(uint256 _tradeId,  uint256 _rate) public whenNotPaused  returns(bool){
        Trade memory trade = getOneTrade(_tradeId);
        

        require(trade.owner == _msgSender(), "Trade can update only by owner");
        require(trade.tradeType == TradeType.Bid, "Trade not an BID");
        require(trade.isActive == true, "Trade is not active");
        require(_tradeId >= 0, "Trade Id is not correct");
        require(_rate > 0 , "Rate is not correct");
        require(trade.status == TradeStatus.Created, "Trade has already been acted upon");

        trades[trade.id].rate = _rate;
        trades[trade.id].amount = trades[trade.id].amount - 50000;


       

         emit historyOffer(
            trade.idTr, 
            _msgSender(), 
            block.timestamp,
            0,
            _rate,
            TradeType.Bid,
            TradeStatus.Updated
        );

         return true;
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


      

        emit historyOffer(
            trade.idTr, 
            _msgSender(), 
            block.timestamp,
            _amount,
            0,
            TradeType.Bid,
            TradeStatus.Updated
        );  


        return true;
    }

    function updateAskOffer(uint256 _tradeId,  uint256 _rate) public whenNotPaused returns(bool){
        Trade memory trade = getOneTrade(_tradeId);
        
        require(trade.owner == _msgSender(), "Trade can update only by owner");
        require(trade.tradeType == TradeType.Ask, "Trade not an ASK");
        require(trade.isActive == true, "Trade is not active");
        require(_tradeId >= 0, "Trade Id is not correct");
        require(_rate > 0 , "Rate is not correct");
        require(trade.status == TradeStatus.Created, "Trade has already been acted upon");

        trades[trade.id].rate = _rate;
        trades[trade.id].amount = trades[trade.id].amount - 1000000;

      

         emit historyOffer(
            trade.idTr, 
            _msgSender(), 
            block.timestamp,
            0,
            _rate,
            TradeType.Ask,
            TradeStatus.Updated
        );  


         return true;
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


    
        emit historyOffer(
            trade.idTr, 
            _msgSender(), 
            block.timestamp,
            _amount,
            0,
            TradeType.Ask,
            TradeStatus.Updated
        );  

        return true;
    }
    
    /////////////////////////////////////////////take Offer///////////////////////////////////////////////////////////////////////////////////////////////////////

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
                rate: trade.rate,
                tradeType:TradeType.Bid
        }));


        emit historyOffer(
             trade.idTr, 
            _msgSender(), 
            block.timestamp,
            _amount,
            trade.rate,
            TradeType.Bid,
            TradeStatus.Taken
        );    



        if(trades[trade.id].amount==0){
            trades[trade.id].isActive = false;
            trades[trade.id].status = TradeStatus.Closed;
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
                rate: trade.rate,
                tradeType:TradeType.Ask
        }));


        emit historyOffer(
             trade.idTr, 
            _msgSender(), 
            block.timestamp,
            amountStable,
            trade.rate,
            TradeType.Ask,
            TradeStatus.Taken
        );   

        if(trades[trade.id].amount==0){
            trades[trade.id].isActive = false;
            trades[trade.id].status = TradeStatus.Closed;
        }

        return true;
       
    }

    //////////////////////////////////////////////cancel//////////////////////////////////////////////////////////////////////////////////////////////////////


    function cancelOffer(uint256 _tradeId)  public whenNotPaused nonReentrant returns (bool){
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
                rate: trade.rate,
                tradeType:TradeType.Bid
            }));
           
            emit historyOffer(
                trade.idTr, 
                _msgSender(), 
                block.timestamp,
                trade.amount,
                trade.rate,
                TradeType.Bid,
                TradeStatus.Canceled
            );  
        }else if(trade.tradeType==TradeType.Ask){

            trade.amount = trade.amount - cancelAskFee;
            IERC20(trade.stable).transfer(trade.owner, trade.amount);
            acceptStables[trade.stable].reserve = acceptStables[trade.stable].reserve.sub(trade.amount);

            histories.push(History({
                id:trade.idTr,
                user:_msgSender(),
                date: block.timestamp,
                amount: trade.amount,
                rate: trade.rate,
                tradeType:TradeType.Ask
            }));

        emit historyOffer(
             trade.idTr, 
            _msgSender(), 
            block.timestamp,
            trade.amount,
            trade.rate,
            TradeType.Ask,
            TradeStatus.Canceled
        );  

           
        }
      
       histories.push(History({
            id:trade.idTr,
            user:_msgSender(),
            date: block.timestamp,
            amount: trade.amount,
            rate: trade.rate,
            tradeType:TradeType.Bid
        }));

        trades[trade.id].amount = 0;
        trades[trade.id].isActive = false;
        trades[trade.id].status = TradeStatus.Canceled;
   
   
   
        return true;
    }
  
    ///////////////////////////////////////////////withdraw/////////////////////////////////////////////////////////////////////////////////////////////////////
  
    function withdrawBid911(bool all, uint256 _amount) onlyOwner nonReentrant public {
      
         require(_amount >= 0, "Check the token balance");
         require(_amount <= reserve, "Check the token balance");

        if(all==true){
            validStablecoin.transfer(owner, reserve);
            reserve = 0;

             emit historyTransfer(
                address(this) ,
                owner, 
                block.timestamp, 
                reserve,
                TransferType.Sent,
                address(validStablecoin)
                
            );
        }else{
            validStablecoin.transfer(owner, _amount);
            reserve = reserve.sub(_amount);

             emit historyTransfer(
                address(this),
                owner, 
                block.timestamp, 
                _amount,
                 TransferType.Sent,
               address(validStablecoin)
            );
        }

    }

    function withdrawAsk911(address _stable, bool all, uint256 _amount) onlyOwner nonReentrant public {
      
        require(_amount >= 0, "Check the token balance");
        require(_amount <= acceptStables[_stable].reserve, "Check the token balance");

        if(all==true){
            IERC20(_stable).transfer(owner, acceptStables[_stable].reserve);
            acceptStables[_stable].reserve = 0;

            emit historyTransfer(
                address(this) ,
                owner, 
                block.timestamp, 
                acceptStables[_stable].reserve,
                TransferType.Sent,
                _stable
            );


        }else{

            IERC20(_stable).transfer(owner, _amount);
            acceptStables[_stable].reserve = acceptStables[_stable].reserve.sub(_amount);

             emit historyTransfer(
                address(this), 
                owner, 
                block.timestamp, 
                _amount,
                TransferType.Sent,
                _stable
            );

        }

    }

    function withdrawAny(address token, uint256 _amount) onlyOwner nonReentrant public {
      
         require(IERC20(token) != validStablecoin, "Check the token balance");

         uint256 balance = IERC20(token).balanceOf(address(this));
         require(_amount >= 0, "Check the token balance");
         require(balance >= 0, "Check the token balance");
         require(_amount <= balance, "Check the token amount to withdraw");

         IERC20(token).transfer(owner, _amount);


        emit historyTransfer(
            address(this) ,
            owner, 
             block.timestamp, 
             _amount,
            TransferType.Sent,
            token
        );


    }

    ///////////////////////////////////////////////send/////////////////////////////////////////////////////////////////////////////////////////////////////
    

    function sendToken(address erctoken, address to,  uint256 amount) public whenNotPaused returns (bool) {


        require(amount > 0, "Tokens amount can't be zero");
        require(erctoken != address(0), "ERC20 can't be null address");
        require(to != address(0), "Recipient can't be null address");

        IERC20 ErcToken  = IERC20(erctoken);
        require(ErcToken.balanceOf(_msgSender()) >= amount, "Token not enough");
      
        ErcToken.transferFrom(_msgSender(), to , amount);

        emit historyTransfer(
            _msgSender(),
            to, 
            block.timestamp, 
            amount,
            TransferType.Sent,
            erctoken
        );


        return true;
    }

    ///////////////////////////////////////////////swap/////////////////////////////////////////////////////////////////////////////////////////////////////


    function swapEstimation(address[] memory path,  uint256 amount) public view returns(uint[] memory amounts){
        return uniswapRouter.getAmountsOut(amount, path);
    }

    function swap(address[] memory path, uint256 amount) external returns (bool){
        uint256 allowance = IERC20(path[0]).allowance(_msgSender(), address(this));
        uint256 balance = IERC20(path[0]).balanceOf(_msgSender());

        require(allowance >= amount, "Check the token allowance");
        require(balance >= amount, "Check the token balance");

        IERC20(path[0]).transferFrom(_msgSender(), address(this), amount);
      
        IERC20(path[0]).approve(address(uniswapRouter), amount);
        uniswapRouter.swapExactTokensForTokens(
            amount,
            0, // Accept any amount of USDT
            path,
            _msgSender(),
            block.timestamp + 15 // Deadline
        );

         emit historyTransfer(
            _msgSender(),
            _msgSender(), 
            block.timestamp, 
             amount,
            TransferType.Swapped,
            path[0]
        );

          return true;
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


  

    function getTradesCount() external view returns (uint256) {
        return trades.length;
    }

      function getHistodicCount() external view returns (uint256) {
        return histories.length;
    }


}