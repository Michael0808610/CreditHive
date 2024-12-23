;; CreditHive: Community-Based Lending Protocol
;; A decentralized lending protocol powered by community trust and collective decision making

;; Constants
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-LOAN-SIZE (err u101))
(define-constant ERR-INSUFFICIENT-FUNDS (err u102))
(define-constant ERR-POOR-STANDING (err u103))
(define-constant ERR-EXISTING-LOAN (err u104))
(define-constant ERR-INVALID-MOTION (err u105))
(define-constant ERR-MOTION-EXISTS (err u106))
(define-constant ERR-VOTING-CLOSED (err u107))
(define-constant ERR-VOTE-RECORDED (err u108))
(define-constant ERR-INVALID-MEMBER (err u109))
(define-constant ERR-INVALID-TRUST-LEVEL (err u110))
(define-constant ERR-INVALID-JUSTIFICATION (err u111))
(define-constant ERR-INVALID-ACTIVITY (err u112))

(define-constant TRUST-THRESHOLD u500) ;; Out of 1000
(define-constant VIOLATION-PENALTY u100)
(define-constant HONEY-POT-LIMIT u1000000) ;; In microSTX
(define-constant MOTION-DURATION u1440) ;; ~10 days with 10min blocks
(define-constant MINIMUM-VOTES-NEEDED u10)
(define-constant HIVE-COUNCIL-THRESHOLD u700) ;; Minimum score to participate in governance
(define-constant MAX-TRUST-LEVEL u1000)
(define-constant MAX-ACTIVITY-POINTS u100)
(define-constant MAX-DEPOSIT-POINTS u100)

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

;; Hive Governance Maps
(define-map trust-motions
    uint
    {
        initiator: principal,
        subject-member: principal,
        proposed-level: uint,
        justification: (string-ascii 256),
        support-count: uint,
        oppose-count: uint,
        close-height: uint,
        implemented: bool
    }
)

(define-map motion-votes
    {motion-id: uint, voter: principal}
    bool
)

(define-data-var motion-nonce uint u0)

;; Validation Functions
(define-private (validate-trust-level (level uint))
    (and (>= level u0) (<= level MAX-TRUST-LEVEL))
)

(define-private (validate-activity (points uint))
    (<= points MAX-ACTIVITY-POINTS)
)

(define-private (validate-member (member principal))
    (is-some (get-member-standing member))
)

;; Hive Functions

;; Initialize new member
(define-public (join-hive (member principal))
    (let ((existing-record (get-member-standing member)))
        (if (is-none existing-record)
            (ok (map-set hive-standing member {
                trust-level: u500,
                completed-loans: u0,
                community-activity: u0,
                nectar-deposits: u0
            }))
            ERR-UNAUTHORIZED
        )
    )
)

;; Calculate trust level based on activity
(define-private (compute-trust-level 
    (completed-loans uint) 
    (community-activity uint)
    (nectar-deposits uint))
    (let (
        (base-level (* completed-loans u100))
        (activity-bonus (* community-activity u50))
        (deposit-bonus (* nectar-deposits u50))
        (total-level (+ (+ base-level activity-bonus) deposit-bonus))
    )
        (if (> total-level MAX-TRUST-LEVEL)
            MAX-TRUST-LEVEL
            total-level
        )
    )
)

;; Update member's hive activity
(define-public (update-hive-activity
    (member principal)
    (activity-points uint)
    (deposit-points uint))
    (let (
        (current-standing (unwrap! (get-member-standing member) ERR-UNAUTHORIZED))
    )
        ;; Validate member exists and inputs
        (asserts! (validate-member member) ERR-INVALID-MEMBER)
        (asserts! (validate-activity activity-points) ERR-INVALID-ACTIVITY)
        (asserts! (validate-activity deposit-points) ERR-INVALID-ACTIVITY)
        
        ;; Validate current values
        (asserts! (validate-activity (get community-activity current-standing)) ERR-INVALID-ACTIVITY)
        (asserts! (validate-activity (get nectar-deposits current-standing)) ERR-INVALID-ACTIVITY)
        
        ;; Calculate new values safely
        (let (
            (new-activity (+ (get community-activity current-standing) activity-points))
            (new-deposits (+ (get nectar-deposits current-standing) deposit-points))
            (current-completed (get completed-loans current-standing))
        )
            ;; Additional validation of calculated values
            (asserts! (validate-activity new-activity) ERR-INVALID-ACTIVITY)
            (asserts! (validate-activity new-deposits) ERR-INVALID-ACTIVITY)
            
            ;; Calculate new trust level and update state
            (let (
                (new-trust-level (compute-trust-level 
                    current-completed
                    new-activity
                    new-deposits))
            )
                (asserts! (validate-trust-level new-trust-level) ERR-INVALID-TRUST-LEVEL)
                (ok (map-set hive-standing member
                    {
                        trust-level: new-trust-level,
                        completed-loans: current-completed,
                        community-activity: new-activity,
                        nectar-deposits: new-deposits
                    }
                ))
            )
        )
    )
)

