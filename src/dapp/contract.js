import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.flightSuretyData = new this.web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
    }

    registerAirlines(callback) {
        let self = this;
        let counter = 0;
        for(counter; counter < this.airlines.length; counter++)
        {
            let payload = {
                inputAirlineAddress : this.airlines[counter]
            }
            self.flightSuretyApp.methods
                .registerAirline(payload.inputAirlineAddress)
                .send({ from: self.owner, gas: 3000000 }, (error, result) => {
                    callback(error, payload);
                });
        }
    }

    registerPassengers(callback) {
        let self = this;
        let counter = 0;
        for(counter; counter < this.passengers.length; counter++)
        {
            let payload = {
                inputPassengerAddress : this.passengers[counter]
            }
            self.flightSuretyApp.methods
                .registerPassenger(payload.inputPassengerAddress)
                .send({ from: self.owner, gas: 3000000 }, (error, result) => {
                    callback(error, payload);
                });
        }
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {
           
            this.owner = accts[0];

            let counter = 1;
            
            while(this.airlines.length < 3) {
                this.airlines.push(accts[counter++]);
            }

            while(this.passengers.length < 3) {
                this.passengers.push(accts[counter++]);
            }

            callback();
        });
    }

    loadDefaultData(callback){
        let self = this;
        let defaultFlightnames = ['Delta 1080', 'Spirit 123444', 'United 24'];
        //                     roughly 1 day from now,         2 days,             3 days
        let defaultFlightTimes = [Date.now() + 86000, Date.now() + 172000, Date.now() + 258000 ];
        let payload = {
            defaultAirlines : self.airlines,
            defaultPassengers : self.passengers,
            defaultFlightNames : defaultFlightnames,
            defaultTimeStamps :  defaultFlightTimes
        }
        self.flightSuretyApp.methods
            .loadDefaultContractDataForUIDemo(payload.defaultAirlines, payload.defaultPassengers, payload.defaultFlightNames, payload.defaultTimeStamps)
            .send({ from: self.owner, gas: 3000000 }, (error, result) => {
                callback(error, payload);
                console.log(self.owner);
            });
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

     getFlightInfoByIndex(index, callback) {
        let self = this;
        let payload = {
            flightIndex: index
        }
        self.flightSuretyApp.methods
             .getFlightInfoByIndex(payload.flightIndex)
             .call({ from: self.owner, gas: 3000000}, (error, result) => {
                callback(error, result);
            });
     }

     getAllFlights(callback) {
        let self = this;
        self.flightSuretyApp.methods
             .getAllFlights()
             .call({ from: self.owner, gas: 3000000}, (error, result) => {
                callback(error, result);
            });
     }

     submitInsuranceRequest(flightAddress, flightName, timeStamp, amountEther, callback) {
         let self = this;
         self.flightSuretyApp.methods
            .passengerBuysInsurance(flightAddress, flightName, timeStamp)
            .call({from: self.passengers[0], gas: 3000000, value: amountEther}, (error, result) => {
                callback(error, result);
            });
     }

    fetchFlightStatus(flight, airline, callback) {
        let self = this;
        let payload = {
            airline: airline,
            flight: flight,
            timestamp: Math.floor(Date.now() / 1000)
        } 
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner, gas: 3000000}, (error, result) => {
                callback(error, payload);
            });
    }
}