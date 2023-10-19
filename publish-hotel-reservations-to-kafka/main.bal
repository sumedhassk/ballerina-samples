import ballerina/http;
import ballerina/lang.'string as string0;
import ballerina/lang.runtime;
import ballerina/log;
import ballerina/observe;
import ballerinax/jaeger as _;
import ballerinax/kafka;
import ballerinax/prometheus as _;

configurable string kafkaUrl = ?;
configurable string kafkaTopic = ?;

type Guest record {
    string firstName;
    string lastName;
    string email;
    string phoneNumber;
};

type BookingDetails record {
    string hotelId;
    string roomType;
    string checkInDate;
    string checkOutDate;
    int numberOfGuests;
    int[] kidsAges;
    string[] specialRequests;
};

type BookingRequest record {
    string bookingId;
    Guest guest;
    BookingDetails bookingDetails;
};

type ResevationDetails record {
    string hotelCode;
    string roomType;
    string checkInDate;
    string checkOutDate;
    int numberOfGuests;
    int numberOfKids;
    int[] kidsAges;
    string specialRequests;
};

type Reservation record {
    string reservationId;
    Guest guest;
    ResevationDetails resevationDetails;
};

final kafka:Producer kafka = check new (bootstrapServers = kafkaUrl, config = {
    retryCount: 3
});

service /abc on new http:Listener(8081) {
    resource function post bookings(BookingRequest[] payload) returns http:Created|http:InternalServerError {
        // Start publishing to Kafka in separate strands.
        future<kafka:Error?>[] futures = [];
        foreach var bookingReq in payload {
            future<kafka:Error?> f = start publishToKafka(bookingReq);
            futures.push(f);
        }

        // Let's wait for all 'publishToKafka' funtions to complete.
        foreach var f in futures {
            kafka:Error? status = wait f;
            if status is kafka:Error {
                // Here we are returning if at least one of the 'publishToKafka' functions failed.
                // Not ideal, but I am doing this for the sake of simplicity.
                return http:INTERNAL_SERVER_ERROR;
            }
        }

        // Send 201 Created response, if all the 'publishToKafka' functions succeeded.
        log:printInfo("Successfully published all the reservations to Kafka.");
        return http:CREATED;
    }
}

@observe:Observable
isolated function publishToKafka(BookingRequest bookingReq) returns kafka:Error? {
    // 1) Transform a booking request to a reservation
    Reservation reservation = transformBookingToReservation(bookingReq);
    // 2) Publish the reservation to Kafka
    kafka:Error? status = kafka->send({value: reservation, topic: kafkaTopic});
    
    // Introduce a delay to simulate a real-world scenario.
    runtime:sleep(0.05);
    if status is kafka:Error {
        log:printError("Error while publishing the reservation to Kafka: ", reservation = reservation, 'error = status);
        return status;
    }
}

@observe:Observable
isolated function transformBookingToReservation(BookingRequest bookingRequest) returns Reservation => {
    reservationId: bookingRequest.bookingId,
    guest: bookingRequest.guest,
    resevationDetails: {
        hotelCode: bookingRequest.bookingDetails.hotelId,
        roomType: bookingRequest.bookingDetails.roomType,
        checkInDate: bookingRequest.bookingDetails.checkInDate,
        checkOutDate: bookingRequest.bookingDetails.checkOutDate,
        numberOfGuests: bookingRequest.bookingDetails.numberOfGuests,
        numberOfKids: bookingRequest.bookingDetails.kidsAges.length(),
        kidsAges: bookingRequest.bookingDetails.kidsAges,
        specialRequests: string0:'join(",", ...bookingRequest.bookingDetails.specialRequests)
    }
};

