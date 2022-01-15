//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/
    address private contractOwner;      // Account used to deploy contract
    bool private operational = true;    // Blocks all state changes throughout the contract if false
    mapping(address => bool) isAppContractAuthorized;

    address[] private airlines;         
    uint numAirlines; 
    mapping(address => bool) isAirline; // mapping makes the isAirline modifier simple to understand
    mapping(address => bool) isAirlineFeePaid;

    address[] private passengers;
    mapping(address => bool) isPassenger;
    mapping(address => uint256) passengerBalance;

    address[] private flights;
    mapping(address => bool) isFlight;

    struct Insurance
    {
        // address passenger;
        // address flight;
        uint256 amountInsured;
        uint256 amountPayout;
        bool    repaymentGranted;
    }
    mapping(address => mapping(address => Insurance)) insurances;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor()
    {
        contractOwner = msg.sender;
        airlines.push(msg.sender);
        isAirline[msg.sender] = true;
        isAirlineFeePaid[msg.sender] = false;
        numAirlines = 1;
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireCallerIsAuthorized()
    {
        require(isAppContractAuthorized[msg.sender], "Caller is not authorized");
        _;
    }

    /**
    * @dev Modifier that requires only registered airlines can call this function
    */
    modifier requireIsAirline(address inputAddress) 
    {
        require(isAirline[inputAddress], "The supplied address is not an airline, cannot use this function");
        _;
    }

    modifier requireIsAirlineFeePaid(address inputAddress)
    {
        require(isAirlineFeePaid[inputAddress], "The supplied address is not a funded airline, cannot use this function");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
        public 
        view 
        returns(bool)
    {
        return operational;
    }

    function addAuthorizedCaller (address inputAddress) 
        external 
        requireContractOwner
    {
        isAppContractAuthorized[inputAddress] = true;
    }

    function removeAuthorizedCaller (address inputAddress) 
        external 
        requireContractOwner
    {
        isAppContractAuthorized[inputAddress] = false;
    }

    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus(bool mode)
        external
        requireContractOwner 
    {
        operational = mode;
    }

    function isAddressAirline(address inputAddress)
        external
        view
        requireIsOperational
        returns(bool)
    {
        return isAirline[inputAddress];
    }

    function isAddressAuthorized(address inputAddress)
        external
        view
        requireIsOperational
        returns(bool)
    {
        return isAppContractAuthorized[inputAddress];
    }

    function isAddressFundedAirline(address inputAddress)
        external
        view
        requireIsOperational
        requireIsAirline(inputAddress)
        returns(bool)
    {
        return isAirlineFeePaid[inputAddress];
    }

    function isAddressPassenger(address inputAddress)
        external
        view
        requireIsOperational
        returns(bool)
    {
        return isPassenger[inputAddress];
    }

    function isAddressFlight(address inputAddress)
        external
        view
        requireIsOperational
        returns(bool)
    {
        return isFlight[inputAddress];
    }

    function isInsuranceCollectable(address passenger, address flight)
        external
        view
        requireIsOperational
        returns(bool)
    {
        return insurances[passenger][flight].repaymentGranted;
    }

    function getInsurancePayoutAmount(address passenger, address flight)
        external
        view
        requireIsOperational
        // requireCallerIsAuthorized
        returns(uint256)
    {
        return insurances[passenger][flight].amountPayout;
    }

    function getNumAirlines()
        external
        view
        requireIsOperational
        // requireCallerIsAuthorized
        returns(uint)
    {
        return numAirlines;
    }

    function getContractOwner()
        external
        view
        returns(address)
    {
        return contractOwner;
    }

    function getAuthCaller(address input)
        external
        view
        returns(bool)
    {
        return isAppContractAuthorized[input];
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline(address airlineAddress) 
        requireIsOperational 
        // requireCallerIsAuthorized
        external
    {
        airlines.push(airlineAddress);
        isAirline[airlineAddress] = true;
        isAirlineFeePaid[airlineAddress] = false;
        isAppContractAuthorized[airlineAddress] = true;
        numAirlines += 1;
    }

    function payAirlineFee(address airlineAddress)
        requireIsOperational
        // requireCallerIsAuthorized
        // requireIsAirline(msg.sender)
        external 
    {
        // require(msg.sender == airlineAddress, "An airline can only pay for their own funding fee");
        isAirlineFeePaid[airlineAddress] = true;
    }

    function registerPassenger(address passengerAddress) 
        requireIsOperational 
        // requireCallerIsAuthorized
        external
    {
        passengers.push(passengerAddress);
        isPassenger[passengerAddress] = true;
    }

    function registerFlight(address flightAddress) 
        requireIsOperational 
        // requireCallerIsAuthorized
        external
    {
        flights.push(flightAddress);
        isFlight[flightAddress] = true;
    }

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy(address passenger, address flight, uint256 value)                             
        requireIsOperational 
        // requireCallerIsAuthorized
        // payable
        external
    {
        insurances[passenger][flight].amountInsured = value;

        uint256 insuranceBonus = value / 2;
        insurances[passenger][flight].amountPayout = value + insuranceBonus;
        insurances[passenger][flight].repaymentGranted = false;
    }

    function setRepaymentStatus(address passenger, address flight, bool status)
        requireIsOperational 
        // requireCallerIsAuthorized
        external
    {
        insurances[passenger][flight].repaymentGranted = status;
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees(address passenger, address flight)
        requireIsOperational 
        // requireCallerIsAuthorized
        payable
        external
    {
        require(insurances[passenger][flight].repaymentGranted == true, "Not authorized for repayment");
        uint256 payoutAmount = insurances[passenger][flight].amountPayout;
        insurances[passenger][flight].amountPayout = 0;
        insurances[passenger][flight].repaymentGranted = false;
        
        address payable payablePassenger = payable(address(passenger));
        payablePassenger.transfer(payoutAmount);
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    // function pay(address passenger, address flight)
    //     requireIsOperational 
    //     // requireCallerIsAuthorized
    //     payable
    //     external
    // {
    //     require(insurances[passenger][flight].repaymentGranted == true, "payment not authorized");

    // }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund() 
        requireIsOperational 
        // requireIsAirline
        // payable 
        public
    {
        // airlineBalances.
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    fallback() external payable 
    {
        fund();
    }

    //suggested by user "Yarode" in FlightSurety Template:
    //https://github.com/yarode/FlightSurety/commit/cd75f8017e769280d7216ffb3603d97f3903552f
    /**
    * @dev Receive function for funding smart contract
    *
    */
    receive() external payable
    {
        fund();
    }
}

