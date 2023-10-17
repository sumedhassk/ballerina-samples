import ballerina/persist as _;

type Book record {|
    readonly string bookId;          
    string title;
    string author;
    decimal price;     
    int stock;
	OrderItem? orderitem;
|};

type Order record {|
    readonly string orderId;
    string customerId;
    string createdAt;    
    decimal totalPrice;
	OrderItem[] orderItems;
	Payment? payment;
|};

type OrderItem record {|
    readonly string orderItemId;
    int quantity;
    decimal price;
    Book book;
    Order 'order;
|};

type Payment record {|
    readonly string paymentId;
    decimal paymentAmount;
    string paymentDate; 
    Order 'order;
|};
