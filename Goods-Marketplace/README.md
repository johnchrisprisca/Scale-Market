# Decentralized Bulk Purchase Marketplace Smart Contract

A comprehensive decentralized marketplace smart contract built on the Stacks blockchain that enables merchants to create dynamic pricing strategies through automated volume-based discount tiers. This platform facilitates secure bulk purchasing with real-time inventory management, tiered discount calculations, automated payment processing, and comprehensive transaction analytics.

## Features

### For Merchants
- **Dynamic Product Management**: Add, modify, and remove products from the catalog
- **Flexible Pricing**: Set and adjust product prices with real-time updates
- **Inventory Control**: Real-time inventory tracking and management
- **Tiered Discount System**: Configure volume-based discounts to incentivize bulk purchases
- **Revenue Analytics**: Track total revenue and transaction metrics
- **Marketplace Control**: Suspend/reactivate marketplace operations

### For Buyers
- **Transparent Pricing**: View real-time product information and pricing
- **Automatic Bulk Discounts**: Get discounts automatically applied based on purchase quantity
- **Single & Bulk Purchases**: Buy individual items or multiple products in one transaction
- **Transaction History**: Track all purchase records with detailed information
- **Cost Calculation**: Preview total costs including discounts before purchase

### Security & Administration
- **Owner-only Controls**: Critical functions restricted to contract owner
- **Input Validation**: Comprehensive validation for all inputs
- **Error Handling**: Detailed error codes for different failure scenarios
- **Marketplace Suspension**: Emergency controls to halt operations if needed

## Contract Architecture

### Data Structures

#### Product Catalog
```clarity
product-catalog: {
  product-id: uint,
  name: string-ascii(64),
  price-per-unit: uint,
  available-quantity: uint,
  is-listed: bool
}
```

#### Discount Tiers
```clarity
discount-tier-config: {
  product-id: uint,
  min-quantity-threshold: uint,
  discount-rate: uint,
  tier-enabled: bool
}
```

#### Transaction Records
```clarity
purchase-transaction-ledger: {
  buyer-address: principal,
  transaction-id: uint,
  purchased-product-id: uint,
  units-purchased: uint,
  final-payment-amount: uint,
  transaction-block-height: uint,
  applied-discount-rate: uint
}
```

## Business Logic Constraints

| Parameter | Minimum | Maximum |
|-----------|---------|---------|
| Product Name Length | 1 character | 64 characters |
| Order Quantity | 1 unit | 1,000,000 units |
| Unit Price | 1 µSTX | 1,000,000,000 µSTX |
| Discount Percentage | 0% | 100% |
| Bulk Items per Order | 1 item | 10 items |

## Core Functions

### Merchant Functions

#### Product Management
```clarity
;; Add a new product to the catalog
(add-new-product (product-name string-ascii) (unit-price uint) (initial-inventory uint))

;; Update product inventory levels
(adjust-inventory-level (product-id uint) (new-stock-level uint))

;; Modify product pricing
(modify-product-price (product-id uint) (updated-price uint))

;; Remove product from active catalog
(remove-product-from-catalog (product-id uint))
```

#### Discount Configuration
```clarity
;; Create volume-based discount tiers
(establish-discount-tier (product-id uint) (minimum-purchase-quantity uint) (discount-percentage uint))

;; Remove existing discount tiers
(remove-discount-tier (product-id uint) (minimum-purchase-quantity uint))
```

### Customer Functions

#### Purchase Operations
```clarity
;; Purchase a single product
(execute-single-purchase (product-id uint) (purchase-quantity uint))

;; Execute bulk purchase with multiple items
(execute-bulk-purchase (order-items (list 10 {product-id: uint, desired-quantity: uint})))
```

#### Information Queries
```clarity
;; Get product details
(get-product-info (product-id uint))

;; Calculate order total with discounts
(calculate-order-total (product-id uint) (desired-quantity uint))

;; View discount tier information
(get-discount-tier-details (product-id uint) (purchase-quantity uint))

;; Check transaction history
(get-buyer-transaction-record (transaction-id uint))
```

