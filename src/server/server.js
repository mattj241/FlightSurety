import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';
require("babel-polyfill");

//Inspiration of server.js comes from josancamon19 (https://github.com/josancamon19/FlightSurety)
let provider;
let web3;
let accounts;
let flightSuretyApp;
const status_code = [0, 10, 20, 30, 40, 50];

async function initWeb3() {
  let config = Config['localhost'];
  let url = config.url.replace('http', 'ws');
  provider = new Web3.providers.WebsocketProvider(url, {});
  web3 = new Web3(provider);
  accounts = await web3.eth.getAccounts();
  flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
}

const oracles = [];

async function submitOracleResponse(data, account) {

  let statusCode = status_code[Math.floor(Math.random() * status_code.length)];
  console.log(data.oracleIndex, data.airline, data.flight, data.timestamp, statusCode);

  try {
      await flightSuretyApp.methods.submitOracleResponse(
          oracleIndex,
          airline,
          flight,
          timestamp,
          statusCode
      ).send({
          from: account
      });
  } catch (e) {
      console.log("error " + e.reason);
  }
}

async function listenRequests() {
  flightSuretyApp.events.OracleRequest({}, function (error, event) {
      if (error)
      {
        console.log("error: " + error)
      }
      if (event)
      {
        for (let i = 0; i < oracles.length; i++) {
            submitOracleResponse(event.returnValues, oracles[i]);
            console.log(event.returnValues);
        }
      }
  });

}

async function registerOracles() {
  let fee = await flightSuretyApp.methods.REGISTRATION_FEE().call();
  let oracleLimit = 20;
  console.log('Oracle registration Fee:', fee);
  for (let i = 0; i < accounts.length && oracles.length < oracleLimit; i++) {
      try {
          await flightSuretyApp.methods.registerOracle().send({
              from: accounts[i],
              value: fee,
              gas: 3000000
          });
          oracles.push(accounts[i]);
          console.log(`Oracle ${i} registered.`);
      } catch (e) {
          // console.log(e);
      }
  }

  console.log(`Registered Oracles: ${oracles.length}`);
}

async function init() {
  try {
      await initWeb3();
      await registerOracles();
      listenRequests();
  } catch (e) {
      console.log(e);
      provider.disconnect();
  }
}

init();

const app = express();
app.get('/', (req, res) => {});


