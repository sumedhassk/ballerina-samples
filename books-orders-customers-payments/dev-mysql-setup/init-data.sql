-- Inserting dummy data with UUIDs

-- Insert data into Book table
INSERT INTO `Book` (`bookId`, `title`, `author`, `price`, `stock`) VALUES
('550e8400-e29b-41d4-a716-446655440000', 'The Great Novel', 'John Doe', 19.99, 100),
('550e8400-e29b-41d4-a716-446655440001', 'Learning SQL', 'Jane Smith', 29.99, 50),
('550e8400-e29b-41d4-a716-446655440002', 'A Day in Life', 'Emma Brown', 14.99, 75);

-- Insert data into Order table
INSERT INTO `Order` (`orderId`, `customerId`, `createdAt`, `totalPrice`) VALUES
('6ba7b810-9dad-11d1-80b4-00c04fd430c0', 'C550e840-9dad-11d1-80b4-00c04fd430c0', '2023-10-14T12:00:00Z', 19.99),
('6ba7b810-9dad-11d1-80b4-00c04fd430c1', 'C550e840-9dad-11d1-80b4-00c04fd430c1', '2023-10-15T14:30:00Z', 44.98);

-- Insert data into OrderItem table
INSERT INTO `OrderItem` (`orderItemId`, `quantity`, `price`, `orderitemBookId`, `orderOrderId`) VALUES
('6ba7b812-9dad-11d1-80b4-00c04fd430c0', 1, 19.99, '550e8400-e29b-41d4-a716-446655440000', '6ba7b810-9dad-11d1-80b4-00c04fd430c0'),
('6ba7b812-9dad-11d1-80b4-00c04fd430c1', 1, 29.99, '550e8400-e29b-41d4-a716-446655440001', '6ba7b810-9dad-11d1-80b4-00c04fd430c1'),
('6ba7b812-9dad-11d1-80b4-00c04fd430c2', 1, 14.99, '550e8400-e29b-41d4-a716-446655440002', '6ba7b810-9dad-11d1-80b4-00c04fd430c1');

-- Insert data into Payment table
INSERT INTO `Payment` (`paymentId`, `paymentAmount`, `paymentDate`, `paymentOrderId`) VALUES
('6ba7b814-9dad-11d1-80b4-00c04fd430c0', 19.99, '2023-10-14T12:10:00Z', '6ba7b810-9dad-11d1-80b4-00c04fd430c0'),
('6ba7b814-9dad-11d1-80b4-00c04fd430c1', 44.98, '2023-10-15T14:40:00Z', '6ba7b810-9dad-11d1-80b4-00c04fd430c1');
