;; Hawkpass - Smart Hawker License System
;; Daily permit token system for street vendors and hawkers
;; Manages license issuance, renewal, and compliance tracking

;; === CONSTANTS ===
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_LICENSE_NOT_FOUND (err u101))
(define-constant ERR_LICENSE_EXPIRED (err u102))
(define-constant ERR_INVALID_FEE (err u103))
(define-constant ERR_ALREADY_EXISTS (err u104))
(define-constant ERR_INSUFFICIENT_FUNDS (err u105))
(define-constant ERR_TRANSFER_FAILED (err u106))

;; License fees in microSTX
(define-constant DAILY_LICENSE_FEE u1000000)  ;; 1 STX
(define-constant RENEWAL_FEE u800000)         ;; 0.8 STX
(define-constant LATE_PENALTY u200000)        ;; 0.2 STX

;; Time constants (in blocks, ~10 min per block)
(define-constant BLOCKS_PER_DAY u144)         ;; ~24 hours
(define-constant GRACE_PERIOD u72)            ;; ~12 hours grace period

;; === DATA MAPS AND VARIABLES ===
;; License counter for unique IDs
(define-data-var license-counter uint u0)

;; Total fees collected
(define-data-var total-fees-collected uint u0)

;; Authorized authorities (can issue/revoke licenses)
(define-map authorities principal bool)

;; License information
(define-map licenses uint {
    hawker: principal,
    issued-at: uint,
    expires-at: uint,
    status: (string-ascii 20),
    fee-paid: uint,
    renewal-count: uint,
    is-active: bool
})

;; Hawker to license mapping (one active license per hawker)
(define-map hawker-licenses principal uint)

;; License history for audit trail
(define-map license-history uint (list 50 {
    action: (string-ascii 20),
    timestamp: uint,
    actor: principal,
    details: (string-ascii 100)
}))

;; === PRIVATE FUNCTIONS ===
;; Check if caller is authorized authority
(define-private (is-authority (user principal))
    (or (is-eq user CONTRACT_OWNER)
        (default-to false (map-get? authorities user)))
)

;; Get current block height
(define-private (get-current-block)
    stacks-block-height
)

;; Calculate license expiry block
(define-private (calculate-expiry (start-block uint))
    (+ start-block BLOCKS_PER_DAY)
)

;; Add entry to license history
(define-private (add-to-history (license-id uint) (action (string-ascii 20)) (actor principal) (details (string-ascii 100)))
    (let (
        (current-history (default-to (list) (map-get? license-history license-id)))
        (new-entry {
            action: action,
            timestamp: (get-current-block),
            actor: actor,
            details: details
        })
    )
        (map-set license-history license-id 
            (unwrap-panic (as-max-len? (append current-history new-entry) u50))
        )
    )
)

;; Generate new license ID
(define-private (generate-license-id)
    (let ((new-id (+ (var-get license-counter) u1)))
        (var-set license-counter new-id)
        new-id
    )
)

;; === PUBLIC FUNCTIONS ===
;; Initialize contract - add deployer as authority
(define-public (initialize)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set authorities CONTRACT_OWNER true)
        (ok "Contract initialized")
    )
)

;; Add new authority (only contract owner)
(define-public (add-authority (new-authority principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set authorities new-authority true)
        (ok "Authority added")
    )
)

;; Remove authority (only contract owner)
(define-public (remove-authority (authority principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (not (is-eq authority CONTRACT_OWNER)) ERR_UNAUTHORIZED)
        (map-delete authorities authority)
        (ok "Authority removed")
    )
)

;; Issue new daily license
(define-public (issue-license (hawker principal))
    (let (
        (current-block (get-current-block))
        (license-id (generate-license-id))
        (expiry-block (calculate-expiry current-block))
        (existing-license (map-get? hawker-licenses hawker))
    )
        (asserts! (is-authority tx-sender) ERR_UNAUTHORIZED)
        (asserts! (is-none existing-license) ERR_ALREADY_EXISTS)
        
        ;; Transfer fee from hawker to contract
        (try! (stx-transfer? DAILY_LICENSE_FEE hawker (as-contract tx-sender)))
        
        ;; Create license
        (map-set licenses license-id {
            hawker: hawker,
            issued-at: current-block,
            expires-at: expiry-block,
            status: "active",
            fee-paid: DAILY_LICENSE_FEE,
            renewal-count: u0,
            is-active: true
        })
        
        ;; Map hawker to license
        (map-set hawker-licenses hawker license-id)
        
        ;; Update fees collected
        (var-set total-fees-collected (+ (var-get total-fees-collected) DAILY_LICENSE_FEE))
        
        ;; Add to history
        (add-to-history license-id "issued" tx-sender "Daily license issued")
        
        (ok license-id)
    )
)

