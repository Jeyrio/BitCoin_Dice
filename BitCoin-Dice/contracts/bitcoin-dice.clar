;; BitCoin Dice - A provably fair dice game on Stacks
;; Players can bet on dice outcomes and win STX

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

;; - Add place-bet function with comprehensive validation and house balance checks
;; - Implement provably fair dice resolution using VRF for randomness
;; - Include automatic payout system with 5x multiplier for winning bets
;; - Integrate player statistics tracking for game history
;; - Add basic read-only functions for game data retrieval

(define-public (place-bet (target-number uint) (bet-amount uint))
  (let
    (
      (game-id (+ (var-get game-counter) u1))
      (max-payout (* bet-amount u5))
    )
    (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
    (asserts! (and (>= target-number u1) (<= target-number u6)) ERR_INVALID_BET)
    (asserts! (and (>= bet-amount (var-get min-bet)) (<= bet-amount (var-get max-bet))) ERR_INVALID_BET)
    (asserts! (>= (var-get house-balance) max-payout) ERR_INSUFFICIENT_HOUSE_FUNDS)
    
    (try! (stx-transfer? bet-amount tx-sender (as-contract tx-sender)))
    (var-set game-counter game-id)
    (var-set house-balance (+ (var-get house-balance) bet-amount))
    
    (map-set games
      { game-id: game-id }
      {
        player: tx-sender,
        bet-amount: bet-amount,
        target-number: target-number,
        block-height: block-height,
        resolved: false,
        won: false
      }
    )
    
    ;; Update player stats
    (update-player-stats tx-sender bet-amount u0)
    (ok game-id)
  )
)

(define-public (resolve-game (game-id uint))
  (let
    (
      (game-data (unwrap! (map-get? games { game-id: game-id }) ERR_GAME_NOT_FOUND))
      (dice-roll (+ (mod (unwrap-panic (get-block-info? vrf-seed (get block-height game-data))) u6) u1))
      (won (is-eq dice-roll (get target-number game-data)))
      (payout (if won (* (get bet-amount game-data) u5) u0))
    )
    (asserts! (not (get resolved game-data)) ERR_GAME_NOT_FOUND)
    
    (map-set games
      { game-id: game-id }
      (merge game-data { resolved: true, won: won })
    )
    
    (if won
      (begin
        (try! (as-contract (stx-transfer? payout tx-sender (get player game-data))))
        (var-set house-balance (- (var-get house-balance) payout))
        (update-player-stats (get player game-data) u0 payout)
      )
      true
    )
    (ok { dice-roll: dice-roll, won: won, payout: payout })
  )
)

(define-read-only (get-game (game-id uint))
  (map-get? games { game-id: game-id })
)

(define-read-only (get-game-count)
  (var-get game-counter)
)