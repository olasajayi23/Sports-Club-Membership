;; title: Membership
;; version: 1.0.0
;; summary: Sports club membership token-gated system with on-chain benefits and voting
;; description: A comprehensive membership management system for sports clubs with NFT-based memberships

(define-trait membership-trait
    (
        (get-membership-info (principal) (response {membership-type: (string-ascii 20), tier: uint, benefits: uint, active: bool} uint))
        (has-voting-rights (principal) (response bool uint))
    )
)

(define-non-fungible-token membership-nft uint)
(define-fungible-token club-points)

(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-MEMBERSHIP-NOT-FOUND (err u404))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u402))
(define-constant ERR-INVALID-MEMBERSHIP-TYPE (err u400))
(define-constant ERR-VOTING-PERIOD-ENDED (err u403))
(define-constant ERR-ALREADY-VOTED (err u409))
(define-constant ERR-NO-VOTING-RIGHTS (err u405))
(define-constant ERR-PROPOSAL-NOT-ACTIVE (err u406))
(define-constant ERR-INVALID-TIER (err u407))

(define-constant CONTRACT-OWNER tx-sender)
(define-constant MEMBERSHIP-PRICE-BASIC u1000000)
(define-constant MEMBERSHIP-PRICE-PREMIUM u2500000)
(define-constant MEMBERSHIP-PRICE-VIP u5000000)
(define-constant VOTING-PERIOD-BLOCKS u1440)
(define-constant POINTS-BASIC-MONTHLY u100)
(define-constant POINTS-PREMIUM-MONTHLY u300)
(define-constant POINTS-VIP-MONTHLY u600)

(define-data-var next-membership-id uint u1)
(define-data-var next-proposal-id uint u1)
(define-data-var club-treasury uint u0)
(define-data-var total-members uint u0)

(define-map memberships uint {
    owner: principal,
    membership-type: (string-ascii 20),
    tier: uint,
    benefits: uint,
    registration-block: uint,
    expiration-block: uint,
    active: bool,
    points-claimed-block: uint
})

(define-map member-profiles principal {
    membership-id: uint,
    join-date: uint,
    total-benefits-claimed: uint,
    voting-power: uint
})

(define-map proposals uint {
    title: (string-ascii 100),
    description: (string-ascii 500),
    proposer: principal,
    start-block: uint,
    end-block: uint,
    votes-for: uint,
    votes-against: uint,
    executed: bool,
    proposal-type: (string-ascii 30)
})

(define-map votes {proposal-id: uint, voter: principal} {
    vote: bool,
    voting-power: uint,
    block-height: uint
})

(define-map membership-benefits uint {
    gym-access: bool,
    pool-access: bool,
    spa-access: bool,
    guest-passes: uint,
    priority-booking: bool,
    exclusive-events: bool
})

(define-public (mint-membership (membership-type (string-ascii 20)) (recipient principal))
    (let ((membership-id (var-get next-membership-id))
          (current-block stacks-block-height)
          (price (get-membership-price membership-type))
          (tier (get-membership-tier membership-type))
          (expiration (+ current-block u52560)))
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (> tier u0) ERR-INVALID-MEMBERSHIP-TYPE)
        (try! (stx-transfer? price recipient CONTRACT-OWNER))
        (try! (nft-mint? membership-nft membership-id recipient))
        (try! (ft-mint? club-points (get-monthly-points membership-type) recipient))
        (map-set memberships membership-id {
            owner: recipient,
            membership-type: membership-type,
            tier: tier,
            benefits: (calculate-benefits tier),
            registration-block: current-block,
            expiration-block: expiration,
            active: true,
            points-claimed-block: current-block
        })
        (map-set member-profiles recipient {
            membership-id: membership-id,
            join-date: current-block,
            total-benefits-claimed: u0,
            voting-power: tier
        })
        (set-membership-benefits membership-id tier)
        (var-set next-membership-id (+ membership-id u1))
        (var-set club-treasury (+ (var-get club-treasury) price))
        (var-set total-members (+ (var-get total-members) u1))
        (ok membership-id)
    )
)

(define-public (renew-membership (membership-id uint))
    (let ((membership (unwrap! (map-get? memberships membership-id) ERR-MEMBERSHIP-NOT-FOUND))
          (current-block stacks-block-height)
          (price (get-membership-price (get membership-type membership))))
        (asserts! (is-eq tx-sender (get owner membership)) ERR-NOT-AUTHORIZED)
        (try! (stx-transfer? price tx-sender CONTRACT-OWNER))
        (map-set memberships membership-id 
            (merge membership {
                expiration-block: (+ current-block u52560),
                active: true
            }))
        (var-set club-treasury (+ (var-get club-treasury) price))
        (ok true)
    )
)

