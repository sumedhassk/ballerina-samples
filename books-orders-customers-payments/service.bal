import ballerina/http;
import ballerina/log;
import ballerina/persist;
import ballerina/uuid;

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
    *Order;
    OrderItem[] orderItems;
|};

// Defines the data structure that represents a complete order.
// This is the data structure that is returned by the GET orders resource.
type CompleteOrder record {|
    *OrderWithItems;
    Payment payment;
|};

final Client db = check new ();

service /orderbiblio on new http:Listener(8081) {

    resource function get books() returns Book[]|http:InternalServerError {
        Book[]|persist:Error books = from var book in db->/books(targetType = Book)
            select book;
        if books is persist:Error {
            log:printError("Error while retrieving books from the database", 'error = books);
            return http:INTERNAL_SERVER_ERROR;
        } else {
            return books;
        }
    }

    resource function get book/[string bookId]() returns Book|http:NotFound|http:InternalServerError {
        Book|persist:Error book = db->/books/[bookId];
        if book is persist:NotFoundError {
            return http:NOT_FOUND;
        } else if book is persist:Error {
            log:printError("Error while retrieving book from the database", bookId = bookId, 'error = book);
            return http:INTERNAL_SERVER_ERROR;
        } else {
            return book;
        }
    }

    resource function post book(NewBook newBook) returns Book|http:InternalServerError {
        Book book = {
            bookId: uuid:createType4AsString(),
            title: newBook.title,
            author: newBook.author,
            price: newBook.price,
            stock: newBook.stock
        };

        string[]|persist:Error insertStatus = db->/books.post([book]);
        if insertStatus is string[] {
            return book;
        } else {
            log:printError("Error while inserting book into the database", 'error = insertStatus);
            return http:INTERNAL_SERVER_ERROR;
        }
    }

    resource function delete book/[string bookId]() returns http:NoContent|http:NotFound|http:InternalServerError {
        Book|persist:Error book = db->/books/[bookId].delete();
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
        CompleteOrder[]|persist:Error orders = from var 'order in db->/orders(targetType = CompleteOrder)
            select 'order;
        if orders is persist:Error {
            log:printError("Error while retrieving orders from the database", 'error = orders);
            return http:INTERNAL_SERVER_ERROR;
        } else {
            return orders;
        }
    }

    resource function get orders/[string orderId]() returns CompleteOrder|http:NotFound|http:InternalServerError {
        CompleteOrder|persist:Error completeOrder = db->/orders/[orderId];
        if completeOrder is persist:NotFoundError {
            return http:NOT_FOUND;
        } else if completeOrder is persist:Error {
            log:printError("Error while retrieving order from the database", orderId = orderId, 'error = completeOrder);
            return http:INTERNAL_SERVER_ERROR;
        } else {
            return completeOrder;
        }
    }

    resource function post orders(NewOrder newOrder) returns OrderWithItems|http:BadRequest|http:InternalServerError {
        string orderId = uuid:createType4AsString();

        transaction {
            // Heavylifting is done by the processOrder function.
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

    resource function post payments(PaymentDetails paymentDetails) returns Payment|http:BadRequest|http:InternalServerError {
        Payment payment = {
            paymentId: uuid:createType4AsString(),
            paymentAmount: paymentDetails.amouont,
            paymentDate: paymentDetails.paymentDate,
            paymentOrderId: paymentDetails.orderId
        };

        string[]|persist:Error insertStatus = db->/payments.post([payment]);
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

    // A function with a "transactional" qualifier can only be called from a transactional context.
    transactional function processOrder(NewOrder newOrder, string orderId) returns OrderWithItems|error {
        // Step 1: Insert order
        Order 'order = createOrderFromNewOrder(newOrder, orderId);
        _ = check db->/orders.post(['order]);

        // Step 2: Update stock of books
        foreach var {bookId, quantity} in newOrder.orderItems {
            Book|persist:Error book = db->/books/[bookId];
            if book is persist:NotFoundError {
                return error OrderedBookNotFoundError(string `Book with id ${bookId} not found`);
            } else if book is persist:Error {
                return book;
            } else {
                if book.stock < quantity {
                    return error InsufficientStockError(string `Insufficient stock for book with id ${bookId}`);
                }
                _ = check db->/books/[bookId].put({stock: book.stock - quantity});
            }
        }

        // Step 3: Insert order items
        OrderItem[] orderItems = createOrderItemsFromNewOrder(newOrder, orderId);
        _ = check db->/orderitems.post(orderItems);

        return {...'order, orderItems};
    }
}

function createOrderFromNewOrder(NewOrder newOrder, string orderId) returns Order => {
    orderId: orderId,
    customerId: newOrder.customerId,
    createdAt: newOrder.createdAt,
    totalPrice: newOrder.totalPrice
};

function createOrderItemsFromNewOrder(NewOrder newOrder, string orderId) returns OrderItem[] => from var newOrderItem in newOrder.orderItems
    select {
        orderItemId: uuid:createType4AsString(),
        orderOrderId: orderId,
        orderitemBookId: newOrderItem.bookId,
        quantity: newOrderItem.quantity,
        price: newOrderItem.price
    };

