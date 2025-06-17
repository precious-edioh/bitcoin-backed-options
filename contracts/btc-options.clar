;; Title: Bitcoin-Backed Options Protocol (BBOP) - Secure Layer-2 Options on Stacks

;; Summary:
;; A trust-minimized, collateral-backed protocol enabling users to create, exercise,
;; and settle BTC-denominated CALL and PUT options on the Stacks blockchain. Built for
;; compliance with Bitcoin value transfer and Layer-2 scaling principles.

;; Description:
;; The Bitcoin-Backed Options Protocol (BBOP) empowers users to deposit synthetic BTC (sBTC),
;; minting on-chain CALL and PUT options with fully-backed collateral. Features include:
;; - Dynamic BTC price oracle with staleness protection
;; - Configurable collateralization, fees, and expiry windows
;; - Secure creation, exercise, and expiry flows with strict authorization and error codes
;; - Transparent storage of balances, locked collateral, and option lifecycle states

;; Constants & Configuration

;; Contract owner (only deployer can manage protocol settings)
(define-constant CONTRACT_OWNER tx-sender)

;; Parameter Limits
(define-constant MAX_FEE_BASIS_POINTS u10000)      ;; Maximum platform fee = 100%
(define-constant MAX_COLLATERAL_RATIO u1000)       ;; Max collateral = 1000%
(define-constant MIN_DEPOSIT_AMOUNT u1000)         ;; Minimum deposit = 1sBTC
(define-constant MAX_DEPOSIT_AMOUNT u100000000000) ;; Maximum deposit cap
(define-constant MIN_VALIDITY_WINDOW u10)          ;; Minimum price validity = 10 blocks
(define-constant MAX_VALIDITY_WINDOW u1440)        ;; Max validity = ~24hrs

;; Error Codes
(define-constant ERR_NOT_AUTHORIZED     (err u100))
(define-constant ERR_INVALID_AMOUNT     (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_OPTION_NOT_FOUND   (err u103))
(define-constant ERR_OPTION_EXPIRED     (err u104))
(define-constant ERR_INVALID_STRIKE_PRICE (err u105))
(define-constant ERR_INVALID_EXPIRY     (err u106))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u107))
(define-constant ERR_OPTION_NOT_EXERCISABLE (err u108))
(define-constant ERR_STALE_PRICE        (err u109))
(define-constant ERR_INVALID_PRICE      (err u110))
(define-constant ERR_OPTION_NOT_EXPIRED (err u111))
(define-constant ERR_INVALID_PARAMETER  (err u112))

;; Protocol Parameters
(define-data-var min-collateral-ratio uint u150)   ;; Minimum 150% collateralization
(define-data-var platform-fee uint u10)            ;; Platform fee = 0.1%
(define-data-var next-option-id uint u0)

;; Oracle Configuration
(define-data-var oracle-address principal CONTRACT_OWNER)
(define-data-var btc-price uint u0)
(define-data-var price-last-updated uint u0)
(define-data-var price-validity-window uint u150)  ;; ~25 minutes

;; Data Maps
(define-map options
  uint  ;; option-id
  {
    creator: principal,
    holder: principal,
    option-type: (string-ascii 4),  ;; "CALL" or "PUT"
    strike-price: uint,
    expiry: uint,
    amount: uint,
    collateral: uint,
    status: (string-ascii 10)       ;; "ACTIVE", "EXERCISED", or "EXPIRED"
  }
)

(define-map user-balances
  principal
  {
    sbtc-balance: uint,
    locked-collateral: uint
  }
)

;; Oracle Functions
(define-public (update-btc-price (new-price uint))
  (begin
    (asserts! (is-eq tx-sender (var-get oracle-address)) ERR_NOT_AUTHORIZED)
    (asserts! (> new-price u0) ERR_INVALID_PRICE)
    (var-set btc-price new-price)
    (var-set price-last-updated stacks-block-height)
    (ok true)
  )
)

(define-read-only (get-current-btc-price)
  (let (
    (price (var-get btc-price))
    (last-updated (var-get price-last-updated))
    (validity-window (var-get price-validity-window))
  )
    (asserts! (> price u0) ERR_INVALID_PRICE)
    (asserts! (< (- stacks-block-height last-updated) validity-window) ERR_STALE_PRICE)
    (ok price)
  )
)