;; Request honey (loan)
(define-public (request-honey (amount uint))
    (let (
        (collector tx-sender)
        (standing (unwrap! (get-member-standing collector) ERR-UNAUTHORIZED))
        (current-loan (get-current-loan collector))
    )
        (asserts! (<= amount HONEY-POT-LIMIT) ERR-INVALID-LOAN-SIZE)
        (asserts! (>= (get trust-level standing) TRUST-THRESHOLD) ERR-POOR-STANDING)
        (asserts! (is-none current-loan) ERR-EXISTING-LOAN)
        
        (map-set current-loans collector {
            honey-amount: amount,
            collection-height: (+ block-height u1440),
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

;; Check honey status and update standing
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

;; Propose trust level adjustment
(define-public (propose-trust-adjustment 
    (subject-member principal)
    (proposed-level uint)
    (justification (string-ascii 256)))
    (let (
        (initiator tx-sender)
        (motion-id (var-get motion-nonce))
        (initiator-standing (unwrap! (get-member-standing initiator) ERR-UNAUTHORIZED))
    )
        ;; Validate inputs
        (asserts! (validate-member subject-member) ERR-INVALID-MEMBER)
        (asserts! (validate-trust-level proposed-level) ERR-INVALID-TRUST-LEVEL)
        (asserts! (not (is-eq justification "")) ERR-INVALID-JUSTIFICATION)
        (asserts! (>= (get trust-level initiator-standing) HIVE-COUNCIL-THRESHOLD) ERR-UNAUTHORIZED)
        
        ;; Create motion
        (map-set trust-motions motion-id {
            initiator: initiator,
            subject-member: subject-member,
            proposed-level: proposed-level,
            justification: justification,
            support-count: u0,
            oppose-count: u0,
            close-height: (+ block-height MOTION-DURATION),
            implemented: false
        })
        
        ;; Increment nonce
        (var-set motion-nonce (+ motion-id u1))
        (ok motion-id)
    )
)

;; Cast vote on trust motion
(define-public (vote-on-motion (motion-id uint) (support bool))
    (let (
        (voter tx-sender)
        (motion (unwrap! (map-get? trust-motions motion-id) ERR-INVALID-MOTION))
        (voter-standing (unwrap! (get-member-standing voter) ERR-UNAUTHORIZED))
        (updated-motion (merge motion {
            support-count: (if support (+ (get support-count motion) u1) (get support-count motion)),
            oppose-count: (if support (get oppose-count motion) (+ (get oppose-count motion) u1))
        }))
    )
        ;; Check voting requirements
        (asserts! (>= (get trust-level voter-standing) HIVE-COUNCIL-THRESHOLD) ERR-UNAUTHORIZED)
        (asserts! (< block-height (get close-height motion)) ERR-VOTING-CLOSED)
        (asserts! (is-none (map-get? motion-votes {motion-id: motion-id, voter: voter})) ERR-VOTE-RECORDED)
        
        ;; Record vote
        (map-set motion-votes {motion-id: motion-id, voter: voter} support)
        
        ;; Update vote counts
        (map-set trust-motions motion-id updated-motion)
        
        ;; Update community activity safely
        (try! (update-hive-activity voter u1 u0))
        (ok true)
    )
)

;; Implement passed motion
(define-public (implement-motion (motion-id uint))
    (let (
        (motion (unwrap! (map-get? trust-motions motion-id) ERR-INVALID-MOTION))
        (total-votes (+ (get support-count motion) (get oppose-count motion)))
    )
        ;; Check implementation requirements
        (asserts! (>= block-height (get close-height motion)) ERR-UNAUTHORIZED)
        (asserts! (not (get implemented motion)) ERR-UNAUTHORIZED)
        (asserts! (>= total-votes MINIMUM-VOTES-NEEDED) ERR-UNAUTHORIZED)
        (asserts! (validate-trust-level (get proposed-level motion)) ERR-INVALID-TRUST-LEVEL)
        
        ;; Check if motion passed (simple majority)
        (if (> (get support-count motion) (get oppose-count motion))
            (begin
                ;; Update subject member's standing
                (try! (set-trust-level (get subject-member motion) (get proposed-level motion)))
                ;; Mark motion as implemented
                (map-set trust-motions motion-id
                    (merge motion {implemented: true})
                )
                (ok true)
            )
            (ok false)
        )
    )
)

;; Private function to set trust level directly
(define-private (set-trust-level (member principal) (new-level uint))
    (let (
        (current-standing (unwrap! (get-member-standing member) ERR-UNAUTHORIZED))
    )
        (asserts! (validate-trust-level new-level) ERR-INVALID-TRUST-LEVEL)
        (ok (map-set hive-standing member
            (merge current-standing {trust-level: new-level})
        ))
    )
)

;; Getter Functions
(define-read-only (get-member-standing (member principal))
    (map-get? hive-standing member)
)

(define-read-only (get-current-loan (member principal))
    (map-get? current-loans member)
)

(define-read-only (get-nectar-balance (member principal))
    (default-to u0 (map-get? nectar-reserves member))
)

(define-read-only (get-motion (motion-id uint))
    (map-get? trust-motions motion-id)
)

(define-read-only (get-vote (motion-id uint) (voter principal))
    (map-get? motion-votes {motion-id: motion-id, voter: voter})
)