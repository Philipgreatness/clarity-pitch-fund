;; PitchFund - Decentralized Crowdfunding Platform

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-invalid-amount (err u101))
(define-constant err-deadline-passed (err u102))
(define-constant err-campaign-not-found (err u103))
(define-constant err-campaign-active (err u104))
(define-constant err-goal-not-reached (err u105))

;; Data Variables
(define-data-var campaign-id uint u0)

;; Define campaign map
(define-map campaigns uint {
  creator: principal,
  title: (string-ascii 100),
  description: (string-ascii 500),
  goal: uint,
  deadline: uint,
  raised: uint,
  claimed: bool
})

;; Define contributions map
(define-map contributions (tuple (campaign-id uint) (contributor principal)) uint)

;; Public Functions
(define-public (create-campaign (title (string-ascii 100)) (description (string-ascii 500)) (goal uint) (deadline uint))
  (let ((new-id (+ (var-get campaign-id) u1)))
    (asserts! (> deadline block-height) err-deadline-passed)
    (asserts! (> goal u0) err-invalid-amount)
    (map-set campaigns new-id {
      creator: tx-sender,
      title: title,
      description: description,
      goal: goal,
      deadline: deadline,
      raised: u0,
      claimed: false
    })
    (var-set campaign-id new-id)
    (ok new-id)))

(define-public (contribute (campaign-id uint) (amount uint))
  (let (
    (campaign (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found))
    (current-contribution (default-to u0 (map-get? contributions {campaign-id: campaign-id, contributor: tx-sender})))
  )
    (asserts! (< block-height (get deadline campaign)) err-deadline-passed)
    (asserts! (>= (stx-get-balance tx-sender) amount) err-invalid-amount)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set campaigns campaign-id 
      (merge campaign {raised: (+ (get raised campaign) amount)}))
    (map-set contributions {campaign-id: campaign-id, contributor: tx-sender} 
      (+ current-contribution amount))
    (ok true)))

(define-public (withdraw-funds (campaign-id uint))
  (let ((campaign (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found)))
    (asserts! (is-eq (get creator campaign) tx-sender) err-unauthorized)
    (asserts! (>= (get raised campaign) (get goal campaign)) err-goal-not-reached)
    (asserts! (not (get claimed campaign)) err-unauthorized)
    (try! (as-contract (stx-transfer? (get raised campaign) tx-sender (get creator campaign))))
    (map-set campaigns campaign-id 
      (merge campaign {claimed: true}))
    (ok true)))

(define-public (claim-refund (campaign-id uint))
  (let (
    (campaign (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found))
    (contribution (unwrap! (map-get? contributions {campaign-id: campaign-id, contributor: tx-sender}) err-unauthorized))
  )
    (asserts! (> (get deadline campaign) block-height) err-campaign-active)
    (asserts! (< (get raised campaign) (get goal campaign)) err-unauthorized)
    (try! (as-contract (stx-transfer? contribution tx-sender tx-sender)))
    (map-delete contributions {campaign-id: campaign-id, contributor: tx-sender})
    (ok true)))

;; Read Only Functions
(define-read-only (get-campaign (campaign-id uint))
  (ok (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found)))

(define-read-only (get-contribution (campaign-id uint) (contributor principal))
  (ok (default-to u0 (map-get? contributions {campaign-id: campaign-id, contributor: contributor}))))
