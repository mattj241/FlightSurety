//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./FlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    FlightSuretyData private dataContract;

    // address[] private queuedAirlines;
    mapping(address => bool) isAirlineQueued; 

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }
    mapping(bytes32 => Flight) private flights;

    uint8 private constant NUM_CONSENSUS_MIN = 4;
    uint8 private constant CONSENSUS_FACTOR = 2; //Multi-party consensus divising factor (ex: 2 = 50%, 4 = 25%, etc...)
    uint256 private constant INSURANCE_LIMIT = 1000000000000000000; //1 ether
    uint256 private constant AIRLINE_FUNDING_FEE = 10000000000000000000; //10 ether
        
    mapping(address => mapping (address => bool)) voteCasted;
    mapping(address => uint256) voteTotal; 

    /********************************************************************************************/
    /*                                            EVENTS                                        */
    /********************************************************************************************/

    // event AirlineQueued(address airline);
    event airlineRegistered(address airline);
    event airlineFeesPaid(address airline);
    event passengerRegistered(address passenger);
    event flightRegistered(address airline, string flightName, uint256 timestamp);
    event passengerBoughtInsurance(address passengerAddress, address flightAddress, string flightName, uint256 insuranceAmount);
 
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
         // Modify to call data contract's status
        bool operationalStatus = isOperational();
        require(operationalStatus == true, "Contract is currently not operational");  
        _;
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireIsAirline(address inputAddress)
    {
        bool isAirline = isAddressAirline(inputAddress);
        require(isAirline == true, "Address not a registered airline");
        _;
    }

    modifier requireIsPassenger(address inputAddress)
    {
        bool isPassenger = isAddressPassenger(inputAddress);
        require(isPassenger == true, "Caller is not a passenger");
        _;
    }

    // modifier requireIsFlight(address inputAddress)
    // {
    //     bool isFlight = isAddressFlight(inputAddress);
    //     require(isFlight == true, "Address is not a flight");
    //     _;
    // }

    modifier requireIsFundedAirline(address inputAddress)
    {
        bool isFundedAirline = isAddressFundedAirline(inputAddress);
        require(isFundedAirline == true, "Address not a funded airline");
        _;
    }

    modifier requireIsNotAirline(address inputAddress)
    {
        bool isAirline = isAddressAirline(inputAddress);
        require(isAirline == false, "Address already a airline");
        _;
    }

    modifier requireIsNotPassenger(address inputAddress)
    {
        bool isPassenger = isAddressPassenger(inputAddress);
        require(isPassenger == false, "Address already a Passenger");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor(address payable flightSuretyDataContract)
    {
        dataContract = FlightSuretyData(flightSuretyDataContract);
        contractOwner = msg.sender;

        //contractOwner is the first airline
        registerInitialAirline(contractOwner);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
        public 
        view 
        returns(bool) 
    {
        return dataContract.isOperational();
    }

    function setOperatingStatus(bool newStatus) 
        public 
        requireIsOperational
        requireContractOwner
    {
        dataContract.setOperatingStatus(newStatus);
    }

    function isAddressAirline(address inputAddress) 
        public
        view
        returns(bool)
    {
        return dataContract.isAddressAirline(inputAddress);
    }

    function isAddressQueuedAirline(address inputAddress) 
        public
        view
        returns(bool)
    {
        return isAirlineQueued[inputAddress];
    }

    function isAddressFundedAirline(address inputAddress) 
        public
        view
        returns(bool)
    {
        return dataContract.isAddressFundedAirline(inputAddress);
    }

    function isAddressPassenger(address inputAddress) 
        public
        view
        returns(bool)
    {
        return dataContract.isAddressPassenger(inputAddress);
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline(address inputAirlineAddress)
        public
        requireIsOperational
        requireIsNotAirline(inputAirlineAddress)
        requireIsNotPassenger(inputAirlineAddress)
    {
        uint airlinesCount = dataContract.getNumAirlines();

        if (airlinesCount < NUM_CONSENSUS_MIN)
        {
            require(isAddressFundedAirline(msg.sender), "Must be an airline to submit another airline when total airlines are below the minimum for consensus");
            dataContract.registerAirline(inputAirlineAddress);
            emit airlineRegistered(inputAirlineAddress);
        }
        else
        {

            if (voteCasted[msg.sender][inputAirlineAddress] == false)
            {
                voteCasted[msg.sender][inputAirlineAddress] = true;
                voteTotal[inputAirlineAddress] += 1;
                if(voteTotal[inputAirlineAddress] >= (airlinesCount / CONSENSUS_FACTOR))
                {
                    dataContract.registerAirline(inputAirlineAddress);
                    isAirlineQueued[inputAirlineAddress] = false;
                    emit airlineRegistered(inputAirlineAddress);
                }
                else
                {
                    isAirlineQueued[inputAirlineAddress] = true;
                }
            }
            else
            {
                isAirlineQueued[inputAirlineAddress] = true;
            }
        }
    }

    function registerInitialAirline(address inputAirlineAddress)
        public
        requireIsOperational
        requireContractOwner
    {
        dataContract.registerFirstAirline(inputAirlineAddress);
        emit airlineRegistered(inputAirlineAddress);
    }

    function payAirlineFee()
        public
        payable
        requireIsOperational
        requireIsAirline(msg.sender)
    {
        require(!(isAddressFundedAirline(msg.sender)), "Airline is already funded!");
        require(msg.value >= AIRLINE_FUNDING_FEE, "Supplied ether doesn't meet the funding fee");
        address payable payableContract = payable(address(dataContract));

        uint256 changeToSendBack = msg.value - AIRLINE_FUNDING_FEE; 
        if (changeToSendBack > 0)
        {
            safeTransfer(payableContract, AIRLINE_FUNDING_FEE);
            safeTransfer(payable(msg.sender), changeToSendBack);
        }
        else
        {
            safeTransfer(payableContract, AIRLINE_FUNDING_FEE);
        }
        dataContract.payAirlineFee(msg.sender);
        emit airlineFeesPaid(msg.sender);
    }

    function registerPassenger(address inputPassengerAddress)
        public
        requireIsOperational
        requireIsNotAirline(inputPassengerAddress)
        requireIsNotPassenger(inputPassengerAddress)
    {
        bool isPassenger = isAddressPassenger(inputPassengerAddress);
        require(isPassenger == false, "An address can not be doubled up as airline and passenger");
        dataContract.registerPassenger(inputPassengerAddress);
        emit passengerRegistered(inputPassengerAddress);
    }

    function registerPassengerContractOwner(address inputPassengerAddress)
        public
        requireIsOperational
        // requireContractOwner
    {
        require(dataContract.isAddressPassenger(inputPassengerAddress) == false, "address is already a passenger!");
        dataContract.registerPassenger(inputPassengerAddress);
        //emit passengerRegistered(inputPassengerAddress);
    }

    function registerFlight(string memory flightName, uint256 timestamp)
        public
        requireIsOperational
        requireIsAirline(msg.sender)
        returns(bytes32)
    {
        bytes32 flightKey = dataContract.registerFlight(msg.sender, flightName, timestamp);
        emit flightRegistered(msg.sender, flightName, timestamp);
        return flightKey;
    }

    function getFlightInfo(bytes32 flightKey)
        public
        view
        requireIsOperational
        returns (address, string memory, uint256)
    {
        (address airline, string memory flightName, uint256 timeStamp) = dataContract.getFlightInfo(flightKey);
        return (airline, flightName, timeStamp);
    }

    function passengerBuysInsurance(address airlineAddress, string memory flightName, uint256 timeStamp)
        public
        payable
        requireIsOperational
        requireIsPassenger(msg.sender)
    {
        require(msg.value <= INSURANCE_LIMIT, "Insurance Contributions may not exceed 1 ether");
        address payable payableContract = payable(address(dataContract));
        safeTransfer(payableContract, msg.value);

        dataContract.buy(msg.sender, flightName, msg.value, airlineAddress, timeStamp);
        emit passengerBoughtInsurance(msg.sender, airlineAddress, flightName, msg.value);
    }

    function claimInsurancePayout()
        public
        payable
        requireIsOperational
        requireIsPassenger(msg.sender)
    {
        dataContract.claimInsurance(msg.sender);
    }

    //https://solidity-by-example.org/sending-ether/
    function safeTransfer(address payable _to, uint256 _amount)
        public
        payable
        requireIsOperational
    {
        (bool sent, bytes memory data) = _to.call{value: _amount}("");
        require(sent, "Failed to send Ether");
    }

    receive() 
        external 
        payable
    {
        //safeTransfer(payable(address(dataContract)), msg.value);
    }

    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus(
        address airline, string memory flight,
        uint256 timestamp, uint8 statusCode)
        public
    {
        if (    statusCode == STATUS_CODE_LATE_AIRLINE )
            // ||  statusCode == STATUS_CODE_LATE_WEATHER
            // ||  statusCode == STATUS_CODE_LATE_TECHNICAL)
            {
                dataContract.creditInsurees(airline, flight, timestamp);
            }
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus( address airline, string memory flight, uint256 timestamp )
        external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    }


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
    }

    //suggested by user "Yarode" in FlightSurety Template:
    //https://github.com/yarode/FlightSurety/commit/cd75f8017e769280d7216ffb3603d97f3903552f
    mapping(bytes32 => mapping(uint8 => address[])) private responsesByType;    // Mapping key is the status code reported
                                                                                // This lets us group responses and identify
                                                                                // the response that majority of the oracles

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle()
        external
        payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes()
        view
        external
        returns(uint8[3] memory)
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }


    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(uint8 index, address airline,
        string memory flight, uint256 timestamp, uint8 statusCode)
        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        //suggested by user "Yarode" in FlightSurety Template:
        //https://github.com/yarode/FlightSurety/commit/cd75f8017e769280d7216ffb3603d97f3903552f
        responsesByType[key][statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);

        //suggested by user "Yarode" in FlightSurety Template:
        //https://github.com/yarode/FlightSurety/commit/cd75f8017e769280d7216ffb3603d97f3903552f
        if (responsesByType[key][statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
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

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3] memory)
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   
