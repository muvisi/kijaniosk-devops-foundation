'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createProduct } = require('../src/index');

test('creates a product with a trimmed name and price', () => {
  assert.deepEqual(createProduct('  Maize Flour  ', 125), {
    name: 'Maize Flour',
    price: 125
  });
});

test('rounds product prices to two decimal places', () => {
  assert.equal(createProduct('Tea', 12.345).price, 12.35);
});

test('rejects an empty product name', () => {
  assert.throws(() => createProduct('  ', 20), /Product name is required/);
});

test('rejects a negative price', () => {
  assert.throws(() => createProduct('Sugar', -1), /non-negative number/);
});

test('formats a product label with two decimal places', () => {
  const { formatProductLabel } = require('../src/index');

  assert.equal(
    formatProductLabel({ name: 'Maize Flour', price: 125 }),
    'Maize Flour - 125.00'
  );
});

test('formats a product label with two decimal places', () => {
  const { formatProductLabel } = require('../src/index');

  assert.equal(
    formatProductLabel({ name: 'Maize Flour', price: 125 }),
    'Maize Flour - 125.00'
  );
});
