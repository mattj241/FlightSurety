import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
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
        this.flights = [];
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

    registerFlights(callback) {
        let defaultFlightNames = ['Delta 1080', 'Spirit 123444', 'United 24', 'Ryanair 1500']
        let self = this;
        let counter = 0;
        for(counter; counter < this.flights.length; counter++)
        {
            let payload = {
                inputFlightAddress : this.flights[counter],
                flightName : defaultFlightNames[counter]
            }
            self.flightSuretyApp.methods
                .registerFlight(payload.inputFlightAddress, payload.flightName)
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

            while(this.flights.length < 3) {
                this.flights.push(accts[counter++]);
            }

            callback();
        });
    }

    loadDefaultData(callback){
        let self = this;
        self.registerAirlines(callback);
        self.registerPassengers(callback);
        self.registerFlights(callback);
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    // getNumFlights(callback) {
    //     let self = this;
    //     self.flightSuretyApp.methods
    //          .getNumFlights()
    //          .call({ from: self.owner, gas: 3000000}, callback);
    //  }

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

     getFlightInfo(callback) {
        let self = this;
        self.flightSuretyApp.methods
             .getAllFlights()
             .call({ from: self.owner, gas: 3000000}, (error, result) => {
                callback(error, result);
            });
     }

     submitInsuranceRequest(flightAddress, flightName, amountEther, callback) {
         let self = this;
         self.flightSuretyApp.methods
            .passengerBuysInsurance(flightAddress)
            .call({from: self.passengers[0], gas: 3000000, value: "10000000000000000000"}, (error, result) => {
                callback(error, result);
            });
     }

    fetchFlightStatus(flight, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[0],
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