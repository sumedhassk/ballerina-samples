import ballerina/lang.'string as string0;
import ballerinax/kafka;
import ballerina/log;
import ballerina/http;

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
        foreach var bookingReq in payload {
            // 1) Transform a booking request to a reservation
            Reservation reservation = transformBookingToReservation(bookingReq);
            // 2) Publish the reservation to Kafka
            kafka:Error? status = kafka->send({value: reservation, topic: kafkaTopic});
            if status is kafka:Error {
                log:printError("Error while publishing the reservation to Kafka: ", reservation = reservation, 'error = status);
                return http:INTERNAL_SERVER_ERROR;
            }
        }
        return http:CREATED;
    }
}

function transformBookingToReservation(BookingRequest bookingRequest) returns Reservation => {
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


