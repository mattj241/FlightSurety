const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require('fs');

// module.exports = function (deployer) {
    
//     deployer.deploy(FlightSuretyData)
//     .then(() => {
//         return deployer.deploy(FlightSuretyApp, FlightSuretyData.address)
//                 .then(() => {
//                     let config = {
//                         localhost: {
//                             url: 'http://localhost:7545',
//                             dataAddress: FlightSuretyData.address,
//                             appAddress: FlightSuretyApp.address
//                         }
//                     }
//                     fs.writeFileSync(__dirname + '/../src/dapp/config.json',JSON.stringify(config, null, '\t'), 'utf-8');
//                     fs.writeFileSync(__dirname + '/../src/server/config.json',JSON.stringify(config, null, '\t'), 'utf-8');
//                 });
//     });
//     // const instance = FlightSuretyData.deployed();
//     FlightSuretyData.addAuthorizedCaller(FlightSuretyApp.address);
// }

module.exports = async function (deployer, accounts) {

    await deployer.deploy(FlightSuretyData);
    await deployer.deploy(FlightSuretyApp, FlightSuretyData.address);

    // Get deployed instance of Data contract, and set App as a valid caller.
    const instanceData = await FlightSuretyData.deployed();
    let result = await instanceData.addAuthorizedCaller(FlightSuretyApp.address);
    console.log(result);

    let config = {
        localhost: {
            url: 'http://localhost:7545',
            dataAddress: FlightSuretyData.address,
            appAddress: FlightSuretyApp.address
        }
    }
    fs.writeFileSync(__dirname + '/../src/dapp/config.json', JSON.stringify(config, null, '\t'), 'utf-8');
    fs.writeFileSync(__dirname + '/../src/server/config.json', JSON.stringify(config, null, '\t'), 'utf-8');
}