
// var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');
var FlightSuretyApp = artifacts.require("FlightSuretyApp");
var FlightSuretyData = artifacts.require("FlightSuretyData");
const Web3 = require('web3');

let flightSuretyData = null;
let flightSuretyApp = null;
const NUM_CONSENSUS_MIN = 4;
const CONSENSUS_FACTOR = 2; //Multi-party consensus divising factor (ex: 2 = 50%, 4 = 25%, etc...)
const insurance_limit = Web3.utils.toWei("1","ether");
const funding_fee = Web3.utils.toWei("10","ether");
const STATUS_CODE_UNKNOWN = 0;
const STATUS_CODE_ON_TIME = 10;
const STATUS_CODE_LATE_AIRLINE = 20;
const STATUS_CODE_LATE_WEATHER = 30;
const STATUS_CODE_LATE_TECHNICAL = 40;
const STATUS_CODE_LATE_OTHER = 50;


contract('Flight Surety Tests', async (accounts) => {

    let owner = accounts[0];
    let airline2 = accounts[1];
    let airline3 = accounts[2];
    let airline4 = accounts[3];
    let airline5 = accounts[4];
    let passenger = accounts[5];
    let globalFlightName = "Spirit 777";
    let globalFightKey;
    let globalTimeStamp;
    var BN = web3.utils.BN;

    let testAddresses = [
        "0x69e1CB5cFcA8A311586e3406ed0301C06fb839a2",
        "0xF014343BDFFbED8660A9d8721deC985126f189F3",
        "0x0E79EDbD6A727CfeE09A2b1d0A59F7752d5bf7C9",
        "0x9bC1169Ca09555bf2721A5C9eC6D69c8073bfeB4",
        "0xa23eAEf02F9E0338EEcDa8Fdd0A73aDD781b2A86",
        "0x6b85cc8f612d5457d49775439335f83e12b8cfde",
        "0xcbd22ff1ded1423fbc24a7af2148745878800024",
        "0xc257274276a4e539741ca11b590b9447b26a8051",
        "0x2f2899d6d35b1a48a4fbdc93a37a72f264a9fca7"
    ];

  before('setup contract', async () => {
    flightSuretyData = await FlightSuretyData.new( {from:owner});
    flightSuretyApp = await FlightSuretyApp.new(flightSuretyData.address, {from:owner});
    await flightSuretyData.addAuthorizedCaller(flightSuretyApp.address, {from:owner});
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await flightSuretyData.isOperational.call();
    let testOwner = await flightSuretyData.getContractOwner();
    assert.equal(status, true, "Incorrect initial operating status value");
    assert.equal(owner, testOwner);
  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await flightSuretyData.setOperatingStatus(false, { from: testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await flightSuretyData.setOperatingStatus(false, { from: owner });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");

      await flightSuretyData.setOperatingStatus(true, { from: owner });
  });

  it(`(multiparty) is the app contract an authorizedCaller`, async function () {

    let result = await flightSuretyData.getAirline(0);
    assert.equal(owner,result);

    let reverted = false;
    try 
    {
      await flightSuretyData.getNumAirlines({from: flightSuretyApp.address});
    }
    catch(e) {
        reverted = true;
    }
    assert.equal(reverted, false, "App Contract is not authorized");
});

  it(`(multiparty) add authorizedCaller functionality`, async function () {

      //Ensure only the contractOwner can grant authorizedCallers
      let reverted = false;
      try 
      {
        await flightSuretyData.getNumAirlines({from: flightSuretyApp.address});
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, false, "App Contract is not authorized");

  });

  it('(airline) cannot register an Airline when the caller is not a an airline and # of airlines is below 4', async () => {
        
    let airline2 = accounts[1];
    // ARRANGE

    // ACT
    let revert = false;
    try {
        await flightSuretyApp.registerAirline(airline2, {from: accounts[10]});
    }
    catch(e) {
        revert = true
    }

    //ASSERT
    assert.equal(revert, true, "Airlines cannot be added by a non airline when the count is low");
  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
        
    // ARRANGE
    let newAirline = testAddresses[1];

    // ACT
    let revert = false;
    try {
        await flightSuretyApp.registerAirline(newAirline, {from: owner});
    }
    catch(e) {
        revert = true
    }

    //ASSERT
    assert.equal(revert, true, "Airline should not be able to register another airline if it hasn't provided funding");
  });

  it('(airline) fund the first airline', async () => {

    let firstBalance = await web3.eth.getBalance(flightSuretyData.address);
    
    let isFunded = await flightSuretyApp.isAddressFundedAirline(owner);

    assert.equal(isFunded, false, "Airline should not be considered funded yet");
    
    // ARRANGE
    await flightSuretyApp.payAirlineFee({from: owner, value: funding_fee});

    isFunded = await flightSuretyApp.isAddressFundedAirline(owner);

    let secondBalance = await web3.eth.getBalance(flightSuretyData.address);
    let sum = new BN(firstBalance).add(new BN(funding_fee));
    //ASSERT
    assert.equal(isFunded, true, "Airline should have been considered funded");
    assert.deepEqual(secondBalance, sum.toString(), "dataContract should have been transfered eth for funding");
  });
 
  it('(airline) 5th registered Airline becomes queued', async () => {
        
    // ARRANGE

    await flightSuretyApp.registerAirline(airline2, {from: owner});
    await flightSuretyApp.registerAirline(airline3, {from: owner});
    await flightSuretyApp.registerAirline(airline4, {from: owner});

    await flightSuretyApp.payAirlineFee({from: airline2, value: funding_fee});
    await flightSuretyApp.payAirlineFee({from: airline3, value: funding_fee});
    await flightSuretyApp.payAirlineFee({from: airline4, value: funding_fee});
    // await flightSuretyApp.payAirlineFee({from: airline5, value: funding_fee});

    await flightSuretyApp.registerAirline(airline5, {from: owner});

    let result1 = await flightSuretyApp.isAddressAirline(airline5);
    let result2 = await flightSuretyApp.isAddressQueuedAirline(airline5);

    //ASSERT
    assert.equal(result1, false, "Airline should not be in the real airline list yet");
    assert.equal(result2, true, "Airline should be in the queued airline list");
  });

  it('(airline) 5th registered Airline becomes queued and must be voted on by other airlines', async () => {
        
    // ARRANGE
    
    await flightSuretyApp.registerAirline(airline5, {from: airline2});
    // await flightSuretyApp.registerAirline(airline5, {from: airline3});
    // await flightSuretyApp.registerAirline(airline5, {from: airline4});

    // await flightSuretyApp.payAirlineFee({from: airline2, value: funding_fee});
    // await flightSuretyApp.payAirlineFee({from: airline3, value: funding_fee});
    // await flightSuretyApp.payAirlineFee({from: airline4, value: funding_fee});
    // await flightSuretyApp.payAirlineFee({from: airline5, value: funding_fee});

    // await flightSuretyApp.registerAirline(airline5, {from: owner});

    let result1 = await flightSuretyApp.isAddressAirline(airline5);
    let result2 = await flightSuretyApp.isAddressQueuedAirline(airline5);

    //ASSERT
    assert.equal(result1, true, "Airline should be in the real airline list");
    assert.equal(result2, false, "Airline should not be in the queued airline list anymore");
  });

  it('(flights) List a flight by an airline', async () => {
        
    // ARRANGE
    let revert1 = false;
    globalTimeStamp = BigNumber(Date.now() + 100000);
    try {
        await flightSuretyApp.registerFlight(globalFlightName, globalTimeStamp, {from: passenger});
    } catch (error) {
        revert1 = true;
    }
    let revert2 = false;
    try {
        globalFightKey = await flightSuretyApp.registerFlight(globalFlightName, globalTimeStamp, {from: airline2});
    } catch (error) {
        revert2 = true;
    }

    //ASSERT
    assert.equal(revert1, true, "Passengers should not prepare flights");
    assert.equal(revert2, false, "Airlines should be able to make flights");
  });

  it('(passengers) Passenger Buys Insurance and collects payout', async () => {
        
    // ARRANGE
    let originalBalance = new BN(await web3.eth.getBalance(passenger));

    await flightSuretyApp.registerPassenger(passenger, {from: passenger});

    await flightSuretyApp.passengerBuysInsurance(airline2, globalFlightName, globalTimeStamp, {from: passenger, value:insurance_limit});

    await flightSuretyApp.processFlightStatus(airline2, globalFlightName, globalTimeStamp, STATUS_CODE_LATE_AIRLINE);

    await flightSuretyApp.claimInsurancePayout({from: passenger});

    let newBalance = new BN(await web3.eth.getBalance(passenger));

    assert.notEqual(newBalance.toString(), originalBalance.toString(), "Unexepected wallet balance occured")
  });
 
});
