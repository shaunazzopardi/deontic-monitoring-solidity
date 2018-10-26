# deontic-monitoring-solidity

Here we illustrate a case study in monitoring a Solidity smart contract with a deontic logic specification language, as [published](https://github.com/shaunazzopardi/secure-parity-wallet) in the proceedings of [Jurix 2018](http://jurix2018.ai.rug.nl/). We consider a smart contract implementing a procurement process, involving a buyer and a seller that agree to certain terms (e.g. the minimum number of items that need to be ordered during the term of the contract) involving the procurement of goods.  This contract is specified formally and informally below. We are currently working on an implementation of contractLarva (github.com/gordonpace/contractlarva) that can take as input such a deontic contract specification (with more code-like actions) for automated instrumented of a smart contract with a monitor checking for the deontic contract. 

### Files

**procurement-simple.sol** is the Solidity smart contract implementing this procurement interaction between the buyer and the seller.

**procurement-simple-monitored.sol** is the Solidity smart contract **procurement-simple.sol** monitored for the contract as specified formally below.

### Informal Contract

>1.  This contract is between *buyer-name*, henceforth referred to as 'the buyer' and *seller-name*, henceforth referred to as 'the seller'. The contract will hold until either party requests its termination.

>2.  The buyer is obliged to order at least *minimum-items*, but no more than *maximum-items* items for a fixed price *price* before the termination of this contract. 

>3.  Notwithstanding clause 1, no request for termination will be accepted before  *contract-end-date*. Furthermore, the seller may not terminate the contract as long as there are pending orders.
   
>4. Upon enactment of this contract, the buyer is obliged to place the cost of the minimum number of items to be ordered in escrow.

>5.  Upon accepting this contract, the seller is obliged to place the amount of *performance-guarantee* in escrow, otherwise, if only a partial amount is placed, the seller is obliged to place the rest by a time period at the buyer's discretion.%the contract is terminated and the buyer's and seller's respective escrow is returned.

>6.  While the contract has not been terminated, the buyer has the right to place an order for an amount of items and a specified time-frame as long as (i) the running number of items ordered does not exceed the maximum stipulated in clause 2; and (ii) the time-frame must be of at least 24 hours, but may not extend beyond the contract end date specified in clause 2/

>7.  Upon placing an order, the buyer is obliged to ensure that there is enough money in escrow to cover payment of all pending orders.
    
>8. Before termination of the contract, upon delivery the seller must receive payment of the order.
    
>9. Upon termination of the contract, if either any orders were undelivered or more than 25% of the orders were delivered late, the buyer has the right to receive the performance guarantee placed in escrow according to clause 5.

### Formal (Deontic) Contract

>C1.    **P**(TerminateContractUnlessOtherwiseForbidden)

>C2.       **F**(TeminateContractWithItemsNotBetweenMinAndMaxItems)	

>C3. **F**(TerminateContractBeforeEndTimestamp) & **F**(TerminateContractBySellerAndWithPendingOrders)
		
>C4.		**F**(EnactmentWithLessThanCostOfMinimumItems)
		
>C5.		**F**(AcceptContractWithLessThanGuarantee) ▷ **O**(SendRestOfGuarantee)	 

>C6.		[ContractNotTerminated]**P**(OrderWithLessThanMaxItemsAndDeliveryTimeLessThanOneDayAndBeforeEnd)		

>C7.		**F**(OrderWithLessThanEnoughMoneyForPendingOrders)
	
>C8. [ContractNotTerminated]**F**(DeliveryWithPaymentLessThanCost)	

>C9.		[TerminateContractWithPendingOrdersOrQuarterLateOrders]**O**(SendGuaranteeToBuyer)&[TerminateContractWithoutPendingOrdersAndQuarterLateOrders]**O**(SendGuaranteeToSeller)

>ProcurementContract = rec X. [¬Ψ]((C4 & C5) ; X)  &  [¬Ψ](rec Y. (C1 & C2 & C3 & C6 & C7 & C8 & C9); Y)

>*where* Ψ = EnactmentAndSellerAcceptanceWithEnoughInEscrow









<!---
_C1. **P**(terminateContract | msg.sender ∈ {seller, buyer} ∧ clauses2And3NotApplicable)_

_C2. **F**(terminateContract | itemsOrdered < minItems ∨ maxItems < itemsOrdered)_

_C3. **F**(terminateContract | now < endOfContractTimestamp) & **F**(terminateContract | msg.sender = seller & pendingOrdersCount \neq 0)_
		
_C4. **F**(enactment | msg.value < minItems*costPerUnit)_
		
_C5. **F**(sellerAcceptsContract | msg.value < guarantee) ▷ **O**(returnEscrow)_
		 

_C6. [\neg terminateContract<sup>Y</sup>]**P**(order(no, size, byTime) | itemsOrdered ≤ maxItems ∧ byTime < 24 hours ∧ now + byTime ≤ endTime)_
		

_C7. **F**(order(no, size, time) | this.balance - performanceGuarantee < pendingOrders*costPerUnit)_
	
_C8. [\neg terminateContract<sup>Y</sup>]**F**(delivery(no) | balanceBefore \neq balanceAfter + orders[no].cost)_

_C9. [terminateContract<sup>Y</sup> | pendingOrders \neq 0 ∨ lateOrders ≥ 0.25*(pendingOrder + inTimeOrders + lateOrders)]**O**(sendGuaranteeToBuyer)_
    _& [terminateContract<sup>Y</sup> | \neg(pendingOrders \neq 0 ∨ lateOrders ≥ 0.25*(pendingOrder + inTimeOrders + lateOrders))]**O**(sendGuaranteeToSeller)_

__Full Contract:__

_ProcurementContract = \recursion X. [¬ Ψ]((C4 & C5) ; X) & [Ψ](rec Y. (C1 & C2 & C3 & C6 & C7 & C8 & C9);Y)_

_where Ψ = enactment<sup>Y</sup> ∧ (sellerAcceptsContract<sup>Y</sup> | msg.value ≥ guarantee)*_ --->