;; Renew existing license
(define-public (renew-license (license-id uint))
    (let (
        (license-info (unwrap! (map-get? licenses license-id) ERR_LICENSE_NOT_FOUND))
        (current-block (get-current-block))
        (hawker (get hawker license-info))
        (is-expired (> current-block (get expires-at license-info)))
        (fee (if is-expired (+ RENEWAL_FEE LATE_PENALTY) RENEWAL_FEE))
        (new-expiry (calculate-expiry current-block))
    )
        (asserts! (is-eq tx-sender hawker) ERR_UNAUTHORIZED)
        (asserts! (get is-active license-info) ERR_LICENSE_EXPIRED)
        
        ;; Transfer renewal fee
        (try! (stx-transfer? fee hawker (as-contract tx-sender)))
        
        ;; Update license
        (map-set licenses license-id 
            (merge license-info {
                expires-at: new-expiry,
                status: "active",
                renewal-count: (+ (get renewal-count license-info) u1),
                fee-paid: (+ (get fee-paid license-info) fee)
            })
        )
        
        ;; Update fees collected
        (var-set total-fees-collected (+ (var-get total-fees-collected) fee))
        
        ;; Add to history
        (add-to-history license-id "renewed" tx-sender 
            (if is-expired "License renewed with penalty" "License renewed")
        )
        
        (ok "License renewed")
    )
)

;; Revoke license (authority only)
(define-public (revoke-license (license-id uint) (reason (string-ascii 100)))
    (let (
        (license-info (unwrap! (map-get? licenses license-id) ERR_LICENSE_NOT_FOUND))
        (hawker (get hawker license-info))
    )
        (asserts! (is-authority tx-sender) ERR_UNAUTHORIZED)
        (asserts! (get is-active license-info) ERR_LICENSE_EXPIRED)
        
        ;; Deactivate license
        (map-set licenses license-id 
            (merge license-info {
                status: "revoked",
                is-active: false
            })
        )
        
        ;; Remove hawker mapping
        (map-delete hawker-licenses hawker)
        
        ;; Add to history
        (add-to-history license-id "revoked" tx-sender reason)
        
        (ok "License revoked")
    )
)

;; Collect fees (authority only)
(define-public (collect-fees (amount uint))
    (begin
        (asserts! (is-authority tx-sender) ERR_UNAUTHORIZED)
        (asserts! (<= amount (var-get total-fees-collected)) ERR_INSUFFICIENT_FUNDS)
        
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        (var-set total-fees-collected (- (var-get total-fees-collected) amount))
        
        (ok "Fees collected")
    )
)

;; === READ-ONLY FUNCTIONS ===
;; Get license information
(define-read-only (get-license-info (license-id uint))
    (map-get? licenses license-id)
)

;; Get hawker's current license
(define-read-only (get-hawker-license (hawker principal))
    (match (map-get? hawker-licenses hawker)
        license-id (map-get? licenses license-id)
        none
    )
)

;; Check if license is currently valid
(define-read-only (is-license-valid (license-id uint))
    (match (map-get? licenses license-id)
        license-info (and 
            (get is-active license-info)
            (> (get expires-at license-info) (get-current-block))
        )
        false
    )
)

;; Get license history
(define-read-only (get-license-history (license-id uint))
    (map-get? license-history license-id)
)

;; Get total fees collected
(define-read-only (get-total-fees)
    (var-get total-fees-collected)
)

;; Get license counter
(define-read-only (get-license-counter)
    (var-get license-counter)
)

;; Check if user is authority
(define-read-only (check-authority (user principal))
    (is-authority user)
)
