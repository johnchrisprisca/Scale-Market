;; Title: Decentralized Bulk Purchase Marketplace Smart Contract
;; Description: A comprehensive decentralized marketplace smart contract enabling merchants to create 
;; dynamic pricing strategies through automated volume-based discount tiers. This platform facilitates 
;; secure bulk purchasing with real-time inventory management, tiered discount calculations, automated 
;; payment processing, and comprehensive transaction analytics. Merchants benefit from configurable 
;; discount structures to maximize sales volume, while buyers enjoy transparent pricing with automatic 
;; bulk discounts and seamless multi-item purchasing capabilities.

;; ERROR HANDLING CONSTANTS

(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-PRODUCT-ALREADY-EXISTS (err u101))
(define-constant ERR-PRODUCT-NOT-FOUND (err u102))
(define-constant ERR-INVALID-DISCOUNT-RATE (err u103))
(define-constant ERR-INVALID-PRICE-AMOUNT (err u104))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u105))
(define-constant ERR-INVALID-QUANTITY-REQUESTED (err u106))
(define-constant ERR-TRANSACTION-PROCESSING-FAILED (err u107))
(define-constant ERR-MARKETPLACE-SUSPENDED (err u108))
(define-constant ERR-EMPTY-ORDER-LIST (err u109))
(define-constant ERR-INVALID-INPUT-PARAMETER (err u110))
(define-constant ERR-INVALID-PRODUCT-NAME (err u111))
(define-constant ERR-INSUFFICIENT-INVENTORY (err u112))
(define-constant ERR-DISCOUNT-TIER-NOT-FOUND (err u113))
(define-constant ERR-MAXIMUM-ITEMS-EXCEEDED (err u114))

;; BUSINESS LOGIC CONFIGURATION

(define-constant max-product-name-length u64)
(define-constant max-order-quantity u1000000)
(define-constant max-unit-price u1000000000)
(define-constant max-discount-percentage u100)
(define-constant max-bulk-items-per-order u10)
(define-constant min-product-name-length u1)
(define-constant min-order-quantity u1)
(define-constant min-unit-price u1)
(define-constant default-discount-rate u0)

;; DATA STRUCTURE DEFINITIONS

;; Primary product catalog with comprehensive inventory details
(define-map product-catalog
  { product-id: uint }
  {
    name: (string-ascii 64),
    price-per-unit: uint,
    available-quantity: uint,
    is-listed: bool
  }
)

;; Tiered discount system for bulk purchase incentives
(define-map discount-tier-config
  { product-id: uint, min-quantity-threshold: uint }
  { 
    discount-rate: uint,
    tier-enabled: bool
  }
)

;; Comprehensive purchase transaction ledger
(define-map purchase-transaction-ledger
  { buyer-address: principal, transaction-id: uint }
  {
    purchased-product-id: uint,
    units-purchased: uint,
    final-payment-amount: uint,
    transaction-block-height: uint,
    applied-discount-rate: uint
  }
)

;; CONTRACT STATE MANAGEMENT

(define-data-var contract-owner principal tx-sender)
(define-data-var marketplace-active bool true)
(define-data-var next-product-id uint u1)
(define-data-var next-transaction-id uint u1)
(define-data-var total-revenue-collected uint u0)
(define-data-var completed-transaction-count uint u0)

;; INPUT VALIDATION HELPERS

(define-private (is-valid-product-id (product-id uint))
  (and 
    (>= product-id u1) 
    (< product-id (var-get next-product-id))
  )
)

(define-private (is-valid-quantity (quantity uint))
  (and 
    (>= quantity min-order-quantity) 
    (<= quantity max-order-quantity)
  )
)

(define-private (is-valid-price (price uint))
  (and 
    (>= price min-unit-price) 
    (<= price max-unit-price)
  )
)

(define-private (is-valid-discount-rate (discount uint))
  (<= discount max-discount-percentage)
)

