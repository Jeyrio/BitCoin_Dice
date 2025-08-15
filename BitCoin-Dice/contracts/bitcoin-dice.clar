;; BitCoin Dice - A provably fair dice game on Stacks
;; Players can bet on dice outcomes and win STX

;; COMMIT MESSAGE: feat: initialize contract constants and data structures
;; 
;; - Add contract owner and error constants for proper access control
;; - Define data variables for game state management and betting limits
;; - Create game and player statistics maps for comprehensive tracking
;; - Set up foundation for secure dice betting contract

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_BALANCE (err u101))
(define-constant ERR_INVALID_BET (err u102))
(define-constant ERR_GAME_NOT_FOUND (err u103))
(define-constant ERR_INSUFFICIENT_HOUSE_FUNDS (err u104))
(define-constant ERR_WITHDRAWAL_FAILED (err u105))

(define-data-var game-counter uint u0)
(define-data-var house-balance uint u0)
(define-data-var min-bet uint u1000000) ;; 1 STX minimum
(define-data-var max-bet uint u100000000) ;; 100 STX maximum
(define-data-var contract-paused bool false)

(define-map games
  { game-id: uint }
  {
    player: principal,
    bet-amount: uint,
    target-number: uint,
    block-height: uint,
    resolved: bool,
    won: bool
  }
)

;; Track player statistics
(define-map player-stats
  { player: principal }
  {
    games-played: uint,
    total-wagered: uint,
    total-won: uint
  }
)