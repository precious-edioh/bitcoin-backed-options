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