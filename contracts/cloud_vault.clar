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
(define-constant grace-period-blocks u72) ;; ~12 hours grace period

;; Data Variables
(define-data-var min-storage-price uint u100) ;; minimum price per GB in STX
(define-data-var provider-count uint u0)
(define-data-var contract-paused bool false)
(define-data-var min-provider-stake uint u1000000) ;; minimum stake in STX

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
    space-utilized: uint    ;; currently used space
  }
)

;; Storage Requests
(define-map storage-requests uint 
  {
    client: principal,
    provider: principal,
    space-requested: uint,    ;; in GB
    price-per-gb: uint,
    status: (string-ascii 20), ;; pending, accepted, rejected
    payment-status: (string-ascii 20), ;; unpaid, paid, late
    last-payment: uint,        ;; block height of last payment
    payment-due: uint,         ;; next payment due at block height
    grace-period-end: uint     ;; end of grace period
  }
)

;; Administrative Functions
(define-public (toggle-contract-pause)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (ok (var-set contract-paused (not (var-get contract-paused))))
  )
)

;; Provider Registration with Stake
(define-public (register-provider (price-per-gb uint) (available-space uint))
  (let
    (
      (provider-exists (contract-call? .providers get provider tx-sender))
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
        space-utilized: u0
      }
    )
    (var-set provider-count (+ (var-get provider-count) u1))
    (ok true)
  )
)

;; Enhanced Payment Processing
(define-public (make-payment (request-id uint))
  (let
    (
      (request (unwrap! (map-get? storage-requests request-id) err-not-found))
      (provider-data (unwrap! (map-get? providers (get provider request)) err-not-found))
      (payment-amount (* (get space-requested request) (get price-per-gb request)))
      (current-block (unwrap! block-height u0))
    )
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (is-eq (get client request) tx-sender) err-unauthorized)
    (try! (stx-transfer? payment-amount tx-sender (get provider request)))
    
    ;; Update provider earnings and reputation
    (map-set providers (get provider request)
      (merge provider-data 
        { 
          earnings: (+ (get earnings provider-data) payment-amount),
          reputation-score: (+ (get reputation-score provider-data) u1)
        }
      )
    )
    
    ;; Update payment status with grace period
    (map-set storage-requests request-id
      (merge request 
        {
          payment-status: "paid",
          last-payment: current-block,
          payment-due: (+ current-block u144),
          grace-period-end: (+ current-block u144 grace-period-blocks)
        }
      )
    )
    (ok true)
  )
)

;; Provider Deactivation
(define-public (deactivate-provider)
  (let
    (
      (provider-data (unwrap! (map-get? providers tx-sender) err-not-found))
    )
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (is-eq (get space-utilized provider-data) u0) err-unauthorized)
    ;; Return stake if no active clients
    (try! (as-contract (stx-transfer? (get stake provider-data) tx-sender tx-sender)))
    (map-set providers tx-sender
      (merge provider-data { active: false, stake: u0 })
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