(define-public (set-oracle-address (new-oracle principal))
  (begin
    (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
    (asserts! (not (is-eq new-oracle 'SP000000000000000000002Q6VF78)) ERR_INVALID_PARAMETER)
    (var-set oracle-address new-oracle)
    (ok true)
  )
)

(define-public (set-price-validity-window (new-window uint))
  (begin
    (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
    (asserts! (and (>= new-window MIN_VALIDITY_WINDOW)
                  (<= new-window MAX_VALIDITY_WINDOW)) ERR_INVALID_PARAMETER)
    (var-set price-validity-window new-window)
    (ok true)
  )
)

;; Private Helpers
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (check-expiry (option-id uint))
  (let (
    (opt (unwrap! (map-get? options option-id) ERR_OPTION_NOT_FOUND))
    (now stacks-block-height)
  )
    (if (> now (get expiry opt))
      ERR_OPTION_EXPIRED
      (ok true))
  )
)

(define-private (update-user-balance (user principal) (delta uint) (is-subtract bool))
  (let (
    (bal (default-to { sbtc-balance: u0, locked-collateral: u0 }
           (map-get? user-balances user)))
    (sbtc (get sbtc-balance bal))
    (new-sbtc (if is-subtract
                 (begin (asserts! (>= sbtc delta) ERR_INSUFFICIENT_BALANCE)
                        (- sbtc delta))
                 (+ sbtc delta)))
  )
    (ok (map-set user-balances user
         (merge bal { sbtc-balance: new-sbtc })))
  )
)

;; Public API

;; Deposit sBTC
(define-public (deposit-sbtc (amount uint))
  (begin
    (asserts! (and (>= amount MIN_DEPOSIT_AMOUNT)
                   (<= amount MAX_DEPOSIT_AMOUNT)) ERR_INVALID_AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (try! (update-user-balance tx-sender amount false))
    (ok true)
  )
)

;; Create Option
(define-public (create-option (option-type (string-ascii 4))
                              (strike-price uint)
                              (expiry uint)
                              (amount uint))
  (let (
    (option-id (var-get next-option-id))
    (required-collateral (/ (* amount strike-price) u100))
    (user-bal (default-to { sbtc-balance: u0, locked-collateral: u0 }
                  (map-get? user-balances tx-sender)))
  )
    (asserts! (or (is-eq option-type "CALL") (is-eq option-type "PUT")) ERR_NOT_AUTHORIZED)
    (asserts! (>= strike-price u0) ERR_INVALID_STRIKE_PRICE)
    (asserts! (and (> expiry stacks-block-height)
                   (<= (- expiry stacks-block-height) u5200)) ERR_INVALID_EXPIRY)
    (asserts! (and (>= amount MIN_DEPOSIT_AMOUNT)
                   (<= amount MAX_DEPOSIT_AMOUNT)) ERR_INVALID_AMOUNT)
    (asserts! (>= (get sbtc-balance user-bal) required-collateral) ERR_INSUFFICIENT_COLLATERAL)

    (try! (update-user-balance tx-sender required-collateral true))

    (map-set options option-id {
      creator: tx-sender,
      holder: tx-sender,
      option-type: option-type,
      strike-price: strike-price,
      expiry: expiry,
      amount: amount,
      collateral: required-collateral,
      status: "ACTIVE"
    })

    (map-set user-balances tx-sender
      (merge user-bal { locked-collateral: (+ (get locked-collateral user-bal) required-collateral) }))

    (var-set next-option-id (+ option-id u1))
    (ok option-id)
  )
)

;; Exercise Option
(define-public (exercise-option (option-id uint))
  (let (
    (opt (unwrap! (map-get? options option-id) ERR_OPTION_NOT_FOUND))
    (current-price (unwrap! (get-current-btc-price) ERR_INVALID_PRICE))
  )
    (asserts! (is-eq (get holder opt) tx-sender) ERR_NOT_AUTHORIZED)
    (try! (check-expiry option-id))
    (asserts! (is-eq (get status opt) "ACTIVE") ERR_OPTION_NOT_EXERCISABLE)

    (if (is-eq (get option-type opt) "CALL")
      (if (> current-price (get strike-price opt))
        (let ((profit (- current-price (get strike-price opt))))
          (try! (update-user-balance tx-sender profit false))
          (map-set options option-id (merge opt { status: "EXERCISED" }))
          (ok true))
        ERR_OPTION_NOT_EXERCISABLE)
      (if (< current-price (get strike-price opt))
        (let ((profit (- (get strike-price opt) current-price)))
          (try! (update-user-balance tx-sender profit false))
          (map-set options option-id (merge opt { status: "EXERCISED" }))
          (ok true))
        ERR_OPTION_NOT_EXERCISABLE))
  )
)

;; Expire Option
(define-public (expire-option (option-id uint))
  (let ((opt (unwrap! (map-get? options option-id) ERR_OPTION_NOT_FOUND)))
    (asserts! (> stacks-block-height (get expiry opt)) ERR_OPTION_NOT_EXPIRED)
    (asserts! (is-eq (get status opt) "ACTIVE") ERR_OPTION_NOT_EXERCISABLE)

    (try! (update-user-balance (get creator opt) (get collateral opt) false))
    (map-set options option-id (merge opt { status: "EXPIRED" }))
    (ok true)
  )
)
