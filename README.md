# SolrSim
Simulation of SOLR

Created a Python Flask web application that:

Input Validation: Accept input for "Area" from the predefined list: ["OP1", "OP2", "OP3", "OP4", "OP5", "OP6", "OP7", "OP8"]

Threat Matching: Accept input for "Threat" and search for matches against the "Threats" array in the JSON data file data/productissues.json

Query Logic:

Search for products where the Area matches the input Area
Within matching products, search all platforms for the specified Threat
When a threat match is found, return the corresponding platform value
Output Requirements:

Display results via a web page
For each match, show: platform name + "Threat Active - No Action Possible" + current datetime stamp
Handle cases where no matches are found
Technical Requirements:

Use Flask for the web framework
Create HTML templates for the user interface
Include proper error handling for invalid inputs
Format datetime stamps in a readable format
Provide a clean, user-friendly web interface
File Structure:

Main Flask application file
HTML templates for the web interface
CSS styling for better presentation
Proper handling of the existing JSON data file
The application should be production-ready with proper error handling and validation.