(define-public (claim-monthly-points)
    (let ((member-profile (unwrap! (map-get? member-profiles tx-sender) ERR-MEMBERSHIP-NOT-FOUND))
          (membership-id (get membership-id member-profile))
          (membership (unwrap! (map-get? memberships membership-id) ERR-MEMBERSHIP-NOT-FOUND))
          (current-block stacks-block-height)
          (last-claim (get points-claimed-block membership))
          (blocks-since-claim (- current-block last-claim)))
        (asserts! (get active membership) ERR-MEMBERSHIP-NOT-FOUND)
        (asserts! (>= blocks-since-claim u4320) ERR-NOT-AUTHORIZED)
        (let ((points (get-monthly-points (get membership-type membership))))
            (try! (ft-mint? club-points points tx-sender))
            (map-set memberships membership-id 
                (merge membership { points-claimed-block: current-block }))
            (ok points)
        )
    )
)

(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)) (proposal-type (string-ascii 30)))
    (let ((proposal-id (var-get next-proposal-id))
          (current-block stacks-block-height)
          (member-profile (unwrap! (map-get? member-profiles tx-sender) ERR-NOT-AUTHORIZED)))
        (asserts! (> (get voting-power member-profile) u0) ERR-NO-VOTING-RIGHTS)
        (map-set proposals proposal-id {
            title: title,
            description: description,
            proposer: tx-sender,
            start-block: current-block,
            end-block: (+ current-block VOTING-PERIOD-BLOCKS),
            votes-for: u0,
            votes-against: u0,
            executed: false,
            proposal-type: proposal-type
        })
        (var-set next-proposal-id (+ proposal-id u1))
        (ok proposal-id)
    )
)

(define-public (vote-on-proposal (proposal-id uint) (vote bool))
    (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR-MEMBERSHIP-NOT-FOUND))
          (current-block stacks-block-height)
          (member-profile (unwrap! (map-get? member-profiles tx-sender) ERR-NO-VOTING-RIGHTS))
          (voting-power (get voting-power member-profile)))
        (asserts! (<= current-block (get end-block proposal)) ERR-VOTING-PERIOD-ENDED)
        (asserts! (is-none (map-get? votes {proposal-id: proposal-id, voter: tx-sender})) ERR-ALREADY-VOTED)
        (asserts! (> voting-power u0) ERR-NO-VOTING-RIGHTS)
        (map-set votes {proposal-id: proposal-id, voter: tx-sender} {
            vote: vote,
            voting-power: voting-power,
            block-height: current-block
        })
        (if vote
            (map-set proposals proposal-id 
                (merge proposal { votes-for: (+ (get votes-for proposal) voting-power) }))
            (map-set proposals proposal-id 
                (merge proposal { votes-against: (+ (get votes-against proposal) voting-power) }))
        )
        (ok true)
    )
)

(define-public (execute-proposal (proposal-id uint))
    (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR-MEMBERSHIP-NOT-FOUND))
          (current-block stacks-block-height))
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (> current-block (get end-block proposal)) ERR-PROPOSAL-NOT-ACTIVE)
        (asserts! (not (get executed proposal)) ERR-PROPOSAL-NOT-ACTIVE)
        (asserts! (> (get votes-for proposal) (get votes-against proposal)) ERR-PROPOSAL-NOT-ACTIVE)
        (map-set proposals proposal-id (merge proposal { executed: true }))
        (ok true)
    )
)

(define-public (upgrade-membership (membership-id uint) (new-type (string-ascii 20)))
    (let ((membership (unwrap! (map-get? memberships membership-id) ERR-MEMBERSHIP-NOT-FOUND))
          (current-tier (get tier membership))
          (new-tier (get-membership-tier new-type))
          (price-difference (- (get-membership-price new-type) (get-membership-price (get membership-type membership)))))
        (asserts! (is-eq tx-sender (get owner membership)) ERR-NOT-AUTHORIZED)
        (asserts! (> new-tier current-tier) ERR-INVALID-TIER)
        (try! (stx-transfer? price-difference tx-sender CONTRACT-OWNER))
        (map-set memberships membership-id 
            (merge membership {
                membership-type: new-type,
                tier: new-tier,
                benefits: (calculate-benefits new-tier)
            }))
        (map-set member-profiles tx-sender 
            (merge (unwrap! (map-get? member-profiles tx-sender) ERR-MEMBERSHIP-NOT-FOUND)
                { voting-power: new-tier }))
        (set-membership-benefits membership-id new-tier)
        (var-set club-treasury (+ (var-get club-treasury) price-difference))
        (ok true)
    )
)