(define-private (is-valid-product-name (name (string-ascii 64)))
  (and 
    (>= (len name) min-product-name-length) 
    (<= (len name) max-product-name-length)
  )
)

(define-private (is-marketplace-operational)
  (var-get marketplace-active)
)

(define-private (has-owner-privileges)
  (is-eq tx-sender (var-get contract-owner))
)

;; PRODUCT INFORMATION RETRIEVAL

(define-read-only (get-product-info (product-id uint))
  (if (is-valid-product-id product-id)
    (map-get? product-catalog { product-id: product-id })
    none
  )
)

(define-read-only (get-discount-tier-details (product-id uint) (purchase-quantity uint))
  (if (and (is-valid-product-id product-id) (is-valid-quantity purchase-quantity))
    (default-to 
      { discount-rate: default-discount-rate, tier-enabled: false }
      (map-get? discount-tier-config { 
        product-id: product-id, 
        min-quantity-threshold: purchase-quantity 
      })
    )
    { discount-rate: default-discount-rate, tier-enabled: false }
  )
)

(define-read-only (calculate-order-total (product-id uint) (desired-quantity uint))
  (if (and (is-valid-product-id product-id) (is-valid-quantity desired-quantity))
    (match (get-product-info product-id)
      product-data
      (let 
        ((base-price (get price-per-unit product-data))
         (discount-info (get-discount-tier-details product-id desired-quantity))
         (discount-percentage (get discount-rate discount-info))
         (price-multiplier (- u100 discount-percentage))
         (gross-total (* base-price desired-quantity))
         (discounted-total (/ (* gross-total price-multiplier) u100)))
        
        (ok { 
          base-price-per-unit: base-price,
          quantity-requested: desired-quantity,
          discount-percentage-applied: discount-percentage, 
          final-total-cost: discounted-total,
          gross-subtotal: gross-total
        })
      )
      (err ERR-PRODUCT-NOT-FOUND)
    )
    (err ERR-INVALID-INPUT-PARAMETER)
  )
)

(define-read-only (get-buyer-transaction-record (transaction-id uint))
  (map-get? purchase-transaction-ledger { 
    buyer-address: tx-sender, 
    transaction-id: transaction-id 
  })
)

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-read-only (get-marketplace-metrics)
  {
    total-revenue: (var-get total-revenue-collected),
    completed-transactions: (var-get completed-transaction-count),
    operational-status: (var-get marketplace-active),
    next-available-product-id: (var-get next-product-id),
    next-available-transaction-id: (var-get next-transaction-id)
  }
)

;; PRODUCT AVAILABILITY VERIFICATION

(define-private (ensure-product-exists (product-id uint))
  (if (is-valid-product-id product-id)
    (match (get-product-info product-id)
      product-data
      (if (get is-listed product-data)
        (ok true)
        (err ERR-PRODUCT-NOT-FOUND))
      (err ERR-PRODUCT-NOT-FOUND)
    )
    (err ERR-INVALID-INPUT-PARAMETER)
  )
)

(define-private (ensure-adequate-inventory (product-id uint) (required-units uint))
  (match (get-product-info product-id)
    product-data
    (if (>= (get available-quantity product-data) required-units)
      (ok true)
      (err ERR-INSUFFICIENT-INVENTORY))
    (err ERR-PRODUCT-NOT-FOUND)
  )
)

;; MERCHANT PRODUCT MANAGEMENT

(define-public (add-new-product (product-name (string-ascii 64)) (unit-price uint) (initial-inventory uint))
  (begin
    ;; Authorization and operational checks
    (asserts! (has-owner-privileges) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-marketplace-operational) ERR-MARKETPLACE-SUSPENDED)
    
    ;; Input validation
    (asserts! (is-valid-product-name product-name) ERR-INVALID-PRODUCT-NAME)
    (asserts! (is-valid-price unit-price) ERR-INVALID-PRICE-AMOUNT)
    (asserts! (is-valid-quantity initial-inventory) ERR-INVALID-QUANTITY-REQUESTED)
    
    ;; Product registration
    (let ((new-product-id (var-get next-product-id)))
      (map-set product-catalog 
        { product-id: new-product-id }
        { 
          name: product-name,
          price-per-unit: unit-price,
          available-quantity: initial-inventory,
          is-listed: true
        }
      )
      
      ;; Update product counter
      (var-set next-product-id (+ new-product-id u1))
      
      (ok new-product-id)
    )
  )
)

