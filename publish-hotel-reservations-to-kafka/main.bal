import ballerina/http;
import ballerinax/kafka;
import ballerinax/jaeger as _;
import ballerinax/prometheus as _;
import ballerina/lang.runtime;

service /abc on new http:Listener(8081) {
    resource function post bookings(BookingRequest[] payload) returns http:Created|http:InternalServerError {
        foreach var bookingRequest in payload {
            // Step 1: Transform the booking request to a reservation request
            ReservationRequest reservationRequest = transform(bookingRequest);
            // Step 2: Send the reservation request to Kafka
            kafka:Error? sendStatus = kafka->send({topic: kafkaTopic, value: reservationRequest});
            runtime:sleep(0.2);
            if sendStatus is kafka:Error {
                return http:INTERNAL_SERVER_ERROR;
            }
        }
        return http:CREATED;
    }
}

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

final kafka:Producer kafka = check new (bootstrapServers = kafkaUrl, config = {
    retryCount: 3
});

configurable string kafkaUrl = ?;
configurable string kafkaTopic = ?;

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

type ReservationRequest record {
    string reservationId;
    Guest guest;
    ResevationDetails resevationDetails;
};

function transform(BookingRequest bookingRequest) returns ReservationRequest => {
    reservationId: bookingRequest.bookingId,
    guest: bookingRequest.guest,
    resevationDetails: {
        hotelCode: bookingRequest.bookingDetails.hotelId,
        roomType: bookingRequest.bookingDetails.roomType,
        checkInDate: bookingRequest.bookingDetails.checkInDate,
        checkOutDate: bookingRequest.bookingDetails.checkOutDate,
        numberOfGuests: bookingRequest.bookingDetails.numberOfGuests,
        kidsAges: bookingRequest.bookingDetails.kidsAges,
        numberOfKids: bookingRequest.bookingDetails.kidsAges.length(),
        specialRequests: string:'join(",", ...bookingRequest.bookingDetails.specialRequests)   
    }
};
