
enum SensorType {
    Temperature,
    Humidity,
    Pressure,
    Light,
    Motion,
    Sound,
    Acceleration
}

type Sensor record {
    readonly string id;
    string name;
    SensorType sensorType;
    string location;
    boolean isActive;
    string lastChecked;
};

// table<Sensor> key(id) sensors = table [
Sensor[] sensors = [
    {
        id: "sensor_12345",
        name: "Environmental Sensor",
        sensorType: Temperature,
        location: "Main Office - Room 202",
        isActive: true,
        lastChecked: "2023-12-11T10:30:00Z"
    },
    {
        id: "sensor_12346",
        name: "Environmental Sensor",
        sensorType: Humidity,
        location: "Main Office - Room 202",
        isActive: true,
        lastChecked: "2023-12-11T10:30:00Z"
    },
    {
        id: "sensor_12347",
        name: "Environmental Sensor",
        sensorType: Pressure,
        location: "Main Office - Room 202",
        isActive: true,
        lastChecked: "2023-12-11T10:30:00Z"
    },
    {
        id: "sensor_12348",
        name: "Environmental Sensor",
        sensorType: Temperature,
        location: "Main Office - Room 202",
        isActive: true,
        lastChecked: "2023-12-11T10:30:00Z"
    },
    {
        id: "sensor_12349",
        name: "Environmental Sensor",
        sensorType: Motion,
        location: "Main Office - Room 202",
        isActive: true,
        lastChecked: "2023-12-11T10:30:00Z"
    },
    {
        id: "sensor_12350",
        name: "Environmental Sensor",
        sensorType: Temperature,
        location: "Main Office - Room 202",
        isActive: true,
        lastChecked: "2023-12-11T10:30:00Z"
    },
    {
        id: "sensor_12351",
        name: "Environmental Sensor",
        sensorType: Acceleration,
        location: "Main Office - Room 202",
        isActive: true,
        lastChecked: "2023-12-11T10:30:00Z"
    }
];
