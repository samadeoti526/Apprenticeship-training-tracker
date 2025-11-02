;; Apprenticeship Training Manager
;; Comprehensive platform for tracking apprentice progress, skill verification, and certification

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-input (err u103))
(define-constant err-not-completed (err u104))
(define-constant err-already-certified (err u105))
(define-constant err-insufficient-milestones (err u106))

;; Data variables
(define-data-var apprentice-nonce uint u0)
(define-data-var milestone-nonce uint u0)
(define-data-var program-nonce uint u0)
(define-data-var certificate-nonce uint u0)
(define-data-var placement-nonce uint u0)

;; Data maps
;; Apprentice profiles with comprehensive information
(define-map apprentices
  { id: uint }
  {
    name: (string-ascii 100),
    trade: (string-ascii 50),
    trainer: principal,
    start-date: uint,
    status: (string-ascii 20),
    total-hours: uint,
    active: bool
  }
)

;; Training programs defining requirements
(define-map training-programs
  { id: uint }
  {
    name: (string-ascii 100),
    trade: (string-ascii 50),
    duration-weeks: uint,
    required-milestones: uint,
    created-by: principal,
    active: bool
  }
)

;; Training milestones for skill tracking
(define-map milestones
  { id: uint }
  {
    apprentice-id: uint,
    program-id: uint,
    skill: (string-ascii 100),
    description: (string-ascii 200),
    completed: bool,
    completion-date: (optional uint),
    verified-by: (optional principal),
    hours-logged: uint
  }
)

;; Competency assessments
(define-map competencies
  { apprentice-id: uint, skill-id: uint }
  {
    skill-name: (string-ascii 100),
    proficiency-level: uint,
    assessed-by: principal,
    assessment-date: uint,
    notes: (string-ascii 200)
  }
)

;; Certifications issued to apprentices
(define-map certificates
  { id: uint }
  {
    apprentice-id: uint,
    program-id: uint,
    issue-date: uint,
    issued-by: principal,
    credential-hash: (string-ascii 64),
    valid: bool
  }
)

;; Employer placements
(define-map placements
  { id: uint }
  {
    apprentice-id: uint,
    employer: principal,
    position: (string-ascii 100),
    start-date: uint,
    status: (string-ascii 20)
  }
)

;; Authorized trainers
(define-map authorized-trainers
  { trainer: principal }
  { authorized: bool, specialization: (string-ascii 50) }
)

;; Public functions

;; Register a new apprentice
(define-public (register-apprentice (name (string-ascii 100)) (trade (string-ascii 50)))
  (let
    (
      (apprentice-id (+ (var-get apprentice-nonce) u1))
    )
    (asserts! (> (len name) u0) err-invalid-input)
    (asserts! (> (len trade) u0) err-invalid-input)
    (map-set apprentices
      { id: apprentice-id }
      {
        name: name,
        trade: trade,
        trainer: tx-sender,
        start-date: block-height,
        status: "enrolled",
        total-hours: u0,
        active: true
      }
    )
    (var-set apprentice-nonce apprentice-id)
    (ok apprentice-id)
  )
)

;; Create a training program
(define-public (create-program (name (string-ascii 100)) (trade (string-ascii 50)) (duration uint) (required-milestones uint))
  (let
    (
      (program-id (+ (var-get program-nonce) u1))
    )
    (asserts! (> (len name) u0) err-invalid-input)
    (asserts! (> duration u0) err-invalid-input)
    (asserts! (> required-milestones u0) err-invalid-input)
    (map-set training-programs
      { id: program-id }
      {
        name: name,
        trade: trade,
        duration-weeks: duration,
        required-milestones: required-milestones,
        created-by: tx-sender,
        active: true
      }
    )
    (var-set program-nonce program-id)
    (ok program-id)
  )
)

;; Add a milestone to an apprentice's training
(define-public (add-milestone (apprentice-id uint) (program-id uint) (skill (string-ascii 100)) (description (string-ascii 200)))
  (let
    (
      (milestone-id (+ (var-get milestone-nonce) u1))
      (apprentice (unwrap! (map-get? apprentices { id: apprentice-id }) err-not-found))
    )
    (asserts! (> (len skill) u0) err-invalid-input)
    (map-set milestones
      { id: milestone-id }
      {
        apprentice-id: apprentice-id,
        program-id: program-id,
        skill: skill,
        description: description,
        completed: false,
        completion-date: none,
        verified-by: none,
        hours-logged: u0
      }
    )
    (var-set milestone-nonce milestone-id)
    (ok milestone-id)
  )
)

;; Complete and verify a milestone
(define-public (complete-milestone (milestone-id uint) (hours uint))
  (let
    (
      (milestone (unwrap! (map-get? milestones { id: milestone-id }) err-not-found))
      (apprentice (unwrap! (map-get? apprentices { id: (get apprentice-id milestone) }) err-not-found))
    )
    (asserts! (is-eq (get trainer apprentice) tx-sender) err-not-authorized)
    (asserts! (not (get completed milestone)) err-already-exists)
    (map-set milestones
      { id: milestone-id }
      (merge milestone {
        completed: true,
        completion-date: (some block-height),
        verified-by: (some tx-sender),
        hours-logged: hours
      })
    )
    (map-set apprentices
      { id: (get apprentice-id milestone) }
      (merge apprentice {
        total-hours: (+ (get total-hours apprentice) hours)
      })
    )
    (ok true)
  )
)