(define-public (adjust-inventory-level (product-id uint) (new-stock-level uint))
  (begin 
    ;; Authorization and operational checks
    (asserts! (has-owner-privileges) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-marketplace-operational) ERR-MARKETPLACE-SUSPENDED)
    
    ;; Input validation
    (asserts! (is-valid-product-id product-id) ERR-INVALID-INPUT-PARAMETER)
    (asserts! (is-valid-quantity new-stock-level) ERR-INVALID-QUANTITY-REQUESTED)
    
    ;; Product existence check
    (unwrap! (ensure-product-exists product-id) ERR-PRODUCT-NOT-FOUND)
    
    ;; Update inventory
    (let ((current-product-data (unwrap! (get-product-info product-id) ERR-PRODUCT-NOT-FOUND)))
      (map-set product-catalog
        { product-id: product-id }
        (merge current-product-data { available-quantity: new-stock-level })
      )
      (ok true)
    )
  )
)

(define-public (modify-product-price (product-id uint) (updated-price uint))
  (begin
    ;; Authorization and operational checks
    (asserts! (has-owner-privileges) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-marketplace-operational) ERR-MARKETPLACE-SUSPENDED)
    
    ;; Input validation
    (asserts! (is-valid-product-id product-id) ERR-INVALID-INPUT-PARAMETER)
    (asserts! (is-valid-price updated-price) ERR-INVALID-PRICE-AMOUNT)
    
    ;; Product existence check
    (unwrap! (ensure-product-exists product-id) ERR-PRODUCT-NOT-FOUND)
    
    ;; Price update
    (let ((current-product-data (unwrap! (get-product-info product-id) ERR-PRODUCT-NOT-FOUND)))
      (map-set product-catalog
        { product-id: product-id }
        (merge current-product-data { price-per-unit: updated-price })
      )
      (ok true)
    )
  )
)

(define-public (remove-product-from-catalog (product-id uint))
  (begin
    ;; Authorization and operational checks
    (asserts! (has-owner-privileges) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-marketplace-operational) ERR-MARKETPLACE-SUSPENDED)
    
    ;; Input validation
    (asserts! (is-valid-product-id product-id) ERR-INVALID-INPUT-PARAMETER)
    
    ;; Product existence check
    (unwrap! (ensure-product-exists product-id) ERR-PRODUCT-NOT-FOUND)
    
    ;; Product removal
    (let ((current-product-data (unwrap! (get-product-info product-id) ERR-PRODUCT-NOT-FOUND)))
      (map-set product-catalog
        { product-id: product-id }
        (merge current-product-data { is-listed: false })
      )
      (ok true)
    )
  )
)

;; DISCOUNT TIER CONFIGURATION

(define-public (establish-discount-tier 
  (product-id uint) 
  (minimum-purchase-quantity uint) 
  (discount-percentage uint))
  (begin
    ;; Authorization and operational checks
    (asserts! (has-owner-privileges) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-marketplace-operational) ERR-MARKETPLACE-SUSPENDED)
    
    ;; Input validation
    (asserts! (is-valid-product-id product-id) ERR-INVALID-INPUT-PARAMETER)
    (asserts! (is-valid-quantity minimum-purchase-quantity) ERR-INVALID-QUANTITY-REQUESTED)
    (asserts! (is-valid-discount-rate discount-percentage) ERR-INVALID-DISCOUNT-RATE)
    
    ;; Product existence check
    (unwrap! (ensure-product-exists product-id) ERR-PRODUCT-NOT-FOUND)
    
    ;; Discount tier creation
    (map-set discount-tier-config
      { product-id: product-id, min-quantity-threshold: minimum-purchase-quantity }
      { discount-rate: discount-percentage, tier-enabled: true }
    )
    
    (ok true)
  )
)