(define-public (transfer-membership (membership-id uint) (new-owner principal))
    (let ((membership (unwrap! (map-get? memberships membership-id) ERR-MEMBERSHIP-NOT-FOUND)))
        (asserts! (is-eq tx-sender (get owner membership)) ERR-NOT-AUTHORIZED)
        (try! (nft-transfer? membership-nft membership-id tx-sender new-owner))
        (map-delete member-profiles tx-sender)
        (map-set memberships membership-id (merge membership { owner: new-owner }))
        (map-set member-profiles new-owner {
            membership-id: membership-id,
            join-date: (get registration-block membership),
            total-benefits-claimed: u0,
            voting-power: (get tier membership)
        })
        (ok true)
    )
)

(define-read-only (get-membership-info (member principal))
    (match (map-get? member-profiles member)
        member-data 
            (match (map-get? memberships (get membership-id member-data))
                membership-data 
                    (ok {
                        membership-type: (get membership-type membership-data),
                        tier: (get tier membership-data),
                        benefits: (get benefits membership-data),
                        active: (and 
                            (get active membership-data)
                            (> (get expiration-block membership-data) stacks-block-height)
                        )
                    })
                (err u404)
            )
        (err u404)
    )
)

(define-read-only (has-voting-rights (member principal))
    (match (map-get? member-profiles member)
        member-data 
            (let ((membership-id (get membership-id member-data)))
                (match (map-get? memberships membership-id)
                    membership 
                        (ok (and 
                            (get active membership)
                            (> (get expiration-block membership) stacks-block-height)
                            (> (get tier membership) u0)
                        ))
                    (ok false)
                )
            )
        (ok false)
    )
)

(define-read-only (get-proposal-info (proposal-id uint))
    (match (map-get? proposals proposal-id)
        proposal (ok proposal)
        (err u404)
    )
)

(define-read-only (get-vote-info (proposal-id uint) (voter principal))
    (match (map-get? votes {proposal-id: proposal-id, voter: voter})
        vote-data (ok vote-data)
        (err u404)
    )
)

(define-read-only (get-membership-benefits (membership-id uint))
    (match (map-get? membership-benefits membership-id)
        benefits (ok benefits)
        (err u404)
    )
)

(define-read-only (get-club-stats)
    (ok {
        total-members: (var-get total-members),
        treasury: (var-get club-treasury),
        next-membership-id: (var-get next-membership-id),
        next-proposal-id: (var-get next-proposal-id)
    })
)

(define-read-only (check-membership-expiry (membership-id uint))
    (match (map-get? memberships membership-id)
        membership 
            (ok {
                expired: (< (get expiration-block membership) stacks-block-height),
                blocks-remaining: (if (> (get expiration-block membership) stacks-block-height)
                    (- (get expiration-block membership) stacks-block-height)
                    u0
                )
            })
        (err u404)
    )
)

(define-private (get-membership-price (membership-type (string-ascii 20)))
    (if (is-eq membership-type "basic")
        MEMBERSHIP-PRICE-BASIC
        (if (is-eq membership-type "premium")
            MEMBERSHIP-PRICE-PREMIUM
            (if (is-eq membership-type "vip")
                MEMBERSHIP-PRICE-VIP
                u0
            )
        )
    )
)

(define-private (get-membership-tier (membership-type (string-ascii 20)))
    (if (is-eq membership-type "basic")
        u1
        (if (is-eq membership-type "premium")
            u2
            (if (is-eq membership-type "vip")
                u3
                u0
            )
        )
    )
)

(define-private (get-monthly-points (membership-type (string-ascii 20)))
    (if (is-eq membership-type "basic")
        POINTS-BASIC-MONTHLY
        (if (is-eq membership-type "premium")
            POINTS-PREMIUM-MONTHLY
            (if (is-eq membership-type "vip")
                POINTS-VIP-MONTHLY
                u0
            )
        )
    )
)

(define-private (calculate-benefits (tier uint))
    (if (is-eq tier u1)
        u3
        (if (is-eq tier u2)
            u6
            (if (is-eq tier u3)
                u10
                u0
            )
        )
    )
)

(define-private (set-membership-benefits (membership-id uint) (tier uint))
    (if (is-eq tier u1)
        (map-set membership-benefits membership-id {
            gym-access: true,
            pool-access: false,
            spa-access: false,
            guest-passes: u1,
            priority-booking: false,
            exclusive-events: false
        })
        (if (is-eq tier u2)
            (map-set membership-benefits membership-id {
                gym-access: true,
                pool-access: true,
                spa-access: false,
                guest-passes: u3,
                priority-booking: true,
                exclusive-events: false
            })
            (if (is-eq tier u3)
                (map-set membership-benefits membership-id {
                    gym-access: true,
                    pool-access: true,
                    spa-access: true,
                    guest-passes: u5,
                    priority-booking: true,
                    exclusive-events: true
                })
                false
            )
        )
    )
)

