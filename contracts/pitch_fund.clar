;; PitchFund - Decentralized Crowdfunding Platform

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-invalid-amount (err u101))
(define-constant err-deadline-passed (err u102))
(define-constant err-campaign-not-found (err u103))
(define-constant err-campaign-active (err u104))
(define-constant err-goal-not-reached (err u105))
(define-constant err-invalid-parameters (err u106))

;; Data Variables
(define-data-var campaign-id uint u0)

;; Events
(define-data-var last-event-id uint u0)

(define-map events uint {
  event-type: (string-ascii 20),
  campaign-id: uint,
  user: principal,
  amount: uint,
  timestamp: uint
})

;; Campaign Status
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-SUCCESSFUL u2)
(define-constant STATUS-FAILED u3)

;; Define campaign map
(define-map campaigns uint {
  creator: principal,
  title: (string-ascii 100),
  description: (string-ascii 500),
  goal: uint,
  deadline: uint,
  raised: uint,
  claimed: bool,
  status: uint
})

;; Define contributions map
(define-map contributions (tuple (campaign-id uint) (contributor principal)) uint)

;; Helper Functions
(define-private (emit-event (event-type (string-ascii 20)) (campaign-id uint) (amount uint))
  (let ((new-id (+ (var-get last-event-id) u1)))
    (map-set events new-id {
      event-type: event-type,
      campaign-id: campaign-id,
      user: tx-sender,
      amount: amount,
      timestamp: block-height
    })
    (var-set last-event-id new-id)
    true))

;; Public Functions
(define-public (create-campaign (title (string-ascii 100)) (description (string-ascii 500)) (goal uint) (deadline uint))
  (let ((new-id (+ (var-get campaign-id) u1)))
    (asserts! (> deadline block-height) err-deadline-passed)
    (asserts! (> goal u0) err-invalid-amount)
    (asserts! (>= (- deadline block-height) u100) err-invalid-parameters)
    (map-set campaigns new-id {
      creator: tx-sender,
      title: title,
      description: description,
      goal: goal,
      deadline: deadline,
      raised: u0,
      claimed: false,
      status: STATUS-ACTIVE
    })
    (var-set campaign-id new-id)
    (emit-event "CAMPAIGN_CREATED" new-id u0)
    (ok new-id)))

(define-public (contribute (campaign-id uint) (amount uint))
  (let (
    (campaign (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found))
    (current-contribution (default-to u0 (map-get? contributions {campaign-id: campaign-id, contributor: tx-sender})))
  )
    (asserts! (< block-height (get deadline campaign)) err-deadline-passed)
    (asserts! (is-eq (get status campaign) STATUS-ACTIVE) err-campaign-active)
    (asserts! (>= (stx-get-balance tx-sender) amount) err-invalid-amount)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set campaigns campaign-id 
      (merge campaign {raised: (+ (get raised campaign) amount)}))
    (map-set contributions {campaign-id: campaign-id, contributor: tx-sender} 
      (+ current-contribution amount))
    (emit-event "CONTRIBUTION" campaign-id amount)
    (ok true)))

(define-public (withdraw-funds (campaign-id uint))
  (let ((campaign (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found)))
    (asserts! (is-eq (get creator campaign) tx-sender) err-unauthorized)
    (asserts! (>= (get raised campaign) (get goal campaign)) err-goal-not-reached)
    (asserts! (not (get claimed campaign)) err-unauthorized)
    (try! (as-contract (stx-transfer? (get raised campaign) tx-sender (get creator campaign))))
    (map-set campaigns campaign-id 
      (merge campaign {claimed: true, status: STATUS-SUCCESSFUL}))
    (emit-event "WITHDRAWAL" campaign-id (get raised campaign))
    (ok true)))

(define-public (claim-refund (campaign-id uint))
  (let (
    (campaign (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found))
    (contribution (unwrap! (map-get? contributions {campaign-id: campaign-id, contributor: tx-sender}) err-unauthorized))
  )
    (asserts! (>= block-height (get deadline campaign)) err-campaign-active)
    (asserts! (< (get raised campaign) (get goal campaign)) err-unauthorized)
    (try! (as-contract (stx-transfer? contribution tx-sender tx-sender)))
    (map-delete contributions {campaign-id: campaign-id, contributor: tx-sender})
    (map-set campaigns campaign-id (merge campaign {status: STATUS-FAILED}))
    (emit-event "REFUND" campaign-id contribution)
    (ok true)))

;; Read Only Functions
(define-read-only (get-campaign (campaign-id uint))
  (ok (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found)))

(define-read-only (get-contribution (campaign-id uint) (contributor principal))
  (ok (default-to u0 (map-get? contributions {campaign-id: campaign-id, contributor: contributor}))))

(define-read-only (get-event (event-id uint))
  (ok (unwrap! (map-get? events event-id) err-not-found)))