(define-public (remove-discount-tier (product-id uint) (minimum-purchase-quantity uint))
  (begin
    ;; Authorization and operational checks
    (asserts! (has-owner-privileges) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-marketplace-operational) ERR-MARKETPLACE-SUSPENDED)
    
    ;; Input validation
    (asserts! (is-valid-product-id product-id) ERR-INVALID-INPUT-PARAMETER)
    (asserts! (is-valid-quantity minimum-purchase-quantity) ERR-INVALID-QUANTITY-REQUESTED)
    
    ;; Remove discount tier
    (map-delete discount-tier-config 
      { product-id: product-id, min-quantity-threshold: minimum-purchase-quantity })
    
    (ok true)
  )
)

;; SINGLE ITEM PURCHASE PROCESSING

(define-public (execute-single-purchase (product-id uint) (purchase-quantity uint))
  (begin
    ;; Operational validation
    (asserts! (is-marketplace-operational) ERR-MARKETPLACE-SUSPENDED)
    
    ;; Input validation
    (asserts! (is-valid-product-id product-id) ERR-INVALID-INPUT-PARAMETER)
    (asserts! (is-valid-quantity purchase-quantity) ERR-INVALID-QUANTITY-REQUESTED)
    
    ;; Product and inventory checks
    (unwrap! (ensure-product-exists product-id) ERR-PRODUCT-NOT-FOUND)
    (unwrap! (ensure-adequate-inventory product-id purchase-quantity) ERR-INSUFFICIENT-INVENTORY)
    
    ;; Retrieve product and pricing information
    (let ((product-details (unwrap! (get-product-info product-id) ERR-PRODUCT-NOT-FOUND))
          (order-calculation (unwrap! (calculate-order-total product-id purchase-quantity) ERR-TRANSACTION-PROCESSING-FAILED)))
      
      (let ((payment-amount (get final-total-cost order-calculation))
            (assigned-transaction-id (var-get next-transaction-id))
            (current-inventory (get available-quantity product-details)))
        
        ;; Execute payment transfer
        (try! (stx-transfer? payment-amount tx-sender (var-get contract-owner)))
        
        ;; Update product inventory
        (map-set product-catalog
          { product-id: product-id }
          (merge product-details { available-quantity: (- current-inventory purchase-quantity) })
        )
        
        ;; Record transaction
        (map-set purchase-transaction-ledger
          { buyer-address: tx-sender, transaction-id: assigned-transaction-id }
          {
            purchased-product-id: product-id,
            units-purchased: purchase-quantity,
            final-payment-amount: payment-amount,
            transaction-block-height: block-height,
            applied-discount-rate: (get discount-percentage-applied order-calculation)
          }
        )
        
        ;; Update marketplace metrics
        (var-set total-revenue-collected (+ (var-get total-revenue-collected) payment-amount))
        (var-set completed-transaction-count (+ (var-get completed-transaction-count) u1))
        (var-set next-transaction-id (+ assigned-transaction-id u1))
        
        ;; Return purchase confirmation
        (ok {
          transaction-id: assigned-transaction-id,
          product-id: product-id,
          product-name: (get name product-details),
          units-purchased: purchase-quantity,
          total-payment: payment-amount,
          discount-applied: (get discount-percentage-applied order-calculation),
          inventory-remaining: (- current-inventory purchase-quantity)
        })
      )
    )
  )
)

;; BULK ORDER PROCESSING UTILITIES