;; Assess apprentice competency in a skill
(define-public (assess-competency (apprentice-id uint) (skill-id uint) (skill-name (string-ascii 100)) (level uint) (notes (string-ascii 200)))
  (let
    (
      (apprentice (unwrap! (map-get? apprentices { id: apprentice-id }) err-not-found))
    )
    (asserts! (is-eq (get trainer apprentice) tx-sender) err-not-authorized)
    (asserts! (<= level u5) err-invalid-input)
    (map-set competencies
      { apprentice-id: apprentice-id, skill-id: skill-id }
      {
        skill-name: skill-name,
        proficiency-level: level,
        assessed-by: tx-sender,
        assessment-date: block-height,
        notes: notes
      }
    )
    (ok true)
  )
)

;; Issue a certificate upon program completion
(define-public (issue-certificate (apprentice-id uint) (program-id uint) (credential-hash (string-ascii 64)))
  (let
    (
      (certificate-id (+ (var-get certificate-nonce) u1))
      (apprentice (unwrap! (map-get? apprentices { id: apprentice-id }) err-not-found))
      (program (unwrap! (map-get? training-programs { id: program-id }) err-not-found))
    )
    (asserts! (is-eq (get trainer apprentice) tx-sender) err-not-authorized)
    (asserts! (get active apprentice) err-not-found)
    (map-set certificates
      { id: certificate-id }
      {
        apprentice-id: apprentice-id,
        program-id: program-id,
        issue-date: block-height,
        issued-by: tx-sender,
        credential-hash: credential-hash,
        valid: true
      }
    )
    (map-set apprentices
      { id: apprentice-id }
      (merge apprentice { status: "certified" })
    )
    (var-set certificate-nonce certificate-id)
    (ok certificate-id)
  )
)

;; Create a placement with an employer
(define-public (create-placement (apprentice-id uint) (employer principal) (position (string-ascii 100)))
  (let
    (
      (placement-id (+ (var-get placement-nonce) u1))
      (apprentice (unwrap! (map-get? apprentices { id: apprentice-id }) err-not-found))
    )
    (asserts! (> (len position) u0) err-invalid-input)
    (map-set placements
      { id: placement-id }
      {
        apprentice-id: apprentice-id,
        employer: employer,
        position: position,
        start-date: block-height,
        status: "active"
      }
    )
    (var-set placement-nonce placement-id)
    (ok placement-id)
  )
)

;; Update apprentice status
(define-public (update-apprentice-status (apprentice-id uint) (new-status (string-ascii 20)))
  (let
    (
      (apprentice (unwrap! (map-get? apprentices { id: apprentice-id }) err-not-found))
    )
    (asserts! (is-eq (get trainer apprentice) tx-sender) err-not-authorized)
    (map-set apprentices
      { id: apprentice-id }
      (merge apprentice { status: new-status })
    )
    (ok true)
  )
)

;; Authorize a trainer
(define-public (authorize-trainer (trainer principal) (specialization (string-ascii 50)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
    (map-set authorized-trainers
      { trainer: trainer }
      { authorized: true, specialization: specialization }
    )
    (ok true)
  )
)

;; Revoke certificate
(define-public (revoke-certificate (certificate-id uint))
  (let
    (
      (certificate (unwrap! (map-get? certificates { id: certificate-id }) err-not-found))
    )
    (asserts! (is-eq (get issued-by certificate) tx-sender) err-not-authorized)
    (map-set certificates
      { id: certificate-id }
      (merge certificate { valid: false })
    )
    (ok true)
  )
)

;; Read-only functions

;; Get apprentice details
(define-read-only (get-apprentice (id uint))
  (map-get? apprentices { id: id })
)

;; Get milestone details
(define-read-only (get-milestone (id uint))
  (map-get? milestones { id: id })
)

;; Get program details
(define-read-only (get-program (id uint))
  (map-get? training-programs { id: id })
)

;; Get certificate details
(define-read-only (get-certificate (id uint))
  (map-get? certificates { id: id })
)

;; Get placement details
(define-read-only (get-placement (id uint))
  (map-get? placements { id: id })
)

;; Get competency assessment
(define-read-only (get-competency (apprentice-id uint) (skill-id uint))
  (map-get? competencies { apprentice-id: apprentice-id, skill-id: skill-id })
)

;; Check if trainer is authorized
(define-read-only (is-authorized-trainer (trainer principal))
  (default-to false (get authorized (map-get? authorized-trainers { trainer: trainer })))
)

;; Get total apprentices count
(define-read-only (get-apprentice-count)
  (ok (var-get apprentice-nonce))
)

;; Get total certificates issued
(define-read-only (get-certificate-count)
  (ok (var-get certificate-nonce))
)
