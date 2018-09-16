pragma solidity ^0.4.24;


contract Procurement {
    enum ContractStatus { Proposed, Open, Closed }
    enum OrderStatus { Ordered, Delivered }

    struct Order {
        bool exists;
        uint cost;
        OrderStatus status;
        uint deliveryTimeDue;
    }

    // Addresses of buyer and seller in contract
    address public seller;
    address public buyer;
    
    // Contract parameters
    uint public minimumItemsToBeOrdered;
    uint public maximumItemsToBeOrdered;
    uint public costPerUnit;
    uint public performanceGuarantee;
    uint public sellerDeposit;
    uint public endOfContractTimestamp;
    
    // Contract status
    ContractStatus public contractStatus;
    uint8 public itemsOrderedCount;
    uint public moneyLeftInContract;

    // Orders
    mapping (uint8 => Order) public orders;
    uint8 public pendingOrderCount;
    uint public pendingOrderCost;
    uint public lateOrdersCount;
    uint public inTimeOrdersCount;
    
    bool buyerEnacted = false;
    
    modifier enacted(){
        require(buyerEnacted);
        _;
    }

    modifier bySeller { 
        require(msg.sender == seller); 
        _; 
    }

    modifier byBuyer { 
        require(msg.sender == buyer); 
        _; 
    }
    
    modifier internalCall(){
        require(msg.sender == address(this));
        _;
    }
    
    function enactment(
        address _seller, address _buyer,
        uint _minimumItemsToBeOrdered, uint _maximumItemsToBeOrdered,
        uint _costPerUnit,
        uint _performanceGuarantee,
        uint _contractDuration
    ) public payable{
        buyerEnacted = true;

        uint index = eventsIndex;
        if(!this.call.value(msg.value)(bytes4(keccak256("constructorLogic(address, address, uint, uint, uint, uint, uint)")), _seller, _buyer, _minimumItemsToBeOrdered, _maximumItemsToBeOrdered, _costPerUnit, _performanceGuarantee, _contractDuration)){
            index++;
        }

        events[uint(ContractEvents.Enactment)] = eventsIndex;
        
        if(msg.value < minimumItemsToBeOrdered*costPerUnit){
            events[uint(ContractEvents.EnactmentWithLessThanCostOfMinimumItems)] = index;
        }

    }
    
    function enactmentLogic(
        address _seller, address _buyer,
        uint _minimumItemsToBeOrdered, uint _maximumItemsToBeOrdered,
        uint _costPerUnit,
        uint _performanceGuarantee,
        uint _contractDuration
    ) public internalCall payable
    {
        // The minimum order size must be put in escrow at signing time
        require(msg.value >= _costPerUnit * _minimumItemsToBeOrdered);

        // Set the contract parameters
        seller = _seller;
        buyer = _buyer;

        minimumItemsToBeOrdered = _minimumItemsToBeOrdered;
        maximumItemsToBeOrdered = _maximumItemsToBeOrdered;

        costPerUnit = _costPerUnit;

        endOfContractTimestamp = now + _contractDuration;

        performanceGuarantee = _performanceGuarantee;

        // Contract status
        contractStatus = ContractStatus.Proposed;
        itemsOrderedCount = 0;
        moneyLeftInContract = msg.value;

        // Initialise orders
        pendingOrderCount = 0;
        pendingOrderCost = 0;
        lateOrdersCount = 0;
        inTimeOrdersCount = 0;
        
    }
    
    function returnEscrow() enacted public{
        uint index = eventsIndex;
        if(!this.call(bytes4(keccak256("returnEscrowLogic()")))){
            index++;
        }

        events[uint(ContractEvents.ReturnEscrow)] = index;
    }
    
    bool sellerAccepted = false;
    function returnEscrowLogic() enacted private{
        if(sellerAccepted){
            seller.transfer(sellerDeposit);
            buyer.transfer(this.balance);
        }
    }
    
    function acceptContract() public enacted bySeller payable{
        uint index = eventsIndex;
        if(!this.call.value(msg.value)(bytes4(keccak256("acceptContractLogic()")))){
            index++;
        }
        
        if(msg.value < performanceGuarantee){
            events[uint(ContractEvents.AcceptContractWithLessThanGuarantee)] = index;
        }

    }

    function acceptContractLogic() public enacted internalCall payable{
        //require(msg.value >= performanceGuarantee);
        contractStatus = ContractStatus.Open;
        
        sellerDeposit = msg.value;
        sellerAccepted = true;
    }
    
    
    function createOrder(
        uint8 _orderNumber,
        uint8 _orderSize,
        uint _orderDeliveryTimeLeft
    ) public payable enacted byBuyer
    {
        uint index = eventsIndex;
        if(!address(this).call.value(msg.value)(bytes4(keccak256("createOrderLogic(uint8, uint8, uint)")), _orderNumber, _orderSize, _orderDeliveryTimeLeft)){
            index++;
        }

        if(itemsOrderedCount < maximumItemsToBeOrdered && _orderDeliveryTimeLeft + now < endOfContractTimestamp){
            events[uint(ContractEvents.OrderWithLessThanMaxItemsAndDeliveryTimeLessThan24HrsAndBeforeEnd)] = index;
        }
        
        if(moneyLeftInContract - performanceGuarantee < pendingOrderCost){
            events[uint(ContractEvents.OrderWithLessThanEnoughMoneyForPendingOrders)] = index;
        }
    }

    function createOrderLogic(
        uint8 _orderNumber,
        uint8 _orderSize,
        uint _orderDeliveryTimeLeft
    ) public payable enacted internalCall byBuyer 
    {
        // Order does not already exist
        require(!orders[_orderNumber].exists);
        // Number of items ordered does not exceed maximum
        require(itemsOrderedCount + _orderSize <= maximumItemsToBeOrdered);
        // Order delivery deadline will not be too late
        require(now + _orderDeliveryTimeLeft <= endOfContractTimestamp);

        // Ensure there is enough money left in the contract to pay for the order
        uint orderCost = _orderSize * costPerUnit;
        moneyLeftInContract += msg.value;
        require(orderCost <= moneyLeftInContract);
        moneyLeftInContract -= orderCost;
        
        // Update number of items ordered
        itemsOrderedCount += _orderSize;

        // Update contract status
        pendingOrderCount++;
        pendingOrderCost += orderCost;

        // Record the order
        orders[_orderNumber] = Order(true, orderCost, OrderStatus.Ordered, now+_orderDeliveryTimeLeft);
    }
    
    function deliveryMade(uint8 _orderNumber) public enacted byBuyer{
        uint index = eventsIndex;
        
        uint balanceBefore = this.balance; 
        
        if(!this.call(bytes4(keccak256("deliveryMadeLogic()")))){
            index++;
        }
        
        uint balanceAfter = this.balance;
        
        if(balanceBefore < balanceAfter + orders[_orderNumber].cost){
            events[uint(ContractEvents.DeliveryWithPaymentLessThanCost)] = index;
        }
        
    }

    function deliveryMadeLogic(
        uint8 _orderNumber
    ) private enacted byBuyer 
    {
        Order memory order = orders[_orderNumber];

        // Ensure that the order exists and has not yet been delivered
        require(order.exists && order.status == OrderStatus.Ordered);

        // Order state update
        order.status = OrderStatus.Delivered;

        // Contract state update
        if (order.deliveryTimeDue < now) {
            lateOrdersCount++;
        } else {
            inTimeOrdersCount++;
        }

        pendingOrderCount--;
        pendingOrderCost -= order.cost;

        // Pay the seller
        seller.transfer(order.cost);
    }
    
    
    function disableContract() public enacted {
        contractStatus = ContractStatus.Closed;
    }
    
    function tick() public enacted {
        transition();

        if(currentState == uint(ContractStates.viol)){
            disableContract();
        }
    }

    //events[0] = eventsIndex // 0th event is successful
    //events[0] = eventsIndex + 1// 0th event failed
    uint eventsIndex = 1;
    mapping(uint => uint) events;
    uint currentState;
    
    mapping(uint => Norm[]) stateNorms;

    struct Norm{
        Modality modality;
        ContractEvents normedEvent;
        Norm[] reparations;
    }
    
    enum Modality{O, F, P}
    
    enum ContractStates{init, repLessThanGuarantee, secondState, sendBuyerGuarantee, sendSellerGuarantee, viol, sat}
    enum ContractEvents{TerminateContract,
                        TeminateContractNotBetweenMinAndMaxItems, 
                        TerminateContractBeforeEndTimestamp,
                        TerminateContractBySellerAndWithPendingOrders,
                        TerminateContractUnlessOtherwiseForbidden,
                        Enactment,
                        EnactmentWithLessThanCostOfMinimumItems,
                        AcceptContractWithLessThanGuarantee,
                        ReturnEscrow,
                        OrderWithLessThanMaxItemsAndDeliveryTimeLessThan24HrsAndBeforeEnd,
                        OrderWithLessThanEnoughMoneyForPendingOrders,
                        DeliveryWithPaymentLessThanCost,
                        TerminateContractWithPendingOrdersOr25PercentLateOrders,
                        SendGuaranteeToBuyer,
                        TerminateContractWithoutPendingOrdersAnd25PercentLateOrders,
                        SendGuaranteeToSeller,
                        SellerAcceptsContractWithEnoughGuarantee
    }
    
    function transition() public enacted{
        require(currentState == uint(ContractStates.viol));
        require(currentState == uint(ContractStates.sat));
        
        if(currentState == uint(ContractStates.init)){
            if(events[uint(ContractEvents.EnactmentWithLessThanCostOfMinimumItems)] == eventsIndex
                || events[uint(ContractEvents.EnactmentWithLessThanCostOfMinimumItems)] == eventsIndex + 1){
                    currentState = uint(ContractStates.viol);
                    return;
            }
            else if(events[uint(ContractEvents.AcceptContractWithLessThanGuarantee)] == eventsIndex){
                    currentState = uint(ContractStates.repLessThanGuarantee);
                    return;
            }
            else if(events[uint(ContractEvents.Enactment)] == eventsIndex){
                    currentState = uint(ContractStates.secondState);
                    return;
            }
        }
        else if(currentState == uint(ContractStates.repLessThanGuarantee)){
            if((events[uint(ContractEvents.ReturnEscrow)] == eventsIndex
                    || events[uint(ContractEvents.ReturnEscrow)] == eventsIndex + 1)){
                currentState = uint(ContractStates.sat);
                return;
             }
             else{
                currentState = uint(ContractStates.viol);
                return;
             }
        }
        else if(currentState == uint(ContractStates.secondState)){
            if(events[uint(ContractEvents.TeminateContractNotBetweenMinAndMaxItems)] == eventsIndex
                || events[uint(ContractEvents.TeminateContractNotBetweenMinAndMaxItems)] == eventsIndex + 1
                || events[uint(ContractEvents.TerminateContractBeforeEndTimestamp)] == eventsIndex
                || events[uint(ContractEvents.TerminateContractBeforeEndTimestamp)] == eventsIndex + 1
                || events[uint(ContractEvents.TerminateContractBySellerAndWithPendingOrders)] == eventsIndex
                || events[uint(ContractEvents.TerminateContractBySellerAndWithPendingOrders)] == eventsIndex + 1
                || events[uint(ContractEvents.OrderWithLessThanEnoughMoneyForPendingOrders)] == eventsIndex
                || events[uint(ContractEvents.OrderWithLessThanEnoughMoneyForPendingOrders)] == eventsIndex + 1){
                    currentState = uint(ContractStates.viol);
                    return;
            }
            else if(events[uint(ContractEvents.TerminateContract)] != eventsIndex
                    && (events[uint(ContractEvents.OrderWithLessThanMaxItemsAndDeliveryTimeLessThan24HrsAndBeforeEnd)] == eventsIndex + 1
                        || events[uint(ContractEvents.DeliveryWithPaymentLessThanCost)] == eventsIndex
                        || events[uint(ContractEvents.DeliveryWithPaymentLessThanCost)] == eventsIndex + 1)){
                            currentState = uint(ContractStates.viol);
                            return;
            }
            else if(events[uint(ContractEvents.TerminateContractWithoutPendingOrdersAnd25PercentLateOrders)] == eventsIndex){
                    currentState = uint(ContractStates.sendSellerGuarantee);
                    return;
            }
            else if(events[uint(ContractEvents.TerminateContractWithPendingOrdersOr25PercentLateOrders)] == eventsIndex){
                    currentState = uint(ContractStates.sendBuyerGuarantee);
                    return;
            }
        }
        else if(currentState == uint(ContractStates.sendSellerGuarantee)){
            if(events[uint(ContractEvents.SendGuaranteeToSeller)] == eventsIndex
                || events[uint(ContractEvents.SendGuaranteeToSeller)] == eventsIndex + 1){
                    currentState = uint(ContractStates.sat);
                    return;
            }
            else{
                currentState = uint(ContractStates.viol);
                return;
            }
        }
        else if(currentState == uint(ContractStates.sendBuyerGuarantee)){
            if(events[uint(ContractEvents.SendGuaranteeToBuyer)] == eventsIndex
                || events[uint(ContractEvents.SendGuaranteeToBuyer)] == eventsIndex + 1){
                    currentState = uint(ContractStates.sat);
                    return;
            }
            else{
                currentState = uint(ContractStates.viol);
                return;
            }
        }
        
        eventsIndex += 2;
    }

    function terminateContract() public enacted{
        uint index = eventsIndex;
        if(!this.call(bytes4(keccak256("terminateContractLogic()")))){
            index++;
        }
        
        events[uint(ContractEvents.TerminateContract)] = index;
            
        uint otherwise = 0; 
            
        if(itemsOrderedCount >= minimumItemsToBeOrdered
            && itemsOrderedCount <= maximumItemsToBeOrdered){
            events[uint(ContractEvents.TeminateContractNotBetweenMinAndMaxItems)] = index;
            otherwise++;
        }
            
        if(now < endOfContractTimestamp){
            events[uint(ContractEvents.TerminateContractBeforeEndTimestamp)] = index;
            otherwise++;
        }
            
        if(msg.sender == seller && pendingOrderCount != 0){
            events[uint(ContractEvents.TerminateContractBySellerAndWithPendingOrders)] = index;
            otherwise++;
        }
            
        if(otherwise == 3){
            events[uint(ContractEvents.TerminateContractUnlessOtherwiseForbidden)] = index;
            otherwise++;
        }
            
        if(pendingOrderCount != 0 || lateOrdersCount*100 >= 25*itemsOrderedCount){
            events[uint(ContractEvents.TerminateContractWithPendingOrdersOr25PercentLateOrders)] = index;
        }
        else if(pendingOrderCount != 0 || lateOrdersCount*100 >= 25*itemsOrderedCount){
            events[uint(ContractEvents.TerminateContractWithoutPendingOrdersAnd25PercentLateOrders)] = index;
        }
    }

    function terminateContractLogic() private enacted{
        // Can only be done by the seller or buyer
        require(msg.sender == seller || msg.sender == buyer);

        // Can only be closed after the contract time frame ended
        require(now > endOfContractTimestamp);

        if (msg.sender == seller) {
            // Can only be closed by seller if there are no pending orders
            require(pendingOrderCount == 0);
        }

        if (pendingOrderCount > 0) {
            // If there are any undelivered orders, return their cost to the buyer 
            buyer.transfer(pendingOrderCost);
        } else {
            // If there are no undelivered orders, and not enough orders were made (less 
            // than minimum) the seller gets money for the unordered items
            if (itemsOrderedCount < minimumItemsToBeOrdered) {
                seller.transfer((itemsOrderedCount-minimumItemsToBeOrdered)*costPerUnit);
            }
        }

        // If there are any pending orders or 25%+ of the orders were delivered late
        // the buyer gets the performance guarantee, otherwise it is returned to the seller
        if ((pendingOrderCount > 0) || (lateOrdersCount * 3 >= inTimeOrdersCount)) {
            sendGuaranteeToBuyer();
        } else {
            sendGuaranteeToSeller();
        }

    }

    function sendGuaranteeToSeller() private enacted{
        uint index = eventsIndex;
        
        if(!address(this).call(bytes4(keccak256("sendGuaranteeToSellerLogic()")))){
            index++;
        }
        
        events[uint(ContractEvents.SendGuaranteeToSeller)] = index;
    }

    function sendGuaranteeToSellerLogic() private enacted{
        seller.transfer(performanceGuarantee);
    }

    function sendGuaranteeToBuyer() private enacted{
        uint index = eventsIndex;
        
        if(!address(this).call(bytes4(keccak256("sendGuaranteeToBuyerLogic()")))){
            index++;
        }
        
        events[uint(ContractEvents.SendGuaranteeToBuyer)] = index;
    }

    function sendGuaranteeToBuyerLogic() private enacted{
        buyer.transfer(performanceGuarantee);
    }
}
