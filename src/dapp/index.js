
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';
var Web3 = require('web3');

(async() => {

    let result = null;

    let contract = new Contract('localhost', () => {

        // DOM.elid('get-contract-sts').addEventListener('click', () => {
        //     // Read transaction
            contract.isOperational((error, result) => {
                console.log(error,result);
                display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
            });
        // })

        DOM.elid('load-default').addEventListener('click', () => {
            contract.loadDefaultData((error, result) => {
                console.log(error,result);
            });
        })
    

        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            let airline = DOM.elid('flight-address').value
            // Write transaction
            contract.fetchFlightStatus(flight, airline, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        })

        DOM.elid('get-flights').addEventListener('click', () => {
            let timestamps = new Array();
            let flightNames = new Array();
            let airlines = new Array();
            let list = document.getElementById("flight-list");
            contract.getAllFlights((error, result) => {
                console.log(result);
                result[2].forEach(timeStamp => {
                    timestamps.push(timeStamp)
                });
                result[1].forEach(name => {
                    flightNames.push(name)
                });
                result[0].forEach(airline => {
                    airlines.push(airline);
                });
                for (var i = 0; i<flightNames.length;i++)
                {
                    var obj = "Airline addr: "+ airlines[i] + " || Flight Name: "+ flightNames[i] + " || Time Stamp: " + timestamps[i];
                    var li = document.createElement("li");
                    li.textContent = obj;
                    list.appendChild(li);
                }
            });
        })

        DOM.elid('submit-insurance').addEventListener('click', () => {
            let flightNumber = DOM.elid('flight-number-insurance').value;
            let flightAddress = DOM.elid('flight-address-insurance').value;
            let flightTimestamp = (DOM.elid('flight-timestamp-insurance').value);
            let etherAmount = Web3.utils.toWei((DOM.elid('flight-amount-insurance').value), 'ether');
            // Write transaction
            contract.submitInsuranceRequest(flightAddress, flightNumber, flightTimestamp, etherAmount, (error, result) => {
                console.log(result)
            });
        })
    
    });
    

})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    // displayDiv.lastChild.remove();
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}







