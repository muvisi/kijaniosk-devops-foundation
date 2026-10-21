'use strict';

function createProduct(name, price) {
  if (typeof name !== 'string' || name.trim() === '') {
    throw new Error('Product name is required');
  }

  if (typeof price !== 'number' || !Number.isFinite(price) || price < 0) {
    throw new Error('Product price must be a non-negative number');
  }

  return {
    name: name.trim(),
    price: Number(price.toFixed(2))
  };
}

function formatProductLabel(product) {
  if (!product || typeof product.name !== 'string' ||
      typeof product.price !== 'number') {
    throw new Error('A valid product is required');
  }

  return `${product.name} - ${product.price.toFixed(2)}`;
}

module.exports = { createProduct, formatProductLabel };
