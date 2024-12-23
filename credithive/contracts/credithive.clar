;; CreditHive: Community-Based Lending Protocol
;; A decentralized lending protocol powered by community trust and participation

(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-LOAN-SIZE (err u101))
(define-constant ERR-INSUFFICIENT-FUNDS (err u102))
(define-constant ERR-POOR-STANDING (err u103))
(define-constant ERR-EXISTING-LOAN (err u104))
(define-constant TRUST-THRESHOLD u500) ;; Out of 1000
(define-constant VIOLATION-PENALTY u100)
(define-constant HONEY-POT-LIMIT u1000000) ;; In microSTX

;; Data Maps
(define-map hive-standing 
    principal 
    {
        trust-level: uint,
        completed-loans: uint,
        community-activity: uint,
        nectar-deposits: uint
    }
)

(define-map current-loans
    principal
    {
        honey-amount: uint,
        collection-height: uint,
        collected: bool
    }
)

(define-map nectar-reserves principal uint)

;; Initialize or update member standing
(define-public (join-hive (member principal))
    (let ((existing-member (get-member-standing member)))
        (if (is-none existing-member)
            (ok (map-set hive-standing member {
                trust-level: u500,  ;; Starting level
                completed-loans: u0,
                community-activity: u0,
                nectar-deposits: u0
            }))
            ERR-UNAUTHORIZED
        )
    )
)

;; Calculate trust level based on various factors
(define-private (compute-trust-level 
    (completed-loans uint) 
    (community-activity uint)
    (nectar-deposits uint))
    (let ((core-score (* completed-loans u100))
          (activity-bonus (* community-activity u50))
          (deposit-bonus (* nectar-deposits u50)))
        (+ (+ core-score activity-bonus) deposit-bonus)
    )
)

;; Update member's hive activity
(define-public (update-hive-activity
    (member principal)
    (activity-points uint)
    (deposit-points uint))
    (let ((current-standing (unwrap! (get-member-standing member) ERR-UNAUTHORIZED)))
        (ok (map-set hive-standing member
            {
                trust-level: (compute-trust-level 
                    (get completed-loans current-standing)
                    (+ (get community-activity current-standing) activity-points)
                    (+ (get nectar-deposits current-standing) deposit-points)
                ),
                completed-loans: (get completed-loans current-standing),
                community-activity: (+ (get community-activity current-standing) activity-points),
                nectar-deposits: (+ (get nectar-deposits current-standing) deposit-points)
            }
        ))
    )
)

;; Request honey (loan)
(define-public (request-honey (amount uint))
    (let (
        (collector tx-sender)
        (standing (unwrap! (get-member-standing collector) ERR-UNAUTHORIZED))
        (existing-loan (get-current-loan collector))
    )
        (asserts! (<= amount HONEY-POT-LIMIT) ERR-INVALID-LOAN-SIZE)
        (asserts! (>= (get trust-level standing) TRUST-THRESHOLD) ERR-POOR-STANDING)
        (asserts! (is-none existing-loan) ERR-EXISTING-LOAN)
        
        (map-set current-loans collector {
            honey-amount: amount,
            collection-height: (+ block-height u1440), ;; ~10 days with 10min blocks
            collected: false
        })
        
        (ok (as-contract (stx-transfer? amount (as-contract tx-sender) collector)))
    )
)

;; Return honey (repay loan)
(define-public (return-honey)
    (let (
        (collector tx-sender)
        (loan (unwrap! (get-current-loan collector) ERR-UNAUTHORIZED))
        (standing (unwrap! (get-member-standing collector) ERR-UNAUTHORIZED))
    )
        (asserts! (not (get collected loan)) ERR-UNAUTHORIZED)
        (try! (stx-transfer? (get honey-amount loan) collector (as-contract tx-sender)))
        
        (map-set current-loans collector {
            honey-amount: (get honey-amount loan),
            collection-height: (get collection-height loan),
            collected: true
        })
        
        (ok (map-set hive-standing collector {
            trust-level: (+ (get trust-level standing) u50),
            completed-loans: (+ (get completed-loans standing) u1),
            community-activity: (get community-activity standing),
            nectar-deposits: (get nectar-deposits standing)
        }))
    )
)

;; Check if honey is overdue and apply penalties
(define-public (check-honey-status (member principal))
    (let (
        (loan (unwrap! (get-current-loan member) ERR-UNAUTHORIZED))
        (standing (unwrap! (get-member-standing member) ERR-UNAUTHORIZED))
    )
        (if (and 
            (> block-height (get collection-height loan))
            (not (get collected loan))
        )
            (ok (map-set hive-standing member {
                trust-level: (- (get trust-level standing) VIOLATION-PENALTY),
                completed-loans: (get completed-loans standing),
                community-activity: (get community-activity standing),
                nectar-deposits: (get nectar-deposits standing)
            }))
            (ok true)
        )
    )
)

;; Getter functions
(define-read-only (get-member-standing (member principal))
    (map-get? hive-standing member)
)

(define-read-only (get-current-loan (member principal))
    (map-get? current-loans member)
)

(define-read-only (get-nectar-balance (member principal))
    (default-to u0 (map-get? nectar-reserves member))
)