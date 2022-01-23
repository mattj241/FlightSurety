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
    mapping(address => bool) isAddressAuthorized;

    address[] private airlines;         
    mapping(address => bool) isAirline; // mapping makes the isAirline modifier simple to understand
    mapping(address => bool) isAirlineFeePaid;

    address[] private passengers;
    mapping(address => bool) isPassenger;
    mapping(address => uint256) passengerBalance;

    bytes32[] private flightKeys; //airline, flightName, timestamp
    mapping(bytes32 => Flight) private flights;

    struct Insurance
    {
        address passenger;
        uint256 amountInsured;
        uint256 amountPayout;
    }
    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        address airline;
        string flightName;
        uint256 updatedTimestamp;
    }

    mapping(bytes32 => Insurance[]) insurances;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    event dataContractFunded();

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor()
        payable
    {
        contractOwner = msg.sender;
        isAddressAuthorized[contractOwner] = true;
        isAddressAuthorized[address(this)] = true;
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
        require(isAddressAuthorized[msg.sender], "Caller is not authorized");
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
        isAddressAuthorized[inputAddress] = true;
    }

    function removeAuthorizedCaller (address inputAddress) 
        external 
        requireContractOwner
    {
        isAddressAuthorized[inputAddress] = false;
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

    function getAirline(uint index)
        external
        view
        requireIsOperational
        returns(address)
    {
        return airlines[index];
    }

    function isCallerAuthorized(address inputAddress)
        external
        view
        requireIsOperational
        returns(bool)
    {
        return isAddressAuthorized[inputAddress];
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

    function getInsurancePayoutAmount(address passenger)
        external
        view
        requireIsOperational
        requireCallerIsAuthorized
        returns(uint256)
    {
        return passengerBalance[passenger];
    }

    function getNumAirlines()
        external
        view
        requireIsOperational
        requireCallerIsAuthorized
        returns(uint)
    {
        return airlines.length;
    }

    function getContractOwner()
        external
        view
        returns(address)
    {
        return contractOwner;
    }

    function getFlightKey(address airline, string memory flight, uint256 timestamp)
        pure
        internal
        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    function getFlightKeysForUI()
        public
        view
        returns(bytes32[] memory)
    {
        return flightKeys;
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
        requireCallerIsAuthorized
        external
    {
        airlines.push(airlineAddress);
        isAirline[airlineAddress] = true;
        isAirlineFeePaid[airlineAddress] = false;
        isAddressAuthorized[airlineAddress] = true;
    }

    function registerFirstAirline(address initialAirline) 
        requireIsOperational 
        external
    {
        require(airlines.length <= 0, "This function can only be used once");
        airlines.push(initialAirline);
        isAirline[initialAirline] = true;
        isAirlineFeePaid[initialAirline] = false;
        isAddressAuthorized[initialAirline] = true;

        // emit airline registration in dataContract only for initial airline
        // emit airlineRegistered(initialAirline);
    }

    function payAirlineFee(address airlineAddress)
        requireIsOperational
        requireCallerIsAuthorized
        external 
    {
        isAirlineFeePaid[airlineAddress] = true;
    }

    function registerPassenger(address passengerAddress) 
        requireIsOperational 
        requireCallerIsAuthorized
        external
    {
        passengers.push(passengerAddress);
        isPassenger[passengerAddress] = true;
        passengerBalance[passengerAddress] = 0;
    }

    function registerFlight(address airline, string memory flightName, uint256 timestamp) 
        requireIsOperational 
        requireCallerIsAuthorized
        external
        returns (bytes32)
    {
        bytes32 flightKey = getFlightKey(airline, flightName, timestamp);
        flightKeys.push(flightKey);
        flights[flightKey] = Flight(true, 0, airline, flightName, timestamp);
        return flightKey;
    }

    function getFlightInfo(bytes32 flightKey)
        requireIsOperational 
        requireCallerIsAuthorized
        external
        view
        returns (address, string memory, uint256)
    {
        address airline = flights[flightKey].airline;
        string memory name = flights[flightKey].flightName;
        uint256 timeStamp = flights[flightKey].updatedTimestamp;
        return (airline, name, timeStamp);
    }

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy(address passenger, string memory flightName, uint256 value, address airline, uint256 timeStamp)                             
        requireIsOperational 
        requireCallerIsAuthorized
        external
    {
        bytes32 flightKey = getFlightKey(airline, flightName, timeStamp);
        Insurance memory newInsurance;
        newInsurance.passenger = passenger;
        newInsurance.amountInsured = value;

        uint256 insuranceBonus = value / 2;
        newInsurance.amountPayout = value + insuranceBonus;
        insurances[flightKey].push(newInsurance);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees(address airline, string memory flight, uint256 timestamp)
        requireIsOperational 
        requireCallerIsAuthorized
        external
    {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        for (uint8 i = 0; i < insurances[flightKey].length; i++)
        {
            address passengerToCredit = insurances[flightKey][i].passenger;
            uint256 amountToCredit = insurances[flightKey][i].amountPayout;
            passengerBalance[passengerToCredit] = amountToCredit;
            insurances[flightKey][i].amountPayout = 0;
        }
    }

    function claimInsurance(address passenger)
        requireIsOperational 
        requireCallerIsAuthorized
        payable
        external
    {
        require(passengerBalance[passenger] > 0, "There is nothing to claim");
        uint256 payout = passengerBalance[passenger];
        passengerBalance[passenger] = 0;

        address payable payablePassenger = payable(address(passenger));
        safeTransfer(payablePassenger, payout);
    }
    

    //https://solidity-by-example.org/sending-ether/
    function safeTransfer(address payable _to, uint256 _amount)
        requireIsOperational
        payable 
        public
    {
        //https://solidity-by-example.org/sending-ether/
        (bool sent, bytes memory data) = _to.call{value: _amount}("");
        require(sent, "Failed to send Ether");
    }

    function fund()
        payable
        external
    {
        safeTransfer(payable(address(this)), msg.value);
    }

    fallback() external payable 
    {
        // emit dataContractFunded();
    }

    receive() external payable
    {
        // emit dataContractFunded();
    }
}

