import ballerinax/salesforce;
import ballerina/http;

# A service representing a network-accessible API
# bound to port `9090`.
service / on new http:Listener(9090) {

    # A resource for generating greetings
    # + name - the input string name
    # + return - string name with hello message or error
    resource function get greeting(string name) returns string|error {
        // Send a response back to the caller.
        if name is "" {
            return error("name should not be empty!");
        }
        return "Hello, " + name;
    }

    # A resource for transforming contacts
    # + contactsInput - the input contacts
    # + return - transformed contacts or error
    resource function post contacts(@http:Payload ContactsInput contactsInput) returns ContactsOutput|error? {
        ContactsOutput contactsOutput = transform(contactsInput);
        return contactsOutput;
    }

    # A resource for fetching contacts from salesforce
    # + return - Contacts collection or error
    resource function get contacts() returns ContactsOutput|error {
        // salesforce:SoqlResult|salesforce:Error soqlResult = salesforceEp -> getQueryResult("SELECT Id,FirstName,LastName,Email,Phone FROM Contact");

        // if (soqlResult is salesforce:SoqlResult) {
        //     json results = soqlResult.toJson();
        //     ContactsInput salesforceContactResponse = check results.cloneWithType(ContactsInput);
        //     ContactsOutput contacts = transform(salesforceContactResponse);
        //     return contacts;
        // } else {
        //     return error(soqlResult.message());
        // } 
        
        stream<RecordsItem, error?>|error soqlResult  = salesforceEp -> query("SELECT Id,FirstName,LastName,Email,Phone FROM Contact", RecordsItem);

        if (soqlResult is stream<RecordsItem, error?>) {
            ContactsOutput|error contacts = transform2(soqlResult);
            return contacts;
        } else {
            return error(soqlResult.message());
        }
    }
}

type Attributes record {
    string 'type;
    string url;
};

type ContactsItem record {
    string fullName;
    (anydata|string)? phoneNumber;
    (anydata|string)? email;
    string id;
};

type ContactsOutput record {
    int numberOfContacts;
    ContactsItem[] contacts;
};

type RecordsItem record {
    Attributes attributes;
    string Id;
    string FirstName;
    string LastName;
    (anydata|string)? Email;
    (anydata|string)? Phone;
};

type ContactsInput record {
    int totalSize;
    boolean done;
    RecordsItem[] records;
};

type SalesforceConfig record {|
    string baseUrl;
    string token;
|};

configurable SalesforceConfig sfConfig = ?;

function transform(ContactsInput contactsInput) returns ContactsOutput => {
    numberOfContacts: contactsInput.totalSize,
    contacts: from var recordsItem in contactsInput.records
        select {
            fullName: recordsItem.FirstName + recordsItem.LastName,
            phoneNumber: recordsItem.Phone,
            email: recordsItem.Email,
            id: recordsItem.Id
        }
};

function transform2(stream<RecordsItem, error?> resultStream) returns ContactsOutput|error {
    ContactsOutput contactsOutput = {numberOfContacts: 0, contacts: []};
    var resultStreamElement = resultStream.next();
    while (resultStreamElement !is ()) {
        if (resultStreamElement !is error?) {
            RecordsItem recordsItem = resultStreamElement.value;
            contactsOutput.numberOfContacts += 1;
            contactsOutput.contacts.push({
                fullName: recordsItem.FirstName + recordsItem.LastName,
                phoneNumber: recordsItem.Phone,
                email: recordsItem.Email,
                id: recordsItem.Id
            });
        } else {
            return error(resultStreamElement.message());
        }
        resultStreamElement = resultStream.next();
    }
    return contactsOutput;

};

salesforce:Client salesforceEp = check new (config = {
    baseUrl: sfConfig.baseUrl,
    auth: {
        token: sfConfig.token
    }
});
