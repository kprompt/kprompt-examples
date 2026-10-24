const { UserModel, ProductModel, OrderModel } = require('../../models/defaultModels');

describe('Default Models - P-007 Refresh', () => {
  test('UserModel has expected fields and types', () => {
    expect(UserModel).toHaveProperty('id', 'string');
    expect(UserModel).toHaveProperty('name', 'string');
    expect(UserModel).toHaveProperty('email', 'string');
    expect(UserModel).toHaveProperty('createdAt', 'Date');
    expect(UserModel).toHaveProperty('updatedAt', 'Date');
  });

  test('ProductModel has expected fields and types', () => {
    expect(ProductModel).toHaveProperty('id', 'string');
    expect(ProductModel).toHaveProperty('name', 'string');
    expect(ProductModel).toHaveProperty('description', 'string');
    expect(ProductModel).toHaveProperty('price', 'number');
    expect(ProductModel).toHaveProperty('available', 'boolean');
    expect(ProductModel).toHaveProperty('createdAt', 'Date');
    expect(ProductModel).toHaveProperty('updatedAt', 'Date');
  });

  test('OrderModel has expected fields and types', () => {
    expect(OrderModel).toHaveProperty('id', 'string');
    expect(OrderModel).toHaveProperty('userId', 'string');
    expect(OrderModel).toHaveProperty('productIds');
    expect(Array.isArray(OrderModel.productIds)).toBe(true);
    expect(OrderModel.productIds[0]).toBe('string');
    expect(OrderModel).toHaveProperty('totalAmount', 'number');
    expect(OrderModel).toHaveProperty('status');
    expect(Array.isArray(OrderModel.status)).toBe(true);
    expect(OrderModel.status).toEqual(expect.arrayContaining(['pending', 'completed', 'cancelled']));
    expect(OrderModel).toHaveProperty('createdAt', 'Date');
    expect(OrderModel).toHaveProperty('updatedAt', 'Date');
  });
});
