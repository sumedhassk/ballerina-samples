import ballerina/http;
import ballerina/log;
import ballerina/persist;
import ballerina/uuid;
import book_shop.datastore;

type InsufficientStockError distinct error;

type OrderedBookNotFoundError distinct error;

type NewBook record {
    string title;
    string author;
    decimal price;
    int stock;
};

type NewOrderItem record {
    string bookId;
    int quantity;
    decimal price;
};

type NewOrder record {
    string customerId;
    string createdAt;
    decimal totalPrice;
    NewOrderItem[] orderItems;
};

type PaymentDetails record {
    decimal amouont;
    string paymentDate;
    string orderId;
};

type OrderWithItems record {|
    *datastore:Order;
    datastore:OrderItem[] orderItems;
|};

// Defines the data structure that represents a complete order.
// This is the data structure that is returned by the GET orders resource.
type CompleteOrder record {|
    *OrderWithItems;
    datastore:Payment payment;
|};

final datastore:Client booksDb = check initializeBooksDbClient();

service /book\-store on new http:Listener(8080) {

    # Initialize the service
    function init() {
        log:printInfo("*************************************************************************************************************");
        log:printInfo("Book Store service started on port 8080");
        log:printInfo("*************************************************************************************************************");
    }    

    resource function get books() returns datastore:Book[]|http:InternalServerError {
        datastore:Book[]|persist:Error books = from var book in booksDb->/books(targetType = datastore:Book)
            select book;
        if books is persist:Error {
            log:printError("Error while retrieving books from the database", 'error = books);
            return http:INTERNAL_SERVER_ERROR;
        } else {
            return books;
        }
    }

    resource function get book/[string bookId]() returns datastore:Book|http:NotFound|http:InternalServerError {
        datastore:Book|persist:Error book = booksDb->/books/[bookId];
        if book is persist:NotFoundError {
            return http:NOT_FOUND;
        } else if book is persist:Error {
            log:printError("Error while retrieving book from the database", bookId = bookId, 'error = book);
            return http:INTERNAL_SERVER_ERROR;
        } else {
            return book;
        }
    }

    resource function post book(NewBook newBook) returns datastore:Book|http:InternalServerError {
        datastore:Book book = {
            bookId: uuid:createType4AsString(),
            title: newBook.title,
            author: newBook.author,
            price: newBook.price,
            stock: newBook.stock
        };

        string[]|persist:Error insertStatus = booksDb->/books.post([book]);
        if insertStatus is string[] {
            return book;
        } else {
            log:printError("Error while inserting book into the database", 'error = insertStatus);
            return http:INTERNAL_SERVER_ERROR;
        }
    }

    resource function delete book/[string bookId]() returns http:NoContent|http:NotFound|http:InternalServerError {
        datastore:Book|persist:Error book = booksDb->/books/[bookId].delete();
        if book is persist:NotFoundError {
            return http:NOT_FOUND;
        } else if book is persist:Error {
            log:printError("Error while deleting book from the database", bookId = bookId, 'error = book);
            return http:INTERNAL_SERVER_ERROR;
        } else {
            return http:NO_CONTENT;
        }
    }

    resource function get orders() returns CompleteOrder[]|http:InternalServerError {
        // order is a keyword in Ballerina, so we use 'order instead as the variable name.
        // In case, you haven't noticed, here we join the orders, orderItems and payments tables.
        CompleteOrder[]|persist:Error orders = from var 'order in booksDb->/orders(targetType = CompleteOrder)
            select 'order;
        if orders is persist:Error {
            log:printError("Error while retrieving orders from the database", 'error = orders);
            return http:INTERNAL_SERVER_ERROR;
        } else {
            return orders;
        }
    }

    resource function get orders/[string orderId]() returns CompleteOrder|http:NotFound|http:InternalServerError {
        CompleteOrder|persist:Error completeOrder = booksDb->/orders/[orderId];
        if completeOrder is persist:NotFoundError {
            return http:NOT_FOUND;
        } else if completeOrder is persist:Error {
            log:printError("Error while retrieving order from the database", orderId = orderId, 'error = completeOrder);
            return http:INTERNAL_SERVER_ERROR;
        } else {
            return completeOrder;
        }
    }

    resource function post payments(PaymentDetails paymentDetails) returns datastore:Payment|http:BadRequest|http:InternalServerError {
        datastore:Payment payment = {
            paymentId: uuid:createType4AsString(),
            paymentAmount: paymentDetails.amouont,
            paymentDate: paymentDetails.paymentDate,
            paymentOrderId: paymentDetails.orderId
        };

        string[]|persist:Error insertStatus = booksDb->/payments.post([payment]);
        if insertStatus is string[] {
            return payment;
        } else if insertStatus is persist:ConstraintViolationError {
            log:printError("Error while inserting payment into the database: Invalid orderId", 'error = insertStatus, paymentDetails = paymentDetails);
            return http:BAD_REQUEST;
        } else {
            log:printError("Error while inserting payment into the database", 'error = insertStatus, paymentDetails = paymentDetails);
            return http:INTERNAL_SERVER_ERROR;
        }
    }

    resource function post orders(NewOrder newOrder) returns OrderWithItems|http:BadRequest|http:InternalServerError {
        string orderId = uuid:createType4AsString();
        transaction {
            OrderWithItems processedOrder = check self.processOrder(newOrder, orderId);
            check commit;
            return processedOrder;
        } on fail error e {
            if e is InsufficientStockError|OrderedBookNotFoundError {
                return <http:BadRequest>{body: e.message()};
            } else {
                log:printError("Error while inserting order into the database", 'error = e,
                orderDetails = newOrder, orderId = orderId);
                return http:INTERNAL_SERVER_ERROR;
            }
        }
    }

    // A function with a "transactional" qualifier can only be called from a transactional context.
    transactional function processOrder(NewOrder newOrder, string orderId) returns OrderWithItems|error {
        // Step 1: Insert order
        datastore:Order 'order = createOrderFromNewOrder(newOrder, orderId);
        _ = check booksDb->/orders.post(['order]);

        // Step 2: Update stock of books
        foreach var {bookId, quantity} in newOrder.orderItems {
            datastore:Book|persist:Error book = booksDb->/books/[bookId];
            if book is persist:NotFoundError {
                return error OrderedBookNotFoundError(string `Book with id ${bookId} not found`);
            } else if book is persist:Error {
                return book;
            } else {
                if book.stock < quantity {
                    return error InsufficientStockError(string `Insufficient stock for book with id ${bookId}`);
                }
                _ = check booksDb->/books/[bookId].put({stock: book.stock - quantity});
            }
        }

        // Step 3: Insert order items
        datastore:OrderItem[] orderItems = createOrderItemsFromNewOrder(newOrder, orderId);
        _ = check booksDb->/orderitems.post(orderItems);
        return {...'order, orderItems};
    }
}

function createOrderFromNewOrder(NewOrder newOrder, string orderId) returns datastore:Order => {
    orderId: orderId,
    customerId: newOrder.customerId,
    createdAt: newOrder.createdAt,
    totalPrice: newOrder.totalPrice
};

function createOrderItemsFromNewOrder(NewOrder newOrder, string orderId) returns datastore:OrderItem[] => from var newOrderItem in newOrder.orderItems
    select {
        orderItemId: uuid:createType4AsString(),
        orderOrderId: orderId,
        orderitemBookId: newOrderItem.bookId,
        quantity: newOrderItem.quantity,
        price: newOrderItem.price
    };

function initializeBooksDbClient() returns datastore:Client|error {
    return new datastore:Client();
}

