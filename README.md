# BitCoin Dice

A provably fair dice betting game built on Stacks blockchain using Clarity smart contracts.

## Features

- Provably fair dice rolls using VRF
- Simple betting mechanism (1-6 target numbers)
- 5x payout multiplier for winning bets
- Transparent on-chain game resolution

## How to Play

1. Place a bet by calling `place-bet` with your target number (1-6) and bet amount
2. Wait for the next block to be mined
3. Call `resolve-game` with your game ID to reveal the result
4. Winners receive 5x their bet amount

## Smart Contract Functions

- `place-bet`: Create a new dice game
- `resolve-game`: Resolve a pending game
- `get-game`: View game details
- `get-game-count`: Get total number of games

## Development

Built with Clarinet for local development and testing.