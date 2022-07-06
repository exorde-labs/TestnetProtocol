#Compile contracts
yarn compile
#Summary of static ananlysis
slither . --ignore-compile --exclude-dependencies --filter-path 'realitio|openzeppelin|GnosisSafe|test|daostack' --print human-summary
#Contract summary of static ananlysis
slither . --ignore-compile --exclude-dependencies --filter-path 'realitio|openzeppelin|GnosisSafe|test|daostack' --print contract-summary
#Function summary of contracts
slither . --ignore-compile --exclude-dependencies --filter-path 'realitio|openzeppelin|GnosisSafe|test|daostack' --print function-summary
#Inheritance analysis of contracts
slither . --ignore-compile --exclude-dependencies --filter-path 'realitio|openzeppelin|GnosisSafe|test|daostack' --print inheritance
#Data dependency of contracts
slither . --ignore-compile --exclude-dependencies --filter-path 'realitio|openzeppelin|GnosisSafe|test|daostack' --print data-dependency
#nalysis of contracts
slither . --ignore-compile --config-file slither.config.json