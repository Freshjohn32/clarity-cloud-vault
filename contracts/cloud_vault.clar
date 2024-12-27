;; CloudVault - Decentralized Storage Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-funds (err u103))

;; Data Variables
(define-data-var min-storage-price uint u100) ;; minimum price per GB in STX
(define-data-var provider-count uint u0)

;; Storage Provider Data
(define-map providers principal
  {
    available-space: uint,    ;; in GB
    price-per-gb: uint,      ;; in STX
    total-clients: uint,
    reputation-score: uint,
    active: bool
  }
)

;; Storage Requests
(define-map storage-requests uint
  {
    client: principal,
    provider: principal,
    space-requested: uint,    ;; in GB
    price-per-gb: uint,
    status: (string-ascii 20) ;; pending, accepted, rejected
  }
)

;; Provider Registration
(define-public (register-provider (price-per-gb uint) (available-space uint))
  (let
    (
      (provider-exists (contract-call? .providers get provider tx-sender))
    )
    (asserts! (>= price-per-gb (var-get min-storage-price)) err-unauthorized)
    (asserts! (is-none provider-exists) err-already-exists)
    (map-set providers tx-sender
      {
        available-space: available-space,
        price-per-gb: price-per-gb,
        total-clients: u0,
        reputation-score: u100,
        active: true
      }
    )
    (var-set provider-count (+ (var-get provider-count) u1))
    (ok true)
  )
)

;; Update Provider Storage Space
(define-public (update-storage-space (new-space uint))
  (let
    (
      (provider-data (unwrap! (map-get? providers tx-sender) err-not-found))
    )
    (map-set providers tx-sender
      (merge provider-data { available-space: new-space })
    )
    (ok true)
  )
)

;; Request Storage
(define-public (request-storage (provider principal) (space-needed uint))
  (let
    (
      (provider-data (unwrap! (map-get? providers provider) err-not-found))
      (request-id (+ (var-get provider-count) u1))
    )
    (asserts! (>= (get available-space provider-data) space-needed) err-insufficient-funds)
    (map-set storage-requests request-id
      {
        client: tx-sender,
        provider: provider,
        space-requested: space-needed,
        price-per-gb: (get price-per-gb provider-data),
        status: "pending"
      }
    )
    (ok request-id)
  )
)

;; Accept Storage Request
(define-public (accept-request (request-id uint))
  (let
    (
      (request (unwrap! (map-get? storage-requests request-id) err-not-found))
      (provider-data (unwrap! (map-get? providers tx-sender) err-not-found))
    )
    (asserts! (is-eq (get provider request) tx-sender) err-unauthorized)
    (map-set storage-requests request-id
      (merge request { status: "accepted" })
    )
    (map-set providers tx-sender
      (merge provider-data
        {
          available-space: (- (get available-space provider-data) (get space-requested request)),
          total-clients: (+ (get total-clients provider-data) u1)
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

(define-read-only (get-total-providers)
  (ok (var-get provider-count))
)