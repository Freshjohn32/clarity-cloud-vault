;; CloudVault - Decentralized Storage Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102)) 
(define-constant err-insufficient-funds (err u103))
(define-constant err-invalid-payment (err u104))
(define-constant err-contract-paused (err u105))
(define-constant err-insufficient-stake (err u106))
(define-constant err-invalid-request (err u107))
(define-constant grace-period-blocks u72) ;; ~12 hours grace period

;; Data Variables
(define-data-var min-storage-price uint u100) ;; minimum price per GB in STX
(define-data-var provider-count uint u0)
(define-data-var contract-paused bool false)
(define-data-var min-provider-stake uint u1000000) ;; minimum stake in STX
(define-data-var request-counter uint u0)

;; Storage Provider Data
(define-map providers principal
  {
    available-space: uint,    ;; in GB
    price-per-gb: uint,      ;; in STX
    total-clients: uint,
    reputation-score: uint,
    active: bool,
    earnings: uint,          ;; total STX earned
    stake: uint,            ;; staked STX
    space-utilized: uint,   ;; currently used space
    withdrawable-earnings: uint  ;; earnings available for withdrawal
    penalties: uint         ;; accumulated penalties
  }
)

;; Storage Requests
(define-map storage-requests uint 
  {
    client: principal,
    provider: principal,
    space-requested: uint,    ;; in GB
    price-per-gb: uint,
    status: (string-ascii 20), ;; pending, accepted, rejected, cancelled
    payment-status: (string-ascii 20), ;; unpaid, paid, late
    last-payment: uint,        ;; block height of last payment
    payment-due: uint,         ;; next payment due at block height
    grace-period-end: uint,    ;; end of grace period
    total-paid: uint,          ;; total amount paid
    creation-time: uint        ;; request creation block height
  }
)

;; Provider Management Functions
(define-public (register-provider (price-per-gb uint) (available-space uint))
  (let
    (
      (provider-exists (map-get? providers tx-sender))
    )
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (>= price-per-gb (var-get min-storage-price)) err-unauthorized)
    (asserts! (is-none provider-exists) err-already-exists)
    ;; Require stake deposit
    (try! (stx-transfer? (var-get min-provider-stake) tx-sender (as-contract tx-sender)))
    (map-set providers tx-sender
      {
        available-space: available-space,
        price-per-gb: price-per-gb,
        total-clients: u0,
        reputation-score: u100,
        active: true,
        earnings: u0,
        stake: (var-get min-provider-stake),
        space-utilized: u0,
        withdrawable-earnings: u0,
        penalties: u0
      }
    )
    (var-set provider-count (+ (var-get provider-count) u1))
    (ok true)
  )
)

;; Enhanced Payment Processing with Partial Payments
(define-public (make-payment (request-id uint) (payment-amount uint))
  (let
    (
      (request (unwrap! (map-get? storage-requests request-id) err-not-found))
      (provider-data (unwrap! (map-get? providers (get provider request)) err-not-found))
      (required-amount (* (get space-requested request) (get price-per-gb request)))
      (current-block (unwrap! block-height u0))
    )
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (is-eq (get client request) tx-sender) err-unauthorized)
    (asserts! (>= payment-amount u0) err-invalid-payment)
    (try! (stx-transfer? payment-amount tx-sender (get provider request)))
    
    ;; Update provider earnings and reputation
    (map-set providers (get provider request)
      (merge provider-data 
        { 
          earnings: (+ (get earnings provider-data) payment-amount),
          withdrawable-earnings: (+ (get withdrawable-earnings provider-data) payment-amount),
          reputation-score: (+ (get reputation-score provider-data) u1)
        }
      )
    )
    
    ;; Update payment status with grace period
    (map-set storage-requests request-id
      (merge request 
        {
          payment-status: (if (>= payment-amount required-amount) "paid" "partial"),
          last-payment: current-block,
          payment-due: (+ current-block u144),
          grace-period-end: (+ current-block u144 grace-period-blocks),
          total-paid: (+ (get total-paid request) payment-amount)
        }
      )
    )
    (ok true)
  )
)

;; Provider Withdrawal Function
(define-public (withdraw-earnings)
  (let
    (
      (provider-data (unwrap! (map-get? providers tx-sender) err-not-found))
      (withdrawable (get withdrawable-earnings provider-data))
    )
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (> withdrawable u0) err-insufficient-funds)
    (try! (as-contract (stx-transfer? withdrawable tx-sender tx-sender)))
    (map-set providers tx-sender
      (merge provider-data 
        {
          withdrawable-earnings: u0
        }
      )
    )
    (ok withdrawable)
  )
)

;; Request Management Functions
(define-public (cancel-request (request-id uint))
  (let
    (
      (request (unwrap! (map-get? storage-requests request-id) err-not-found))
    )
    (asserts! (or (is-eq (get client request) tx-sender)
                 (is-eq (get provider request) tx-sender)) err-unauthorized)
    (map-set storage-requests request-id
      (merge request 
        {
          status: "cancelled"
        }
      )
    )
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-provider-details (provider principal))
  (map-get? providers provider)
)

(define-read-only (get-request-details (request-id uint))
  (map-get? storage-requests request-id)
)

(define-read-only (get-contract-status)
  (ok (var-get contract-paused))
)
