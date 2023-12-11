import ballerina/http;
import ballerina/log;
import ballerinax/kafka;

import crates/bqueue as bq;

enum TemperatureUnit {
    CELSIUS = "C",
    FAHRENHEIT = "F"
};

type TemperatureReading record {|
    string sensorId;
    float temperature;
    TemperatureUnit unit;
    string timestamp;
|};

type TemperatureEvent record {|
    *TemperatureReading;
    string sensorName;
    boolean sensorIsActive;
    SensorType sensorType;
    string sensorLocation;
|};

// Represents a channel
final bq:BlockingQueue bq = new;

configurable string kafkaUrl = ?;
configurable string kafkaTopic = ?;
final kafka:Producer kafka = check new (bootstrapServers = kafkaUrl, config = {
    retryCount: 3
});

// This service receives temperature readings from sensors and write them to kafka
service / on new http:Listener(8006) {

    function init() returns error? {
        _ = start runStreamReader();
    }

    resource function post temp(TemperatureReading tempReading) returns error? {
        check bq.put(tempReading);
    }
}

class QueueReader {
    public isolated function next() returns record {|TemperatureReading value;|}|error? {
        TemperatureReading data = check bq.take();
        return {value: data};
    }
}

function runStreamReader() returns error? {
    QueueReader queueReader = new ();
    stream<TemperatureReading, error?> tempReadingStream = new (queueReader);

    stream<TemperatureReading, error?> fahrenheitReadingStream = from var reading in tempReadingStream
        where reading.unit == FAHRENHEIT
        select reading;

    check from var temperatureReading in fahrenheitReadingStream
        do {
            kafka:Error? status = kafka->send({value: temperatureReading, topic: kafkaTopic});
            if status is kafka:Error {
                log:printError("Error sending message to Kafka: ", 'error = status);
            }

        };

    // This stream with Join didn't work. Need to check why.
    // stream<TemperatureEvent, error?> temperatureEventStream = from var reading in tempReadingStream
    //     join Sensor sensor in sensors on reading.sensorId equals sensor.id
    //     select {sensorName: sensor.name, sensorIsActive: sensor.isActive, sensorType: sensor.sensorType, sensorLocation: sensor.location, ...reading};

    // check from var temperatureEvent in temperatureEventStream
    //     do {
    //         io:println(temperatureEvent);
    //     };
}

