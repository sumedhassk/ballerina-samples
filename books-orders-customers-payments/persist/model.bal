import ballerina/persist as _;

// Represents the Books entity
type Book record {|
    readonly string bookId;          
    string title;
    string author;
    decimal price;     
    int stock;
	OrderItem? orderitem;
|};

// Represents the Orders entity
type Order record {|
    readonly string orderId;
    string customerId;
    string createdAt;    
    decimal totalPrice;
	OrderItem[] orderItems;
	Payment? payment;
|};

// Represents the OrderItems entity
type OrderItem record {|
    readonly string orderItemId;
    int quantity;
    decimal price;
    Book book;
    Order 'order;
|};

// Represents the Payments entity
type Payment record {|
    readonly string paymentId;
    decimal paymentAmount;
    string paymentDate; 
    Order 'order;
|};