(define-private (process-bulk-order-item
  (order-item { product-id: uint, desired-quantity: uint })
  (assigned-transaction-id uint))
  
  (if (and 
        (is-valid-product-id (get product-id order-item))
        (is-valid-quantity (get desired-quantity order-item)))
    (let ((item-product-id (get product-id order-item))
          (item-quantity (get desired-quantity order-item)))
    
      (match (get-product-info item-product-id)
        product-details
        (let ((product-name (get name product-details))
              (unit-price (get price-per-unit product-details))
              (available-stock (get available-quantity product-details)))
          
          (match (calculate-order-total item-product-id item-quantity)
            pricing-calculation
            (let ((item-payment-total (get final-total-cost pricing-calculation))
                  (discount-applied (get discount-percentage-applied pricing-calculation)))
                
                ;; Update inventory
                (map-set product-catalog
                  { product-id: item-product-id }
                  (merge product-details { available-quantity: (- available-stock item-quantity) })
                )
                
                ;; Record transaction
                (map-set purchase-transaction-ledger
                  { buyer-address: tx-sender, transaction-id: assigned-transaction-id }
                  {
                    purchased-product-id: item-product-id,
                    units-purchased: item-quantity,
                    final-payment-amount: item-payment-total,
                    transaction-block-height: block-height,
                    applied-discount-rate: discount-applied
                  }
                )
                
                ;; Update metrics
                (var-set total-revenue-collected (+ (var-get total-revenue-collected) item-payment-total))
                (var-set completed-transaction-count (+ (var-get completed-transaction-count) u1))
                
                ;; Return processed item details
                {
                  transaction-id: assigned-transaction-id,
                  product-id: item-product-id,
                  product-name: product-name,
                  units-purchased: item-quantity,
                  total-payment: item-payment-total,
                  discount-applied: discount-applied
                }
            )
            pricing-error
            {
              transaction-id: u0,
              product-id: u0,
              product-name: "",
              units-purchased: u0,
              total-payment: u0,
              discount-applied: u0
            }
          )
        )
        {
          transaction-id: u0,
          product-id: u0,
          product-name: "",
          units-purchased: u0,
          total-payment: u0,
          discount-applied: u0
        }
      )
    )
    ;; Invalid input fallback
    {
      transaction-id: u0,
      product-id: u0,
      product-name: "",
      units-purchased: u0,
      total-payment: u0,
      discount-applied: u0
    }
  )
)

(define-private (compute-bulk-order-total
  (order-items (list 10 { product-id: uint, desired-quantity: uint })))
  
  (fold sum-item-costs order-items u0)
)

(define-private (sum-item-costs
  (order-item { product-id: uint, desired-quantity: uint })
  (accumulated-total uint))
  
  (if (and 
        (is-valid-product-id (get product-id order-item))
        (is-valid-quantity (get desired-quantity order-item)))
    (let ((item-product-id (get product-id order-item))
          (item-quantity (get desired-quantity order-item)))
      
      (match (calculate-order-total item-product-id item-quantity)
        pricing-calculation
        (let ((item-cost (get final-total-cost pricing-calculation)))
          (+ accumulated-total item-cost))
        pricing-error
        accumulated-total
      )
    )
    accumulated-total
  )
)

(define-private (validate-bulk-order-viability
  (order-items (list 10 { product-id: uint, desired-quantity: uint })))
  
  (fold check-order-item-validity order-items true)
)

(define-private (check-order-item-validity
  (order-item { product-id: uint, desired-quantity: uint })
  (all-valid bool))
  
  (if (not all-valid)
    false
    (if (and 
          (is-valid-product-id (get product-id order-item))
          (is-valid-quantity (get desired-quantity order-item)))
      (let ((item-product-id (get product-id order-item))
            (item-quantity (get desired-quantity order-item)))
        
        (match (get-product-info item-product-id)
          product-details
          (let ((stock-available (get available-quantity product-details))
                (product-listed (get is-listed product-details)))
            
            (if (and product-listed (>= stock-available item-quantity))
              (match (calculate-order-total item-product-id item-quantity)
                pricing-calculation true
                pricing-error false
              )
              false
            )
          )
          false
        )
      )
      false
    )
  )
)

