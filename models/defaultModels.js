/**
 * Default models refreshed for hygiene and maintainability.
 * P-007: Refresh stale default models.
 */

const UserModel = {
  id: 'string',
  name: 'string',
  email: 'string',
  createdAt: 'Date',
  updatedAt: 'Date',
};

const ProductModel = {
  id: 'string',
  name: 'string',
  description: 'string',
  price: 'number',
  available: 'boolean',
  createdAt: 'Date',
  updatedAt: 'Date',
};

const OrderModel = {
  id: 'string',
  userId: 'string',
  productIds: ['string'],
  totalAmount: 'number',
  status: ['pending', 'completed', 'cancelled'],
  createdAt: 'Date',
  updatedAt: 'Date',
};

module.exports = {
  UserModel,
  ProductModel,
  OrderModel,
};