### Administrative Functions

#### Marketplace Control
```clarity
;; Transfer contract ownership
(transfer-ownership (new-contract-owner principal))

;; Suspend marketplace operations
(suspend-marketplace)

;; Reactivate marketplace
(reactivate-marketplace)

;; Withdraw collected revenue
(withdraw-collected-revenue (withdrawal-amount uint))
```

#### Analytics
```clarity
;; Get comprehensive marketplace metrics
(get-marketplace-metrics)
```

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | ERR-UNAUTHORIZED-ACCESS | Caller lacks required permissions |
| 101 | ERR-PRODUCT-ALREADY-EXISTS | Product ID already in use |
| 102 | ERR-PRODUCT-NOT-FOUND | Requested product doesn't exist |
| 103 | ERR-INVALID-DISCOUNT-RATE | Discount rate exceeds maximum allowed |
| 104 | ERR-INVALID-PRICE-AMOUNT | Price outside acceptable range |
| 105 | ERR-INSUFFICIENT-PAYMENT | Payment amount too low |
| 106 | ERR-INVALID-QUANTITY-REQUESTED | Quantity outside valid range |
| 107 | ERR-TRANSACTION-PROCESSING-FAILED | General transaction failure |
| 108 | ERR-MARKETPLACE-SUSPENDED | Operations halted by owner |
| 109 | ERR-EMPTY-ORDER-LIST | Bulk order contains no items |
| 110 | ERR-INVALID-INPUT-PARAMETER | Invalid function parameter |
| 111 | ERR-INVALID-PRODUCT-NAME | Product name doesn't meet requirements |
| 112 | ERR-INSUFFICIENT-INVENTORY | Not enough stock available |
| 113 | ERR-DISCOUNT-TIER-NOT-FOUND | Discount tier doesn't exist |
| 114 | ERR-MAXIMUM-ITEMS-EXCEEDED | Too many items in bulk order |

## Usage Examples

### Setting Up Products

```clarity
;; Add a new product
(contract-call? .marketplace add-new-product "Premium Widget" u100000 u1000)

;; Configure bulk discount (10% off for 50+ units)
(contract-call? .marketplace establish-discount-tier u1 u50 u10)

;; Configure larger bulk discount (20% off for 100+ units)
(contract-call? .marketplace establish-discount-tier u1 u100 u20)
```

### Making Purchases

```clarity
;; Single purchase
(contract-call? .marketplace execute-single-purchase u1 u75)

;; Bulk purchase
(contract-call? .marketplace execute-bulk-purchase 
  (list 
    {product-id: u1, desired-quantity: u50}
    {product-id: u2, desired-quantity: u25}
  ))
```

### Checking Information

```clarity
;; View product details
(contract-call? .marketplace get-product-info u1)

;; Calculate order total with discounts
(contract-call? .marketplace calculate-order-total u1 u75)

;; Check marketplace metrics
(contract-call? .marketplace get-marketplace-metrics)
```

## Deployment Instructions

1. **Deploy Contract**: Deploy the smart contract to the Stacks blockchain
2. **Initial Setup**: The deployer automatically becomes the contract owner
3. **Add Products**: Use `add-new-product` to populate the catalog
4. **Configure Discounts**: Set up volume discounts using `establish-discount-tier`
5. **Go Live**: Marketplace is active by default upon deployment

## Security Considerations

- **Owner Privileges**: Only the contract owner can modify products, prices, and marketplace settings
- **Payment Security**: All payments are processed through the Stacks blockchain's native STX transfer mechanism
- **Input Validation**: All user inputs are validated against defined constraints
- **Emergency Controls**: Marketplace can be suspended in case of issues
- **Inventory Tracking**: Real-time inventory prevents overselling

## Gas Optimization

- **Batch Operations**: Bulk purchases process multiple items in a single transaction
- **Efficient Storage**: Maps used for O(1) lookups of products and transactions
- **Validation Caching**: Input validation functions prevent unnecessary computation