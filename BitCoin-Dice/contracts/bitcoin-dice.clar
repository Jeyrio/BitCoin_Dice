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

;; - Implement house funding and withdrawal system for contract owner
;; - Add dynamic betting limits configuration with validation
;; - Include emergency pause/unpause functionality for contract security
;; - Create player statistics and contract info read-only functions
;; - Ensure proper authorization checks for all administrative operations

(define-public (fund-house (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set house-balance (+ (var-get house-balance) amount))
    (ok true)
  )
)

;; NEW FUNCTION 1: Withdraw house funds (owner only)
(define-public (withdraw-house-funds (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= amount (var-get house-balance)) ERR_INSUFFICIENT_BALANCE)
    (try! (as-contract (stx-transfer? amount tx-sender CONTRACT_OWNER)))
    (var-set house-balance (- (var-get house-balance) amount))
    (ok amount)
  )
)

;; NEW FUNCTION 2: Set betting limits (owner only)
(define-public (set-bet-limits (new-min-bet uint) (new-max-bet uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> new-max-bet new-min-bet) ERR_INVALID_BET)
    (var-set min-bet new-min-bet)
    (var-set max-bet new-max-bet)
    (ok { min-bet: new-min-bet, max-bet: new-max-bet })
  )
)

;; NEW FUNCTION 3: Pause/unpause contract (owner only)
(define-public (toggle-contract-pause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set contract-paused (not (var-get contract-paused)))
    (ok (var-get contract-paused))
  )
)

;; NEW FUNCTION 4: Get player statistics
(define-read-only (get-player-stats (player principal))
  (default-to 
    { games-played: u0, total-wagered: u0, total-won: u0 }
    (map-get? player-stats { player: player })
  )
)

;; NEW FUNCTION 5: Get contract info and settings
(define-read-only (get-contract-info)
  {
    house-balance: (var-get house-balance),
    min-bet: (var-get min-bet),
    max-bet: (var-get max-bet),
    contract-paused: (var-get contract-paused),
    total-games: (var-get game-counter),
    owner: CONTRACT_OWNER
  }
)

;; - Add paginated game history retrieval for better UX
;; - Implement bulk game resolution for operational efficiency
;; - Create comprehensive helper functions for data management
;; - Add robust error handling for batch operations
;; - Optimize gas usage with efficient data structures and algorithms

;; NEW FUNCTION 6: Get recent games (with pagination)
(define-read-only (get-recent-games (start-game-id uint) (count uint))
  (let
    (
      (current-game-count (var-get game-counter))
      (end-id (if (<= start-game-id current-game-count) start-game-id current-game-count))
      (actual-count (if (> count u10) u10 count)) ;; Limit to 10 games max
    )
    (map get-game-by-id (generate-game-ids end-id actual-count))
  )
)

;; NEW FUNCTION 7: Bulk resolve games (resolve multiple games at once)
(define-public (bulk-resolve-games (game-ids (list 10 uint)))
  (let
    (
      (results (map resolve-single-game game-ids))
    )
    (ok results)
  )
)

;; Helper function for bulk resolve
(define-private (resolve-single-game (game-id uint))
  (match (resolve-game game-id)
    success success
    error { game-id: game-id, error: error }
  )
)

;; Helper function to generate game IDs for recent games
(define-private (generate-game-ids (start-id uint) (count uint))
  (if (is-eq count u0)
    (list)
    (if (is-eq start-id u0)
      (list)
      (unwrap-panic (as-max-len? 
        (concat 
          (list start-id) 
          (generate-game-ids (- start-id u1) (- count u1))
        ) 
        u10
      ))
    )
  )
)

;; Helper function to get game by ID for mapping
(define-private (get-game-by-id (game-id uint))
  {
    game-id: game-id,
    game-data: (map-get? games { game-id: game-id })
  }
)

;; Helper function to update player statistics
(define-private (update-player-stats (player principal) (wagered uint) (won uint))
  (let
    (
      (current-stats (get-player-stats player))
    )
    (map-set player-stats
      { player: player }
      {
        games-played: (+ (get games-played current-stats) u1),
        total-wagered: (+ (get total-wagered current-stats) wagered),
        total-won: (+ (get total-won current-stats) won)
      }
    )
  )
)