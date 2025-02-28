# PitchFund
A decentralized crowdfunding platform with blockchain verification built on Stacks.

## Features
- Create funding campaigns with target amount and deadline
- Contribute funds to existing campaigns
- Withdraw funds when campaign goal is reached
- Refund contributors if campaign fails
- View campaign details and contribution history

## Setup and Installation
1. Clone the repository
2. Install Clarinet (if not already installed)
3. Run `clarinet check` to verify the contract
4. Run `clarinet test` to run the test suite

## Usage Examples
```clarity
;; Create a new campaign
(contract-call? .pitch-fund create-campaign 
  "My Project" 
  "Project Description" 
  u100000000 
  u1672531200)

;; Contribute to a campaign
(contract-call? .pitch-fund contribute u1 u1000000)

;; Withdraw funds (creator only, after successful campaign)
(contract-call? .pitch-fund withdraw-funds u1)

;; Get campaign details
(contract-call? .pitch-fund get-campaign u1)
```

## Dependencies
- Clarity language
- Clarinet for testing and deployment