(define-private (execute-bulk-order-processing
  (order-items (list 10 { product-id: uint, desired-quantity: uint }))
  (initial-transaction-id uint))
  
  (fold process-with-incremental-transaction-id 
        order-items 
        { 
          current-transaction-id: initial-transaction-id, 
          processed-results: (list)
        })
)

(define-private (process-with-incremental-transaction-id
  (order-item { product-id: uint, desired-quantity: uint })
  (processing-context { 
    current-transaction-id: uint, 
    processed-results: (list 10 { 
      transaction-id: uint, 
      product-id: uint, 
      product-name: (string-ascii 64), 
      units-purchased: uint, 
      total-payment: uint, 
      discount-applied: uint 
    })
  }))
  
  (let ((current-transaction-id (get current-transaction-id processing-context))
        (existing-results (get processed-results processing-context))
        (processed-item-result (process-bulk-order-item order-item current-transaction-id)))
    
    {
      current-transaction-id: (+ current-transaction-id u1),
      processed-results: (default-to 
                        existing-results
                        (as-max-len? 
                          (append existing-results processed-item-result)
                          u10))
    }
  )
)

;; BULK PURCHASE EXECUTION

(define-public (execute-bulk-purchase 
  (order-items (list 10 { product-id: uint, desired-quantity: uint })))
  (begin
    ;; Operational validation
    (asserts! (is-marketplace-operational) ERR-MARKETPLACE-SUSPENDED)
    (asserts! (> (len order-items) u0) ERR-EMPTY-ORDER-LIST)
    (asserts! (<= (len order-items) max-bulk-items-per-order) ERR-MAXIMUM-ITEMS-EXCEEDED)
    
    ;; Validate entire bulk order
    (asserts! (validate-bulk-order-viability order-items) ERR-TRANSACTION-PROCESSING-FAILED)
    
    ;; Process payment and execute order
    (let ((total-order-payment (compute-bulk-order-total order-items)))
      (try! (stx-transfer? total-order-payment tx-sender (var-get contract-owner)))
      
      ;; Execute bulk order processing
      (let ((starting-transaction-id (var-get next-transaction-id))
            (bulk-processing-results (execute-bulk-order-processing order-items starting-transaction-id)))
        
        ;; Update transaction counter
        (var-set next-transaction-id (+ starting-transaction-id (len order-items)))
        
        ;; Return bulk order summary
        (ok { 
          total-payment-processed: total-order-payment,
          items-purchased: (len order-items),
          transaction-details: (get processed-results bulk-processing-results),
          bulk-order-successful: true
        })
      )
    )
  )
)

;; MARKETPLACE ADMINISTRATION

(define-public (transfer-ownership (new-contract-owner principal))
  (begin
    (asserts! (has-owner-privileges) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (not (is-eq new-contract-owner tx-sender)) ERR-INVALID-INPUT-PARAMETER)
    (var-set contract-owner new-contract-owner)
    (ok true)
  )
)

(define-public (suspend-marketplace)
  (begin
    (asserts! (has-owner-privileges) ERR-UNAUTHORIZED-ACCESS)
    (var-set marketplace-active false)
    (ok true)
  )
)

(define-public (reactivate-marketplace)
  (begin
    (asserts! (has-owner-privileges) ERR-UNAUTHORIZED-ACCESS)
    (var-set marketplace-active true)
    (ok true)
  )
)

(define-public (withdraw-collected-revenue (withdrawal-amount uint))
  (begin
    (asserts! (has-owner-privileges) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-valid-price withdrawal-amount) ERR-INVALID-PRICE-AMOUNT)
    (asserts! (<= withdrawal-amount (var-get total-revenue-collected)) ERR-INSUFFICIENT-PAYMENT)
    
    (try! (stx-transfer? withdrawal-amount (var-get contract-owner) tx-sender))
    (var-set total-revenue-collected (- (var-get total-revenue-collected) withdrawal-amount))
    (ok true)
  )
)